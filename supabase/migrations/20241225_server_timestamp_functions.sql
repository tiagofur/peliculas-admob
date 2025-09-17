-- Función para obtener el timestamp actual del servidor
-- Esta función asegura consistencia de timestamps en todas las operaciones de sync

CREATE OR REPLACE FUNCTION get_server_timestamp()
RETURNS TIMESTAMPTZ
LANGUAGE sql
STABLE
AS $$
  SELECT NOW();
$$;

-- Dar permisos públicos para que puedan usarla los usuarios autenticados
GRANT EXECUTE ON FUNCTION get_server_timestamp() TO authenticated;
GRANT EXECUTE ON FUNCTION get_server_timestamp() TO anon;

-- Crear tabla de metadata de sync si no existe (para obtener timestamps como fallback)
CREATE TABLE IF NOT EXISTS sync_metadata (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Configurar RLS
ALTER TABLE sync_metadata ENABLE ROW LEVEL SECURITY;

-- Política para que todos puedan leer (solo para obtener timestamps)
CREATE POLICY "Allow read access for timestamp extraction" 
ON sync_metadata 
FOR SELECT 
TO authenticated, anon
USING (true);

-- Insertar registro inicial si no existe
INSERT INTO sync_metadata (metadata) 
SELECT '{"purpose": "timestamp_reference"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM sync_metadata LIMIT 1);

-- Función para mantener sync_metadata actualizada (trigger)
CREATE OR REPLACE FUNCTION update_sync_metadata_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Trigger para actualizar timestamps automáticamente
DROP TRIGGER IF EXISTS sync_metadata_updated_at ON sync_metadata;
CREATE TRIGGER sync_metadata_updated_at
  BEFORE UPDATE ON sync_metadata
  FOR EACH ROW
  EXECUTE FUNCTION update_sync_metadata_timestamp();