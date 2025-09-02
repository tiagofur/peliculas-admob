#!/bin/bash

# Script de verificación de optimización de tamaño del build
# Valida reducción ≥20% en tamaño del bundle según optimizaciones de caché

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
RESULTS_DIR="$PROJECT_ROOT/build_analysis_$(date +%Y%m%d_%H%M%S)"
ANALYSIS_FILE="$RESULTS_DIR/build_size_analysis.json"

# Funciones de utilidad
log() {
    echo -e "$1" | tee -a "$RESULTS_DIR/build_analysis.log"
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
    elif [ "$status" == "WARN" ]; then
        log "${YELLOW}⚠️  $message${NC}"
    else
        log "${CYAN}ℹ️  $message${NC}"
    fi
}

# Preparar directorio de resultados
setup_results_directory() {
    mkdir -p "$RESULTS_DIR"
    log "Directorio de resultados creado: $RESULTS_DIR"
}

# Analizar build actual (con optimizaciones de caché)
analyze_current_build() {
    print_section "Analizando build actual (con optimizaciones de caché)"
    
    cd "$PROJECT_ROOT"
    
    # Limpiar builds anteriores
    print_result "INFO" "Limpiando builds anteriores..."
    flutter clean > /dev/null 2>&1
    
    # Build web release (más fácil de analizar)
    print_result "INFO" "Construyendo versión web release..."
    if flutter build web --release --dart-define=CACHE_OPTIMIZATION=enabled > "$RESULTS_DIR/current_build.log" 2>&1; then
        print_result "PASS" "Build web completado exitosamente"
    else
        print_result "FAIL" "Error en build web"
        return 1
    fi
    
    # Analizar tamaño del build
    local web_build_dir="$PROJECT_ROOT/build/web"
    if [ -d "$web_build_dir" ]; then
        local total_size=$(du -sb "$web_build_dir" | cut -f1)
        local total_size_mb=$(echo "scale=2; $total_size / 1024 / 1024" | bc)
        
        # Analizar componentes principales
        local main_dart_js_size=0
        local assets_size=0
        local icons_size=0
        local fonts_size=0
        
        if [ -f "$web_build_dir/main.dart.js" ]; then
            main_dart_js_size=$(stat -c%s "$web_build_dir/main.dart.js" 2>/dev/null || echo "0")
        fi
        
        if [ -d "$web_build_dir/assets" ]; then
            assets_size=$(du -sb "$web_build_dir/assets" 2>/dev/null | cut -f1 || echo "0")
        fi
        
        if [ -d "$web_build_dir/icons" ]; then
            icons_size=$(du -sb "$web_build_dir/icons" 2>/dev/null | cut -f1 || echo "0")
        fi
        
        if [ -d "$web_build_dir/fonts" ]; then
            fonts_size=$(du -sb "$web_build_dir/fonts" 2>/dev/null | cut -f1 || echo "0")
        fi
        
        # Guardar resultados actuales
        cat > "$RESULTS_DIR/current_build_analysis.json" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "build_type": "web_release_with_cache_optimization",
  "total_size_bytes": $total_size,
  "total_size_mb": $total_size_mb,
  "components": {
    "main_dart_js_bytes": $main_dart_js_size,
    "assets_bytes": $assets_size,
    "icons_bytes": $icons_size,
    "fonts_bytes": $fonts_size
  }
}
EOF
        
        print_result "INFO" "Build actual analizado:"
        print_result "INFO" "  - Tamaño total: ${total_size_mb}MB"
        print_result "INFO" "  - main.dart.js: $(echo "scale=2; $main_dart_js_size / 1024 / 1024" | bc)MB"
        print_result "INFO" "  - Assets: $(echo "scale=2; $assets_size / 1024 / 1024" | bc)MB"
        
    else
        print_result "FAIL" "Directorio de build web no encontrado"
        return 1
    fi
}

