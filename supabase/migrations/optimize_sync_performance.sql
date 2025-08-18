-- Optimización de rendimiento para sincronización
-- Índices adicionales para mejorar consultas de sincronización

-- Índices compuestos para consultas de sincronización por usuario y timestamp
CREATE INDEX IF NOT EXISTS idx_user_favorites_sync 
    ON user_favorites(user_id, updated_at DESC, movie_id);

CREATE INDEX IF NOT EXISTS idx_user_watched_sync 
    ON user_watched_movies(user_id, updated_at DESC, movie_id);

CREATE INDEX IF NOT EXISTS idx_user_lists_sync 
    ON user_lists(user_id, updated_at DESC, id);

CREATE INDEX IF NOT EXISTS idx_user_list_items_sync 
    ON user_list_items(list_id, updated_at DESC, movie_id);

-- Índices para consultas de paginación
CREATE INDEX IF NOT EXISTS idx_user_favorites_pagination 
    ON user_favorites(user_id, added_at DESC, id);

CREATE INDEX IF NOT EXISTS idx_user_watched_pagination 
    ON user_watched_movies(user_id, watched_at DESC, id);

CREATE INDEX IF NOT EXISTS idx_user_lists_pagination 
    ON user_lists(user_id, created_at DESC, id);

-- Índices para búsquedas por película
CREATE INDEX IF NOT EXISTS idx_user_favorites_movie_search 
    ON user_favorites(movie_id, user_id) WHERE movie_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_user_watched_movie_search 
    ON user_watched_movies(movie_id, user_id) WHERE movie_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_user_list_items_movie_search 
    ON user_list_items(movie_id, list_id) WHERE movie_id IS NOT NULL;

-- Índices para listas públicas
CREATE INDEX IF NOT EXISTS idx_user_lists_public 
    ON user_lists(is_public, created_at DESC) WHERE is_public = true;

-- Índices para estadísticas de usuario
CREATE INDEX IF NOT EXISTS idx_user_stats_updated 
    ON user_stats(updated_at DESC, user_id);

