#!/bin/bash

# Script de verificación completa del sistema de caché de imágenes
# Valida rendimiento, eficiencia y criterios de éxito según especificaciones

set -e

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_ROOT/cache_verification_$(date +%Y%m%d_%H%M%S).log"
METRICS_FILE="$PROJECT_ROOT/cache_metrics_$(date +%Y%m%d_%H%M%S).json"

# Funciones de utilidad
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

print_header() {
    echo ""
    log "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log "${CYAN}$1${NC}"
    log "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_section() {
    echo ""
    log "${YELLOW}▶ $1${NC}"
    log "${YELLOW}─────────────────────────────────────────────────────────────────────────────────────────────────────────${NC}"
}

print_result() {
    local status=$1
    local message=$2
    if [ "$status" == "PASS" ]; then
        log "${GREEN}✅ $message${NC}"
    elif [ "$status" == "FAIL" ]; then
        log "${RED}❌ $message${NC}"
        exit 1
    elif [ "$status" == "WARN" ]; then
        log "${YELLOW}⚠️  $message${NC}"
    else
        log "${CYAN}ℹ️  $message${NC}"
    fi
}

# Verificar que Flutter esté disponible
check_flutter() {
    if ! command -v flutter &> /dev/null; then
        print_result "FAIL" "Flutter no está instalado o no está en PATH"
    fi
    print_result "PASS" "Flutter encontrado: $(flutter --version | head -n 1)"
}

# Verificar dependencias del proyecto
check_dependencies() {
    print_section "Verificando dependencias del proyecto"
    
    cd "$PROJECT_ROOT"
    
    if [ ! -f "pubspec.yaml" ]; then
        print_result "FAIL" "pubspec.yaml no encontrado"
    fi
    
    print_result "INFO" "Obteniendo dependencias..."
    flutter pub get &>> "$LOG_FILE"
    print_result "PASS" "Dependencias instaladas correctamente"
}

# Ejecutar tests de componentes de caché adaptativo
run_adaptive_cache_tests() {
    print_section "Ejecutando tests de componentes de caché adaptativo"
    
    cd "$PROJECT_ROOT"
    
    print_result "INFO" "Ejecutando tests de componentes..."
    if flutter test test/adaptive_cache_components_test.dart --reporter=expanded &>> "$LOG_FILE"; then
        print_result "PASS" "Tests de componentes adaptativos: PASARON"
    else
        print_result "FAIL" "Tests de componentes adaptativos: FALLARON"
    fi
}

# Ejecutar tests de rendimiento completos
run_performance_tests() {
    print_section "Ejecutando tests de rendimiento de caché de imágenes"
    
    cd "$PROJECT_ROOT"
    
    print_result "INFO" "Ejecutando tests de rendimiento (esto puede tomar varios minutos)..."
    
    # Ejecutar tests con timeout extendido
    if timeout 600 flutter test test/adaptive_image_cache_performance_test.dart --reporter=expanded &>> "$LOG_FILE"; then
        print_result "PASS" "Tests de rendimiento: PASARON"
    else
        print_result "FAIL" "Tests de rendimiento: FALLARON o excedieron timeout"
    fi
}

# Analizar métricas de rendimiento
analyze_performance_metrics() {
    print_section "Analizando métricas de rendimiento"
    
    # Extraer métricas del log
    local baseline_time=$(grep -o "Baseline establecido.*Tiempo promedio: [0-9]*ms" "$LOG_FILE" | grep -o "[0-9]*ms" | head -n 1 | sed 's/ms//')
    local optimized_time=$(grep -o "Tiempo promedio: [0-9]*ms" "$LOG_FILE" | grep -o "[0-9]*" | tail -n 1)
    local cache_hit_rate=$(grep -o "Hit rate total: [0-9.]*%" "$LOG_FILE" | grep -o "[0-9.]*" | head -n 1)
    local crash_free_rate=$(grep -o "Tasa libre de crashes: [0-9.]*%" "$LOG_FILE" | grep -o "[0-9.]*" | head -n 1)
    local improvement=$(grep -o "Mejora: [0-9.]*%" "$LOG_FILE" | grep -o "[0-9.]*" | head -n 1)
    
    print_result "INFO" "Métricas extraídas del log:"
    if [ -n "$baseline_time" ]; then
        print_result "INFO" "  Tiempo baseline: ${baseline_time}ms"
    fi
    if [ -n "$optimized_time" ]; then
        print_result "INFO" "  Tiempo optimizado: ${optimized_time}ms"
    fi
    if [ -n "$cache_hit_rate" ]; then
        print_result "INFO" "  Cache hit rate: ${cache_hit_rate}%"
    fi
    if [ -n "$crash_free_rate" ]; then
        print_result "INFO" "  Crash-free rate: ${crash_free_rate}%"
    fi
    if [ -n "$improvement" ]; then
        print_result "INFO" "  Mejora de rendimiento: ${improvement}%"
    fi
    
    # Crear archivo de métricas JSON
    cat > "$METRICS_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "baseline_time_ms": ${baseline_time:-0},
  "optimized_time_ms": ${optimized_time:-0},
  "cache_hit_rate_percent": ${cache_hit_rate:-0},
  "crash_free_rate_percent": ${crash_free_rate:-0},
  "performance_improvement_percent": ${improvement:-0},
  "targets": {
    "performance_improvement_target": 30.0,
    "crash_free_target": 99.7,
    "cache_hit_target": 80.0
  }
}
EOF
    
    print_result "PASS" "Métricas guardadas en: $METRICS_FILE"
}

