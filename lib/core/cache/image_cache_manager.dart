import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../logging/logger_factory.dart';
import 'adaptive_cache_config.dart';
import 'image_cache_performance_metrics.dart';
import 'network_aware_strategy.dart';

/// Gestor avanzado de caché de imágenes con estrategias adaptativas
class ImageCacheManager {
  ImageCacheManager._();
  static ImageCacheManager? _instance;
  static ImageCacheManager get instance => _instance ??= ImageCacheManager._();

  // Configuración adaptativa (se inicializa dinámicamente)
  int _maxMemoryCache = 50 * 1024 * 1024; // 50MB default
  int _maxDiskCache = 250 * 1024 * 1024; // 250MB default
  int _maxConcurrentDownloads = 2; // default
// default
  Duration _cacheExpiry = const Duration(days: 7); // default

  final _logger = LoggerFactory.logger;

  // Caché en memoria usando LRU
  final Map<String, _CacheEntry> _memoryCache = {};
  final List<String> _lruOrder = [];
  int _memoryCacheSize = 0;

  // Control de descargas concurrentes
  final Map<String, Future<Uint8List?>> _activeDownloads = {};
  final Set<String> _failedUrls = {};

  // Directorio de caché en disco
  Directory? _cacheDirectory;

  /// Inicializa el gestor de caché con configuración adaptativa
  Future<void> initialize() async {
    try {
      _logger.info('🚀 Inicializando ImageCacheManager adaptativo...');

      // Inicializar configuración adaptativa
      await AdaptiveCacheConfig.instance.initialize();
      final config = AdaptiveCacheConfig.instance.configuration;

      // Aplicar configuración adaptativa
      _maxMemoryCache = config.memoryCacheSize;
      _maxDiskCache = config.diskCacheSize;
      _maxConcurrentDownloads = config.maxConcurrentDownloads;
      _cacheExpiry = config.cacheExpiry;

      // Inicializar estrategia de red
      await NetworkAwareStrategy.instance.initialize();

      // Inicializar métricas de rendimiento
      ImageCachePerformanceMetrics.instance.initialize();

      // Configurar directorio de caché
      await _setupCacheDirectory();

      // Limpiar caché expirado al inicializar
      await _cleanExpiredCache();

      _logger.info(
          '✅ ImageCacheManager inicializado con configuración adaptativa: '
          'memoria=${(_maxMemoryCache / 1024 / 1024).toStringAsFixed(1)}MB, '
          'disco=${(_maxDiskCache / 1024 / 1024).toStringAsFixed(1)}MB, '
          'concurrent=$_maxConcurrentDownloads');
    } catch (e) {
      _logger.error('❌ Error inicializando ImageCacheManager: $e');
    }
  }

  /// Configura el directorio de caché
  Future<void> _setupCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDirectory = Directory('${appDir.path}/image_cache');

