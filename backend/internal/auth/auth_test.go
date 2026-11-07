package auth

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"math/big"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"

	"github.com/tiagofur/peliculas-admob/backend/internal/db"
)

// ---- fake OpenID provider ----

type fakeIDP struct {
	key *rsa.PrivateKey
	srv *httptest.Server
}

func newFakeIDP(t *testing.T) *fakeIDP {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	f := &fakeIDP{key: key}
	f.srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		json.NewEncoder(w).Encode(map[string]any{"keys": []map[string]string{{
			"kid": "k1", "kty": "RSA",
			"n": base64.RawURLEncoding.EncodeToString(key.N.Bytes()),
			"e": base64.RawURLEncoding.EncodeToString(big.NewInt(int64(key.E)).Bytes()),
		}}})
	}))
	t.Cleanup(f.srv.Close)
	return f
}

func (f *fakeIDP) verifier(provider, iss, aud string) *Verifier {
	return &Verifier{Provider: provider, Issuers: []string{iss}, Audiences: []string{aud}, keys: NewJWKS(f.srv.URL), now: time.Now}
}

func (f *fakeIDP) token(t *testing.T, kid string, claims jwt.MapClaims) string {
	tok := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	tok.Header["kid"] = kid
	s, err := tok.SignedString(f.key)
	if err != nil {
		t.Fatal(err)
	}
	return s
}

func appleClaims(sub, email string) jwt.MapClaims {
	return jwt.MapClaims{
		"iss": "https://appleid.apple.com", "aud": "com.peliculas.app", "sub": sub,
		"email": email, "email_verified": "true", "exp": time.Now().Add(time.Hour).Unix(),
	}
}

// ---- pure tests ----

func TestIssuer(t *testing.T) {
	iss, err := NewIssuer([]byte("0123456789abcdef0123456789abcdef"))
	if err != nil {
		t.Fatal(err)
	}
	tok, _ := iss.Issue("user-1")
	if id, err := iss.Parse(tok); err != nil || id != "user-1" {
		t.Fatalf("parse: %q %v", id, err)
	}
	other, _ := NewIssuer([]byte("ffffffffffffffffffffffffffffffff"))
	if _, err := other.Parse(tok); err == nil {
		t.Fatal("token signed with another secret must fail")
	}
	iss.now = func() time.Time { return time.Now().Add(AccessTTL + time.Minute) }
	if _, err := iss.Parse(tok); err == nil {
		t.Fatal("expired token must fail")
	}
	if _, err := NewIssuer([]byte("short")); err == nil {
		t.Fatal("short secret must be rejected")
	}
}

func TestVerifier(t *testing.T) {
	idp := newFakeIDP(t)
	v := idp.verifier("apple", "https://appleid.apple.com", "com.peliculas.app")
	ctx := context.Background()

	c, err := v.Verify(ctx, idp.token(t, "k1", appleClaims("apple-1", "a@b.com")))
	if err != nil || c.Subject != "apple-1" || !c.EmailVerified {
		t.Fatalf("valid token: %+v %v", c, err)
	}
	bad := map[string]jwt.MapClaims{
		"wrong audience": {"iss": "https://appleid.apple.com", "aud": "other.app", "sub": "x", "exp": time.Now().Add(time.Hour).Unix()},
		"wrong issuer":   {"iss": "https://evil.com", "aud": "com.peliculas.app", "sub": "x", "exp": time.Now().Add(time.Hour).Unix()},
		"expired":        {"iss": "https://appleid.apple.com", "aud": "com.peliculas.app", "sub": "x", "exp": time.Now().Add(-time.Hour).Unix()},
		"no expiry":      {"iss": "https://appleid.apple.com", "aud": "com.peliculas.app", "sub": "x"},
	}
	for name, claims := range bad {
		if _, err := v.Verify(ctx, idp.token(t, "k1", claims)); !errors.Is(err, ErrInvalidToken) {
			t.Errorf("%s: want ErrInvalidToken, got %v", name, err)
		}
	}
	if _, err := v.Verify(ctx, idp.token(t, "unknown", appleClaims("x", ""))); err == nil {
		t.Error("unknown key id must fail")
	}
	hs := jwt.NewWithClaims(jwt.SigningMethodHS256, appleClaims("x", ""))
	hsTok, _ := hs.SignedString([]byte("secret"))
	if _, err := v.Verify(ctx, hsTok); err == nil {
		t.Error("HS256 token must be rejected")
	}
	if _, err := (&Verifier{Provider: "google"}).Verify(ctx, "x"); !errors.Is(err, ErrNotConfigured) {
		t.Errorf("unconfigured: %v", err)
	}
}

