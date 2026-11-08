import 'package:flutter/material.dart';

import 'advanced_cache_manager.dart';
import 'image_optimization_service.dart';
import 'memory_manager_service.dart';

/// Servicio principal de performance que coordina todas las optimizaciones
class PerformanceManagerService {
  PerformanceManagerService._();
  static PerformanceManagerService? _instance;

  static PerformanceManagerService get instance {
    _instance ??= PerformanceManagerService._();
    return _instance!;
  }

  /// Inicializa todas las optimizaciones de performance
  Future<void> initializePerformanceOptimizations() async {
    try {
      debugPrint('🚀 Iniciando optimizaciones de performance...');

      // 1. Configurar memoria
      MemoryManagerService.instance.configureImageCache();
      MemoryManagerService.instance.optimizeForDevice();

      // 2. Configurar cache managers
      await AdvancedCacheManager.manageCacheSizes();

      debugPrint('✅ Optimizaciones de performance inicializadas');
    } catch (e) {
      debugPrint('❌ Error inicializando performance: $e');
    }
  }

  /// Realiza mantenimiento de performance en segundo plano
  Future<void> performBackgroundMaintenance() async {
    try {
      debugPrint('🧹 Ejecutando mantenimiento de performance...');

      // 1. Limpieza de memoria
      await MemoryManagerService.instance.performMemoryCleanup();

      // 2. Gestión de cache
      await AdvancedCacheManager.performMaintenance();

      // 3. Monitoreo de memoria
      await MemoryManagerService.instance.monitorMemoryUsage();

      debugPrint('✅ Mantenimiento de performance completado');
    } catch (e) {
      debugPrint('❌ Error en mantenimiento: $e');
    }
  }

  /// Optimiza la app para el primer arranque
  Future<void> optimizeAppStartup() async {
    try {
      debugPrint('⚡ Optimizando arranque de la app...');

      // 1. Pre-configurar cache de imágenes
      MemoryManagerService.instance.configureImageCache();

      // 2. Detectar tipo de dispositivo y optimizar
      MemoryManagerService.instance.optimizeForDevice();

      debugPrint('✅ Optimización de arranque completada');
    } catch (e) {
      debugPrint('❌ Error optimizando arranque: $e');
    }
  }

  /// Pre-carga recursos críticos de manera inteligente
  Future<void> preloadCriticalResources({
    List<String>? imageUrls,
    List<String>? moviePosters,
  }) async {
    try {
      debugPrint('📦 Pre-cargando recursos críticos...');

      // 1. Pre-cargar imágenes importantes
      if (imageUrls != null && imageUrls.isNotEmpty) {
        await ImageOptimizationService.instance
            .preloadImportantImages(imageUrls);
      }

      // 2. Pre-cargar posters de películas populares
      if (moviePosters != null && moviePosters.isNotEmpty) {
        await MemoryManagerService.instance.preloadCriticalImages(moviePosters);
      }

      debugPrint('✅ Recursos críticos pre-cargados');
    } catch (e) {
      debugPrint('❌ Error pre-cargando recursos: $e');
    }
  }

  /// Optimiza la performance durante la navegación
  void optimizeNavigation() {
    try {
      // Limpiar cache de widgets antiguos
      WidgetsBinding.instance.buildOwner
          ?.reassemble(WidgetsBinding.instance.rootElement!);

      debugPrint('🧭 Navegación optimizada');
    } catch (e) {
      debugPrint('❌ Error optimizando navegación: $e');
    }
  }

  /// Obtiene métricas de performance actuales
  Future<PerformanceMetrics> getPerformanceMetrics() async {
    try {
      final imageCache = PaintingBinding.instance.imageCache;

      return PerformanceMetrics(
        imageCacheSize: imageCache.currentSize,
        imageCacheMaxSize: imageCache.maximumSize,
        imageCacheBytes: imageCache.currentSizeBytes,
        imageCacheMaxBytes: imageCache.maximumSizeBytes,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Error obteniendo métricas: $e');
      return PerformanceMetrics.empty();
    }
  }

  /// Limpieza completa cuando la app va a segundo plano
  Future<void> onAppPaused() async {
    try {
      debugPrint('⏸️ App pausada, ejecutando limpieza...');

      MemoryManagerService.instance.onAppPaused();
      await AdvancedCacheManager.manageCacheSizes();

      debugPrint('✅ Limpieza por pausa completada');
    } catch (e) {
      debugPrint('❌ Error en pausa: $e');
    }
  }

  /// Reconfiguración cuando la app vuelve a primer plano
  void onAppResumed() {
    try {
      debugPrint('▶️ App resumida, reconfigurando...');

      MemoryManagerService.instance.onAppResumed();

      debugPrint('✅ Reconfiguración por resume completada');
    } catch (e) {
      debugPrint('❌ Error en resume: $e');
    }
  }
}

/// Métricas de performance de la aplicación
class PerformanceMetrics {
  const PerformanceMetrics({
    required this.imageCacheSize,
    required this.imageCacheMaxSize,
    required this.imageCacheBytes,
    required this.imageCacheMaxBytes,
    required this.timestamp,
  });

  factory PerformanceMetrics.empty() {
    return PerformanceMetrics(
      imageCacheSize: 0,
      imageCacheMaxSize: 0,
      imageCacheBytes: 0,
      imageCacheMaxBytes: 0,
      timestamp: DateTime.now(),
    );
  }
  final int imageCacheSize;
  final int imageCacheMaxSize;
  final int imageCacheBytes;
  final int imageCacheMaxBytes;
  final DateTime timestamp;

  /// Porcentaje de uso del cache de imágenes
  double get cacheUsagePercentage {
    if (imageCacheMaxSize == 0) return 0.0;
    return (imageCacheSize / imageCacheMaxSize) * 100;
  }

  /// Porcentaje de uso de memoria del cache
  double get memoryUsagePercentage {
    if (imageCacheMaxBytes == 0) return 0.0;
    return (imageCacheBytes / imageCacheMaxBytes) * 100;
  }

  /// Memoria total en MB
  double get totalMemoryMB {
    return imageCacheBytes / 1024 / 1024;
  }

  /// Memoria máxima en MB
  double get maxMemoryMB {
    return imageCacheMaxBytes / 1024 / 1024;
  }

  @override
  String toString() {
    return 'PerformanceMetrics('
        'cache: $imageCacheSize/$imageCacheMaxSize (${cacheUsagePercentage.toStringAsFixed(1)}%), '
        'memory: ${totalMemoryMB.toStringAsFixed(1)}/${maxMemoryMB.toStringAsFixed(1)}MB '
        '(${memoryUsagePercentage.toStringAsFixed(1)}%))';
  }
}
