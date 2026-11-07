// Command migrate-supabase copies users and libraries from Supabase into the
// new backend database. Safe to run many times.
//
//	SUPABASE_DB_URL=postgres://postgres.xxxx:PASS@aws-0-...pooler.supabase.com:5432/postgres \
//	DATABASE_URL=postgres://peliculas:PASS@localhost:5432/peliculas \
//	go run ./cmd/migrate-supabase -dry-run
package main

import (
	"context"
	"flag"
	"fmt"
	"log/slog"
	"os"

	"github.com/tiagofur/peliculas-admob/backend/internal/db"
	"github.com/tiagofur/peliculas-admob/backend/internal/migrate"
)

func main() {
	dryRun := flag.Bool("dry-run", false, "run everything, print the report, save nothing")
	flag.Parse()
	if err := run(*dryRun); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func run(dryRun bool) error {
	srcURL, dstURL := os.Getenv("SUPABASE_DB_URL"), os.Getenv("DATABASE_URL")
	if srcURL == "" || dstURL == "" {
		return fmt.Errorf("set SUPABASE_DB_URL and DATABASE_URL")
	}
	ctx := context.Background()
	src, err := db.Open(ctx, srcURL)
	if err != nil {
		return fmt.Errorf("supabase: %w", err)
	}
	defer src.Close()
	dst, err := db.Open(ctx, dstURL)
	if err != nil {
		return fmt.Errorf("destination: %w", err)
	}
	defer dst.Close()
	if err := db.Migrate(ctx, dst); err != nil {
		return err
	}
	m := &migrate.Migrator{Src: src, Dst: dst, DryRun: dryRun,
		Log: slog.New(slog.NewTextHandler(os.Stderr, nil))}
	rep, err := m.Run(ctx)
	fmt.Print(rep)
	return err
}
