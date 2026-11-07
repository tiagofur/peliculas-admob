package tmdb

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"net/url"
	"time"

	"golang.org/x/sync/singleflight"

	"github.com/tiagofur/peliculas-admob/backend/internal/cache"
)

// Cache states sent back in the X-Cache header.
const (
	Hit   = "HIT"
	Stale = "STALE"
	Miss  = "MISS"
)

var (
	ErrNotAllowed  = errors.New("tmdb: path not allowed")
	ErrUnavailable = errors.New("tmdb: upstream unavailable and nothing cached")
)

// Result is what the HTTP layer sends to the app.
type Result struct {
	Status int
	Body   []byte
	Cache  string
	MaxAge time.Duration
}

// Proxy answers from memory, then Postgres, then TMDB.
type Proxy struct {
	Memory   cache.Store
	DB       cache.Store // optional
	Upstream Fetcher
	StaleMax time.Duration // how long an expired entry may still be served
	Now      func() time.Time
	Log      *slog.Logger

	group singleflight.Group
}

func (p *Proxy) now() time.Time {
	if p.Now != nil {
		return p.Now()
	}
	return time.Now()
}

func (p *Proxy) Get(ctx context.Context, path string, rawQuery url.Values) (Result, error) {
	ttl, ok := Match(path)
	if !ok {
		return Result{}, ErrNotAllowed
	}
	q := Normalize(rawQuery)
	key := CacheKey(path, q)
	now := p.now()

	cached, found := p.lookup(ctx, key)
	if found && now.Before(cached.ExpiresAt) {
		return result(cached, Hit, now), nil
	}
	if found && now.Before(cached.FetchedAt.Add(p.StaleMax)) {
		go p.refresh(key, path, q, ttl)
		return result(cached, Stale, now), nil
	}

	e, err := p.fetch(ctx, key, path, q, ttl)
	if err != nil {
		if found { // TMDB down: an old answer beats an error
			return result(cached, Stale, now), nil
		}
		return Result{}, err
	}
	return result(e, Miss, now), nil
}

func result(e cache.Entry, state string, now time.Time) Result {
	return Result{Status: e.Status, Body: e.Body, Cache: state, MaxAge: max(e.ExpiresAt.Sub(now), 0)}
}

func (p *Proxy) lookup(ctx context.Context, key string) (cache.Entry, bool) {
	if e, ok, _ := p.Memory.Get(ctx, key); ok {
		return e, true
	}
	if p.DB == nil {
		return cache.Entry{}, false
	}
	e, ok, err := p.DB.Get(ctx, key)
	if err != nil {
		p.logger().Warn("cache db get", "key", key, "err", err)
		return cache.Entry{}, false
	}
	if ok {
		_ = p.Memory.Set(ctx, key, e)
	}
	return e, ok
}

func (p *Proxy) refresh(key, path string, q url.Values, ttl ttlFunc) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if _, err := p.fetch(ctx, key, path, q, ttl); err != nil {
		p.logger().Warn("tmdb background refresh", "key", key, "err", err)
	}
}

// fetch makes one upstream call per key, however many requests wait on it.
func (p *Proxy) fetch(ctx context.Context, key, path string, q url.Values, ttl ttlFunc) (cache.Entry, error) {
	v, err, _ := p.group.Do(key, func() (any, error) {
		// Detached so one cancelled client does not fail everyone sharing the call.
		fctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 15*time.Second)
		defer cancel()
		status, body, err := p.Upstream.Fetch(fctx, path, q)
		if err != nil {
			return nil, errors.Join(ErrUnavailable, err)
		}
		now := p.now()
		e := cache.Entry{Status: status, Body: body, FetchedAt: now}
		switch {
		case status == http.StatusOK:
			e.ExpiresAt = now.Add(ttl(body, now))
		case status == http.StatusNotFound:
			e.ExpiresAt = now.Add(NotFoundTTL)
		case status == http.StatusTooManyRequests || status >= 500:
			return nil, errors.Join(ErrUnavailable, errors.New(http.StatusText(status)))
		default: // other 4xx: pass through, never cache
			return e, nil
		}
		p.store(fctx, key, e)
		return e, nil
	})
	if err != nil {
		return cache.Entry{}, err
	}
	return v.(cache.Entry), nil
}

func (p *Proxy) store(ctx context.Context, key string, e cache.Entry) {
	_ = p.Memory.Set(ctx, key, e)
	if p.DB != nil {
		if err := p.DB.Set(ctx, key, e); err != nil {
			p.logger().Warn("cache db set", "key", key, "err", err)
		}
	}
}

func (p *Proxy) logger() *slog.Logger {
	if p.Log != nil {
		return p.Log
	}
	return slog.Default()
}
