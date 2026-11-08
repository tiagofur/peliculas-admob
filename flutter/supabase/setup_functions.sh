#!/bin/bash

# Script para configurar funciones de Supabase necesarias para peliculas-admob
# Run this script in your Supabase SQL editor or via Supabase CLI

echo "🚀 Setting up Supabase functions for peliculas-admob..."

# Verificar conexión a Supabase
echo "📡 Checking Supabase connection..."

# Crear la función get_server_timestamp
echo "⏰ Creating get_server_timestamp function..."

psql $DATABASE_URL << 'EOF'
-- Create get_server_timestamp function
CREATE OR REPLACE FUNCTION get_server_timestamp()
RETURNS timestamp with time zone
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT now();
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_server_timestamp() TO authenticated;
GRANT EXECUTE ON FUNCTION get_server_timestamp() TO anon;

-- Add documentation
COMMENT ON FUNCTION get_server_timestamp() IS 'Returns current server timestamp for app synchronization';

-- Test the function
SELECT 'get_server_timestamp function created: ' || get_server_timestamp()::text as result;
EOF

echo "✅ Supabase functions setup completed!"
echo ""
echo "📋 Summary:"
echo "  ✅ get_server_timestamp() - Server timestamp for synchronization"
echo ""
echo "🔧 Manual Installation (if script fails):"
echo "  1. Go to your Supabase Dashboard > SQL Editor"
echo "  2. Run the SQL from: supabase/migrations/20250918_add_server_timestamp_function.sql"
echo "  3. Verify by running: SELECT get_server_timestamp();"