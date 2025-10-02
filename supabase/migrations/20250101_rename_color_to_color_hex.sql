-- =====================================================
-- MIGRACIÓN: Renombrar columna color a color_hex
-- Fecha: 2025-01-01
-- Descripción: Renombra la columna 'color' a 'color_hex' para
--              consistencia con el código de la aplicación
-- =====================================================

-- Verificar si la columna 'color' existe y 'color_hex' no existe
DO $$
BEGIN
    -- Si existe 'color' y no existe 'color_hex', renombrar
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_lists'
          AND column_name = 'color'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_lists'
          AND column_name = 'color_hex'
    ) THEN
        ALTER TABLE user_lists RENAME COLUMN color TO color_hex;
        RAISE NOTICE 'Columna "color" renombrada a "color_hex"';
    ELSE
        RAISE NOTICE 'La columna ya está correctamente nombrada o no existe "color"';
    END IF;
END $$;

-- Asegurar que color_hex tenga un valor por defecto
ALTER TABLE user_lists
ALTER COLUMN color_hex SET DEFAULT '#2196F3';

-- Comentario en la columna
COMMENT ON COLUMN user_lists.color_hex IS
'Color hexadecimal de la lista en formato #RRGGBB';
