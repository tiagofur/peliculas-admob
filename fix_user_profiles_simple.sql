-- 🔧 CORRECCIÓN SIMPLE: Crear tabla user_profiles desde cero
-- Ejecutar este script en Supabase Dashboard > SQL Editor
-- Version simplificada que evita errores de columnas faltantes

-- =======================
-- PASO 1: RECREAR tabla user_profiles con estructura completa
-- =======================

-- Eliminar tabla existente si tiene problemas (CUIDADO: esto borra datos)
-- Descomenta las siguientes líneas solo si quieres empezar desde cero:
-- DROP TABLE IF EXISTS user_profiles CASCADE;

-- Crear tabla user_profiles con TODAS las columnas que el código necesita
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    -- Columnas básicas
    full_name VARCHAR(100),
    display_name VARCHAR(100) NOT NULL DEFAULT 'Usuario Anónimo',
    bio TEXT CHECK (char_length(bio) <= 500),
    email VARCHAR(255),
    -- URLs
    avatar_url TEXT,
    banner_url TEXT,
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_active_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_synced_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- Campos adicionales
    custom_fields JSONB DEFAULT '{}'
);

-- =======================
-- PASO 2: Crear índices CRÍTICOS
-- =======================

-- Índice único en user_id (CRÍTICO para onConflict)
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_created_at ON user_profiles(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_profiles_updated_at ON user_profiles(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_profiles_display_name ON user_profiles(display_name);

-- =======================
-- PASO 3: Configurar RLS (Row Level Security)
-- =======================

-- Habilitar RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Eliminar políticas existentes que puedan estar en conflicto
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Public profiles are readable" ON user_profiles;

-- Crear políticas de seguridad
CREATE POLICY "Users can view their own profile" ON user_profiles
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own profile" ON user_profiles
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own profile" ON user_profiles
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Política para permitir lectura pública (comentar si no quieres perfiles públicos)
CREATE POLICY "Public profiles are readable" ON user_profiles
    FOR SELECT USING (true);

-- =======================
-- PASO 4: Función para updated_at automático
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
-- PASO 5: Función para crear perfiles automáticamente
-- =======================

-- Función para crear perfiles cuando se registra un usuario
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (
        user_id, 
        display_name, 
        full_name,
        email, 
        avatar_url, 
        last_active_date
    )
    VALUES (
        NEW.id,
        COALESCE(
            NEW.raw_user_meta_data->>'display_name', 
            NEW.raw_user_meta_data->>'full_name', 
            NEW.raw_user_meta_data->>'name',
            'Usuario Anónimo'
        ),
        COALESCE(
            NEW.raw_user_meta_data->>'full_name', 
            NEW.raw_user_meta_data->>'display_name', 
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
-- PASO 6: Otorgar permisos
-- =======================

-- Permisos para usuarios autenticados
GRANT SELECT, INSERT, UPDATE ON user_profiles TO authenticated;
GRANT SELECT ON user_profiles TO anon;

-- Permisos en secuencias
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- =======================
-- PASO 7: Crear perfil para usuario actual (si existe)
-- =======================

DO $$
DECLARE
    current_user_id UUID;
BEGIN
    SELECT auth.uid() INTO current_user_id;
    
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
            
        RAISE NOTICE '✅ Perfil creado/actualizado para usuario: %', current_user_id;
    ELSE
        RAISE NOTICE 'ℹ️ No hay usuario autenticado actual';
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️ No se pudo crear perfil para usuario actual: %', SQLERRM;
END;
$$;

-- =======================
-- PASO 8: Verificación final
-- =======================

DO $$
DECLARE
    column_count INTEGER;
    unique_index_exists BOOLEAN;
    table_exists BOOLEAN;
    total_profiles INTEGER;
BEGIN
    -- Verificar tabla
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'user_profiles' AND table_schema = 'public'
    ) INTO table_exists;
    
    IF table_exists THEN
        -- Contar columnas críticas
        SELECT COUNT(*) INTO column_count
        FROM information_schema.columns 
        WHERE table_name = 'user_profiles' AND table_schema = 'public'
        AND column_name IN ('user_id', 'display_name', 'email', 'avatar_url', 'updated_at');
        
        -- Verificar índice único
        SELECT EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE tablename = 'user_profiles' AND indexname = 'idx_user_profiles_user_id'
        ) INTO unique_index_exists;
        
        -- Contar perfiles
        SELECT COUNT(*) INTO total_profiles FROM user_profiles;
        
        -- Resultados
        RAISE NOTICE '✅ Tabla user_profiles: EXISTE';
        RAISE NOTICE '📊 Columnas críticas: % de 5', column_count;
        RAISE NOTICE '🔑 Índice único user_id: %', 
            CASE WHEN unique_index_exists THEN 'SÍ' ELSE 'NO' END;
        RAISE NOTICE '👥 Total perfiles: %', total_profiles;
        
        IF column_count >= 5 AND unique_index_exists THEN
            RAISE NOTICE '🎉 ¡Tabla user_profiles configurada correctamente!';
        ELSE
            RAISE NOTICE '⚠️ Tabla user_profiles tiene problemas de configuración';
        END IF;
    ELSE
        RAISE NOTICE '❌ ERROR: Tabla user_profiles no existe';
    END IF;
END;
$$;

-- Final: Mostrar estructura de la tabla
SELECT 
    'user_profiles table setup completed!' as status,
    current_timestamp as completed_at;