-- Migration to ensure default lists exist for all users
-- This function creates default lists for any user who doesn't have them

-- Function to create default lists for a user
CREATE OR REPLACE FUNCTION create_default_lists_for_user(user_id_param UUID)
RETURNS void AS $$
DECLARE
    default_list_ids TEXT[] := ARRAY[
        'quiero-ver',
        'para-el-fin-de-semana',
        'noche-de-citas',
        'con-amigos',
        'clasicos-pendientes',
        'accion-y-aventura',
        'documentales',
        'cuando-llueve'
    ];
    list_id TEXT;
    list_exists BOOLEAN;
BEGIN
    FOREACH list_id IN ARRAY default_list_ids
    LOOP
        -- Check if list already exists for this user
        SELECT EXISTS (
            SELECT 1 FROM public.user_lists
            WHERE id = list_id AND user_id = user_id_param
        ) INTO list_exists;

        -- Create list if it doesn't exist
        IF NOT list_exists THEN
            INSERT INTO public.user_lists (id, user_id, name, description, emoji, color_hex, is_default, is_public, sync_version, is_deleted, created_at)
            VALUES (
                list_id,
                user_id_param,
                CASE list_id
                    WHEN 'quiero-ver' THEN 'Quiero Ver'
                    WHEN 'para-el-fin-de-semana' THEN 'Para el Fin de Semana'
                    WHEN 'noche-de-citas' THEN 'Noche de Citas'
                    WHEN 'con-amigos' THEN 'Con Amigos'
                    WHEN 'clasicos-pendientes' THEN 'Clásicos Pendientes'
                    WHEN 'accion-y-aventura' THEN 'Acción y Aventura'
                    WHEN 'documentales' THEN 'Documentales'
                    WHEN 'cuando-llueve' THEN 'Cuando Llueve'
                END,
                CASE list_id
                    WHEN 'quiero-ver' THEN 'Películas que quiero ver próximamente'
                    WHEN 'para-el-fin-de-semana' THEN 'Películas perfectas para relajarse'
                    WHEN 'noche-de-citas' THEN 'Películas románticas para ver en pareja'
                    WHEN 'con-amigos' THEN 'Películas divertidas para ver en grupo'
                    WHEN 'clasicos-pendientes' THEN 'Películas clásicas que debo ver'
                    WHEN 'accion-y-aventura' THEN 'Para cuando quiero adrenalina'
                    WHEN 'documentales' THEN 'Para aprender algo nuevo'
                    WHEN 'cuando-llueve' THEN 'Películas perfectas para días lluviosos'
                END,
                CASE list_id
                    WHEN 'quiero-ver' THEN '🍿'
                    WHEN 'para-el-fin-de-semana' THEN '🛋️'
                    WHEN 'noche-de-citas' THEN '💕'
                    WHEN 'con-amigos' THEN '👥'
                    WHEN 'clasicos-pendientes' THEN '🎭'
                    WHEN 'accion-y-aventura' THEN '💥'
                    WHEN 'documentales' THEN '📚'
                    WHEN 'cuando-llueve' THEN '🌧️'
                END,
                CASE list_id
                    WHEN 'quiero-ver' THEN '#2196F3'
                    WHEN 'para-el-fin-de-semana' THEN '#4CAF50'
                    WHEN 'noche-de-citas' THEN '#E91E63'
                    WHEN 'con-amigos' THEN '#FF9800'
                    WHEN 'clasicos-pendientes' THEN '#9C27B0'
                    WHEN 'accion-y-aventura' THEN '#F44336'
                    WHEN 'documentales' THEN '#009688'
                    WHEN 'cuando-llueve' THEN '#3F51B5'
                END,
                true, -- is_default
                false, -- is_public
                1, -- sync_version
                false, -- is_deleted
                NOW()
            );

            RAISE NOTICE 'Created default list % for user %', list_id, user_id_param;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Create default lists for all existing users
DO $$
DECLARE
    user_record RECORD;
BEGIN
    FOR user_record IN SELECT id FROM auth.users
    LOOP
        PERFORM create_default_lists_for_user(user_record.id);
    END LOOP;

    RAISE NOTICE 'Default lists creation completed for all existing users';
END;
$$;

-- Create trigger to automatically create default lists for new users
CREATE OR REPLACE FUNCTION auto_create_default_lists()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM create_default_lists_for_user(NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS auto_create_default_lists_trigger ON auth.users;

-- Create trigger for new user registration
CREATE TRIGGER auto_create_default_lists_trigger
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION auto_create_default_lists();

-- Add comment for documentation
COMMENT ON FUNCTION create_default_lists_for_user(UUID) IS 'Creates default movie lists for a specific user';
COMMENT ON FUNCTION auto_create_default_lists() IS 'Trigger function to automatically create default lists for new users';