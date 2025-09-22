-- Migration: Complete Custom Lists Fix
-- Date: 2025-01-22
-- Purpose: Fix custom lists and enable real-time sync

BEGIN;

-- ==========================================
-- 1. CLEAN UP LEGACY TABLES AND DATA
-- ==========================================

-- Drop all old policies first
DROP POLICY IF EXISTS "Users can manage items in their own lists" ON public.user_list_items;
DROP POLICY IF EXISTS "Users can manage their own list items" ON public.user_list_items;
DROP POLICY IF EXISTS "Public lists are viewable by anyone" ON public.user_list_items;
DROP POLICY IF EXISTS "Users can view and manage their own lists" ON public.user_lists;
DROP POLICY IF EXISTS "Public lists are viewable by anyone" ON public.user_lists;

-- Drop old indexes
DROP INDEX IF EXISTS idx_user_list_items_user_id;
DROP INDEX IF EXISTS idx_user_list_items_sync;
DROP INDEX IF EXISTS idx_user_list_items_user_sync;

-- ==========================================
-- 2. RECREATE USER_LISTS TABLE (CLEAN)
-- ==========================================

DROP TABLE IF EXISTS public.user_list_items CASCADE;
DROP TABLE IF EXISTS public.user_lists CASCADE;

CREATE TABLE public.user_lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT DEFAULT '',
    emoji VARCHAR(10) DEFAULT '📝',
    color_hex VARCHAR(7) DEFAULT '#2196F3',
    is_public BOOLEAN NOT NULL DEFAULT false,
    is_default BOOLEAN NOT NULL DEFAULT false,
    sync_version INTEGER NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_modified_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ==========================================
-- 3. CREATE USER_LIST_ITEMS TABLE (CLEAN)
-- ==========================================

CREATE TABLE public.user_list_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    list_id UUID NOT NULL REFERENCES public.user_lists(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    movie_id INTEGER NOT NULL,
    movie_title VARCHAR(500) DEFAULT '',
    movie_poster_path TEXT DEFAULT '',
    movie_backdrop_path TEXT DEFAULT '',
    position INTEGER DEFAULT 0,
    sync_version INTEGER NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_modified_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ==========================================
-- 4. CREATE PERFORMANCE INDEXES
-- ==========================================

-- Lists indexes
CREATE INDEX idx_user_lists_user_id ON public.user_lists(user_id);
CREATE INDEX idx_user_lists_sync ON public.user_lists(user_id, is_deleted, last_modified_at DESC);

-- Items indexes
CREATE INDEX idx_user_list_items_list_id ON public.user_list_items(list_id);
CREATE INDEX idx_user_list_items_user_id ON public.user_list_items(user_id);
CREATE INDEX idx_user_list_items_movie ON public.user_list_items(list_id, movie_id, is_deleted);
CREATE INDEX idx_user_list_items_sync ON public.user_list_items(user_id, list_id, is_deleted, last_modified_at DESC);

-- Unique constraint to prevent duplicates
CREATE UNIQUE INDEX idx_user_list_items_unique
ON public.user_list_items(list_id, movie_id, user_id)
WHERE is_deleted = false;

-- ==========================================
-- 5. ENABLE ROW LEVEL SECURITY
-- ==========================================

ALTER TABLE public.user_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_list_items ENABLE ROW LEVEL SECURITY;

-- ==========================================
-- 6. CREATE RLS POLICIES (SIMPLE AND SECURE)
-- ==========================================

-- User Lists Policies
CREATE POLICY "Users manage their own lists" ON public.user_lists
    FOR ALL USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- User List Items Policies
CREATE POLICY "Users manage their own list items" ON public.user_list_items
    FOR ALL USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ==========================================
-- 7. CREATE TRIGGERS FOR AUTO-UPDATE
-- ==========================================

-- Function to update last_modified_at
CREATE OR REPLACE FUNCTION update_last_modified_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_modified_at = NOW();
    NEW.sync_version = NEW.sync_version + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for both tables
CREATE TRIGGER user_lists_update_timestamp
    BEFORE UPDATE ON public.user_lists
    FOR EACH ROW
    EXECUTE FUNCTION update_last_modified_at();

CREATE TRIGGER user_list_items_update_timestamp
    BEFORE UPDATE ON public.user_list_items
    FOR EACH ROW
    EXECUTE FUNCTION update_last_modified_at();

-- ==========================================
-- 8. ENABLE REAL-TIME SYNC
-- ==========================================

-- Remove tables from realtime first (if they exist)
ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS public.user_lists;
ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS public.user_list_items;

-- Add tables to realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_lists;
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_list_items;

-- ==========================================
-- 9. ADD COMMENTS FOR DOCUMENTATION
-- ==========================================

COMMENT ON TABLE public.user_lists IS 'User custom lists for organizing movies';
COMMENT ON TABLE public.user_list_items IS 'Movies within user lists';

COMMENT ON COLUMN public.user_lists.sync_version IS 'Version for conflict resolution';
COMMENT ON COLUMN public.user_lists.is_deleted IS 'Soft deletion flag';
COMMENT ON COLUMN public.user_list_items.sync_version IS 'Version for conflict resolution';
COMMENT ON COLUMN public.user_list_items.is_deleted IS 'Soft deletion flag';

-- ==========================================
-- 10. VERIFY SETUP
-- ==========================================

-- Check tables exist
SELECT
    schemaname,
    tablename,
    tableowner
FROM pg_tables
WHERE tablename IN ('user_lists', 'user_list_items');

-- Check RLS is enabled
SELECT
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables
WHERE tablename IN ('user_lists', 'user_list_items');

-- Check policies exist
SELECT
    tablename,
    policyname,
    cmd
FROM pg_policies
WHERE tablename IN ('user_lists', 'user_list_items');

COMMIT;

-- Final success message
DO $$
BEGIN
    RAISE NOTICE '✅ Custom Lists schema fixed and real-time enabled!';
    RAISE NOTICE '📋 Tables: user_lists, user_list_items';
    RAISE NOTICE '🔒 RLS: Enabled with user-based policies';
    RAISE NOTICE '⚡ Real-time: Enabled for both tables';
    RAISE NOTICE '🚀 Ready for testing!';
END $$;