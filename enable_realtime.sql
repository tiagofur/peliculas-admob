-- EXECUTE THIS ON SUPABASE TO ENABLE REALTIME
-- Connect to: fyzujpifkzftweynrudh.supabase.co

-- Enable realtime for user_favorites table specifically
ALTER TABLE public.user_favorites REPLICA IDENTITY FULL;

-- Create/Update publication for realtime
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE user_favorites;

-- Verify configuration
SELECT 
    schemaname,
    tablename,
    pubname
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime';

-- Check replica identity
SELECT 
    c.relname as table_name,
    CASE c.relreplident
        WHEN 'd' THEN 'DEFAULT'
        WHEN 'n' THEN 'NOTHING'
        WHEN 'f' THEN 'FULL'
        WHEN 'i' THEN 'INDEX'
    END as replica_identity
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relname = 'user_favorites' 
AND n.nspname = 'public';