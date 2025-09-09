-- Verificación de consolidación de triggers
-- Este archivo verifica que todos los triggers estén correctamente configurados

-- 1. Verificar que existen los triggers esperados
SELECT 
    'Triggers existentes:' as status,
    n.nspname as schema_name,
    c.relname as table_name,
    t.tgname as trigger_name,
    CASE 
        WHEN t.tgname LIKE '%update_sync_metadata%' THEN 'CORRECTO'
        ELSE 'REVISAR'
    END as validation_status
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public'
    AND c.relname IN ('user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items')
    AND NOT t.tgisinternal
ORDER BY c.relname, t.tgname;

-- 2. Verificar que existe la función unificada
SELECT 
    'Función update_sync_metadata:' as status,
    p.proname as function_name,
    CASE 
        WHEN p.proname = 'update_sync_metadata' THEN 'EXISTE'
        ELSE 'NO EXISTE'
    END as validation_status
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
    AND p.proname = 'update_sync_metadata';

-- 3. Verificar estructura de columnas de sincronización
SELECT 
    'Columnas de sincronización:' as status,
    table_name,
    column_name,
    data_type,
    CASE 
        WHEN column_name IN ('last_modified_at', 'sync_version', 'device_id', 'is_deleted') THEN 'CORRECTO'
        WHEN column_name = 'updated_at' THEN 'INCONSISTENTE - Debería ser last_modified_at'
        WHEN column_name = 'deleted_at' AND table_name NOT IN ('user_lists', 'user_list_items') THEN 'INCONSISTENTE - Debería usar is_deleted'
        ELSE 'REVISAR'
    END as validation_status
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name IN ('user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items')
    AND column_name IN ('updated_at', 'last_modified_at', 'sync_version', 'device_id', 'is_deleted', 'deleted_at')
ORDER BY table_name, column_name;

-- 4. Verificar que no existen funciones obsoletas
SELECT 
    'Funciones obsoletas encontradas:' as status,
    p.proname as function_name,
    'ELIMINAR' as action_needed
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
    AND p.proname IN ('update_updated_at_column', 'update_last_modified_at_column')
UNION ALL
SELECT 
    'Estado de limpieza:' as status,
    'Sin funciones obsoletas' as function_name,
    'CORRECTO' as action_needed
WHERE NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
        AND p.proname IN ('update_updated_at_column', 'update_last_modified_at_column')
);

-- 5. Resumen final
SELECT 
    '=== RESUMEN DE CONSOLIDACIÓN ===' as summary,
    (
        SELECT COUNT(*) 
        FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE n.nspname = 'public'
            AND c.relname IN ('user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items')
            AND NOT t.tgisinternal
            AND t.tgname LIKE '%update_sync_metadata%'
    ) as triggers_correctos,
    (
        SELECT COUNT(*) 
        FROM information_schema.columns
        WHERE table_schema = 'public'
            AND table_name IN ('user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items')
            AND column_name = 'updated_at'
    ) as columnas_inconsistentes,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'public' AND p.proname = 'update_sync_metadata'
        ) THEN 'FUNCIÓN UNIFICADA EXISTE'
        ELSE 'FUNCIÓN UNIFICADA FALTA'
    END as estado_funcion;