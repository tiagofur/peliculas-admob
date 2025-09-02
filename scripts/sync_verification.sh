#!/bin/bash

# Script de verificación automática de sincronización Supabase
# Ejecuta tests de sincronización y genera reporte de resultados

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_DIR="sync_verification_reports"
REPORT_FILE="$REPORT_DIR/sync_verification_$TIMESTAMP.md"

# Crear directorio de reportes si no existe
mkdir -p $REPORT_DIR

# Función para logging
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $timestamp - $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $timestamp - $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $timestamp - $message"
            ;;
        "DEBUG")
            echo -e "${BLUE}[DEBUG]${NC} $timestamp - $message"
            ;;
    esac
    
    # También escribir al reporte
    echo "[$level] $timestamp - $message" >> $REPORT_FILE
}

# Función para ejecutar test y capturar resultado
run_test() {
    local test_name=$1
    local test_command=$2
    local description=$3
    
    log "INFO" "Ejecutando: $test_name"
    echo "## $test_name" >> $REPORT_FILE
    echo "$description" >> $REPORT_FILE
    echo "" >> $REPORT_FILE
    
    local start_time=$(date +%s)
    
    if eval $test_command >> $REPORT_FILE 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log "INFO" "✅ $test_name - PASÓ (${duration}s)"
        echo "**Resultado**: ✅ PASÓ (${duration}s)" >> $REPORT_FILE
        echo "" >> $REPORT_FILE
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log "ERROR" "❌ $test_name - FALLÓ (${duration}s)"
        echo "**Resultado**: ❌ FALLÓ (${duration}s)" >> $REPORT_FILE
        echo "" >> $REPORT_FILE
        return 1
    fi
}

# Función para verificar prerrequisitos
check_prerequisites() {
    log "INFO" "Verificando prerrequisitos..."
    
    # Verificar Flutter
    if ! command -v flutter &> /dev/null; then
        log "ERROR" "Flutter no está instalado o no está en el PATH"
        return 1
    fi
    
    # Verificar dependencias
    if [ ! -f "pubspec.yaml" ]; then
        log "ERROR" "No se encontró pubspec.yaml. Ejecutar desde la raíz del proyecto."
        return 1
    fi
    
    # Verificar archivo .env
    if [ ! -f ".env" ]; then
        log "WARN" "No se encontró archivo .env. Algunas pruebas podrían fallar."
    fi
    
    log "INFO" "Prerrequisitos verificados"
    return 0
}

# Función para obtener dependencias
get_dependencies() {
    log "INFO" "Obteniendo dependencias de Flutter..."
    
    if flutter pub get; then
        log "INFO" "Dependencias obtenidas exitosamente"
        return 0
    else
        log "ERROR" "Error obteniendo dependencias"
        return 1
    fi
}

