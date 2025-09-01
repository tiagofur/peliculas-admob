import 'dart:io';
import 'package:flutter/foundation.dart';

/// Configuración de optimización de rendimiento para el sistema de sincronización
class PerformanceConfig {
  factory PerformanceConfig() => _instance;
  const PerformanceConfig._internal();
  
  static const PerformanceConfig _instance = PerformanceConfig._internal();

  /// Configuración de throttling para diferentes tipos de eventos
  static const Map<String, ThrottleConfig> throttleConfigs = {
    'favorites': ThrottleConfig(
      debounceMs: 300,
      throttleMs: 1000,
      maxEventsPerSecond: 3,
      batchSize: 5,
    ),
    'watched_movies': ThrottleConfig(
      debounceMs: 500,
      throttleMs: 1500,
      maxEventsPerSecond: 2,
      batchSize: 3,
    ),
    'custom_lists': ThrottleConfig(
      debounceMs: 400,
      throttleMs: 1200,
      maxEventsPerSecond: 2,
      batchSize: 4,
    ),
  };

  /// Configuración de reconexión con exponential backoff
  static const ReconnectionConfig reconnectionConfig = ReconnectionConfig(
    initialDelayMs: 1000,
    maxDelayMs: 30000,
    backoffMultiplier: 2.0,
    maxRetries: 10,
    jitterMs: 500,
  );

  /// Configuración de métricas y monitoreo
  static const MetricsConfig metricsConfig = MetricsConfig(
    maxHistoryPoints: 50,
    metricsRetentionHours: 24,
    performanceThreshold: 0.8,
    memoryThresholdMB: 100,
    enableDetailedLogging: kDebugMode,
  );

  /// Configuración de cache y memoria
  static const CacheConfig cacheConfig = CacheConfig(
    maxCacheSize: 1000,
    cacheExpirationMinutes: 30,
    enableMemoryOptimization: true,
    gcIntervalMinutes: 5,
  );

  /// Configuración específica por plataforma
  static PlatformConfig get platformConfig {
    if (Platform.isIOS) {
      return const PlatformConfig(
        maxConcurrentOperations: 3,
        backgroundSyncEnabled: true,
        lowPowerModeOptimizations: true,
        networkTimeoutSeconds: 15,
      );
    } else if (Platform.isAndroid) {
      return const PlatformConfig(
        maxConcurrentOperations: 4,
        backgroundSyncEnabled: true,
        lowPowerModeOptimizations: false,
        networkTimeoutSeconds: 20,
      );
    } else {
      // Web y otras plataformas
      return const PlatformConfig(
        maxConcurrentOperations: 2,
        backgroundSyncEnabled: false,
        lowPowerModeOptimizations: false,
        networkTimeoutSeconds: 10,
      );
    }
  }

  /// Configuración de red y conectividad
  static const NetworkConfig networkConfig = NetworkConfig(
    connectionTimeoutSeconds: 10,
    readTimeoutSeconds: 15,
    retryAttempts: 3,
    enableNetworkOptimization: true,
    compressionEnabled: true,
    keepAliveEnabled: true,
  );

  /// Obtiene la configuración de throttling para una entidad específica
  static ThrottleConfig getThrottleConfig(String entityType) {
    return throttleConfigs[entityType] ?? const ThrottleConfig();
  }

  /// Verifica si el rendimiento está dentro de los límites aceptables
  static bool isPerformanceAcceptable(double performanceScore) {
    return performanceScore >= metricsConfig.performanceThreshold;
  }

  /// Calcula el delay de reconexión con exponential backoff
  static int calculateReconnectionDelay(int attemptNumber) {
    final baseDelay = reconnectionConfig.initialDelayMs;
    final maxDelay = reconnectionConfig.maxDelayMs;
    final multiplier = reconnectionConfig.backoffMultiplier;
    final jitter = reconnectionConfig.jitterMs;
    
    int delay = (baseDelay * (multiplier * attemptNumber)).round();
    delay = delay > maxDelay ? maxDelay : delay;
    
    // Agregar jitter para evitar thundering herd
    final jitterAmount = (jitter * (0.5 + (DateTime.now().millisecondsSinceEpoch % 1000) / 2000));
    delay += jitterAmount.round();
    
    return delay;
  }

  /// Determina si se debe habilitar el modo de optimización de memoria
  static bool shouldOptimizeMemory(int currentMemoryUsageMB) {
    return currentMemoryUsageMB > metricsConfig.memoryThresholdMB;
  }

