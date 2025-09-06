-- =============================================
-- ENABLE REALTIME FOR USER DATA TABLES
-- =============================================
-- This migration enables real-time functionality for all user data tables
-- that need cross-device synchronization

-- =============================================
-- PHASE 1: CONFIGURE REPLICA IDENTITY
-- =============================================
-- Set replica identity to FULL for all user tables to enable real-time
-- This allows Supabase to track all column changes, not just primary key

DO $$
DECLARE
    tbl_name text;
    tables text[] := ARRAY['user_favorites', 'user_watched_movies', 'user_watchlist', 'user_lists', 'user_list_items'];
BEGIN
    RAISE NOTICE '🔧 Configurando replica identity para real-time...';
    
    FOREACH tbl_name IN ARRAY tables
    LOOP
        -- Set replica identity to FULL for complete change tracking
        EXECUTE format('ALTER TABLE public.%I REPLICA IDENTITY FULL', tbl_name);
        RAISE NOTICE '✅ %: Replica identity configurada', tbl_name;
    END LOOP;
    
    RAISE NOTICE '✅ Replica identity configurada para todas las tablas';
END $$;

-- =============================================
-- PHASE 2: CREATE PUBLICATION FOR REALTIME
-- =============================================
-- Create publication that includes all user data tables
-- This tells PostgreSQL which tables should send change events

DO $$
BEGIN
    -- Drop existing publication if it exists
    DROP PUBLICATION IF EXISTS supabase_realtime;
    
    -- Create new publication with all user tables
    CREATE PUBLICATION supabase_realtime FOR TABLE 
        user_favorites,
        user_watched_movies,
        user_watchlist,
        user_lists,
        user_list_items;
    
    RAISE NOTICE '✅ Publicación supabase_realtime creada con todas las tablas de usuario';
END $$;

-- =============================================
-- PHASE 3: VERIFY REALTIME CONFIGURATION
-- =============================================
-- Queries to verify the real-time configuration is correct

DO $$
DECLARE
    tbl_name text;
    tables text[] := ARRAY['user_favorites', 'user_watched_movies', 'user_watchlist', 'user_lists', 'user_list_items'];
    pub_count integer;
    replica_count integer;
BEGIN
    RAISE NOTICE '=== VERIFICACIÓN DE CONFIGURACIÓN REAL-TIME ===';
    
    -- Check publication exists and has tables
    SELECT COUNT(*) INTO pub_count
    FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime';
    
    RAISE NOTICE 'Tablas en publicación supabase_realtime: %', pub_count;
    
    -- Check replica identity for each table
    FOREACH tbl_name IN ARRAY tables
    LOOP
        SELECT COUNT(*) INTO replica_count
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relname = tbl_name 
        AND n.nspname = 'public'
        AND c.relreplident = 'f'; -- 'f' means FULL
        
        IF replica_count = 1 THEN
            RAISE NOTICE '✅ %: Replica identity FULL configurada', tbl_name;
        ELSE
            RAISE WARNING '❌ %: Replica identity NO configurada', tbl_name;
        END IF;
    END LOOP;
    
    RAISE NOTICE '=== CONFIGURACIÓN REAL-TIME COMPLETADA ===';
END $$;

-- =============================================
-- PHASE 4: ADDITIONAL REALTIME OPTIMIZATIONS
-- =============================================
-- Add optimizations for better real-time performance

-- Enable WAL (Write-Ahead Logging) if not already enabled
-- This is usually enabled by default in Supabase but we verify it
DO $$
BEGIN
    -- Check if WAL is enabled
    IF current_setting('wal_level') != 'logical' THEN
        RAISE NOTICE '⚠️  WAL level no es logical. Esto debe configurarse a nivel de instancia.';
        RAISE NOTICE 'Contactar soporte de Supabase si hay problemas de real-time.';
    ELSE
        RAISE NOTICE '✅ WAL level es logical - real-time funcionará correctamente';
    END IF;
END $$;

-- =============================================
-- COMMENTS AND DOCUMENTATION
-- =============================================

COMMENT ON PUBLICATION supabase_realtime IS 'Publicación para real-time sync de datos de usuario entre dispositivos';

-- Log completion
DO $$
BEGIN
    RAISE NOTICE '🎉 REAL-TIME HABILITADO PARA TODAS LAS TABLAS DE USUARIO';
    RAISE NOTICE '📱 Los cambios en favoritos, watchlist, etc. se sincronizarán automáticamente';
    RAISE NOTICE '🔄 Reiniciar la aplicación para activar los listeners de real-time';
END $$;