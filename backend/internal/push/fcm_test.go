package push

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
)

type fakeAuth struct {
	mu          sync.Mutex
	n           int
	invalidated int
}

func (f *fakeAuth) Token(context.Context) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.n++
	return "access-" + string(rune('0'+f.n)), nil
}

func (f *fakeAuth) Invalidate() { f.mu.Lock(); f.invalidated++; f.mu.Unlock() }

func TestFCMClient(t *testing.T) {
	var (
		mu       sync.Mutex
		path     string
		auths    []string
		body     map[string]any
		status   = http.StatusOK
		respBody = `{"name":"projects/p/messages/1"}`
		reject   int // answer 401 this many times first
	)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		defer mu.Unlock()
		path = r.URL.Path
		auths = append(auths, r.Header.Get("Authorization"))
		if reject > 0 {
			reject--
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		b, _ := io.ReadAll(r.Body)
		json.Unmarshal(b, &body)
		w.WriteHeader(status)
		io.WriteString(w, respBody)
	}))
	defer srv.Close()

	auth := &fakeAuth{}
	f := NewFCM("peliculas-app", auth)
	f.BaseURL, f.HTTP = srv.URL, srv.Client()
	ctx := context.Background()

	err := f.Send(ctx, "production", fcmTok, Alert{Title: "The Last of Us", Body: "Nuevo episodio: T2·E3",
		ThreadID: "tv-100088", CollapseID: "tv-100088-s2e3",
		Data: map[string]any{"tv_id": 100088, "url": "peliculas://serie/100088"}})
	if err != nil {
		t.Fatal(err)
	}
	if path != "/v1/projects/peliculas-app/messages:send" || auths[0] != "Bearer access-1" {
		t.Fatalf("request: %s %v", path, auths)
	}
	msg := body["message"].(map[string]any)
	notif := msg["notification"].(map[string]any)
	data := msg["data"].(map[string]any)
	android := msg["android"].(map[string]any)
	an := android["notification"].(map[string]any)
	if msg["token"] != fcmTok || notif["title"] != "The Last of Us" || data["tv_id"] != "100088" ||
		data["url"] != "peliculas://serie/100088" || android["priority"] != "high" ||
		android["collapse_key"] != "tv-100088-s2e3" || an["channel_id"] != "peliculas_episodes" || an["tag"] != "tv-100088-s2e3" {
		t.Fatalf("payload: %v", body)
	}

	// An expired access token is refreshed once.
	reject = 1
	if err := f.Send(ctx, "production", fcmTok, Alert{Title: "x"}); err != nil {
		t.Fatal(err)
	}
	if auth.invalidated != 1 {
		t.Fatal("401 should drop the cached access token")
	}

	// Dead tokens: the app was uninstalled.
	status = http.StatusNotFound
	respBody = `{"error":{"code":404,"status":"NOT_FOUND","message":"Requested entity was not found.",
		"details":[{"@type":"type.googleapis.com/google.firebase.fcm.v1.FcmError","errorCode":"UNREGISTERED"}]}}`
	if err := f.Send(ctx, "production", fcmTok, Alert{Title: "x"}); !errors.Is(err, ErrUnregistered) {
		t.Fatalf("unregistered: %v", err)
	}
	status = http.StatusBadRequest
	respBody = `{"error":{"code":400,"status":"INVALID_ARGUMENT","message":"The registration token is not a valid FCM registration token"}}`
	if err := f.Send(ctx, "production", fcmTok, Alert{Title: "x"}); !errors.Is(err, ErrUnregistered) {
		t.Fatalf("invalid token: %v", err)
	}
	// A bad payload must not disable the device.
	respBody = `{"error":{"code":400,"status":"INVALID_ARGUMENT","message":"Invalid value at 'message.android.ttl'"}}`
	if err := f.Send(ctx, "production", fcmTok, Alert{Title: "x"}); err == nil || errors.Is(err, ErrUnregistered) {
		t.Fatalf("bad payload: %v", err)
	}
	status, respBody = http.StatusServiceUnavailable, `{"error":{"status":"UNAVAILABLE"}}`
	if err := f.Send(ctx, "production", fcmTok, Alert{Title: "x"}); err == nil || errors.Is(err, ErrUnregistered) || !strings.Contains(err.Error(), "503") {
		t.Fatalf("unavailable: %v", err)
	}

	var nilFCM *FCM
	if err := nilFCM.Send(ctx, "", fcmTok, Alert{}); !errors.Is(err, ErrNotConfigured) {
		t.Errorf("nil client: %v", err)
	}
}

// ---- database: android devices go to FCM, iOS devices to APNs ----

func TestAndroidDevicesUseFCM(t *testing.T) {
	s, apns, user := setup(t)
	fcm := &fakeSender{fail: map[string]error{}}
	s.FCM = fcm
	ctx := context.Background()
	if err := s.Register(ctx, user, Device{Token: tok, Environment: "sandbox", Locale: "en-US"}); err != nil {
		t.Fatal(err)
	}
	if err := s.Register(ctx, user, Device{Token: fcmTok, Platform: "android", Locale: "pt-BR"}); err != nil {
		t.Fatal(err)
	}
	n, err := s.SendTest(ctx, user)
	if err != nil || n != 2 || apns.count() != 1 || fcm.count() != 1 {
		t.Fatalf("sent %d (%v): apns %d fcm %d", n, err, apns.count(), fcm.count())
	}
	if fcm.sent[0].token != fcmTok || !strings.HasPrefix(fcm.sent[0].al.Body, "Tudo pronto") {
		t.Fatalf("fcm got %+v", fcm.sent[0])
	}

	// Without FCM configured, Android devices are skipped, not sent to APNs.
	s.FCM = nil
	if n, _ := s.SendTest(ctx, user); n != 1 || apns.count() != 2 {
		t.Fatalf("no fcm: sent %d, apns %d", n, apns.count())
	}

	// A dead FCM token is disabled; unregister matches the exact case.
	s.FCM = fcm
	fcm.fail[fcmTok] = ErrUnregistered
	s.SendTest(ctx, user)
	var disabled bool
	s.DB.QueryRow(ctx, `SELECT disabled_at IS NOT NULL FROM devices WHERE token = $1`, fcmTok).Scan(&disabled)
	if !disabled {
		t.Fatal("dead FCM token should be disabled")
	}
	if err := s.Unregister(ctx, user, fcmTok); err != nil {
		t.Fatal(err)
	}
	var left int
	s.DB.QueryRow(ctx, `SELECT count(*) FROM devices WHERE user_id = $1`, user).Scan(&left)
	if left != 1 {
		t.Fatalf("devices left: %d", left)
	}
}
