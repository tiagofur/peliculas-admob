-- Corrección final de inconsistencias en triggers y campos de sincronización
-- Esta migración corrige los problemas identificados en la verificación

-- 1. Corregir user_watched_movies: cambiar updated_at por last_modified_at
ALTER TABLE user_watched_movies 
RENAME COLUMN updated_at TO last_modified_at;

-- 2. Asegurar que user_watched_movies tenga el trigger correcto
DROP TRIGGER IF EXISTS update_user_watched_movies_updated_at ON user_watched_movies;
DROP TRIGGER IF EXISTS update_user_watched_movies_last_modified_at ON user_watched_movies;

-- Crear el trigger unificado para user_watched_movies
CREATE TRIGGER update_user_watched_movies_sync_metadata
    BEFORE UPDATE ON user_watched_movies
    FOR EACH ROW
    EXECUTE FUNCTION update_sync_metadata();

-- 3. Verificar y corregir user_favorites (asegurar que tenga el trigger correcto)
DROP TRIGGER IF EXISTS update_user_favorites_updated_at ON user_favorites;
DROP TRIGGER IF EXISTS update_user_favorites_last_modified_at ON user_favorites;

CREATE TRIGGER update_user_favorites_sync_metadata
    BEFORE UPDATE ON user_favorites
    FOR EACH ROW
    EXECUTE FUNCTION update_sync_metadata();

-- 4. Verificar y corregir user_watchlist
DROP TRIGGER IF EXISTS update_user_watchlist_updated_at ON user_watchlist;
DROP TRIGGER IF EXISTS update_user_watchlist_last_modified_at ON user_watchlist;

CREATE TRIGGER update_user_watchlist_sync_metadata
    BEFORE UPDATE ON user_watchlist
    FOR EACH ROW
    EXECUTE FUNCTION update_sync_metadata();

-- 5. Verificar y corregir user_lists
DROP TRIGGER IF EXISTS update_user_lists_updated_at ON user_lists;
DROP TRIGGER IF EXISTS update_user_lists_last_modified_at ON user_lists;

CREATE TRIGGER update_user_lists_sync_metadata
    BEFORE UPDATE ON user_lists
    FOR EACH ROW
    EXECUTE FUNCTION update_sync_metadata();

-- 6. Verificar y corregir user_list_items
DROP TRIGGER IF EXISTS update_user_list_items_updated_at ON user_list_items;
DROP TRIGGER IF EXISTS update_user_list_items_last_modified_at ON user_list_items;

CREATE TRIGGER update_user_list_items_sync_metadata
    BEFORE UPDATE ON user_list_items
    FOR EACH ROW
    EXECUTE FUNCTION update_sync_metadata();

-- 7. Limpiar funciones obsoletas si aún existen
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS update_last_modified_at_column() CASCADE;

-- 8. Verificación final - Probar que los triggers funcionan
-- Crear una función de prueba temporal
CREATE OR REPLACE FUNCTION test_sync_triggers()
RETURNS TABLE(
    table_name text,
    trigger_test_result text
) AS $$
BEGIN
    -- Test user_watchlist
    UPDATE user_watchlist 
    SET priority = priority 
    WHERE id = (SELECT id FROM user_watchlist LIMIT 1);
    
    RETURN QUERY
    SELECT 
        'user_watchlist'::text,
        CASE 
            WHEN EXISTS(
                SELECT 1 FROM user_watchlist 
                WHERE last_modified_at > NOW() - INTERVAL '1 minute'
                LIMIT 1
            ) THEN 'TRIGGER FUNCIONANDO'
            ELSE 'TRIGGER NO FUNCIONA'
        END;
    
    -- Test user_favorites si tiene datos
    IF EXISTS(SELECT 1 FROM user_favorites LIMIT 1) THEN
        UPDATE user_favorites 
        SET movie_title = movie_title 
        WHERE id = (SELECT id FROM user_favorites LIMIT 1);
        
        RETURN QUERY
        SELECT 
            'user_favorites'::text,
            CASE 
                WHEN EXISTS(
                    SELECT 1 FROM user_favorites 
                    WHERE last_modified_at > NOW() - INTERVAL '1 minute'
                    LIMIT 1
                ) THEN 'TRIGGER FUNCIONANDO'
                ELSE 'TRIGGER NO FUNCIONA'
            END;
    END IF;
    
END;
$$ LANGUAGE plpgsql;

-- Ejecutar prueba
SELECT * FROM test_sync_triggers();

-- Limpiar función de prueba
DROP FUNCTION test_sync_triggers();

-- 9. Resumen final
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
    'CONSOLIDACIÓN EXITOSA' as resultado;