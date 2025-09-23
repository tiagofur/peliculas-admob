@echo off
REM Script para generar archivos de configuración de Windows para Flutter
REM Ejecutar cuando aparezcan errores de CMake

echo 🔧 Generando archivos de configuración de Windows para Flutter...

REM Cambiar al directorio del proyecto
cd /d "%~dp0"

echo 📂 Limpiando archivos de build anteriores...
if exist "build\windows" rmdir /s /q "build\windows"
if exist "windows\flutter\ephemeral" rmdir /s /q "windows\flutter\ephemeral"

echo 🧹 Ejecutando flutter clean...
flutter clean

echo ⚙️  Configurando Flutter para Windows...
flutter config --enable-windows-desktop

echo 📦 Obteniendo dependencias...
flutter pub get

echo 🏗️  Generando archivos de Windows...
flutter create --platforms=windows .

echo 🔨 Preparando build de Windows (esto puede tomar varios minutos)...
flutter build windows --debug

echo ✅ Proceso completado. Los archivos de configuración de Windows han sido generados.
echo 💡 Si aún ves errores, reinicia VS Code.

pause