-- Función para obtener el timestamp actual del servidor
-- Esta función es útil para sincronización y asegurar timestamps consistentes

CREATE OR REPLACE FUNCTION get_server_timestamp()
RETURNS timestamp with time zone
LANGUAGE sql
STABLE
AS $$
  SELECT now();
$$;

-- Comentario explicativo
COMMENT ON FUNCTION get_server_timestamp() IS 'Retorna el timestamp actual del servidor de Supabase para operaciones de sincronización';

-- Verificar que la función funciona correctamente
DO $$
BEGIN
  RAISE NOTICE 'Server timestamp function created. Current time: %', get_server_timestamp();
END $$;