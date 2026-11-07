CREATE TABLE users (
    id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    email          text        UNIQUE,          -- lowercase; NULL when the provider hides it
    email_verified boolean     NOT NULL DEFAULT false,
    display_name   text        NOT NULL DEFAULT '',
    avatar_url     text        NOT NULL DEFAULT '',
    locale         text        NOT NULL DEFAULT '',
    country        text        NOT NULL DEFAULT '',
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);

-- One row per way of signing in. For 'email' the subject is the lowercase email.
CREATE TABLE identities (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    provider            text        NOT NULL CHECK (provider IN ('email', 'apple', 'google')),
    subject             text        NOT NULL,
    email               text,
    password_hash       text,                   -- bcrypt, only for 'email'
    apple_refresh_token text,                   -- to revoke on account deletion
    created_at          timestamptz NOT NULL DEFAULT now(),
    UNIQUE (provider, subject)
);
CREATE INDEX identities_user_id_idx ON identities (user_id);

-- Refresh tokens rotate on every use. All tokens of one login share a family,
-- so reusing an old token revokes the whole family.
CREATE TABLE refresh_tokens (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    family_id   uuid        NOT NULL,
    token_hash  bytea       NOT NULL UNIQUE,    -- sha256 of the token
    device_name text        NOT NULL DEFAULT '',
    created_at  timestamptz NOT NULL DEFAULT now(),
    expires_at  timestamptz NOT NULL,
    revoked_at  timestamptz
);
CREATE INDEX refresh_tokens_user_id_idx ON refresh_tokens (user_id);
CREATE INDEX refresh_tokens_family_id_idx ON refresh_tokens (family_id);
