-- =====================================================
-- DIAGNÓSTICO: Estado actual de user_lists
-- Ejecuta esto para entender qué está pasando
-- =====================================================

-- 1. Ver TODAS las listas actuales
SELECT
    id,
    name,
    emoji,
    color_hex,
    default_type,
    is_default,
    is_deleted,
    user_id,
    created_at
FROM user_lists
ORDER BY created_at DESC;

-- 2. Contar duplicados por usuario y tipo
SELECT
    user_id,
    default_type,
    COUNT(*) as count,
    STRING_AGG(name, ', ') as nombres
FROM user_lists
WHERE is_default = true
  AND is_deleted = false
GROUP BY user_id, default_type
HAVING COUNT(*) > 1
ORDER BY count DESC;

-- 3. Ver índices únicos existentes
SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'user_lists'
  AND indexname LIKE '%unique%';

-- 4. Ver listas con problemas de color/emoji
SELECT
    name,
    emoji,
    color_hex,
    CASE
        WHEN emoji = '📝' THEN 'PROBLEMA: Emoji genérico'
        ELSE 'OK'
    END as emoji_status,
    CASE
        WHEN color_hex = '#2196F3' OR color_hex IS NULL THEN 'PROBLEMA: Color por defecto'
        ELSE 'OK'
    END as color_status
FROM user_lists
WHERE is_default = true
  AND is_deleted = false
ORDER BY name;

-- 5. Total de listas por usuario
SELECT
    user_id,
    COUNT(*) FILTER (WHERE is_default = true AND is_deleted = false) as listas_predefinidas,
    COUNT(*) FILTER (WHERE is_default = false AND is_deleted = false) as listas_personalizadas,
    COUNT(*) FILTER (WHERE is_deleted = true) as listas_eliminadas
FROM user_lists
GROUP BY user_id;