  /// Configuración adaptativa basada en el rendimiento actual
  static ThrottleConfig getAdaptiveThrottleConfig(String entityType, double currentPerformance) {
    final baseConfig = getThrottleConfig(entityType);
    
    if (currentPerformance < 0.5) {
      // Rendimiento muy bajo - throttling más agresivo
      return ThrottleConfig(
        debounceMs: (baseConfig.debounceMs * 2).round(),
        throttleMs: (baseConfig.throttleMs * 1.5).round(),
        maxEventsPerSecond: (baseConfig.maxEventsPerSecond * 0.5).round(),
        batchSize: (baseConfig.batchSize * 0.7).round(),
      );
    } else if (currentPerformance < 0.7) {
      // Rendimiento bajo - throttling moderado
      return ThrottleConfig(
        debounceMs: (baseConfig.debounceMs * 1.5).round(),
        throttleMs: (baseConfig.throttleMs * 1.2).round(),
        maxEventsPerSecond: (baseConfig.maxEventsPerSecond * 0.8).round(),
        batchSize: baseConfig.batchSize,
      );
    } else if (currentPerformance > 0.9) {
      // Rendimiento excelente - menos throttling
      return ThrottleConfig(
        debounceMs: (baseConfig.debounceMs * 0.8).round(),
        throttleMs: (baseConfig.throttleMs * 0.9).round(),
        maxEventsPerSecond: (baseConfig.maxEventsPerSecond * 1.2).round(),
        batchSize: (baseConfig.batchSize * 1.2).round(),
      );
    }
    
    return baseConfig;
  }
}

/// Configuración de throttling para eventos
class ThrottleConfig {
  const ThrottleConfig({
    this.debounceMs = 300,
    this.throttleMs = 1000,
    this.maxEventsPerSecond = 3,
    this.batchSize = 5,
  });

  final int debounceMs;
  final int throttleMs;
  final int maxEventsPerSecond;
  final int batchSize;

  Duration get debounceDuration => Duration(milliseconds: debounceMs);
  Duration get throttleDuration => Duration(milliseconds: throttleMs);
}

/// Configuración de reconexión
class ReconnectionConfig {
  const ReconnectionConfig({
    required this.initialDelayMs,
    required this.maxDelayMs,
    required this.backoffMultiplier,
    required this.maxRetries,
    required this.jitterMs,
  });

  final int initialDelayMs;
  final int maxDelayMs;
  final double backoffMultiplier;
  final int maxRetries;
  final int jitterMs;
}

/// Configuración de métricas
class MetricsConfig {
  const MetricsConfig({
    required this.maxHistoryPoints,
    required this.metricsRetentionHours,
    required this.performanceThreshold,
    required this.memoryThresholdMB,
    required this.enableDetailedLogging,
  });

  final int maxHistoryPoints;
  final int metricsRetentionHours;
  final double performanceThreshold;
  final int memoryThresholdMB;
  final bool enableDetailedLogging;
}

/// Configuración de cache
class CacheConfig {
  const CacheConfig({
    required this.maxCacheSize,
    required this.cacheExpirationMinutes,
    required this.enableMemoryOptimization,
    required this.gcIntervalMinutes,
  });

  final int maxCacheSize;
  final int cacheExpirationMinutes;
  final bool enableMemoryOptimization;
  final int gcIntervalMinutes;
}

/// Configuración específica por plataforma
class PlatformConfig {
  const PlatformConfig({
    required this.maxConcurrentOperations,
    required this.backgroundSyncEnabled,
    required this.lowPowerModeOptimizations,
    required this.networkTimeoutSeconds,
  });

  final int maxConcurrentOperations;
  final bool backgroundSyncEnabled;
  final bool lowPowerModeOptimizations;
  final int networkTimeoutSeconds;
}

/// Configuración de red
class NetworkConfig {
  const NetworkConfig({
    required this.connectionTimeoutSeconds,
    required this.readTimeoutSeconds,
    required this.retryAttempts,
    required this.enableNetworkOptimization,
    required this.compressionEnabled,
    required this.keepAliveEnabled,
  });

  final int connectionTimeoutSeconds;
  final int readTimeoutSeconds;
  final int retryAttempts;
  final bool enableNetworkOptimization;
  final bool compressionEnabled;
  final bool keepAliveEnabled;
}