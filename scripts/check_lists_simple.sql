-- =====================================================
-- DIAGNÓSTICO SIMPLE: Ver estado de user_lists
-- Copia y pega este SQL en Supabase SQL Editor
-- =====================================================

-- 1. Ver TODAS las listas actuales
SELECT
    name,
    emoji,
    color_hex,
    default_type,
    is_default,
    is_deleted,
    created_at
FROM user_lists
ORDER BY created_at DESC;

-- 2. Contar listas por tipo
SELECT
    'Total listas' as tipo,
    COUNT(*) as cantidad
FROM user_lists
WHERE is_deleted = false

UNION ALL

SELECT
    'Predefinidas' as tipo,
    COUNT(*) as cantidad
FROM user_lists
WHERE is_default = true AND is_deleted = false

UNION ALL

SELECT
    'Personalizadas' as tipo,
    COUNT(*) as cantidad
FROM user_lists
WHERE is_default = false AND is_deleted = false;

-- 3. Buscar duplicados
SELECT
    default_type,
    COUNT(*) as duplicados
FROM user_lists
WHERE is_default = true
  AND is_deleted = false
GROUP BY default_type
HAVING COUNT(*) > 1;
