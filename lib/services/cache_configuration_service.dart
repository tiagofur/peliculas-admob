import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'image_preloader_service.dart';

/// Configuración del sistema de caché de imágenes
class CacheConfiguration {
  const CacheConfiguration({
    this.maxMemoryCacheSize = 100 * 1024 * 1024, // 100MB
    this.maxDiskCacheSize = 500 * 1024 * 1024, // 500MB
    this.cacheExpiration = const Duration(days: 7),
    this.maxConcurrentDownloads = 3,
    this.enablePreloading = true,
    this.maxConcurrentPreloads = 3,
    this.enableCompression = true,
    this.compressionQuality = 0.8,
    this.enableMetrics = true,
    this.metricsReportInterval = const Duration(minutes: 5),
  });

  factory CacheConfiguration.fromJson(Map<String, dynamic> json) {
    return CacheConfiguration(
      maxMemoryCacheSize: json['maxMemoryCacheSize'] ?? 100 * 1024 * 1024,
      maxDiskCacheSize: json['maxDiskCacheSize'] ?? 500 * 1024 * 1024,
      cacheExpiration: Duration(days: json['cacheExpirationDays'] ?? 7),
      maxConcurrentDownloads: json['maxConcurrentDownloads'] ?? 3,
      enablePreloading: json['enablePreloading'] ?? true,
      maxConcurrentPreloads: json['maxConcurrentPreloads'] ?? 3,
      enableCompression: json['enableCompression'] ?? true,
      compressionQuality: json['compressionQuality']?.toDouble() ?? 0.8,
      enableMetrics: json['enableMetrics'] ?? true,
      metricsReportInterval:
          Duration(minutes: json['metricsReportIntervalMinutes'] ?? 5),
    );
  }
  final int maxMemoryCacheSize;
  final int maxDiskCacheSize;
  final Duration cacheExpiration;
  final int maxConcurrentDownloads;
  final bool enablePreloading;
  final int maxConcurrentPreloads;
  final bool enableCompression;
  final double compressionQuality;
  final bool enableMetrics;
  final Duration metricsReportInterval;

  Map<String, dynamic> toJson() => {
        'maxMemoryCacheSize': maxMemoryCacheSize,
        'maxDiskCacheSize': maxDiskCacheSize,
        'cacheExpirationDays': cacheExpiration.inDays,
        'maxConcurrentDownloads': maxConcurrentDownloads,
        'enablePreloading': enablePreloading,
        'maxConcurrentPreloads': maxConcurrentPreloads,
        'enableCompression': enableCompression,
        'compressionQuality': compressionQuality,
        'enableMetrics': enableMetrics,
        'metricsReportIntervalMinutes': metricsReportInterval.inMinutes,
      };

  CacheConfiguration copyWith({
    int? maxMemoryCacheSize,
    int? maxDiskCacheSize,
    Duration? cacheExpiration,
    int? maxConcurrentDownloads,
    bool? enablePreloading,
    int? maxConcurrentPreloads,
    bool? enableCompression,
    double? compressionQuality,
    bool? enableMetrics,
    Duration? metricsReportInterval,
  }) {
    return CacheConfiguration(
      maxMemoryCacheSize: maxMemoryCacheSize ?? this.maxMemoryCacheSize,
      maxDiskCacheSize: maxDiskCacheSize ?? this.maxDiskCacheSize,
      cacheExpiration: cacheExpiration ?? this.cacheExpiration,
      maxConcurrentDownloads:
          maxConcurrentDownloads ?? this.maxConcurrentDownloads,
      enablePreloading: enablePreloading ?? this.enablePreloading,
      maxConcurrentPreloads:
          maxConcurrentPreloads ?? this.maxConcurrentPreloads,
      enableCompression: enableCompression ?? this.enableCompression,
      compressionQuality: compressionQuality ?? this.compressionQuality,
      enableMetrics: enableMetrics ?? this.enableMetrics,
      metricsReportInterval:
          metricsReportInterval ?? this.metricsReportInterval,
    );
  }
}

/// Métricas de rendimiento del caché
class CacheMetrics {
  int hitCount = 0;
  int missCount = 0;
  int errorCount = 0;
  int totalRequests = 0;
  int memoryHits = 0;
  int diskHits = 0;
  int networkRequests = 0;
  double totalDownloadTime = 0.0;
  double totalCacheTime = 0.0;
  int currentMemoryUsage = 0;
  int currentDiskUsage = 0;
  DateTime lastResetTime = DateTime.now();

  double get hitRate => totalRequests > 0 ? hitCount / totalRequests : 0.0;
  double get missRate => totalRequests > 0 ? missCount / totalRequests : 0.0;
  double get errorRate => totalRequests > 0 ? errorCount / totalRequests : 0.0;
  double get averageDownloadTime =>
      networkRequests > 0 ? totalDownloadTime / networkRequests : 0.0;
  double get averageCacheTime => (memoryHits + diskHits) > 0
      ? totalCacheTime / (memoryHits + diskHits)
      : 0.0;

