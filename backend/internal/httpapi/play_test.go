package httpapi

import (
	"encoding/base64"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/tiagofur/peliculas-admob/backend/internal/play"
)

// pubsubPush wraps an RTDN payload the way Pub/Sub push delivers it.
func pubsubPush(payload string) string {
	return `{"message":{"data":"` + base64.StdEncoding.EncodeToString([]byte(payload)) +
		`","messageId":"1"},"subscription":"projects/p/subscriptions/play-rtdn"}`
}

func TestPlayNotificationRoute(t *testing.T) {
	s := &Server{Log: slog.New(slog.NewTextHandler(io.Discard, nil))}
	ts := httptest.NewServer(s.Handler())
	defer ts.Close()
	post := func(path, body string) int {
		resp, err := http.Post(ts.URL+path, "application/json", strings.NewReader(body))
		if err != nil {
			t.Fatal(err)
		}
		resp.Body.Close()
		return resp.StatusCode
	}
	test := pubsubPush(`{"version":"1.0","packageName":"mx.creapolis.peliculas.android","testNotification":{"version":"1.0"}}`)

	if code := post("/v1/play/notifications", test); code != http.StatusServiceUnavailable {
		t.Fatalf("disabled: %d", code)
	}
	// The test notification touches neither the database nor Google.
	s.Play = &play.Service{PackageName: "mx.creapolis.peliculas.android"}
	s.RTDNAuth = RTDNAuth{Token: "s3cret"}
	if code := post("/v1/play/notifications", test); code != http.StatusUnauthorized {
		t.Fatalf("no token: %d", code)
	}
	if code := post("/v1/play/notifications?token=wrong", test); code != http.StatusUnauthorized {
		t.Fatalf("wrong token: %d", code)
	}
	if code := post("/v1/play/notifications?token=s3cret", test); code != http.StatusNoContent {
		t.Fatalf("valid: %d", code)
	}
	if code := post("/v1/play/notifications?token=s3cret", `{nope`); code != http.StatusBadRequest {
		t.Fatalf("bad json: %d", code)
	}
}
