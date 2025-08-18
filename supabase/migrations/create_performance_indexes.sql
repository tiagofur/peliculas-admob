-- Índices de rendimiento para optimizar sincronización
-- Archivo: create_performance_indexes.sql
-- Propósito: Mejorar rendimiento de consultas de sincronización

-- =====================================================
-- ÍNDICES PARA TABLA user_favorites
-- =====================================================

-- Índice compuesto para consultas de sincronización por usuario y timestamp
CREATE INDEX IF NOT EXISTS idx_user_favorites_sync 
ON user_favorites (user_id, updated_at DESC);

-- Índice para búsquedas rápidas por película
CREATE INDEX IF NOT EXISTS idx_user_favorites_movie 
ON user_favorites (movie_id);

-- Índice para consultas de rango de fechas
CREATE INDEX IF NOT EXISTS idx_user_favorites_created_at 
ON user_favorites (created_at DESC);

-- Índice parcial para favoritos activos (si se implementa soft delete)
CREATE INDEX IF NOT EXISTS idx_user_favorites_active 
ON user_favorites (user_id, movie_id) 
WHERE deleted_at IS NULL;

-- =====================================================
-- ÍNDICES PARA TABLA user_watched_movies
-- =====================================================

-- Índice compuesto principal para sincronización
CREATE INDEX IF NOT EXISTS idx_user_watched_sync 
ON user_watched_movies (user_id, updated_at DESC);

-- Índice para consultas por fecha de visualización
CREATE INDEX IF NOT EXISTS idx_user_watched_date 
ON user_watched_movies (user_id, watched_at DESC);

-- Índice para búsquedas por película
CREATE INDEX IF NOT EXISTS idx_user_watched_movie 
ON user_watched_movies (movie_id);

-- Índice compuesto para evitar duplicados
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_watched_unique 
ON user_watched_movies (user_id, movie_id);

-- =====================================================
-- ÍNDICES PARA TABLA user_lists
-- =====================================================

-- Índice principal para consultas por usuario
CREATE INDEX IF NOT EXISTS idx_user_lists_user 
ON user_lists (user_id, updated_at DESC);

-- Índice para búsquedas por nombre de lista
CREATE INDEX IF NOT EXISTS idx_user_lists_name 
ON user_lists (user_id, name);

-- Índice para consultas de creación reciente
CREATE INDEX IF NOT EXISTS idx_user_lists_created 
ON user_lists (created_at DESC);

-- =====================================================
-- ÍNDICES PARA TABLA user_list_items
-- =====================================================

-- Índice compuesto principal para items de lista
CREATE INDEX IF NOT EXISTS idx_user_list_items_list 
ON user_list_items (list_id, added_at DESC);

-- Índice para búsquedas por película en listas
CREATE INDEX IF NOT EXISTS idx_user_list_items_movie 
ON user_list_items (movie_id);

-- Índice único para evitar duplicados en listas
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_list_items_unique 
ON user_list_items (list_id, movie_id);

-- Índice para consultas de películas populares en listas
CREATE INDEX IF NOT EXISTS idx_user_list_items_popular 
ON user_list_items (movie_id, added_at DESC);

-- =====================================================
-- ÍNDICES PARA TABLA user_profiles
-- =====================================================

-- Índice para consultas de perfil por usuario
CREATE INDEX IF NOT EXISTS idx_user_profiles_user 
ON user_profiles (user_id);

-- Índice para búsquedas por nombre completo
CREATE INDEX IF NOT EXISTS idx_user_profiles_name 
ON user_profiles (full_name);

-- Índice para perfiles actualizados recientemente
CREATE INDEX IF NOT EXISTS idx_user_profiles_updated 
ON user_profiles (updated_at DESC);

-- =====================================================
-- ÍNDICES PARA TABLA user_stats
-- =====================================================

-- Índice principal para estadísticas por usuario
CREATE INDEX IF NOT EXISTS idx_user_stats_user 
ON user_stats (user_id);

-- Índice para estadísticas actualizadas recientemente
CREATE INDEX IF NOT EXISTS idx_user_stats_updated 
ON user_stats (updated_at DESC);

-- Índice para consultas de usuarios más activos
CREATE INDEX IF NOT EXISTS idx_user_stats_activity 
ON user_stats (movies_watched DESC, favorites_count DESC);

-- =====================================================
-- ÍNDICES FUNCIONALES PARA OPTIMIZACIONES AVANZADAS
-- =====================================================

-- Índice funcional para búsquedas case-insensitive en nombres de listas
CREATE INDEX IF NOT EXISTS idx_user_lists_name_lower 
ON user_lists (user_id, LOWER(name));

-- Índice para consultas de sincronización incremental
CREATE INDEX IF NOT EXISTS idx_favorites_incremental_sync 
ON user_favorites (user_id, updated_at) 
WHERE updated_at > (CURRENT_TIMESTAMP - INTERVAL '7 days');

-- Índice para consultas de películas vistas en el último mes
CREATE INDEX IF NOT EXISTS idx_watched_recent 
ON user_watched_movies (user_id, watched_at) 
WHERE watched_at > (CURRENT_TIMESTAMP - INTERVAL '30 days');

-- =====================================================
-- ESTADÍSTICAS Y MANTENIMIENTO
-- =====================================================

-- Actualizar estadísticas de las tablas para el optimizador de consultas
ANALYZE user_favorites;
ANALYZE user_watched_movies;
ANALYZE user_lists;
ANALYZE user_list_items;
ANALYZE user_profiles;
ANALYZE user_stats;

-- =====================================================
-- COMENTARIOS SOBRE OPTIMIZACIÓN
-- =====================================================

-- Los índices creados están diseñados para:
-- 1. Acelerar consultas de sincronización por usuario y timestamp
-- 2. Optimizar búsquedas por película específica
-- 3. Mejorar rendimiento de consultas de rango de fechas
-- 4. Evitar duplicados con índices únicos
-- 5. Soportar consultas de estadísticas y reportes

-- Consideraciones de mantenimiento:
-- - Los índices se actualizan automáticamente con los datos
-- - Ejecutar ANALYZE periódicamente para mantener estadísticas actualizadas
-- - Monitorear el uso de índices con pg_stat_user_indexes
-- - Considerar REINDEX si hay fragmentación significativa

-- Para monitorear el uso de índices:
-- SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
-- FROM pg_stat_user_indexes 
-- WHERE schemaname = 'public'
-- ORDER BY idx_scan DESC;

-- Para identificar índices no utilizados:
-- SELECT schemaname, tablename, indexname, idx_scan
-- FROM pg_stat_user_indexes 
-- WHERE idx_scan = 0 AND schemaname = 'public';