    if (_cacheDirectory != null &&
        !(await _cacheDirectory?.exists() ?? false)) {
      await _cacheDirectory?.create(recursive: true);
    }
  }

  /// Obtiene una imagen del caché o la descarga con estrategia adaptativa
  Future<ImageProvider?> getCachedImage(String url) async {
    if (url.isEmpty) return null;

    final stopwatch = Stopwatch()..start();
    ImageCachePerformanceMetrics.instance.recordImageRequest();

    try {
      // Verificar si la URL ha fallado recientemente
      if (_failedUrls.contains(url)) {
        ImageCachePerformanceMetrics.instance.recordFailedRequest();
        return null;
      }

      final cacheKey = _generateCacheKey(url);

      // 1. Verificar caché en memoria
      final memoryStopwatch = Stopwatch()..start();
      final memoryEntry = _getFromMemoryCache(cacheKey);
      memoryStopwatch.stop();

      if (memoryEntry != null) {
        stopwatch.stop();
        ImageCachePerformanceMetrics.instance
            .recordMemoryCacheHit(memoryStopwatch.elapsed);
        ImageCachePerformanceMetrics.instance.recordLoadTime(stopwatch.elapsed);
        _logger.debug('✅ Imagen encontrada en caché de memoria: $url');
        return MemoryImage(memoryEntry);
      }

      // 2. Verificar caché en disco
      final diskStopwatch = Stopwatch()..start();
      final diskData = await _getFromDiskCache(cacheKey);
      diskStopwatch.stop();

      if (diskData != null) {
        stopwatch.stop();
        ImageCachePerformanceMetrics.instance
            .recordDiskCacheHit(diskStopwatch.elapsed);
        ImageCachePerformanceMetrics.instance.recordLoadTime(stopwatch.elapsed);
        _addToMemoryCache(cacheKey, diskData);
        _logger.debug('💾 Imagen encontrada en caché de disco: $url');
        return MemoryImage(diskData);
      }

      // 3. Descargar imagen con estrategia adaptativa
      final downloadStopwatch = Stopwatch()..start();
      final downloadedData = await _downloadImageAdaptive(url);
      downloadStopwatch.stop();

      if (downloadedData != null) {
        stopwatch.stop();
        ImageCachePerformanceMetrics.instance
            .recordNetworkDownload(downloadStopwatch.elapsed);
        ImageCachePerformanceMetrics.instance.recordLoadTime(stopwatch.elapsed);
        await _saveToDiskCache(cacheKey, downloadedData);
        _addToMemoryCache(cacheKey, downloadedData);
        _logger.debug('🌐 Imagen descargada exitosamente: $url');
        return MemoryImage(downloadedData);
      }

      stopwatch.stop();
      ImageCachePerformanceMetrics.instance.recordFailedRequest();
      return null;
    } catch (e) {
      stopwatch.stop();
      ImageCachePerformanceMetrics.instance.recordFailedRequest();
      _logger.error('❌ Error obteniendo imagen $url: $e');
      _failedUrls.add(url);
      return null;
    }
  }

  /// Precarga una lista de imágenes en segundo plano
  Future<void> preloadImages(List<String> urls) async {
    if (urls.isEmpty) return;

    _logger.info('Precargando ${urls.length} imágenes');

    // Procesar en lotes para no sobrecargar la red
    const batchSize = 5;
    for (int i = 0; i < urls.length; i += batchSize) {
      final batch = urls.skip(i).take(batchSize).toList();

      await Future.wait(
        batch.map((url) => getCachedImage(url)),
        eagerError: false,
      );

      // Pequeña pausa entre lotes
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _logger.info('Precarga completada');
  }

  /// Limpia el caché expirado
  Future<void> cleanExpiredCache() async {
    await _cleanExpiredCache();
  }

  /// Limpia todo el caché
  Future<void> clearCache() async {
    try {
      // Limpiar caché en memoria
      _memoryCache.clear();
      _lruOrder.clear();
      _memoryCacheSize = 0;

      // Limpiar caché en disco
      if (_cacheDirectory != null &&
          (await _cacheDirectory?.exists() ?? false)) {
        final cacheDir = _cacheDirectory;
        if (cacheDir == null) return;
        await for (final file in cacheDir.list()) {
          if (file is File) {
            try {
              await file.delete();
            } catch (e) {
              _logger.warning('No se pudo eliminar archivo: ${file.path}');
            }
          }
        }
      }

      _logger.info('Caché limpiado completamente');
    } catch (e) {
      _logger.error('Error limpiando caché: $e');
    }
  }

  /// Obtiene estadísticas básicas del caché
  Future<CacheStats> getStats() async {
    int diskCacheSize = 0;
    int diskCacheFiles = 0;

    // Calcular tamaño del caché de disco
    if (_cacheDirectory != null && (await _cacheDirectory?.exists() ?? false)) {
      final cacheDir = _cacheDirectory;
      if (cacheDir != null) {
        await for (final file in cacheDir.list()) {
          if (file is File) {
            try {
              final stat = await file.stat();
              diskCacheSize += stat.size;
              diskCacheFiles++;
            } catch (e) {
              _logger.warning(
                  'No se pudo obtener estadísticas del archivo: ${file.path}');
            }
          }
        }
      }
    }

    return CacheStats(
      memoryCacheSize: _memoryCacheSize,
      memoryCacheEntries: _memoryCache.length,
      diskCacheSize: diskCacheSize,
      diskCacheFiles: diskCacheFiles,
      failedUrls: _failedUrls.length,
    );
  }

  /// Obtiene estadísticas del caché con métricas de rendimiento
  Future<EnhancedCacheStats> getEnhancedStats() async {
    final basicStats = await getStats();
    final performanceStats = ImageCachePerformanceMetrics.instance.getStats();
    final performanceAssessment =
        ImageCachePerformanceMetrics.instance.assessPerformance();
    final networkStatus = NetworkAwareStrategy.instance.getNetworkStatus();
    final deviceCapabilities = AdaptiveCacheConfig.instance.deviceCapabilities;

    return EnhancedCacheStats(
      // Estadísticas básicas
      memoryCacheSize: basicStats.memoryCacheSize,
      memoryCacheEntries: basicStats.memoryCacheEntries,
      diskCacheSize: basicStats.diskCacheSize,
      diskCacheFiles: basicStats.diskCacheFiles,
      failedUrls: basicStats.failedUrls,

      // Métricas de rendimiento
      performanceStats: performanceStats,
      performanceAssessment: performanceAssessment,

      // Estado de red
      networkCondition: NetworkAwareStrategy.instance.currentCondition,
      networkStatus: networkStatus,

      // Configuración del dispositivo
      deviceCapabilities: deviceCapabilities,

      // Configuración actual
      currentConfig: AdaptiveCacheConfig.instance.configuration,
    );
  }

  /// Genera reporte completo de rendimiento
  String generatePerformanceReport() {
    final buffer = StringBuffer();

    buffer.writeln('=== REPORTE COMPLETO DE RENDIMIENTO DEL CACHÉ ===');
    buffer.writeln('Timestamp: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    // Métricas de rendimiento
    buffer.writeln(ImageCachePerformanceMetrics.instance.generateReport());
    buffer.writeln();

    // Estado de red
    buffer.writeln('ESTADO DE RED:');
    final networkStatus = NetworkAwareStrategy.instance.getNetworkStatus();
    networkStatus.forEach((key, value) {
      buffer.writeln('  $key: $value');
    });
    buffer.writeln();

    // Configuración del dispositivo
    buffer.writeln('CONFIGURACIÓN DEL DISPOSITIVO:');
    final deviceCapabilities = AdaptiveCacheConfig.instance.deviceCapabilities;
    buffer.writeln('  $deviceCapabilities');
    buffer.writeln();

    // Configuración actual del caché
    buffer.writeln('CONFIGURACIÓN ACTUAL DEL CACHÉ:');
    final currentConfig = AdaptiveCacheConfig.instance.configuration;
    buffer.writeln('  $currentConfig');

    return buffer.toString();
  }

  /// Fuerza la re-evaluación de la configuración adaptativa
  Future<void> refreshAdaptiveConfiguration() async {
    _logger.info('🔄 Refrescando configuración adaptativa...');

    try {
      // Re-evaluar red
      await NetworkAwareStrategy.instance.refreshNetworkCondition();

      // Obtener nueva configuración
      final config = AdaptiveCacheConfig.instance.configuration;

      // Aplicar nuevos límites
      _maxMemoryCache = config.memoryCacheSize;
      _maxDiskCache = config.diskCacheSize;
      _maxConcurrentDownloads = config.maxConcurrentDownloads;
      _cacheExpiry = config.cacheExpiry;

      // Limpiar caché si excede nuevos límites
      await _enforceNewLimits();

      _logger.info('✅ Configuración adaptativa actualizada');
    } catch (e) {
      _logger.error('❌ Error refrescando configuración: $e');
    }
  }

  /// Aplica nuevos límites al caché existente
  Future<void> _enforceNewLimits() async {
    // Limpiar memoria si excede nuevo límite
    while (_memoryCacheSize > _maxMemoryCache && _lruOrder.isNotEmpty) {
      final oldestKey = _lruOrder.first;
      _removeFromMemoryCache(oldestKey);
    }

    // Verificar límite de disco (simplificado)
    final stats = await getStats();
    if (stats.diskCacheSize > _maxDiskCache) {
      _logger.info('💾 Disco excede límite, iniciando limpieza...');
      await _cleanOldestDiskFiles();
    }
  }

  /// Limpia archivos más antiguos del disco
  Future<void> _cleanOldestDiskFiles() async {
    if (_cacheDirectory == null) return;

    try {
      final files = <File>[];
      final cacheDir = _cacheDirectory;
      if (cacheDir == null) return;
      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          files.add(entity);
        }
      }

      // Ordenar por fecha de modificación (más antiguos primero)
      files.sort((a, b) {
        return a.statSync().modified.compareTo(b.statSync().modified);
      });

      // Eliminar hasta alcanzar límite
      int currentSize =
          files.fold(0, (sum, file) => sum + file.statSync().size);
      int deletedFiles = 0;

      for (final file in files) {
        if (currentSize <= _maxDiskCache) break;

        final fileSize = file.statSync().size;
        await file.delete();
        currentSize -= fileSize;
        deletedFiles++;
      }

      if (deletedFiles > 0) {
        _logger.info(
            '🧹 Eliminados $deletedFiles archivos antiguos del caché de disco');
      }
    } catch (e) {
      _logger.error('❌ Error limpiando archivos antiguos: $e');
    }
  }

  // Métodos privados

  String _generateCacheKey(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Uint8List? _getFromMemoryCache(String cacheKey) {
    final entry = _memoryCache[cacheKey];
    if (entry == null) return null;

    // Verificar expiración
    if (DateTime.now().isAfter(entry.expiryDate)) {
      _removeFromMemoryCache(cacheKey);
      return null;
    }

    // Actualizar orden LRU
    _lruOrder.remove(cacheKey);
    _lruOrder.add(cacheKey);

    return entry.data;
  }

  /// Verificar límite de memoria adaptativo
  void _addToMemoryCache(String cacheKey, Uint8List data) {
    // Verificar si ya existe
    if (_memoryCache.containsKey(cacheKey)) {
      _removeFromMemoryCache(cacheKey);
    }

    // Verificar límite de memoria adaptativo
    while (_memoryCacheSize + data.length > _maxMemoryCache &&
        _lruOrder.isNotEmpty) {
      final oldestKey = _lruOrder.first;
      _removeFromMemoryCache(oldestKey);
    }

    // Agregar nueva entrada
    final entry = _CacheEntry(
      data: data,
      expiryDate: DateTime.now().add(_cacheExpiry),
    );

    _memoryCache[cacheKey] = entry;
    _lruOrder.add(cacheKey);
    _memoryCacheSize += data.length;
  }

  void _removeFromMemoryCache(String cacheKey) {
    final entry = _memoryCache.remove(cacheKey);
    if (entry != null) {
      _memoryCacheSize -= entry.data.length;
    }
    _lruOrder.remove(cacheKey);
  }

  Future<Uint8List?> _getFromDiskCache(String cacheKey) async {
    if (_cacheDirectory == null) return null;

    try {
      final cacheDir = _cacheDirectory;
      if (cacheDir == null) return null;
      final file = File('${cacheDir.path}/$cacheKey');
      if (!await file.exists()) return null;

      // Verificar expiración con duración adaptativa
      final stat = await file.stat();
      final age = DateTime.now().difference(stat.modified);
      if (age > _cacheExpiry) {
        await file.delete();
        return null;
      }

      return await file.readAsBytes();
    } catch (e) {
      _logger.error('Error leyendo caché de disco $cacheKey: $e');
      return null;
    }
  }

  Future<void> _saveToDiskCache(String cacheKey, Uint8List data) async {
    if (_cacheDirectory == null) return;

    try {
      final cacheDir = _cacheDirectory;
      if (cacheDir == null) return;
      final file = File('${cacheDir.path}/$cacheKey');
      await file.writeAsBytes(data);
    } catch (e) {
      _logger.error('Error guardando en caché de disco $cacheKey: $e');
    }
  }

  /// Descarga imagen con estrategia adaptativa
  Future<Uint8List?> _downloadImageAdaptive(String url) async {
    // Obtener estrategia de red actual
    final strategy = NetworkAwareStrategy.instance.getDownloadStrategy();

    // Verificar si debemos descargar según las condiciones de red
    if (strategy.concurrentDownloads == 0) {
      _logger.debug('🚫 Red offline, no descargando: $url');
      return null;
    }

    // Verificar si ya hay una descarga en progreso
    if (_activeDownloads.containsKey(url)) {
      return await _activeDownloads[url];
    }

    // Limitar descargas concurrentes según estrategia
    if (_activeDownloads.length >= strategy.concurrentDownloads) {
      _logger.debug('⏳ Esperando slot de descarga para: $url');
      await Future.any(_activeDownloads.values);
    }

    // Iniciar descarga
    final downloadFuture = _performDownloadAdaptive(url, strategy);
    _activeDownloads[url] = downloadFuture;

    try {
      final result = await downloadFuture;
      return result;
    } finally {
      _activeDownloads.remove(url);
    }
  }

  /// Realiza la descarga con configuración adaptativa
  Future<Uint8List?> _performDownloadAdaptive(
      String url, DownloadStrategy strategy) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts <= strategy.retryAttempts) {
      try {
        _logger.debug('📡 Descargando imagen (intento ${attempts + 1}): $url');

        final response = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'PeliculasApp/1.0',
            'Accept': 'image/*',
            if (strategy.qualityPreference == ImageQuality.thumbnail)
              'Accept': 'image/webp,image/jpeg;q=0.8,image/png;q=0.6',
          },
        ).timeout(strategy.downloadTimeout);

        if (response.statusCode == 200) {
          final data = response.bodyBytes;
          _logger.debug('✅ Descarga exitosa: $url (${data.length} bytes)');
          return data;
        } else {
          throw HttpException(
              'HTTP ${response.statusCode}: ${response.reasonPhrase}');
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        attempts++;

        if (attempts <= strategy.retryAttempts) {
          _logger.warning(
              '⚠️ Reintentando descarga de $url en ${strategy.retryDelay.inSeconds}s (error: $e)');
          await Future.delayed(strategy.retryDelay);
        } else {
          _logger.error(
              '❌ Descarga fallida después de $attempts intentos: $url (error: $e)');
        }
      }
    }

    throw lastException ?? Exception('Download failed for unknown reason');
  }

  Future<void> _cleanExpiredCache() async {
    if (_cacheDirectory == null) return;

    try {
      final now = DateTime.now();
      int deletedFiles = 0;

      final cacheDir = _cacheDirectory;
      if (cacheDir == null) return;
      await for (final file in cacheDir.list()) {
        if (file is File) {
          final stat = await file.stat();
          final age = now.difference(stat.modified);

          if (age > _cacheExpiry) {
            await file.delete();
            deletedFiles++;
          }
        }
      }

      if (deletedFiles > 0) {
        _logger.info('Eliminados $deletedFiles archivos expirados del caché');
      }
    } catch (e) {
      _logger.error('Error limpiando caché expirado: $e');
    }
  }

  /// Libera recursos y limpia la memoria
  Future<void> dispose() async {
    try {
      _logger.info('🧹 Disposing ImageCacheManager...');

      // Limpiar caché en memoria
      _memoryCache.clear();
      _lruOrder.clear();
      _memoryCacheSize = 0;

      // Limpiar conjuntos de URLs fallidas
      _failedUrls.clear();

      // Cancelar descargas activas (se cancelarán automáticamente al limpiar referencias)
      _activeDownloads.clear();

      // Limpiar métricas de rendimiento
      ImageCachePerformanceMetrics.instance.dispose();

      _logger.info('✅ ImageCacheManager disposed successfully');
    } catch (e) {
      _logger.error('❌ Error disposing ImageCacheManager: $e');
    }
  }
}

