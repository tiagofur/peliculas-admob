-- Diagnóstico de la tabla user_movie_ratings
-- Ejecuta este script en Supabase SQL Editor para ver el estado actual

-- =============================================
-- 1. VERIFICAR SI LA TABLA EXISTE
-- =============================================
SELECT 
    EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'user_movie_ratings'
    ) AS table_exists;

-- =============================================
-- 2. LISTAR TODAS LAS COLUMNAS Y SUS TIPOS
-- =============================================
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default,
    character_maximum_length
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'user_movie_ratings'
ORDER BY ordinal_position;

-- =============================================
-- 3. VERIFICAR COLUMNAS REQUERIDAS
-- =============================================
WITH required_columns AS (
    SELECT unnest(ARRAY[
        'id', 'user_id', 'movie_id', 'rating', 'movie_title',
        'created_at', 'rated_at', 'last_modified_at', 
        'sync_version', 'device_id', 'is_deleted'
    ]) AS column_name
),
existing_columns AS (
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'user_movie_ratings'
)
SELECT 
    rc.column_name,
    CASE 
        WHEN ec.column_name IS NOT NULL THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END AS status
FROM required_columns rc
LEFT JOIN existing_columns ec ON rc.column_name = ec.column_name
ORDER BY 
    CASE WHEN ec.column_name IS NULL THEN 0 ELSE 1 END,
    rc.column_name;

-- =============================================
-- 4. LISTAR ÍNDICES DE LA TABLA
-- =============================================
SELECT 
    i.relname AS index_name,
    a.attname AS column_name,
    am.amname AS index_type
FROM pg_class t
JOIN pg_index ix ON t.oid = ix.indrelid
JOIN pg_class i ON i.oid = ix.indexrelid
JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(ix.indkey)
JOIN pg_am am ON i.relam = am.oid
WHERE t.relname = 'user_movie_ratings'
AND t.relkind = 'r'
ORDER BY i.relname, a.attnum;

-- =============================================
-- 5. VERIFICAR POLÍTICAS RLS
-- =============================================
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'user_movie_ratings'
ORDER BY policyname;

-- =============================================
-- 6. VERIFICAR TRIGGERS
-- =============================================
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement,
    action_timing
FROM information_schema.triggers
WHERE event_object_table = 'user_movie_ratings'
ORDER BY trigger_name;

-- =============================================
-- 7. ESTADÍSTICAS DE LA TABLA
-- =============================================
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS indexes_size
FROM pg_tables
WHERE schemaname = 'public'
AND tablename = 'user_movie_ratings';

-- =============================================
-- 8. CONTAR REGISTROS (si la tabla existe y tiene datos)
-- =============================================
DO $$
DECLARE
    row_count INTEGER;
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'user_movie_ratings'
    ) THEN
        SELECT COUNT(*) INTO row_count FROM public.user_movie_ratings;
        RAISE NOTICE 'Total records in user_movie_ratings: %', row_count;
    ELSE
        RAISE NOTICE 'Table user_movie_ratings does not exist';
    END IF;
END $$;

-- =============================================
-- 9. MUESTRA DE DATOS (primeros 5 registros)
-- =============================================
SELECT * FROM public.user_movie_ratings
LIMIT 5;
