#!/bin/bash

# Script de configuración del entorno de desarrollo
# Configura hooks pre-commit y herramientas de calidad

set -e

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Configurando entorno de desarrollo...${NC}"

# 1. Instalar dependencias
echo ""
echo -e "${YELLOW}📦 Instalando dependencias de Flutter...${NC}"
flutter pub get

# 2. Configurar pre-commit hook (opcional)
read -p "¿Quieres instalar el hook pre-commit automático? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⚙️ Configurando pre-commit hook...${NC}"
    
    # Crear directorio de hooks si no existe
    mkdir -p .git/hooks
    
    # Crear pre-commit hook
    cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Hook pre-commit automático para validación de calidad

echo "🔍 Ejecutando validaciones pre-commit..."

# Ejecutar script de calidad
if ! ./scripts/quality_check.sh; then
    echo "❌ Commit cancelado debido a errores de calidad"
    echo "💡 Corrige los errores y vuelve a intentar"
    exit 1
fi

echo "✅ Validaciones pasaron, continuando con commit..."
EOF
    
    # Hacer ejecutable
    chmod +x .git/hooks/pre-commit
    
    echo -e "${GREEN}✅ Pre-commit hook instalado${NC}"
else
    echo "⏭️ Pre-commit hook omitido (puedes instalarlo más tarde con este script)"
fi

# 3. Verificar configuración
echo ""
echo -e "${YELLOW}🔧 Verificando configuración...${NC}"

# Verificar Flutter
if flutter doctor | grep -q "No issues found"; then
    echo -e "${GREEN}✅ Flutter configurado correctamente${NC}"
else
    echo -e "${YELLOW}⚠️ Flutter tiene algunos problemas, ejecuta 'flutter doctor' para más detalles${NC}"
fi

# 4. Información útil
echo ""
echo -e "${GREEN}🎉 Configuración completada!${NC}"
echo ""
echo "📋 Comandos útiles:"
echo "  • ./scripts/quality_check.sh      - Ejecutar todas las validaciones"
echo "  • ./scripts/quality_check.sh --build - Incluir validación de build"
echo "  • dart format .                   - Formatear código"
echo "  • flutter analyze                 - Análisis estático"
echo "  • flutter test                    - Ejecutar tests"
echo "  • flutter test --coverage         - Tests con cobertura"
echo ""
echo "📚 Documentación:"
echo "  • README.md - Guía completa del proyecto"
echo "  • .github/pull_request_template.md - Template para PRs"
echo ""
echo -e "${YELLOW}💡 Tip: Ejecuta './scripts/quality_check.sh' antes de cada commit${NC}"