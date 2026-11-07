package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/tiagofur/peliculas-admob/backend/internal/auth"
	"github.com/tiagofur/peliculas-admob/backend/internal/cache"
	"github.com/tiagofur/peliculas-admob/backend/internal/config"
	"github.com/tiagofur/peliculas-admob/backend/internal/db"
	"github.com/tiagofur/peliculas-admob/backend/internal/httpapi"
	"github.com/tiagofur/peliculas-admob/backend/internal/library"
	"github.com/tiagofur/peliculas-admob/backend/internal/tmdb"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	if err := run(log); err != nil {
		log.Error("fatal", "err", err)
		os.Exit(1)
	}
}

func run(log *slog.Logger) error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	proxy := &tmdb.Proxy{
		Memory:   cache.NewMemory(cfg.MemEntries),
		Upstream: tmdb.NewClient(cfg.TMDBAPIKey, cfg.TMDBReadToken),
		StaleMax: cfg.StaleMax,
		Log:      log,
	}
	srv := &httpapi.Server{TMDB: proxy, Log: log, TrustProxy: cfg.TrustProxy}

	if cfg.DatabaseURL != "" {
		pool, err := db.Open(ctx, cfg.DatabaseURL)
		if err != nil {
			return err
		}
		defer pool.Close()
		if err := db.Migrate(ctx, pool); err != nil {
			return err
		}
		pg := cache.NewPostgres(pool)
		proxy.DB = pg
		srv.Ready = pool.Ping
		go pruneLoop(ctx, log, pg, cfg.StaleMax)

		issuer, err := auth.NewIssuer([]byte(cfg.JWTSecret))
		if err != nil {
			return err
		}
		var bundleID string
		if len(cfg.AppleClientIDs) > 0 {
			bundleID = cfg.AppleClientIDs[0]
		}
		appleAPI, err := auth.NewAppleClient(cfg.AppleTeamID, cfg.AppleKeyID, bundleID, cfg.ApplePrivateKey)
		if err != nil {
			return err
		}
		if appleAPI == nil {
			log.Warn("Apple .p8 key not set: Apple tokens will not be revoked on account deletion")
		}
		srv.Auth = &auth.Service{
			DB: pool, Tokens: issuer, Log: log, AppleAPI: appleAPI,
			Apple:  auth.NewAppleVerifier(cfg.AppleClientIDs),
			Google: auth.NewGoogleVerifier(cfg.GoogleClientIDs),
		}
		srv.Library = &library.Service{DB: pool}
	} else {
		log.Warn("DATABASE_URL not set: cache is memory-only; auth and sync are disabled")
	}

	httpSrv := &http.Server{
		Addr:              cfg.Addr,
		Handler:           srv.Handler(),
		ReadHeaderTimeout: 5 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       120 * time.Second,
	}
	errc := make(chan error, 1)
	go func() { errc <- httpSrv.ListenAndServe() }()
	log.Info("listening", "addr", cfg.Addr)

	select {
	case err := <-errc:
		if !errors.Is(err, http.ErrServerClosed) {
			return err
		}
	case <-ctx.Done():
	}
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	return httpSrv.Shutdown(shutdownCtx)
}

// pruneLoop deletes cache rows too old to serve, once an hour.
func pruneLoop(ctx context.Context, log *slog.Logger, pg *cache.Postgres, staleMax time.Duration) {
	t := time.NewTicker(time.Hour)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			n, err := pg.Prune(ctx, time.Now().Add(-staleMax))
			if err != nil {
				log.Warn("cache prune", "err", err)
			} else if n > 0 {
				log.Info("cache prune", "deleted", n)
			}
		}
	}
}
