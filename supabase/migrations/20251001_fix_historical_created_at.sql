-- Migration: Fix created_at for historical ratings
-- Date: 2025-10-01
-- Description: Corrige created_at para que sea consistente con rated_at en registros históricos

-- =============================================
-- CORRECCIÓN DE DATOS HISTÓRICOS
-- =============================================

-- Para registros existentes donde created_at es posterior a rated_at,
-- ajustar created_at para que sea igual a rated_at
UPDATE public.user_movie_ratings
SET created_at = rated_at
WHERE created_at > rated_at
  AND rated_at IS NOT NULL;

-- También asegurar que last_modified_at sea al menos igual a rated_at
UPDATE public.user_movie_ratings
SET last_modified_at = GREATEST(last_modified_at, rated_at, created_at)
WHERE last_modified_at < rated_at 
  OR last_modified_at < created_at;

-- Verificar resultados
DO $$
DECLARE
    inconsistent_count INTEGER;
    total_count INTEGER;
BEGIN
    -- Contar registros con inconsistencias de timestamps
    SELECT COUNT(*) INTO inconsistent_count
    FROM public.user_movie_ratings
    WHERE created_at > rated_at 
       OR last_modified_at < created_at
       OR last_modified_at < rated_at;
    
    -- Contar total de registros
    SELECT COUNT(*) INTO total_count
    FROM public.user_movie_ratings;
    
    IF inconsistent_count > 0 THEN
        RAISE WARNING '⚠️ Still have % inconsistent timestamp records out of % total', 
            inconsistent_count, total_count;
    ELSE
        RAISE NOTICE '✅ All % rating records have consistent timestamps', total_count;
    END IF;
END $$;

-- =============================================
-- AÑADIR CONSTRAINT PARA PREVENIR FUTURAS INCONSISTENCIAS
-- =============================================

-- Constraint: created_at debe ser <= last_modified_at
ALTER TABLE public.user_movie_ratings
DROP CONSTRAINT IF EXISTS check_created_before_modified;

ALTER TABLE public.user_movie_ratings
ADD CONSTRAINT check_created_before_modified 
CHECK (created_at <= last_modified_at);

-- Constraint: rated_at debe ser >= created_at (el usuario no puede calificar antes de que exista el registro)
-- Comentado porque rated_at podría ser anterior si se sincroniza después
-- ALTER TABLE public.user_movie_ratings
-- ADD CONSTRAINT check_rated_after_created 
-- CHECK (rated_at >= created_at);

COMMENT ON CONSTRAINT check_created_before_modified ON public.user_movie_ratings 
IS 'Ensures created_at is never after last_modified_at for data consistency';

-- =============================================
-- VERIFICACIÓN FINAL
-- =============================================

-- Mostrar estadísticas de timestamps
SELECT 
    COUNT(*) as total_ratings,
    COUNT(CASE WHEN created_at <= rated_at THEN 1 END) as created_before_rated,
    COUNT(CASE WHEN created_at > rated_at THEN 1 END) as created_after_rated,
    COUNT(CASE WHEN last_modified_at >= created_at THEN 1 END) as modified_after_created,
    MIN(created_at) as earliest_created,
    MAX(created_at) as latest_created,
    MIN(rated_at) as earliest_rated,
    MAX(rated_at) as latest_rated
FROM public.user_movie_ratings;
