-- 🚀 HABILITAR RE-- Agregar tablas a la publicación real-time (usando IF NOT EXISTS para evitar errores)
-- Listas personalizadas
ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.user_lists;
ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.user_list_items;

-- Favoritos, watchlist y películas vistas
ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.user_favorites;
ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.user_watched_movies;  
ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.user_watchlist;N SUPABASE - Día 2
-- Este script habilita las suscripciones real-time para todas las tablas críticas

BEGIN;

-- 1. Verificar y habilitar publicación real-time si no existe
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
    ) THEN
        CREATE PUBLICATION supabase_realtime;
        RAISE NOTICE '✅ Publicación supabase_realtime creada';
    ELSE
        RAISE NOTICE '✅ Publicación supabase_realtime ya existe';
    END IF;
END $$;

-- 2. Agregar tablas a la publicación real-time (usando IF NOT EXISTS para evitar errores)
-- Listas personalizadas
ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.user_lists;
ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.user_list_items;

-- Favoritos, watchlist y películas vistas
ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.favorite_movies;
ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.watched_movies;  
ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.watchlist_movies;

-- Ratings y comentarios
ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.movie_ratings;

-- 3. Verificar que user_list_items tiene user_id (crítico para RLS)
DO $$
BEGIN
    -- Agregar user_id si no existe
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'user_list_items'
        AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.user_list_items
        ADD COLUMN user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
        RAISE NOTICE '✅ Columna user_id agregada a user_list_items';
    ELSE
        RAISE NOTICE '✅ Columna user_id ya existe en user_list_items';
    END IF;
END $$;

-- 4. Poblar user_id en user_list_items basándose en el owner de la lista
UPDATE public.user_list_items uli
SET user_id = ul.user_id
FROM public.user_lists ul
WHERE uli.list_id = ul.id
AND uli.user_id IS NULL;

-- 5. Hacer user_id NOT NULL si no lo es (con manejo de errores)
DO $$
BEGIN
    BEGIN
        ALTER TABLE public.user_list_items
        ALTER COLUMN user_id SET NOT NULL;
        RAISE NOTICE '✅ user_id establecido como NOT NULL en user_list_items';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '⚠️ No se pudo establecer user_id como NOT NULL: %', SQLERRM;
    END;
END $$;

-- 6. Crear índices optimizados para real-time (si no existen)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_list_items_user_sync
ON public.user_list_items(user_id, list_id, is_deleted, last_modified_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_lists_realtime
ON public.user_lists(user_id, is_deleted, last_modified_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_favorites_realtime
ON public.user_favorites(user_id, added_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_watched_movies_realtime
ON public.user_watched_movies(user_id, watched_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_watchlist_realtime
ON public.user_watchlist(user_id, added_at DESC);

-- 7. Verificar estado de real-time
DO $$
DECLARE
    table_count INTEGER;
BEGIN
    SELECT COUNT(*)
    FROM pg_publication_tables pt
    WHERE pt.pubname = 'supabase_realtime'
    AND pt.schemaname = 'public'
    AND pt.tablename IN ('user_lists', 'user_list_items', 'user_favorites', 'user_watched_movies', 'user_watchlist', 'movie_ratings')
    INTO table_count;
    
    RAISE NOTICE '✅ Total de tablas habilitadas para real-time: %', table_count;
    
    -- Mostrar tablas habilitadas
    RAISE NOTICE '📋 Tablas habilitadas para real-time:';
    FOR table_name IN 
        SELECT pt.tablename
        FROM pg_publication_tables pt
        WHERE pt.pubname = 'supabase_realtime'
        AND pt.schemaname = 'public'
        ORDER BY pt.tablename
    LOOP
        RAISE NOTICE '  - %', table_name;
    END LOOP;
END $$;

COMMIT;

-- 8. Script de verificación manual (ejecutar después del COMMIT)
/*
-- Para verificar que todo funciona, ejecuta esto por separado:

SELECT 
    pt.tablename,
    CASE 
        WHEN pt.tablename IS NOT NULL THEN '✅ Habilitada'
        ELSE '❌ No habilitada'
    END as realtime_status
FROM (
    VALUES 
        ('user_lists'),
        ('user_list_items'), 
        ('user_favorites'),
        ('user_watched_movies'),
        ('user_watchlist'),
        ('movie_ratings')
) AS expected_tables(table_name)
LEFT JOIN pg_publication_tables pt ON pt.tablename = table_name 
    AND pt.pubname = 'supabase_realtime' 
    AND pt.schemaname = 'public'
ORDER BY table_name;
*/