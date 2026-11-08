-- =============================================
-- SYNC SCHEMA VALIDATION SCRIPT
-- =============================================
-- Run this script to validate the unified sync schema
-- This should be executed AFTER the migration to verify everything is correct

-- =============================================
-- VALIDATION 1: CHECK REQUIRED COLUMNS
-- =============================================

DO $$
DECLARE
    tbl_name text;
    tables text[] := ARRAY['user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items'];
    required_columns text[] := ARRAY['is_deleted', 'last_modified_at', 'sync_version', 'device_id'];
    col_name text;
    col_exists boolean;
    missing_columns text := '';
    all_valid boolean := true;
BEGIN
    RAISE NOTICE '=== COLUMN VALIDATION ===';
    
    FOREACH tbl_name IN ARRAY tables
    LOOP
        missing_columns := '';
        
        FOREACH col_name IN ARRAY required_columns
        LOOP
            SELECT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = tbl_name 
                AND column_name = col_name 
                AND table_schema = 'public'
            ) INTO col_exists;
            
            IF NOT col_exists THEN
                IF missing_columns != '' THEN
                    missing_columns := missing_columns || ', ';
                END IF;
                missing_columns := missing_columns || col_name;
                all_valid := false;
            END IF;
        END LOOP;
        
        IF missing_columns = '' THEN
            RAISE NOTICE '✅ %: All sync columns present', tbl_name;
        ELSE
            RAISE WARNING '❌ %: Missing columns: %', tbl_name, missing_columns;
        END IF;
    END LOOP;
    
    IF all_valid THEN
        RAISE NOTICE '✅ All tables have required sync columns';
    ELSE
        RAISE WARNING '❌ Some tables are missing required columns';
    END IF;
END $$;

-- =============================================
-- VALIDATION 2: CHECK DATA TYPES
-- =============================================

DO $$
DECLARE
    tbl_name text;
    tables text[] := ARRAY['user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items'];
    data_type_check record;
    type_errors text := '';
BEGIN
    RAISE NOTICE '=== DATA TYPE VALIDATION ===';
    
    FOREACH tbl_name IN ARRAY tables
    LOOP
        -- Check is_deleted is boolean
        SELECT data_type INTO data_type_check
        FROM information_schema.columns 
        WHERE table_name = tbl_name 
        AND column_name = 'is_deleted' 
        AND table_schema = 'public';
        
        IF data_type_check.data_type != 'boolean' THEN
            RAISE WARNING '❌ %: is_deleted should be boolean, found %', tbl_name, data_type_check.data_type;
            type_errors := type_errors || tbl_name || '.is_deleted ';
        END IF;
        
        -- Check sync_version is integer
        SELECT data_type INTO data_type_check
        FROM information_schema.columns 
        WHERE table_name = tbl_name 
        AND column_name = 'sync_version' 
        AND table_schema = 'public';
        
        IF data_type_check.data_type != 'integer' THEN
            RAISE WARNING '❌ %: sync_version should be integer, found %', tbl_name, data_type_check.data_type;
            type_errors := type_errors || tbl_name || '.sync_version ';
        END IF;
        
        -- Check last_modified_at is timestamp with time zone
        SELECT data_type INTO data_type_check
        FROM information_schema.columns 
        WHERE table_name = tbl_name 
        AND column_name = 'last_modified_at' 
        AND table_schema = 'public';
        
        IF data_type_check.data_type != 'timestamp with time zone' THEN
            RAISE WARNING '❌ %: last_modified_at should be timestamp with time zone, found %', tbl_name, data_type_check.data_type;
            type_errors := type_errors || tbl_name || '.last_modified_at ';
        END IF;
    END LOOP;
    
    IF type_errors = '' THEN
        RAISE NOTICE '✅ All data types are correct';
    ELSE
        RAISE WARNING '❌ Data type errors found: %', type_errors;
    END IF;
END $$;

-- =============================================
-- VALIDATION 3: CHECK TRIGGERS
-- =============================================

DO $$
DECLARE
    tbl_name text;
    tables text[] := ARRAY['user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items'];
    trigger_exists boolean;
    trig_name text;
    missing_triggers text := '';