# Función para ejecutar tests de sincronización
run_sync_tests() {
    log "INFO" "Iniciando tests de sincronización..."
    
    local failed_tests=0
    local total_tests=0
    
    # Tests básicos de sincronización
    ((total_tests++))
    if ! run_test "Sync Integration Test" \
        "flutter test test/sync_integration_test.dart" \
        "Pruebas básicas de integración para sincronización bidireccional"; then
        ((failed_tests++))
    fi
    
    # Tests de sincronización en tiempo real
    ((total_tests++))
    if ! run_test "Realtime Sync Complex Test" \
        "flutter test test/realtime_sync_complex_test.dart" \
        "Pruebas complejas de sincronización en tiempo real con eventos de alta frecuencia"; then
        ((failed_tests++))
    fi
    
    # Tests de conflictos multi-dispositivo
    ((total_tests++))
    if ! run_test "Multi-Device Conflict Test" \
        "flutter test test/multi_device_realtime_conflict_test.dart" \
        "Pruebas de resolución de conflictos entre múltiples dispositivos"; then
        ((failed_tests++))
    fi
    
    # Tests de estado de sincronización
    ((total_tests++))
    if ! run_test "Sync Status Integration Test" \
        "flutter test test/sync_status_integration_test.dart" \
        "Pruebas de indicadores y estado de sincronización"; then
        ((failed_tests++))
    fi
    
    # Tests de repositorio híbrido
    ((total_tests++))
    if ! run_test "Repository Integration Test" \
        "flutter test test/repository_integration_test.dart" \
        "Pruebas de integración del patrón de repositorio híbrido"; then
        ((failed_tests++))
    fi
    
    # Tests de cola persistente
    ((total_tests++))
    if ! run_test "Persistent Sync Queue Test" \
        "flutter test test/persistent_sync_queue_test.dart" \
        "Pruebas de cola persistente para operaciones offline"; then
        ((failed_tests++))
    fi

    # Tests de rendimiento y métricas de sincronización
    ((total_tests++))
    if ! run_test "Sync Performance Metrics Test" \
        "flutter test test/sync_performance_metrics_test.dart" \
        "Pruebas de rendimiento y latencia de sincronización ≤3s"; then
        ((failed_tests++))
    fi

    # Tests de integridad de datos
    ((total_tests++))
    if ! run_test "Sync Data Integrity Validation Test" \
        "flutter test test/sync_data_integrity_validation_test.dart" \
        "Validación de integridad de datos durante sincronización"; then
        ((failed_tests++))
    fi

    # Tests de simulación multi-dispositivo
    ((total_tests++))
    if ! run_test "Multi-Device Sync Simulation Test" \
        "flutter test test/multi_device_sync_simulation_test.dart" \
        "Simulación de sincronización entre múltiples dispositivos"; then
        ((failed_tests++))
    fi

    # Tests de recuperación offline
    ((total_tests++))
    if ! run_test "Offline Sync Recovery Test" \
        "flutter test test/offline_sync_recovery_test.dart" \
        "Pruebas de recuperación de sincronización después de modo offline"; then
        ((failed_tests++))
    fi
    
    log "INFO" "Tests de sincronización completados: $((total_tests - failed_tests))/$total_tests pasaron"
    return $failed_tests
}

# Función para ejecutar tests offline
run_offline_tests() {
    log "INFO" "Iniciando tests de funcionalidad offline..."
    
    local failed_tests=0
    local total_tests=0
    
    # Tests de funcionalidad offline
    ((total_tests++))
    if ! run_test "Offline Functionality Test" \
        "flutter test test/offline_functionality_test.dart" \
        "Pruebas de funcionalidad cuando no hay conexión a internet"; then
        ((failed_tests++))
    fi
    
    # Tests de caché offline
    ((total_tests++))
    if ! run_test "Offline Cache Test" \
        "flutter test test/offline_cache_test.dart" \
        "Pruebas del sistema de caché para funcionamiento offline"; then
        ((failed_tests++))
    fi
    
    # Tests de validación de caché
    ((total_tests++))
    if ! run_test "Offline Cache Validation Test" \
        "flutter test test/offline_cache_validation_test.dart" \
        "Validación del comportamiento del caché offline"; then
        ((failed_tests++))
    fi
    
    log "INFO" "Tests offline completados: $((total_tests - failed_tests))/$total_tests pasaron"
    return $failed_tests
}

# Función para ejecutar tests de integración E2E
run_integration_tests() {
    log "INFO" "Iniciando tests de integración E2E..."
    
    local failed_tests=0
    local total_tests=0
    
    # Test de flujo de autenticación
    ((total_tests++))
    if ! run_test "User Authentication Flow Test" \
        "flutter test integration_test/user_authentication_flow_test.dart" \
        "Prueba del flujo completo de autenticación de usuario"; then
        ((failed_tests++))
    fi
    
    # Test de flujo de watchlist
    ((total_tests++))
    if ! run_test "Watchlist Flow Test" \
        "flutter test integration_test/watchlist_flow_test.dart" \
        "Prueba del flujo completo de gestión de watchlist"; then
        ((failed_tests++))
    fi
    
    # Test de funcionalidad de compartir
    ((total_tests++))
    if ! run_test "Sharing Functionality Flow Test" \
        "flutter test integration_test/sharing_functionality_flow_test.dart" \
        "Prueba del flujo completo de funcionalidad de compartir"; then
        ((failed_tests++))
    fi
    
    log "INFO" "Tests de integración E2E completados: $((total_tests - failed_tests))/$total_tests pasaron"
    return $failed_tests
}

