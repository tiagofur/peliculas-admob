# Script para corregir la tabla user_movie_ratings en Supabase
# Guía paso a paso para ejecutar la migración SQL

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  FIX: Tabla user_movie_ratings - Columnas Faltantes" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

$migrationFile = Join-Path $PSScriptRoot "..\supabase\migrations\fix_user_movie_ratings_columns_20250930.sql"
$supabaseUrl = "https://fyzujpifkzftweynrudh.supabase.co"

Write-Host "URL de Supabase: $supabaseUrl" -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $migrationFile)) {
    Write-Host "ERROR: No se encontró el archivo de migración" -ForegroundColor Red
    Write-Host "Ruta esperada: $migrationFile" -ForegroundColor Red
    exit 1
}

Write-Host "Archivo de migración encontrado:" -ForegroundColor Green
Write-Host "$migrationFile" -ForegroundColor Gray
Write-Host ""

Write-Host "================================================================" -ForegroundColor Yellow
Write-Host "  INSTRUCCIONES PASO A PASO" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "PASO 1: Abrir el SQL Editor de Supabase" -ForegroundColor Cyan
Write-Host "  Ve a: $supabaseUrl/project/_/sql" -ForegroundColor White
Write-Host ""
Write-Host "PASO 2: Copiar el SQL de migracion" -ForegroundColor Cyan
Write-Host "  El archivo esta en:" -ForegroundColor White
Write-Host "  $migrationFile" -ForegroundColor Gray
Write-Host ""
Write-Host "PASO 3: Ejecutar la migracion" -ForegroundColor Cyan
Write-Host "  - Pega el contenido completo del archivo en el SQL Editor" -ForegroundColor White
Write-Host "  - Haz clic en el boton RUN (o presiona Ctrl+Enter)" -ForegroundColor White
Write-Host "  - Verifica que no haya errores en los resultados" -ForegroundColor White
Write-Host ""
Write-Host "PASO 4: Verificar que se agregaron las columnas" -ForegroundColor Cyan
Write-Host "  Deberias ver mensajes como:" -ForegroundColor White
Write-Host "  - NOTICE: Agregada columna: movie_backdrop_path" -ForegroundColor Gray
Write-Host "  - NOTICE: Agregada columna: review" -ForegroundColor Gray
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  QUE HACE ESTA MIGRACION" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Esta migracion agrega las siguientes columnas faltantes:" -ForegroundColor White
Write-Host "  - movie_backdrop_path, movie_overview, movie_release_date" -ForegroundColor Gray
Write-Host "  - movie_vote_average, review, sync_version, device_id" -ForegroundColor Gray
Write-Host "  - is_deleted, last_modified_at, rated_at, is_public, tags" -ForegroundColor Gray
Write-Host ""
Write-Host "También crea los indices necesarios y actualiza el trigger." -ForegroundColor White
Write-Host ""
Write-Host "================================================================" -ForegroundColor Magenta
Write-Host "  PROBLEMA RESUELTO" -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "Después de ejecutar esta migracion:" -ForegroundColor White
Write-Host "  - Las calificaciones se guardaran correctamente" -ForegroundColor Green
Write-Host "  - La sincronización funcionará sin errores" -ForegroundColor Green
Write-Host "  - Todos los campos de SyncableMovieRating se persistiran" -ForegroundColor Green
Write-Host ""

Write-Host "Quieres abrir el SQL Editor de Supabase ahora? (S/N): " -NoNewline -ForegroundColor Yellow
$respuesta = Read-Host

if ($respuesta -eq "S" -or $respuesta -eq "s") {
    Write-Host ""
    Write-Host "Abriendo Supabase SQL Editor..." -ForegroundColor Cyan
    Start-Process "$supabaseUrl/project/_/sql"
    
    Write-Host ""
    Write-Host "Abriendo el archivo de migracion en el editor..." -ForegroundColor Cyan
    if (Get-Command code -ErrorAction SilentlyContinue) {
        Start-Process "code" -ArgumentList $migrationFile
    } else {
        Start-Process notepad -ArgumentList $migrationFile
    }
    
    Write-Host ""
    Write-Host "Listo! Ahora solo copia y pega el SQL en el editor de Supabase." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Puedes ejecutar este script cuando estes listo." -ForegroundColor Yellow
    Write-Host "El archivo de migracion esta en:" -ForegroundColor Gray
    Write-Host "$migrationFile" -ForegroundColor Gray
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
