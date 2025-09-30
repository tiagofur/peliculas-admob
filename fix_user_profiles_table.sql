-- 🔧 CORRECCIÓN URGENTE: Tabla user_profiles missing/inconsistent
-- Ejecutar este script en Supabase Dashboard > SQL Editor
-- Este script crea/actualiza la tabla user_profiles para que coincida con el código

-- =======================
-- PASO 1: Crear tabla user_profiles si no existe
-- =======================

CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name VARCHAR(100),
    bio TEXT CHECK (char_length(bio) <= 500),
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Agregar updated_at si no existe (para tablas existentes sin esta columna)
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- =======================
-- PASO 2: Migrar de full_name a display_name (como espera el código)
-- =======================

-- Agregar columnas faltantes que el código espera
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS display_name VARCHAR(100),
ADD COLUMN IF NOT EXISTS email VARCHAR(255),
ADD COLUMN IF NOT EXISTS banner_url TEXT,
ADD COLUMN IF NOT EXISTS last_active_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS custom_fields JSONB DEFAULT '{}',
ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Migrar datos de full_name a display_name si es necesario
UPDATE user_profiles 
SET display_name = COALESCE(full_name, 'Usuario Anónimo') 
WHERE display_name IS NULL;

-- Establecer display_name como NOT NULL con valor por defecto
ALTER TABLE user_profiles ALTER COLUMN display_name SET DEFAULT 'Usuario Anónimo';
UPDATE user_profiles SET display_name = 'Usuario Anónimo' WHERE display_name IS NULL;
ALTER TABLE user_profiles ALTER COLUMN display_name SET NOT NULL;

-- Ahora podemos eliminar full_name si existe (opcional)
-- ALTER TABLE user_profiles DROP COLUMN IF EXISTS full_name;

-- =======================
-- PASO 3: Crear índices críticos
-- =======================

