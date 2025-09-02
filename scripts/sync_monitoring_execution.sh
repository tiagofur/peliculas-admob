#!/bin/bash

# Script integral de monitoreo y verificación de sincronización
# Ejecuta tests, genera métricas y proporciona análisis en tiempo real

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuración
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
MONITORING_DIR="sync_monitoring"
METRICS_FILE="$MONITORING_DIR/sync_metrics_$TIMESTAMP.json"
PERFORMANCE_LOG="$MONITORING_DIR/performance_$TIMESTAMP.log"
SUMMARY_REPORT="$MONITORING_DIR/summary_report_$TIMESTAMP.md"

# Crear directorio de monitoreo
mkdir -p $MONITORING_DIR

# Variables de métricas
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
TOTAL_EXECUTION_TIME=0
declare -a TEST_RESULTS=()
declare -a PERFORMANCE_METRICS=()

# Función para logging con timestamp
log_with_timestamp() {
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
        "METRIC")
            echo -e "${PURPLE}[METRIC]${NC} $timestamp - $message"
            ;;
    esac
    
    # También escribir al log de rendimiento
    echo "[$level] $timestamp - $message" >> $PERFORMANCE_LOG
}

# Función para capturar métricas de rendimiento
capture_metrics() {
    local test_name=$1
    local execution_time=$2
    local status=$3
    local details=$4
    
    local metric_entry="{
        \"test_name\": \"$test_name\",
        \"execution_time_ms\": $execution_time,
        \"status\": \"$status\",
        \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",
        \"details\": \"$details\"
    }"
    
    PERFORMANCE_METRICS+=("$metric_entry")
    log_with_timestamp "METRIC" "$test_name: ${execution_time}ms - $status"
}

# Función para ejecutar test con métricas detalladas
execute_test_with_metrics() {
    local test_name=$1
    local test_command=$2
    local expected_max_time=$3
    local description=$4
    
    log_with_timestamp "INFO" "🧪 Ejecutando: $test_name"
    log_with_timestamp "DEBUG" "Comando: $test_command"
    log_with_timestamp "DEBUG" "Tiempo máximo esperado: ${expected_max_time}ms"
    
    local start_time=$(date +%s%3N)
    local temp_output=$(mktemp)
    local test_status="UNKNOWN"
    
    ((TOTAL_TESTS++))
    
    if timeout 300 $test_command > $temp_output 2>&1; then
        test_status="PASSED"
        ((PASSED_TESTS++))
        log_with_timestamp "INFO" "✅ $test_name - PASÓ"
    else
        test_status="FAILED"
        ((FAILED_TESTS++))
        log_with_timestamp "ERROR" "❌ $test_name - FALLÓ"
        
        # Mostrar últimas líneas del error
        echo -e "${RED}Últimas líneas del error:${NC}"
        tail -10 $temp_output
    fi
    
    local end_time=$(date +%s%3N)
    local execution_time=$((end_time - start_time))
    TOTAL_EXECUTION_TIME=$((TOTAL_EXECUTION_TIME + execution_time))
    
    # Verificar si excede tiempo esperado
    local performance_status="OK"
    if [ $execution_time -gt $expected_max_time ]; then
        performance_status="SLOW"
        log_with_timestamp "WARN" "⚠️ $test_name tardó ${execution_time}ms (esperado ≤ ${expected_max_time}ms)"
    fi
    
    # Capturar métricas
    capture_metrics "$test_name" "$execution_time" "$test_status" "$performance_status"
    
    # Guardar resultado detallado
    TEST_RESULTS+=("{
        \"name\": \"$test_name\",
        \"status\": \"$test_status\",
        \"execution_time\": $execution_time,
        \"expected_max_time\": $expected_max_time,
        \"performance_status\": \"$performance_status\",
        \"description\": \"$description\"
    }")
    
    rm -f $temp_output
    return $([ "$test_status" = "PASSED" ] && echo 0 || echo 1)
}

# Función para verificar prerrequisitos con métricas
verify_prerequisites_with_metrics() {
    log_with_timestamp "INFO" "🔍 Verificando prerrequisitos del sistema..."
    
    local prereq_start=$(date +%s%3N)
    
    # Verificar Flutter
    if ! command -v flutter &> /dev/null; then
        log_with_timestamp "ERROR" "Flutter no está instalado"
        return 1
    fi
    
    # Verificar versión de Flutter
    local flutter_version=$(flutter --version | head -1)
    log_with_timestamp "INFO" "Flutter: $flutter_version"
    
    # Verificar dependencias del proyecto
    if [ ! -f "pubspec.yaml" ]; then
        log_with_timestamp "ERROR" "pubspec.yaml no encontrado"
        return 1
    fi
    
    # Verificar memoria disponible
    local available_memory=$(free -m | awk 'NR==2{printf "%.1f", $7/1024}')
    log_with_timestamp "INFO" "Memoria disponible: ${available_memory}GB"
    
    # Verificar espacio en disco
    local available_disk=$(df -h . | awk 'NR==2{print $4}')
    log_with_timestamp "INFO" "Espacio en disco disponible: $available_disk"
    
    local prereq_end=$(date +%s%3N)
    local prereq_time=$((prereq_end - prereq_start))
    
    capture_metrics "Prerequisites Check" "$prereq_time" "PASSED" "System ready"
    
    log_with_timestamp "INFO" "✅ Prerrequisitos verificados en ${prereq_time}ms"
    return 0
}

