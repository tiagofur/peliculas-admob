# Script para verificar funcionalidad Web
Write-Host "🌐 Verificando funcionalidad Web de la aplicación de películas..." -ForegroundColor Cyan

Write-Host "📦 Limpiando proyecto..." -ForegroundColor Yellow
flutter clean

Write-Host "📥 Obteniendo dependencias..." -ForegroundColor Yellow
flutter pub get

Write-Host "🔧 Compilando para Web..." -ForegroundColor Yellow
flutter build web --no-tree-shake-icons

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Compilación Web exitosa!" -ForegroundColor Green
    
    Write-Host "🧪 Ejecutando tests básicos..." -ForegroundColor Yellow
    flutter test test/offline_functionality_test.dart --reporter=compact
    
    Write-Host "📱 Para probar en navegador, ejecuta:" -ForegroundColor Cyan
    Write-Host "   flutter run -d chrome" -ForegroundColor White
    Write-Host ""
    Write-Host "🔄 Para verificar sincronización:" -ForegroundColor Cyan
    Write-Host "   1. Abre la app en Web" -ForegroundColor White
    Write-Host "   2. Inicia sesión" -ForegroundColor White
    Write-Host "   3. Agrega algunas películas a favoritos" -ForegroundColor White
    Write-Host "   4. Verifica en Supabase que se sincronizaron" -ForegroundColor White
    Write-Host "   5. Abre la misma cuenta en móvil y verifica sync" -ForegroundColor White
    Write-Host ""
    Write-Host "🛠️  Para debug de sincronización:" -ForegroundColor Cyan
    Write-Host "   - En modo debug, verás un widget en la esquina inferior derecha" -ForegroundColor White
    Write-Host "   - Puedes forzar sincronización manual desde ahí" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "❌ Error en compilación Web" -ForegroundColor Red
    exit 1
}
