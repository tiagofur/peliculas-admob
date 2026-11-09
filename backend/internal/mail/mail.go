// Package mail sends transactional email (password reset codes) through Resend.
package mail

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"time"
)

// ErrNotConfigured means no RESEND_API_KEY: the API still answers, nothing is sent.
var ErrNotConfigured = errors.New("mail: not configured")

// Message is one plain-text + HTML email.
type Message struct {
	To      string
	Subject string
	Text    string
	HTML    string
}

// Sender delivers a Message. Tests swap in a fake.
type Sender interface {
	Send(ctx context.Context, m Message) error
}

// Resend talks to https://resend.com/docs/api-reference/emails/send-email.
type Resend struct {
	APIKey  string
	From    string // "Películas <no-reply@creapolis.dev>"; the domain must be verified in Resend
	BaseURL string // tests only; default https://api.resend.com
	HTTP    *http.Client
}

func (r *Resend) Send(ctx context.Context, m Message) error {
	if r == nil || r.APIKey == "" {
		return ErrNotConfigured
	}
	body, err := json.Marshal(map[string]any{
		"from":    r.From,
		"to":      []string{m.To},
		"subject": m.Subject,
		"text":    m.Text,
		"html":    m.HTML,
	})
	if err != nil {
		return err
	}
	base := r.BaseURL
	if base == "" {
		base = "https://api.resend.com"
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, base+"/emails", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+r.APIKey)
	req.Header.Set("Content-Type", "application/json")
	client := r.HTTP
	if client == nil {
		client = &http.Client{Timeout: 15 * time.Second}
	}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		msg, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return fmt.Errorf("mail: resend %d: %s", resp.StatusCode, msg)
	}
	return nil
}
