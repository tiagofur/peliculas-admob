-- =============================================
-- FIX USER_LISTS SCHEMA FOR CUSTOM LISTS FEATURE
-- =============================================
-- This migration adds missing columns to user_lists table
-- to support the custom lists feature with emoji, color, etc.

-- =============================================
-- PHASE 1: ADD MISSING COLUMNS TO user_lists
-- =============================================

-- Add emoji column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_lists' 
                   AND column_name = 'emoji' 
                   AND table_schema = 'public') THEN
        ALTER TABLE public.user_lists 
        ADD COLUMN emoji VARCHAR(10) DEFAULT '📝';
        RAISE NOTICE 'user_lists: Added emoji column';
    END IF;
END $$;

-- Add color column if it doesn't exist (rename color_hex to color for consistency)
DO $$
BEGIN
    -- First check if color_hex exists and color doesn't
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'user_lists' 
               AND column_name = 'color_hex' 
               AND table_schema = 'public')
    AND NOT EXISTS (SELECT 1 FROM information_schema.columns 
                    WHERE table_name = 'user_lists' 
                    AND column_name = 'color' 
                    AND table_schema = 'public') THEN
        -- Rename color_hex to color
        ALTER TABLE public.user_lists 
        RENAME COLUMN color_hex TO color;
        RAISE NOTICE 'user_lists: Renamed color_hex to color';
    ELSIF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                      WHERE table_name = 'user_lists' 
                      AND column_name = 'color' 
                      AND table_schema = 'public') 
    AND NOT EXISTS (SELECT 1 FROM information_schema.columns 
                    WHERE table_name = 'user_lists' 
                    AND column_name = 'color_hex' 
                    AND table_schema = 'public') THEN
        -- Add color column if neither exists
        ALTER TABLE public.user_lists 
        ADD COLUMN color VARCHAR(20) DEFAULT 'blue';
        RAISE NOTICE 'user_lists: Added color column';
    END IF;
END $$;

-- Add is_default column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_lists' 
                   AND column_name = 'is_default' 
                   AND table_schema = 'public') THEN
        ALTER TABLE public.user_lists 
        ADD COLUMN is_default BOOLEAN NOT NULL DEFAULT false;
        RAISE NOTICE 'user_lists: Added is_default column';
    END IF;
END $$;

-- Ensure created_at exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_lists' 
                   AND column_name = 'created_at' 
                   AND table_schema = 'public') THEN
        ALTER TABLE public.user_lists 
        ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        RAISE NOTICE 'user_lists: Added created_at column';
    END IF;
END $$;

-- Ensure last_modified_at exists (may have been added by previous migrations)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_lists' 
                   AND column_name = 'last_modified_at' 
                   AND table_schema = 'public') THEN
        -- Check if updated_at exists first
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_lists' 
                   AND column_name = 'updated_at' 
                   AND table_schema = 'public') THEN
            -- Rename updated_at to last_modified_at
            ALTER TABLE public.user_lists 
            RENAME COLUMN updated_at TO last_modified_at;
            RAISE NOTICE 'user_lists: Renamed updated_at to last_modified_at';
        ELSE
            -- Add last_modified_at column
            ALTER TABLE public.user_lists 
            ADD COLUMN last_modified_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
            RAISE NOTICE 'user_lists: Added last_modified_at column';
        END IF;
    END IF;
END $$;

-- Add sync_version column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_lists' 
                   AND column_name = 'sync_version' 
                   AND table_schema = 'public') THEN
        ALTER TABLE public.user_lists 
        ADD COLUMN sync_version INTEGER NOT NULL DEFAULT 1;
        RAISE NOTICE 'user_lists: Added sync_version column';
    END IF;
END $$;

-- Add device_id column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_lists' 
                   AND column_name = 'device_id' 
                   AND table_schema = 'public') THEN
        ALTER TABLE public.user_lists 
        ADD COLUMN device_id VARCHAR(100);
        RAISE NOTICE 'user_lists: Added device_id column';
    END IF;
END $$;

-- =============================================
-- PHASE 2: ADD MISSING COLUMNS TO user_list_items
-- =============================================

-- Add added_at column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_list_items' 
                   AND column_name = 'added_at' 
                   AND table_schema = 'public') THEN
        ALTER TABLE public.user_list_items 
        ADD COLUMN added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        RAISE NOTICE 'user_list_items: Added added_at column';
    END IF;
END $$;

-- Add last_modified_at column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_list_items' 
                   AND column_name = 'last_modified_at' 
                   AND table_schema = 'public') THEN
        -- Check if updated_at exists first
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_list_items' 
                   AND column_name = 'updated_at' 
                   AND table_schema = 'public') THEN
            -- Rename updated_at to last_modified_at
            ALTER TABLE public.user_list_items 
            RENAME COLUMN updated_at TO last_modified_at;
            RAISE NOTICE 'user_list_items: Renamed updated_at to last_modified_at';
        ELSE
            -- Add last_modified_at column
            ALTER TABLE public.user_list_items 
            ADD COLUMN last_modified_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
            RAISE NOTICE 'user_list_items: Added last_modified_at column';
        END IF;
    END IF;
END $$;

