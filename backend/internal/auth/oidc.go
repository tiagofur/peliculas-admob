package auth

import (
	"context"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"slices"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// IDClaims is what we keep from an Apple or Google ID token.
type IDClaims struct {
	Subject       string
	Email         string
	EmailVerified bool
	Nonce         string
}

// Verifier checks ID tokens signed by an OpenID provider.
type Verifier struct {
	Provider  string
	Issuers   []string
	Audiences []string
	keys      *JWKS
	now       func() time.Time
}

func NewAppleVerifier(clientIDs []string) *Verifier {
	return &Verifier{Provider: "apple", Issuers: []string{"https://appleid.apple.com"},
		Audiences: clientIDs, keys: NewJWKS("https://appleid.apple.com/auth/keys"), now: time.Now}
}

func NewGoogleVerifier(clientIDs []string) *Verifier {
	return &Verifier{Provider: "google", Issuers: []string{"https://accounts.google.com", "accounts.google.com"},
		Audiences: clientIDs, keys: NewJWKS("https://www.googleapis.com/oauth2/v3/certs"), now: time.Now}
}

// boolish accepts true or "true": Apple sends email_verified as a string.
type boolish bool

func (b *boolish) UnmarshalJSON(data []byte) error {
	*b = boolish(string(data) == "true" || string(data) == `"true"`)
	return nil
}

type idTokenClaims struct {
	jwt.RegisteredClaims
	Email         string  `json:"email"`
	EmailVerified boolish `json:"email_verified"`
	Nonce         string  `json:"nonce"`
}

func (v *Verifier) Verify(ctx context.Context, token string) (IDClaims, error) {
	if v == nil || len(v.Audiences) == 0 {
		return IDClaims{}, ErrNotConfigured
	}
	var c idTokenClaims
	_, err := jwt.ParseWithClaims(token, &c, func(t *jwt.Token) (any, error) {
		kid, _ := t.Header["kid"].(string)
		return v.keys.Key(ctx, kid)
	},
		jwt.WithValidMethods([]string{"RS256"}),
		jwt.WithExpirationRequired(),
		jwt.WithTimeFunc(v.now),
		jwt.WithLeeway(30*time.Second),
	)
	if err != nil {
		return IDClaims{}, fmt.Errorf("%w: %v", ErrInvalidToken, err)
	}
	if !slices.Contains(v.Issuers, c.Issuer) {
		return IDClaims{}, fmt.Errorf("%w: issuer %q", ErrInvalidToken, c.Issuer)
	}
	if !slices.ContainsFunc(c.Audience, func(a string) bool { return slices.Contains(v.Audiences, a) }) {
		return IDClaims{}, fmt.Errorf("%w: audience", ErrInvalidToken)
	}
	if c.Subject == "" {
		return IDClaims{}, fmt.Errorf("%w: no subject", ErrInvalidToken)
	}
	return IDClaims{Subject: c.Subject, Email: c.Email, EmailVerified: bool(c.EmailVerified), Nonce: c.Nonce}, nil
}

// CheckNonce compares the token nonce with the raw nonce the app generated.
// Apple stores sha256(raw) as hex; Google stores the raw value.
func CheckNonce(tokenNonce, raw string) bool {
	if raw == "" {
		return true // nonce is optional
	}
	sum := sha256.Sum256([]byte(raw))
	hashed := hex.EncodeToString(sum[:])
	return subtle.ConstantTimeCompare([]byte(tokenNonce), []byte(hashed)) == 1 ||
		subtle.ConstantTimeCompare([]byte(tokenNonce), []byte(raw)) == 1
}

// JWKS fetches and caches a provider's public keys. Unknown key IDs trigger a
// refetch (providers rotate keys), at most once a minute.
type JWKS struct {
	URL    string
	HTTP   *http.Client
	mu     sync.Mutex
	keys   map[string]*rsa.PublicKey
	loaded time.Time
}

func NewJWKS(url string) *JWKS {
	return &JWKS{URL: url, HTTP: &http.Client{Timeout: 5 * time.Second}}
}

func (j *JWKS) Key(ctx context.Context, kid string) (*rsa.PublicKey, error) {
	j.mu.Lock()
	defer j.mu.Unlock()
	if k, ok := j.keys[kid]; ok && time.Since(j.loaded) < 24*time.Hour {
		return k, nil
	}
	if time.Since(j.loaded) > time.Minute || j.keys == nil {
		if err := j.load(ctx); err != nil {
			return nil, err
		}
	}
	if k, ok := j.keys[kid]; ok {
		return k, nil
	}
	return nil, errors.New("auth: unknown signing key")
}

func (j *JWKS) load(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, j.URL, nil)
	if err != nil {
		return err
	}
	resp, err := j.HTTP.Do(req)
	if err != nil {
		return fmt.Errorf("auth: fetch jwks: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("auth: fetch jwks: %s", resp.Status)
	}
	var set struct {
		Keys []struct {
			Kid string `json:"kid"`
			Kty string `json:"kty"`
			N   string `json:"n"`
			E   string `json:"e"`
		} `json:"keys"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&set); err != nil {
		return fmt.Errorf("auth: decode jwks: %w", err)
	}
	keys := map[string]*rsa.PublicKey{}
	for _, k := range set.Keys {
		if k.Kty != "RSA" {
			continue
		}
		n, err1 := base64.RawURLEncoding.DecodeString(k.N)
		e, err2 := base64.RawURLEncoding.DecodeString(k.E)
		if err1 != nil || err2 != nil {
			continue
		}
		keys[k.Kid] = &rsa.PublicKey{N: new(big.Int).SetBytes(n), E: int(new(big.Int).SetBytes(e).Int64())}
	}
	j.keys, j.loaded = keys, time.Now()
	return nil
}