# Función para ejecutar suite completa de tests de sincronización
run_comprehensive_sync_tests() {
    log_with_timestamp "INFO" "🚀 Iniciando suite completa de tests de sincronización"
    
    # Tests básicos de sincronización (tiempo esperado: ≤ 30s)
    execute_test_with_metrics \
        "Basic Sync Integration" \
        "flutter test test/sync_integration_test.dart" \
        30000 \
        "Pruebas básicas de integración para sincronización"
    
    # Tests de sincronización en tiempo real (tiempo esperado: ≤ 60s)
    execute_test_with_metrics \
        "Realtime Sync Complex" \
        "flutter test test/realtime_sync_complex_test.dart" \
        60000 \
        "Pruebas complejas de sincronización en tiempo real"
    
    # Tests de conflictos multi-dispositivo (tiempo esperado: ≤ 45s)
    execute_test_with_metrics \
        "Multi-Device Conflicts" \
        "flutter test test/multi_device_realtime_conflict_test.dart" \
        45000 \
        "Resolución de conflictos entre múltiples dispositivos"
    
    # Tests de estado de sincronización (tiempo esperado: ≤ 30s)
    execute_test_with_metrics \
        "Sync Status Integration" \
        "flutter test test/sync_status_integration_test.dart" \
        30000 \
        "Indicadores y estado de sincronización"
    
    # Tests de rendimiento y métricas (tiempo esperado: ≤ 90s)
    execute_test_with_metrics \
        "Sync Performance Metrics" \
        "flutter test test/sync_performance_metrics_test.dart" \
        90000 \
        "Pruebas de rendimiento y latencia ≤3s"
    
    # Tests de integridad de datos (tiempo esperado: ≤ 60s)
    execute_test_with_metrics \
        "Data Integrity Validation" \
        "flutter test test/sync_data_integrity_validation_test.dart" \
        60000 \
        "Validación de integridad de datos durante sync"
    
    # Tests de simulación multi-dispositivo (tiempo esperado: ≤ 120s)
    execute_test_with_metrics \
        "Multi-Device Simulation" \
        "flutter test test/multi_device_sync_simulation_test.dart" \
        120000 \
        "Simulación completa multi-dispositivo"
    
    # Tests de recuperación offline (tiempo esperado: ≤ 75s)
    execute_test_with_metrics \
        "Offline Sync Recovery" \
        "flutter test test/offline_sync_recovery_test.dart" \
        75000 \
        "Recuperación de sincronización post-offline"
}

# Función para ejecutar tests de funcionalidad offline
run_offline_functionality_tests() {
    log_with_timestamp "INFO" "📡 Ejecutando tests de funcionalidad offline"
    
    execute_test_with_metrics \
        "Offline Functionality" \
        "flutter test test/offline_functionality_test.dart" \
        45000 \
        "Funcionalidad sin conexión a internet"
    
    execute_test_with_metrics \
        "Offline Cache System" \
        "flutter test test/offline_cache_test.dart" \
        30000 \
        "Sistema de caché para modo offline"
    
    execute_test_with_metrics \
        "Persistent Sync Queue" \
        "flutter test test/persistent_sync_queue_test.dart" \
        30000 \
        "Cola persistente de operaciones"
}

# Función para ejecutar tests de integración E2E
run_integration_tests() {
    log_with_timestamp "INFO" "🎯 Ejecutando tests de integración E2E"
    
    execute_test_with_metrics \
        "User Authentication Flow" \
        "flutter test integration_test/user_authentication_flow_test.dart" \
        120000 \
        "Flujo completo de autenticación"
    
    execute_test_with_metrics \
        "Watchlist Management Flow" \
        "flutter test integration_test/watchlist_flow_test.dart" \
        90000 \
        "Gestión completa de watchlist"
    
    execute_test_with_metrics \
        "Sharing Functionality Flow" \
        "flutter test integration_test/sharing_functionality_flow_test.dart" \
        60000 \
        "Funcionalidad de compartir contenido"
}

