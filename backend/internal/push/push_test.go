package push

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/tiagofur/peliculas-admob/backend/internal/db"
	"github.com/tiagofur/peliculas-admob/backend/internal/tmdb"
)

const tok = "a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90"

// fcmTok looks like a real FCM registration token: mixed case, ':' and '-'.
const fcmTok = "dQw4w9WgXcQ:APA91bHun4MxP5egoKMwt2KZFBaFUH-1RYqx_KlZ1Bc3pT7Lk9Xw0aB_CdEfGhIjKlMnOpQrStUvWxYz"

// ---- APNs client against a fake HTTP/2 server ----

func TestAPNsClient(t *testing.T) {
	key, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	var got struct {
		sync.Mutex
		proto, path, topic, pushType, collapse, auth string
		body                                         map[string]any
	}
	status, reason := http.StatusOK, ""
	srv := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		got.Lock()
		defer got.Unlock()
		got.proto, got.path = r.Proto, r.URL.Path
		got.topic, got.pushType = r.Header.Get("apns-topic"), r.Header.Get("apns-push-type")
		got.collapse, got.auth = r.Header.Get("apns-collapse-id"), r.Header.Get("authorization")
		b, _ := io.ReadAll(r.Body)
		json.Unmarshal(b, &got.body)
		w.WriteHeader(status)
		if reason != "" {
			fmt.Fprintf(w, `{"reason":%q}`, reason)
		}
	}))
	srv.EnableHTTP2 = true
	srv.StartTLS()
	defer srv.Close()

	a := &APNs{KeyID: "KEY123", TeamID: "TEAM123", Topic: "mx.creapolis.peliculas.native", Key: key,
		HTTP: srv.Client(), Hosts: map[string]string{"sandbox": srv.URL}}
	ctx := context.Background()
	err := a.Send(ctx, "sandbox", tok, Alert{Title: "The Last of Us", Body: "Nuevo episodio", ThreadID: "tv-100088",
		CollapseID: "tv-100088-s2e3", Data: map[string]any{"tv_id": 100088}})
	if err != nil {
		t.Fatal(err)
	}
	if got.proto != "HTTP/2.0" || got.path != "/3/device/"+tok || got.topic != "mx.creapolis.peliculas.native" ||
		got.pushType != "alert" || got.collapse != "tv-100088-s2e3" {
		t.Fatalf("request: %s %s %s %s %s", got.proto, got.path, got.topic, got.pushType, got.collapse)
	}
	aps := got.body["aps"].(map[string]any)
	if aps["alert"].(map[string]any)["title"] != "The Last of Us" || aps["thread-id"] != "tv-100088" || got.body["tv_id"] != float64(100088) {
		t.Fatalf("payload: %v", got.body)
	}
	bearer := strings.TrimPrefix(got.auth, "bearer ")
	parsed, err := jwt.Parse(bearer, func(*jwt.Token) (any, error) { return &key.PublicKey, nil }, jwt.WithValidMethods([]string{"ES256"}))
	if err != nil || parsed.Header["kid"] != "KEY123" || parsed.Claims.(jwt.MapClaims)["iss"] != "TEAM123" {
		t.Fatalf("provider token: %v", err)
	}
	first := got.auth
	a.Send(ctx, "sandbox", tok, Alert{Title: "x"})
	if got.auth != first {
		t.Fatal("provider token should be reused")
	}

	for _, c := range []struct {
		status int
		reason string
		dead   bool
	}{{410, "Unregistered", true}, {400, "BadDeviceToken", true}, {400, "DeviceTokenNotForTopic", true}, {500, "InternalServerError", false}, {429, "TooManyRequests", false}} {
		status, reason = c.status, c.reason
		err := a.Send(ctx, "sandbox", tok, Alert{Title: "x"})
		if errors.Is(err, ErrUnregistered) != c.dead || err == nil {
			t.Errorf("%d %s: %v", c.status, c.reason, err)
		}
	}
	if err := a.Send(ctx, "production", tok, Alert{}); err == nil {
		t.Error("unknown host must fail")
	}
	var nilClient *APNs
	if err := nilClient.Send(ctx, "sandbox", tok, Alert{}); !errors.Is(err, ErrNotConfigured) {
		t.Errorf("nil client: %v", err)
	}
}

func TestDeviceValidation(t *testing.T) {
	ok := Device{Token: strings.ToUpper(tok), Environment: "sandbox", Timezone: "America/Mexico_City"}
	if err := ok.normalize(); err != nil || ok.Token != tok || ok.Platform != "ios" {
		t.Fatalf("valid: %+v %v", ok, err)
	}
	bad := []Device{
		{Token: "../../etc", Environment: "sandbox"},
		{Token: tok, Environment: "dev"},
		{Token: tok, Environment: "sandbox", Platform: "watchos"},
		{Token: fcmTok + " /../", Platform: "android"},
		{Token: "short:token", Platform: "android"},
		{Token: fcmTok, Platform: "android", Environment: "dev"},
		{Token: fcmTok, Platform: "ios", Environment: "production"}, // FCM token is not hex
		{Token: tok, Environment: "sandbox", Timezone: "Mars/Olympus"},
	}
	for i, d := range bad {
		if err := d.normalize(); !errors.Is(err, ErrBadDevice) {
			t.Errorf("bad %d accepted", i)
		}
	}
}

