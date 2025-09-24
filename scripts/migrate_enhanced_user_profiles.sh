#!/bin/bash

# Script para ejecutar la migración de perfiles de usuario mejorados en Supabase
# Fecha: 2025-01-20
# Descripción: Aplica el esquema completo para el sistema de perfiles de usuario

set -e

echo "🔄 Iniciando migración de perfiles de usuario mejorados en Supabase..."

# Verificar que estemos en el directorio correcto
if [ ! -f "supabase/migrations/20250120_create_enhanced_user_profiles.sql" ]; then
    echo "❌ Error: No se encontró el archivo de migración"
    echo "   Asegúrate de ejecutar este script desde la raíz del proyecto"
    exit 1
fi

# Verificar variables de entorno de Supabase
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_SERVICE_ROLE_KEY" ]; then
    echo "⚠️  Cargando variables de entorno desde .env..."
    
    if [ -f ".env" ]; then
        export $(grep -v '^#' .env | xargs)
    else
        echo "❌ Error: No se encontró archivo .env"
        echo "   Crea un archivo .env con SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY"
        exit 1
    fi
fi

# Verificar que las variables estén configuradas
if [ -z "$SUPABASE_URL" ]; then
    echo "❌ Error: SUPABASE_URL no está configurado"
    exit 1
fi

if [ -z "$SUPABASE_SERVICE_ROLE_KEY" ]; then
    echo "❌ Error: SUPABASE_SERVICE_ROLE_KEY no está configurado"
    exit 1
fi

echo "✅ Configuración verificada"
echo "🔗 URL de Supabase: ${SUPABASE_URL:0:30}..."
echo "🔑 Service Key: ${SUPABASE_SERVICE_ROLE_KEY:0:20}..."

# Función para ejecutar SQL en Supabase
execute_sql() {
    local sql_file="$1"
    local description="$2"
    
    echo "📋 Ejecutando: $description"
    
    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        "${SUPABASE_URL}/rest/v1/rpc/exec_sql" \
        -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"sql\":$(jq -Rs . < "$sql_file")}")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        echo "✅ $description - Ejecutado correctamente"
        if [ "$body" != "null" ] && [ -n "$body" ]; then
            echo "   Respuesta: $body"
        fi
    else
        echo "❌ $description - Error (HTTP $http_code)"
        echo "   Respuesta: $body"
        return 1
    fi
}

# Función alternativa usando psql si está disponible
execute_sql_psql() {
    local sql_file="$1"
    local description="$2"
    
    echo "📋 Ejecutando con psql: $description"
    
    # Extraer componentes de la URL de Supabase
    # Formato: https://project.supabase.co
    project_id=$(echo "$SUPABASE_URL" | sed -n 's/https:\/\/\([^.]*\)\.supabase\.co.*/\1/p')
    
    if [ -z "$project_id" ]; then
        echo "❌ No se pudo extraer project_id de SUPABASE_URL"
        return 1
    fi
    
    # Crear conexión temporal a PostgreSQL
    export PGPASSWORD="$SUPABASE_SERVICE_ROLE_KEY"
    
    if psql -h "db.${project_id}.supabase.co" -p 5432 -d postgres -U postgres -f "$sql_file"; then
        echo "✅ $description - Ejecutado correctamente con psql"
    else
        echo "❌ $description - Error con psql"
        return 1
    fi
}

# Intentar ejecutar la migración
migration_file="supabase/migrations/20250120_create_enhanced_user_profiles.sql"

echo ""
echo "🚀 Aplicando migración de perfiles de usuario mejorados..."

# Primero intentar con la API REST
if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    echo "🔧 Usando API REST de Supabase..."
    if execute_sql "$migration_file" "Migración de perfiles mejorados"; then
        echo ""
        echo "🎉 ¡Migración completada exitosamente!"
        echo ""
        echo "📊 Tablas creadas/modificadas:"
        echo "   - user_profiles (expandida)"
        echo "   - user_statistics (nueva)"
        echo "   - user_preferences (nueva)"  
        echo "   - user_achievements (nueva)"
        echo ""
        echo "🔒 Políticas RLS configuradas para todas las tablas"
        echo "⚙️  Funciones auxiliares creadas"
        echo "📈 Triggers de actualización configurados"
        echo ""
        echo "✅ El sistema de perfiles de usuario está listo para usar"
    else
        echo "❌ Error en la migración con API REST"
        exit 1
    fi
else
    # Fallback a psql si está disponible
    if command -v psql >/dev/null 2>&1; then
        echo "🔧 curl/jq no disponibles, usando psql..."
        if execute_sql_psql "$migration_file" "Migración de perfiles mejorados"; then
            echo ""
            echo "🎉 ¡Migración completada exitosamente!"
        else
            echo "❌ Error en la migración con psql"
            exit 1
        fi
    else
        echo "❌ Error: Necesitas curl+jq o psql para ejecutar la migración"
        echo "   Instala uno de estos conjuntos de herramientas:"
        echo "   - curl + jq: apt install curl jq"
        echo "   - PostgreSQL client: apt install postgresql-client"
        exit 1
    fi
fi

# Mostrar próximos pasos
echo ""
echo "🎯 Próximos pasos recomendados:"
echo ""
echo "1. 🏃‍♂️ Ejecutar tests de integración:"
echo "   flutter test integration_test/user_authentication_flow_test.dart"
echo ""
echo "2. 📱 Probar la aplicación:"
echo "   flutter run"
echo ""
echo "3. 🔍 Verificar en Supabase Dashboard:"
echo "   - Revisar que las tablas se crearon correctamente"
echo "   - Verificar las políticas RLS"
echo "   - Probar las funciones auxiliares"
echo ""
echo "4. 📋 Actualizar documentación:"
echo "   - Marcar TODO #10 como completado"
echo "   - Documentar los cambios realizados"
echo ""

exit 0