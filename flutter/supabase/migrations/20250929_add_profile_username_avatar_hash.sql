-- Migration: Add username, avatar hash, and sync metadata to user_profiles
-- Date: 2025-09-29

CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Ensure base columns exist
ALTER TABLE user_profiles
    ADD COLUMN IF NOT EXISTS display_name VARCHAR(150);

ALTER TABLE user_profiles
    ADD COLUMN IF NOT EXISTS username CITEXT;

ALTER TABLE user_profiles
    ADD COLUMN IF NOT EXISTS avatar_hash TEXT;

ALTER TABLE user_profiles
    ADD COLUMN IF NOT EXISTS stats JSONB;

ALTER TABLE user_profiles
    ADD COLUMN IF NOT EXISTS preferences JSONB;

ALTER TABLE user_profiles
    ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMP WITH TIME ZONE;

-- Backfill and enforce defaults
UPDATE user_profiles
SET display_name = COALESCE(display_name, full_name, 'Usuario')
WHERE display_name IS NULL;

ALTER TABLE user_profiles ALTER COLUMN display_name SET DEFAULT 'Usuario';
ALTER TABLE user_profiles ALTER COLUMN display_name SET NOT NULL;

UPDATE user_profiles
SET stats = '{}'::jsonb
WHERE stats IS NULL;

ALTER TABLE user_profiles ALTER COLUMN stats SET DEFAULT '{}'::jsonb;
ALTER TABLE user_profiles ALTER COLUMN stats SET NOT NULL;

UPDATE user_profiles
SET preferences = COALESCE(
    preferences,
    '{"email_notifications": true, "push_notifications": true, "profile_public": true}'::jsonb
)
WHERE preferences IS NULL;

ALTER TABLE user_profiles
    ALTER COLUMN preferences SET DEFAULT '{"email_notifications": true, "push_notifications": true, "profile_public": true}'::jsonb;
ALTER TABLE user_profiles ALTER COLUMN preferences SET NOT NULL;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'user_profiles'
          AND table_schema = 'public'
          AND column_name = 'updated_at'
    ) THEN
        UPDATE user_profiles
        SET last_synced_at = COALESCE(last_synced_at, updated_at, created_at, NOW());
    ELSE
        UPDATE user_profiles
        SET last_synced_at = COALESCE(last_synced_at, created_at, NOW());
    END IF;
END $$;

UPDATE user_profiles
SET avatar_hash = encode(digest(avatar_url, 'sha256'), 'hex')
WHERE avatar_url IS NOT NULL
  AND avatar_url <> ''
  AND (avatar_hash IS NULL OR avatar_hash = '');

-- Username constraints and indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_profiles_username_unique
    ON user_profiles (username)
    WHERE username IS NOT NULL;

ALTER TABLE user_profiles
    DROP CONSTRAINT IF EXISTS user_profiles_username_length;
ALTER TABLE user_profiles
    ADD CONSTRAINT user_profiles_username_length
    CHECK (username IS NULL OR char_length(username) BETWEEN 3 AND 20);

ALTER TABLE user_profiles
    DROP CONSTRAINT IF EXISTS user_profiles_username_format;
ALTER TABLE user_profiles
    ADD CONSTRAINT user_profiles_username_format
    CHECK (username IS NULL OR username ~ '^[a-z0-9_]+$');

COMMENT ON COLUMN user_profiles.username IS 'Unique lowercase handle (3-20 chars, letters/numbers/underscore)';

-- Ensure last_synced_at is automatically populated when omitted
CREATE OR REPLACE FUNCTION public.ensure_user_profile_last_synced()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.last_synced_at IS NULL THEN
        NEW.last_synced_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS user_profiles_last_synced_default ON user_profiles;
CREATE TRIGGER user_profiles_last_synced_default
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.ensure_user_profile_last_synced();

-- Update the user creation hook to populate new columns
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    raw_username TEXT;
    normalized_username TEXT;
BEGIN
    raw_username := COALESCE(NEW.raw_user_meta_data->>'username', '');
    normalized_username := NULLIF(
        regexp_replace(lower(raw_username), '[^a-z0-9_]', '', 'g'),
        ''
    );

    INSERT INTO public.user_profiles (
        user_id,
        full_name,
        display_name,
        username,
        bio,
        avatar_url,
        avatar_hash,
        stats,
        preferences,
        last_synced_at
    )
    VALUES (
        NEW.id,
        COALESCE(
            NEW.raw_user_meta_data->>'full_name',
            NEW.raw_user_meta_data->>'display_name',
            split_part(COALESCE(NEW.email, 'usuario@cineplus.app'), '@', 1)
        ),
        COALESCE(
            NEW.raw_user_meta_data->>'display_name',
            NEW.raw_user_meta_data->>'full_name',
            split_part(COALESCE(NEW.email, 'usuario@cineplus.app'), '@', 1)
        ),
        normalized_username,
        NULLIF(NEW.raw_user_meta_data->>'bio', ''),
        COALESCE(NEW.raw_user_meta_data->>'avatar_url', ''),
        NULLIF(NEW.raw_user_meta_data->>'avatar_hash', ''),
        '{}'::jsonb,
        '{"email_notifications": true, "push_notifications": true, "profile_public": true}'::jsonb,
        NOW()
    )
    ON CONFLICT (user_id) DO NOTHING;

    INSERT INTO public.user_stats (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
