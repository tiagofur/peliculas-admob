-- Migration: Rename user_watched_movies to user_watched for consistency
-- Date: 2025-10-01
-- Description: Renames the watched movies table to match naming convention of other tables
--              (user_favorites, user_watchlist, user_movie_ratings, etc.)

-- ⚠️ IMPORTANT: This migration renames the table to maintain consistency
-- All references in the codebase will be updated to use 'user_watched'

-- Step 1: Rename the table
ALTER TABLE IF EXISTS public.user_watched_movies
RENAME TO user_watched;

-- Step 2: Update indexes (they will be renamed automatically, but let's verify names)
-- The indexes will keep their old names, which is fine, or we can rename them:

-- Optional: Rename indexes for consistency (uncomment if you want clean index names)
-- ALTER INDEX IF EXISTS idx_user_watched_movies_user_id RENAME TO idx_user_watched_user_id;
-- ALTER INDEX IF EXISTS idx_user_watched_movies_movie_id RENAME TO idx_user_watched_movie_id;
-- ALTER INDEX IF EXISTS idx_user_watched_movies_watched_at RENAME TO idx_user_watched_watched_at;

-- Step 3: Update triggers (if any exist, they need to reference the new table name)
-- Check if there are any triggers that need updating
DO $$
DECLARE
    trigger_record RECORD;
BEGIN
    -- List any triggers on the old table name (for logging)
    FOR trigger_record IN
        SELECT tgname
        FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE c.relname = 'user_watched'
    LOOP
        RAISE NOTICE 'Trigger found: %', trigger_record.tgname;
    END LOOP;
END $$;

-- Step 4: Verify the rename was successful
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_tables
        WHERE schemaname = 'public'
        AND tablename = 'user_watched'
    ) THEN
        RAISE NOTICE '✅ Table successfully renamed to user_watched';
    ELSE
        RAISE EXCEPTION '❌ Failed to rename table to user_watched';
    END IF;

    -- Verify old table name doesn't exist
    IF EXISTS (
        SELECT 1 FROM pg_tables
        WHERE schemaname = 'public'
        AND tablename = 'user_watched_movies'
    ) THEN
        RAISE WARNING '⚠️ Old table user_watched_movies still exists!';
    END IF;
END $$;

-- Step 5: Grant permissions on the renamed table
GRANT ALL ON public.user_watched TO authenticated;
GRANT ALL ON public.user_watched TO service_role;

-- Step 6: Update table comment
COMMENT ON TABLE public.user_watched IS 'Stores movies watched by users with sync capabilities (renamed from user_watched_movies for consistency)';

-- Verification queries (for manual testing):
-- SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE 'user_watched%';
-- SELECT * FROM user_watched LIMIT 1; -- Should work with new name
