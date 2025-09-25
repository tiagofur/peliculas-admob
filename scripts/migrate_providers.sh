#!/bin/bash

# Script para migrar StateNotifierProvider a NotifierProvider en Riverpod 3.0
# Este script automatiza la corrección de errores críticos

echo "🔧 Iniciando migración automática de providers..."

# Lista de archivos que contienen StateNotifierProvider
FILES=(
    "lib/presentation/providers/challenge_providers.dart"
    "lib/presentation/providers/sync_status_provider.dart" 
    "lib/presentation/providers/watched_movies_provider.dart"
    "lib/presentation/providers/user_movie_ratings_provider.dart"
    "lib/presentation/providers/sync_integration_provider.dart"
    "lib/presentation/providers/movie_ratings_provider.dart"
    "lib/presentation/providers/movies/movies_providers.dart"
    "lib/presentation/providers/movies/discovery_provider.dart"
    "lib/presentation/providers/silent_sync_provider.dart"
    "lib/presentation/providers/social_sharing_provider.dart"
)

# Contador de archivos procesados
count=0

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "📝 Procesando: $file"
        
        # Backup del archivo
        cp "$file" "${file}.backup"
        
        # 1. Cambiar StateNotifier por Notifier
        sed -i 's/extends StateNotifier</extends Notifier</g' "$file"
        
        # 2. Cambiar StateNotifierProvider por NotifierProvider
        sed -i 's/StateNotifierProvider</NotifierProvider</g' "$file"
        
        # 3. Remover import de state_notifier si existe
        sed -i '/import.*state_notifier.*state_notifier/d' "$file"
        
        # 4. Agregar método build() básico si no existe
        if ! grep -q "build()" "$file"; then
            echo "⚠️  Necesita método build() manual: $file"
        fi
        
        count=$((count + 1))
        echo "✅ Completado: $file"
    else
        echo "❌ Archivo no encontrado: $file"
    fi
done

echo ""
echo "🎉 Migración automática completada!"
echo "📊 Archivos procesados: $count"
echo "⚠️  IMPORTANTE: Algunos archivos pueden necesitar ajustes manuales en los constructores y métodos build()"
echo ""
echo "🧪 Ejecutar flutter analyze para verificar errores restantes..."