# Script para generar archivos de configuración de Windows para Flutter
# Ejecutar cuando aparezcan errores de CMake

Write-Host "🔧 Generando archivos de configuración de Windows para Flutter..." -ForegroundColor Cyan

# Cambiar al directorio del script
Set-Location $PSScriptRoot\..

# Verificar y configurar NuGet
if (-not (Get-Command nuget -ErrorAction SilentlyContinue)) {
    if (Test-Path "nuget.exe") {
        Write-Host "📦 Configurando NuGet local..." -ForegroundColor Yellow
        $env:PATH += ";$(Get-Location)"
    } else {
        Write-Host "📥 Descargando NuGet..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile "nuget.exe"
        $env:PATH += ";$(Get-Location)"
    }
}

Write-Host "📂 Limpiando archivos de build anteriores..." -ForegroundColor Yellow
if (Test-Path "build\windows") {
    Remove-Item -Recurse -Force "build\windows"
}
if (Test-Path "windows\flutter\ephemeral") {
    Remove-Item -Recurse -Force "windows\flutter\ephemeral"
}

Write-Host "🧹 Ejecutando flutter clean..." -ForegroundColor Yellow
flutter clean

Write-Host "⚙️  Configurando Flutter para Windows..." -ForegroundColor Yellow
flutter config --enable-windows-desktop

Write-Host "📦 Obteniendo dependencias..." -ForegroundColor Yellow
flutter pub get

Write-Host "🏗️  Generando archivos de Windows..." -ForegroundColor Yellow
flutter create --platforms=windows .

Write-Host "🔨 Iniciando build de Windows (esto puede tomar varios minutos)..." -ForegroundColor Yellow
Write-Host "   Nota: Es normal que tome tiempo en la primera ejecución." -ForegroundColor Gray

try {
    flutter build windows --debug
    Write-Host "✅ Proceso completado exitosamente!" -ForegroundColor Green
    Write-Host "   Los archivos de configuración de Windows han sido generados." -ForegroundColor Green
} catch {
    Write-Host "⚠️  El build completo falló, pero los archivos de configuración deberían estar listos." -ForegroundColor Yellow
    Write-Host "   Error: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "💡 Próximos pasos:" -ForegroundColor Cyan
Write-Host "   1. Reinicia VS Code para que tome los nuevos archivos" -ForegroundColor White
Write-Host "   2. Los errores de CMake deberían haber desaparecido" -ForegroundColor White
Write-Host "   3. Si persisten, verifica que CMake Tools esté configurado correctamente" -ForegroundColor White

Read-Host -Prompt "Presiona Enter para continuar"