/// Entrada del caché en memoria
class _CacheEntry {
  _CacheEntry({
    required this.data,
    required this.expiryDate,
  });
  final Uint8List data;
  final DateTime expiryDate;
}

/// Estadísticas del caché
class CacheStats {
  CacheStats({
    required this.memoryCacheSize,
    required this.memoryCacheEntries,
    required this.diskCacheSize,
    required this.diskCacheFiles,
    required this.failedUrls,
  });
  final int memoryCacheSize;
  final int memoryCacheEntries;
  final int diskCacheSize;
  final int diskCacheFiles;
  final int failedUrls;

  @override
  String toString() {
    return 'CacheStats(memory: ${(memoryCacheSize / 1024 / 1024).toStringAsFixed(1)}MB/$memoryCacheEntries, '
        'disk: ${(diskCacheSize / 1024 / 1024).toStringAsFixed(1)}MB/$diskCacheFiles, '
        'failed: $failedUrls)';
  }
}

/// Estadísticas mejoradas del caché con métricas de rendimiento
class EnhancedCacheStats {
  const EnhancedCacheStats({
    required this.memoryCacheSize,
    required this.memoryCacheEntries,
    required this.diskCacheSize,
    required this.diskCacheFiles,
    required this.failedUrls,
    required this.performanceStats,
    required this.performanceAssessment,
    required this.networkCondition,
    required this.networkStatus,
    required this.deviceCapabilities,
    required this.currentConfig,
  });