# Simular build sin optimizaciones de caché (baseline)
simulate_baseline_build() {
    print_section "Simulando build sin optimizaciones de caché (baseline)"
    
    cd "$PROJECT_ROOT"
    
    # Crear backup temporal de archivos de caché
    local temp_backup_dir="$RESULTS_DIR/cache_backup"
    mkdir -p "$temp_backup_dir"
    
    # Backup de archivos de caché principales
    local cache_files=(
        "lib/core/cache/image_cache_manager.dart"
        "lib/core/cache/adaptive_cache_config.dart"
        "lib/core/cache/network_aware_strategy.dart"
        "lib/services/hybrid_image_service.dart"
        "lib/services/image_preloader_service.dart"
    )
    
    print_result "INFO" "Creando backup de archivos de caché..."
    for file in "${cache_files[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "$temp_backup_dir/"
        fi
    done
    
    # Crear versiones "dummy" sin optimizaciones para simular baseline
    print_result "INFO" "Generando versiones baseline (sin optimizaciones)..."
    _create_baseline_cache_files
    
    # Build sin optimizaciones
    flutter clean > /dev/null 2>&1
    
    print_result "INFO" "Construyendo versión baseline..."
    if flutter build web --release --dart-define=CACHE_OPTIMIZATION=disabled > "$RESULTS_DIR/baseline_build.log" 2>&1; then
        print_result "PASS" "Build baseline completado"
        
        # Analizar tamaño baseline
        local web_build_dir="$PROJECT_ROOT/build/web"
        if [ -d "$web_build_dir" ]; then
            local baseline_size=$(du -sb "$web_build_dir" | cut -f1)
            local baseline_size_mb=$(echo "scale=2; $baseline_size / 1024 / 1024" | bc)
            
            # Guardar resultados baseline
            cat > "$RESULTS_DIR/baseline_build_analysis.json" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "build_type": "web_release_baseline",
  "total_size_bytes": $baseline_size,
  "total_size_mb": $baseline_size_mb,
  "note": "Simulated baseline without cache optimizations"
}
EOF
            
            print_result "INFO" "Build baseline analizado:"
            print_result "INFO" "  - Tamaño total: ${baseline_size_mb}MB"
            
        else
            print_result "FAIL" "Build baseline falló"
        fi
    else
        print_result "FAIL" "Error en build baseline"
    fi
    
    # Restaurar archivos originales
    print_result "INFO" "Restaurando archivos originales..."
    for file in "${cache_files[@]}"; do
        local filename=$(basename "$file")
        if [ -f "$temp_backup_dir/$filename" ]; then
            cp "$temp_backup_dir/$filename" "$file"
        fi
    done
    
    # Cleanup
    rm -rf "$temp_backup_dir"
}

# Crear archivos de caché baseline (sin optimizaciones)
_create_baseline_cache_files() {
    # Simular ImageCacheManager sin optimizaciones
    cat > "lib/core/cache/image_cache_manager.dart" << 'EOF'
// Baseline version - minimal cache implementation
import 'dart:typed_data';
import 'package:flutter/material.dart';

class ImageCacheManager {
  static ImageCacheManager? _instance;
  static ImageCacheManager get instance => _instance ??= ImageCacheManager._();
  ImageCacheManager._();

  Future<void> initialize() async {
    // Minimal initialization
  }

  Future<ImageProvider?> getCachedImage(String url) async {
    // No caching - always return network image
    return NetworkImage(url);
  }

  Future<void> clearCache() async {
    // No-op in baseline
  }

  Future<CacheStats> getStats() async {
    return CacheStats(
      memoryCacheEntries: 0,
      diskCacheEntries: 0,
      totalCacheSize: 0,
      memoryCacheHitRate: 0.0,
      diskCacheHitRate: 0.0,
      overallCacheHitRate: 0.0,
    );
  }

  Future<void> preloadImages(List<String> urls) async {
    // No preloading in baseline
  }
}

class CacheStats {
  final int memoryCacheEntries;
  final int diskCacheEntries;
  final int totalCacheSize;
  final double memoryCacheHitRate;
  final double diskCacheHitRate;
  final double overallCacheHitRate;

  CacheStats({
    required this.memoryCacheEntries,
    required this.diskCacheEntries,
    required this.totalCacheSize,
    required this.memoryCacheHitRate,
    required this.diskCacheHitRate,
    required this.overallCacheHitRate,
  });
}
EOF

    # Simular HybridImageService baseline
    cat > "lib/services/hybrid_image_service.dart" << 'EOF'
// Baseline version - no optimization
import 'package:flutter/material.dart';

class HybridImageService {
  static HybridImageService? _instance;
  static HybridImageService get instance => _instance ??= HybridImageService._();
  HybridImageService._();

  Future<void> initialize() async {
    // Minimal initialization
  }

  Future<ImageProvider> getOptimizedImageProvider(String imageUrl) async {
    if (imageUrl.isEmpty) {
      return const AssetImage('assets/images/no-image.jpg');
    }
    return NetworkImage(imageUrl);
  }

  Future<void> preloadPopularImages({
    List<String>? moviePosters,
    List<String>? personImages,
    List<String>? backdropImages,
  }) async {
    // No preloading in baseline
  }
}
EOF
}

