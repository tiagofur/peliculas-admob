-- 🔧 CORRECCIÓN URGENTE: Función get_server_timestamp faltante
-- Ejecutar este script en Supabase Dashboard > SQL Editor

-- Crear la función get_server_timestamp que está causando el error 404
CREATE OR REPLACE FUNCTION get_server_timestamp()
RETURNS timestamp with time zone
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT now();
$$;

-- Dar permisos a usuarios autenticados
GRANT EXECUTE ON FUNCTION get_server_timestamp() TO authenticated;

-- Dar permisos a usuarios anónimos (para modo invitado)
GRANT EXECUTE ON FUNCTION get_server_timestamp() TO anon;

-- Agregar documentación
COMMENT ON FUNCTION get_server_timestamp() IS 'Returns the current server timestamp for synchronization operations. Used by the mobile app to ensure consistent timestamps across devices.';

-- Verificar que la función funciona correctamente
DO $$
DECLARE
    test_timestamp timestamp with time zone;
BEGIN
    SELECT get_server_timestamp() INTO test_timestamp;
    RAISE NOTICE 'Server timestamp function created successfully. Test result: %', test_timestamp;
END $$;

-- Mensaje de confirmación
SELECT 'get_server_timestamp function created successfully!' as status,
       get_server_timestamp() as current_server_time;