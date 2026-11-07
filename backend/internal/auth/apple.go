package auth

import (
	"context"
	"crypto/ecdsa"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// AppleClient exchanges sign-in codes and revokes tokens. App Review requires
// revoking Apple tokens when a user deletes their account.
type AppleClient struct {
	TeamID   string
	KeyID    string
	ClientID string // the iOS bundle ID
	Key      *ecdsa.PrivateKey
	BaseURL  string
	HTTP     *http.Client
}

// NewAppleClient returns nil when the .p8 key is not configured.
func NewAppleClient(teamID, keyID, clientID, privateKeyPEM string) (*AppleClient, error) {
	if teamID == "" || keyID == "" || privateKeyPEM == "" || clientID == "" {
		return nil, nil
	}
	key, err := jwt.ParseECPrivateKeyFromPEM([]byte(strings.ReplaceAll(privateKeyPEM, `\n`, "\n")))
	if err != nil {
		return nil, fmt.Errorf("auth: APPLE_PRIVATE_KEY: %w", err)
	}
	return &AppleClient{TeamID: teamID, KeyID: keyID, ClientID: clientID, Key: key,
		BaseURL: "https://appleid.apple.com", HTTP: &http.Client{Timeout: 10 * time.Second}}, nil
}

func (a *AppleClient) clientSecret() (string, error) {
	now := time.Now()
	t := jwt.NewWithClaims(jwt.SigningMethodES256, jwt.RegisteredClaims{
		Issuer:    a.TeamID,
		Subject:   a.ClientID,
		Audience:  jwt.ClaimStrings{"https://appleid.apple.com"},
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(now.Add(5 * time.Minute)),
	})
	t.Header["kid"] = a.KeyID
	return t.SignedString(a.Key)
}

// ExchangeCode turns the one-time authorization code into a refresh token.
func (a *AppleClient) ExchangeCode(ctx context.Context, code string) (string, error) {
	var out struct {
		RefreshToken string `json:"refresh_token"`
	}
	err := a.post(ctx, "/auth/token", url.Values{"grant_type": {"authorization_code"}, "code": {code}}, &out)
	return out.RefreshToken, err
}

func (a *AppleClient) Revoke(ctx context.Context, refreshToken string) error {
	return a.post(ctx, "/auth/revoke", url.Values{"token": {refreshToken}, "token_type_hint": {"refresh_token"}}, nil)
}

func (a *AppleClient) post(ctx context.Context, path string, form url.Values, out any) error {
	secret, err := a.clientSecret()
	if err != nil {
		return err
	}
	form.Set("client_id", a.ClientID)
	form.Set("client_secret", secret)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, a.BaseURL+path, strings.NewReader(form.Encode()))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	resp, err := a.HTTP.Do(req)
	if err != nil {
		return fmt.Errorf("apple %s: %w", path, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("apple %s: %s", path, resp.Status)
	}
	if out != nil {
		return json.NewDecoder(resp.Body).Decode(out)
	}
	return nil
}
