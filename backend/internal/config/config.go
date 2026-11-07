// Package config reads settings from environment variables.
package config

import (
	"errors"
	"os"
	"strconv"
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

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
