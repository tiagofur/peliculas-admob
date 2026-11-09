# Script de validacion rapida para sistema de rating
# Ejecutar: .\scripts\validate_rating_fix.ps1

Write-Host "Validando correccion de sistema de rating..." -ForegroundColor Cyan
Write-Host ""

# Verificar archivos modificados
Write-Host "Verificando archivos modificados..." -ForegroundColor Yellow

$files = @(
    "lib\domain\entities\syncable_movie_rating.dart",
    "lib\infrastructure\repositories\hybrid_movie_ratings_repository.dart",
    "lib\presentation\widgets\ratings\rating_dialog.dart",
    "lib\presentation\widgets\ratings\rating_slider_widget.dart"
)

$allFilesExist = $true
foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "  [OK] $file" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] $file NO ENCONTRADO" -ForegroundColor Red
        $allFilesExist = $false
    }
}

if (-not $allFilesExist) {
    Write-Host ""
    Write-Host "ERROR: Faltan archivos necesarios" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Buscar validaciones implementadas
Write-Host "Buscando validaciones implementadas..." -ForegroundColor Yellow

$validationCount = 0

# Buscar clamp en syncable_movie_rating.dart
$content = Get-Content "lib\domain\entities\syncable_movie_rating.dart" -Raw
if ($content -match "rating.clamp") {
    Write-Host "  [OK] Validacion en syncable_movie_rating.dart" -ForegroundColor Green
    $validationCount++
} else {
    Write-Host "  [ERROR] Falta validacion en syncable_movie_rating.dart" -ForegroundColor Red
}

# Buscar clamp en repository
$content = Get-Content "lib\infrastructure\repositories\hybrid_movie_ratings_repository.dart" -Raw
$clampMatches = ([regex]::Matches($content, "rating.clamp")).Count
if ($clampMatches -ge 2) {
    Write-Host "  [OK] Validaciones en hybrid_movie_ratings_repository.dart ($clampMatches encontradas)" -ForegroundColor Green
    $validationCount += $clampMatches
} else {
    Write-Host "  [WARNING] Solo $clampMatches validaciones en repository" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Total validaciones encontradas: $validationCount" -ForegroundColor Cyan

# Buscar uso de RatingSlider
Write-Host ""
Write-Host "Verificando uso de RatingSlider..." -ForegroundColor Yellow

$dialogContent = Get-Content "lib\presentation\widgets\ratings\rating_dialog.dart" -Raw
if ($dialogContent -match "RatingSlider") {
    Write-Host "  [OK] RatingDialog usa RatingSlider" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] RatingDialog NO usa RatingSlider" -ForegroundColor Red
}

# Resumen
Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "RESUMEN DE VALIDACION" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

if ($validationCount -ge 3) {
    Write-Host "  [OK] Validaciones: $validationCount implementadas" -ForegroundColor Green
} else {
    Write-Host "  [WARNING] Validaciones: $validationCount (se esperan 3+)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "CHECKLIST DE TESTING MANUAL:" -ForegroundColor Yellow
Write-Host "  1. Ejecutar: flutter run -d chrome" -ForegroundColor White
Write-Host "  2. Abrir detalles de pelicula" -ForegroundColor White
Write-Host "  3. Verificar que se muestra SLIDER (no estrellas)" -ForegroundColor White
Write-Host "  4. Calificar con diferentes valores (1.0, 5.5, 10.0)" -ForegroundColor White
Write-Host "  5. Confirmar que NO aparece error PostgreSQL" -ForegroundColor White
Write-Host ""
Write-Host "Ver checklist completo: docs\RATING_TESTING_CHECKLIST.md" -ForegroundColor Cyan
Write-Host "Ver documentacion: docs\FIX_RATING_OVERFLOW_AND_SLIDER.md" -ForegroundColor Cyan
Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
