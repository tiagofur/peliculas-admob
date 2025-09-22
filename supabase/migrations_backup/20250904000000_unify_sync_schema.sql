-- =============================================
-- UNIFIED SYNC SCHEMA MIGRATION
-- =============================================
-- This migration standardizes all sync-related fields across tables
-- Created: 2025-09-04
-- Purpose: Fix schema inconsistencies for robust offline-first sync

-- =============================================
-- PHASE 1: STANDARDIZE SOFT DELETE FIELDS
-- =============================================

-- Fix user_watchlist: Change deleted_at to is_deleted (boolean)
DO $$
BEGIN
    -- Check if deleted_at exists and is_deleted doesn't exist
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'user_watchlist' 
               AND column_name = 'deleted_at' 
               AND table_schema = 'public')
    AND NOT EXISTS (SELECT 1 FROM information_schema.columns 
                    WHERE table_name = 'user_watchlist' 
                    AND column_name = 'is_deleted' 
                    AND table_schema = 'public') THEN
        
        -- Add is_deleted column
        ALTER TABLE public.user_watchlist 
        ADD COLUMN is_deleted BOOLEAN NOT NULL DEFAULT false;
        
        -- Migrate data: if deleted_at is not null, set is_deleted = true
        UPDATE public.user_watchlist 
        SET is_deleted = true 
        WHERE deleted_at IS NOT NULL;
        
        -- Drop the old column
        ALTER TABLE public.user_watchlist 
        DROP COLUMN deleted_at;
        
        RAISE NOTICE 'user_watchlist: Converted deleted_at to is_deleted';
    END IF;
END $$;

-- Ensure is_deleted exists in all sync tables
DO $$
DECLARE
    tbl_name text;
    tables text[] := ARRAY['user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items'];
BEGIN
    FOREACH tbl_name IN ARRAY tables
    LOOP
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                      WHERE table_name = tbl_name 
                      AND column_name = 'is_deleted' 
                      AND table_schema = 'public') THEN
            EXECUTE format('ALTER TABLE public.%I ADD COLUMN is_deleted BOOLEAN NOT NULL DEFAULT false', tbl_name);
            RAISE NOTICE '%: Added is_deleted column', tbl_name;
        END IF;
    END LOOP;
END $$;

-- =============================================
-- PHASE 2: STANDARDIZE TIMESTAMP FIELDS
-- =============================================

-- Rename updated_at to last_modified_at for all sync tables
DO $$
DECLARE
    tbl_name text;
    tables text[] := ARRAY['user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items'];
BEGIN
    FOREACH tbl_name IN ARRAY tables
    LOOP
        -- Check if updated_at exists and last_modified_at doesn't
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_name = tbl_name 
                  AND column_name = 'updated_at' 
                  AND table_schema = 'public')
        AND NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = tbl_name 
                       AND column_name = 'last_modified_at' 
                       AND table_schema = 'public') THEN
            EXECUTE format('ALTER TABLE public.%I RENAME COLUMN updated_at TO last_modified_at', tbl_name);
            RAISE NOTICE '%: Renamed updated_at to last_modified_at', tbl_name;
        END IF;
    END LOOP;
END $$;

-- =============================================
-- PHASE 3: ADD SYNC VERSION CONTROL
-- =============================================

-- Add sync_version to all tables for conflict resolution
DO $$
DECLARE
    tbl_name text;
    tables text[] := ARRAY['user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items'];
BEGIN
    FOREACH tbl_name IN ARRAY tables
    LOOP
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                      WHERE table_name = tbl_name 
                      AND column_name = 'sync_version' 
                      AND table_schema = 'public') THEN
            EXECUTE format('ALTER TABLE public.%I ADD COLUMN sync_version INTEGER NOT NULL DEFAULT 1', tbl_name);
            RAISE NOTICE '%: Added sync_version column', tbl_name;
        END IF;
    END LOOP;
END $$;

-- Add device_id for multi-device tracking
DO $$
DECLARE
    tbl_name text;
    tables text[] := ARRAY['user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items'];
BEGIN
    FOREACH tbl_name IN ARRAY tables
    LOOP
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                      WHERE table_name = tbl_name 
                      AND column_name = 'device_id' 
                      AND table_schema = 'public') THEN
            EXECUTE format('ALTER TABLE public.%I ADD COLUMN device_id VARCHAR(100)', tbl_name);
            RAISE NOTICE '%: Added device_id column', tbl_name;
        END IF;
    END LOOP;
END $$;

-- =============================================
-- PHASE 4: UPDATE TRIGGERS AND FUNCTIONS
-- =============================================

-- Create unified trigger function for last_modified_at and sync_version
CREATE OR REPLACE FUNCTION update_sync_metadata()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_modified_at = NOW();
    NEW.sync_version = COALESCE(OLD.sync_version, 0) + 1;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Drop old triggers and create new unified ones
DO $$
DECLARE
    tbl_name text;
    trigger_name text;
    tables text[] := ARRAY['user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items'];
BEGIN
    FOREACH tbl_name IN ARRAY tables
    LOOP
        -- Drop old triggers
        trigger_name := 'update_' || tbl_name || '_updated_at';
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I', trigger_name, tbl_name);
        
        trigger_name := 'update_' || tbl_name || '_last_modified_at';
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I', trigger_name, tbl_name);
        
        -- Create new unified trigger
        trigger_name := 'update_' || tbl_name || '_sync_metadata';
        EXECUTE format('CREATE TRIGGER %I BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION update_sync_metadata()', 
                      trigger_name, tbl_name);
        
        RAISE NOTICE '%: Updated sync metadata trigger', tbl_name;
    END LOOP;