  void recordHit({required bool fromMemory, required double responseTime}) {
    hitCount++;
    totalRequests++;
    if (fromMemory) {
      memoryHits++;
    } else {
      diskHits++;
    }
    totalCacheTime += responseTime;
  }

  void recordMiss({required double downloadTime}) {
    missCount++;
    totalRequests++;
    networkRequests++;
    totalDownloadTime += downloadTime;
  }

  void recordError() {
    errorCount++;
    totalRequests++;
  }

  void updateUsage({required int memoryUsage, required int diskUsage}) {
    currentMemoryUsage = memoryUsage;
    currentDiskUsage = diskUsage;
  }

  void reset() {
    hitCount = 0;
    missCount = 0;
    errorCount = 0;
    totalRequests = 0;
    memoryHits = 0;
    diskHits = 0;
    networkRequests = 0;
    totalDownloadTime = 0.0;
    totalCacheTime = 0.0;
    lastResetTime = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
        'hitCount': hitCount,
        'missCount': missCount,
        'errorCount': errorCount,
        'totalRequests': totalRequests,
        'memoryHits': memoryHits,
        'diskHits': diskHits,
        'networkRequests': networkRequests,
        'hitRate': hitRate,
        'missRate': missRate,
        'errorRate': errorRate,
        'averageDownloadTime': averageDownloadTime,
        'averageCacheTime': averageCacheTime,
        'currentMemoryUsage': currentMemoryUsage,
        'currentDiskUsage': currentDiskUsage,
        'lastResetTime': lastResetTime.toIso8601String(),
      };
}

/// Servicio de configuración y monitoreo del caché
class CacheConfigurationService {
  factory CacheConfigurationService() => _instance;
  CacheConfigurationService._internal();
  static final CacheConfigurationService _instance =
      CacheConfigurationService._internal();

  final Logger _logger = Logger('CacheConfigurationService');
  CacheConfiguration _config = const CacheConfiguration();
  final CacheMetrics _metrics = CacheMetrics();
  Timer? _metricsTimer;
  SharedPreferences? _prefs;

  static const String _configKey = 'cache_configuration';
  static const String _metricsKey = 'cache_metrics';

  CacheConfiguration get config => _config;
  CacheMetrics get metrics => _metrics;

