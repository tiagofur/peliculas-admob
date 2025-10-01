-- Migration: Fix user_movie_ratings schema to match application requirements
-- Date: 2025-10-01
-- Description: Ensures the table has all required fields (created_at, rated_at, last_modified_at)

-- =============================================
-- VERIFICAR Y AÑADIR COLUMNAS FALTANTES
-- =============================================

-- Añadir created_at si no existe (para sincronización)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_movie_ratings' 
        AND column_name = 'created_at'
    ) THEN
        ALTER TABLE public.user_movie_ratings 
        ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL;
        
        RAISE NOTICE 'Added created_at column to user_movie_ratings';
        
        -- Copiar datos de rated_at si existe
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'user_movie_ratings' 
            AND column_name = 'rated_at'
        ) THEN
            UPDATE public.user_movie_ratings 
            SET created_at = rated_at 
            WHERE created_at IS NULL;
            RAISE NOTICE 'Copied rated_at to created_at for existing records';
        END IF;
    ELSE
        RAISE NOTICE 'created_at column already exists';
    END IF;
END $$;

-- Añadir last_modified_at si no existe (para sincronización)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_movie_ratings' 
        AND column_name = 'last_modified_at'
    ) THEN
        ALTER TABLE public.user_movie_ratings 
        ADD COLUMN last_modified_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL;
        
        RAISE NOTICE 'Added last_modified_at column to user_movie_ratings';
        
        -- Inicializar con created_at o rated_at
        UPDATE public.user_movie_ratings 
        SET last_modified_at = COALESCE(created_at, rated_at, TIMEZONE('utc', NOW()));
        
        RAISE NOTICE 'Initialized last_modified_at for existing records';
    ELSE
        RAISE NOTICE 'last_modified_at column already exists';
    END IF;
END $$;

-- Añadir sync_version si no existe (para resolución de conflictos)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_movie_ratings' 
        AND column_name = 'sync_version'
    ) THEN
        ALTER TABLE public.user_movie_ratings 
        ADD COLUMN sync_version INTEGER DEFAULT 1 NOT NULL;
        
        RAISE NOTICE 'Added sync_version column to user_movie_ratings';
    ELSE
        RAISE NOTICE 'sync_version column already exists';
    END IF;
END $$;

-- Añadir device_id si no existe (para identificar dispositivo origen)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_movie_ratings' 
        AND column_name = 'device_id'
    ) THEN
        ALTER TABLE public.user_movie_ratings 
        ADD COLUMN device_id VARCHAR(255);
        
        RAISE NOTICE 'Added device_id column to user_movie_ratings';
    ELSE
        RAISE NOTICE 'device_id column already exists';
    END IF;
END $$;

-- Añadir is_deleted si no existe (para soft deletes)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_movie_ratings' 
        AND column_name = 'is_deleted'
    ) THEN
        ALTER TABLE public.user_movie_ratings 
        ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE NOT NULL;
        
        RAISE NOTICE 'Added is_deleted column to user_movie_ratings';
    ELSE
        RAISE NOTICE 'is_deleted column already exists';
    END IF;
END $$;

-- =============================================
-- ACTUALIZAR O CREAR TRIGGER PARA last_modified_at
-- =============================================

-- Drop trigger existente si existe
DROP TRIGGER IF EXISTS trigger_update_user_movie_ratings_modified_time ON public.user_movie_ratings;

-- Crear o reemplazar función de trigger
CREATE OR REPLACE FUNCTION update_user_movie_ratings_modified_time()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_modified_at = TIMEZONE('utc', NOW());
    NEW.sync_version = OLD.sync_version + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger
CREATE TRIGGER trigger_update_user_movie_ratings_modified_time
    BEFORE UPDATE ON public.user_movie_ratings
    FOR EACH ROW
    EXECUTE FUNCTION update_user_movie_ratings_modified_time();

-- =============================================
-- CREAR ÍNDICES FALTANTES
-- =============================================

-- Índice para last_modified_at (importante para sync)
CREATE INDEX IF NOT EXISTS idx_user_movie_ratings_last_modified 
ON public.user_movie_ratings(last_modified_at);

-- Índice para sync operations
CREATE INDEX IF NOT EXISTS idx_user_movie_ratings_sync 
ON public.user_movie_ratings(user_id, last_modified_at, sync_version) 
WHERE is_deleted = FALSE;

-- Índice para device_id
CREATE INDEX IF NOT EXISTS idx_user_movie_ratings_device_id 
ON public.user_movie_ratings(device_id) 
WHERE device_id IS NOT NULL;

-- Índice para registros no eliminados
CREATE INDEX IF NOT EXISTS idx_user_movie_ratings_not_deleted 
ON public.user_movie_ratings(user_id, movie_id) 
WHERE is_deleted = FALSE;

-- =============================================
-- VERIFICACIÓN FINAL
-- =============================================

DO $$
DECLARE
    missing_columns TEXT[];
    required_columns TEXT[] := ARRAY[
        'id', 'user_id', 'movie_id', 'rating', 'movie_title',
        'created_at', 'rated_at', 'last_modified_at', 
        'sync_version', 'device_id', 'is_deleted'
    ];
    col TEXT;
BEGIN
    -- Verificar columnas requeridas
    FOREACH col IN ARRAY required_columns
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'user_movie_ratings' 
            AND column_name = col
        ) THEN
            missing_columns := array_append(missing_columns, col);
        END IF;
    END LOOP;
    
    IF array_length(missing_columns, 1) IS NOT NULL THEN
        RAISE EXCEPTION 'Missing required columns: %', array_to_string(missing_columns, ', ');
    ELSE
        RAISE NOTICE '✅ All required columns exist in user_movie_ratings table';
    END IF;
END $$;

-- =============================================
-- DOCUMENTACIÓN
-- =============================================

COMMENT ON COLUMN public.user_movie_ratings.created_at IS 'Timestamp when the rating record was first created (for sync system)';
COMMENT ON COLUMN public.user_movie_ratings.rated_at IS 'Timestamp when the user actually rated the movie (user-facing date)';
COMMENT ON COLUMN public.user_movie_ratings.last_modified_at IS 'Timestamp of last modification (for sync conflict resolution)';
COMMENT ON COLUMN public.user_movie_ratings.sync_version IS 'Version number for optimistic locking and conflict resolution';
COMMENT ON COLUMN public.user_movie_ratings.device_id IS 'Identifier of the device that created/modified this rating';
COMMENT ON COLUMN public.user_movie_ratings.is_deleted IS 'Soft delete flag for sync system';