-- Función para obtener cambios recientes de favoritos
CREATE OR REPLACE FUNCTION get_user_favorites_since(
    p_user_id UUID,
    p_since TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    id UUID,
    movie_id INTEGER,
    movie_title VARCHAR(255),
    movie_poster_path TEXT,
    movie_backdrop_path TEXT,
    movie_overview TEXT,
    movie_release_date DATE,
    movie_vote_average DECIMAL(3,1),
    added_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        f.id,
        f.movie_id,
        f.movie_title,
        f.movie_poster_path,
        f.movie_backdrop_path,
        f.movie_overview,
        f.movie_release_date,
        f.movie_vote_average,
        f.added_at,
        f.updated_at
    FROM user_favorites f
    WHERE f.user_id = p_user_id
        AND (p_since IS NULL OR f.updated_at > p_since)
    ORDER BY f.updated_at DESC
    LIMIT p_limit;
END;
$$;

-- Función para obtener cambios recientes de películas vistas
CREATE OR REPLACE FUNCTION get_user_watched_since(
    p_user_id UUID,
    p_since TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    id UUID,
    movie_id INTEGER,
    movie_title VARCHAR(255),
    movie_poster_path TEXT,
    movie_backdrop_path TEXT,
    movie_overview TEXT,
    movie_release_date DATE,
    movie_vote_average DECIMAL(3,1),
    watched_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        w.id,
        w.movie_id,
        w.movie_title,
        w.movie_poster_path,
        w.movie_backdrop_path,
        w.movie_overview,
        w.movie_release_date,
        w.movie_vote_average,
        w.watched_at,
        w.updated_at
    FROM user_watched_movies w
    WHERE w.user_id = p_user_id
        AND (p_since IS NULL OR w.updated_at > p_since)
    ORDER BY w.updated_at DESC
    LIMIT p_limit;
END;
$$;

-- Función para obtener listas con cambios recientes
CREATE OR REPLACE FUNCTION get_user_lists_since(
    p_user_id UUID,
    p_since TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    id UUID,
    name VARCHAR(100),
    description TEXT,
    color_hex VARCHAR(7),
    is_public BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    items_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.id,
        l.name,
        l.description,
        l.color_hex,
        l.is_public,
        l.created_at,
        l.updated_at,
        COALESCE(item_counts.count, 0) as items_count
    FROM user_lists l
    LEFT JOIN (
        SELECT list_id, COUNT(*) as count
        FROM user_list_items
        GROUP BY list_id
    ) item_counts ON l.id = item_counts.list_id
    WHERE l.user_id = p_user_id
        AND (p_since IS NULL OR l.updated_at > p_since)
    ORDER BY l.updated_at DESC
    LIMIT p_limit;
END;
$$;

-- Función para obtener items de lista con cambios recientes
CREATE OR REPLACE FUNCTION get_list_items_since(
    p_list_id UUID,
    p_since TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    id UUID,
    movie_id INTEGER,
    movie_title VARCHAR(255),
    movie_poster_path TEXT,
    movie_backdrop_path TEXT,
    movie_overview TEXT,
    movie_release_date DATE,
    movie_vote_average DECIMAL(3,1),
    "position" INTEGER,
    added_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        i.id,
        i.movie_id,
        i.movie_title,
        i.movie_poster_path,
        i.movie_backdrop_path,
        i.movie_overview,
        i.movie_release_date,
        i.movie_vote_average,
        i.position,
        i.added_at,
        i.updated_at
    FROM user_list_items i
    WHERE i.list_id = p_list_id
        AND (p_since IS NULL OR i.updated_at > p_since)
    ORDER BY i."position" ASC, i.updated_at DESC
    LIMIT p_limit;
END;
$$;

-- Función para sincronización por lotes (batch upsert)
CREATE OR REPLACE FUNCTION batch_upsert_favorites(
    p_user_id UUID,
    p_favorites JSONB
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    affected_rows INTEGER := 0;
    fav_record RECORD;
BEGIN
    FOR fav_record IN 
        SELECT * FROM jsonb_to_recordset(p_favorites) AS x(
            movie_id INTEGER,
            movie_title VARCHAR(255),
            movie_poster_path TEXT,
            movie_backdrop_path TEXT,
            movie_overview TEXT,
            movie_release_date DATE,
            movie_vote_average DECIMAL(3,1),
            added_at TIMESTAMP WITH TIME ZONE,
            updated_at TIMESTAMP WITH TIME ZONE
        )
    LOOP
        INSERT INTO user_favorites (
            user_id, movie_id, movie_title, movie_poster_path,
            movie_backdrop_path, movie_overview, movie_release_date,
            movie_vote_average, added_at, updated_at
        ) VALUES (
            p_user_id, fav_record.movie_id, fav_record.movie_title,
            fav_record.movie_poster_path, fav_record.movie_backdrop_path,
            fav_record.movie_overview, fav_record.movie_release_date,
            fav_record.movie_vote_average, 
            COALESCE(fav_record.added_at, NOW()),
            COALESCE(fav_record.updated_at, NOW())
        )
        ON CONFLICT (user_id, movie_id) 
        DO UPDATE SET
            movie_title = EXCLUDED.movie_title,
            movie_poster_path = EXCLUDED.movie_poster_path,
            movie_backdrop_path = EXCLUDED.movie_backdrop_path,
            movie_overview = EXCLUDED.movie_overview,
            movie_release_date = EXCLUDED.movie_release_date,
            movie_vote_average = EXCLUDED.movie_vote_average,
            updated_at = GREATEST(user_favorites.updated_at, EXCLUDED.updated_at);
        
        affected_rows := affected_rows + 1;
    END LOOP;
    
    RETURN affected_rows;
END;
$$;

-- Función para sincronización por lotes de películas vistas
CREATE OR REPLACE FUNCTION batch_upsert_watched(
    p_user_id UUID,
    p_watched JSONB
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    affected_rows INTEGER := 0;
    watched_record RECORD;
BEGIN
    FOR watched_record IN 
        SELECT * FROM jsonb_to_recordset(p_watched) AS x(
            movie_id INTEGER,
            movie_title VARCHAR(255),
            movie_poster_path TEXT,
            movie_backdrop_path TEXT,
            movie_overview TEXT,
            movie_release_date DATE,
            movie_vote_average DECIMAL(3,1),
            watched_at TIMESTAMP WITH TIME ZONE,
            updated_at TIMESTAMP WITH TIME ZONE
        )
    LOOP
        INSERT INTO user_watched_movies (
            user_id, movie_id, movie_title, movie_poster_path,
            movie_backdrop_path, movie_overview, movie_release_date,
            movie_vote_average, watched_at, updated_at
        ) VALUES (
            p_user_id, watched_record.movie_id, watched_record.movie_title,
            watched_record.movie_poster_path, watched_record.movie_backdrop_path,
            watched_record.movie_overview, watched_record.movie_release_date,
            watched_record.movie_vote_average,
            COALESCE(watched_record.watched_at, NOW()),
            COALESCE(watched_record.updated_at, NOW())
        )
        ON CONFLICT (user_id, movie_id) 
        DO UPDATE SET
            movie_title = EXCLUDED.movie_title,
            movie_poster_path = EXCLUDED.movie_poster_path,
            movie_backdrop_path = EXCLUDED.movie_backdrop_path,
            movie_overview = EXCLUDED.movie_overview,
            movie_release_date = EXCLUDED.movie_release_date,
            movie_vote_average = EXCLUDED.movie_vote_average,
            watched_at = COALESCE(EXCLUDED.watched_at, user_watched_movies.watched_at),
            updated_at = GREATEST(user_watched_movies.updated_at, EXCLUDED.updated_at);
        
        affected_rows := affected_rows + 1;
    END LOOP;
    
    RETURN affected_rows;
END;
$$;

-- Permisos para las funciones
GRANT EXECUTE ON FUNCTION get_user_favorites_since(UUID, TIMESTAMP WITH TIME ZONE, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_watched_since(UUID, TIMESTAMP WITH TIME ZONE, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_lists_since(UUID, TIMESTAMP WITH TIME ZONE, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_list_items_since(UUID, TIMESTAMP WITH TIME ZONE, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION batch_upsert_favorites(UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION batch_upsert_watched(UUID, JSONB) TO authenticated;

-- Trigger para actualizar automáticamente updated_at en user_lists
CREATE OR REPLACE FUNCTION update_user_lists_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_user_lists_updated_at ON user_lists;
CREATE TRIGGER trigger_update_user_lists_updated_at
    BEFORE UPDATE ON user_lists
    FOR EACH ROW
    EXECUTE FUNCTION update_user_lists_updated_at();

-- Trigger para actualizar automáticamente updated_at en user_list_items
CREATE OR REPLACE FUNCTION update_user_list_items_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_user_list_items_updated_at ON user_list_items;
CREATE TRIGGER trigger_update_user_list_items_updated_at
    BEFORE UPDATE ON user_list_items
    FOR EACH ROW
    EXECUTE FUNCTION update_user_list_items_updated_at();

-- Trigger para actualizar automáticamente updated_at en user_favorites
CREATE OR REPLACE FUNCTION update_user_favorites_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_user_favorites_updated_at ON user_favorites;
CREATE TRIGGER trigger_update_user_favorites_updated_at
    BEFORE UPDATE ON user_favorites
    FOR EACH ROW
    EXECUTE FUNCTION update_user_favorites_updated_at();

-- Trigger para actualizar automáticamente updated_at en user_watched_movies
CREATE OR REPLACE FUNCTION update_user_watched_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_user_watched_updated_at ON user_watched_movies;
CREATE TRIGGER trigger_update_user_watched_updated_at
    BEFORE UPDATE ON user_watched_movies
    FOR EACH ROW
    EXECUTE FUNCTION update_user_watched_updated_at();

-- Comentarios para documentación
COMMENT ON FUNCTION get_user_favorites_since IS 'Obtiene favoritos del usuario modificados desde una fecha específica';
COMMENT ON FUNCTION get_user_watched_since IS 'Obtiene películas vistas del usuario modificadas desde una fecha específica';
COMMENT ON FUNCTION get_user_lists_since IS 'Obtiene listas del usuario modificadas desde una fecha específica';
COMMENT ON FUNCTION get_list_items_since IS 'Obtiene items de una lista modificados desde una fecha específica';
COMMENT ON FUNCTION batch_upsert_favorites IS 'Inserta o actualiza favoritos en lote para optimizar sincronización';
COMMENT ON FUNCTION batch_upsert_watched IS 'Inserta o actualiza películas vistas en lote para optimizar sincronización';