BEGIN
    RAISE NOTICE '=== TRIGGER VALIDATION ===';
    
    FOREACH tbl_name IN ARRAY tables
    LOOP
        trig_name := 'update_' || tbl_name || '_sync_metadata';
        
        SELECT EXISTS (
            SELECT 1 FROM information_schema.triggers t
            WHERE t.trigger_name = trig_name
            AND t.event_object_table = tbl_name
            AND t.event_object_schema = 'public'
        ) INTO trigger_exists;
        
        IF trigger_exists THEN
            RAISE NOTICE '✅ %: Sync metadata trigger exists', tbl_name;
        ELSE
            RAISE WARNING '❌ %: Missing sync metadata trigger', tbl_name;
            missing_triggers := missing_triggers || trig_name || ' ';
        END IF;
    END LOOP;
    
    IF missing_triggers = '' THEN
        RAISE NOTICE '✅ All triggers are present';
    ELSE
        RAISE WARNING '❌ Missing triggers: %', missing_triggers;
    END IF;
END $$;

-- =============================================
-- VALIDATION 4: CHECK INDEXES
-- =============================================

DO $$
DECLARE
    tbl_name text;
    tables text[] := ARRAY['user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items'];
    index_name text;
    index_exists boolean;
    missing_indexes text := '';
BEGIN
    RAISE NOTICE '=== INDEX VALIDATION ===';
    
    FOREACH tbl_name IN ARRAY tables
    LOOP
        -- Check sync query index
        index_name := 'idx_' || tbl_name || '_sync_query';
        SELECT EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE indexname = index_name
            AND tablename = tbl_name
            AND schemaname = 'public'
        ) INTO index_exists;
        
        IF NOT index_exists THEN
            missing_indexes := missing_indexes || index_name || ' ';
        END IF;
        
        -- Check conflict detection index
        index_name := 'idx_' || tbl_name || '_conflict_detection';
        SELECT EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE indexname = index_name
            AND tablename = tbl_name
            AND schemaname = 'public'
        ) INTO index_exists;
        
        IF NOT index_exists THEN
            missing_indexes := missing_indexes || index_name || ' ';
        END IF;
    END LOOP;
    
    IF missing_indexes = '' THEN
        RAISE NOTICE '✅ All sync indexes are present';
    ELSE
        RAISE WARNING '❌ Missing indexes: %', missing_indexes;
    END IF;
END $$;

-- =============================================
-- VALIDATION 5: CHECK SYNC TABLES
-- =============================================

DO $$
DECLARE
    sync_status_exists boolean;
    sync_conflicts_exists boolean;
BEGIN
    RAISE NOTICE '=== SYNC TABLES VALIDATION ===';
    
    -- Check sync_status table
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'sync_status'
        AND table_schema = 'public'
    ) INTO sync_status_exists;
    
    -- Check sync_conflicts table
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'sync_conflicts'
        AND table_schema = 'public'
    ) INTO sync_conflicts_exists;
    
    IF sync_status_exists THEN
        RAISE NOTICE '✅ sync_status table exists';
    ELSE
        RAISE WARNING '❌ sync_status table missing';
    END IF;
    
    IF sync_conflicts_exists THEN
        RAISE NOTICE '✅ sync_conflicts table exists';
    ELSE
        RAISE WARNING '❌ sync_conflicts table missing';
    END IF;
END $$;

-- =============================================
-- VALIDATION 6: CHECK RLS POLICIES
-- =============================================

DO $$
DECLARE
    tbl_name text;
    tables text[] := ARRAY['user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items', 'sync_status', 'sync_conflicts'];
    rls_enabled boolean;
    missing_rls text := '';
BEGIN
    RAISE NOTICE '=== RLS VALIDATION ===';
    
    FOREACH tbl_name IN ARRAY tables
    LOOP
        SELECT relrowsecurity INTO rls_enabled
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relname = tbl_name
        AND n.nspname = 'public';
        
        IF COALESCE(rls_enabled, false) THEN
            RAISE NOTICE '✅ %: RLS enabled', tbl_name;
        ELSE
            RAISE WARNING '❌ %: RLS not enabled', tbl_name;
            missing_rls := missing_rls || tbl_name || ' ';
        END IF;
    END LOOP;
    
    IF missing_rls = '' THEN
        RAISE NOTICE '✅ RLS is enabled on all tables';
    ELSE
        RAISE WARNING '❌ RLS missing on tables: %', missing_rls;
    END IF;
END $$;

-- =============================================
-- FINAL SUMMARY
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '=== VALIDATION COMPLETE ===';
    RAISE NOTICE 'Review the output above for any warnings or errors.';
    RAISE NOTICE 'All ✅ marks indicate successful validation.';
    RAISE NOTICE 'All ❌ marks indicate issues that need to be fixed.';
END $$;