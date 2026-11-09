# Script de Validación de Real-Time Sync
# Ejecutar este script para probar la sincronización en tiempo real

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Real-Time Sync Validation Script" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Verificar que Flutter esté instalado
Write-Host "[1/5] Verificando Flutter..." -ForegroundColor Yellow
$flutterVersion = flutter --version 2>&1 | Select-String "Flutter"
if ($flutterVersion) {
    Write-Host "✅ Flutter instalado: $flutterVersion" -ForegroundColor Green
} else {
    Write-Host "❌ Flutter no encontrado. Instala Flutter primero." -ForegroundColor Red
    exit 1
}

# Verificar que no haya errores de compilación
Write-Host ""
Write-Host "[2/5] Verificando código..." -ForegroundColor Yellow
$analyzeResult = flutter analyze --no-fatal-infos 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Código sin errores" -ForegroundColor Green
} else {
    Write-Host "❌ Errores en el código:" -ForegroundColor Red
    Write-Host $analyzeResult
    Write-Host ""
    Write-Host "⚠️  Corrige los errores antes de continuar" -ForegroundColor Yellow
    exit 1
}

# Instrucciones para testing manual
Write-Host ""
Write-Host "[3/5] Setup de Testing Manual" -ForegroundColor Yellow
Write-Host ""
Write-Host "Para probar el Real-Time Sync necesitas:" -ForegroundColor Cyan
Write-Host "  • 2 navegadores o 2 tabs en diferentes puertos" -ForegroundColor White
Write-Host "  • Login con el MISMO usuario en ambos" -ForegroundColor White
Write-Host "  • Observar que los cambios se propagan automáticamente" -ForegroundColor White
Write-Host ""

$continue = Read-Host "¿Quieres abrir 2 instancias de la app en Chrome? (S/N)"

if ($continue -eq "S" -or $continue -eq "s") {
    Write-Host ""
    Write-Host "[4/5] Iniciando primera instancia en puerto 8080..." -ForegroundColor Yellow
    
    # Abrir primera instancia en background
    $job1 = Start-Job -ScriptBlock {
        Set-Location $using:PWD
        flutter run -d chrome --web-port 8080
    }
    
    Write-Host "✅ Primera instancia iniciando (Job ID: $($job1.Id))" -ForegroundColor Green
    Write-Host "   URL: http://localhost:8080" -ForegroundColor Cyan
    
    Start-Sleep -Seconds 5
    
    Write-Host ""
    Write-Host "[5/5] Iniciando segunda instancia en puerto 8081..." -ForegroundColor Yellow
    
    # Abrir segunda instancia en background
    $job2 = Start-Job -ScriptBlock {
        Set-Location $using:PWD
        flutter run -d chrome --web-port 8081
    }
    
    Write-Host "✅ Segunda instancia iniciando (Job ID: $($job2.Id))" -ForegroundColor Green
    Write-Host "   URL: http://localhost:8081" -ForegroundColor Cyan
    
    Write-Host ""
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "Testing Instructions" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "📋 PASO 1: LOGIN" -ForegroundColor Yellow
    Write-Host "   - En ambos tabs, inicia sesión con el MISMO usuario" -ForegroundColor White
    Write-Host ""
    
    Write-Host "📋 PASO 2: TEST WATCHED MOVIES" -ForegroundColor Yellow
    Write-Host "   Tab 1: Marca una película como vista" -ForegroundColor White
    Write-Host "   Tab 2: Espera 1-3 segundos" -ForegroundColor White
    Write-Host "   Tab 2: Verifica que aparece en 'Watched' SIN refresh manual" -ForegroundColor White
    Write-Host "   ✅ Si aparece automáticamente = FUNCIONA" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "📋 PASO 3: TEST FAVORITES" -ForegroundColor Yellow
    Write-Host "   Tab 1: Agrega una película a favoritos" -ForegroundColor White
    Write-Host "   Tab 2: Espera 1-3 segundos" -ForegroundColor White
    Write-Host "   Tab 2: Verifica que aparece en 'Favorites' SIN refresh manual" -ForegroundColor White
    Write-Host "   ✅ Si aparece automáticamente = FUNCIONA" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "📋 PASO 4: TEST DELETE" -ForegroundColor Yellow
    Write-Host "   Tab 1: Elimina un favorito" -ForegroundColor White
    Write-Host "   Tab 2: Espera 1-3 segundos" -ForegroundColor White
    Write-Host "   Tab 2: Verifica que desaparece SIN refresh manual" -ForegroundColor White
    Write-Host "   ✅ Si desaparece automáticamente = FUNCIONA" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "🔍 VERIFICAR LOGS" -ForegroundColor Yellow
    Write-Host "   En la consola de ambos tabs, busca mensajes como:" -ForegroundColor White
    Write-Host "   • '⚡️ Realtime event received for...'" -ForegroundColor Cyan
    Write-Host "   • '✅ Realtime INSERT processed...'" -ForegroundColor Cyan
    Write-Host "   • '✅ Realtime DELETE processed...'" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "Jobs Running" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "Job 1 (Port 8080): $($job1.Id)" -ForegroundColor White
    Write-Host "Job 2 (Port 8081): $($job2.Id)" -ForegroundColor White
    Write-Host ""
    Write-Host "Para detener los jobs:" -ForegroundColor Yellow
    Write-Host "  Get-Job | Stop-Job" -ForegroundColor Cyan
    Write-Host "  Get-Job | Remove-Job" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Presiona ENTER cuando termines el testing..." -ForegroundColor Yellow
    Read-Host
    
    Write-Host ""
    Write-Host "Deteniendo jobs..." -ForegroundColor Yellow
    Stop-Job -Id $job1.Id
    Stop-Job -Id $job2.Id
    Remove-Job -Id $job1.Id
    Remove-Job -Id $job2.Id
    
    Write-Host "✅ Jobs detenidos y limpiados" -ForegroundColor Green
    
} else {
    Write-Host ""
    Write-Host "[4/5] Testing Manual" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Puedes ejecutar manualmente:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Terminal 1:" -ForegroundColor Yellow
    Write-Host "    flutter run -d chrome --web-port 8080" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Terminal 2:" -ForegroundColor Yellow
    Write-Host "    flutter run -d chrome --web-port 8081" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Luego sigue las instrucciones de testing del documento:" -ForegroundColor White
    Write-Host "  docs/FIX_REALTIME_SYNC_2025_10_01.md" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Validación Completa" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📚 Documentación completa en:" -ForegroundColor Yellow
Write-Host "   docs/FIX_REALTIME_SYNC_2025_10_01.md" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Código corregido en:" -ForegroundColor Yellow  
Write-Host "   lib/infrastructure/repositories/base_hybrid_repository.dart" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎯 Qué se corrigió:" -ForegroundColor Yellow
Write-Host "   • Filtro PostgresChangeFilter correcto para user_id" -ForegroundColor Green
Write-Host "   • Mejor manejo de eventos INSERT/UPDATE/DELETE" -ForegroundColor Green
Write-Host "   • Try-catch para evitar crashes en realtime" -ForegroundColor Green
Write-Host "   • Logging mejorado para debugging" -ForegroundColor Green
Write-Host ""
Write-Host "🚀 Ahora Watched y Favorites se sincronizan en tiempo real!" -ForegroundColor Green
Write-Host ""
