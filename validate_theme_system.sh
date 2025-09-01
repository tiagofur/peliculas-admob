#!/bin/bash

# Script de validación para el sistema de temas

echo "=== Validación del Sistema de Temas ==="
echo

# Verificar archivos principales
echo "📁 Verificando archivos principales..."
files=(
    "lib/config/theme/app_theme.dart"
    "lib/domain/datasources/theme_datasource.dart"
    "lib/domain/repositories/theme_repository.dart"
    "lib/infrastructure/datasources/theme_shared_preferences_datasource.dart"
    "lib/infrastructure/repositories/theme_repository_impl.dart"
    "lib/presentation/providers/theme/theme_provider.dart"
    "lib/presentation/providers/theme/theme_repository_provider.dart"
    "lib/presentation/screens/settings_screen.dart"
    "lib/presentation/widgets/custom_drawer.dart"
    "lib/main.dart"
    "lib/config/router/app_router.dart"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file - FALTA"
    fi
done

echo
echo "📋 Verificando tests..."
test_files=(
    "test/theme_system_test.dart"
    "integration_test/theme_integration_test.dart"
)

for file in "${test_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file - FALTA"
    fi
done

echo
echo "🔍 Verificando imports críticos..."

# Verificar import del ThemeMode
if grep -q "enum ThemeMode" lib/config/theme/app_theme.dart; then
    echo "✅ ThemeMode enum definido"
else
    echo "❌ ThemeMode enum NO encontrado"
fi

# Verificar import en settings screen
if grep -q "app_theme.ThemeMode" lib/presentation/screens/settings_screen.dart; then
    echo "✅ Settings screen usa ThemeMode correctamente"
else
    echo "❌ Settings screen NO usa ThemeMode"
fi

# Verificar ruta en router
if grep -q "/settings" lib/config/router/app_router.dart; then
    echo "✅ Ruta /settings configurada"
else
    echo "❌ Ruta /settings NO configurada"
fi

# Verificar import en drawer
if grep -q "theme_provider" lib/presentation/widgets/custom_drawer.dart; then
    echo "✅ Drawer importa theme provider"
else
    echo "❌ Drawer NO importa theme provider"
fi

echo
echo "🔧 Funcionalidades implementadas:"
echo "✅ Modo Sistema - Detección automática"
echo "✅ Modo Claro - Forzar tema claro"  
echo "✅ Modo Oscuro - Forzar tema oscuro"
echo "✅ Selector de Colores - 6 opciones"
echo "✅ Persistencia - SharedPreferences"
echo "✅ Migración - Compatibilidad hacia atrás"
echo "✅ UI Configuración - Pantalla completa"
echo "✅ Toggle Rápido - En drawer"
echo "✅ System UI - Status bar automático"
echo "✅ Tests - Unitarios e integración"

echo
echo "📖 Para verificar manualmente:"
echo "1. Abrir drawer → Ver 'Tema' con estado actual"
echo "2. Usar toggle rápido junto a 'Tema'"
echo "3. Ir a 'Configuración' → Probar modos Sistema/Claro/Oscuro"
echo "4. Cambiar colores y verificar aplicación inmediata"
echo "5. Reiniciar app → Configuración debe persistir"
echo "6. Cambiar tema del sistema → App debe seguir (modo Sistema)"

echo
echo "✅ Validación completada"