-- Fix user_watchlist table schema to match sync logic expectations

-- Drop existing constraints and indexes that reference deleted_at
DROP INDEX IF EXISTS idx_user_watchlist_user_movie;

-- Add is_deleted column if it doesn't exist
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

-- Convert deleted_at to is_deleted if deleted_at exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'user_watchlist' 
               AND column_name = 'deleted_at' 
               AND table_schema = 'public') THEN
        -- Update is_deleted based on deleted_at
        UPDATE public.user_watchlist 
        SET is_deleted = (deleted_at IS NOT NULL);
        
        -- Drop deleted_at column
        ALTER TABLE public.user_watchlist 
        DROP COLUMN deleted_at;
    END IF;
END $$;

-- Ensure last_modified_at column exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_watchlist' 
                   AND column_name = 'last_modified_at' 
                   AND table_schema = 'public') THEN
        -- If updated_at exists, rename it
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_watchlist' 
                   AND column_name = 'updated_at' 
                   AND table_schema = 'public') THEN
            ALTER TABLE public.user_watchlist 
            RENAME COLUMN updated_at TO last_modified_at;
        ELSE
            -- Add the column
            ALTER TABLE public.user_watchlist 
            ADD COLUMN last_modified_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        END IF;
    END IF;
END $$;

-- Recreate the unique index with is_deleted filter
CREATE UNIQUE INDEX idx_user_watchlist_user_movie 
ON user_watchlist(user_id, movie_id) 
WHERE is_deleted = false;

-- Update triggers to use last_modified_at
CREATE OR REPLACE FUNCTION update_last_modified_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_modified_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_user_watchlist_updated_at ON public.user_watchlist;
DROP TRIGGER IF EXISTS update_user_watchlist_last_modified_at ON public.user_watchlist;
CREATE TRIGGER update_user_watchlist_last_modified_at 
    BEFORE UPDATE ON public.user_watchlist
    FOR EACH ROW EXECUTE FUNCTION update_last_modified_at_column();

-- Update comments
COMMENT ON COLUMN user_watchlist.is_deleted IS 'Soft delete flag for synchronization (replaces deleted_at)';