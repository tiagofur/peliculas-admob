-- Habilitar real-time para todas las tablas de sincronización
-- Este archivo configura las publicaciones de real-time para las tablas principales

-- Habilitar real-time para user_favorites
ALTER PUBLICATION supabase_realtime ADD TABLE user_favorites;

-- Habilitar real-time para user_watched_movies
ALTER PUBLICATION supabase_realtime ADD TABLE user_watched_movies;

-- Habilitar real-time para user_watchlist
ALTER PUBLICATION supabase_realtime ADD TABLE user_watchlist;

-- Habilitar real-time para user_lists
ALTER PUBLICATION supabase_realtime ADD TABLE user_lists;

-- Habilitar real-time para user_list_items
ALTER PUBLICATION supabase_realtime ADD TABLE user_list_items;

-- Habilitar real-time para sync_status
ALTER PUBLICATION supabase_realtime ADD TABLE sync_status;

-- Habilitar real-time para sync_conflicts
ALTER PUBLICATION supabase_realtime ADD TABLE sync_conflicts;

-- Real-time habilitado para todas las tablas de sincronización