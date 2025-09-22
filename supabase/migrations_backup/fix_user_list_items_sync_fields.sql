-- Migration to add missing sync fields to user_list_items table
-- This fixes the issue where custom lists can't save properly

-- Add user_id field to user_list_items for direct user association
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_list_items' 
                   AND column_name = 'user_id' 
                   AND table_schema = 'public') THEN
        ALTER TABLE public.user_list_items 
        ADD COLUMN user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
        
        -- Update existing rows to set user_id based on the list owner
        UPDATE public.user_list_items 
        SET user_id = ul.user_id 
        FROM public.user_lists ul 
        WHERE ul.id = user_list_items.list_id;
        
        -- Make user_id NOT NULL after setting values
        ALTER TABLE public.user_list_items 
        ALTER COLUMN user_id SET NOT NULL;
    END IF;
END $$;

-- Add is_deleted field for soft deletion support
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_list_items' 
                   AND column_name = 'is_deleted' 
                   AND table_schema = 'public') THEN
        ALTER TABLE public.user_list_items 
        ADD COLUMN is_deleted BOOLEAN NOT NULL DEFAULT false;
    END IF;
END $$;

-- Add sync_version field for conflict resolution
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_list_items' 
                   AND column_name = 'sync_version' 
                   AND table_schema = 'public') THEN
        ALTER TABLE public.user_list_items 
        ADD COLUMN sync_version INTEGER NOT NULL DEFAULT 1;
    END IF;
END $$;

-- Ensure last_modified_at exists (should be renamed from updated_at by previous migration)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_list_items' 
                   AND column_name = 'last_modified_at' 
                   AND table_schema = 'public') THEN
        -- If updated_at still exists, rename it
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_list_items' 
                   AND column_name = 'updated_at' 
                   AND table_schema = 'public') THEN
            ALTER TABLE public.user_list_items 
            RENAME COLUMN updated_at TO last_modified_at;
        ELSE
            -- If neither exists, create last_modified_at
            ALTER TABLE public.user_list_items 
            ADD COLUMN last_modified_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        END IF;
    END IF;
END $$;

-- Create indexes for better query performance
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_list_items_user_id 
ON public.user_list_items(user_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_list_items_sync 
ON public.user_list_items(user_id, list_id, is_deleted, last_modified_at);

-- Update RLS policies to include user_id direct access
DROP POLICY IF EXISTS "Users can manage items in their own lists" ON public.user_list_items;
DROP POLICY IF EXISTS "Users can manage their own list items" ON public.user_list_items;

CREATE POLICY "Users can manage their own list items" ON public.user_list_items
    FOR ALL USING (auth.uid() = user_id);

-- Keep existing policy for public access
-- (Public list items policy should already exist from create_sync_tables.sql)

-- Add comment for documentation
COMMENT ON COLUMN public.user_list_items.user_id IS 'Direct reference to user for faster queries and RLS';
COMMENT ON COLUMN public.user_list_items.is_deleted IS 'Soft deletion flag for sync purposes';
COMMENT ON COLUMN public.user_list_items.sync_version IS 'Version number for conflict resolution';
COMMENT ON COLUMN public.user_list_items.last_modified_at IS 'Timestamp for sync ordering';