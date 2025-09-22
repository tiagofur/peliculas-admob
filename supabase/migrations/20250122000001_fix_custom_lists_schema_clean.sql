-- ==========================================
-- CLEAN SUPABASE SCHEMA FOR CUSTOM LISTS
-- ==========================================

-- 1. Drop existing tables (clean slate)
DROP TABLE IF EXISTS public.user_list_items CASCADE;
DROP TABLE IF EXISTS public.user_lists CASCADE;

-- 2. Create user_lists table
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

-- 3. Create user_list_items table
CREATE TABLE public.user_list_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    list_id UUID NOT NULL REFERENCES public.user_lists(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    movie_id INTEGER NOT NULL,
    movie_title VARCHAR(500) DEFAULT '',
    movie_poster_path TEXT DEFAULT '',
    position INTEGER DEFAULT 0,
    sync_version INTEGER NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_modified_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Create indexes
CREATE INDEX idx_user_lists_user_id ON public.user_lists(user_id);
CREATE INDEX idx_user_lists_sync ON public.user_lists(user_id, is_deleted, last_modified_at DESC);
CREATE INDEX idx_user_list_items_list_id ON public.user_list_items(list_id);
CREATE INDEX idx_user_list_items_user_id ON public.user_list_items(user_id);
CREATE INDEX idx_user_list_items_sync ON public.user_list_items(user_id, list_id, is_deleted, last_modified_at DESC);

-- Unique constraint
CREATE UNIQUE INDEX idx_user_list_items_unique
ON public.user_list_items(list_id, movie_id, user_id)
WHERE is_deleted = false;

-- 5. Enable RLS
ALTER TABLE public.user_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_list_items ENABLE ROW LEVEL SECURITY;

-- 6. Create policies
CREATE POLICY "Users manage their own lists" ON public.user_lists
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users manage their own list items" ON public.user_list_items
    FOR ALL USING (auth.uid() = user_id);

-- 7. Create update function
CREATE OR REPLACE FUNCTION update_last_modified_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_modified_at = NOW();
    NEW.sync_version = NEW.sync_version + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 8. Create triggers
CREATE TRIGGER user_lists_update_timestamp
    BEFORE UPDATE ON public.user_lists
    FOR EACH ROW
    EXECUTE FUNCTION update_last_modified_at();

CREATE TRIGGER user_list_items_update_timestamp
    BEFORE UPDATE ON public.user_list_items
    FOR EACH ROW
    EXECUTE FUNCTION update_last_modified_at();

-- 9. Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_lists;
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_list_items;