func TestAndroidDeviceValidation(t *testing.T) {
	d := Device{Token: "  " + fcmTok + "\n", Platform: "android", Locale: "pt-BR"}
	if err := d.normalize(); err != nil {
		t.Fatal(err)
	}
	if d.Token != fcmTok { // case kept: FCM tokens are case-sensitive
		t.Fatalf("token changed: %q", d.Token)
	}
	if d.Environment != "production" || d.Timezone != "UTC" {
		t.Fatalf("defaults: %+v", d)
	}
}

func TestDue(t *testing.T) {
	j := &EpisodeJob{AlertHour: 18}
	// 2026-11-07 20:00 in Mexico City = 2026-11-08 02:00 UTC
	evening := time.Date(2026, 11, 8, 2, 0, 0, 0, time.UTC)
	morning := time.Date(2026, 11, 7, 15, 0, 0, 0, time.UTC) // 09:00 Mexico City
	cases := []struct {
		air, tz string
		now     time.Time
		want    bool
	}{
		{"2026-11-07", "America/Mexico_City", evening, true},  // today, after 18:00
		{"2026-11-07", "America/Mexico_City", morning, false}, // today, too early
		{"2026-11-06", "America/Mexico_City", morning, true},  // yesterday, missed
		{"2026-11-04", "America/Mexico_City", evening, false}, // too old
		{"2026-11-08", "America/Mexico_City", evening, false}, // tomorrow there (already the 8th in UTC)
		{"2026-11-08", "UTC", evening, false},                 // today in UTC but only 02:00
		{"bad", "UTC", evening, false},
	}
	for _, c := range cases {
		if got := j.due(c.air, c.tz, c.now); got != c.want {
			t.Errorf("%s %s %s: got %v", c.air, c.tz, c.now, got)
		}
	}
}

// ---- database tests ----

type fakeSender struct {
	mu   sync.Mutex
	sent []sentAlert
	fail map[string]error
}

type sentAlert struct {
	token string
	al    Alert
}

func (f *fakeSender) Send(_ context.Context, _, token string, al Alert) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if err := f.fail[token]; err != nil {
		return err
	}
	f.sent = append(f.sent, sentAlert{token, al})
	return nil
}

func (f *fakeSender) count() int { f.mu.Lock(); defer f.mu.Unlock(); return len(f.sent) }

type fakeShows map[string]string // "tvID/language" -> body

func (f fakeShows) Get(_ context.Context, path string, q url.Values) (tmdb.Result, error) {
	body, ok := f[strings.TrimPrefix(path, "/tv/")+"/"+q.Get("language")]
	if !ok {
		return tmdb.Result{Status: 404, Body: []byte(`{}`)}, nil
	}
	return tmdb.Result{Status: 200, Body: []byte(body)}, nil
}

func setup(t *testing.T) (*Service, *fakeSender, string) {
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
	if _, err := pool.Exec(ctx, `TRUNCATE users, entitlements CASCADE`); err != nil {
		t.Fatal(err)
	}
	var user string
	pool.QueryRow(ctx, `INSERT INTO users (email) VALUES ('a@x.com') RETURNING id`).Scan(&user)
	sender := &fakeSender{fail: map[string]error{}}
	return &Service{DB: pool, Sender: sender}, sender, user
}

func TestRegisterAndTestPush(t *testing.T) {
	s, sender, user := setup(t)
	ctx := context.Background()
	if err := s.Register(ctx, user, Device{Token: tok, Environment: "sandbox", Locale: "en-US"}); err != nil {
		t.Fatal(err)
	}
	n, err := s.SendTest(ctx, user)
	if err != nil || n != 1 || !strings.HasPrefix(sender.sent[0].al.Body, "All set") {
		t.Fatalf("test push: %d %v %+v", n, err, sender.sent)
	}

	// The same phone signs into another account: the token moves.
	var other string
	s.DB.QueryRow(ctx, `INSERT INTO users (email) VALUES ('b@x.com') RETURNING id`).Scan(&other)
	s.Register(ctx, other, Device{Token: tok, Environment: "sandbox"})
	if n, _ := s.SendTest(ctx, user); n != 0 {
		t.Fatal("old account must not get alerts")
	}

	// A dead token is disabled after APNs rejects it.
	sender.fail[tok] = ErrUnregistered
	s.SendTest(ctx, other)
	var disabled bool
	s.DB.QueryRow(ctx, `SELECT disabled_at IS NOT NULL FROM devices WHERE token = $1`, tok).Scan(&disabled)
	if !disabled {
		t.Fatal("dead token should be disabled")
	}
	// Registering again revives it.
	s.Register(ctx, other, Device{Token: tok, Environment: "sandbox"})
	s.DB.QueryRow(ctx, `SELECT disabled_at IS NOT NULL FROM devices WHERE token = $1`, tok).Scan(&disabled)
	if disabled {
		t.Fatal("re-register should re-enable")
	}
	if err := s.Unregister(ctx, other, strings.ToUpper(tok)); err != nil {
		t.Fatal(err)
	}
	if n, _ := s.SendTest(ctx, other); n != 0 {
		t.Fatal("unregistered device got an alert")
	}
}

