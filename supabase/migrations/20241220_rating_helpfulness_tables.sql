-- Migración: Sistema de Helpfulness para Ratings
-- Fecha: 20/12/2024
-- Descripción: Tablas para permitir que usuarios voten sobre la utilidad de las reseñas

-- Tabla para almacenar votos de utilidad sobre reseñas
CREATE TABLE rating_helpfulness_votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL, -- ID de la reseña (puede ser external_review_id o local)
    voter_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    is_helpful BOOLEAN NOT NULL, -- true = útil, false = no útil
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(review_id, voter_user_id), -- Un usuario solo puede votar una vez por reseña
    CHECK (review_id IS NOT NULL AND review_id != '00000000-0000-0000-0000-000000000000'::UUID)
);

-- Tabla para estadísticas agregadas de utilidad (para performance)
CREATE TABLE rating_helpfulness_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL UNIQUE, -- ID de la reseña
    helpful_votes INTEGER DEFAULT 0 NOT NULL CHECK (helpful_votes >= 0),
    not_helpful_votes INTEGER DEFAULT 0 NOT NULL CHECK (not_helpful_votes >= 0),
    total_votes INTEGER GENERATED ALWAYS AS (helpful_votes + not_helpful_votes) STORED,
    helpfulness_score DECIMAL(5,4) GENERATED ALWAYS AS (
        CASE 
            WHEN (helpful_votes + not_helpful_votes) = 0 THEN 0.0
            ELSE ROUND(helpful_votes::DECIMAL / (helpful_votes + not_helpful_votes), 4)
        END
    ) STORED,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CHECK (review_id IS NOT NULL AND review_id != '00000000-0000-0000-0000-000000000000'::UUID)
);

-- Índices para performance
CREATE INDEX idx_helpfulness_votes_review_id ON rating_helpfulness_votes(review_id);
CREATE INDEX idx_helpfulness_votes_voter_user_id ON rating_helpfulness_votes(voter_user_id);
CREATE INDEX idx_helpfulness_votes_created_at ON rating_helpfulness_votes(created_at);
CREATE INDEX idx_helpfulness_stats_review_id ON rating_helpfulness_stats(review_id);
CREATE INDEX idx_helpfulness_stats_helpfulness_score ON rating_helpfulness_stats(helpfulness_score DESC);

-- Función para actualizar las estadísticas automáticamente
CREATE OR REPLACE FUNCTION update_helpfulness_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Insertar o actualizar estadísticas
    INSERT INTO rating_helpfulness_stats (
        review_id,
        helpful_votes,
        not_helpful_votes,
        updated_at
    )
    SELECT 
        COALESCE(NEW.review_id, OLD.review_id) as review_id,
        COALESCE(SUM(CASE WHEN is_helpful THEN 1 ELSE 0 END), 0) as helpful_votes,
        COALESCE(SUM(CASE WHEN NOT is_helpful THEN 1 ELSE 0 END), 0) as not_helpful_votes,
        NOW() as updated_at
    FROM rating_helpfulness_votes 
    WHERE review_id = COALESCE(NEW.review_id, OLD.review_id)
    ON CONFLICT (review_id) 
    DO UPDATE SET
        helpful_votes = EXCLUDED.helpful_votes,
        not_helpful_votes = EXCLUDED.not_helpful_votes,
        updated_at = NOW();
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Triggers para mantener estadísticas actualizadas
CREATE TRIGGER trigger_update_helpfulness_stats_insert
    AFTER INSERT ON rating_helpfulness_votes
    FOR EACH ROW EXECUTE FUNCTION update_helpfulness_stats();

CREATE TRIGGER trigger_update_helpfulness_stats_update
    AFTER UPDATE ON rating_helpfulness_votes
    FOR EACH ROW EXECUTE FUNCTION update_helpfulness_stats();

CREATE TRIGGER trigger_update_helpfulness_stats_delete
    AFTER DELETE ON rating_helpfulness_votes
    FOR EACH ROW EXECUTE FUNCTION update_helpfulness_stats();

-- Función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_helpfulness_votes_updated_at
    BEFORE UPDATE ON rating_helpfulness_votes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_helpfulness_stats_updated_at
    BEFORE UPDATE ON rating_helpfulness_stats
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Row Level Security (RLS)
ALTER TABLE rating_helpfulness_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE rating_helpfulness_stats ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para rating_helpfulness_votes
CREATE POLICY "Users can view all helpfulness votes" 
    ON rating_helpfulness_votes FOR SELECT 
    USING (true);

CREATE POLICY "Users can create their own helpfulness votes" 
    ON rating_helpfulness_votes FOR INSERT 
    WITH CHECK (auth.uid() = voter_user_id);

CREATE POLICY "Users can update their own helpfulness votes" 
    ON rating_helpfulness_votes FOR UPDATE 
    USING (auth.uid() = voter_user_id)
    WITH CHECK (auth.uid() = voter_user_id);

CREATE POLICY "Users can delete their own helpfulness votes" 
    ON rating_helpfulness_votes FOR DELETE 
    USING (auth.uid() = voter_user_id);

-- Políticas RLS para rating_helpfulness_stats
CREATE POLICY "Anyone can view helpfulness stats" 
    ON rating_helpfulness_stats FOR SELECT 
    USING (true);

-- Solo triggers pueden insertar/actualizar stats (no acceso directo de usuarios)
CREATE POLICY "Only system can modify helpfulness stats" 
    ON rating_helpfulness_stats FOR INSERT 
    WITH CHECK (false);

CREATE POLICY "Only system can update helpfulness stats" 
    ON rating_helpfulness_stats FOR UPDATE 
    USING (false);

-- Comentarios para documentación
COMMENT ON TABLE rating_helpfulness_votes IS 'Almacena votos de usuarios sobre la utilidad de reseñas de películas';
COMMENT ON TABLE rating_helpfulness_stats IS 'Estadísticas agregadas de utilidad por reseña (calculadas automáticamente)';
COMMENT ON COLUMN rating_helpfulness_votes.review_id IS 'ID de la reseña (puede ser externa o local)';
COMMENT ON COLUMN rating_helpfulness_votes.voter_user_id IS 'Usuario que emite el voto';
COMMENT ON COLUMN rating_helpfulness_votes.is_helpful IS 'true = útil, false = no útil';
COMMENT ON COLUMN rating_helpfulness_stats.helpfulness_score IS 'Score de 0.0 a 1.0 (votos útiles / total votos)';