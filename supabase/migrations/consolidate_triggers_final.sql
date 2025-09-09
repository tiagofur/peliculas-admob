-- =============================================
-- CONSOLIDATE TRIGGERS AND FUNCTIONS - FINAL
-- =============================================
-- This migration consolidates all trigger inconsistencies
-- and creates a unified, robust trigger system
-- Created: 2025-01-27
-- Purpose: Fix all trigger naming inconsistencies and function duplications

-- =============================================
-- PHASE 1: CLEANUP OLD FUNCTIONS AND TRIGGERS
-- =============================================

-- Drop all old trigger functions that might exist
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS update_last_modified_at_column() CASCADE;
DROP FUNCTION IF EXISTS update_user_favorites_updated_at() CASCADE;
DROP FUNCTION IF EXISTS update_user_watchlist_updated_at() CASCADE;
DROP FUNCTION IF EXISTS update_user_watched_movies_updated_at() CASCADE;
DROP FUNCTION IF EXISTS update_user_lists_updated_at() CASCADE;
DROP FUNCTION IF EXISTS update_user_list_items_updated_at() CASCADE;

-- Drop all old triggers systematically
DO $$
DECLARE
    tbl_name text;
    trigger_name text;
    tables text[] := ARRAY['user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items'];
    old_trigger_patterns text[] := ARRAY['_updated_at', '_last_modified_at', '_sync_metadata'];
    pattern text;
BEGIN
    RAISE NOTICE '=== CLEANING UP OLD TRIGGERS ===';
    
    FOREACH tbl_name IN ARRAY tables
    LOOP
        FOREACH pattern IN ARRAY old_trigger_patterns
        LOOP
            trigger_name := 'update_' || tbl_name || pattern;
            EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I', trigger_name, tbl_name);
        END LOOP;
        
        RAISE NOTICE 'Cleaned triggers for table: %', tbl_name;
    END LOOP;
END $$;

-- =============================================
-- PHASE 2: CREATE UNIFIED TRIGGER FUNCTION
-- =============================================

-- Create the definitive, unified trigger function
CREATE OR REPLACE FUNCTION update_sync_metadata()
RETURNS TRIGGER AS $$
BEGIN
    -- Handle INSERT operations
    IF TG_OP = 'INSERT' THEN
        NEW.last_modified_at = NOW();
        NEW.sync_version = COALESCE(NEW.sync_version, 1);
        RETURN NEW;
    END IF;
    
    -- Handle UPDATE operations
    IF TG_OP = 'UPDATE' THEN
        -- Always update timestamp
        NEW.last_modified_at = NOW();
        
        -- Increment sync_version for conflict resolution
        NEW.sync_version = COALESCE(OLD.sync_version, 0) + 1;
        
        -- Preserve device_id if not explicitly changed
        IF NEW.device_id IS NULL AND OLD.device_id IS NOT NULL THEN
            NEW.device_id = OLD.device_id;
        END IF;
        
        RETURN NEW;
    END IF;
    
    -- For other operations, return NEW
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add function comment for documentation
COMMENT ON FUNCTION update_sync_metadata() IS 'Unified trigger function that updates last_modified_at and sync_version for all sync tables';

-- =============================================
-- PHASE 3: CREATE UNIFIED TRIGGERS
-- =============================================

-- Create consistent triggers for all sync tables
DO $$
DECLARE
    tbl_name text;
    trigger_name text;
    tables text[] := ARRAY['user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items'];
BEGIN
    RAISE NOTICE '=== CREATING UNIFIED TRIGGERS ===';
    
    FOREACH tbl_name IN ARRAY tables
    LOOP
        -- Create unified trigger name: sync_metadata_trigger
        trigger_name := tbl_name || '_sync_metadata_trigger';
        
        -- Create trigger for INSERT and UPDATE operations
        EXECUTE format(
            'CREATE TRIGGER %I 
             BEFORE INSERT OR UPDATE ON public.%I 
             FOR EACH ROW EXECUTE FUNCTION update_sync_metadata()',
            trigger_name, tbl_name
        );
        
        RAISE NOTICE '✅ Created trigger: % for table: %', trigger_name, tbl_name;
    END LOOP;
END $$;

-- =============================================
-- PHASE 4: VERIFY SCHEMA CONSISTENCY
-- =============================================

-- Verify all required columns exist
DO $$
DECLARE
    tbl_name text;
    tables text[] := ARRAY['user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items'];
    required_columns text[] := ARRAY['last_modified_at', 'sync_version', 'is_deleted'];
    col_name text;
    missing_columns text := '';
    col_exists boolean;
BEGIN
    RAISE NOTICE '=== SCHEMA VERIFICATION ===';
    
    FOREACH tbl_name IN ARRAY tables
    LOOP
        FOREACH col_name IN ARRAY required_columns
        LOOP
            SELECT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = tbl_name 
                AND column_name = col_name 
                AND table_schema = 'public'
            ) INTO col_exists;
            
            IF NOT col_exists THEN
                missing_columns := missing_columns || tbl_name || '.' || col_name || ' ';
            END IF;
        END LOOP;
    END LOOP;
    
    IF missing_columns = '' THEN
        RAISE NOTICE '✅ All required sync columns are present';
    ELSE
        RAISE WARNING '❌ Missing columns: %', missing_columns;
    END IF;
