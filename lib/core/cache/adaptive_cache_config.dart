import 'dart:io';

import 'package:flutter/foundation.dart';

import '../logging/logger_factory.dart';

/// Configuración adaptativa del caché basada en las capacidades del dispositivo
class AdaptiveCacheConfig {
  AdaptiveCacheConfig._();
  static AdaptiveCacheConfig? _instance;
  static AdaptiveCacheConfig get instance =>
      _instance ??= AdaptiveCacheConfig._();

  final _logger = LoggerFactory.logger;

  // Configuración por defecto
  static const int _baseMemoryCache = 50 * 1024 * 1024; // 50MB base
  static const int _baseDiskCache = 250 * 1024 * 1024; // 250MB base

  // Configuración detectada
  DeviceCapabilities? _deviceCapabilities;
  CacheConfiguration? _cacheConfiguration;

  bool _isInitialized = false;

  /// Inicializa la configuración adaptativa
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.info('🔧 Inicializando configuración adaptativa de caché...');

      // Detectar capacidades del dispositivo
      _deviceCapabilities = await _detectDeviceCapabilities();

      // Configurar caché según capacidades
      _cacheConfiguration = _calculateOptimalConfiguration(_deviceCapabilities!);

      _isInitialized = true;

      _logger.info('✅ Configuración adaptativa inicializada: '
          'memoria=${(_cacheConfiguration!.memoryCacheSize / 1024 / 1024).toStringAsFixed(1)}MB, '
          'disco=${(_cacheConfiguration!.diskCacheSize / 1024 / 1024).toStringAsFixed(1)}MB, '
          'tier=${_deviceCapabilities!.performanceTier}');
    } catch (e) {
      _logger.error('❌ Error inicializando configuración adaptativa: $e');
      // Fallback a configuración segura
      _deviceCapabilities = DeviceCapabilities.safeFallback();
      _cacheConfiguration = CacheConfiguration.safeFallback();
      _isInitialized = true;
    }
  }

  /// Detecta las capacidades del dispositivo
  Future<DeviceCapabilities> _detectDeviceCapabilities() async {
    try {
      // Detectar memoria aproximada basada en la plataforma
      int estimatedMemoryMB = _estimateDeviceMemory();

      // Detectar tipo de dispositivo
      DeviceType deviceType = _detectDeviceType();

      // Detectar nivel de rendimiento
      PerformanceTier performanceTier =
          _detectPerformanceTier(estimatedMemoryMB, deviceType);

      // Verificar almacenamiento disponible (simplificado)
      double storageMultiplier = await _getStorageMultiplier();

      return DeviceCapabilities(
        estimatedMemoryMB: estimatedMemoryMB,
        deviceType: deviceType,
        performanceTier: performanceTier,
        storageMultiplier: storageMultiplier,
      );
    } catch (e) {
      _logger.warning('⚠️ Error detectando capacidades del dispositivo: $e');
      return DeviceCapabilities.safeFallback();
    }
  }

  /// Estima la memoria del dispositivo basada en la plataforma
  int _estimateDeviceMemory() {
    if (kIsWeb) {
      // En web, asumir menos memoria disponible
      return 2048; // 2GB estimado para web
    }

    if (Platform.isAndroid || Platform.isIOS) {
      // Para móviles, usar heurísticas basadas en resolución de pantalla
      final size = PlatformDispatcher.instance.views.first.physicalSize;
      final pixels = size.width * size.height;

      if (pixels > 3000000) {
        // ~2K+ resolution
        return 8192; // 8GB estimado para dispositivos premium
      } else if (pixels > 2000000) {
        // ~1080p
        return 4096; // 4GB estimado para dispositivos mid-range
      } else {
        return 2048; // 2GB estimado para dispositivos básicos
      }
    }

    // Desktop: asumir más memoria disponible
    return 8192; // 8GB estimado para desktop
  }

  /// Detecta el tipo de dispositivo
  DeviceType _detectDeviceType() {
    if (kIsWeb) return DeviceType.web;
    if (Platform.isAndroid) return DeviceType.android;
    if (Platform.isIOS) return DeviceType.ios;
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return DeviceType.desktop;
    }
    return DeviceType.unknown;
  }

  /// Detecta el nivel de rendimiento del dispositivo
  PerformanceTier _detectPerformanceTier(int memoryMB, DeviceType deviceType) {
    // Heurísticas conservadoras para determinar el tier de rendimiento
    if (deviceType == DeviceType.desktop) {
      return memoryMB >= 8192 ? PerformanceTier.high : PerformanceTier.medium;
    }

    if (deviceType == DeviceType.web) {
      return PerformanceTier.low; // Conservador para web
    }

    // Para móviles (Android/iOS)
    if (memoryMB >= 8192) {
      return PerformanceTier.high;
    } else if (memoryMB >= 4096) {
      return PerformanceTier.medium;
    } else {
      return PerformanceTier.low;
    }
  }

  /// Obtiene el multiplicador de almacenamiento disponible
  Future<double> _getStorageMultiplier() async {
    try {
      // Simplificado: asumir almacenamiento adecuado
      // En una implementación real, se podría verificar el espacio disponible
      return 1.0;
    } catch (e) {
      _logger.warning('⚠️ Error verificando almacenamiento: $e');
      return 0.5; // Conservador si no se puede detectar
    }
  }

  /// Calcula la configuración óptima basada en las capacidades
  CacheConfiguration _calculateOptimalConfiguration(
      DeviceCapabilities capabilities) {
    // Multiplicadores basados en el tier de rendimiento
    double memoryMultiplier;
    double diskMultiplier;
    int concurrentDownloads;

    switch (capabilities.performanceTier) {
      case PerformanceTier.high:
        memoryMultiplier = 3.0; // 150MB
        diskMultiplier = 4.0; // 1GB
        concurrentDownloads = 5;
        break;
      case PerformanceTier.medium:
        memoryMultiplier = 2.0; // 100MB
        diskMultiplier = 2.0; // 500MB
        concurrentDownloads = 3;
        break;
      case PerformanceTier.low:
        memoryMultiplier = 1.0; // 50MB
        diskMultiplier = 1.0; // 250MB
        concurrentDownloads = 2;
        break;
    }

    // Ajustar por almacenamiento disponible
    diskMultiplier *= capabilities.storageMultiplier;

    // Calcular tamaños finales
    int memoryCacheSize = (_baseMemoryCache * memoryMultiplier).round();
    int diskCacheSize = (_baseDiskCache * diskMultiplier).round();

    // Límites de seguridad
    memoryCacheSize = memoryCacheSize.clamp(
        20 * 1024 * 1024, 200 * 1024 * 1024); // 20MB - 200MB
    diskCacheSize = diskCacheSize.clamp(
        100 * 1024 * 1024, 2 * 1024 * 1024 * 1024); // 100MB - 2GB

    return CacheConfiguration(
      memoryCacheSize: memoryCacheSize,
      diskCacheSize: diskCacheSize,
      maxConcurrentDownloads: concurrentDownloads,
      downloadTimeout: _calculateDownloadTimeout(capabilities.performanceTier),
      cacheExpiry: _calculateCacheExpiry(capabilities.performanceTier),
    );
  }

  /// Calcula el timeout de descarga basado en el rendimiento
  Duration _calculateDownloadTimeout(PerformanceTier tier) {
    switch (tier) {
      case PerformanceTier.high:
        return const Duration(seconds: 20);
      case PerformanceTier.medium:
        return const Duration(seconds: 30);
      case PerformanceTier.low:
        return const Duration(seconds: 45);
    }
  }

  /// Calcula la expiración del caché basada en el rendimiento
  Duration _calculateCacheExpiry(PerformanceTier tier) {
    switch (tier) {
      case PerformanceTier.high:
        return const Duration(days: 14); // Más tiempo para dispositivos capaces
      case PerformanceTier.medium:
        return const Duration(days: 7);
      case PerformanceTier.low:
        return const Duration(days: 3); // Limpiar más frecuentemente
    }
  }

  // Getters públicos
  CacheConfiguration get configuration {
    if (!_isInitialized || _cacheConfiguration == null) {
      throw StateError('AdaptiveCacheConfig no ha sido inicializado');
    }
    return _cacheConfiguration!;
  }

  DeviceCapabilities get deviceCapabilities {
    if (!_isInitialized || _deviceCapabilities == null) {
      throw StateError('AdaptiveCacheConfig no ha sido inicializado');
    }
    return _deviceCapabilities!;
  }

  bool get isInitialized => _isInitialized;
}

