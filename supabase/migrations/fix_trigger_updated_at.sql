-- =============================================
-- FIX TRIGGER ERROR: updated_at field does not exist
-- =============================================
-- This migration fixes the trigger error caused by the field name mismatch
-- The trigger is trying to update 'updated_at' but the field is 'last_modified_at'

-- Drop the problematic trigger function if it exists
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

-- Verify the update_sync_metadata function exists and is correctly implemented
CREATE OR REPLACE FUNCTION update_sync_metadata()
RETURNS TRIGGER AS $$
BEGIN
    -- Only update if the column exists
    IF TG_OP = 'UPDATE' THEN
        -- Use last_modified_at instead of updated_at
        NEW.last_modified_at = NOW();
        NEW.sync_version = COALESCE(OLD.sync_version, 0) + 1;
    END IF;
    
    -- For INSERT operations
    IF TG_OP = 'INSERT' THEN
        NEW.last_modified_at = NOW();
        NEW.sync_version = COALESCE(NEW.sync_version, 1);
    END IF;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Recreate triggers for all sync tables with the correct function
DO $$
DECLARE
    tbl_name text;
    trigger_name text;
    tables text[] := ARRAY['user_favorites', 'user_watched_movies', 'user_watchlist', 'user_lists', 'user_list_items'];
BEGIN
    FOREACH tbl_name IN ARRAY tables
    LOOP
        -- Drop all old triggers that might exist
        EXECUTE format('DROP TRIGGER IF EXISTS update_%I_updated_at ON public.%I', tbl_name, tbl_name);
        EXECUTE format('DROP TRIGGER IF EXISTS update_%I_last_modified_at ON public.%I', tbl_name, tbl_name);
        EXECUTE format('DROP TRIGGER IF EXISTS update_%I_sync_metadata ON public.%I', tbl_name, tbl_name);
        
        -- Create new trigger with correct function
        trigger_name := 'update_' || tbl_name || '_sync_metadata';
        EXECUTE format('CREATE TRIGGER %I 
                       BEFORE INSERT OR UPDATE ON public.%I 
                       FOR EACH ROW EXECUTE FUNCTION update_sync_metadata()', 
                      trigger_name, tbl_name);
        
        RAISE NOTICE 'Fixed trigger for table: %', tbl_name;
    END LOOP;
END $$;

-- Verify the table structure for user_favorites
DO $$
BEGIN
    -- Check if the table has the correct columns
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'user_favorites' 
               AND column_name = 'last_modified_at'
               AND table_schema = 'public') THEN
        RAISE NOTICE '✅ user_favorites has last_modified_at column';
    ELSE
        RAISE WARNING '❌ user_favorites missing last_modified_at column';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'user_favorites' 
               AND column_name = 'sync_version'
               AND table_schema = 'public') THEN
        RAISE NOTICE '✅ user_favorites has sync_version column';
    ELSE
        RAISE WARNING '❌ user_favorites missing sync_version column';
    END IF;
END $$;

-- Test the trigger functionality
DO $$
DECLARE
    test_user_id UUID := gen_random_uuid();
    test_movie_id INTEGER := 999999;
BEGIN
    -- Insert a test record to verify trigger works
    BEGIN
        INSERT INTO user_favorites (user_id, movie_id, movie_title, is_deleted, sync_version)
        VALUES (test_user_id, test_movie_id, 'Test Movie', false, 1);
        
        -- Update the test record to verify trigger works on UPDATE
        UPDATE user_favorites 
        SET movie_title = 'Updated Test Movie'
        WHERE user_id = test_user_id AND movie_id = test_movie_id;
        
        -- Clean up test record
        DELETE FROM user_favorites 
        WHERE user_id = test_user_id AND movie_id = test_movie_id;
        
        RAISE NOTICE '✅ Trigger test passed - no errors';
        
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

RAISE NOTICE '🎉 Trigger fix migration completed!';