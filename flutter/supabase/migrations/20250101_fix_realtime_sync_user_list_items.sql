-- Migration: Fix Realtime Sync for user_list_items
-- Date: 2025-10-01
-- Description: Adds user_id column to user_list_items for better realtime filtering
--              and improves sync performance

-- Step 1: Add user_id column to user_list_items
ALTER TABLE public.user_list_items 
ADD COLUMN user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Step 2: Populate user_id from the parent list
UPDATE public.user_list_items 
SET user_id = ul.user_id 
FROM public.user_lists ul 
WHERE ul.id = user_list_items.list_id;

-- Step 3: Make user_id NOT NULL after populating data
ALTER TABLE public.user_list_items 
ALTER COLUMN user_id SET NOT NULL;

-- Step 4: Add index for better performance
CREATE INDEX IF NOT EXISTS idx_user_list_items_user_id 
ON public.user_list_items(user_id, last_modified_at DESC) 
WHERE is_deleted = false;

-- Step 5: Update RLS policy to use user_id directly
DROP POLICY IF EXISTS "Users can manage items in their own lists" ON user_list_items;

CREATE POLICY "Users can manage items in their own lists" ON user_list_items
    FOR ALL USING (auth.uid() = user_id);

-- Step 6: Create trigger to auto-populate user_id when inserting new items
CREATE OR REPLACE FUNCTION populate_list_item_user_id()
RETURNS TRIGGER AS $$
BEGIN
    -- Get user_id from the parent list
    SELECT user_id INTO NEW.user_id 
    FROM public.user_lists 
    WHERE id = NEW.list_id;
    
    -- If user_id is still null, raise an error
    IF NEW.user_id IS NULL THEN
        RAISE EXCEPTION 'Cannot determine user_id for list_id: %', NEW.list_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 7: Create trigger for INSERT operations
DROP TRIGGER IF EXISTS trigger_populate_list_item_user_id ON user_list_items;
CREATE TRIGGER trigger_populate_list_item_user_id
    BEFORE INSERT ON user_list_items
    FOR EACH ROW
    WHEN (NEW.user_id IS NULL)
    EXECUTE FUNCTION populate_list_item_user_id();

-- Step 8: Grant permissions
GRANT ALL ON public.user_list_items TO authenticated;
GRANT ALL ON public.user_list_items TO service_role;

-- Step 9: Verification
DO $$
DECLARE
    null_user_count INTEGER;
    total_items INTEGER;
BEGIN
    -- Count items without user_id
    SELECT COUNT(*) INTO null_user_count 
    FROM public.user_list_items 
    WHERE user_id IS NULL;
    
    -- Count total items
    SELECT COUNT(*) INTO total_items 
    FROM public.user_list_items;
    
    IF null_user_count = 0 THEN
        RAISE NOTICE '✅ All % user_list_items have user_id populated', total_items;
    ELSE
        RAISE WARNING '⚠️ Found % items without user_id out of % total', null_user_count, total_items;
    END IF;
    
    -- Verify index exists
    IF EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'user_list_items' 
        AND indexname = 'idx_user_list_items_user_id'
    ) THEN
        RAISE NOTICE '✅ Performance index created successfully';
    ELSE
        RAISE WARNING '⚠️ Performance index not found';
    END IF;
END $$;

-- Step 10: Add comment
COMMENT ON COLUMN user_list_items.user_id IS 'User ID copied from parent list for realtime filtering and RLS performance';