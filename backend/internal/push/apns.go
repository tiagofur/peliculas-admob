// Package push registers devices and sends APNs alerts, including the hourly
// "new episode" job.
package push

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

var (
	// ErrUnregistered means the token is dead: stop sending to it.
	ErrUnregistered  = errors.New("push: device token is no longer valid")
	ErrNotConfigured = errors.New("push: APNs not configured")
)

// Alert is one visible notification.
type Alert struct {
	Title      string
	Body       string
	ThreadID   string         // groups alerts for the same show
	CollapseID string         // replaces an older alert with the same ID
	Data       map[string]any // custom keys for the app (deep link etc.)
}

// APNs sends alerts over HTTP/2 with token (JWT) authentication.
type APNs struct {
	KeyID  string
	TeamID string
	Topic  string // the app bundle ID
	Key    *ecdsa.PrivateKey
	HTTP   *http.Client
	// Hosts by environment; tests point them at a fake server.
	Hosts map[string]string

	mu      sync.Mutex
	jwt     string
	jwtMade time.Time
}

// NewAPNs returns nil when the APNs key is not configured.
func NewAPNs(keyID, teamID, topic, privateKeyPEM string) (*APNs, error) {
	if keyID == "" || teamID == "" || topic == "" || privateKeyPEM == "" {
		return nil, nil
	}
	key, err := jwt.ParseECPrivateKeyFromPEM([]byte(strings.ReplaceAll(privateKeyPEM, `\n`, "\n")))
	if err != nil {
		return nil, fmt.Errorf("push: APNS_PRIVATE_KEY: %w", err)
	}
	return &APNs{
		KeyID: keyID, TeamID: teamID, Topic: topic, Key: key,
		HTTP: &http.Client{Timeout: 15 * time.Second}, // Go negotiates HTTP/2 over TLS
		Hosts: map[string]string{
			"production": "https://api.push.apple.com",
			"sandbox":    "https://api.sandbox.push.apple.com",
		},
	}, nil
}

// token reuses the provider JWT for 50 minutes; Apple rejects ones older than
// an hour and throttles if they change more often than every 20 minutes.
func (a *APNs) token() (string, error) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.jwt != "" && time.Since(a.jwtMade) < 50*time.Minute {
		return a.jwt, nil
	}
	t := jwt.NewWithClaims(jwt.SigningMethodES256, jwt.MapClaims{"iss": a.TeamID, "iat": time.Now().Unix()})
	t.Header["kid"] = a.KeyID
	s, err := t.SignedString(a.Key)
	if err != nil {
		return "", err
	}
	a.jwt, a.jwtMade = s, time.Now()
	return s, nil
}

func (a *APNs) Send(ctx context.Context, environment, deviceToken string, al Alert) error {
	if a == nil {
		return ErrNotConfigured
	}
	host, ok := a.Hosts[environment]
	if !ok {
		return fmt.Errorf("push: unknown environment %q", environment)
	}
	payload := map[string]any{}
	for k, v := range al.Data {
		payload[k] = v
	}
	aps := map[string]any{"alert": map[string]string{"title": al.Title, "body": al.Body}, "sound": "default"}
	if al.ThreadID != "" {
		aps["thread-id"] = al.ThreadID
	}
	payload["aps"] = aps
	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	bearer, err := a.token()
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, host+"/3/device/"+deviceToken, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("authorization", "bearer "+bearer)
	req.Header.Set("apns-topic", a.Topic)
	req.Header.Set("apns-push-type", "alert")
	req.Header.Set("apns-priority", "10")
	if al.CollapseID != "" {
		req.Header.Set("apns-collapse-id", al.CollapseID)
	}
	resp, err := a.HTTP.Do(req)
	if err != nil {
		return fmt.Errorf("push: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusOK {
		return nil
	}
	var reason struct {
		Reason string `json:"reason"`
	}
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
	_ = json.Unmarshal(raw, &reason)
	if resp.StatusCode == http.StatusGone || reason.Reason == "BadDeviceToken" || reason.Reason == "Unregistered" ||
		reason.Reason == "DeviceTokenNotForTopic" {
		return fmt.Errorf("%w (%s)", ErrUnregistered, reason.Reason)
	}
	if reason.Reason == "ExpiredProviderToken" {
		a.mu.Lock()
		a.jwt = ""
		a.mu.Unlock()
	}
	return fmt.Errorf("push: apns %d %s", resp.StatusCode, reason.Reason)
}
