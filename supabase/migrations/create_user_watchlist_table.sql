-- Migración para crear tabla de watchlist de usuario con prioridades
-- Tabla: user_watchlist

-- =============================================
-- TABLA: user_watchlist
-- =============================================
CREATE TABLE user_watchlist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    movie_id INTEGER NOT NULL,
    movie_title VARCHAR(255) NOT NULL,
    movie_poster_path TEXT,
    movie_backdrop_path TEXT,
    movie_overview TEXT,
    movie_release_date DATE,
    movie_vote_average DECIMAL(3,1),
    priority VARCHAR(10) NOT NULL DEFAULT 'normal' CHECK (priority IN ('alta', 'normal', 'baja')),
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- Índices para user_watchlist
CREATE UNIQUE INDEX idx_user_watchlist_user_movie ON user_watchlist(user_id, movie_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_user_watchlist_added_at ON user_watchlist(added_at DESC);
CREATE INDEX idx_user_watchlist_priority ON user_watchlist(priority, added_at DESC);
CREATE INDEX idx_user_watchlist_user_priority ON user_watchlist(user_id, priority, added_at DESC);

-- =============================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================

-- Habilitar RLS para la tabla
ALTER TABLE user_watchlist ENABLE ROW LEVEL SECURITY;

-- =============================================
-- POLÍTICAS DE SEGURIDAD
-- =============================================

-- Políticas para user_watchlist
CREATE POLICY "Users can manage their own watchlist" ON user_watchlist
    FOR ALL USING (auth.uid() = user_id);

-- =============================================
-- PERMISOS PARA ROLES
-- =============================================

-- Otorgar permisos completos a rol authenticated
GRANT ALL PRIVILEGES ON user_watchlist TO authenticated;

-- =============================================
-- TRIGGERS
-- =============================================

-- Trigger para actualizar updated_at automáticamente
CREATE TRIGGER update_user_watchlist_updated_at BEFORE UPDATE ON user_watchlist
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- COMENTARIOS PARA DOCUMENTACIÓN
-- =============================================

COMMENT ON TABLE user_watchlist IS 'Almacena las películas que el usuario quiere ver después, organizadas por prioridad';
COMMENT ON COLUMN user_watchlist.priority IS 'Prioridad de la película: alta, normal, baja';
COMMENT ON COLUMN user_watchlist.deleted_at IS 'Marca de eliminación suave para sincronización';