-- Every synced row carries:
--   updated_at  client time of the last change (last write wins)
--   deleted_at  tombstone, so other devices learn about deletions
--   txid        id of the transaction that wrote it; the sync cursor
-- Title/poster/year are a small snapshot so the library renders without TMDB.

CREATE TABLE library_items (
    user_id     uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    kind        text        NOT NULL CHECK (kind IN ('favorite', 'watchlist', 'watched')),
    media_type  text        NOT NULL CHECK (media_type IN ('movie', 'tv')),
    tmdb_id     integer     NOT NULL CHECK (tmdb_id > 0),
    title       text        NOT NULL DEFAULT '',
    poster_path text        NOT NULL DEFAULT '',
    year        text        NOT NULL DEFAULT '',
    updated_at  timestamptz NOT NULL,
    deleted_at  timestamptz,
    txid        xid8        NOT NULL DEFAULT pg_current_xact_id(),
    PRIMARY KEY (user_id, kind, media_type, tmdb_id)
);
CREATE INDEX library_items_sync_idx ON library_items (user_id, txid);

-- List IDs come from the device so lists can be created offline.
CREATE TABLE lists (
    id          uuid        PRIMARY KEY,
    user_id     uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name        text        NOT NULL DEFAULT '',
    description text        NOT NULL DEFAULT '',
    position    integer     NOT NULL DEFAULT 0,
    updated_at  timestamptz NOT NULL,
    deleted_at  timestamptz,
    txid        xid8        NOT NULL DEFAULT pg_current_xact_id()
);
CREATE INDEX lists_sync_idx ON lists (user_id, txid);

CREATE TABLE list_items (
    list_id     uuid        NOT NULL REFERENCES lists (id) ON DELETE CASCADE,
    user_id     uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    media_type  text        NOT NULL CHECK (media_type IN ('movie', 'tv')),
    tmdb_id     integer     NOT NULL CHECK (tmdb_id > 0),
    title       text        NOT NULL DEFAULT '',
    poster_path text        NOT NULL DEFAULT '',
    year        text        NOT NULL DEFAULT '',
    position    integer     NOT NULL DEFAULT 0,
    updated_at  timestamptz NOT NULL,
    deleted_at  timestamptz,
    txid        xid8        NOT NULL DEFAULT pg_current_xact_id(),
    PRIMARY KEY (list_id, media_type, tmdb_id)
);
CREATE INDEX list_items_sync_idx ON list_items (user_id, txid);

-- Score is 1..10 (half stars of a 5-star scale).
CREATE TABLE ratings (
    user_id     uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    media_type  text        NOT NULL CHECK (media_type IN ('movie', 'tv')),
    tmdb_id     integer     NOT NULL CHECK (tmdb_id > 0),
    score       smallint    NOT NULL DEFAULT 0 CHECK (score BETWEEN 0 AND 10),
    review      text        NOT NULL DEFAULT '',
    title       text        NOT NULL DEFAULT '',
    poster_path text        NOT NULL DEFAULT '',
    updated_at  timestamptz NOT NULL,
    deleted_at  timestamptz,
    txid        xid8        NOT NULL DEFAULT pg_current_xact_id(),
    PRIMARY KEY (user_id, media_type, tmdb_id)
);
CREATE INDEX ratings_sync_idx ON ratings (user_id, txid);

CREATE TABLE watched_episodes (
    user_id     uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    tv_id       integer     NOT NULL CHECK (tv_id > 0),
    season      smallint    NOT NULL CHECK (season >= 0),
    episode     smallint    NOT NULL CHECK (episode >= 1),
    watched_at  timestamptz NOT NULL,
    updated_at  timestamptz NOT NULL,
    deleted_at  timestamptz,
    txid        xid8        NOT NULL DEFAULT pg_current_xact_id(),
    PRIMARY KEY (user_id, tv_id, season, episode)
);
CREATE INDEX watched_episodes_sync_idx ON watched_episodes (user_id, txid);
