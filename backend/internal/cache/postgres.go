package cache

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Postgres stores entries in the tmdb_cache table so they survive restarts
// and are shared by every API instance.
type Postgres struct{ db *pgxpool.Pool }

func NewPostgres(db *pgxpool.Pool) *Postgres { return &Postgres{db: db} }

func (p *Postgres) Get(ctx context.Context, key string) (Entry, bool, error) {
	var e Entry
	err := p.db.QueryRow(ctx,
		`SELECT status, body, fetched_at, expires_at FROM tmdb_cache WHERE key = $1`, key,
	).Scan(&e.Status, &e.Body, &e.FetchedAt, &e.ExpiresAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return Entry{}, false, nil
	}
	return e, err == nil, err
}

func (p *Postgres) Set(ctx context.Context, key string, e Entry) error {
	_, err := p.db.Exec(ctx, `
		INSERT INTO tmdb_cache (key, status, body, fetched_at, expires_at)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (key) DO UPDATE
		SET status = EXCLUDED.status, body = EXCLUDED.body,
		    fetched_at = EXCLUDED.fetched_at, expires_at = EXCLUDED.expires_at`,
		key, e.Status, e.Body, e.FetchedAt, e.ExpiresAt)
	return err
}

// Prune deletes entries too old to be served even as stale.
func (p *Postgres) Prune(ctx context.Context, olderThan time.Time) (int64, error) {
	tag, err := p.db.Exec(ctx, `DELETE FROM tmdb_cache WHERE fetched_at < $1`, olderThan)
	return tag.RowsAffected(), err
}
