-- Migración para sincronización de datos de usuario con Supabase
-- Tablas: user_favorites, user_watched_movies, user_lists, user_list_items

-- =============================================
-- TABLA: user_favorites
-- =============================================
CREATE TABLE user_favorites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    movie_id INTEGER NOT NULL,
    movie_title VARCHAR(255) NOT NULL,
    movie_poster_path TEXT,
    movie_backdrop_path TEXT,
    movie_overview TEXT,
    movie_release_date DATE,
    movie_vote_average DECIMAL(3,1),
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para user_favorites
CREATE UNIQUE INDEX idx_user_favorites_user_movie ON user_favorites(user_id, movie_id);
CREATE INDEX idx_user_favorites_added_at ON user_favorites(added_at DESC);

-- =============================================
-- TABLA: user_watched_movies
-- =============================================
CREATE TABLE user_watched_movies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    movie_id INTEGER NOT NULL,
    movie_title VARCHAR(255) NOT NULL,
    movie_poster_path TEXT,
    movie_backdrop_path TEXT,
    movie_overview TEXT,
    movie_release_date DATE,
    movie_vote_average DECIMAL(3,1),
    watched_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para user_watched_movies
CREATE UNIQUE INDEX idx_user_watched_user_movie ON user_watched_movies(user_id, movie_id);
CREATE INDEX idx_user_watched_watched_at ON user_watched_movies(watched_at DESC);

-- =============================================
-- TABLA: user_lists
-- =============================================
CREATE TABLE user_lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    color_hex VARCHAR(7) DEFAULT '#FF5722',
    is_public BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para user_lists
CREATE INDEX idx_user_lists_user_id ON user_lists(user_id);
CREATE INDEX idx_user_lists_created_at ON user_lists(created_at DESC);

-- =============================================
-- TABLA: user_list_items
-- =============================================
CREATE TABLE user_list_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    list_id UUID REFERENCES user_lists(id) ON DELETE CASCADE,
    movie_id INTEGER NOT NULL,
    movie_title VARCHAR(255) NOT NULL,
    movie_poster_path TEXT,
    movie_backdrop_path TEXT,
    movie_overview TEXT,
    movie_release_date DATE,
    movie_vote_average DECIMAL(3,1),
    position INTEGER DEFAULT 0,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para user_list_items
CREATE UNIQUE INDEX idx_list_items_list_movie ON user_list_items(list_id, movie_id);
CREATE INDEX idx_list_items_position ON user_list_items(list_id, position);

-- =============================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================

-- Habilitar RLS para todas las tablas
ALTER TABLE user_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_watched_movies ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_list_items ENABLE ROW LEVEL SECURITY;

-- =============================================
-- POLÍTICAS DE SEGURIDAD
-- =============================================

-- Políticas para user_favorites
CREATE POLICY "Users can manage their own favorites" ON user_favorites
    FOR ALL USING (auth.uid() = user_id);

-- Políticas para user_watched_movies
CREATE POLICY "Users can manage their own watched movies" ON user_watched_movies
    FOR ALL USING (auth.uid() = user_id);

-- Políticas para user_lists
CREATE POLICY "Users can manage their own lists" ON user_lists
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Public lists are viewable" ON user_lists
    FOR SELECT USING (is_public = true);

-- Políticas para user_list_items
CREATE POLICY "Users can manage items in their own lists" ON user_list_items
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_lists 
            WHERE user_lists.id = user_list_items.list_id 
            AND user_lists.user_id = auth.uid()
        )
    );

CREATE POLICY "Public list items are viewable" ON user_list_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_lists 
            WHERE user_lists.id = user_list_items.list_id 
            AND user_lists.is_public = true
        )
    );

-- =============================================
-- PERMISOS PARA ROLES
-- =============================================

-- Otorgar permisos SELECT a rol anon para listas públicas
GRANT SELECT ON user_lists TO anon;
GRANT SELECT ON user_list_items TO anon;

-- Otorgar permisos completos a rol authenticated
GRANT ALL PRIVILEGES ON user_favorites TO authenticated;
GRANT ALL PRIVILEGES ON user_watched_movies TO authenticated;
GRANT ALL PRIVILEGES ON user_lists TO authenticated;
GRANT ALL PRIVILEGES ON user_list_items TO authenticated;

-- =============================================
-- FUNCIONES DE UTILIDAD
-- =============================================

-- Función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers para actualizar updated_at
CREATE TRIGGER update_user_favorites_updated_at BEFORE UPDATE ON user_favorites
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_watched_movies_updated_at BEFORE UPDATE ON user_watched_movies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_lists_updated_at BEFORE UPDATE ON user_lists
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_list_items_updated_at BEFORE UPDATE ON user_list_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- COMENTARIOS PARA DOCUMENTACIÓN
-- =============================================

COMMENT ON TABLE user_favorites IS 'Almacena las películas favoritas de cada usuario';
COMMENT ON TABLE user_watched_movies IS 'Almacena las películas vistas por cada usuario';
COMMENT ON TABLE user_lists IS 'Almacena las listas personalizadas de películas de cada usuario';
COMMENT ON TABLE user_list_items IS 'Almacena los elementos (películas) dentro de cada lista personalizada';

COMMENT ON COLUMN user_lists.is_public IS 'Indica si la lista es pública y visible para otros usuarios';
COMMENT ON COLUMN user_list_items.position IS 'Posición del elemento dentro de la lista para ordenamiento';