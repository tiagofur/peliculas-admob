# Script para corregir la tabla user_movie_ratings en Supabase
# Este script te guía para ejecutar la migración SQL necesaria

Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║    FIX: Tabla user_movie_ratings - Columnas Faltantes       ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Cargar variables de entorno desde .env
$envPath = Join-Path $PSScriptRoot "..\.env"
$SUPABASE_URL = ""

if (Test-Path $envPath) {
    Get-Content $envPath | ForEach-Object {
        if ($_ -match '^SUPABASE_URL=(.*)$') {
            $SUPABASE_URL = $matches[1].Trim()
        }
    }
}

if (-not $SUPABASE_URL) {
    Write-Host "⚠️  No se pudo cargar SUPABASE_URL desde .env" -ForegroundColor Yellow
    $SUPABASE_URL = "https://fyzujpifkzftweynrudh.supabase.co"
}

Write-Host "🔗 URL de Supabase: $SUPABASE_URL" -ForegroundColor Gray
Write-Host ""

$migrationFile = Join-Path $PSScriptRoot "..\supabase\migrations\fix_user_movie_ratings_columns_20250930.sql"

if (-not (Test-Path $migrationFile)) {
    Write-Host "❌ ERROR: No se encontró el archivo de migración" -ForegroundColor Red
    Write-Host "   Ruta esperada: $migrationFile" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Archivo de migración encontrado:" -ForegroundColor Green
Write-Host "   $migrationFile" -ForegroundColor Gray
Write-Host ""

Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║                 INSTRUCCIONES PASO A PASO                    ║" -ForegroundColor Yellow
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""
Write-Host "📋 PASO 1: Abrir el SQL Editor de Supabase" -ForegroundColor Cyan
Write-Host "   Ve a: $SUPABASE_URL/project/_/sql" -ForegroundColor White
Write-Host ""
Write-Host "📋 PASO 2: Copiar el SQL de migración" -ForegroundColor Cyan
Write-Host "   El archivo está en:" -ForegroundColor White
Write-Host "   $migrationFile" -ForegroundColor Gray
Write-Host ""
Write-Host "📋 PASO 3: Ejecutar la migración" -ForegroundColor Cyan
Write-Host "   - Pega el contenido completo del archivo en el SQL Editor" -ForegroundColor White
Write-Host "   - Haz clic en el botón 'RUN' (o presiona Ctrl+Enter)" -ForegroundColor White
Write-Host "   - Verifica que no haya errores en los resultados" -ForegroundColor White
Write-Host ""
Write-Host "📋 PASO 4: Verificar que se agregaron las columnas" -ForegroundColor Cyan
Write-Host "   Deberías ver mensajes como:" -ForegroundColor White
Write-Host "   - NOTICE: Agregada columna: movie_backdrop_path" -ForegroundColor Gray
Write-Host "   - NOTICE: Agregada columna: review" -ForegroundColor Gray
Write-Host "   - etc..." -ForegroundColor Gray
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                  ¿QUÉ HACE ESTA MIGRACIÓN?                   ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Esta migración agrega las siguientes columnas faltantes:" -ForegroundColor White
Write-Host "  • movie_backdrop_path, movie_overview, movie_release_date" -ForegroundColor Gray
Write-Host "  • movie_vote_average, review, sync_version, device_id" -ForegroundColor Gray
Write-Host "  • is_deleted, last_modified_at, rated_at, is_public, tags" -ForegroundColor Gray
Write-Host ""
Write-Host "También crea los índices necesarios y actualiza el trigger." -ForegroundColor White
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║                    PROBLEMA RESUELTO                         ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""
Write-Host "Después de ejecutar esta migración:" -ForegroundColor White
Write-Host "  ✅ Las calificaciones se guardarán correctamente" -ForegroundColor Green
Write-Host "  ✅ La sincronización funcionará sin errores" -ForegroundColor Green
Write-Host "  ✅ Todos los campos de SyncableMovieRating se persistirán" -ForegroundColor Green
Write-Host ""

# Preguntar si quiere abrir el dashboard
Write-Host "¿Quieres abrir el SQL Editor de Supabase ahora? (S/N): " -NoNewline -ForegroundColor Yellow
$respuesta = Read-Host

if ($respuesta -eq "S" -or $respuesta -eq "s" -or $respuesta -eq "si" -or $respuesta -eq "SI") {
    Write-Host ""
    Write-Host "🌐 Abriendo Supabase SQL Editor..." -ForegroundColor Cyan
    Start-Process "$SUPABASE_URL/project/_/sql"
    
    Write-Host ""
    Write-Host "📂 Abriendo el archivo de migración en el editor..." -ForegroundColor Cyan
    Start-Process "code" -ArgumentList $migrationFile
    
    Write-Host ""
    Write-Host "✅ ¡Listo! Ahora solo copia y pega el SQL en el editor de Supabase." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "📝 Puedes ejecutar este script cuando estés listo." -ForegroundColor Yellow
    Write-Host "   El archivo de migración está en:" -ForegroundColor Gray
    Write-Host "   $migrationFile" -ForegroundColor Gray
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