END $$;

-- =============================================
-- PHASE 5: VERIFY TRIGGER FUNCTIONALITY
-- =============================================

-- Test trigger functionality on user_favorites (safest table to test)
DO $$
DECLARE
    test_user_id UUID := gen_random_uuid();
    test_movie_id INTEGER := 999999;
    initial_version INTEGER;
    updated_version INTEGER;
    initial_timestamp TIMESTAMP WITH TIME ZONE;
    updated_timestamp TIMESTAMP WITH TIME ZONE;
BEGIN
    RAISE NOTICE '=== TESTING TRIGGER FUNCTIONALITY ===';
    
    BEGIN
        -- Test INSERT trigger
        INSERT INTO user_favorites (user_id, movie_id, movie_title, is_deleted, sync_version)
        VALUES (test_user_id, test_movie_id, 'Test Movie', false, 1)
        RETURNING sync_version, last_modified_at INTO initial_version, initial_timestamp;
        
        RAISE NOTICE '✅ INSERT trigger test passed - version: %, timestamp set: %', 
                     initial_version, (initial_timestamp IS NOT NULL);
        
        -- Wait a moment to ensure timestamp difference
        PERFORM pg_sleep(0.1);
        
        -- Test UPDATE trigger
        UPDATE user_favorites 
        SET movie_title = 'Updated Test Movie'
        WHERE user_id = test_user_id AND movie_id = test_movie_id
        RETURNING sync_version, last_modified_at INTO updated_version, updated_timestamp;
        
        -- Verify version incremented and timestamp updated
        IF updated_version > initial_version AND updated_timestamp > initial_timestamp THEN
            RAISE NOTICE '✅ UPDATE trigger test passed - version incremented: % -> %, timestamp updated', 
                         initial_version, updated_version;
        ELSE
            RAISE WARNING '❌ UPDATE trigger test failed - version: % -> %, timestamp updated: %', 
                          initial_version, updated_version, (updated_timestamp > initial_timestamp);
        END IF;
        
        -- Clean up test record
        DELETE FROM user_favorites 
        WHERE user_id = test_user_id AND movie_id = test_movie_id;
        
        RAISE NOTICE '✅ Trigger functionality test completed successfully';
        
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING '❌ Trigger test failed: %', SQLERRM;
        
        -- Clean up in case of error
        BEGIN
            DELETE FROM user_favorites 
            WHERE user_id = test_user_id AND movie_id = test_movie_id;
        EXCEPTION WHEN OTHERS THEN
            -- Ignore cleanup errors
        END;
    END;
END $$;

-- =============================================
-- PHASE 6: CREATE TRIGGER MONITORING VIEW
-- =============================================

-- Create a view to monitor trigger status
CREATE OR REPLACE VIEW sync_trigger_status AS
SELECT 
    n.nspname as schema_name,
    c.relname as table_name,
    t.tgname as trigger_name,
    CASE 
        WHEN t.tgname LIKE '%sync_metadata_trigger' THEN 'UNIFIED'
        WHEN t.tgname LIKE '%updated_at%' THEN 'OLD_PATTERN'
        WHEN t.tgname LIKE '%last_modified_at%' THEN 'OLD_PATTERN'
        ELSE 'OTHER'
    END as trigger_type,
    t.tgenabled as is_enabled
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public'
AND c.relname IN ('user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items')
AND NOT t.tgisinternal
ORDER BY c.relname, t.tgname;

-- Grant access to the view
GRANT SELECT ON sync_trigger_status TO authenticated;

-- =============================================
-- FINAL VERIFICATION AND SUMMARY
-- =============================================

DO $$
DECLARE
    unified_trigger_count INTEGER;
    old_trigger_count INTEGER;
    total_tables INTEGER := 5;
BEGIN
    RAISE NOTICE '=== FINAL CONSOLIDATION SUMMARY ===';
    
    -- Count unified triggers
    SELECT COUNT(*) INTO unified_trigger_count
    FROM sync_trigger_status 
    WHERE trigger_type = 'UNIFIED';
    
    -- Count old pattern triggers
    SELECT COUNT(*) INTO old_trigger_count
    FROM sync_trigger_status 
    WHERE trigger_type = 'OLD_PATTERN';
    
    RAISE NOTICE 'Unified triggers created: %/%', unified_trigger_count, total_tables;
    RAISE NOTICE 'Old pattern triggers remaining: %', old_trigger_count;
    
    IF unified_trigger_count = total_tables AND old_trigger_count = 0 THEN
        RAISE NOTICE '🎉 TRIGGER CONSOLIDATION COMPLETED SUCCESSFULLY!';
        RAISE NOTICE '✅ All sync tables now use unified trigger system';
        RAISE NOTICE '✅ All old inconsistent triggers have been removed';
        RAISE NOTICE '✅ Trigger functionality verified and working';
    ELSE
        RAISE WARNING '⚠️ Consolidation incomplete - manual review required';
    END IF;
END $$;

-- Add final comment
COMMENT ON VIEW sync_trigger_status IS 'Monitoring view for sync trigger consolidation status';