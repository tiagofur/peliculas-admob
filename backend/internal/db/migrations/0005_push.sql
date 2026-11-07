-- APNs device tokens. A token belongs to whoever registered it last, so
-- signing into another account on the same phone moves it.
CREATE TABLE devices (
    token       text        PRIMARY KEY,           -- APNs token, lowercase hex
    user_id     uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    platform    text        NOT NULL CHECK (platform IN ('ios', 'tvos')),
    environment text        NOT NULL CHECK (environment IN ('sandbox', 'production')),
    locale      text        NOT NULL DEFAULT '',
    timezone    text        NOT NULL DEFAULT 'UTC',
    app_version text        NOT NULL DEFAULT '',
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    disabled_at timestamptz                         -- APNs said the token is dead
);
CREATE INDEX devices_user_id_idx ON devices (user_id) WHERE disabled_at IS NULL;

-- One row per episode alert per user, so each user hears about an episode once.
CREATE TABLE episode_alerts (
    user_id uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    tv_id   integer     NOT NULL,
    season  smallint    NOT NULL,
    episode smallint    NOT NULL,
    sent_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, tv_id, season, episode)
);
