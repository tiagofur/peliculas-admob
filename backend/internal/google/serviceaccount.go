// Package google gets OAuth access tokens for a Google service account
// (Play Developer API, FCM) without pulling in the Google SDKs.
package google

import (
	"context"
	"crypto/rsa"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const defaultTokenURL = "https://oauth2.googleapis.com/token"

// ServiceAccount signs a JWT with the account's key and trades it for an
// access token, which it caches until shortly before it expires.
type ServiceAccount struct {
	Email     string
	ProjectID string
	TokenURL  string
	Scopes    []string
	Key       *rsa.PrivateKey
	KeyID     string
	HTTP      *http.Client
	Now       func() time.Time

	mu      sync.Mutex
	token   string
	expires time.Time
}

type keyFile struct {
	Type         string `json:"type"`
	ProjectID    string `json:"project_id"`
	PrivateKeyID string `json:"private_key_id"`
	PrivateKey   string `json:"private_key"`
	ClientEmail  string `json:"client_email"`
	TokenURI     string `json:"token_uri"`
}

// ParseServiceAccount reads a service account key. raw is the JSON itself or
// a path to the JSON file. It returns nil, nil when raw is empty.
func ParseServiceAccount(raw string, scopes ...string) (*ServiceAccount, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil, nil
	}
	data := []byte(raw)
	if !strings.HasPrefix(raw, "{") {
		b, err := os.ReadFile(raw)
		if err != nil {
			return nil, fmt.Errorf("google: read service account: %w", err)
		}
		data = b
	}
	var f keyFile
	if err := json.Unmarshal(data, &f); err != nil {
		return nil, fmt.Errorf("google: service account JSON: %w", err)
	}
	if f.Type != "" && f.Type != "service_account" {
		return nil, fmt.Errorf("google: key type %q is not service_account", f.Type)
	}
	if f.ClientEmail == "" || f.PrivateKey == "" {
		return nil, errors.New("google: service account needs client_email and private_key")
	}
	key, err := jwt.ParseRSAPrivateKeyFromPEM([]byte(strings.ReplaceAll(f.PrivateKey, `\n`, "\n")))
	if err != nil {
		return nil, fmt.Errorf("google: private_key: %w", err)
	}
	tokenURL := f.TokenURI
	if tokenURL == "" {
		tokenURL = defaultTokenURL
	}
	return &ServiceAccount{
		Email: f.ClientEmail, ProjectID: f.ProjectID, TokenURL: tokenURL, Scopes: scopes,
		Key: key, KeyID: f.PrivateKeyID, HTTP: &http.Client{Timeout: 15 * time.Second},
	}, nil
}

func (s *ServiceAccount) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

// Token returns a valid access token, fetching a new one when needed.
func (s *ServiceAccount) Token(ctx context.Context) (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := s.now()
	if s.token != "" && now.Before(s.expires) {
		return s.token, nil
	}
	claims := jwt.MapClaims{
		"iss":   s.Email,
		"scope": strings.Join(s.Scopes, " "),
		"aud":   s.TokenURL,
		"iat":   now.Unix(),
		"exp":   now.Add(time.Hour).Unix(),
	}
	t := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	if s.KeyID != "" {
		t.Header["kid"] = s.KeyID
	}
	assertion, err := t.SignedString(s.Key)
	if err != nil {
		return "", err
	}
	form := url.Values{"grant_type": {"urn:ietf:params:oauth:grant-type:jwt-bearer"}, "assertion": {assertion}}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.TokenURL, strings.NewReader(form.Encode()))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	resp, err := s.HTTP.Do(req)
	if err != nil {
		return "", fmt.Errorf("google: token: %w", err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("google: token: %s %s", resp.Status, strings.TrimSpace(string(body)))
	}
	var out struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if err := json.Unmarshal(body, &out); err != nil || out.AccessToken == "" {
		return "", errors.New("google: token: empty response")
	}
	if out.ExpiresIn <= 0 {
		out.ExpiresIn = 3600
	}
	s.token = out.AccessToken
	s.expires = now.Add(time.Duration(out.ExpiresIn)*time.Second - 2*time.Minute)
	return s.token, nil
}

// Invalidate drops the cached token (after a 401).
func (s *ServiceAccount) Invalidate() {
	s.mu.Lock()
	s.token = ""
	s.mu.Unlock()
}
