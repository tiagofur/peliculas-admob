-- Query to check what user-related tables exist in your database
-- Run this FIRST to see what tables you have

SELECT
    tablename,
    schemaname
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename LIKE 'user_%'
ORDER BY tablename;

-- This will show you all tables that start with 'user_'
-- Use this information to determine which tables to include in the realtime publication
