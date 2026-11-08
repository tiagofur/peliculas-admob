-- Migration: Add get_server_timestamp RPC function
-- Created: 2025-09-18
-- Purpose: Fix 404 error for server timestamp synchronization

-- Create the get_server_timestamp RPC function
CREATE OR REPLACE FUNCTION get_server_timestamp()
RETURNS timestamp with time zone
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT now();
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_server_timestamp() TO authenticated;

-- Grant execute permission to anon users (for guest mode)
GRANT EXECUTE ON FUNCTION get_server_timestamp() TO anon;

-- Add comment for documentation
COMMENT ON FUNCTION get_server_timestamp() IS 'Returns the current server timestamp for synchronization operations. Used by the mobile app to ensure consistent timestamps across devices.';

-- Verify the function works
DO $$
DECLARE
    test_timestamp timestamp with time zone;
BEGIN
    SELECT get_server_timestamp() INTO test_timestamp;
    RAISE NOTICE 'Server timestamp function created successfully. Test result: %', test_timestamp;
END $$;