-- Índice único en user_id (CRÍTICO para onConflict)
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_created_at ON user_profiles(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_profiles_updated_at ON user_profiles(updated_at DESC);

-- =======================
-- PASO 4: Configurar RLS (Row Level Security)
-- =======================

-- Habilitar RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Eliminar políticas existentes que puedan estar en conflicto
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Public profiles are readable" ON user_profiles;

-- Crear políticas de seguridad actualizadas
CREATE POLICY "Users can view their own profile" ON user_profiles
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own profile" ON user_profiles
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own profile" ON user_profiles
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Política para permitir lectura pública (si es necesario)
CREATE POLICY "Public profiles are readable" ON user_profiles
    FOR SELECT USING (true);

-- =======================
-- PASO 5: Crear función de trigger actualizada
-- =======================

-- Función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para updated_at
DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON user_profiles;
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =======================
-- PASO 6: Función para crear perfiles automáticamente
-- =======================

-- Función mejorada para manejar nuevos usuarios
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- Crear user_profile con la estructura esperada por el código
    INSERT INTO public.user_profiles (user_id, display_name, email, avatar_url, last_active_date)
    VALUES (
        NEW.id,
        COALESCE(
            NEW.raw_user_meta_data->>'display_name', 
            NEW.raw_user_meta_data->>'full_name', 
            NEW.raw_user_meta_data->>'name',
            'Usuario Anónimo'
        ),
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'avatar_url', ''),
        NOW()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        email = NEW.email,
        last_active_date = NOW(),
        updated_at = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recrear trigger para nuevos usuarios
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =======================
-- PASO 7: Otorgar permisos
-- =======================

-- Permisos para usuarios autenticados
GRANT SELECT, INSERT, UPDATE ON user_profiles TO authenticated;
GRANT SELECT ON user_profiles TO anon;

-- Permisos en secuencias
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- =======================
-- PASO 8: Crear registro por defecto para usuario actual (si está autenticado)
-- =======================

-- Esta parte se ejecutará solo si hay un usuario actual
DO $$
DECLARE
    current_user_id UUID;
BEGIN
    -- Intentar obtener el ID del usuario actual si existe
    SELECT auth.uid() INTO current_user_id;
    
    -- Si hay un usuario actual, crear su perfil si no existe
    IF current_user_id IS NOT NULL THEN
        INSERT INTO public.user_profiles (user_id, display_name, last_active_date)
        VALUES (
            current_user_id,
            'Usuario Anónimo',
            NOW()
        )
        ON CONFLICT (user_id) DO UPDATE SET
            last_active_date = NOW(),
            updated_at = NOW();
            
        RAISE NOTICE 'Perfil creado/actualizado para usuario: %', current_user_id;
    ELSE
        RAISE NOTICE 'No hay usuario autenticado actual';
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'No se pudo crear perfil para usuario actual: %', SQLERRM;
END;
$$;

-- =======================
-- PASO 9: Verificación final
-- =======================

-- Verificar que la tabla tenga la estructura correcta
DO $$
DECLARE
    column_count INTEGER;
    unique_index_exists BOOLEAN;
    table_exists BOOLEAN;
    col_name TEXT;
BEGIN
    -- Verificar si la tabla existe
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'user_profiles' 
        AND table_schema = 'public'
    ) INTO table_exists;
    
    IF table_exists THEN
        -- Contar columnas críticas
        SELECT COUNT(*) INTO column_count
        FROM information_schema.columns 
        WHERE table_name = 'user_profiles' 
        AND table_schema = 'public'
        AND column_name IN ('user_id', 'display_name', 'email', 'avatar_url', 'updated_at');
        
        -- Verificar índice único en user_id
        SELECT EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE tablename = 'user_profiles' 
            AND indexname = 'idx_user_profiles_user_id'
        ) INTO unique_index_exists;
        
        -- Mostrar resultados
        RAISE NOTICE 'Tabla user_profiles existe: %', table_exists;
        RAISE NOTICE 'Columnas críticas encontradas: % de 5', column_count;
        RAISE NOTICE 'Índice único en user_id existe: %', unique_index_exists;
        
        IF column_count >= 5 AND unique_index_exists THEN
            RAISE NOTICE '✅ Tabla user_profiles configurada correctamente';
        ELSE
            RAISE NOTICE '⚠️ Tabla user_profiles puede tener problemas de configuración';
            
            -- Mostrar qué columnas faltan
            RAISE NOTICE 'Columnas existentes en user_profiles:';
            FOR col_name IN 
                SELECT c.column_name 
                FROM information_schema.columns c 
                WHERE c.table_name = 'user_profiles' 
                AND c.table_schema = 'public'
                ORDER BY c.ordinal_position
            LOOP
                RAISE NOTICE '  - %', col_name;
            END LOOP;
        END IF;
    ELSE
        RAISE NOTICE '❌ Tabla user_profiles no existe';
    END IF;
END;
$$;

-- Mensaje final (solo si la tabla existe)
DO $$
DECLARE
    table_exists BOOLEAN;
    total_count INTEGER := 0;
    display_name_count INTEGER := 0;
BEGIN
    -- Verificar si la tabla existe
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'user_profiles' 
        AND table_schema = 'public'
    ) INTO table_exists;
    
    IF table_exists THEN
        -- Contar registros de forma segura
        SELECT COUNT(*) INTO total_count FROM user_profiles;
        
        -- Contar registros con display_name (solo si la columna existe)
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'user_profiles' 
            AND column_name = 'display_name' 
            AND table_schema = 'public'
        ) THEN
            SELECT COUNT(*) INTO display_name_count 
            FROM user_profiles 
            WHERE display_name IS NOT NULL;
        END IF;
        
        RAISE NOTICE '📊 RESUMEN: user_profiles table ready!';
        RAISE NOTICE '   Total profiles: %', total_count;
        RAISE NOTICE '   Profiles with display_name: %', display_name_count;
    ELSE
        RAISE NOTICE '❌ No se pudo crear la tabla user_profiles';
    END IF;
END;
$$;