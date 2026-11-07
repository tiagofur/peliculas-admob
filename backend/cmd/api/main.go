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

	"github.com/tiagofur/peliculas-admob/backend/internal/cache"
	"github.com/tiagofur/peliculas-admob/backend/internal/config"
	"github.com/tiagofur/peliculas-admob/backend/internal/db"
	"github.com/tiagofur/peliculas-admob/backend/internal/httpapi"
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
	} else {
		log.Warn("DATABASE_URL not set: cache is memory-only")
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