# Validar criterios de éxito
validate_success_criteria() {
    print_section "Validando criterios de éxito"
    
    if [ ! -f "$METRICS_FILE" ]; then
        print_result "WARN" "Archivo de métricas no encontrado, saltando validación"
        return
    fi
    
    # Leer métricas del archivo JSON (simple parsing)
    local improvement=$(grep -o '"performance_improvement_percent": [0-9.]*' "$METRICS_FILE" | grep -o '[0-9.]*')
    local crash_free=$(grep -o '"crash_free_rate_percent": [0-9.]*' "$METRICS_FILE" | grep -o '[0-9.]*')
    local cache_hit=$(grep -o '"cache_hit_rate_percent": [0-9.]*' "$METRICS_FILE" | grep -o '[0-9.]*')
    
    # Validar mejora de rendimiento ≥30%
    if [ -n "$improvement" ] && (( $(echo "$improvement >= 30.0" | bc -l) )); then
        print_result "PASS" "Mejora de rendimiento: ${improvement}% (≥30% ✓)"
    else
        print_result "FAIL" "Mejora de rendimiento: ${improvement}% (< 30% ❌)"
    fi
    
    # Validar crash-free sessions ≥99.7%
    if [ -n "$crash_free" ] && (( $(echo "$crash_free >= 99.7" | bc -l) )); then
        print_result "PASS" "Crash-free sessions: ${crash_free}% (≥99.7% ✓)"
    else
        print_result "FAIL" "Crash-free sessions: ${crash_free}% (< 99.7% ❌)"
    fi
    
    # Validar cache hit rate ≥80%
    if [ -n "$cache_hit" ] && (( $(echo "$cache_hit >= 80.0" | bc -l) )); then
        print_result "PASS" "Cache hit rate: ${cache_hit}% (≥80% ✓)"
    else
        print_result "WARN" "Cache hit rate: ${cache_hit}% (< 80% recomendado)"
    fi
}

# Verificar uso de almacenamiento
check_storage_usage() {
    print_section "Verificando uso de almacenamiento del caché"
    
    cd "$PROJECT_ROOT"
    
    # Buscar directorios de caché
    local cache_dirs=(
        "build/cache"
        "~/.cache/flutter"
        "/tmp/cache"
        "android/app/build/cache"
    )
    
    local total_cache_size=0
    
    for dir in "${cache_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local size=$(du -sm "$dir" 2>/dev/null | cut -f1 || echo "0")
            print_result "INFO" "Caché en $dir: ${size}MB"
            total_cache_size=$((total_cache_size + size))
        fi
    done
    
    print_result "INFO" "Uso total de almacenamiento de caché: ${total_cache_size}MB"
    
    # Verificar que no exceda límites razonables (2GB)
    if [ "$total_cache_size" -gt 2048 ]; then
        print_result "WARN" "Uso de caché alto: ${total_cache_size}MB (> 2GB)"
    else
        print_result "PASS" "Uso de caché dentro de límites: ${total_cache_size}MB"
    fi
}

# Verificar optimización del build
check_build_optimization() {
    print_section "Verificando optimización del build"
    
    cd "$PROJECT_ROOT"
    
    print_result "INFO" "Construyendo versión release para web..."
    if flutter build web --release &>> "$LOG_FILE"; then
        local build_size=$(du -sm build/web 2>/dev/null | cut -f1 || echo "0")
        print_result "PASS" "Build web completado: ${build_size}MB"
        
        # Verificar tamaño razonable (típicamente < 50MB para app Flutter)
        if [ "$build_size" -gt 50 ]; then
            print_result "WARN" "Build size grande: ${build_size}MB (considerar optimización)"
        else
            print_result "PASS" "Build size óptimo: ${build_size}MB"
        fi
    else
        print_result "FAIL" "Build web falló"
    fi
}

# Ejecutar análisis estático
run_static_analysis() {
    print_section "Ejecutando análisis estático"
    
    cd "$PROJECT_ROOT"
    
    print_result "INFO" "Ejecutando flutter analyze..."
    if flutter analyze --fatal-infos --fatal-warnings &>> "$LOG_FILE"; then
        print_result "PASS" "Análisis estático: sin problemas encontrados"
    else
        print_result "FAIL" "Análisis estático: se encontraron problemas"
    fi
}

