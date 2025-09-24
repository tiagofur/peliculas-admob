-- Migration to fix synchronization fields for tables that need them

-- Add is_deleted to user_watched_movies (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_watched_movies' 
                   AND column_name = 'is_deleted' 
                   AND table_schema = 'public') THEN
        ALTER TABLE public.user_watched_movies 
        ADD COLUMN is_deleted BOOLEAN NOT NULL DEFAULT false;
    END IF;
END $$;

-- Add is_deleted to user_watchlist (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_watchlist' 
                   AND column_name = 'is_deleted' 
                   AND table_schema = 'public') THEN
        ALTER TABLE public.user_watchlist 
        ADD COLUMN is_deleted BOOLEAN NOT NULL DEFAULT false;
    END IF;
END $$;

-- Rename updated_at to last_modified_at for user_watchlist (if column exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'user_watchlist' 
               AND column_name = 'updated_at' 
               AND table_schema = 'public') THEN
        ALTER TABLE public.user_watchlist 
        RENAME COLUMN updated_at TO last_modified_at;
    END IF;
END $$;

-- Rename updated_at to last_modified_at for user_favorites (if column exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'user_favorites' 
               AND column_name = 'updated_at' 
               AND table_schema = 'public') THEN
        ALTER TABLE public.user_favorites 
        RENAME COLUMN updated_at TO last_modified_at;
    END IF;
END $$;

-- Rename updated_at to last_modified_at for user_watched_movies (if column exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'user_watched_movies' 
               AND column_name = 'updated_at' 
               AND table_schema = 'public') THEN
        ALTER TABLE public.user_watched_movies 
        RENAME COLUMN updated_at TO last_modified_at;
    END IF;
END $$;

-- Rename updated_at to last_modified_at for user_lists (if column exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'user_lists' 
               AND column_name = 'updated_at' 
               AND table_schema = 'public') THEN
        ALTER TABLE public.user_lists 
        RENAME COLUMN updated_at TO last_modified_at;
    END IF;
END $$;

-- Rename updated_at to last_modified_at for user_list_items (if column exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'user_list_items' 
               AND column_name = 'updated_at' 
               AND table_schema = 'public') THEN
        ALTER TABLE public.user_list_items 
        RENAME COLUMN updated_at TO last_modified_at;
    END IF;
END $$;

-- Update triggers to use last_modified_at
CREATE OR REPLACE FUNCTION update_last_modified_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_modified_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Update triggers for all tables
DROP TRIGGER IF EXISTS update_user_watchlist_updated_at ON public.user_watchlist;
DROP TRIGGER IF EXISTS update_user_watchlist_last_modified_at ON public.user_watchlist;
CREATE TRIGGER update_user_watchlist_last_modified_at 
    BEFORE UPDATE ON public.user_watchlist
    FOR EACH ROW EXECUTE FUNCTION update_last_modified_at_column();

DROP TRIGGER IF EXISTS update_user_favorites_updated_at ON public.user_favorites;
DROP TRIGGER IF EXISTS update_user_favorites_last_modified_at ON public.user_favorites;
CREATE TRIGGER update_user_favorites_last_modified_at 
    BEFORE UPDATE ON public.user_favorites
    FOR EACH ROW EXECUTE FUNCTION update_last_modified_at_column();

DROP TRIGGER IF EXISTS update_user_watched_movies_updated_at ON public.user_watched_movies;
DROP TRIGGER IF EXISTS update_user_watched_movies_last_modified_at ON public.user_watched_movies;
CREATE TRIGGER update_user_watched_movies_last_modified_at 
    BEFORE UPDATE ON public.user_watched_movies
    FOR EACH ROW EXECUTE FUNCTION update_last_modified_at_column();

DROP TRIGGER IF EXISTS update_user_lists_updated_at ON public.user_lists;
DROP TRIGGER IF EXISTS update_user_lists_last_modified_at ON public.user_lists;
CREATE TRIGGER update_user_lists_last_modified_at 
    BEFORE UPDATE ON public.user_lists
    FOR EACH ROW EXECUTE FUNCTION update_last_modified_at_column();

DROP TRIGGER IF EXISTS update_user_list_items_updated_at ON public.user_list_items;
DROP TRIGGER IF EXISTS update_user_list_items_last_modified_at ON public.user_list_items;
CREATE TRIGGER update_user_list_items_last_modified_at 
    BEFORE UPDATE ON public.user_list_items
    FOR EACH ROW EXECUTE FUNCTION update_last_modified_at_column();

-- Drop old function with cascade to handle dependencies
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

-- Recreate trigger for deletion_history table if it exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables 
               WHERE table_name = 'deletion_history' 
               AND table_schema = 'public') THEN
        DROP TRIGGER IF EXISTS update_deletion_history_updated_at ON public.deletion_history;
        CREATE TRIGGER update_deletion_history_updated_at 
            BEFORE UPDATE ON public.deletion_history
            FOR EACH ROW EXECUTE FUNCTION update_last_modified_at_column();
    END IF;
END $$;