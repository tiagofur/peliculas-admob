-- Migration: Complete Realtime Configuration for ALL User Tables
-- Date: 2025-10-01
-- Description: Configures Realtime for ALL user-related tables including:
--              - user_favorites (películas favoritas)
--              - user_watched (películas vistas - renombrada)
--              - user_watchlist (películas para ver después)
--              - user_movie_ratings (calificaciones y reviews)
--              - user_lists (listas personalizadas)
--              - user_list_items (items de listas personalizadas)

-- ⚠️ IMPORTANT: This is the COMPLETE and FINAL Realtime configuration
-- Execute this AFTER renaming user_watched_movies to user_watched

-- Step 1: Drop the incorrect/incomplete publication
DROP PUBLICATION IF EXISTS supabase_realtime;

-- Step 2: Create publication with ALL user-related tables
CREATE PUBLICATION supabase_realtime FOR TABLE
    public.user_favorites,
    public.user_watched,
    public.user_watchlist,
    public.user_movie_ratings,
    public.user_lists,
    public.user_list_items;

-- Step 3: Verify the publication was created successfully
DO $$
DECLARE
    table_count INTEGER;
BEGIN
    -- Count tables in the publication
    SELECT COUNT(*) INTO table_count
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime';

    IF table_count = 6 THEN
        RAISE NOTICE '✅ Publication supabase_realtime created successfully with 6 tables';
        RAISE NOTICE '   - user_favorites';
        RAISE NOTICE '   - user_watched';
        RAISE NOTICE '   - user_watchlist';
        RAISE NOTICE '   - user_movie_ratings';
        RAISE NOTICE '   - user_lists';
        RAISE NOTICE '   - user_list_items';
    ELSE
        RAISE WARNING '⚠️ Expected 6 tables but found %', table_count;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication
        WHERE pubname = 'supabase_realtime'
    ) THEN
        RAISE EXCEPTION '❌ Failed to create supabase_realtime publication';
    END IF;
END $$;

-- Step 4: Grant necessary permissions to ALL tables
-- Favorites
GRANT ALL ON public.user_favorites TO authenticated;
GRANT ALL ON public.user_favorites TO service_role;

-- Watched
GRANT ALL ON public.user_watched TO authenticated;
GRANT ALL ON public.user_watched TO service_role;

-- Watchlist
GRANT ALL ON public.user_watchlist TO authenticated;
GRANT ALL ON public.user_watchlist TO service_role;

-- Ratings
GRANT ALL ON public.user_movie_ratings TO authenticated;
GRANT ALL ON public.user_movie_ratings TO service_role;

-- Custom Lists
GRANT ALL ON public.user_lists TO authenticated;
GRANT ALL ON public.user_lists TO service_role;

-- List Items
GRANT ALL ON public.user_list_items TO authenticated;
GRANT ALL ON public.user_list_items TO service_role;

-- Step 5: Add comprehensive comment
COMMENT ON PUBLICATION supabase_realtime IS 'Complete Realtime publication for all user-related tables: favorites, watched, watchlist, ratings, lists, and list items';

-- Step 6: Verification queries (for manual testing)
-- Run these to confirm everything is set up correctly:

-- List all tables in the publication
-- SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime' ORDER BY tablename;

-- Verify permissions
-- SELECT grantee, table_name, privilege_type
-- FROM information_schema.table_privileges
-- WHERE table_name IN ('user_favorites', 'user_watched', 'user_watchlist', 'user_movie_ratings', 'user_lists', 'user_list_items')
-- AND grantee IN ('authenticated', 'service_role')
-- ORDER BY table_name, grantee;

-- Expected result for first query:
-- user_favorites
-- user_list_items
-- user_lists
-- user_movie_ratings
-- user_watched
-- user_watchlist
