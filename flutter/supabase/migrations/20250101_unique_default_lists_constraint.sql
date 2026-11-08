-- =====================================================
-- MIGRACIÓN: Prevenir duplicados en listas predefinidas
-- Fecha: 2025-01-01
-- Descripción: Agrega constraint único para evitar que un usuario
--              tenga múltiples listas predefinidas del mismo tipo
-- =====================================================

-- Primero, limpiar duplicados existentes si los hay
-- Esta query conserva la lista más reciente para cada (user_id, default_type)
DO $$
DECLARE
    duplicate_record RECORD;
BEGIN
    -- Encontrar y eliminar duplicados, conservando solo el más reciente
    FOR duplicate_record IN
        WITH ranked_lists AS (
            SELECT
                id,
                user_id,
                default_type,
                ROW_NUMBER() OVER (
                    PARTITION BY user_id, default_type
                    ORDER BY last_modified_at DESC, created_at DESC
                ) as rn
            FROM user_lists
            WHERE is_default = true
              AND is_deleted = false
              AND default_type IS NOT NULL
        )
        SELECT id
        FROM ranked_lists
        WHERE rn > 1
    LOOP
        -- Marcar como eliminado en lugar de borrar físicamente
        UPDATE user_lists
        SET is_deleted = true,
            last_modified_at = NOW()
        WHERE id = duplicate_record.id;

        RAISE NOTICE 'Eliminado duplicado: %', duplicate_record.id;
    END LOOP;
END $$;

-- Crear índice único parcial para prevenir futuros duplicados
-- Solo aplica a listas predefinidas no eliminadas con default_type definido
-- PostgreSQL usa índices únicos parciales en lugar de constraints con WHERE
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