func TestCheckNonce(t *testing.T) {
	// sha256("abc")
	hashed := "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
	if !CheckNonce(hashed, "abc") || !CheckNonce("abc", "abc") || !CheckNonce("anything", "") {
		t.Fatal("valid nonces rejected")
	}
	if CheckNonce(hashed, "abd") {
		t.Fatal("wrong nonce accepted")
	}
}

// ---- database tests (need TEST_DATABASE_URL) ----

func testService(t *testing.T) (*Service, *fakeIDP) {
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("TEST_DATABASE_URL not set")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(pool.Close)
	if err := db.Migrate(ctx, pool); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `TRUNCATE users CASCADE`); err != nil {
		t.Fatal(err)
	}
	iss, _ := NewIssuer([]byte("0123456789abcdef0123456789abcdef"))
	idp := newFakeIDP(t)
	return &Service{
		DB: pool, Tokens: iss,
		Apple:  idp.verifier("apple", "https://appleid.apple.com", "com.peliculas.app"),
		Google: idp.verifier("google", "https://accounts.google.com", "google-client"),
	}, idp
}

func TestEmailSignupAndLogin(t *testing.T) {
	s, _ := testService(t)
	ctx := context.Background()

	sess, err := s.SignupEmail(ctx, "  Ana@Example.com ", "supersecret", "Ana", "iPhone")
	if err != nil {
		t.Fatal(err)
	}
	if sess.User.Email != "ana@example.com" || sess.User.DisplayName != "Ana" || sess.RefreshToken == "" {
		t.Fatalf("session: %+v", sess)
	}
	if _, err := s.SignupEmail(ctx, "ana@example.com", "anotherpass", "", ""); !errors.Is(err, ErrEmailTaken) {
		t.Fatalf("duplicate: %v", err)
	}
	if _, err := s.SignupEmail(ctx, "x@y.com", "short", "", ""); !errors.Is(err, ErrWeakPassword) {
		t.Fatalf("weak: %v", err)
	}
	if _, err := s.SignupEmail(ctx, "not-an-email", "supersecret", "", ""); !errors.Is(err, ErrBadEmail) {
		t.Fatalf("bad email: %v", err)
	}
	if _, err := s.LoginEmail(ctx, "ANA@example.com", "supersecret", ""); err != nil {
		t.Fatalf("login: %v", err)
	}
	if _, err := s.LoginEmail(ctx, "ana@example.com", "wrongpass", ""); !errors.Is(err, ErrBadCredentials) {
		t.Fatalf("wrong password: %v", err)
	}
	if _, err := s.LoginEmail(ctx, "nobody@example.com", "supersecret", ""); !errors.Is(err, ErrBadCredentials) {
		t.Fatalf("unknown email: %v", err)
	}
}

func TestSupabaseBcryptHashStillWorks(t *testing.T) {
	s, _ := testService(t)
	ctx := context.Background()
	sess, _ := s.SignupEmail(ctx, "old@example.com", "placeholder", "", "")
	// GoTrue stores bcrypt at cost 10 with the $2a$ prefix.
	hash, err := bcrypt.GenerateFromPassword([]byte("migrated-pass"), 10)
	if err != nil {
		t.Fatal(err)
	}
	s.DB.Exec(ctx, `UPDATE identities SET password_hash = $2 WHERE user_id = $1`,
		sess.User.ID, "$2a$"+string(hash[4:]))
	if _, err := s.LoginEmail(ctx, "old@example.com", "migrated-pass", ""); err != nil {
		t.Fatalf("cost-10 hash should verify: %v", err)
	}
}