# Función para ejecutar análisis estático
run_static_analysis() {
    log "INFO" "Ejecutando análisis estático..."
    
    if flutter analyze --fatal-infos --fatal-warnings; then
        log "INFO" "✅ Análisis estático pasó"
        echo "## Análisis Estático" >> $REPORT_FILE
        echo "**Resultado**: ✅ PASÓ - Sin warnings ni errores" >> $REPORT_FILE
        echo "" >> $REPORT_FILE
        return 0
    else
        log "ERROR" "❌ Análisis estático falló"
        echo "## Análisis Estático" >> $REPORT_FILE
        echo "**Resultado**: ❌ FALLÓ - Hay warnings o errores" >> $REPORT_FILE
        echo "" >> $REPORT_FILE
        return 1
    fi
}

# Función para verificar formateo de código
check_formatting() {
    log "INFO" "Verificando formateo de código..."
    
    if dart format --set-exit-if-changed .; then
        log "INFO" "✅ Formateo de código correcto"
        echo "## Formateo de Código" >> $REPORT_FILE
        echo "**Resultado**: ✅ PASÓ - Código correctamente formateado" >> $REPORT_FILE
        echo "" >> $REPORT_FILE
        return 0
    else
        log "WARN" "❌ Código necesita formateo"
        echo "## Formateo de Código" >> $REPORT_FILE
        echo "**Resultado**: ❌ FALLÓ - Código necesita formateo" >> $REPORT_FILE
        echo "" >> $REPORT_FILE
        return 1
    fi
}

# Función para generar resumen del reporte
generate_summary() {
    local total_failed=$1
    
    echo "" >> $REPORT_FILE
    echo "# 📊 Resumen de Verificación" >> $REPORT_FILE
    echo "" >> $REPORT_FILE
    echo "**Fecha de ejecución**: $(date '+%Y-%m-%d %H:%M:%S')" >> $REPORT_FILE
    echo "**Duración total**: $(($(date +%s) - $start_total_time)) segundos" >> $REPORT_FILE
    echo "" >> $REPORT_FILE
    
    if [ $total_failed -eq 0 ]; then
        echo "## ✅ TODAS LAS PRUEBAS PASARON" >> $REPORT_FILE
        echo "" >> $REPORT_FILE
        echo "🎉 **¡Excelente!** Todos los tests de sincronización pasaron exitosamente." >> $REPORT_FILE
        echo "El sistema de sincronización está funcionando correctamente." >> $REPORT_FILE
        log "INFO" "🎉 ¡Todas las pruebas pasaron!"
    else
        echo "## ❌ ALGUNAS PRUEBAS FALLARON" >> $REPORT_FILE
        echo "" >> $REPORT_FILE
        echo "**Total de fallas**: $total_failed" >> $REPORT_FILE
        echo "" >> $REPORT_FILE
        echo "⚠️ **Atención requerida**: Hay tests que fallaron y necesitan investigación." >> $REPORT_FILE
        echo "Revisar los detalles de cada test para identificar los problemas." >> $REPORT_FILE
        log "ERROR" "❌ $total_failed tests fallaron"
    fi
    
    echo "" >> $REPORT_FILE
    echo "## 📋 Próximos Pasos" >> $REPORT_FILE
    echo "" >> $REPORT_FILE
    
    if [ $total_failed -eq 0 ]; then
        echo "1. ✅ Proceder con pruebas manuales según SYNC_VERIFICATION_CHECKLIST.md" >> $REPORT_FILE
        echo "2. ✅ Ejecutar pruebas en múltiples dispositivos/plataformas" >> $REPORT_FILE
        echo "3. ✅ Validar métricas de rendimiento en entorno de producción" >> $REPORT_FILE
    else
        echo "1. ❌ Investigar y corregir tests fallidos" >> $REPORT_FILE
        echo "2. ❌ Re-ejecutar verificación después de correcciones" >> $REPORT_FILE
        echo "3. ❌ No proceder con pruebas manuales hasta que todos los tests pasen" >> $REPORT_FILE
    fi
    
    echo "" >> $REPORT_FILE
    echo "---" >> $REPORT_FILE
    echo "*Reporte generado automáticamente por sync_verification.sh*" >> $REPORT_FILE
}

