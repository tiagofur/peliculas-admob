#!/bin/bash

# Script de validación pre-commit para calidad de código
# Ejecuta las mismas validaciones que el CI

set -e

echo "🚀 Ejecutando validaciones de calidad..."

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para mostrar errores
show_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Función para mostrar éxito
show_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Función para mostrar info
show_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# 1. Verificar dependencias
echo ""
show_info "Verificando dependencias..."
if ! flutter pub get; then
    show_error "Error al obtener dependencias"
    exit 1
fi
show_success "Dependencias actualizadas"

# 2. Verificar formato
echo ""
show_info "Verificando formato de código..."
if ! dart format --output=none --set-exit-if-changed .; then
    show_error "Código no está formateado correctamente"
    echo "Ejecuta: dart format ."
    exit 1
fi
show_success "Formato de código correcto"

# 3. Análisis estático
echo ""
show_info "Ejecutando análisis estático..."
if ! flutter analyze --fatal-infos --fatal-warnings; then
    show_error "Análisis estático falló"
    exit 1
fi
show_success "Análisis estático pasó"

# 4. Ejecutar tests
echo ""
show_info "Ejecutando tests..."
if ! flutter test; then
    show_error "Tests fallaron"
    exit 1
fi
show_success "Todos los tests pasaron"

# 5. Verificar build (opcional, solo si se pasa --build)
if [[ "$1" == "--build" ]]; then
    echo ""
    show_info "Verificando build..."
    if ! flutter build web --release; then
        show_error "Build web falló"
        exit 1
    fi
    show_success "Build web exitoso"
fi

echo ""
echo -e "${GREEN}🎉 Todas las validaciones pasaron! Tu código está listo para commit/push.${NC}"