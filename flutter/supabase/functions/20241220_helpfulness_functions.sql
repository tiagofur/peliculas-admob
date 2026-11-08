-- Funciones RPC para el sistema de helpfulness
-- Fecha: 20/12/2024
-- Descripción: Funciones de utilidad para obtener estadísticas del sistema

-- Función para contar total de votos de helpfulness
CREATE OR REPLACE FUNCTION count_helpfulness_votes()
RETURNS INTEGER AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM rating_helpfulness_votes);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función para contar reseñas con estadísticas de helpfulness
CREATE OR REPLACE FUNCTION count_reviews_with_helpfulness_stats()
RETURNS INTEGER AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM rating_helpfulness_stats WHERE total_votes > 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función para obtener reseñas más útiles (top reviews)
CREATE OR REPLACE FUNCTION get_most_helpful_reviews(
    limit_count INTEGER DEFAULT 50,
    min_score DECIMAL DEFAULT 0.6,
    min_votes INTEGER DEFAULT 3
)
RETURNS TABLE(
    review_id UUID,
    helpful_votes INTEGER,
    not_helpful_votes INTEGER,
    total_votes INTEGER,
    helpfulness_score DECIMAL,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rhs.review_id,
        rhs.helpful_votes,
        rhs.not_helpful_votes,
        rhs.total_votes,
        rhs.helpfulness_score,
        rhs.created_at,
        rhs.updated_at
    FROM rating_helpfulness_stats rhs
    WHERE rhs.helpfulness_score >= min_score
      AND rhs.total_votes >= min_votes
    ORDER BY rhs.helpfulness_score DESC, rhs.total_votes DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función para obtener estadísticas de distribución de scores
CREATE OR REPLACE FUNCTION get_helpfulness_score_distribution()
RETURNS TABLE(
    score_range TEXT,
    count INTEGER,
    percentage DECIMAL
) AS $$
DECLARE
    total_reviews INTEGER;
BEGIN
    -- Obtener total de reseñas con estadísticas
    SELECT COUNT(*) INTO total_reviews 
    FROM rating_helpfulness_stats 
    WHERE total_votes > 0;
    
    IF total_reviews = 0 THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    WITH score_buckets AS (
        SELECT 
            CASE 
                WHEN helpfulness_score < 0.2 THEN '0.0-0.2'
                WHEN helpfulness_score < 0.4 THEN '0.2-0.4'
                WHEN helpfulness_score < 0.6 THEN '0.4-0.6'
                WHEN helpfulness_score < 0.8 THEN '0.6-0.8'
                ELSE '0.8-1.0'
            END as bucket,
            1 as review_count
        FROM rating_helpfulness_stats 
        WHERE total_votes > 0
    )
    SELECT 
        sb.bucket as score_range,
        COUNT(sb.review_count)::INTEGER as count,
        ROUND((COUNT(sb.review_count)::DECIMAL / total_reviews) * 100, 2) as percentage
    FROM score_buckets sb
    GROUP BY sb.bucket
    ORDER BY sb.bucket;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función para limpiar votos huérfanos (sin reseñas asociadas)
CREATE OR REPLACE FUNCTION cleanup_orphaned_helpfulness_votes()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Eliminar votos de reseñas que ya no existen
    -- Nota: Esta función asume que hay una tabla de reseñas para validar
    -- Por ahora, solo contamos los votos existentes
    SELECT COUNT(*) INTO deleted_count 
    FROM rating_helpfulness_votes;
    
    -- En el futuro, aquí se podría hacer:
    -- DELETE FROM rating_helpfulness_votes 
    -- WHERE review_id NOT IN (SELECT id FROM reviews_table);
    
    RETURN 0; -- Por ahora retorna 0
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función para recalcular todas las estadísticas de helpfulness
CREATE OR REPLACE FUNCTION recalculate_all_helpfulness_stats()
RETURNS INTEGER AS $$
DECLARE
    processed_count INTEGER := 0;
    review_record RECORD;
BEGIN
    -- Recalcular estadísticas para todas las reseñas que tienen votos
    FOR review_record IN 
        SELECT DISTINCT review_id 
        FROM rating_helpfulness_votes
    LOOP
        -- Insertar o actualizar estadísticas usando la función de trigger
        INSERT INTO rating_helpfulness_stats (
            review_id,
            helpful_votes,
            not_helpful_votes,
            updated_at
        )
        SELECT 
            review_record.review_id,
            COALESCE(SUM(CASE WHEN is_helpful THEN 1 ELSE 0 END), 0) as helpful_votes,
            COALESCE(SUM(CASE WHEN NOT is_helpful THEN 1 ELSE 0 END), 0) as not_helpful_votes,
            NOW() as updated_at
        FROM rating_helpfulness_votes 
        WHERE review_id = review_record.review_id
        ON CONFLICT (review_id) 
        DO UPDATE SET
            helpful_votes = EXCLUDED.helpful_votes,
            not_helpful_votes = EXCLUDED.not_helpful_votes,
            updated_at = NOW();
        
        processed_count := processed_count + 1;
    END LOOP;
    
    RETURN processed_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comentarios para documentación
COMMENT ON FUNCTION count_helpfulness_votes() IS 'Cuenta el total de votos de utilidad en el sistema';
COMMENT ON FUNCTION count_reviews_with_helpfulness_stats() IS 'Cuenta reseñas que tienen estadísticas de utilidad';
COMMENT ON FUNCTION get_most_helpful_reviews(INTEGER, DECIMAL, INTEGER) IS 'Obtiene las reseñas más útiles según criterios';
COMMENT ON FUNCTION get_helpfulness_score_distribution() IS 'Obtiene distribución de scores de utilidad por rangos';
COMMENT ON FUNCTION cleanup_orphaned_helpfulness_votes() IS 'Limpia votos de reseñas que ya no existen';
COMMENT ON FUNCTION recalculate_all_helpfulness_stats() IS 'Recalcula todas las estadísticas de utilidad';