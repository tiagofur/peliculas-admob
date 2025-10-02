-- Migración para evitar listas predefinidas duplicadas
-- Fecha: 1 de Octubre, 2025
-- Descripción: Agrega constraint único para prevenir duplicación de listas predefinidas

-- Primero, limpiamos posibles duplicados existentes
-- Esta query elimina las listas duplicadas conservando la más reciente
WITH duplicates AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY user_id, default_type, is_default 
           ORDER BY created_at DESC
         ) as rn
  FROM user_lists 
  WHERE is_default = true 
  AND default_type IS NOT NULL
)
DELETE FROM user_lists 
WHERE id IN (
  SELECT id FROM duplicates WHERE rn > 1
);

-- Crear constraint único para evitar duplicados futuros
-- Esto asegura que cada usuario solo puede tener UNA lista predefinida de cada tipo
ALTER TABLE user_lists 
ADD CONSTRAINT unique_user_default_list 
UNIQUE (user_id, default_type) 
WHERE is_default = true AND default_type IS NOT NULL;

-- Crear índice compuesto optimizado para consultas de listas predefinidas
CREATE INDEX IF NOT EXISTS idx_user_lists_default_unique 
ON user_lists(user_id, default_type, is_default) 
WHERE is_default = true AND default_type IS NOT NULL;

-- Comentario explicativo
COMMENT ON CONSTRAINT unique_user_default_list ON user_lists IS 
'Previene que un usuario tenga múltiples listas predefinidas del mismo tipo (default_type)';

-- Mensaje de confirmación
DO $$
BEGIN
    RAISE NOTICE 'Constraint único agregado: unique_user_default_list';
    RAISE NOTICE 'Duplicados existentes eliminados (se conservó la lista más reciente)';
    RAISE NOTICE 'Las listas predefinidas ya no podrán duplicarse por tipo de usuario';
END $$;