# Comparar tamaños y calcular optimización
compare_build_sizes() {
    print_section "Comparando tamaños de build y calculando optimización"
    
    if [ ! -f "$RESULTS_DIR/current_build_analysis.json" ] || [ ! -f "$RESULTS_DIR/baseline_build_analysis.json" ]; then
        print_result "FAIL" "Archivos de análisis no encontrados"
        return 1
    fi
    
    # Extraer tamaños de los archivos JSON
    local current_size=$(grep -o '"total_size_bytes": [0-9]*' "$RESULTS_DIR/current_build_analysis.json" | grep -o '[0-9]*')
    local baseline_size=$(grep -o '"total_size_bytes": [0-9]*' "$RESULTS_DIR/baseline_build_analysis.json" | grep -o '[0-9]*')
    
    if [ -z "$current_size" ] || [ -z "$baseline_size" ]; then
        print_result "FAIL" "No se pudieron extraer los tamaños de build"
        return 1
    fi
    
    # Calcular optimización
    local size_reduction=$((baseline_size - current_size))
    local reduction_percentage=$(echo "scale=2; ($size_reduction * 100) / $baseline_size" | bc)
    
    local current_size_mb=$(echo "scale=2; $current_size / 1024 / 1024" | bc)
    local baseline_size_mb=$(echo "scale=2; $baseline_size / 1024 / 1024" | bc)
    local reduction_mb=$(echo "scale=2; $size_reduction / 1024 / 1024" | bc)
    
    # Guardar comparación
    cat > "$ANALYSIS_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "comparison": {
    "baseline_size_bytes": $baseline_size,
    "current_size_bytes": $current_size,
    "size_reduction_bytes": $size_reduction,
    "baseline_size_mb": $baseline_size_mb,
    "current_size_mb": $current_size_mb,
    "size_reduction_mb": $reduction_mb,
    "reduction_percentage": $reduction_percentage,
    "target_reduction_percentage": 20.0,
    "meets_target": $(echo "$reduction_percentage >= 20.0" | bc)
  },
  "analysis": {
    "optimization_effective": $(echo "$reduction_percentage > 0" | bc),
    "significant_reduction": $(echo "$reduction_percentage >= 10.0" | bc),
    "meets_20_percent_target": $(echo "$reduction_percentage >= 20.0" | bc)
  }
}
EOF
    
    print_result "INFO" "Análisis de comparación:"
    print_result "INFO" "  - Build baseline: ${baseline_size_mb}MB"
    print_result "INFO" "  - Build optimizado: ${current_size_mb}MB"
    print_result "INFO" "  - Reducción: ${reduction_mb}MB (${reduction_percentage}%)"
    
    # Validar criterio de éxito
    if (( $(echo "$reduction_percentage >= 20.0" | bc -l) )); then
        print_result "PASS" "Reducción ≥20% confirmada: ${reduction_percentage}%"
    elif (( $(echo "$reduction_percentage >= 10.0" | bc -l) )); then
        print_result "WARN" "Reducción significativa pero <20%: ${reduction_percentage}%"
    elif (( $(echo "$reduction_percentage > 0" | bc -l) )); then
        print_result "WARN" "Reducción mínima: ${reduction_percentage}%"
    else
        print_result "FAIL" "No se detectó reducción de tamaño"
    fi
}

