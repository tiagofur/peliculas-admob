// Package auth handles sign-in (email, Apple, Google), sessions and accounts.
package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const (
	AccessTTL  = 15 * time.Minute
	RefreshTTL = 60 * 24 * time.Hour
	// A refresh token reused this soon after rotation is treated as a client
	// race (two requests at once), not theft, so the family is not revoked.
	reuseGrace = 30 * time.Second

	issuer   = "peliculas-api"
	audience = "peliculas-app"
)

var (
	ErrInvalidToken  = errors.New("auth: invalid token")
	ErrNotConfigured = errors.New("auth: sign-in method not configured")
)

// Issuer signs and checks short-lived access tokens (HS256).
type Issuer struct {
	secret []byte
	now    func() time.Time
}

func NewIssuer(secret []byte) (*Issuer, error) {
	if len(secret) < 32 {
		return nil, errors.New("auth: JWT secret must be at least 32 bytes")
	}
	return &Issuer{secret: secret, now: time.Now}, nil
}

func (i *Issuer) Issue(userID string) (string, error) {
	now := i.now()
	return jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.RegisteredClaims{
		Issuer:    issuer,
		Audience:  jwt.ClaimStrings{audience},
		Subject:   userID,
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(now.Add(AccessTTL)),
	}).SignedString(i.secret)
}

// Parse returns the user ID of a valid access token.
func (i *Issuer) Parse(token string) (string, error) {
	var c jwt.RegisteredClaims
	_, err := jwt.ParseWithClaims(token, &c, func(*jwt.Token) (any, error) { return i.secret, nil },
		jwt.WithValidMethods([]string{"HS256"}),
		jwt.WithIssuer(issuer),
		jwt.WithAudience(audience),
		jwt.WithExpirationRequired(),
		jwt.WithTimeFunc(i.now),
	)
	if err != nil || c.Subject == "" {
		return "", ErrInvalidToken
	}
	return c.Subject, nil
}

// newRefreshToken returns the opaque token for the client and the hash we store.
func newRefreshToken() (token string, hash []byte) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		panic(err) // crypto/rand never fails on supported platforms
	}
	token = base64.RawURLEncoding.EncodeToString(b)
	return token, hashToken(token)
}

func hashToken(token string) []byte {
	h := sha256.Sum256([]byte(token))
	return h[:]
}
