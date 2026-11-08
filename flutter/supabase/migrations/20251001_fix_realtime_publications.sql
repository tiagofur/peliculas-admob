-- Migration: Fix Realtime Publications for Multiple Tables
-- Date: 2025-10-01
-- Description: Corrects the supabase_realtime publication to include ALL tables that need realtime,
--              not just user_movie_ratings

-- ⚠️ CRITICAL FIX: The previous migration was overwriting the entire publication
-- which disabled realtime for other tables (favorites, watchlist, etc.)

-- Step 1: Drop the incorrect publication
DROP PUBLICATION IF EXISTS supabase_realtime;

-- Step 2: Recreate publication with ALL tables that need realtime
CREATE PUBLICATION supabase_realtime FOR TABLE
    public.user_favorites,
    public.user_watchlist,
    public.user_watched,
    public.user_movie_ratings,
    public.user_custom_lists,
    public.user_custom_list_items;

-- Step 3: Verify the publication was created
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_publication
        WHERE pubname = 'supabase_realtime'
    ) THEN
        RAISE NOTICE '✅ Publication supabase_realtime created successfully';
    ELSE
        RAISE EXCEPTION '❌ Failed to create supabase_realtime publication';
    END IF;
END $$;

-- Step 4: Grant necessary permissions (ensure all are granted)
GRANT ALL ON public.user_movie_ratings TO authenticated;
GRANT ALL ON public.user_movie_ratings TO service_role;

-- Add comment for documentation
COMMENT ON PUBLICATION supabase_realtime IS 'Realtime publication for all user-related tables including favorites, watchlist, watched, ratings, and custom lists';

-- Verification query (for manual testing)
-- SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