  // Estadísticas básicas
  final int memoryCacheSize;
  final int memoryCacheEntries;
  final int diskCacheSize;
  final int diskCacheFiles;
  final int failedUrls;

  // Métricas de rendimiento
  final PerformanceStats performanceStats;
  final PerformanceAssessment performanceAssessment;

  // Estado de red
  final NetworkCondition networkCondition;
  final Map<String, dynamic> networkStatus;

  // Configuración del dispositivo
  final DeviceCapabilities deviceCapabilities;

  // Configuración actual
  final CacheConfiguration currentConfig;

  @override
  String toString() {
    return 'EnhancedCacheStats('
        'memory: ${(memoryCacheSize / 1024 / 1024).toStringAsFixed(1)}MB/$memoryCacheEntries, '
        'disk: ${(diskCacheSize / 1024 / 1024).toStringAsFixed(1)}MB/$diskCacheFiles, '
        'network: $networkCondition, '
        'performance: ${performanceAssessment.healthStatus}, '
        'device: ${deviceCapabilities.performanceTier})';
  }
}

/// Widget optimizado para mostrar imágenes con caché
class CachedNetworkImageWidget extends StatefulWidget {
  const CachedNetworkImageWidget({
    super.key,
    required this.imageUrl,
    this.placeholder,
    this.errorWidget,
    this.fit,
    this.width,
    this.height,
    this.borderRadius,
  });
  final String imageUrl;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  State<CachedNetworkImageWidget> createState() =>
      _CachedNetworkImageWidgetState();
}

class _CachedNetworkImageWidgetState extends State<CachedNetworkImageWidget> {
  ImageProvider? _imageProvider;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(CachedNetworkImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final imageProvider =
          await ImageCacheManager.instance.getCachedImage(widget.imageUrl);

      if (!mounted) return;

      setState(() {
        _imageProvider = imageProvider;
        _isLoading = false;
        _hasError = imageProvider == null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (_isLoading) {
      child = widget.placeholder ??
          const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
    } else if (_hasError || _imageProvider == null) {
      child = widget.errorWidget ??
          Container(
            color: Colors.grey[300],
            child: const Center(
              child: Icon(
                Icons.broken_image,
                color: Colors.grey,
                size: 32,
              ),
            ),
          );
    } else {
      child = Image(
        image: _imageProvider!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
      );
    }

    if (widget.borderRadius != null) {
      child = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: child,
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: child,
    );
  }
}