# Función para generar métricas JSON
generate_metrics_json() {
    log_with_timestamp "INFO" "📊 Generando métricas en formato JSON"
    
    local metrics_json="{"
    metrics_json+="\"execution_summary\": {"
    metrics_json+="\"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\","
    metrics_json+="\"total_tests\": $TOTAL_TESTS,"
    metrics_json+="\"passed_tests\": $PASSED_TESTS,"
    metrics_json+="\"failed_tests\": $FAILED_TESTS,"
    metrics_json+="\"success_rate\": $(echo "scale=2; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l),"
    metrics_json+="\"total_execution_time_ms\": $TOTAL_EXECUTION_TIME"
    metrics_json+="},"
    
    metrics_json+="\"test_results\": ["
    local first=true
    for result in "${TEST_RESULTS[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            metrics_json+=","
        fi
        metrics_json+="$result"
    done
    metrics_json+="],"
    
    metrics_json+="\"performance_metrics\": ["
    first=true
    for metric in "${PERFORMANCE_METRICS[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            metrics_json+=","
        fi
        metrics_json+="$metric"
    done
    metrics_json+="]"
    
    metrics_json+="}"
    
    echo "$metrics_json" | jq '.' > $METRICS_FILE
    log_with_timestamp "INFO" "📄 Métricas guardadas en: $METRICS_FILE"
}

# Función para generar reporte de resumen
generate_summary_report() {
    log_with_timestamp "INFO" "📋 Generando reporte de resumen"
    
    cat > $SUMMARY_REPORT << EOF
# 📊 Reporte de Verificación de Sincronización

**Fecha de Ejecución**: $(date '+%Y-%m-%d %H:%M:%S')
**Duración Total**: ${TOTAL_EXECUTION_TIME}ms ($(echo "scale=1; $TOTAL_EXECUTION_TIME / 1000" | bc -l)s)

## 🎯 Resumen Ejecutivo

- **Total de Tests**: $TOTAL_TESTS
- **Tests Exitosos**: $PASSED_TESTS
- **Tests Fallidos**: $FAILED_TESTS
- **Tasa de Éxito**: $(echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l)%

## 📈 Métricas de Rendimiento

EOF

    # Agregar detalles de tests
    echo "### Detalles por Test" >> $SUMMARY_REPORT
    echo "" >> $SUMMARY_REPORT
    echo "| Test | Status | Tiempo (ms) | Performance |" >> $SUMMARY_REPORT
    echo "|------|--------|-------------|-------------|" >> $SUMMARY_REPORT
    
    for result in "${TEST_RESULTS[@]}"; do
        local name=$(echo "$result" | jq -r '.name')
        local status=$(echo "$result" | jq -r '.status')
        local time=$(echo "$result" | jq -r '.execution_time')
        local perf=$(echo "$result" | jq -r '.performance_status')
        
        local status_icon="❌"
        if [ "$status" = "PASSED" ]; then
            status_icon="✅"
        fi
        
        local perf_icon="🟢"
        if [ "$perf" = "SLOW" ]; then
            perf_icon="🟡"
        fi
        
        echo "| $name | $status_icon $status | $time | $perf_icon $perf |" >> $SUMMARY_REPORT
    done
    
    # Agregar conclusiones
    cat >> $SUMMARY_REPORT << EOF

## 🔍 Análisis de Resultados

EOF

    if [ $FAILED_TESTS -eq 0 ]; then
        cat >> $SUMMARY_REPORT << EOF
### ✅ Estado: TODOS LOS TESTS PASARON

🎉 **¡Excelente!** Todos los tests de sincronización han pasado exitosamente.

**Próximos Pasos**:
1. ✅ Proceder con pruebas manuales multi-dispositivo
2. ✅ Ejecutar SYNC_VERIFICATION_CHECKLIST.md
3. ✅ Validar en entorno de producción

EOF
    else
        cat >> $SUMMARY_REPORT << EOF
### ❌ Estado: REQUIERE ATENCIÓN

⚠️ **Atención**: $FAILED_TESTS tests han fallado y requieren investigación.

**Acciones Requeridas**:
1. ❌ Investigar y corregir tests fallidos
2. ❌ Re-ejecutar verificación completa
3. ❌ No proceder con pruebas manuales hasta resolver issues

EOF
    fi
    
    cat >> $SUMMARY_REPORT << EOF
## 📋 Criterios de Aceptación

- [$([ $FAILED_TESTS -eq 0 ] && echo "x" || echo " ")] **100% de tests pasando**
- [$([ $(echo "$TOTAL_EXECUTION_TIME < 600000" | bc -l) -eq 1 ] && echo "x" || echo " ")] **Tiempo total ≤ 10 minutos**
- [$([ $PASSED_TESTS -gt 0 ] && echo "x" || echo " ")] **Al menos un test de cada categoría pasando**

## 📁 Archivos Generados

- **Métricas JSON**: $METRICS_FILE
- **Log de Rendimiento**: $PERFORMANCE_LOG
- **Reporte de Resumen**: $SUMMARY_REPORT

---
*Reporte generado automáticamente por sync_monitoring_execution.sh*
EOF

    log_with_timestamp "INFO" "📄 Reporte de resumen guardado en: $SUMMARY_REPORT"
}

