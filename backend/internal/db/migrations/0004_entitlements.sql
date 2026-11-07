-- One row per App Store purchase chain (a subscription and all its renewals
-- share original_transaction_id). user_id is NULL until a signed-in device
-- claims it, e.g. when Apple notifies us before the app does.
CREATE TABLE entitlements (
    original_transaction_id text        PRIMARY KEY,
    user_id                 uuid        REFERENCES users (id) ON DELETE CASCADE,
    product_id              text        NOT NULL,
    environment             text        NOT NULL,          -- Production | Sandbox
    ownership               text        NOT NULL DEFAULT 'PURCHASED', -- or FAMILY_SHARED
    purchased_at            timestamptz NOT NULL,
    expires_at              timestamptz,                   -- NULL = lifetime
    grace_until             timestamptz,                   -- billing grace period
    revoked_at              timestamptz,                   -- refund or family sharing removed
    auto_renew              boolean,
    last_signed_at          timestamptz NOT NULL,          -- ignore older Apple messages
    updated_at              timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX entitlements_user_id_idx ON entitlements (user_id);