END $$;

-- Drop old function
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS update_last_modified_at_column() CASCADE;

-- =============================================
-- PHASE 5: CREATE SYNC STATUS TABLE
-- =============================================

-- Table to track sync status per user and device
CREATE TABLE IF NOT EXISTS sync_status (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id VARCHAR(100) NOT NULL,
    table_name VARCHAR(50) NOT NULL,
    last_sync_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    sync_direction VARCHAR(10) CHECK (sync_direction IN ('pull', 'push', 'both')) DEFAULT 'both',
    is_syncing BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, device_id, table_name)
);

-- Enable RLS
ALTER TABLE sync_status ENABLE ROW LEVEL SECURITY;

-- Policies for sync_status
CREATE POLICY "Users can manage their own sync status" ON sync_status
    FOR ALL USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_sync_status_user_device ON sync_status(user_id, device_id);
CREATE INDEX IF NOT EXISTS idx_sync_status_table ON sync_status(table_name, last_sync_at DESC);

-- Grant permissions
GRANT ALL PRIVILEGES ON sync_status TO authenticated;

-- =============================================
-- PHASE 6: CREATE CONFLICT RESOLUTION TABLE
-- =============================================

-- Table to track conflicts during sync
CREATE TABLE IF NOT EXISTS sync_conflicts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    table_name VARCHAR(50) NOT NULL,
    record_id UUID NOT NULL,
    conflict_type VARCHAR(20) CHECK (conflict_type IN ('update', 'delete', 'concurrent')) NOT NULL,
    local_data JSONB,
    remote_data JSONB,
    resolution_strategy VARCHAR(20) CHECK (resolution_strategy IN ('local_wins', 'remote_wins', 'merge', 'manual')) DEFAULT 'remote_wins',
    is_resolved BOOLEAN DEFAULT false,
    resolved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE sync_conflicts ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view their own conflicts" ON sync_conflicts
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "System can manage conflicts" ON sync_conflicts
    FOR ALL USING (true);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_sync_conflicts_user ON sync_conflicts(user_id, is_resolved);
CREATE INDEX IF NOT EXISTS idx_sync_conflicts_table ON sync_conflicts(table_name, created_at DESC);

-- Grant permissions
GRANT ALL PRIVILEGES ON sync_conflicts TO authenticated;

-- =============================================
-- PHASE 7: UPDATE INDEXES FOR SYNC PERFORMANCE
-- =============================================

-- Add composite indexes for efficient sync queries
DO $$
DECLARE
    tbl_name text;
    user_tables text[] := ARRAY['user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists'];
BEGIN
    -- Add indexes for tables with user_id column
    FOREACH tbl_name IN ARRAY user_tables
    LOOP
        -- Index for sync queries (user + modification time + not deleted)
        EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%I_sync_query ON public.%I(user_id, last_modified_at DESC) WHERE is_deleted = false', 
                      tbl_name, tbl_name);
        
        -- Index for conflict detection (user + sync_version)
        EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%I_conflict_detection ON public.%I(user_id, sync_version DESC)', 
                      tbl_name, tbl_name);
        
        -- Index for device tracking
        EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%I_device_tracking ON public.%I(device_id, last_modified_at DESC) WHERE device_id IS NOT NULL', 
                      tbl_name, tbl_name);
        
        RAISE NOTICE '%: Added sync performance indexes', tbl_name;
    END LOOP;
    
    -- Special indexes for user_list_items (uses list_id instead of user_id)
    CREATE INDEX IF NOT EXISTS idx_user_list_items_sync_query ON public.user_list_items(list_id, last_modified_at DESC) WHERE is_deleted = false;
    CREATE INDEX IF NOT EXISTS idx_user_list_items_conflict_detection ON public.user_list_items(list_id, sync_version DESC);
    CREATE INDEX IF NOT EXISTS idx_user_list_items_device_tracking ON public.user_list_items(device_id, last_modified_at DESC) WHERE device_id IS NOT NULL;
    
    RAISE NOTICE 'user_list_items: Added sync performance indexes';
END $$;

-- =============================================
-- VERIFICATION AND COMMENTS
-- =============================================

-- Add comments for documentation
COMMENT ON COLUMN sync_status.sync_direction IS 'Direction of sync: pull (from server), push (to server), both';
COMMENT ON COLUMN sync_conflicts.resolution_strategy IS 'How conflicts should be resolved: local_wins, remote_wins, merge, manual';

-- Verification queries (these will be logged)
DO $$
DECLARE
    tbl_name text;
    tables text[] := ARRAY['user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items'];
    col_count integer;
BEGIN
    RAISE NOTICE '=== SCHEMA VERIFICATION ===';
    
    FOREACH tbl_name IN ARRAY tables
    LOOP
        -- Check required columns exist
        SELECT COUNT(*) INTO col_count
        FROM information_schema.columns 
        WHERE table_name = tbl_name 
        AND table_schema = 'public'
        AND column_name IN ('is_deleted', 'last_modified_at', 'sync_version', 'device_id');
        
        IF col_count = 4 THEN
            RAISE NOTICE '✅ %: All sync columns present', tbl_name;
        ELSE
            RAISE WARNING '❌ %: Missing sync columns (found %/4)', tbl_name, col_count;
        END IF;
    END LOOP;
    
    RAISE NOTICE '=== MIGRATION COMPLETED ===';
END $$;