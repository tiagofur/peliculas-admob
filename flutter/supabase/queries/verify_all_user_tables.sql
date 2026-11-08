-- Query para verificar TODAS las tablas de usuario que existen
-- Ejecuta esto PRIMERO para confirmar los nombres exactos

SELECT
    tablename,
    schemaname,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename LIKE 'user_%'
ORDER BY tablename;

-- Esta query mostrará todas las tablas que empiezan con 'user_'
-- Úsala para confirmar los nombres exactos antes de configurar Realtime