func TestRefreshRotation(t *testing.T) {
	s, _ := testService(t)
	ctx := context.Background()
	clock := time.Now()
	s.Now = func() time.Time { return clock }

	first, _ := s.SignupEmail(ctx, "r@example.com", "supersecret", "", "iPad")
	second, err := s.Refresh(ctx, first.RefreshToken)
	if err != nil || second.RefreshToken == first.RefreshToken {
		t.Fatalf("rotate: %v", err)
	}

	// Reuse within the grace window: rejected, but the new token keeps working.
	if _, err := s.Refresh(ctx, first.RefreshToken); !errors.Is(err, ErrInvalidToken) {
		t.Fatalf("reuse in grace: %v", err)
	}
	third, err := s.Refresh(ctx, second.RefreshToken)
	if err != nil {
		t.Fatalf("family should survive a race: %v", err)
	}

	// Reuse after the grace window looks like theft: the whole family dies.
	clock = clock.Add(time.Minute)
	if _, err := s.Refresh(ctx, first.RefreshToken); !errors.Is(err, ErrInvalidToken) {
		t.Fatalf("stolen reuse: %v", err)
	}
	if _, err := s.Refresh(ctx, third.RefreshToken); !errors.Is(err, ErrInvalidToken) {
		t.Fatal("family must be revoked after reuse")
	}

	// Expiry.
	fresh, _ := s.LoginEmail(ctx, "r@example.com", "supersecret", "")
	clock = clock.Add(RefreshTTL + time.Hour)
	if _, err := s.Refresh(ctx, fresh.RefreshToken); !errors.Is(err, ErrInvalidToken) {
		t.Fatalf("expired: %v", err)
	}
	if _, err := s.Refresh(ctx, "garbage"); !errors.Is(err, ErrInvalidToken) {
		t.Fatalf("garbage: %v", err)
	}
}

func TestLogoutOnlyEndsThatDevice(t *testing.T) {
	s, _ := testService(t)
	ctx := context.Background()
	phone, _ := s.SignupEmail(ctx, "l@example.com", "supersecret", "", "iPhone")
	tv, _ := s.LoginEmail(ctx, "l@example.com", "supersecret", "Apple TV")
	if err := s.Logout(ctx, phone.RefreshToken); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Refresh(ctx, phone.RefreshToken); err == nil {
		t.Fatal("logged-out device must not refresh")
	}
	if _, err := s.Refresh(ctx, tv.RefreshToken); err != nil {
		t.Fatalf("other device should stay signed in: %v", err)
	}
}

func TestAppleSignIn(t *testing.T) {
	s, idp := testService(t)
	ctx := context.Background()

	first, err := s.SignInApple(ctx, SocialInput{
		IDToken: idp.token(t, "k1", appleClaims("apple-sub", "Relay@privaterelay.appleid.com")), Name: "Tiago",
	})
	if err != nil {
		t.Fatal(err)
	}
	if first.User.Email != "relay@privaterelay.appleid.com" || !first.User.EmailVerified ||
		first.User.DisplayName != "Tiago" || first.User.Providers[0] != "apple" {
		t.Fatalf("new apple user: %+v", first.User)
	}
	again, err := s.SignInApple(ctx, SocialInput{IDToken: idp.token(t, "k1", appleClaims("apple-sub", ""))})
	if err != nil || again.User.ID != first.User.ID || again.User.DisplayName != "Tiago" {
		t.Fatalf("returning user: %+v %v", again.User, err)
	}

	claims := appleClaims("apple-nonce", "")
	claims["nonce"] = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
	if _, err := s.SignInApple(ctx, SocialInput{IDToken: idp.token(t, "k1", claims), Nonce: "wrong"}); !errors.Is(err, ErrNonce) {
		t.Fatalf("nonce mismatch: %v", err)
	}
	if _, err := s.SignInApple(ctx, SocialInput{IDToken: idp.token(t, "k1", claims), Nonce: "abc"}); err != nil {
		t.Fatalf("nonce ok: %v", err)
	}
}

