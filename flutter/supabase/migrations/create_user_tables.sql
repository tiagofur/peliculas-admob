-- Crear tabla de perfiles de usuario de forma idempotente
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name VARCHAR(100) NOT NULL,
    bio TEXT CHECK (char_length(bio) <= 500),
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear índices para user_profiles
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_created_at ON user_profiles(created_at DESC);

-- Habilitar RLS (Row Level Security) para user_profiles
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Políticas de seguridad para user_profiles (idempotentes)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE policyname = 'Users can view their own profile'
          AND schemaname = 'public'
          AND tablename = 'user_profiles'
    ) THEN
        CREATE POLICY "Users can view their own profile" ON user_profiles
            FOR SELECT USING (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE policyname = 'Users can update their own profile'
          AND schemaname = 'public'
          AND tablename = 'user_profiles'
    ) THEN
        CREATE POLICY "Users can update their own profile" ON user_profiles
            FOR UPDATE USING (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE policyname = 'Users can insert their own profile'
          AND schemaname = 'public'
          AND tablename = 'user_profiles'
    ) THEN
        CREATE POLICY "Users can insert their own profile" ON user_profiles
            FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
END;
$$;

-- Crear tabla de estadísticas de usuario de forma idempotente
CREATE TABLE IF NOT EXISTS user_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    movies_watched INTEGER DEFAULT 0,
    favorites_count INTEGER DEFAULT 0,
    lists_count INTEGER DEFAULT 0,
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_stats_user_id ON user_stats(user_id);
CREATE INDEX IF NOT EXISTS idx_user_stats_last_activity ON user_stats(last_activity DESC);

-- Habilitar RLS para user_stats
ALTER TABLE user_stats ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE policyname = 'Users can view their own stats'
          AND schemaname = 'public'
          AND tablename = 'user_stats'
    ) THEN
        CREATE POLICY "Users can view their own stats" ON user_stats
            FOR SELECT USING (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE policyname = 'Users can update their own stats'
          AND schemaname = 'public'
          AND tablename = 'user_stats'
    ) THEN
        CREATE POLICY "Users can update their own stats" ON user_stats
            FOR UPDATE USING (auth.uid() = user_id);
    END IF;
END;
$$;

-- Función para crear perfil automáticamente cuando se registra un usuario
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (user_id, full_name, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'Usuario'),
        COALESCE(NEW.raw_user_meta_data->>'avatar_url', '')
    );
    
    INSERT INTO public.user_stats (user_id)
    VALUES (NEW.id);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'on_auth_user_created'
    ) THEN
        CREATE TRIGGER on_auth_user_created
            AFTER INSERT ON auth.users
            FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
    END IF;
END;
$$;

-- Crear bucket para avatares
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Política para subir avatares
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE policyname = 'Users can upload their own avatar'
          AND schemaname = 'storage'
          AND tablename = 'objects'
    ) THEN
        CREATE POLICY "Users can upload their own avatar" ON storage.objects
            FOR INSERT WITH CHECK (
                bucket_id = 'avatars' AND 
                auth.uid()::text = (storage.foldername(name))[1]
            );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE policyname = 'Users can update their own avatar'
          AND schemaname = 'storage'
          AND tablename = 'objects'
    ) THEN
        CREATE POLICY "Users can update their own avatar" ON storage.objects
            FOR UPDATE USING (
                bucket_id = 'avatars' AND 
                auth.uid()::text = (storage.foldername(name))[1]
            );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE policyname = 'Anyone can view avatars'
          AND schemaname = 'storage'
          AND tablename = 'objects'
    ) THEN
        CREATE POLICY "Anyone can view avatars" ON storage.objects
            FOR SELECT USING (bucket_id = 'avatars');
    END IF;
END;
$$;

-- Otorgar permisos a los roles
GRANT SELECT ON user_profiles TO anon;
GRANT ALL PRIVILEGES ON user_profiles TO authenticated;
GRANT SELECT ON user_stats TO anon;
GRANT ALL PRIVILEGES ON user_stats TO authenticated;