  /// Inicializa el servicio de configuración
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadConfiguration();
      await _loadMetrics();
      _startMetricsTimer();
      _logger.info('CacheConfigurationService initialized');
    } catch (e) {
      _logger.severe('Failed to initialize CacheConfigurationService: $e');
    }
  }

  /// Carga la configuración guardada
  Future<void> _loadConfiguration() async {
    try {
      final configJson = _prefs?.getString(_configKey);
      if (configJson != null) {
        final configMap = jsonDecode(configJson) as Map<String, dynamic>;
        _config = CacheConfiguration.fromJson(configMap);
        _logger.info('Loaded cache configuration from preferences');
      }
    } catch (e) {
      _logger.warning('Failed to load cache configuration: $e');
    }
  }

  /// Carga las métricas guardadas
  Future<void> _loadMetrics() async {
    try {
      final metricsJson = _prefs?.getString(_metricsKey);
      if (metricsJson != null) {
        final metricsMap = jsonDecode(metricsJson) as Map<String, dynamic>;
        // Solo cargar métricas si son del mismo día
        final lastReset = DateTime.parse(metricsMap['lastResetTime']);
        if (DateTime.now().difference(lastReset).inDays == 0) {
          _metrics.hitCount = metricsMap['hitCount'] ?? 0;
          _metrics.missCount = metricsMap['missCount'] ?? 0;
          _metrics.errorCount = metricsMap['errorCount'] ?? 0;
          _metrics.totalRequests = metricsMap['totalRequests'] ?? 0;
          _metrics.memoryHits = metricsMap['memoryHits'] ?? 0;
          _metrics.diskHits = metricsMap['diskHits'] ?? 0;
          _metrics.networkRequests = metricsMap['networkRequests'] ?? 0;
          _metrics.totalDownloadTime = metricsMap['totalDownloadTime'] ?? 0.0;
          _metrics.totalCacheTime = metricsMap['totalCacheTime'] ?? 0.0;
          _metrics.lastResetTime = lastReset;
          _logger.info('Loaded cache metrics from preferences');
        } else {
          _logger.info('Metrics are from previous day, starting fresh');
        }
      }
    } catch (e) {
      _logger.warning('Failed to load cache metrics: $e');
    }
  }

  /// Actualiza la configuración del caché
  Future<void> updateConfiguration(CacheConfiguration newConfig) async {
    _config = newConfig;

    try {
      // Guardar configuración
      await _prefs?.setString(_configKey, jsonEncode(_config.toJson()));

      // Aplicar configuración a los servicios
      await _applyConfiguration();

      _logger.info('Cache configuration updated and applied');
    } catch (e) {
      _logger.severe('Failed to update cache configuration: $e');
    }
  }

  /// Aplica la configuración actual a los servicios
  Future<void> _applyConfiguration() async {
    try {
      // Configurar ImagePreloaderService
      ImagePreloaderService().configure(
        enabled: _config.enablePreloading,
        maxConcurrentPreloads: _config.maxConcurrentPreloads,
      );

      // Reiniciar timer de métricas si cambió el intervalo
      _startMetricsTimer();
    } catch (e) {
      _logger.warning('Failed to apply configuration: $e');
    }
  }

  /// Inicia el timer de métricas
  void _startMetricsTimer() {
    _metricsTimer?.cancel();

    if (_config.enableMetrics) {
      _metricsTimer = Timer.periodic(_config.metricsReportInterval, (timer) {
        _reportMetrics();
        _saveMetrics();
      });
    }
  }

  /// Reporta las métricas actuales
  void _reportMetrics() {
    if (kDebugMode) {
      _logger.info('Cache Metrics Report:');
      _logger
          .info('  Hit Rate: ${(_metrics.hitRate * 100).toStringAsFixed(1)}%');
      _logger.info(
          '  Miss Rate: ${(_metrics.missRate * 100).toStringAsFixed(1)}%');
      _logger.info(
          '  Error Rate: ${(_metrics.errorRate * 100).toStringAsFixed(1)}%');
      _logger.info('  Total Requests: ${_metrics.totalRequests}');
      _logger.info('  Memory Hits: ${_metrics.memoryHits}');
      _logger.info('  Disk Hits: ${_metrics.diskHits}');
      _logger.info('  Network Requests: ${_metrics.networkRequests}');
      _logger.info(
          '  Avg Download Time: ${_metrics.averageDownloadTime.toStringAsFixed(2)}ms');
      _logger.info(
          '  Avg Cache Time: ${_metrics.averageCacheTime.toStringAsFixed(2)}ms');
      _logger.info(
          '  Memory Usage: ${(_metrics.currentMemoryUsage / 1024 / 1024).toStringAsFixed(1)}MB');
      _logger.info(
          '  Disk Usage: ${(_metrics.currentDiskUsage / 1024 / 1024).toStringAsFixed(1)}MB');
    }
  }

  /// Guarda las métricas
  Future<void> _saveMetrics() async {
    try {
      await _prefs?.setString(_metricsKey, jsonEncode(_metrics.toJson()));
    } catch (e) {
      _logger.warning('Failed to save metrics: $e');
    }
  }

  /// Registra un hit en el caché
  void recordCacheHit(
      {required bool fromMemory, required double responseTime}) {
    _metrics.recordHit(fromMemory: fromMemory, responseTime: responseTime);
  }

  /// Registra un miss en el caché
  void recordCacheMiss({required double downloadTime}) {
    _metrics.recordMiss(downloadTime: downloadTime);
  }

  /// Registra un error
  void recordError() {
    _metrics.recordError();
  }

  /// Actualiza el uso de memoria y disco
  void updateUsage({required int memoryUsage, required int diskUsage}) {
    _metrics.updateUsage(memoryUsage: memoryUsage, diskUsage: diskUsage);
  }

  /// Resetea las métricas
  void resetMetrics() {
    _metrics.reset();
    _saveMetrics();
    _logger.info('Cache metrics reset');
  }

  /// Obtiene un reporte completo del estado del caché
  Map<String, dynamic> getFullReport() {
    return {
      'configuration': _config.toJson(),
      'metrics': _metrics.toJson(),
      'preloaderStats': ImagePreloaderService().getStats(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Optimiza automáticamente la configuración basada en las métricas
  Future<void> autoOptimize() async {
    if (_metrics.totalRequests < 100) {
      _logger.info('Not enough data for auto-optimization');
      return;
    }

    var newConfig = _config;
    bool changed = false;

    // Si la tasa de error es alta, reducir descargas concurrentes
    if (_metrics.errorRate > 0.1 && _config.maxConcurrentDownloads > 1) {
      newConfig = newConfig.copyWith(
          maxConcurrentDownloads: _config.maxConcurrentDownloads - 1);
      changed = true;
      _logger.info('Reduced concurrent downloads due to high error rate');
    }

    // Si la tasa de hit es muy baja, aumentar el tamaño del caché
    if (_metrics.hitRate < 0.3 &&
        _config.maxMemoryCacheSize < 200 * 1024 * 1024) {
      newConfig = newConfig.copyWith(
          maxMemoryCacheSize: _config.maxMemoryCacheSize + 50 * 1024 * 1024);
      changed = true;
      _logger.info('Increased memory cache size due to low hit rate');
    }

    // Si el tiempo de descarga promedio es alto, habilitar precarga
    if (_metrics.averageDownloadTime > 2000 && !_config.enablePreloading) {
      newConfig = newConfig.copyWith(enablePreloading: true);
      changed = true;
      _logger.info('Enabled preloading due to slow download times');
    }

    if (changed) {
      await updateConfiguration(newConfig);
      _logger.info('Auto-optimization applied');
    } else {
      _logger.info('No optimization needed');
    }
  }

  /// Libera recursos del servicio
  void dispose() {
    _metricsTimer?.cancel();
    _saveMetrics();
    _logger.info('CacheConfigurationService disposed');
  }
}
