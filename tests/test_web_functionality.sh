#!/bin/bash

# Script para verificar funcionalidad Web
echo "🌐 Verificando funcionalidad Web de la aplicación de películas..."

echo "📦 Limpiando proyecto..."
flutter clean

echo "📥 Obteniendo dependencias..."
flutter pub get

echo "🔧 Compilando para Web..."
flutter build web --no-tree-shake-icons

if [ $? -eq 0 ]; then
    echo "✅ Compilación Web exitosa!"
    
    echo "🧪 Ejecutando tests básicos..."
    flutter test test/offline_functionality_test.dart --reporter=compact
    
    echo "📱 Para probar en navegador, ejecuta:"
    echo "   flutter run -d chrome"
    echo ""
    echo "🔄 Para verificar sincronización:"
    echo "   1. Abre la app en Web"
    echo "   2. Inicia sesión"
    echo "   3. Agrega algunas películas a favoritos"
    echo "   4. Verifica en Supabase que se sincronizaron"
    echo "   5. Abre la misma cuenta en móvil y verifica sync"
    echo ""
    echo "🛠️  Para debug de sincronización:"
    echo "   - En modo debug, verás un widget en la esquina inferior derecha"
    echo "   - Puedes forzar sincronización manual desde ahí"
    echo ""
else
    echo "❌ Error en compilación Web"
    exit 1
fi
