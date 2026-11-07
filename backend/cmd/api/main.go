package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
	_ "time/tzdata" // the distroless image has no zoneinfo; device timezones need it

	"github.com/tiagofur/peliculas-admob/backend/internal/auth"
	"github.com/tiagofur/peliculas-admob/backend/internal/cache"
	"github.com/tiagofur/peliculas-admob/backend/internal/config"
	"github.com/tiagofur/peliculas-admob/backend/internal/db"
	"github.com/tiagofur/peliculas-admob/backend/internal/httpapi"
	"github.com/tiagofur/peliculas-admob/backend/internal/library"
	"github.com/tiagofur/peliculas-admob/backend/internal/push"
	"github.com/tiagofur/peliculas-admob/backend/internal/storekit"
	"github.com/tiagofur/peliculas-admob/backend/internal/tmdb"
)

// version is set at build time: -ldflags "-X main.version=<git sha>".
var version = "dev"

func main() {
	// `api healthcheck` lets Docker probe the container: the distroless
	// image has no curl or shell.
	if len(os.Args) > 1 && os.Args[1] == "healthcheck" {
		os.Exit(healthcheck())
	}
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil)).With("version", version)
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
	srv := &httpapi.Server{TMDB: proxy, Log: log, TrustProxy: cfg.TrustProxy, Version: version}

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

		if cfg.StoreKitBundleID != "" && len(cfg.ProProductIDs) > 0 {
			verifier, err := storekit.NewAppleVerifier()
			if err != nil {
				return err
			}
			srv.StoreKit = &storekit.Service{DB: pool, Verifier: verifier, Log: log,
				BundleID: cfg.StoreKitBundleID, ProductIDs: cfg.ProProductIDs}
		} else {
			log.Warn("STOREKIT_BUNDLE_ID or PRO_PRODUCT_IDS not set: Pro is disabled")
		}

		apns, err := push.NewAPNs(cfg.APNsKeyID, cfg.APNsTeamID, cfg.APNsTopic, cfg.APNsPrivateKey)
		if err != nil {
			return err
		}
		srv.Push = &push.Service{DB: pool, Log: log}
		if apns != nil {
			srv.Push.Sender = apns
			job := &push.EpisodeJob{Push: srv.Push, Shows: proxy, ProOnly: cfg.PushProOnly, AlertHour: cfg.PushAlertHour}
			go job.Loop(ctx, cfg.PushInterval)
		} else {
			log.Warn("APNS_KEY_ID / APNS_PRIVATE_KEY not set: devices are stored but no alerts are sent")
		}
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

func healthcheck() int {
	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8080"
	}
	if strings.HasPrefix(addr, ":") {
		addr = "127.0.0.1" + addr
	}
	c := &http.Client{Timeout: 3 * time.Second}
	resp, err := c.Get("http://" + addr + "/healthz")
	if err != nil {
		return 1
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 1
	}
	return 0
}
