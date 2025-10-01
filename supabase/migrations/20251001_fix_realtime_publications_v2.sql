-- Migration: Fix Realtime Publications (Version 2 - Only Existing Tables)
-- Date: 2025-10-01
-- Description: Corrects the supabase_realtime publication to include only tables that exist

-- ⚠️ CRITICAL FIX: Only include tables that actually exist in the database

-- Step 1: Drop the incorrect publication
DROP PUBLICATION IF EXISTS supabase_realtime;

-- Step 2: Recreate publication with only EXISTING tables
-- ✅ Including only tables that we know exist based on migrations
CREATE PUBLICATION supabase_realtime FOR TABLE
    public.user_favorites,
    public.user_movie_ratings;
    -- Note: Removed user_watchlist, user_watched, user_custom_lists, user_custom_list_items
    -- Add them back if they exist in your database

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

-- Step 4: Grant necessary permissions
GRANT ALL ON public.user_movie_ratings TO authenticated;
GRANT ALL ON public.user_movie_ratings TO service_role;
GRANT ALL ON public.user_favorites TO authenticated;
GRANT ALL ON public.user_favorites TO service_role;

-- Add comment for documentation
COMMENT ON PUBLICATION supabase_realtime IS 'Realtime publication for user_favorites and user_movie_ratings';

-- Verification query (run this to see what tables are included)
-- SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