-- Add sync_version column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_list_items' 
                   AND column_name = 'sync_version' 
                   AND table_schema = 'public') THEN
        ALTER TABLE public.user_list_items 
        ADD COLUMN sync_version INTEGER NOT NULL DEFAULT 1;
        RAISE NOTICE 'user_list_items: Added sync_version column';
    END IF;
END $$;

-- Add device_id column if it doesn't exist  
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_list_items' 
                   AND column_name = 'device_id' 
                   AND table_schema = 'public') THEN
        ALTER TABLE public.user_list_items 
        ADD COLUMN device_id VARCHAR(100);
        RAISE NOTICE 'user_list_items: Added device_id column';
    END IF;
END $$;

-- =============================================
-- PHASE 3: CREATE OR UPDATE TRIGGERS
-- =============================================

-- Create or replace function for updating last_modified_at and sync_version
CREATE OR REPLACE FUNCTION update_sync_metadata()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_modified_at = NOW();
    NEW.sync_version = COALESCE(OLD.sync_version, 0) + 1;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Drop old triggers and create new ones for user_lists
DO $$
BEGIN
    -- Drop old triggers if they exist
    DROP TRIGGER IF EXISTS update_user_lists_updated_at ON public.user_lists;
    DROP TRIGGER IF EXISTS update_user_lists_last_modified_at ON public.user_lists;
    DROP TRIGGER IF EXISTS update_user_lists_sync_metadata ON public.user_lists;
    
    -- Create new trigger
    CREATE TRIGGER update_user_lists_sync_metadata 
        BEFORE UPDATE ON public.user_lists
        FOR EACH ROW EXECUTE FUNCTION update_sync_metadata();
    
    RAISE NOTICE 'user_lists: Updated sync metadata trigger';
END $$;

-- Drop old triggers and create new ones for user_list_items  
DO $$
BEGIN
    -- Drop old triggers if they exist
    DROP TRIGGER IF EXISTS update_user_list_items_updated_at ON public.user_list_items;
    DROP TRIGGER IF EXISTS update_user_list_items_last_modified_at ON public.user_list_items;
    DROP TRIGGER IF EXISTS update_user_list_items_sync_metadata ON public.user_list_items;
    
    -- Create new trigger
    CREATE TRIGGER update_user_list_items_sync_metadata 
        BEFORE UPDATE ON public.user_list_items
        FOR EACH ROW EXECUTE FUNCTION update_sync_metadata();
    
    RAISE NOTICE 'user_list_items: Updated sync metadata trigger';
END $$;

-- =============================================
-- PHASE 4: ENSURE REALTIME IS ENABLED
-- =============================================

-- Make sure both tables are in the realtime publication
DO $$
BEGIN
    -- Add user_lists to realtime publication if not already there
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE user_lists;
        RAISE NOTICE 'user_lists: Added to supabase_realtime publication';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'user_lists: Already in supabase_realtime publication';
    END;
    
    -- Add user_list_items to realtime publication if not already there
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE user_list_items;
        RAISE NOTICE 'user_list_items: Added to supabase_realtime publication';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'user_list_items: Already in supabase_realtime publication';
    END;
END $$;

-- Set replica identity to FULL for both tables
ALTER TABLE public.user_lists REPLICA IDENTITY FULL;
ALTER TABLE public.user_list_items REPLICA IDENTITY FULL;

-- =============================================
-- VERIFICATION QUERIES
-- =============================================

DO $$
DECLARE
    lists_col_count integer;
    items_col_count integer;
    required_lists_cols text[] := ARRAY['id', 'user_id', 'name', 'description', 'emoji', 'color', 'is_default', 'created_at', 'last_modified_at', 'is_deleted', 'sync_version', 'device_id'];
    required_items_cols text[] := ARRAY['list_id', 'movie_id', 'added_at', 'last_modified_at', 'is_deleted', 'sync_version', 'device_id'];
BEGIN
    RAISE NOTICE '=== SCHEMA VERIFICATION ===';
    
    -- Check user_lists columns
    SELECT COUNT(*) INTO lists_col_count
    FROM information_schema.columns 
    WHERE table_name = 'user_lists' 
    AND table_schema = 'public'
    AND column_name = ANY(required_lists_cols);
    
    IF lists_col_count = array_length(required_lists_cols, 1) THEN
        RAISE NOTICE '✅ user_lists: All required columns present (%/12)', lists_col_count;
    ELSE
        RAISE WARNING '❌ user_lists: Missing columns (found %/12)', lists_col_count;
    END IF;
    
    -- Check user_list_items columns
    SELECT COUNT(*) INTO items_col_count
    FROM information_schema.columns 
    WHERE table_name = 'user_list_items' 
    AND table_schema = 'public'
    AND column_name = ANY(required_items_cols);
    
    IF items_col_count = array_length(required_items_cols, 1) THEN
        RAISE NOTICE '✅ user_list_items: All required columns present (%/7)', items_col_count;
    ELSE
        RAISE WARNING '❌ user_list_items: Missing columns (found %/7)', items_col_count;
    END IF;
    
    RAISE NOTICE '=== MIGRATION COMPLETED ===';
END $$;