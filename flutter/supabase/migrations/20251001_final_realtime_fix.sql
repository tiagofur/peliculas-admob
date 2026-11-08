-- Migration: Final Realtime Fix with All Tables
-- Date: 2025-10-01
-- Description: Complete fix for realtime publications after renaming user_watched_movies to user_watched

-- ⚠️ IMPORTANT: Run this AFTER renaming user_watched_movies to user_watched

-- Step 1: Drop the incorrect publication
DROP PUBLICATION IF EXISTS supabase_realtime;

-- Step 2: Recreate publication with ALL existing tables
CREATE PUBLICATION supabase_realtime FOR TABLE
    public.user_favorites,
    public.user_watched,
    public.user_movie_ratings;

-- Step 3: Verify the publication was created
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_publication
        WHERE pubname = 'supabase_realtime'
    ) THEN
        RAISE NOTICE '✅ Publication supabase_realtime created successfully with 3 tables';
    ELSE
        RAISE EXCEPTION '❌ Failed to create supabase_realtime publication';
    END IF;
END $$;

-- Step 4: Grant necessary permissions
GRANT ALL ON public.user_favorites TO authenticated;
GRANT ALL ON public.user_favorites TO service_role;
GRANT ALL ON public.user_watched TO authenticated;
GRANT ALL ON public.user_watched TO service_role;
GRANT ALL ON public.user_movie_ratings TO authenticated;
GRANT ALL ON public.user_movie_ratings TO service_role;

-- Step 5: Add comment for documentation
COMMENT ON PUBLICATION supabase_realtime IS 'Realtime publication for user_favorites, user_watched, and user_movie_ratings tables';

-- Verification query (run this to confirm):
-- SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime' ORDER BY tablename;
-- Expected result: user_favorites, user_movie_ratings, user_watched
