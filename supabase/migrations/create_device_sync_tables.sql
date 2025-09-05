-- =============================================
-- DEVICE SYNC TABLES MIGRATION
-- =============================================
-- Creates tables for multi-device synchronization tracking
-- Created: 2025-09-05

-- =============================================
-- TABLA: user_devices
-- =============================================
-- Tracks user devices for multi-device sync coordination
CREATE TABLE IF NOT EXISTS user_devices (
    id VARCHAR(100) PRIMARY KEY, -- Device UUID
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    platform VARCHAR(50) NOT NULL,
    app_version VARCHAR(20) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- Índices para user_devices
CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON user_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_last_seen ON user_devices(last_seen DESC);
CREATE INDEX IF NOT EXISTS idx_user_devices_platform ON user_devices(platform);

-- =============================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================

-- Habilitar RLS para user_devices
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- =============================================
-- POLÍTICAS DE SEGURIDAD
-- =============================================

-- Políticas para user_devices
CREATE POLICY "Users can manage their own devices" ON user_devices
    FOR ALL USING (auth.uid() = user_id);

-- =============================================
-- PERMISOS PARA ROLES
-- =============================================

-- Otorgar permisos completos a rol authenticated
GRANT ALL PRIVILEGES ON user_devices TO authenticated;

-- =============================================
-- TRIGGERS Y FUNCIONES
-- =============================================

-- Trigger para actualizar last_seen automáticamente en updates
CREATE OR REPLACE FUNCTION update_device_last_seen()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_seen = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_user_devices_last_seen 
    BEFORE UPDATE ON user_devices
    FOR EACH ROW 
    EXECUTE FUNCTION update_device_last_seen();

-- =============================================
-- COMENTARIOS PARA DOCUMENTACIÓN
-- =============================================

COMMENT ON TABLE user_devices IS 'Rastrea los dispositivos de cada usuario para coordinación de sync multi-dispositivo';
COMMENT ON COLUMN user_devices.id IS 'UUID único del dispositivo generado por la app';
COMMENT ON COLUMN user_devices.name IS 'Nombre descriptivo del dispositivo (ej: "iPhone de Juan")';
COMMENT ON COLUMN user_devices.platform IS 'Plataforma del dispositivo (iOS, Android, Web, Windows, etc.)';
COMMENT ON COLUMN user_devices.app_version IS 'Versión de la aplicación instalada';
COMMENT ON COLUMN user_devices.last_seen IS 'Última vez que el dispositivo se conectó';
COMMENT ON COLUMN user_devices.is_active IS 'Indica si el dispositivo está activo (no eliminado por el usuario)';

-- =============================================
-- VERIFICACIÓN Y LOG
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '=== DEVICE SYNC TABLES MIGRATION ===';
    
    -- Verificar que las tablas existen
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_devices' AND table_schema = 'public') THEN
        RAISE NOTICE '✅ user_devices table created successfully';
    ELSE
        RAISE WARNING '❌ user_devices table creation failed';
    END IF;
    
    -- Verificar que las tablas existentes tienen las columnas de sync necesarias
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'sync_status' AND table_schema = 'public') THEN
        RAISE NOTICE '✅ sync_status table already exists';
    ELSE
        RAISE NOTICE 'ℹ️ sync_status table will be created by unified sync schema migration';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'sync_conflicts' AND table_schema = 'public') THEN
        RAISE NOTICE '✅ sync_conflicts table already exists';
    ELSE
        RAISE NOTICE 'ℹ️ sync_conflicts table will be created by unified sync schema migration';
    END IF;
    
    RAISE NOTICE '=== DEVICE SYNC MIGRATION COMPLETED ===';
END $$;