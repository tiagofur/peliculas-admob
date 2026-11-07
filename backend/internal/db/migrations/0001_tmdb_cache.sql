CREATE TABLE tmdb_cache (
    key        text        PRIMARY KEY,
    status     smallint    NOT NULL,
    body       bytea       NOT NULL,
    fetched_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL
);

CREATE INDEX tmdb_cache_fetched_at_idx ON tmdb_cache (fetched_at);
