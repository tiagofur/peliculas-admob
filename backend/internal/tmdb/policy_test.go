package tmdb

import (
	"net/url"
	"testing"
	"time"
)

func TestMatchAllowlist(t *testing.T) {
	allowed := []string{
		"/movie/550", "/tv/1399", "/tv/1399/season/2", "/tv/1399/season/2/episode/3",
		"/trending/movie/week", "/movie/popular", "/search/multi", "/discover/tv",
		"/movie/550/watch/providers", "/movie/550/videos", "/genre/tv/list", "/configuration",
	}
	for _, p := range allowed {
		if _, ok := Match(p); !ok {
			t.Errorf("%s should be allowed", p)
		}
	}
	blocked := []string{"/account", "/authentication/token/new", "/movie/550/rating", "/list/1", "/movie/abc", "/movie/550/../../account"}
	for _, p := range blocked {
		if _, ok := Match(p); ok {
			t.Errorf("%s should be blocked", p)
		}
	}
}

func TestCacheKeyNormalizes(t *testing.T) {
	a := CacheKey("/search/movie", Normalize(url.Values{
		"query": {"  The   MATRIX "}, "language": {"es-MX"}, "api_key": {"secret"}, "utm": {"x"},
	}))
	b := CacheKey("/search/movie", Normalize(url.Values{"language": {"es-MX"}, "query": {"the matrix"}}))
	if a != b {
		t.Fatalf("keys differ: %q vs %q", a, b)
	}
	if a != "/search/movie?language=es-MX&query=the+matrix" {
		t.Fatalf("unexpected key %q", a)
	}
}

func TestDetailTTL(t *testing.T) {
	now := time.Date(2026, 11, 7, 0, 0, 0, 0, time.UTC)
	cases := []struct {
		name string
		f    ttlFunc
		body string
		want time.Duration
	}{
		{"old movie", movieDetailTTL, `{"status":"Released","release_date":"1999-10-15"}`, 7 * day},
		{"new movie", movieDetailTTL, `{"status":"Released","release_date":"2026-10-01"}`, 12 * time.Hour},
		{"upcoming movie", movieDetailTTL, `{"status":"Post Production","release_date":"2027-03-01"}`, 12 * time.Hour},
		{"ended show", tvDetailTTL, `{"status":"Ended"}`, 30 * day},
		{"running show", tvDetailTTL, `{"status":"Returning Series"}`, 6 * time.Hour},
		{"bad json", tvDetailTTL, `nope`, 6 * time.Hour},
	}
	for _, c := range cases {
		if got := c.f([]byte(c.body), now); got != c.want {
			t.Errorf("%s: got %v want %v", c.name, got, c.want)
		}
	}
}
