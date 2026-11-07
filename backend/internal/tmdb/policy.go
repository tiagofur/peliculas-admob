// Package tmdb proxies a fixed set of TMDB endpoints through a tiered cache.
package tmdb

import (
	"encoding/json"
	"net/url"
	"regexp"
	"strings"
	"time"
)

// NotFoundTTL is how long a TMDB 404 is remembered.
const NotFoundTTL = time.Hour

type ttlFunc func(body []byte, now time.Time) time.Duration

func fixed(d time.Duration) ttlFunc { return func([]byte, time.Time) time.Duration { return d } }

const day = 24 * time.Hour

type route struct {
	re  *regexp.Regexp
	ttl ttlFunc
}

// routes is the allowlist: anything else is rejected, so we are never an open proxy.
var routes = []route{
	{regexp.MustCompile(`^/trending/(all|movie|tv|person)/(day|week)$`), fixed(time.Hour)},
	{regexp.MustCompile(`^/movie/now_playing$`), fixed(time.Hour)},
	{regexp.MustCompile(`^/tv/(airing_today|on_the_air)$`), fixed(time.Hour)},
	{regexp.MustCompile(`^/(movie|tv)/(popular|top_rated)$`), fixed(6 * time.Hour)},
	{regexp.MustCompile(`^/movie/upcoming$`), fixed(6 * time.Hour)},
	{regexp.MustCompile(`^/discover/(movie|tv)$`), fixed(3 * time.Hour)},
	{regexp.MustCompile(`^/search/(movie|tv|multi|person)$`), fixed(6 * time.Hour)},
	{regexp.MustCompile(`^/movie/\d+$`), movieDetailTTL},
	{regexp.MustCompile(`^/tv/\d+$`), tvDetailTTL},
	{regexp.MustCompile(`^/tv/\d+/season/\d+(/episode/\d+)?$`), fixed(day)},
	{regexp.MustCompile(`^/(movie|tv)/\d+/(videos|credits|aggregate_credits|keywords|similar|recommendations|images|external_ids)$`), fixed(7 * day)},
	{regexp.MustCompile(`^/(movie|tv)/\d+/watch/providers$`), fixed(day)},
	{regexp.MustCompile(`^/person/\d+(/(movie_credits|tv_credits|combined_credits))?$`), fixed(7 * day)},
	{regexp.MustCompile(`^/collection/\d+$`), fixed(7 * day)},
	{regexp.MustCompile(`^/watch/providers/(movie|tv)$`), fixed(7 * day)},
	{regexp.MustCompile(`^/(watch/providers/regions|genre/(movie|tv)/list|configuration(/languages|/countries)?)$`), fixed(30 * day)},
}

// allowedParams are the query params that change TMDB's answer. Others are dropped
// so they cannot bloat the cache key space.
var allowedParams = map[string]bool{
	"language": true, "region": true, "page": true, "query": true, "include_adult": true,
	"year": true, "primary_release_year": true, "first_air_date_year": true,
	"with_genres": true, "without_genres": true, "sort_by": true, "watch_region": true,
	"with_watch_providers": true, "with_watch_monetization_types": true,
	"with_original_language": true, "vote_count.gte": true, "vote_average.gte": true,
	"primary_release_date.gte": true, "primary_release_date.lte": true,
	"first_air_date.gte": true, "first_air_date.lte": true, "with_runtime.lte": true,
	"append_to_response": true, "include_image_language": true, "timezone": true,
}

// Match reports whether path is allowed and returns its TTL policy.
func Match(path string) (ttlFunc, bool) {
	for _, r := range routes {
		if r.re.MatchString(path) {
			return r.ttl, true
		}
	}
	return nil, false
}

// Normalize keeps only allowed params and canonicalizes values that do not
// change the answer (search text case and spacing).
func Normalize(q url.Values) url.Values {
	out := url.Values{}
	for k, vs := range q {
		if !allowedParams[k] || len(vs) == 0 {
			continue
		}
		v := strings.TrimSpace(vs[0])
		if k == "query" {
			v = strings.ToLower(strings.Join(strings.Fields(v), " "))
		}
		if v != "" {
			out.Set(k, v)
		}
	}
	return out
}

// CacheKey is the path plus sorted, normalized params (never the API key).
func CacheKey(path string, q url.Values) string {
	if enc := q.Encode(); enc != "" {
		return path + "?" + enc
	}
	return path
}

// Old movies rarely change; recent or upcoming ones still get new data.
func movieDetailTTL(body []byte, now time.Time) time.Duration {
	var m struct {
		Status      string `json:"status"`
		ReleaseDate string `json:"release_date"`
	}
	if json.Unmarshal(body, &m) == nil && m.Status == "Released" {
		if d, err := time.Parse("2006-01-02", m.ReleaseDate); err == nil && now.Sub(d) > 365*day {
			return 7 * day
		}
	}
	return 12 * time.Hour
}

// Finished shows are frozen; running ones change next_episode_to_air often.
func tvDetailTTL(body []byte, _ time.Time) time.Duration {
	var t struct {
		Status string `json:"status"`
	}
	if json.Unmarshal(body, &t) == nil && (t.Status == "Ended" || t.Status == "Canceled") {
		return 30 * day
	}
	return 6 * time.Hour
}
