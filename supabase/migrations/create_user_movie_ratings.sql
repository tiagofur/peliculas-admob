-- Migration for user movie ratings and personal notes system
-- Table: user_movie_ratings

-- =============================================
-- TABLA: user_movie_ratings
-- =============================================
CREATE TABLE user_movie_ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    movie_id INTEGER NOT NULL,
    movie_title VARCHAR(255) NOT NULL,
    movie_poster_path TEXT,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    personal_note TEXT CHECK (char_length(personal_note) <= 500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para user_movie_ratings
CREATE UNIQUE INDEX idx_user_movie_ratings_user_movie ON user_movie_ratings(user_id, movie_id);
CREATE INDEX idx_user_movie_ratings_rating ON user_movie_ratings(rating DESC);
CREATE INDEX idx_user_movie_ratings_created_at ON user_movie_ratings(created_at DESC);
CREATE INDEX idx_user_movie_ratings_user_id ON user_movie_ratings(user_id);

-- =============================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================

-- Habilitar RLS para la tabla
ALTER TABLE user_movie_ratings ENABLE ROW LEVEL SECURITY;

-- =============================================
-- POLÍTICAS DE SEGURIDAD
-- =============================================

-- Los usuarios pueden gestionar sus propias valoraciones
CREATE POLICY "Users can manage their own movie ratings" ON user_movie_ratings
    FOR ALL USING (auth.uid() = user_id);

-- Opcional: permitir ver valoraciones públicas (descomentando siguiente línea)
-- CREATE POLICY "Public movie ratings are viewable" ON user_movie_ratings
--     FOR SELECT USING (true);

-- =============================================
-- PERMISOS PARA ROLES
-- =============================================

-- Otorgar permisos completos a rol authenticated
GRANT ALL PRIVILEGES ON user_movie_ratings TO authenticated;

-- Opcional: otorgar permisos SELECT a rol anon para valoraciones públicas
-- GRANT SELECT ON user_movie_ratings TO anon;

-- =============================================
-- FUNCIONES Y TRIGGERS
-- =============================================

-- Trigger para actualizar updated_at automáticamente
CREATE TRIGGER update_user_movie_ratings_updated_at BEFORE UPDATE ON user_movie_ratings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- COMENTARIOS PARA DOCUMENTACIÓN
-- =============================================

COMMENT ON TABLE user_movie_ratings IS 'Almacena las valoraciones (1-5 estrellas) y notas personales de películas por usuario';
COMMENT ON COLUMN user_movie_ratings.rating IS 'Valoración del usuario del 1 al 5 (estrellas)';
COMMENT ON COLUMN user_movie_ratings.personal_note IS 'Nota personal opcional del usuario sobre la película (máximo 500 caracteres)';
COMMENT ON COLUMN user_movie_ratings.movie_title IS 'Título de la película almacenado para consultas rápidas';
COMMENT ON COLUMN user_movie_ratings.movie_poster_path IS 'Ruta del poster de la película para mostrar en listas';