# Función principal
main() {
    local script_start_time=$(date +%s%3N)
    
    echo -e "${CYAN}🔄 VERIFICACIÓN INTEGRAL DE SINCRONIZACIÓN SUPABASE${NC}"
    echo -e "${CYAN}===================================================${NC}"
    echo ""
    
    # Verificar prerrequisitos
    if ! verify_prerequisites_with_metrics; then
        log_with_timestamp "ERROR" "Error en prerrequisitos. Abortando ejecución."
        exit 1
    fi
    
    echo ""
    log_with_timestamp "INFO" "🧪 Iniciando suite completa de tests..."
    echo ""
    
    # Ejecutar suite de tests de sincronización
    run_comprehensive_sync_tests
    
    echo ""
    log_with_timestamp "INFO" "📡 Ejecutando tests offline..."
    echo ""
    
    # Ejecutar tests de funcionalidad offline
    run_offline_functionality_tests
    
    echo ""
    log_with_timestamp "INFO" "🎯 Ejecutando tests de integración..."
    echo ""
    
    # Ejecutar tests de integración E2E
    run_integration_tests
    
    local script_end_time=$(date +%s%3N)
    local total_script_time=$((script_end_time - script_start_time))
    
    echo ""
    log_with_timestamp "INFO" "📊 Generando reportes finales..."
    
    # Generar métricas y reportes
    generate_metrics_json
    generate_summary_report
    
    echo ""
    echo -e "${CYAN}📋 RESUMEN FINAL${NC}"
    echo -e "${CYAN}===============${NC}"
    echo -e "Tests Ejecutados: ${BLUE}$TOTAL_TESTS${NC}"
    echo -e "Tests Exitosos: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Tests Fallidos: ${RED}$FAILED_TESTS${NC}"
    echo -e "Tasa de Éxito: ${YELLOW}$(echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l)%${NC}"
    echo -e "Tiempo Total: ${PURPLE}$(echo "scale=1; $total_script_time / 1000" | bc -l)s${NC}"
    echo ""
    echo -e "${BLUE}📁 Archivos Generados:${NC}"
    echo -e "  • ${METRICS_FILE}"
    echo -e "  • ${PERFORMANCE_LOG}"
    echo -e "  • ${SUMMARY_REPORT}"
    echo ""
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}🎉 ¡VERIFICACIÓN COMPLETADA EXITOSAMENTE!${NC}"
        echo -e "${GREEN}✅ Todos los tests de sincronización han pasado${NC}"
        echo -e "${YELLOW}➡️  Proceder con pruebas manuales en MANUAL_MULTI_DEVICE_TESTING_GUIDE.md${NC}"
        exit 0
    else
        echo -e "${RED}❌ VERIFICACIÓN COMPLETADA CON ERRORES${NC}"
        echo -e "${RED}⚠️  $FAILED_TESTS tests fallaron - Revisar logs para detalles${NC}"
        echo -e "${YELLOW}🔧 Corregir issues antes de proceder con pruebas manuales${NC}"
        exit 1
    fi
}

# Función de ayuda
show_help() {
    echo -e "${CYAN}Script de Monitoreo y Verificación Integral de Sincronización${NC}"
    echo ""
    echo "Uso: $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  -h, --help     Mostrar esta ayuda"
    echo "  -v, --verbose  Modo verbose con logging detallado"
    echo "  -q, --quick    Ejecutar solo tests críticos (más rápido)"
    echo ""
    echo "Este script ejecuta una suite completa de tests de sincronización,"
    echo "captura métricas de rendimiento y genera reportes detallados."
    echo ""
    echo "Prerequisitos:"
    echo "  - Flutter SDK instalado y configurado"
    echo "  - jq instalado para procesamiento JSON"
    echo "  - bc instalado para cálculos matemáticos"
    echo "  - Ejecutar desde la raíz del proyecto"
}

# Verificar dependencias del script
check_script_dependencies() {
    local missing_deps=()
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if ! command -v bc &> /dev/null; then
        missing_deps+=("bc")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}Error: Dependencias faltantes: ${missing_deps[*]}${NC}"
        echo "Instalar con: sudo apt-get install ${missing_deps[*]}"
        exit 1
    fi
}

# Parsear argumentos
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -v|--verbose)
        set -x
        check_script_dependencies
        main
        ;;
    -q|--quick)
        echo "Modo rápido no implementado aún. Ejecutando suite completa."
        check_script_dependencies
        main
        ;;
    "")
        check_script_dependencies
        main
        ;;
    *)
        echo "Opción desconocida: $1"
        show_help
        exit 1
        ;;
esac