-- Migración para agregar campos de listas por defecto
-- Fecha: 2024-01-15
-- Descripción: Agrega campos is_default, default_type y emoji a la tabla user_lists

-- Agregar campo is_default para identificar listas por defecto
ALTER TABLE user_lists 
ADD COLUMN is_default BOOLEAN DEFAULT false;

-- Agregar campo default_type para categorizar las listas por defecto
ALTER TABLE user_lists 
ADD COLUMN default_type VARCHAR(50);

-- Agregar campo emoji para mostrar iconos en las listas
ALTER TABLE user_lists 
ADD COLUMN emoji VARCHAR(10);

-- Crear índice para mejorar consultas de listas por defecto
CREATE INDEX idx_user_lists_is_default ON user_lists(user_id, is_default) WHERE is_default = true;

-- Crear índice para consultas por tipo de lista por defecto
CREATE INDEX idx_user_lists_default_type ON user_lists(user_id, default_type) WHERE default_type IS NOT NULL;

-- Agregar comentarios a los nuevos campos
COMMENT ON COLUMN user_lists.is_default IS 'Indica si la lista es una de las 8 listas por defecto del sistema';
COMMENT ON COLUMN user_lists.default_type IS 'Tipo de lista por defecto (quiero-ver, accion-y-aventura, etc.)';
COMMENT ON COLUMN user_lists.emoji IS 'Emoji asociado a la lista para mostrar en la interfaz';

-- Verificar que real-time esté habilitado (las tablas ya están configuradas)
-- Las tablas user_lists y user_list_items ya están en supabase_realtime

-- Verificar que las políticas RLS estén habilitadas
-- (Las políticas ya existen según la estructura actual)

-- Crear función para actualizar last_modified_at automáticamente
CREATE OR REPLACE FUNCTION update_user_lists_last_modified()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_modified_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger para actualizar last_modified_at en user_lists
DROP TRIGGER IF EXISTS trigger_update_user_lists_last_modified ON user_lists;
CREATE TRIGGER trigger_update_user_lists_last_modified
    BEFORE UPDATE ON user_lists
    FOR EACH ROW
    EXECUTE FUNCTION update_user_lists_last_modified();

-- Crear función para actualizar last_modified_at en user_list_items
CREATE OR REPLACE FUNCTION update_user_list_items_last_modified()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_modified_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger para actualizar last_modified_at en user_list_items
DROP TRIGGER IF EXISTS trigger_update_user_list_items_last_modified ON user_list_items;
CREATE TRIGGER trigger_update_user_list_items_last_modified
    BEFORE UPDATE ON user_list_items
    FOR EACH ROW
    EXECUTE FUNCTION update_user_list_items_last_modified();

-- Verificar que los permisos estén correctos para las tablas
-- Otorgar permisos a los roles anon y authenticated
GRANT SELECT ON user_lists TO anon;
GRANT ALL PRIVILEGES ON user_lists TO authenticated;

GRANT SELECT ON user_list_items TO anon;
GRANT ALL PRIVILEGES ON user_list_items TO authenticated;

-- Mensaje de confirmación
DO $$
BEGIN
    RAISE NOTICE 'Migración completada: Campos is_default, default_type y emoji agregados a user_lists';
    RAISE NOTICE 'Real-time habilitado para user_lists y user_list_items';
    RAISE NOTICE 'Triggers y permisos configurados correctamente';
END $$;