# Función principal
main() {
    local start_total_time=$(date +%s)
    
    echo -e "${BLUE}🔄 Iniciando Verificación de Sincronización Supabase${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # Inicializar reporte
    echo "# 🔄 Reporte de Verificación de Sincronización Supabase" > $REPORT_FILE
    echo "" >> $REPORT_FILE
    echo "**Fecha**: $(date '+%Y-%m-%d %H:%M:%S')" >> $REPORT_FILE
    echo "**Script**: sync_verification.sh" >> $REPORT_FILE
    echo "" >> $REPORT_FILE
    
    local total_failed=0
    
    # Verificar prerrequisitos
    if ! check_prerequisites; then
        log "ERROR" "Error en prerrequisitos. Abortando."
        exit 1
    fi
    
    # Obtener dependencias
    if ! get_dependencies; then
        log "ERROR" "Error obteniendo dependencias. Abortando."
        exit 1
    fi
    
    # Verificar formateo (no crítico)
    check_formatting || ((total_failed++))
    
    # Ejecutar análisis estático
    run_static_analysis || ((total_failed++))
    
    # Ejecutar tests de sincronización
    sync_failures=0
    run_sync_tests
    sync_failures=$?
    total_failed=$((total_failed + sync_failures))
    
    # Ejecutar tests offline
    offline_failures=0
    run_offline_tests
    offline_failures=$?
    total_failed=$((total_failed + offline_failures))
    
    # Ejecutar tests de integración E2E
    integration_failures=0
    run_integration_tests
    integration_failures=$?
    total_failed=$((total_failed + integration_failures))
    
    # Generar resumen
    generate_summary $total_failed
    
    # Mostrar ubicación del reporte
    echo ""
    echo -e "${BLUE}📄 Reporte completo generado en:${NC} $REPORT_FILE"
    echo ""
    
    # Exit code basado en resultados
    if [ $total_failed -eq 0 ]; then
        echo -e "${GREEN}🎉 ¡Verificación completada exitosamente!${NC}"
        exit 0
    else
        echo -e "${RED}❌ Verificación completada con $total_failed errores${NC}"
        exit 1
    fi
}

# Función de ayuda
show_help() {
    echo "Script de Verificación de Sincronización Supabase"
    echo ""
    echo "Uso: $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  -h, --help     Mostrar esta ayuda"
    echo "  -v, --verbose  Modo verbose con más detalles"
    echo ""
    echo "Este script ejecuta todos los tests relacionados con sincronización"
    echo "y genera un reporte detallado de los resultados."
    echo ""
    echo "Prerrequisitos:"
    echo "  - Flutter SDK instalado"
    echo "  - Dependencias del proyecto instaladas"
    echo "  - Ejecutar desde la raíz del proyecto"
}

# Parsear argumentos
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -v|--verbose)
        set -x
        main
        ;;
    "")
        main
        ;;
    *)
        echo "Opción desconocida: $1"
        show_help
        exit 1
        ;;
esac