/// Capacidades detectadas del dispositivo
class DeviceCapabilities {
  const DeviceCapabilities({
    required this.estimatedMemoryMB,
    required this.deviceType,
    required this.performanceTier,
    required this.storageMultiplier,
  });

  factory DeviceCapabilities.safeFallback() {
    return const DeviceCapabilities(
      estimatedMemoryMB: 2048,
      deviceType: DeviceType.unknown,
      performanceTier: PerformanceTier.low,
      storageMultiplier: 0.5,
    );
  }

  final int estimatedMemoryMB;
  final DeviceType deviceType;
  final PerformanceTier performanceTier;
  final double storageMultiplier;

  @override
  String toString() {
    return 'DeviceCapabilities(memory: ${estimatedMemoryMB}MB, '
        'type: $deviceType, tier: $performanceTier, storage: ${storageMultiplier}x)';
  }
}

/// Configuración del caché calculada
class CacheConfiguration {
  const CacheConfiguration({
    required this.memoryCacheSize,
    required this.diskCacheSize,
    required this.maxConcurrentDownloads,
    required this.downloadTimeout,
    required this.cacheExpiry,
  });

  factory CacheConfiguration.safeFallback() {
    return const CacheConfiguration(
      memoryCacheSize: 20 * 1024 * 1024, // 20MB
      diskCacheSize: 100 * 1024 * 1024, // 100MB
      maxConcurrentDownloads: 1,
      downloadTimeout: Duration(seconds: 60),
      cacheExpiry: Duration(days: 3),
    );
  }

  final int memoryCacheSize;
  final int diskCacheSize;
  final int maxConcurrentDownloads;
  final Duration downloadTimeout;
  final Duration cacheExpiry;

  @override
  String toString() {
    return 'CacheConfiguration(memory: ${(memoryCacheSize / 1024 / 1024).toStringAsFixed(1)}MB, '
        'disk: ${(diskCacheSize / 1024 / 1024).toStringAsFixed(1)}MB, '
        'concurrent: $maxConcurrentDownloads, timeout: ${downloadTimeout.inSeconds}s)';
  }
}

/// Tipos de dispositivo soportados
enum DeviceType {
  android,
  ios,
  web,
  desktop,
  unknown,
}

/// Niveles de rendimiento del dispositivo
enum PerformanceTier {
  low, // Dispositivos básicos, recursos limitados
  medium, // Dispositivos mid-range, recursos moderados
  high, // Dispositivos premium, recursos abundantes
}