# Analizar componentes específicos que contribuyen a la optimización
analyze_optimization_components() {
    print_section "Analizando componentes que contribuyen a la optimización"
    
    cd "$PROJECT_ROOT"
    
    # Analizar tree shaking effectiveness
    print_result "INFO" "Analizando efectividad del tree shaking..."
    
    if [ -f "build/web/main.dart.js" ]; then
        # Buscar referencias a componentes de caché
        local cache_references=$(grep -c "ImageCache\|CacheManager\|NetworkStrategy" build/web/main.dart.js 2>/dev/null || echo "0")
        print_result "INFO" "  - Referencias de caché en JS: $cache_references"
        
        # Analizar tamaño del archivo principal
        local main_js_size=$(stat -c%s "build/web/main.dart.js")
        local main_js_size_mb=$(echo "scale=2; $main_js_size / 1024 / 1024" | bc)
        print_result "INFO" "  - Tamaño main.dart.js: ${main_js_size_mb}MB"
    fi
    
    # Verificar assets incluidos
    if [ -d "build/web/assets" ]; then
        local assets_count=$(find build/web/assets -type f | wc -l)
        local assets_size=$(du -sb build/web/assets | cut -f1)
        local assets_size_mb=$(echo "scale=2; $assets_size / 1024 / 1024" | bc)
        
        print_result "INFO" "Assets análisis:"
        print_result "INFO" "  - Número de assets: $assets_count"
        print_result "INFO" "  - Tamaño total assets: ${assets_size_mb}MB"
        
        # Verificar si hay imágenes de placeholder optimizadas
        local placeholder_images=$(find build/web/assets -name "*placeholder*" -o -name "*no-image*" | wc -l)
        print_result "INFO" "  - Imágenes placeholder: $placeholder_images"
    fi
}

# Build para Android y verificar APK
analyze_android_build() {
    print_section "Analizando build de Android (APK)"
    
    cd "$PROJECT_ROOT"
    
    print_result "INFO" "Construyendo APK de Android..."
    if flutter build apk --release > "$RESULTS_DIR/android_build.log" 2>&1; then
        local apk_path="build/app/outputs/flutter-apk/app-release.apk"
        
        if [ -f "$apk_path" ]; then
            local apk_size=$(stat -c%s "$apk_path")
            local apk_size_mb=$(echo "scale=2; $apk_size / 1024 / 1024" | bc)
            
            print_result "PASS" "APK Android construido: ${apk_size_mb}MB"
            
            # Analizar contenido del APK (si unzip está disponible)
            if command -v unzip &> /dev/null; then
                local temp_apk_dir="$RESULTS_DIR/apk_analysis"
                mkdir -p "$temp_apk_dir"
                
                unzip -q "$apk_path" -d "$temp_apk_dir"
                
                # Analizar componentes principales
                local dex_files=$(find "$temp_apk_dir" -name "*.dex" -exec stat -c%s {} \; | paste -sd+ | bc)
                local assets_size=$(du -sb "$temp_apk_dir/assets" 2>/dev/null | cut -f1 || echo "0")
                local lib_size=$(du -sb "$temp_apk_dir/lib" 2>/dev/null | cut -f1 || echo "0")
                
                print_result "INFO" "Análisis del APK:"
                print_result "INFO" "  - DEX files: $(echo "scale=2; $dex_files / 1024 / 1024" | bc)MB"
                print_result "INFO" "  - Assets: $(echo "scale=2; $assets_size / 1024 / 1024" | bc)MB"
                print_result "INFO" "  - Librerías nativas: $(echo "scale=2; $lib_size / 1024 / 1024" | bc)MB"
                
                # Cleanup
                rm -rf "$temp_apk_dir"
            fi
            
            # Guardar información del APK
            cat > "$RESULTS_DIR/android_build_analysis.json" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "build_type": "android_apk_release",
  "apk_size_bytes": $apk_size,
  "apk_size_mb": $apk_size_mb
}
EOF
            
        else
            print_result "FAIL" "APK no encontrado en la ruta esperada"
        fi
    else
        print_result "WARN" "Build de Android falló - continuando con análisis web"
    fi
}

