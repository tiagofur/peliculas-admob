# Script para migrar StateNotifierProvider a NotifierProvider en Riverpod 3.0
# Este script automatiza la corrección de errores críticos

Write-Host "🔧 Iniciando migración automática de providers..." -ForegroundColor Yellow

# Lista de archivos que contienen StateNotifierProvider
$FILES = @(
    "lib\presentation\providers\challenge_providers.dart",
    "lib\presentation\providers\sync_status_provider.dart",
    "lib\presentation\providers\watched_movies_provider.dart", 
    "lib\presentation\providers\user_movie_ratings_provider.dart",
    "lib\presentation\providers\sync_integration_provider.dart",
    "lib\presentation\providers\movie_ratings_provider.dart",
    "lib\presentation\providers\movies\movies_providers.dart",
    "lib\presentation\providers\movies\discovery_provider.dart",
    "lib\presentation\providers\silent_sync_provider.dart",
    "lib\presentation\providers\social_sharing_provider.dart"
)

# Contador de archivos procesados
$count = 0

foreach ($file in $FILES) {
    if (Test-Path $file) {
        Write-Host "📝 Procesando: $file" -ForegroundColor Blue
        
        # Backup del archivo
        Copy-Item $file "$file.backup"
        
        # Leer contenido del archivo
        $content = Get-Content $file -Raw
        
        # 1. Cambiar StateNotifier por Notifier
        $content = $content -replace 'extends StateNotifier<', 'extends Notifier<'
        
        # 2. Cambiar StateNotifierProvider por NotifierProvider  
        $content = $content -replace 'StateNotifierProvider<', 'NotifierProvider<'
        
        # 3. Remover import de state_notifier si existe
        $content = $content -replace "import 'package:state_notifier/state_notifier.dart';\r?\n", ""
        
        # 4. Cambiar constructores con super() por build()
        # Este es más complejo y se hará manualmente por ahora
        
        # Escribir contenido modificado
        Set-Content $file $content
        
        $count++
        Write-Host "✅ Completado: $file" -ForegroundColor Green
    }
    else {
        Write-Host "❌ Archivo no encontrado: $file" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "🎉 Migración automática completada!" -ForegroundColor Green
Write-Host "📊 Archivos procesados: $count" -ForegroundColor Cyan
Write-Host "⚠️  IMPORTANTE: Algunos archivos pueden necesitar ajustes manuales en los constructores y métodos build()" -ForegroundColor Yellow
Write-Host ""
Write-Host "🧪 Ejecutar flutter analyze para verificar errores restantes..." -ForegroundColor Cyan