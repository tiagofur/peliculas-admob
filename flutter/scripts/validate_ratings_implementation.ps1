# Script de Validación del Sistema Unificado de Ratings

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  VALIDACION SISTEMA UNIFICADO RATINGS  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0
$testsTotal = 10

function Test-FileExists {
    param($path, $description)
    
    Write-Host "Verificando: $description..." -NoNewline
    if (Test-Path $path) {
        Write-Host " OK" -ForegroundColor Green
        return $true
    } else {
        Write-Host " FAIL" -ForegroundColor Red
        Write-Host "   Archivo no encontrado: $path" -ForegroundColor Red
        return $false
    }
}

function Test-StringInFile {
    param($path, $searchString, $description)
    
    Write-Host "Verificando: $description..." -NoNewline
    if (Test-Path $path) {
        $content = Get-Content $path -Raw
        if ($content -match [regex]::Escape($searchString)) {
            Write-Host " OK" -ForegroundColor Green
            return $true
        } else {
            Write-Host " FAIL" -ForegroundColor Red
            Write-Host "   No se encontro: $searchString" -ForegroundColor Yellow
            return $false
        }
    } else {
        Write-Host " FAIL" -ForegroundColor Red
        return $false
    }
}

Write-Host "📦 TEST 1: Archivos Principales" -ForegroundColor Yellow
Write-Host "=================================" -ForegroundColor Gray
Write-Host ""

if (Test-FileExists "lib\services\unified_rating_service.dart" "UnifiedRatingService") { $testsPassed++ } else { $testsFailed++ }
if (Test-FileExists "lib\presentation\providers\unified_ratings_provider.dart" "UnifiedRatingsProvider") { $testsPassed++ } else { $testsFailed++ }
if (Test-FileExists "supabase\migrations\fix_user_movie_ratings_columns_20250930.sql" "Migración SQL") { $testsPassed++ } else { $testsFailed++ }

Write-Host ""
Write-Host "🔄 TEST 2: Integración en PostLoginService" -ForegroundColor Yellow
Write-Host "===========================================" -ForegroundColor Gray
Write-Host ""

if (Test-StringInFile "lib\core\services\post_login_initialization_service.dart" "unifiedRatingsProvider" "Import unifiedRatingsProvider") { $testsPassed++ } else { $testsFailed++ }
if (Test-StringInFile "lib\core\services\post_login_initialization_service.dart" "UnifiedRatingService" "Import UnifiedRatingService") { $testsPassed++ } else { $testsFailed++ }

Write-Host ""
Write-Host "🎨 TEST 3: Actualización de Widgets" -ForegroundColor Yellow
Write-Host "====================================" -ForegroundColor Gray
Write-Host ""

if (Test-StringInFile "lib\presentation\widgets\ratings\rating_dialog.dart" "unifiedRatingsProvider" "RatingDialog usa unifiedRatingsProvider") { $testsPassed++ } else { $testsFailed++ }
if (Test-StringInFile "lib\presentation\widgets\movies\movie_rating_and_notes.dart" "unifiedRatingsProvider" "MovieRatingAndNotes usa unifiedRatingsProvider") { $testsPassed++ } else { $testsFailed++ }

Write-Host ""
Write-Host "📚 TEST 4: Documentación" -ForegroundColor Yellow
Write-Host "========================" -ForegroundColor Gray
Write-Host ""

if (Test-FileExists "docs\UNIFIED_RATINGS_IMPLEMENTATION_PLAN.md" "Plan de Implementación") { $testsPassed++ } else { $testsFailed++ }
if (Test-FileExists "scripts\apply_ratings_migration.ps1" "Script de Migración") { $testsPassed++ } else { $testsFailed++ }

Write-Host ""
Write-Host "🔬 TEST 5: Compilación Flutter" -ForegroundColor Yellow
Write-Host "===============================" -ForegroundColor Gray
Write-Host ""

Write-Host "🔍 Ejecutando flutter analyze..." -NoNewline
$analyzeResult = flutter analyze --no-pub 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host " ✅" -ForegroundColor Green
    $testsPassed++
} else {
    Write-Host " ❌" -ForegroundColor Red
    Write-Host ""
    Write-Host "Errores encontrados:" -ForegroundColor Red
    Write-Host $analyzeResult -ForegroundColor Yellow
    Write-Host ""
    $testsFailed++
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  RESULTADOS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$successRate = [math]::Round(($testsPassed / $testsTotal) * 100, 2)

Write-Host "Tests Ejecutados: $testsTotal" -ForegroundColor White
Write-Host "Tests Pasados:    $testsPassed" -ForegroundColor Green
Write-Host "Tests Fallados:   $testsFailed" -ForegroundColor Red
Write-Host "Tasa de Éxito:    $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 50) { "Yellow" } else { "Red" })
Write-Host ""

if ($testsPassed -eq $testsTotal) {
    Write-Host "🎉 ¡TODOS LOS TESTS PASARON!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Próximos pasos:" -ForegroundColor Yellow
    Write-Host "1. Ejecutar: .\scripts\apply_ratings_migration.ps1"
    Write-Host "2. Aplicar migración SQL en Supabase"
    Write-Host "3. Ejecutar: flutter run"
    Write-Host "4. Validar funcionamiento en la app"
    Write-Host ""
} elseif ($testsPassed -ge ($testsTotal * 0.8)) {
    Write-Host "⚠️  MAYORÍA DE TESTS PASARON" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Hay algunos problemas menores que debes revisar" -ForegroundColor Yellow
    Write-Host "Revisa los tests fallados arriba"
    Write-Host ""
} else {
    Write-Host "❌ MÚLTIPLES TESTS FALLARON" -ForegroundColor Red
    Write-Host ""
    Write-Host "Hay problemas significativos que deben corregirse" -ForegroundColor Red
    Write-Host "Revisa los errores detallados arriba"
    Write-Host ""
}

Write-Host "📖 Documentación completa:" -ForegroundColor Cyan
Write-Host "   docs\UNIFIED_RATINGS_IMPLEMENTATION_PLAN.md"
Write-Host ""

Read-Host "Presiona ENTER para salir"

# Retornar código de salida apropiado
if ($testsPassed -eq $testsTotal) {
    exit 0
} else {
    exit 1
}
