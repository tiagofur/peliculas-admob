-- =============================================
-- FIX REALTIME SYNC CONFIGURATION
-- =============================================
-- This migration ensures all sync tables are properly configured for real-time
-- Created: January 2025

-- =============================================
-- PHASE 1: VERIFY AND FIX REPLICA IDENTITY
-- =============================================

DO $$
DECLARE
    tbl_name text;
    tables text[] := ARRAY['user_favorites', 'user_watched_movies', 'user_watchlist', 'user_lists', 'user_list_items', 'sync_status', 'sync_conflicts'];
BEGIN
    RAISE NOTICE '=== FIXING REPLICA IDENTITY FOR REALTIME TABLES ===';
    
    FOREACH tbl_name IN ARRAY tables
    LOOP
        -- Set replica identity to FULL
        EXECUTE format('ALTER TABLE public.%I REPLICA IDENTITY FULL', tbl_name);
        RAISE NOTICE '✅ %: Replica identity set to FULL', tbl_name;
    END LOOP;
END $$;

-- =============================================
-- PHASE 2: CONFIGURE REALTIME PUBLICATION
-- =============================================

DO $$
DECLARE
    tbl_name text;
    tables text[] := ARRAY['user_favorites', 'user_watched_movies', 'user_watchlist', 'user_lists', 'user_list_items', 'sync_status', 'sync_conflicts'];
BEGIN
    RAISE NOTICE '=== CONFIGURING REALTIME PUBLICATION ===';
    
    -- Add each table to supabase_realtime publication
    FOREACH tbl_name IN ARRAY tables
    LOOP
        BEGIN
            EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', tbl_name);
            RAISE NOTICE '✅ %: Added to supabase_realtime publication', tbl_name;
        EXCEPTION
            WHEN duplicate_object THEN
                RAISE NOTICE '⚠️ %: Already in supabase_realtime publication', tbl_name;
        END;
    END LOOP;
END $$;

-- =============================================
-- PHASE 3: VERIFY RLS POLICIES
-- =============================================

DO $$
DECLARE
    tbl_name text;
    tables text[] := ARRAY['user_favorites', 'user_watched_movies', 'user_watchlist', 'user_lists', 'user_list_items', 'sync_status', 'sync_conflicts'];
    rls_enabled boolean;
BEGIN
    RAISE NOTICE '=== VERIFYING RLS CONFIGURATION ===';
    
    FOREACH tbl_name IN ARRAY tables
    LOOP
        -- Check if RLS is enabled
        SELECT relrowsecurity INTO rls_enabled
        FROM pg_class c
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE n.nspname = 'public' AND c.relname = tbl_name;
        
        IF rls_enabled THEN
            RAISE NOTICE '✅ %: RLS is enabled', tbl_name;
        ELSE
            -- Enable RLS if not enabled
            EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', tbl_name);
            RAISE NOTICE '🔧 %: RLS enabled', tbl_name;
        END IF;
    END LOOP;
END $$;

-- =============================================
-- PHASE 4: ENSURE PROPER PERMISSIONS
-- =============================================

DO $$
DECLARE
    tbl_name text;
    tables text[] := ARRAY['user_favorites', 'user_watched_movies', 'user_watchlist', 'user_lists', 'user_list_items', 'sync_status', 'sync_conflicts'];
BEGIN
    RAISE NOTICE '=== CONFIGURING PERMISSIONS ===';
    
    FOREACH tbl_name IN ARRAY tables
    LOOP
        -- Grant permissions to authenticated role
        EXECUTE format('GRANT ALL PRIVILEGES ON public.%I TO authenticated', tbl_name);
        RAISE NOTICE '✅ %: Permissions granted to authenticated role', tbl_name;
    END LOOP;
END $$;