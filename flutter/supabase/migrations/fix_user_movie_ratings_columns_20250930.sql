-- Migration: Fix user_movie_ratings table to add missing columns
-- Date: 2025-09-30
-- Description: Adds missing columns required by SyncableMovieRating entity

-- =============================================
-- AGREGAR COLUMNAS FALTANTES
-- =============================================

DO $$ 
BEGIN
    -- movie_backdrop_path
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_movie_ratings' 
        AND column_name = 'movie_backdrop_path'
    ) THEN
        ALTER TABLE public.user_movie_ratings 
        ADD COLUMN movie_backdrop_path TEXT;
        RAISE NOTICE 'Agregada columna: movie_backdrop_path';
    END IF;

    -- movie_overview
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_movie_ratings' 
        AND column_name = 'movie_overview'
    ) THEN
        ALTER TABLE public.user_movie_ratings 
        ADD COLUMN movie_overview TEXT;
        RAISE NOTICE 'Agregada columna: movie_overview';
    END IF;

    -- movie_release_date
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_movie_ratings' 
        AND column_name = 'movie_release_date'
    ) THEN
        ALTER TABLE public.user_movie_ratings 
        ADD COLUMN movie_release_date DATE;
        RAISE NOTICE 'Agregada columna: movie_release_date';
    END IF;

    -- movie_vote_average
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_movie_ratings' 
        AND column_name = 'movie_vote_average'
    ) THEN
        ALTER TABLE public.user_movie_ratings 
        ADD COLUMN movie_vote_average DECIMAL(3,1);
        RAISE NOTICE 'Agregada columna: movie_vote_average';
    END IF;

    -- review (cambiar de personal_note a review si es necesario)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_movie_ratings' 
        AND column_name = 'review'
    ) THEN
        -- Si existe personal_note, renombrarla
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'user_movie_ratings' 
            AND column_name = 'personal_note'
        ) THEN
            ALTER TABLE public.user_movie_ratings 
            RENAME COLUMN personal_note TO review;
            RAISE NOTICE 'Renombrada columna: personal_note -> review';
        ELSE
            ALTER TABLE public.user_movie_ratings 
            ADD COLUMN review TEXT;
            RAISE NOTICE 'Agregada columna: review';
        END IF;
    END IF;

    -- Columnas de sincronización
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_movie_ratings' 
        AND column_name = 'sync_version'
    ) THEN
        ALTER TABLE public.user_movie_ratings 
        ADD COLUMN sync_version INTEGER DEFAULT 1 NOT NULL;
        RAISE NOTICE 'Agregada columna: sync_version';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_movie_ratings' 
        AND column_name = 'device_id'
    ) THEN
        ALTER TABLE public.user_movie_ratings 
        ADD COLUMN device_id VARCHAR(255);
        RAISE NOTICE 'Agregada columna: device_id';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_movie_ratings' 
        AND column_name = 'is_deleted'
    ) THEN
        ALTER TABLE public.user_movie_ratings 
        ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE NOT NULL;
        RAISE NOTICE 'Agregada columna: is_deleted';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_movie_ratings' 
        AND column_name = 'last_modified_at'
    ) THEN
        -- Si existe updated_at, renombrarla
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'user_movie_ratings' 
            AND column_name = 'updated_at'
        ) THEN
            ALTER TABLE public.user_movie_ratings 
            RENAME COLUMN updated_at TO last_modified_at;
            RAISE NOTICE 'Renombrada columna: updated_at -> last_modified_at';
        ELSE
            ALTER TABLE public.user_movie_ratings 
            ADD COLUMN last_modified_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL;
            RAISE NOTICE 'Agregada columna: last_modified_at';
        END IF;
    END IF;

    -- Columnas adicionales
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_movie_ratings' 
        AND column_name = 'rated_at'
    ) THEN
        ALTER TABLE public.user_movie_ratings 
        ADD COLUMN rated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL;
        
        -- Copiar fecha de created_at a rated_at para registros existentes
        UPDATE public.user_movie_ratings 
        SET rated_at = created_at 
        WHERE rated_at IS NULL;
        
        RAISE NOTICE 'Agregada columna: rated_at';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_movie_ratings' 
        AND column_name = 'is_public'
    ) THEN
        ALTER TABLE public.user_movie_ratings 
        ADD COLUMN is_public BOOLEAN DEFAULT FALSE NOT NULL;
        RAISE NOTICE 'Agregada columna: is_public';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_movie_ratings' 
        AND column_name = 'tags'
    ) THEN
        ALTER TABLE public.user_movie_ratings 
        ADD COLUMN tags TEXT[] DEFAULT '{}';
        RAISE NOTICE 'Agregada columna: tags';
    END IF;
END $$;

-- =============================================
-- CREAR ÍNDICES FALTANTES
-- =============================================

CREATE INDEX IF NOT EXISTS idx_user_movie_ratings_sync_version 
    ON public.user_movie_ratings(sync_version);

CREATE INDEX IF NOT EXISTS idx_user_movie_ratings_last_modified 
    ON public.user_movie_ratings(last_modified_at);

CREATE INDEX IF NOT EXISTS idx_user_movie_ratings_device_id 
    ON public.user_movie_ratings(device_id) WHERE device_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_user_movie_ratings_not_deleted 
    ON public.user_movie_ratings(user_id, movie_id) WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_user_movie_ratings_public 
    ON public.user_movie_ratings(movie_id, rating) WHERE is_public = TRUE AND is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_user_movie_ratings_sync 
    ON public.user_movie_ratings(user_id, last_modified_at, sync_version) WHERE is_deleted = FALSE;

-- =============================================
-- ACTUALIZAR TRIGGER
-- =============================================

CREATE OR REPLACE FUNCTION update_user_movie_ratings_modified_time()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_modified_at = TIMEZONE('utc', NOW());
    IF OLD.sync_version IS NOT NULL THEN
        NEW.sync_version = OLD.sync_version + 1;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_user_movie_ratings_modified_time ON public.user_movie_ratings;
CREATE TRIGGER trigger_update_user_movie_ratings_modified_time
    BEFORE UPDATE ON public.user_movie_ratings
    FOR EACH ROW
    EXECUTE FUNCTION update_user_movie_ratings_modified_time();

-- =============================================
-- VERIFICAR ESTRUCTURA FINAL
-- =============================================

SELECT 
    'Migración completada - Estructura de la tabla:' AS message;

SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'user_movie_ratings'
ORDER BY ordinal_position;
