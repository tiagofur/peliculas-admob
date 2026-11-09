package push

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// FCMScope is the OAuth scope the service account needs.
const FCMScope = "https://www.googleapis.com/auth/firebase.messaging"

// TokenSource gives OAuth access tokens (google.ServiceAccount).
type TokenSource interface {
	Token(ctx context.Context) (string, error)
	Invalidate()
}

// FCM sends Android alerts through the Firebase Cloud Messaging HTTP v1 API.
type FCM struct {
	ProjectID string
	Auth      TokenSource
	ChannelID string // Android notification channel (the app creates it)
	BaseURL   string // https://fcm.googleapis.com; tests use a fake
	HTTP      *http.Client
}

func NewFCM(projectID string, auth TokenSource) *FCM {
	return &FCM{ProjectID: projectID, Auth: auth, ChannelID: "peliculas_episodes",
		BaseURL: "https://fcm.googleapis.com", HTTP: &http.Client{Timeout: 15 * time.Second}}
}

// Send ignores environment: FCM has no sandbox.
func (f *FCM) Send(ctx context.Context, _, deviceToken string, al Alert) error {
	if f == nil {
		return ErrNotConfigured
	}
	// Data values must be strings in FCM.
	data := map[string]string{}
	for k, v := range al.Data {
		data[k] = fmt.Sprint(v)
	}
	android := map[string]any{"priority": "high"}
	notif := map[string]any{"channel_id": f.ChannelID}
	if al.CollapseID != "" {
		android["collapse_key"] = al.CollapseID
		notif["tag"] = al.CollapseID // replaces an older alert with the same tag
	}
	android["notification"] = notif
	msg := map[string]any{
		"token":        deviceToken,
		"notification": map[string]string{"title": al.Title, "body": al.Body},
		"android":      android,
	}
	if len(data) > 0 {
		msg["data"] = data
	}
	body, err := json.Marshal(map[string]any{"message": msg})
	if err != nil {
		return err
	}
	u := f.BaseURL + "/v1/projects/" + url.PathEscape(f.ProjectID) + "/messages:send"
	for attempt := 0; ; attempt++ {
		bearer, err := f.Auth.Token(ctx)
		if err != nil {
			return fmt.Errorf("push: fcm auth: %w", err)
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, u, bytes.NewReader(body))
		if err != nil {
			return err
		}
		req.Header.Set("Authorization", "Bearer "+bearer)
		req.Header.Set("Content-Type", "application/json")
		resp, err := f.HTTP.Do(req)
		if err != nil {
			return fmt.Errorf("push: %w", err)
		}
		raw, _ := io.ReadAll(io.LimitReader(resp.Body, 8192))
		resp.Body.Close()
		if resp.StatusCode == http.StatusOK {
			return nil
		}
		if resp.StatusCode == http.StatusUnauthorized && attempt == 0 {
			f.Auth.Invalidate()
			continue
		}
		code, message := fcmError(raw)
		if fcmDeadToken(code, message) {
			return fmt.Errorf("%w (%s)", ErrUnregistered, code)
		}
		return fmt.Errorf("push: fcm %d %s %s", resp.StatusCode, code, message)
	}
}

// fcmError reads the FcmError code (UNREGISTERED, ...) from an error body.
func fcmError(raw []byte) (code, message string) {
	var e struct {
		Error struct {
			Status  string `json:"status"`
			Message string `json:"message"`
			Details []struct {
				Type      string `json:"@type"`
				ErrorCode string `json:"errorCode"`
			} `json:"details"`
		} `json:"error"`
	}
	_ = json.Unmarshal(raw, &e)
	code = e.Error.Status
	for _, d := range e.Error.Details {
		if strings.HasSuffix(d.Type, "FcmError") && d.ErrorCode != "" {
			code = d.ErrorCode
		}
	}
	return code, e.Error.Message
}

// fcmDeadToken: the app was uninstalled, the token expired, or it belongs to
// another Firebase project. A bad payload (also INVALID_ARGUMENT) must not
// disable every device, so INVALID_ARGUMENT counts only when about the token.
func fcmDeadToken(code, message string) bool {
	switch code {
	case "UNREGISTERED", "SENDER_ID_MISMATCH":
		return true
	case "INVALID_ARGUMENT":
		return strings.Contains(strings.ToLower(message), "registration token")
	}
	return false
}
