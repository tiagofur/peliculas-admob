-- =============================================
-- HABILITAR REAL-TIME PARA USER_FAVORITES
-- =============================================
-- Ejecutar en: https://supabase.com/dashboard/project/fyzujpifkzftweynrudh/sql

-- Paso 1: Configurar replica identity para real-time
-- Esto permite que Supabase detecte todos los cambios en la tabla
ALTER TABLE public.user_favorites REPLICA IDENTITY FULL;

-- Paso 2: Crear/actualizar la publicación para real-time
-- Esto configura qué tablas se incluyen en el sistema de real-time
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE user_favorites;

-- Paso 3: Verificar que la configuración esté correcta
SELECT 
    schemaname,
    tablename,
    pubname
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime';

-- También verificar replica identity
SELECT 
    c.relname as table_name,
    CASE c.relreplident
        WHEN 'd' THEN 'DEFAULT'
        WHEN 'n' THEN 'NOTHING'
        WHEN 'f' THEN 'FULL'
        WHEN 'i' THEN 'INDEX'
    END as replica_identity
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relname = 'user_favorites' 
AND n.nspname = 'public';

-- =============================================
-- NOTAS IMPORTANTES:
-- =============================================
-- 1. Estas queries deben ejecutarse una por una
-- 2. Después de ejecutarlas, reiniciar la aplicación Flutter
-- 3. Los listeners de real-time se activarán automáticamente
-- 4. La sincronización será instantánea entre dispositivos
-- =============================================