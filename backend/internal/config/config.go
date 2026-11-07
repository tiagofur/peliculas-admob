// Package config reads settings from environment variables.
package config

import (
	"errors"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Addr          string
	DatabaseURL   string // empty = memory-only cache
	TMDBAPIKey    string
	TMDBReadToken string
	MemEntries    int
	StaleMax      time.Duration
	TrustProxy    bool // read client IP from X-Forwarded-For (behind Caddy)

	// Auth (needs DATABASE_URL)
	JWTSecret       string
	AppleClientIDs  []string // iOS bundle ID (+ Services ID for web)
	GoogleClientIDs []string // iOS / Android / web OAuth client IDs
	AppleTeamID     string   // these three enable Apple token revoke
	AppleKeyID      string
	ApplePrivateKey string // .p8 contents, \n allowed

	// StoreKit (Pro)
	StoreKitBundleID string   // defaults to the first APPLE_CLIENT_IDS
	ProProductIDs    []string // App Store product IDs that unlock Pro
}

func Load() (Config, error) {
	c := Config{
		Addr:          env("ADDR", ":8080"),
		DatabaseURL:   os.Getenv("DATABASE_URL"),
		TMDBAPIKey:    os.Getenv("TMDB_API_KEY"),
		TMDBReadToken: os.Getenv("TMDB_READ_TOKEN"),
		MemEntries:    5000,
		StaleMax:      30 * 24 * time.Hour,
		TrustProxy:    os.Getenv("TRUST_PROXY") == "true",

		JWTSecret:       os.Getenv("JWT_SECRET"),
		AppleClientIDs:  list(os.Getenv("APPLE_CLIENT_IDS")),
		GoogleClientIDs: list(os.Getenv("GOOGLE_CLIENT_IDS")),
		AppleTeamID:     os.Getenv("APPLE_TEAM_ID"),
		AppleKeyID:      os.Getenv("APPLE_KEY_ID"),
		ApplePrivateKey: os.Getenv("APPLE_PRIVATE_KEY"),

		StoreKitBundleID: os.Getenv("STOREKIT_BUNDLE_ID"),
		ProProductIDs:    list(os.Getenv("PRO_PRODUCT_IDS")),
	}
	if c.StoreKitBundleID == "" && len(c.AppleClientIDs) > 0 {
		c.StoreKitBundleID = c.AppleClientIDs[0]
	}
	if c.DatabaseURL != "" && len(c.JWTSecret) < 32 {
		return c, errors.New("JWT_SECRET must be at least 32 characters (try: openssl rand -base64 48)")
	}
	if v := os.Getenv("MEM_CACHE_ENTRIES"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 {
			return c, errors.New("MEM_CACHE_ENTRIES must be a positive integer")
		}
		c.MemEntries = n
	}
	if v := os.Getenv("CACHE_STALE_MAX"); v != "" {
		d, err := time.ParseDuration(v)
		if err != nil {
			return c, errors.New("CACHE_STALE_MAX must be a duration like 720h")
		}
		c.StaleMax = d
	}
	if c.TMDBAPIKey == "" && c.TMDBReadToken == "" {
		return c, errors.New("set TMDB_API_KEY or TMDB_READ_TOKEN")
	}
	return c, nil
}

func list(v string) []string {
	var out []string
	for _, s := range strings.Split(v, ",") {
		if s = strings.TrimSpace(s); s != "" {
			out = append(out, s)
		}
	}
	return out
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
