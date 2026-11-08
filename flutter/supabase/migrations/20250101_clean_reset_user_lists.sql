-- =====================================================
-- MIGRACIÓN: Limpieza completa de user_lists
-- Fecha: 2025-01-01
-- Descripción: Limpia completamente la tabla user_lists para eliminar
--              todas las listas duplicadas y corruptas.
--              Las listas predefinidas se recrearán automáticamente
--              en el próximo login del usuario.
-- =====================================================

-- IMPORTANTE: Solo ejecutar si user_list_items está vacía
-- Verificar primero con: SELECT COUNT(*) FROM user_list_items;

-- Eliminar TODAS las listas (tanto predefinidas como personalizadas)
-- Las listas predefinidas se recrearán automáticamente
-- Las listas personalizadas se perderán (asegúrate de que esto es aceptable)
TRUNCATE TABLE user_lists CASCADE;

-- Crear índice único parcial para prevenir futuros duplicados
-- Solo aplica a listas predefinidas no eliminadas con default_type definido
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_user_default_type
ON user_lists(user_id, default_type)
WHERE is_default = true AND is_deleted = false AND default_type IS NOT NULL;

-- Crear índice adicional para mejorar rendimiento de queries
CREATE INDEX IF NOT EXISTS idx_user_lists_default_type_lookup
ON user_lists(user_id, default_type, is_default, is_deleted)
WHERE is_default = true AND is_deleted = false;

-- Comentarios en los índices
COMMENT ON INDEX idx_unique_user_default_type IS
'Previene que un usuario tenga múltiples listas predefinidas del mismo tipo (índice único parcial)';

COMMENT ON INDEX idx_user_lists_default_type_lookup IS
'Optimiza queries de listas predefinidas por usuario y tipo';

-- Resultado esperado:
-- ✅ Tabla user_lists completamente vacía
-- ✅ Índices únicos creados
-- ✅ En el próximo login, se crearán automáticamente las 8 listas predefinidas
-- ✅ Sin duplicados gracias al índice único
