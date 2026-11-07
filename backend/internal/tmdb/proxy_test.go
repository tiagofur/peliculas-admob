package tmdb

import (
	"context"
	"errors"
	"net/url"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/tiagofur/peliculas-admob/backend/internal/cache"
)

type fakeUpstream struct {
	calls  atomic.Int32
	status int
	body   string
	err    error
	delay  time.Duration
	mu     sync.Mutex
}

func (f *fakeUpstream) Fetch(ctx context.Context, _ string, _ url.Values) (int, []byte, error) {
	f.calls.Add(1)
	time.Sleep(f.delay)
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.status, []byte(f.body), f.err
}

func (f *fakeUpstream) set(status int, body string, err error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.status, f.body, f.err = status, body, err
}

type clock struct {
	mu sync.Mutex
	t  time.Time
}

func (c *clock) Now() time.Time      { c.mu.Lock(); defer c.mu.Unlock(); return c.t }
func (c *clock) Add(d time.Duration) { c.mu.Lock(); c.t = c.t.Add(d); c.mu.Unlock() }
func newClock() *clock               { return &clock{t: time.Date(2026, 11, 7, 12, 0, 0, 0, time.UTC)} }
func newProxy(up Fetcher, c *clock) *Proxy {
	return &Proxy{Memory: cache.NewMemory(100), DB: cache.NewMemory(100), Upstream: up, StaleMax: 30 * day, Now: c.Now}
}

func TestMissThenHit(t *testing.T) {
	up := &fakeUpstream{status: 200, body: `{"results":[]}`}
	p := newProxy(up, newClock())
	ctx := context.Background()

	r, err := p.Get(ctx, "/trending/movie/day", url.Values{"language": {"es-MX"}})
	if err != nil || r.Cache != Miss || r.Status != 200 {
		t.Fatalf("first: %+v %v", r, err)
	}
	r, _ = p.Get(ctx, "/trending/movie/day", url.Values{"language": {"es-MX"}, "api_key": {"x"}})
	if r.Cache != Hit {
		t.Fatalf("second should hit, got %s", r.Cache)
	}
	if up.calls.Load() != 1 {
		t.Fatalf("upstream calls = %d, want 1", up.calls.Load())
	}
}

func TestDBLayerSurvivesMemoryLoss(t *testing.T) {
	up := &fakeUpstream{status: 200, body: `{}`}
	c := newClock()
	p := newProxy(up, c)
	ctx := context.Background()
	p.Get(ctx, "/movie/popular", nil)
	p.Memory = cache.NewMemory(100) // simulates a restart
	r, _ := p.Get(ctx, "/movie/popular", nil)
	if r.Cache != Hit || up.calls.Load() != 1 {
		t.Fatalf("want HIT from db layer, got %s with %d calls", r.Cache, up.calls.Load())
	}
}

func TestStaleWhileRevalidate(t *testing.T) {
	up := &fakeUpstream{status: 200, body: `{"v":1}`}
	c := newClock()
	p := newProxy(up, c)
	ctx := context.Background()
	p.Get(ctx, "/trending/tv/day", nil)

	c.Add(2 * time.Hour) // past the 1h TTL
	up.set(200, `{"v":2}`, nil)
	r, _ := p.Get(ctx, "/trending/tv/day", nil)
	if r.Cache != Stale || string(r.Body) != `{"v":1}` {
		t.Fatalf("want old body served as STALE, got %s %s", r.Cache, r.Body)
	}
	waitFor(t, func() bool { return up.calls.Load() == 2 })
	waitFor(t, func() bool {
		r, _ := p.Get(ctx, "/trending/tv/day", nil)
		return r.Cache == Hit && string(r.Body) == `{"v":2}`
	})
}

func TestUpstreamDownServesStale(t *testing.T) {
	up := &fakeUpstream{status: 200, body: `{"ok":true}`}
	c := newClock()
	p := newProxy(up, c)
	ctx := context.Background()
	p.Get(ctx, "/movie/now_playing", nil)

	c.Add(60 * day) // beyond StaleMax: would normally refetch
	up.set(0, "", errors.New("connection refused"))
	r, err := p.Get(ctx, "/movie/now_playing", nil)
	if err != nil || r.Cache != Stale || string(r.Body) != `{"ok":true}` {
		t.Fatalf("want stale fallback, got %+v %v", r, err)
	}
}

func TestUpstreamDownNothingCached(t *testing.T) {
	up := &fakeUpstream{err: errors.New("down")}
	p := newProxy(up, newClock())
	if _, err := p.Get(context.Background(), "/movie/1", nil); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("want ErrUnavailable, got %v", err)
	}
}

func TestServerErrorsAreNotCached(t *testing.T) {
	up := &fakeUpstream{status: 503, body: `{}`}
	p := newProxy(up, newClock())
	ctx := context.Background()
	if _, err := p.Get(ctx, "/movie/1", nil); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("503 should be unavailable, got %v", err)
	}
	up.set(200, `{"status":"Released"}`, nil)
	if r, _ := p.Get(ctx, "/movie/1", nil); r.Cache != Miss {
		t.Fatalf("503 must not be cached, got %s", r.Cache)
	}
}

func TestNotFoundIsCachedBriefly(t *testing.T) {
	up := &fakeUpstream{status: 404, body: `{"status_code":34}`}
	c := newClock()
	p := newProxy(up, c)
	ctx := context.Background()
	p.Get(ctx, "/movie/999999999", nil)
	r, _ := p.Get(ctx, "/movie/999999999", nil)
	if r.Status != 404 || r.Cache != Hit || up.calls.Load() != 1 {
		t.Fatalf("404 should be cached: %+v calls=%d", r, up.calls.Load())
	}
}

func TestConcurrentMissesShareOneCall(t *testing.T) {
	up := &fakeUpstream{status: 200, body: `{}`, delay: 50 * time.Millisecond}
	p := newProxy(up, newClock())
	var wg sync.WaitGroup
	for range 50 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			p.Get(context.Background(), "/movie/popular", url.Values{"page": {"1"}})
		}()
	}
	wg.Wait()
	if n := up.calls.Load(); n != 1 {
		t.Fatalf("upstream calls = %d, want 1", n)
	}
}

func TestRejectsUnknownPath(t *testing.T) {
	up := &fakeUpstream{status: 200}
	p := newProxy(up, newClock())
	if _, err := p.Get(context.Background(), "/account", nil); !errors.Is(err, ErrNotAllowed) {
		t.Fatalf("want ErrNotAllowed, got %v", err)
	}
	if up.calls.Load() != 0 {
		t.Fatal("blocked path must not reach TMDB")
	}
}

func waitFor(t *testing.T, cond func() bool) {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		if cond() {
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatal("condition not met in time")
}
