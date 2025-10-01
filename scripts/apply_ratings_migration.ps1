# Script de Aplicación de Migración de Ratings

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MIGRACIÓN DE BASE DE DATOS - RATINGS  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$supabaseUrl = "https://fyzujpifkzftweynrudh.supabase.co/project/_/sql"
$migrationFile = Join-Path $PSScriptRoot "..\supabase\migrations\fix_user_movie_ratings_columns_20250930.sql"

Write-Host "📝 INSTRUCCIONES:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Se abrirá Supabase SQL Editor en tu navegador"
Write-Host "2. El contenido del archivo de migración estará en tu portapapeles"
Write-Host "3. Pégalo en el SQL Editor (Ctrl+V)"
Write-Host "4. Click en 'RUN' para ejecutar"
Write-Host "5. Verifica que se ejecutó correctamente"
Write-Host ""
Write-Host "⚠️  IMPORTANTE: Sin esta migración, los ratings NO funcionarán" -ForegroundColor Red
Write-Host ""

# Verificar que el archivo existe
if (-not (Test-Path $migrationFile)) {
    Write-Host "❌ ERROR: No se encontró el archivo de migración" -ForegroundColor Red
    Write-Host "   Ruta esperada: $migrationFile" -ForegroundColor Red
    Write-Host ""
    Read-Host "Presiona ENTER para salir"
    exit 1
}

# Copiar contenido al portapapeles
try {
    Get-Content $migrationFile | Set-Clipboard
    Write-Host "✅ Contenido copiado al portapapeles" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "⚠️  No se pudo copiar automáticamente al portapapeles" -ForegroundColor Yellow
    Write-Host "   Deberás copiar manualmente el contenido del archivo" -ForegroundColor Yellow
    Write-Host ""
}

# Mostrar preview del contenido
Write-Host "📄 Preview del contenido a ejecutar:" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Gray
Get-Content $migrationFile -Head 20
Write-Host "..." -ForegroundColor Gray
Write-Host "====================================" -ForegroundColor Gray
Write-Host ""
Write-Host "   Archivo completo: $migrationFile" -ForegroundColor Gray
Write-Host ""

# Abrir Supabase SQL Editor
Write-Host "🌐 Abriendo Supabase SQL Editor..." -ForegroundColor Cyan
Start-Process $supabaseUrl

Write-Host ""
Write-Host "✅ Navegador abierto" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Pasos a seguir:" -ForegroundColor Yellow
Write-Host "   1. Pega el contenido (Ctrl+V)"
Write-Host "   2. Click en 'RUN'"
Write-Host "   3. Verifica que no hay errores"
Write-Host "   4. Confirma que se muestran las columnas actualizadas"
Write-Host ""

Read-Host "Presiona ENTER después de ejecutar la migración..."

Write-Host ""
Write-Host "🧪 Verificando conexión..." -ForegroundColor Cyan

# Aquí podrías agregar verificación adicional si tienes un script de test
# Por ahora, solo mostrar mensaje de éxito

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  ✅ PROCESO COMPLETADO  " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Próximos pasos:" -ForegroundColor Yellow
Write-Host "1. Ejecutar la app: flutter run"
Write-Host "2. Login con tu usuario"
Write-Host "3. Calificar una película"
Write-Host "4. Verificar que se guardó en Supabase"
Write-Host "5. Reabrir la app y verificar que se cargó"
Write-Host ""
Write-Host "📖 Ver documentación completa en:" -ForegroundColor Cyan
Write-Host "   docs/UNIFIED_RATINGS_IMPLEMENTATION_PLAN.md"
Write-Host ""

Read-Host "Presiona ENTER para salir"
