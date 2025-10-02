-- Ver el esquema completo de la tabla user_lists
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'user_lists'
ORDER BY ordinal_position;
