package auth

import (
	"context"
	"errors"
	"regexp"
	"testing"
	"time"

	"github.com/tiagofur/peliculas-admob/backend/internal/mail"
)

type fakeMail struct{ sent []mail.Message }

func (f *fakeMail) Send(_ context.Context, m mail.Message) error {
	f.sent = append(f.sent, m)
	return nil
}

var codeRe = regexp.MustCompile(`\b\d{6}\b`)

func TestPasswordResetFlow(t *testing.T) {
	s, _ := testService(t)
	ctx := context.Background()
	box := &fakeMail{}
	s.Mail = box
	clock := time.Now()
	s.Now = func() time.Time { return clock }

	old, err := s.SignupEmail(ctx, "ana@example.com", "oldpassword", "Ana", "Pixel")
	if err != nil {
		t.Fatal(err)
	}

	// Unknown account: same answer, no email (no probing for accounts).
	if err := s.RequestPasswordReset(ctx, "nadie@example.com", "es"); err != nil {
		t.Fatal(err)
	}
	if len(box.sent) != 0 {
		t.Fatalf("emailed an unknown account")
	}

	if err := s.RequestPasswordReset(ctx, "Ana@Example.com", "en-US"); err != nil {
		t.Fatal(err)
	}
	if len(box.sent) != 1 || box.sent[0].To != "ana@example.com" || box.sent[0].Subject != "Your password reset code" {
		t.Fatalf("email: %+v", box.sent)
	}
	code := codeRe.FindString(box.sent[0].Text)

	// Cooldown: a second request right away sends nothing.
	if err := s.RequestPasswordReset(ctx, "ana@example.com", "es"); err != nil || len(box.sent) != 1 {
		t.Fatalf("cooldown ignored: %v %d", err, len(box.sent))
	}

	if _, err := s.ResetPassword(ctx, "ana@example.com", code, "short", "Pixel"); !errors.Is(err, ErrWeakPassword) {
		t.Fatalf("weak: %v", err)
	}
	wrong := "000000"
	if code == wrong {
		wrong = "111111"
	}
	if _, err := s.ResetPassword(ctx, "ana@example.com", wrong, "newpassword", "Pixel"); !errors.Is(err, ErrBadResetCode) {
		t.Fatalf("wrong code: %v", err)
	}

	sess, err := s.ResetPassword(ctx, "ana@example.com", code, "newpassword", "Pixel")
	if err != nil {
		t.Fatal(err)
	}
	if !sess.User.EmailVerified || sess.RefreshToken == "" {
		t.Fatalf("session: %+v", sess)
	}
	// Code is single use; old sessions are gone; new password works, old one doesn't.
	if _, err := s.ResetPassword(ctx, "ana@example.com", code, "another-one", "Pixel"); !errors.Is(err, ErrBadResetCode) {
		t.Fatalf("reused code: %v", err)
	}
	if _, err := s.Refresh(ctx, old.RefreshToken); err == nil {
		t.Fatal("old session survived the reset")
	}
	if _, err := s.LoginEmail(ctx, "ana@example.com", "oldpassword", "Pixel"); !errors.Is(err, ErrBadCredentials) {
		t.Fatalf("old password: %v", err)
	}
	if _, err := s.LoginEmail(ctx, "ana@example.com", "newpassword", "Pixel"); err != nil {
		t.Fatal(err)
	}
}

func TestPasswordResetLimits(t *testing.T) {
	s, _ := testService(t)
	ctx := context.Background()
	box := &fakeMail{}
	s.Mail = box
	clock := time.Now()
	s.Now = func() time.Time { return clock }
	if _, err := s.SignupEmail(ctx, "beto@example.com", "password1", "", ""); err != nil {
		t.Fatal(err)
	}

	if err := s.RequestPasswordReset(ctx, "beto@example.com", ""); err != nil {
		t.Fatal(err)
	}
	code := codeRe.FindString(box.sent[0].Text)
	wrong := "000000"
	if code == wrong {
		wrong = "111111"
	}
	for i := 0; i < resetMaxAttempts; i++ {
		_, _ = s.ResetPassword(ctx, "beto@example.com", wrong, "password2", "")
	}
	if _, err := s.ResetPassword(ctx, "beto@example.com", code, "password2", ""); !errors.Is(err, ErrBadResetCode) {
		t.Fatalf("code still valid after %d misses: %v", resetMaxAttempts, err)
	}

	// A fresh code (after the cooldown) works, and expires after 15 minutes.
	clock = clock.Add(2 * time.Minute)
	if err := s.RequestPasswordReset(ctx, "beto@example.com", ""); err != nil || len(box.sent) != 2 {
		t.Fatalf("second request: %v %d", err, len(box.sent))
	}
	code = codeRe.FindString(box.sent[1].Text)
	clock = clock.Add(resetTTL + time.Second)
	if _, err := s.ResetPassword(ctx, "beto@example.com", code, "password2", ""); !errors.Is(err, ErrBadResetCode) {
		t.Fatalf("expired code accepted: %v", err)
	}
}

func TestPasswordResetNeedsMail(t *testing.T) {
	s, _ := testService(t)
	if err := s.RequestPasswordReset(context.Background(), "x@example.com", ""); !errors.Is(err, ErrMailNotConfigured) {
		t.Fatalf("got %v", err)
	}
}

func TestResetEmailLanguages(t *testing.T) {
	for lang, subject := range map[string]string{
		"es-MX": "Tu código para restablecer la contraseña",
		"pt-BR": "Seu código para redefinir a senha",
		"fr":    "Tu código para restablecer la contraseña", // fallback
	} {
		m := resetEmail("a@b.co", "123456", lang)
		if m.Subject != subject || !codeRe.MatchString(m.HTML) {
			t.Errorf("%s: %q", lang, m.Subject)
		}
	}
}

func TestPasswordResetCreatesPasswordForAppleAccount(t *testing.T) {
	s, idp := testService(t)
	ctx := context.Background()
	box := &fakeMail{}
	s.Mail = box

	apple, err := s.SignInApple(ctx, SocialInput{IDToken: idp.token(t, "k1", appleClaims("apple-tiago", "Tiago@Example.com"))})
	if err != nil {
		t.Fatal(err)
	}
	if err := s.RequestPasswordReset(ctx, "tiago@example.com", "es"); err != nil {
		t.Fatal(err)
	}
	if len(box.sent) != 1 {
		t.Fatalf("an Apple-only account should get a code, sent=%d", len(box.sent))
	}
	code := codeRe.FindString(box.sent[0].Text)

	sess, err := s.ResetPassword(ctx, "tiago@example.com", code, "mi-clave-nueva", "Pixel")
	if err != nil {
		t.Fatal(err)
	}
	if sess.User.ID != apple.User.ID {
		t.Fatalf("reset signed into another account: %s vs %s", sess.User.ID, apple.User.ID)
	}
	login, err := s.LoginEmail(ctx, "tiago@example.com", "mi-clave-nueva", "Pixel")
	if err != nil || login.User.ID != apple.User.ID {
		t.Fatalf("email login after creating password: %v", err)
	}
	providers := map[string]bool{}
	for _, p := range login.User.Providers {
		providers[p] = true
	}
	if !providers["apple"] || !providers["email"] {
		t.Fatalf("providers: %v", login.User.Providers)
	}
	again, err := s.SignInApple(ctx, SocialInput{IDToken: idp.token(t, "k1", appleClaims("apple-tiago", ""))})
	if err != nil || again.User.ID != apple.User.ID {
		t.Fatalf("Apple sign-in still works on the same account: %v", err)
	}
}
