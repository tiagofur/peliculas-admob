// Package httpapi wires HTTP routes and middleware.
package httpapi

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"golang.org/x/time/rate"

	"github.com/tiagofur/peliculas-admob/backend/internal/tmdb"
)

type Server struct {
	TMDB       *tmdb.Proxy
	Log        *slog.Logger
	TrustProxy bool
	Ready      func(context.Context) error // optional readiness check (DB ping)
}

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", s.health)
	mux.HandleFunc("GET /v1/tmdb/{path...}", s.tmdb)

	limiter := newIPLimiter(20, 40)
	return s.recoverer(s.logRequests(limiter.middleware(s.clientIP, mux)))
}

func (s *Server) health(w http.ResponseWriter, r *http.Request) {
	if s.Ready != nil {
		if err := s.Ready(r.Context()); err != nil {
			http.Error(w, "db unavailable", http.StatusServiceUnavailable)
			return
		}
	}
	w.Write([]byte("ok"))
}

func (s *Server) tmdb(w http.ResponseWriter, r *http.Request) {
	path := "/" + r.PathValue("path")
	res, err := s.TMDB.Get(r.Context(), path, r.URL.Query())
	switch {
	case errors.Is(err, tmdb.ErrNotAllowed):
		writeError(w, http.StatusNotFound, "not_found")
		return
	case err != nil:
		s.Log.Error("tmdb proxy", "path", path, "err", err)
		writeError(w, http.StatusBadGateway, "tmdb_unavailable")
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("X-Cache", res.Cache)
	// Let the device keep it a little; the server cache does the heavy lifting.
	w.Header().Set("Cache-Control", fmt.Sprintf("private, max-age=%d", int(min(res.MaxAge, 5*time.Minute).Seconds())))
	w.WriteHeader(res.Status)
	w.Write(res.Body)
}

func writeError(w http.ResponseWriter, status int, code string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	fmt.Fprintf(w, `{"error":%q}`, code)
}

// clientIP uses the last X-Forwarded-For hop (the one Caddy appended) only
// when we sit behind our own proxy; otherwise the header is ignored.
func (s *Server) clientIP(r *http.Request) string {
	if s.TrustProxy {
		if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
			parts := strings.Split(xff, ",")
			return strings.TrimSpace(parts[len(parts)-1])
		}
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

type statusWriter struct {
	http.ResponseWriter
	status int
}

func (w *statusWriter) WriteHeader(code int) {
	w.status = code
	w.ResponseWriter.WriteHeader(code)
}

func (s *Server) logRequests(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		sw := &statusWriter{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(sw, r)
		s.Log.Info("http", "method", r.Method, "path", r.URL.Path, "status", sw.status,
			"cache", sw.Header().Get("X-Cache"), "ms", time.Since(start).Milliseconds())
	})
}

func (s *Server) recoverer(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if v := recover(); v != nil {
				s.Log.Error("panic", "path", r.URL.Path, "panic", v)
				writeError(w, http.StatusInternalServerError, "internal")
			}
		}()
		next.ServeHTTP(w, r)
	})
}

// ipLimiter is a per-IP token bucket; idle buckets are dropped every few minutes.
type ipLimiter struct {
	mu      sync.Mutex
	r       rate.Limit
	burst   int
	buckets map[string]*bucket
	swept   time.Time
}

type bucket struct {
	lim  *rate.Limiter
	seen time.Time
}

func newIPLimiter(perSec float64, burst int) *ipLimiter {
	return &ipLimiter{r: rate.Limit(perSec), burst: burst, buckets: map[string]*bucket{}, swept: time.Now()}
}

func (l *ipLimiter) allow(ip string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := time.Now()
	if now.Sub(l.swept) > 5*time.Minute {
		for k, b := range l.buckets {
			if now.Sub(b.seen) > 10*time.Minute {
				delete(l.buckets, k)
			}
		}
		l.swept = now
	}
	b, ok := l.buckets[ip]
	if !ok {
		b = &bucket{lim: rate.NewLimiter(l.r, l.burst)}
		l.buckets[ip] = b
	}
	b.seen = now
	return b.lim.Allow()
}

func (l *ipLimiter) middleware(ipOf func(*http.Request) string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/healthz" && !l.allow(ipOf(r)) {
			w.Header().Set("Retry-After", "1")
			writeError(w, http.StatusTooManyRequests, "rate_limited")
			return
		}
		next.ServeHTTP(w, r)
	})
}