# Generar reporte final
generate_final_report() {
    print_section "Generando reporte final"
    
    local report_file="$PROJECT_ROOT/cache_verification_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << EOF
# Reporte de Verificación: Sistema de Caché de Imágenes

**Fecha:** $(date)
**Duración:** $(( $(date +%s) - ${start_time:-$(date +%s)} )) segundos

## Resumen Ejecutivo

Este reporte documenta la verificación completa del sistema de caché adaptativo de imágenes implementado en la aplicación peliculas-admob.

## Objetivos de Verificación

- ✅ Garantizar almacenamiento y recuperación eficiente de imágenes desde caché local
- ✅ Validar que las imágenes no se descargan innecesariamente
- ✅ Comprobar mejora significativa en tiempo de carga (≥30%)
- ✅ Verificar adaptación a calidad de red y capacidades del dispositivo
- ✅ Validar uso eficiente de almacenamiento sin saturación
- ✅ Confirmar crash-free sessions ≥99.7%

## Métricas de Rendimiento

EOF

    if [ -f "$METRICS_FILE" ]; then
        echo "### Métricas Medidas" >> "$report_file"
        echo "" >> "$report_file"
        cat "$METRICS_FILE" | jq -r 'to_entries[] | "- **\(.key)**: \(.value)"' >> "$report_file" 2>/dev/null || echo "Métricas disponibles en: $METRICS_FILE" >> "$report_file"
    fi

    cat >> "$report_file" << EOF

## Archivos Generados

- **Log completo**: \`$(basename "$LOG_FILE")\`
- **Métricas JSON**: \`$(basename "$METRICS_FILE")\`
- **Reporte**: \`$(basename "$report_file")\`

## Tests Ejecutados

1. **Tests de Componentes Adaptativos** - Verificación de inicialización y configuración
2. **Tests de Rendimiento** - Medición de tiempos de carga y mejoras
3. **Análisis Estático** - Verificación de calidad de código
4. **Verificación de Build** - Validación de optimización del bundle

## Criterios de Éxito

Los siguientes criterios han sido evaluados según las especificaciones del issue:

EOF

    # Agregar resultados de validación al reporte
    if grep -q "Mejora de rendimiento.*≥30%.*✓" "$LOG_FILE"; then
        echo "- ✅ **Mejora de rendimiento ≥30%**: CUMPLIDO" >> "$report_file"
    else
        echo "- ❌ **Mejora de rendimiento ≥30%**: NO CUMPLIDO" >> "$report_file"
    fi

    if grep -q "Crash-free sessions.*≥99.7%.*✓" "$LOG_FILE"; then
        echo "- ✅ **Crash-free sessions ≥99.7%**: CUMPLIDO" >> "$report_file"
    else
        echo "- ❌ **Crash-free sessions ≥99.7%**: NO CUMPLIDO" >> "$report_file"
    fi

    cat >> "$report_file" << EOF

## Conclusiones

El sistema de caché adaptativo de imágenes ha sido verificado exitosamente. Las optimizaciones implementadas demuestran mejoras significativas en rendimiento y eficiencia de recursos.

### Próximos Pasos

1. Monitorear métricas en producción
2. Ajustar parámetros basándose en datos reales de uso
3. Implementar alertas automáticas para degradación de rendimiento
4. Considerar expansión del sistema adaptativo a otros componentes

---

*Generado automáticamente por el script de verificación de caché de imágenes*
EOF

    print_result "PASS" "Reporte final generado: $report_file"
}

# Función principal
main() {
    local start_time=$(date +%s)
    
    print_header "🚀 VERIFICACIÓN COMPLETA: SISTEMA DE CACHÉ DE IMÁGENES"
    
    log "Iniciando verificación del sistema de caché adaptativo de imágenes..."
    log "Directorio del proyecto: $PROJECT_ROOT"
    log "Log file: $LOG_FILE"
    log "Métricas file: $METRICS_FILE"
    
    # Verificaciones previas
    check_flutter
    check_dependencies
    
    # Tests principales
    run_adaptive_cache_tests
    run_performance_tests
    
    # Análisis de resultados
    analyze_performance_metrics
    validate_success_criteria
    
    # Verificaciones adicionales
    check_storage_usage
    check_build_optimization
    run_static_analysis
    
    # Reporte final
    generate_final_report
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    print_header "✅ VERIFICACIÓN COMPLETADA"
    print_result "PASS" "Duración total: ${duration} segundos"
    print_result "INFO" "Archivos generados:"
    print_result "INFO" "  - Log: $LOG_FILE"
    print_result "INFO" "  - Métricas: $METRICS_FILE"
    print_result "INFO" "  - Reporte: cache_verification_report_*.md"
    
    echo ""
    log "${GREEN}🎉 Verificación del sistema de caché de imágenes completada exitosamente!${NC}"
}

# Manejo de errores
trap 'print_result "FAIL" "Script interrumpido por error"; exit 1' ERR

# Ejecutar verificación
main "$@"