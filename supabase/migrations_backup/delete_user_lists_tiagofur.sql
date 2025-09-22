-- Script para eliminar todas las listas del usuario tiagofur@gmail.com
-- Este script elimina tanto las listas como sus items asociados

-- Primero obtenemos el user_id del email tiagofur@gmail.com
DO $$
DECLARE
    target_user_id uuid;
BEGIN
    -- Obtener el user_id del usuario tiagofur@gmail.com
    SELECT id INTO target_user_id 
    FROM auth.users 
    WHERE email = 'tiagofur@gmail.com';
    
    -- Verificar que el usuario existe
    IF target_user_id IS NULL THEN
        RAISE NOTICE 'Usuario con email tiagofur@gmail.com no encontrado';
        RETURN;
    END IF;
    
    RAISE NOTICE 'Usuario encontrado: %', target_user_id;
    
    -- Mostrar cuántas listas tiene el usuario antes de eliminar
    RAISE NOTICE 'Listas del usuario antes de eliminar: %', 
        (SELECT COUNT(*) FROM user_lists WHERE user_id = target_user_id AND is_deleted = false);
    
    -- Eliminar todos los items de las listas del usuario
    DELETE FROM user_list_items 
    WHERE list_id IN (
        SELECT id FROM user_lists 
        WHERE user_id = target_user_id
    );
    
    RAISE NOTICE 'Items de listas eliminados';
    
    -- Eliminar todas las listas del usuario
    DELETE FROM user_lists 
    WHERE user_id = target_user_id;
    
    RAISE NOTICE 'Todas las listas del usuario tiagofur@gmail.com han sido eliminadas';
    
    -- Mostrar confirmación
    RAISE NOTICE 'Listas restantes del usuario: %', 
        (SELECT COUNT(*) FROM user_lists WHERE user_id = target_user_id);
        
END $$;