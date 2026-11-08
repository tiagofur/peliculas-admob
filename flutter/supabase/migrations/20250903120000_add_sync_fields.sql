-- Migration to add synchronization fields to existing tables

-- Alter user_watchlist
ALTER TABLE public.user_watchlist
  ADD COLUMN is_deleted BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.user_watchlist
  RENAME COLUMN updated_at TO last_modified_at;

-- Alter user_favorites
ALTER TABLE public.user_favorites
  ADD COLUMN is_deleted BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.user_favorites
  RENAME COLUMN updated_at TO last_modified_at;

-- Alter user_watched_movies
ALTER TABLE public.user_watched_movies
  ADD COLUMN is_deleted BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.user_watched_movies
  RENAME COLUMN updated_at TO last_modified_at;

-- Alter user_lists
ALTER TABLE public.user_lists
  ADD COLUMN is_deleted BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.user_lists
  RENAME COLUMN updated_at TO last_modified_at;

-- Alter user_list_items
ALTER TABLE public.user_list_items
  ADD COLUMN is_deleted BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.user_list_items
  RENAME COLUMN updated_at TO last_modified_at;

-- Update triggers to use last_modified_at
CREATE OR REPLACE FUNCTION update_last_modified_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_modified_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_user_watchlist_updated_at ON public.user_watchlist;
CREATE TRIGGER update_user_watchlist_last_modified_at BEFORE UPDATE ON public.user_watchlist
    FOR EACH ROW EXECUTE FUNCTION update_last_modified_at_column();

DROP TRIGGER IF EXISTS update_user_favorites_updated_at ON public.user_favorites;
CREATE TRIGGER update_user_favorites_last_modified_at BEFORE UPDATE ON public.user_favorites
    FOR EACH ROW EXECUTE FUNCTION update_last_modified_at_column();

DROP TRIGGER IF EXISTS update_user_watched_movies_updated_at ON public.user_watched_movies;
CREATE TRIGGER update_user_watched_movies_last_modified_at BEFORE UPDATE ON public.user_watched_movies
    FOR EACH ROW EXECUTE FUNCTION update_last_modified_at_column();

DROP TRIGGER IF EXISTS update_user_lists_updated_at ON public.user_lists;
CREATE TRIGGER update_user_lists_last_modified_at BEFORE UPDATE ON public.user_lists
    FOR EACH ROW EXECUTE FUNCTION update_last_modified_at_column();

DROP TRIGGER IF EXISTS update_user_list_items_updated_at ON public.user_list_items;
CREATE TRIGGER update_user_list_items_last_modified_at BEFORE UPDATE ON public.user_list_items
    FOR EACH ROW EXECUTE FUNCTION update_last_modified_at_column();

-- Drop old function
DROP FUNCTION IF EXISTS update_updated_at_column();