# Generar reporte final
generate_optimization_report() {
    print_section "Generando reporte de optimización de build"
    
    local report_file="$RESULTS_DIR/build_optimization_report.md"
    
    cat > "$report_file" << EOF
# Reporte de Optimización de Tamaño del Build

**Fecha:** $(date)
**Objetivo:** Validar reducción ≥20% en tamaño del build gracias a optimizaciones de caché

## Resumen Ejecutivo

Este reporte documenta el análisis de optimización del tamaño del build después de implementar el sistema de caché adaptativo de imágenes.

## Metodología

1. **Build Baseline:** Simulación de build sin optimizaciones de caché
2. **Build Optimizado:** Build actual con todas las optimizaciones implementadas
3. **Comparación:** Cálculo de reducción de tamaño y validación de criterios

## Resultados de Análisis

EOF

    if [ -f "$ANALYSIS_FILE" ]; then
        echo "### Comparación de Tamaños" >> "$report_file"
        echo "" >> "$report_file"
        
        # Extraer datos del JSON
        local baseline_mb=$(grep -o '"baseline_size_mb": [0-9.]*' "$ANALYSIS_FILE" | grep -o '[0-9.]*')
        local current_mb=$(grep -o '"current_size_mb": [0-9.]*' "$ANALYSIS_FILE" | grep -o '[0-9.]*')
        local reduction_mb=$(grep -o '"size_reduction_mb": [0-9.]*' "$ANALYSIS_FILE" | grep -o '[0-9.]*')
        local reduction_pct=$(grep -o '"reduction_percentage": [0-9.]*' "$ANALYSIS_FILE" | grep -o '[0-9.]*')
        local meets_target=$(grep -o '"meets_20_percent_target": [01]' "$ANALYSIS_FILE" | grep -o '[01]')
        
        cat >> "$report_file" << EOF
- **Build Baseline (sin optimizaciones):** ${baseline_mb:-"N/A"}MB
- **Build Optimizado (con caché):** ${current_mb:-"N/A"}MB
- **Reducción absoluta:** ${reduction_mb:-"N/A"}MB
- **Reducción porcentual:** ${reduction_pct:-"N/A"}%

### Validación de Criterios

EOF
        
        if [ "$meets_target" == "1" ]; then
            echo "✅ **Criterio de reducción ≥20% CUMPLIDO**" >> "$report_file"
        else
            echo "❌ **Criterio de reducción ≥20% NO CUMPLIDO**" >> "$report_file"
        fi
    fi

    cat >> "$report_file" << EOF

## Análisis Detallado

### Componentes del Build Web

EOF

    if [ -f "$RESULTS_DIR/current_build_analysis.json" ]; then
        echo "**Build optimizado:**" >> "$report_file"
        grep -o '"total_size_mb": [0-9.]*' "$RESULTS_DIR/current_build_analysis.json" | sed 's/"total_size_mb": /- Total: /' | sed 's/$/MB/' >> "$report_file"
    fi

    if [ -f "$RESULTS_DIR/android_build_analysis.json" ]; then
        echo "" >> "$report_file"
        echo "### Build Android (APK)" >> "$report_file"
        echo "" >> "$report_file"
        local apk_mb=$(grep -o '"apk_size_mb": [0-9.]*' "$RESULTS_DIR/android_build_analysis.json" | grep -o '[0-9.]*')
        echo "- **Tamaño del APK:** ${apk_mb:-"N/A"}MB" >> "$report_file"
    fi

    cat >> "$report_file" << EOF

## Factores de Optimización

Las siguientes optimizaciones contribuyen a la reducción del tamaño del build:

1. **Tree Shaking Mejorado:** Eliminación de código no utilizado en componentes de caché
2. **Lazy Loading:** Carga diferida de componentes de gestión de imágenes
3. **Configuración Adaptativa:** Carga condicional de estrategias según la plataforma
4. **Assets Optimizados:** Compresión y eliminación de recursos innecesarios
5. **Dead Code Elimination:** Remoción de código de fallback no utilizado en producción

## Impacto en Rendimiento

La reducción del tamaño del build mejora:

- **Tiempo de descarga inicial** (especialmente en web)
- **Tiempo de instalación** (en mobile)
- **Uso de almacenamiento** en el dispositivo
- **Tiempo de carga en frío** de la aplicación

## Recomendaciones

EOF

    if [ -f "$ANALYSIS_FILE" ]; then
        local meets_target=$(grep -o '"meets_20_percent_target": [01]' "$ANALYSIS_FILE" | grep -o '[01]')
        if [ "$meets_target" == "1" ]; then
            cat >> "$report_file" << EOF
✅ Las optimizaciones han alcanzado el objetivo de reducción. Se recomienda:

1. Monitorear el tamaño del build en CI/CD para evitar regresiones
2. Considerar optimizaciones adicionales para assets e imágenes
3. Evaluar técnicas de compresión avanzada para despliegue web

EOF
        else
            cat >> "$report_file" << EOF
⚠️ Las optimizaciones no han alcanzado el objetivo del 20%. Se recomienda:

1. Revisar configuraciones de tree shaking y minificación
2. Analizar dependencias que pueden estar inflando el bundle
3. Considerar lazy loading adicional para componentes no críticos
4. Evaluar el uso de técnicas de code splitting más agresivas

EOF
        fi
    fi

    cat >> "$report_file" << EOF

## Archivos Generados

- **Análisis detallado:** \`$(basename "$ANALYSIS_FILE")\`
- **Logs de build:** \`current_build.log\`, \`baseline_build.log\`
- **Reporte completo:** \`$(basename "$report_file")\`

---

*Generado automáticamente por el script de verificación de optimización de build*
EOF

    print_result "PASS" "Reporte de optimización generado: $report_file"
}

# Función principal
main() {
    print_header "📦 VERIFICACIÓN DE OPTIMIZACIÓN DE TAMAÑO DEL BUILD"
    
    log "Iniciando análisis de optimización del tamaño del build..."
    log "Objetivo: Validar reducción ≥20% del tamaño del bundle"
    
    # Verificar que Flutter esté disponible
    if ! command -v flutter &> /dev/null; then
        print_result "FAIL" "Flutter no encontrado en PATH"
        exit 1
    fi
    
    # Verificar que bc esté disponible para cálculos
    if ! command -v bc &> /dev/null; then
        print_result "FAIL" "bc (calculator) no encontrado - necesario para cálculos"
        exit 1
    fi
    
    setup_results_directory
    
    # Analizar build actual (optimizado)
    analyze_current_build
    
    # Simular build baseline (sin optimizaciones)
    simulate_baseline_build
    
    # Comparar y calcular optimización
    compare_build_sizes
    
    # Análisis adicionales
    analyze_optimization_components
    analyze_android_build
    
    # Generar reporte final
    generate_optimization_report
    
    print_header "✅ ANÁLISIS DE OPTIMIZACIÓN COMPLETADO"
    
    if [ -f "$ANALYSIS_FILE" ]; then
        local meets_target=$(grep -o '"meets_20_percent_target": [01]' "$ANALYSIS_FILE" | grep -o '[01]')
        if [ "$meets_target" == "1" ]; then
            print_result "PASS" "Objetivo de reducción ≥20% CUMPLIDO"
        else
            print_result "WARN" "Objetivo de reducción ≥20% NO CUMPLIDO"
        fi
    fi
    
    print_result "INFO" "Resultados disponibles en: $RESULTS_DIR"
}

# Manejo de errores
trap 'print_result "FAIL" "Script interrumpido por error"; exit 1' ERR

# Ejecutar análisis
main "$@"