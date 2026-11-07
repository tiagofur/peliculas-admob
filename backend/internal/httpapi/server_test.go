package httpapi

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"

	"github.com/tiagofur/peliculas-admob/backend/internal/cache"
	"github.com/tiagofur/peliculas-admob/backend/internal/tmdb"
)

type stubUpstream struct{ calls int }

func (s *stubUpstream) Fetch(context.Context, string, url.Values) (int, []byte, error) {
	s.calls++
	return 200, []byte(`{"id":550}`), nil
}

func newTestServer(t *testing.T) (*httptest.Server, *stubUpstream) {
	up := &stubUpstream{}
	s := &Server{
		TMDB: &tmdb.Proxy{Memory: cache.NewMemory(10), Upstream: up, StaleMax: 1},
		Log:  slog.New(slog.NewTextHandler(io.Discard, nil)),
	}
	ts := httptest.NewServer(s.Handler())
	t.Cleanup(ts.Close)
	return ts, up
}

func TestTMDBRoute(t *testing.T) {
	ts, up := newTestServer(t)
	for i, want := range []string{tmdb.Miss, tmdb.Hit} {
		res, err := http.Get(ts.URL + "/v1/tmdb/movie/550?language=es-MX")
		if err != nil {
			t.Fatal(err)
		}
		body, _ := io.ReadAll(res.Body)
		res.Body.Close()
		if res.StatusCode != 200 || string(body) != `{"id":550}` || res.Header.Get("X-Cache") != want {
			t.Fatalf("call %d: status=%d cache=%s body=%s", i, res.StatusCode, res.Header.Get("X-Cache"), body)
		}
		if res.Header.Get("Content-Type") != "application/json; charset=utf-8" {
			t.Fatalf("content type %q", res.Header.Get("Content-Type"))
		}
	}
	if up.calls != 1 {
		t.Fatalf("upstream calls = %d", up.calls)
	}
}

func TestTMDBRouteRejectsUnknownPath(t *testing.T) {
	ts, up := newTestServer(t)
	res, err := http.Get(ts.URL + "/v1/tmdb/account")
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	if res.StatusCode != http.StatusNotFound || up.calls != 0 {
		t.Fatalf("status=%d calls=%d", res.StatusCode, up.calls)
	}
}

func TestHealth(t *testing.T) {
	ts, _ := newTestServer(t)
	res, err := http.Get(ts.URL + "/healthz")
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	if res.StatusCode != 200 {
		t.Fatalf("status %d", res.StatusCode)
	}
}

func TestRateLimit(t *testing.T) {
	l := newIPLimiter(1, 2)
	if !l.allow("1.1.1.1") || !l.allow("1.1.1.1") {
		t.Fatal("burst should pass")
	}
	if l.allow("1.1.1.1") {
		t.Fatal("third request should be limited")
	}
	if !l.allow("2.2.2.2") {
		t.Fatal("other IPs are independent")
	}
}
