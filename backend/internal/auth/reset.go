package auth

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"errors"
	"fmt"
	"math/big"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"

	"github.com/tiagofur/peliculas-admob/backend/internal/mail"
)

var (
	// ErrBadResetCode covers a wrong, expired, used or over-tried code (one answer for all).
	ErrBadResetCode = errors.New("auth: invalid or expired reset code")
	// ErrMailNotConfigured: the server has no RESEND_API_KEY, so resets can't be sent.
	ErrMailNotConfigured = errors.New("auth: mail not configured")
)

const (
	resetTTL         = 15 * time.Minute
	resetMaxAttempts = 5
	resetCooldown    = time.Minute // between two codes for the same account
)

// RequestPasswordReset emails a 6-digit code to the account with that email. It
// answers the same whether or not the account exists, so it can't be used to probe
// emails. Accounts that only sign in with Apple/Google get a code too: using it
// adds a password (the code proves they own the inbox), so they can also sign in
// with email — e.g. on Android, which has no Sign in with Apple.
func (s *Service) RequestPasswordReset(ctx context.Context, email, lang string) error {
	if s.Mail == nil {
		return ErrMailNotConfigured
	}
	email, err := normalizeEmail(email)
	if err != nil {
		return err
	}
	userID, err := userByEmail(ctx, s.DB, email)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil
	}
	if err != nil {
		return err
	}

	now := s.now()
	var recent bool
	if err := s.DB.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM password_resets
		WHERE user_id = $1 AND created_at > $2)`, userID, now.Add(-resetCooldown)).Scan(&recent); err != nil {
		return err
	}
	if recent {
		return nil // anti-spam: the previous code is still on its way
	}

	code, err := resetCode()
	if err != nil {
		return err
	}
	tx, err := s.DB.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if _, err := tx.Exec(ctx, `UPDATE password_resets SET used_at = $2
		WHERE user_id = $1 AND used_at IS NULL`, userID, now); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `INSERT INTO password_resets (user_id, code_hash, created_at, expires_at)
		VALUES ($1, $2, $3, $4)`, userID, resetHash(userID, code), now, now.Add(resetTTL)); err != nil {
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return err
	}

	if err := s.Mail.Send(ctx, resetEmail(email, code, lang)); err != nil {
		// The code is stored; the user can ask again after the cooldown.
		s.log().Error("password reset email", "err", err)
		if errors.Is(err, mail.ErrNotConfigured) {
			return ErrMailNotConfigured
		}
	}
	return nil
}

// ResetPassword checks the emailed code, sets the new password, signs every
// other session out and returns a fresh session (the user lands signed in).
func (s *Service) ResetPassword(ctx context.Context, email, code, password, device string) (Session, error) {
	if len(password) < 8 || len(password) > 72 {
		return Session{}, ErrWeakPassword
	}
	email, err := normalizeEmail(email)
	if err != nil {
		return Session{}, ErrBadResetCode
	}
	code = strings.TrimSpace(code)

	tx, err := s.DB.Begin(ctx)
	if err != nil {
		return Session{}, err
	}
	defer tx.Rollback(ctx)

	now := s.now()
	userID, err := userByEmail(ctx, tx, email)
	if errors.Is(err, pgx.ErrNoRows) {
		return Session{}, ErrBadResetCode
	}
	if err != nil {
		return Session{}, err
	}
	var resetID string
	var hash []byte
	err = tx.QueryRow(ctx, `SELECT id, code_hash FROM password_resets
		WHERE user_id = $1 AND used_at IS NULL AND expires_at > $2 AND attempts < $3
		ORDER BY created_at DESC LIMIT 1 FOR UPDATE`, userID, now, resetMaxAttempts).
		Scan(&resetID, &hash)
	if errors.Is(err, pgx.ErrNoRows) {
		return Session{}, ErrBadResetCode
	}
	if err != nil {
		return Session{}, err
	}
	if subtle.ConstantTimeCompare(hash, resetHash(userID, code)) != 1 {
		// Count the miss and keep it even though we return an error.
		if _, err := tx.Exec(ctx, `UPDATE password_resets SET attempts = attempts + 1 WHERE id = $1`, resetID); err != nil {
			return Session{}, err
		}
		if err := tx.Commit(ctx); err != nil {
			return Session{}, err
		}
		return Session{}, ErrBadResetCode
	}

	newHash, err := bcrypt.GenerateFromPassword([]byte(password), bcryptCost)
	if err != nil {
		return Session{}, err
	}
	for _, q := range []struct {
		sql  string
		args []any
	}{
		{`UPDATE password_resets SET used_at = $2 WHERE id = $1`, []any{resetID, now}},
		// They proved they own the inbox.
		{`UPDATE users SET email_verified = true, updated_at = $2 WHERE id = $1`, []any{userID, now}},
		{`UPDATE refresh_tokens SET revoked_at = $2 WHERE user_id = $1 AND revoked_at IS NULL`, []any{userID, now}},
	} {
		if _, err := tx.Exec(ctx, q.sql, q.args...); err != nil {
			return Session{}, err
		}
	}
	// Change the password, or create the email identity for an Apple/Google-only
	// account. If that email identity somehow belongs to another user, refuse.
	tag, err := tx.Exec(ctx, `INSERT INTO identities (user_id, provider, subject, email, password_hash)
		VALUES ($1, 'email', $2, $2, $3)
		ON CONFLICT (provider, subject) DO UPDATE SET password_hash = EXCLUDED.password_hash
		WHERE identities.user_id = EXCLUDED.user_id`, userID, email, string(newHash))
	if err != nil {
		return Session{}, err
	}
	if tag.RowsAffected() != 1 {
		return Session{}, ErrBadResetCode
	}
	sess, err := s.newSession(ctx, tx, userID, device)
	if err != nil {
		return Session{}, err
	}
	return sess, tx.Commit(ctx)
}

// userByEmail finds the account for an email: its email-and-password identity
// first, else the account email (Apple/Google sign-ups).
func userByEmail(ctx context.Context, q querier, email string) (string, error) {
	var userID string
	err := q.QueryRow(ctx, `SELECT user_id FROM (
		SELECT user_id, 0 AS rank FROM identities WHERE provider = 'email' AND subject = $1
		UNION ALL
		SELECT id, 1 FROM users WHERE email = $1
	) m ORDER BY rank LIMIT 1`, email).Scan(&userID)
	return userID, err
}

func resetCode() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(1_000_000))
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

// resetHash binds the code to the user so a leaked hash table can't be replayed.
func resetHash(userID, code string) []byte {
	return hashToken(userID + ":" + code)
}

func resetEmail(to, code, lang string) mail.Message {
	type copy struct{ subject, intro, expiry, ignore string }
	texts := map[string]copy{
		"es": {"Tu código para restablecer la contraseña", "Usa este código en la app Películas para crear o cambiar tu contraseña:", "Caduca en 15 minutos.", "Si no lo pediste, ignora este correo: tu contraseña no cambia."},
		"en": {"Your password reset code", "Use this code in the Películas app to create or change your password:", "It expires in 15 minutes.", "If you didn't ask for it, ignore this email: your password stays the same."},
		"pt": {"Seu código para redefinir a senha", "Use este código no app Películas para criar ou trocar sua senha:", "Expira em 15 minutos.", "Se você não pediu, ignore este e-mail: sua senha não muda."},
	}
	lang = strings.ToLower(lang)
	if len(lang) > 2 {
		lang = lang[:2]
	}
	t, ok := texts[lang]
	if !ok {
		t = texts["es"]
	}
	text := fmt.Sprintf("%s\n\n%s\n\n%s\n\n%s\n", t.intro, code, t.expiry, t.ignore)
	html := fmt.Sprintf(`<div style="font-family:-apple-system,Roboto,Helvetica,Arial,sans-serif;max-width:480px;margin:0 auto;padding:24px;color:#1c1c1e">
<h2 style="margin:0 0 16px">Películas</h2>
<p>%s</p>
<p style="font-size:32px;font-weight:700;letter-spacing:8px;margin:24px 0;color:#E84F2E">%s</p>
<p>%s</p>
<p style="color:#6c6c70;font-size:13px">%s</p>
</div>`, t.intro, code, t.expiry, t.ignore)
	return mail.Message{To: to, Subject: t.subject, Text: text, HTML: html}
}
