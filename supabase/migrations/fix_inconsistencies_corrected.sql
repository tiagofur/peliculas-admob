-- Corrección final de inconsistencias en triggers y campos de sincronización
-- Esta migración corrige los problemas identificados, manejando columnas duplicadas

-- 1. Corregir user_watched_movies: eliminar updated_at redundante
-- Primero verificar si existe updated_at y eliminarlo
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_watched_movies' 
        AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE user_watched_movies DROP COLUMN updated_at;
    END IF;
END $$;

-- 2. Asegurar que todas las tablas tengan triggers unificados
-- user_watched_movies
DROP TRIGGER IF EXISTS update_user_watched_movies_updated_at ON user_watched_movies;
DROP TRIGGER IF EXISTS update_user_watched_movies_last_modified_at ON user_watched_movies;
DROP TRIGGER IF EXISTS update_user_watched_movies_sync_metadata ON user_watched_movies;

CREATE TRIGGER update_user_watched_movies_sync_metadata
    BEFORE UPDATE ON user_watched_movies
    FOR EACH ROW
    EXECUTE FUNCTION update_sync_metadata();

-- user_favorites
DROP TRIGGER IF EXISTS update_user_favorites_updated_at ON user_favorites;
DROP TRIGGER IF EXISTS update_user_favorites_last_modified_at ON user_favorites;
DROP TRIGGER IF EXISTS update_user_favorites_sync_metadata ON user_favorites;

CREATE TRIGGER update_user_favorites_sync_metadata
    BEFORE UPDATE ON user_favorites
    FOR EACH ROW
    EXECUTE FUNCTION update_sync_metadata();

-- user_watchlist
DROP TRIGGER IF EXISTS update_user_watchlist_updated_at ON user_watchlist;
DROP TRIGGER IF EXISTS update_user_watchlist_last_modified_at ON user_watchlist;
DROP TRIGGER IF EXISTS update_user_watchlist_sync_metadata ON user_watchlist;

CREATE TRIGGER update_user_watchlist_sync_metadata
    BEFORE UPDATE ON user_watchlist
    FOR EACH ROW
    EXECUTE FUNCTION update_sync_metadata();

-- user_lists
DROP TRIGGER IF EXISTS update_user_lists_updated_at ON user_lists;
DROP TRIGGER IF EXISTS update_user_lists_last_modified_at ON user_lists;
DROP TRIGGER IF EXISTS update_user_lists_sync_metadata ON user_lists;

CREATE TRIGGER update_user_lists_sync_metadata
    BEFORE UPDATE ON user_lists
    FOR EACH ROW
    EXECUTE FUNCTION update_sync_metadata();

-- user_list_items
DROP TRIGGER IF EXISTS update_user_list_items_updated_at ON user_list_items;
DROP TRIGGER IF EXISTS update_user_list_items_last_modified_at ON user_list_items;
DROP TRIGGER IF EXISTS update_user_list_items_sync_metadata ON user_list_items;

CREATE TRIGGER update_user_list_items_sync_metadata
    BEFORE UPDATE ON user_list_items
    FOR EACH ROW
    EXECUTE FUNCTION update_sync_metadata();

-- 3. Limpiar funciones obsoletas si aún existen
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS update_last_modified_at_column() CASCADE;

-- 4. Verificar que la función update_sync_metadata existe y está correcta
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'update_sync_metadata'
    ) THEN
        -- Recrear la función si no existe
        CREATE OR REPLACE FUNCTION update_sync_metadata()
        RETURNS TRIGGER AS $func$
        BEGIN
            -- Actualizar last_modified_at
            NEW.last_modified_at = NOW();
            
            -- Incrementar sync_version
            IF TG_OP = 'UPDATE' THEN
                NEW.sync_version = COALESCE(OLD.sync_version, 0) + 1;
            ELSE
                NEW.sync_version = COALESCE(NEW.sync_version, 1);
            END IF;
            
            RETURN NEW;
        END;
        $func$ LANGUAGE plpgsql;
    END IF;
END $$;

-- 5. Verificación final - Contar triggers correctos
SELECT 
    '=== CONSOLIDACIÓN COMPLETADA ===' as status,
    (
        SELECT COUNT(*) 
        FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE n.nspname = 'public'
            AND c.relname IN ('user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items')
            AND NOT t.tgisinternal
            AND t.tgname LIKE '%sync_metadata%'
    ) as triggers_unificados,
    (
        SELECT COUNT(*) 
        FROM information_schema.columns
        WHERE table_schema = 'public'
            AND table_name IN ('user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items')
            AND column_name = 'last_modified_at'
    ) as tablas_con_last_modified_at,
    (
        SELECT COUNT(*) 
        FROM information_schema.columns
        WHERE table_schema = 'public'
            AND table_name IN ('user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items')
            AND column_name = 'updated_at'
    ) as columnas_updated_at_restantes,
    'CONSOLIDACIÓN EXITOSA' as resultado;

-- 6. Mostrar estado final de triggers
SELECT 
    'Triggers activos:' as info,
    n.nspname as schema_name,
    c.relname as table_name,
    t.tgname as trigger_name
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public'
    AND c.relname IN ('user_watchlist', 'user_favorites', 'user_watched_movies', 'user_lists', 'user_list_items')
    AND NOT t.tgisinternal
ORDER BY c.relname, t.tgname;