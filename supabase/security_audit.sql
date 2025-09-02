-- =============================================
-- SECURITY AUDIT SCRIPT FOR PELICULAS APP
-- =============================================
-- This script audits all RLS policies and security settings
-- Run this in Supabase SQL Editor to get security report

-- 1. Check RLS status for all user tables
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled,
    hasrls as has_policies
FROM pg_tables 
WHERE tablename IN (
    'user_profiles', 
    'user_stats', 
    'user_favorites', 
    'user_watched_movies', 
    'user_lists', 
    'user_list_items',
    'user_watchlist',
    'user_movie_ratings'
)
ORDER BY tablename;

-- 2. List all policies for user tables with details
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as command_type,
    qual as using_expression,
    with_check as check_expression
FROM pg_policies 
WHERE tablename IN (
    'user_profiles', 
    'user_stats', 
    'user_favorites', 
    'user_watched_movies', 
    'user_lists', 
    'user_list_items',
    'user_watchlist',
    'user_movie_ratings'
)
ORDER BY tablename, policyname;

-- 3. Check storage bucket policies
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'objects' AND schemaname = 'storage'
ORDER BY policyname;

-- 4. Check table permissions for anon and authenticated roles
SELECT 
    schemaname,
    tablename,
    grantee,
    privilege_type,
    is_grantable
FROM information_schema.table_privileges 
WHERE table_name IN (
    'user_profiles', 
    'user_stats', 
    'user_favorites', 
    'user_watched_movies', 
    'user_lists', 
    'user_list_items',
    'user_watchlist',
    'user_movie_ratings'
)
AND grantee IN ('anon', 'authenticated', 'public')
ORDER BY table_name, grantee, privilege_type;

-- 5. Find tables without RLS enabled
SELECT 
    schemaname,
    tablename,
    'RLS_NOT_ENABLED' as security_issue
FROM pg_tables 
WHERE schemaname = 'public'
AND tablename LIKE 'user_%'
AND rowsecurity = false;

-- 6. Find policies using overly broad permissions
SELECT 
    tablename,
    policyname,
    'OVERLY_BROAD_POLICY' as security_issue,
    cmd as command_type
FROM pg_policies 
WHERE cmd = 'ALL'
AND tablename IN (
    'user_profiles', 
    'user_stats', 
    'user_favorites', 
    'user_watched_movies', 
    'user_lists', 
    'user_list_items',
    'user_watchlist',
    'user_movie_ratings'
);

-- 7. Check for missing DELETE policies
WITH table_policies AS (
    SELECT 
        tablename,
        array_agg(cmd) as commands
    FROM pg_policies 
    WHERE tablename IN (
        'user_profiles', 
        'user_stats', 
        'user_favorites', 
        'user_watched_movies', 
        'user_lists', 
        'user_list_items',
        'user_watchlist',
        'user_movie_ratings'
    )
    GROUP BY tablename
)
SELECT 
    tablename,
    'MISSING_DELETE_POLICY' as security_issue
FROM table_policies 
WHERE NOT ('DELETE' = ANY(commands) OR 'ALL' = ANY(commands));

-- 8. Check for excessive anon permissions
SELECT 
    table_name,
    privilege_type,
    'EXCESSIVE_ANON_PERMISSIONS' as security_issue
FROM information_schema.table_privileges 
WHERE grantee = 'anon'
AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE')
AND table_name IN (
    'user_profiles', 
    'user_stats', 
    'user_favorites', 
    'user_watched_movies', 
    'user_lists', 
    'user_list_items',
    'user_watchlist',
    'user_movie_ratings'
);

-- 9. Security functions audit
SELECT 
    routine_name,
    routine_type,
    security_type,
    'SECURITY_DEFINER_FUNCTION' as security_note
FROM information_schema.routines 
WHERE routine_schema = 'public'
AND security_type = 'DEFINER'
ORDER BY routine_name;

-- 10. Check for proper auth.uid() usage in policies
SELECT 
    tablename,
    policyname,
    CASE 
        WHEN qual LIKE '%auth.uid()%' THEN 'USES_AUTH_UID'
        ELSE 'MISSING_AUTH_UID_CHECK'
    END as auth_check_status,
    qual as policy_expression
FROM pg_policies 
WHERE tablename IN (
    'user_profiles', 
    'user_stats', 
    'user_favorites', 
    'user_watched_movies', 
    'user_lists', 
    'user_list_items',
    'user_watchlist',
    'user_movie_ratings'
)
ORDER BY tablename, policyname;