func TestSocialTakesOverUnverifiedEmailAccount(t *testing.T) {
	s, idp := testService(t)
	ctx := context.Background()

	// Someone registers the victim's email with a password first.
	squatter, _ := s.SignupEmail(ctx, "victim@gmail.com", "attackerpass", "", "")

	google := jwt.MapClaims{"iss": "https://accounts.google.com", "aud": "google-client", "sub": "g-1",
		"email": "victim@gmail.com", "email_verified": true, "exp": time.Now().Add(time.Hour).Unix()}
	sess, err := s.SignInGoogle(ctx, SocialInput{IDToken: idp.token(t, "k1", google)})
	if err != nil {
		t.Fatal(err)
	}
	if sess.User.ID != squatter.User.ID || !sess.User.EmailVerified || len(sess.User.Providers) != 1 || sess.User.Providers[0] != "google" {
		t.Fatalf("claimed user: %+v", sess.User)
	}
	if _, err := s.LoginEmail(ctx, "victim@gmail.com", "attackerpass", ""); !errors.Is(err, ErrBadCredentials) {
		t.Fatal("squatter password must be gone")
	}
	if _, err := s.Refresh(ctx, squatter.RefreshToken); err == nil {
		t.Fatal("squatter sessions must be revoked")
	}
}

func TestSocialLinksVerifiedAccount(t *testing.T) {
	s, idp := testService(t)
	ctx := context.Background()
	apple, _ := s.SignInApple(ctx, SocialInput{IDToken: idp.token(t, "k1", appleClaims("a-2", "same@gmail.com"))})

	google := jwt.MapClaims{"iss": "https://accounts.google.com", "aud": "google-client", "sub": "g-2",
		"email": "same@gmail.com", "email_verified": true, "exp": time.Now().Add(time.Hour).Unix()}
	sess, err := s.SignInGoogle(ctx, SocialInput{IDToken: idp.token(t, "k1", google)})
	if err != nil || sess.User.ID != apple.User.ID || len(sess.User.Providers) != 2 {
		t.Fatalf("link: %+v %v", sess.User, err)
	}
	if _, err := s.Refresh(ctx, apple.RefreshToken); err != nil {
		t.Fatal("linking a verified account must not revoke its sessions")
	}
}

func TestUnverifiedSocialEmailIsNotStored(t *testing.T) {
	s, idp := testService(t)
	ctx := context.Background()
	s.SignupEmail(ctx, "taken@example.com", "supersecret", "", "")
	c := appleClaims("a-3", "taken@example.com")
	c["email_verified"] = "false"
	sess, err := s.SignInApple(ctx, SocialInput{IDToken: idp.token(t, "k1", c)})
	if err != nil {
		t.Fatal(err)
	}
	if sess.User.Email != "" {
		t.Fatalf("unverified email must not be trusted: %+v", sess.User)
	}
}

func TestUpdateAndDeleteAccount(t *testing.T) {
	s, _ := testService(t)
	ctx := context.Background()
	sess, _ := s.SignupEmail(ctx, "d@example.com", "supersecret", "", "")
	name, country := "Nuevo", "mx"
	u, err := s.UpdateMe(ctx, sess.User.ID, Patch{DisplayName: &name, Country: &country})
	if err != nil || u.DisplayName != "Nuevo" || u.Country != "MX" {
		t.Fatalf("update: %+v %v", u, err)
	}
	bad := "too-long-country"
	if _, err := s.UpdateMe(ctx, sess.User.ID, Patch{Country: &bad}); !errors.Is(err, ErrBadInput) {
		t.Fatalf("bad country: %v", err)
	}
	if err := s.DeleteAccount(ctx, sess.User.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Me(ctx, sess.User.ID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("deleted user: %v", err)
	}
	if _, err := s.Refresh(ctx, sess.RefreshToken); err == nil {
		t.Fatal("sessions must be gone")
	}
	if _, err := s.SignupEmail(ctx, "d@example.com", "supersecret", "", ""); err != nil {
		t.Fatalf("email should be free again: %v", err)
	}
	if err := s.DeleteAccount(ctx, sess.User.ID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("double delete: %v", err)
	}
}
