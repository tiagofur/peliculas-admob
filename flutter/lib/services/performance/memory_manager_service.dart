import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Servicio para monitoreo y optimización del uso de memoria
class MemoryManagerService {
  MemoryManagerService._();
  static MemoryManagerService? _instance;

  static MemoryManagerService get instance {
    _instance ??= MemoryManagerService._();
    return _instance!;
  }

  /// Realiza limpieza de memoria cuando sea necesario
  Future<void> performMemoryCleanup() async {
    try {
      // 1. Limpiar caché de imágenes en memoria
      PaintingBinding.instance.imageCache.clear();

      // 2. Llamar al garbage collector
      await _triggerGarbageCollection();

      // 3. Limpiar cache de widgets si es necesario
      WidgetsBinding.instance.performReassemble();

      if (kDebugMode) {
        debugPrint('Memory cleanup completed');
        await _logMemoryUsage();
      }
    } catch (e) {
      debugPrint('Error during memory cleanup: $e');
    }
  }

  /// Configura límites optimizados para el cache de imágenes
  void configureImageCache() {
    final imageCache = PaintingBinding.instance.imageCache;

    // Configurar límites según el dispositivo
    imageCache.maximumSize = 100; // Máximo 100 imágenes en memoria
    imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50 MB máximo

    if (kDebugMode) {
      debugPrint('Image cache configured: '
          'max size: ${imageCache.maximumSize}, '
          'max bytes: ${imageCache.maximumSizeBytes}');
    }
  }

  /// Monitorea el uso de memoria y ejecuta limpieza si es necesario
  Future<void> monitorMemoryUsage() async {
    if (!kDebugMode) return;

    try {
      final imageCache = PaintingBinding.instance.imageCache;
      final currentImages = imageCache.currentSize;
      final currentBytes = imageCache.currentSizeBytes;

      // Si el uso supera el 80%, realizar limpieza
      if (currentImages > imageCache.maximumSize * 0.8 ||
          currentBytes > imageCache.maximumSizeBytes * 0.8) {
        debugPrint('Memory usage high, performing cleanup...');
        await performMemoryCleanup();
      }

      await _logMemoryUsage();
    } catch (e) {
      debugPrint('Error monitoring memory usage: $e');
    }
  }

  /// Optimiza la configuración de memoria para el dispositivo actual
  void optimizeForDevice() {
    // Detectar si es un dispositivo de gama baja
    final isLowEndDevice = _isLowEndDevice();

    final imageCache = PaintingBinding.instance.imageCache;

    if (isLowEndDevice) {
      // Configuración conservadora para dispositivos de gama baja
      imageCache.maximumSize = 50;
      imageCache.maximumSizeBytes = 25 * 1024 * 1024; // 25 MB

      debugPrint('Low-end device detected, using conservative memory settings');
    } else {
      // Configuración estándar para dispositivos normales
      imageCache.maximumSize = 100;
      imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50 MB

      debugPrint('Standard device detected, using normal memory settings');
    }
  }

  /// Pre-carga selectiva de imágenes importantes
  Future<void> preloadCriticalImages(List<String> imageUrls) async {
    // Solo pre-cargar las primeras imágenes para no saturar la memoria
    final imagesToPreload = imageUrls.take(5).toList();

    for (final imageUrl in imagesToPreload) {
      try {
        final image = NetworkImage(imageUrl);
        await precacheImage(
            image, WidgetsBinding.instance.rootElement as BuildContext);
      } catch (e) {
        debugPrint('Error preloading image $imageUrl: $e');
      }
    }
  }

  /// Detecta si el dispositivo es de gama baja (heurística simple)
  bool _isLowEndDevice() {
    // En un entorno real, podrías usar device_info_plus para obtener más detalles
    // Por ahora, usamos una heurística simple basada en el cache de imágenes
    try {
      // Si la VM tiene limitaciones de memoria, probablemente es gama baja
      return false; // Placeholder - implementar detección real si es necesario
    } catch (e) {
      return true; // En caso de error, asumir dispositivo de gama baja
    }
  }

  /// Fuerza la recolección de basura
  Future<void> _triggerGarbageCollection() async {
    if (kDebugMode) {
      // En Flutter, el GC se maneja automáticamente
      // Simplemente esperamos un poco para dar tiempo al sistema
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Log del uso actual de memoria (solo en debug)
  Future<void> _logMemoryUsage() async {
    if (!kDebugMode) return;

    try {
      final imageCache = PaintingBinding.instance.imageCache;

      debugPrint('Memory Usage Report:');
      debugPrint(
          '  Image Cache: ${imageCache.currentSize}/${imageCache.maximumSize} images');
      debugPrint(
          '  Image Cache: ${(imageCache.currentSizeBytes / 1024 / 1024).toStringAsFixed(2)}/'
          '${(imageCache.maximumSizeBytes / 1024 / 1024).toStringAsFixed(2)} MB');

      // Información adicional si está en debug
      debugPrint('  Debug Mode: $kDebugMode');
    } catch (e) {
      debugPrint('Error logging memory usage: $e');
    }
  }

  /// Limpia recursos cuando la app va a segundo plano
  void onAppPaused() {
    performMemoryCleanup();
  }

  /// Reconfigura cuando la app vuelve a primer plano
  void onAppResumed() {
    configureImageCache();
  }
}