func showBody(name, air string, season, ep int, epName string) string {
	return fmt.Sprintf(`{"name":%q,"last_episode_to_air":{"air_date":%q,"season_number":%d,"episode_number":%d,"name":%q}}`,
		name, air, season, ep, epName)
}

func TestEpisodeJob(t *testing.T) {
	s, sender, user := setup(t)
	ctx := context.Background()
	now := time.Date(2026, 11, 8, 2, 0, 0, 0, time.UTC) // 20:00 on the 7th in Mexico City
	shows := fakeShows{
		"1399/es-MX": showBody("Juego de tronos", "2026-11-07", 9, 1, "Invierno"),
		"1399/en-US": showBody("Game of Thrones", "2026-11-07", 9, 1, "Winter"),
		"2000/es-MX": showBody("Vieja", "2026-10-01", 1, 8, ""),
		"3000/es-MX": showBody("Vista", "2026-11-07", 2, 2, ""),
	}
	job := &EpisodeJob{Push: s, Shows: shows, ProOnly: true, AlertHour: 18, Now: func() time.Time { return now }}

	s.Register(ctx, user, Device{Token: tok, Environment: "sandbox", Locale: "es-MX", Timezone: "America/Mexico_City"})
	enTok := strings.Repeat("b", 64)
	s.Register(ctx, user, Device{Token: enTok, Environment: "production", Locale: "en-GB", Timezone: "America/Mexico_City"})
	s.DB.Exec(ctx, `INSERT INTO library_items (user_id, kind, media_type, tmdb_id, updated_at) VALUES
		($1, 'watchlist', 'tv', 1399, now()), ($1, 'favorite', 'tv', 2000, now()), ($1, 'favorite', 'movie', 550, now())`, user)
	s.DB.Exec(ctx, `INSERT INTO watched_episodes (user_id, tv_id, season, episode, watched_at, updated_at) VALUES
		($1, 3000, 2, 2, now(), now())`, user) // follows 3000 but already saw the new episode

	// Pro only and the user is not Pro: nothing.
	if n, err := job.Run(ctx); err != nil || n != 0 {
		t.Fatalf("non-Pro: %d %v", n, err)
	}
	s.DB.Exec(ctx, `INSERT INTO entitlements (original_transaction_id, user_id, product_id, environment, purchased_at, last_signed_at)
		VALUES ('1', $1, 'peliculas_pro_lifetime', 'Sandbox', now(), now())`, user)

	n, err := job.Run(ctx)
	if err != nil || n != 1 || sender.count() != 2 {
		t.Fatalf("run: alerted=%d err=%v sent=%+v", n, err, sender.sent)
	}
	bodies := map[string]Alert{}
	for _, a := range sender.sent {
		bodies[a.token] = a.al
	}
	if es := bodies[tok]; es.Title != "Juego de tronos" || es.Body != "Nuevo episodio: T9·E1 «Invierno»" || es.Data["url"] != "peliculas://serie/1399" {
		t.Fatalf("es alert: %+v", es)
	}
	if en := bodies[enTok]; en.Title != "Game of Thrones" || en.Body != "New episode: S9E1 “Winter”" {
		t.Fatalf("en alert: %+v", en)
	}

	// Next run: already alerted, nothing new.
	if n, _ := job.Run(ctx); n != 0 || sender.count() != 2 {
		t.Fatalf("second run resent: %d", n)
	}
}

func TestEpisodeJobRetriesWhenNothingDelivered(t *testing.T) {
	s, sender, user := setup(t)
	ctx := context.Background()
	now := time.Date(2026, 11, 7, 20, 0, 0, 0, time.UTC)
	job := &EpisodeJob{Push: s, Shows: fakeShows{"1399/es-MX": showBody("GoT", "2026-11-07", 1, 1, "")},
		AlertHour: 18, Now: func() time.Time { return now }}
	s.Register(ctx, user, Device{Token: tok, Environment: "sandbox"})
	s.DB.Exec(ctx, `INSERT INTO library_items (user_id, kind, media_type, tmdb_id, updated_at) VALUES ($1, 'watchlist', 'tv', 1399, now())`, user)

	sender.fail[tok] = errors.New("apns 503")
	if n, _ := job.Run(ctx); n != 0 {
		t.Fatal("failed delivery must not count")
	}
	delete(sender.fail, tok)
	if n, _ := job.Run(ctx); n != 1 {
		t.Fatal("next run should retry")
	}
}
