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

/// Gestor avanzado de caché de imágenes con estrategias inteligentes
class ImageCacheManager {
  ImageCacheManager._();
  static ImageCacheManager? _instance;
  static ImageCacheManager get instance => _instance ??= ImageCacheManager._();

  static const int maxMemoryCache = 100 * 1024 * 1024; // 100MB
  static const int maxDiskCache = 500 * 1024 * 1024; // 500MB
  static const Duration cacheExpiry = Duration(days: 7);
  static const int maxConcurrentDownloads = 3;
  static const Duration downloadTimeout = Duration(seconds: 30);

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

  /// Inicializa el gestor de caché
  Future<void> initialize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDirectory = Directory('${appDir.path}/image_cache');

      if (!await _cacheDirectory!.exists()) {
        await _cacheDirectory!.create(recursive: true);
      }

      // Limpiar caché expirado al inicializar
      await _cleanExpiredCache();

      _logger.info('ImageCacheManager inicializado correctamente');
    } catch (e) {
      _logger.error('Error inicializando ImageCacheManager: $e');
    }
  }

  /// Obtiene una imagen del caché o la descarga
  Future<ImageProvider?> getCachedImage(String url) async {
    if (url.isEmpty) return null;

    try {
      // Verificar si la URL ha fallado recientemente
      if (_failedUrls.contains(url)) {
        return null;
      }

      final cacheKey = _generateCacheKey(url);

      // 1. Verificar caché en memoria
      final memoryEntry = _getFromMemoryCache(cacheKey);
      if (memoryEntry != null) {
        _logger.debug('Imagen encontrada en caché de memoria: $url');
        return MemoryImage(memoryEntry);
      }

      // 2. Verificar caché en disco
      final diskData = await _getFromDiskCache(cacheKey);
      if (diskData != null) {
        _logger.debug('Imagen encontrada en caché de disco: $url');
        _addToMemoryCache(cacheKey, diskData);
        return MemoryImage(diskData);
      }

      // 3. Descargar imagen
      final downloadedData = await _downloadImage(url);
      if (downloadedData != null) {
        _logger.debug('Imagen descargada exitosamente: $url');
        await _saveToDiskCache(cacheKey, downloadedData);
        _addToMemoryCache(cacheKey, downloadedData);
        return MemoryImage(downloadedData);
      }

      return null;
    } catch (e) {
      _logger.error('Error obteniendo imagen $url: $e');
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
      if (_cacheDirectory != null && await _cacheDirectory!.exists()) {
        await for (final file in _cacheDirectory!.list()) {
          if (file is File) {
            await file.delete();
          }
        }
      }

      _logger.info('Caché limpiado completamente');
    } catch (e) {
      _logger.error('Error limpiando caché: $e');
    }
  }

  /// Obtiene estadísticas del caché
  Future<CacheStats> getStats() async {
    int diskCacheSize = 0;
    int diskCacheFiles = 0;

    if (_cacheDirectory != null && await _cacheDirectory!.exists()) {
      await for (final file in _cacheDirectory!.list()) {
        if (file is File) {
          diskCacheFiles++;
          final stat = await file.stat();
          diskCacheSize += stat.size;
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

  void _addToMemoryCache(String cacheKey, Uint8List data) {
    // Verificar si ya existe
    if (_memoryCache.containsKey(cacheKey)) {
      _removeFromMemoryCache(cacheKey);
    }

    // Verificar límite de memoria
    while (_memoryCacheSize + data.length > maxMemoryCache &&
        _lruOrder.isNotEmpty) {
      final oldestKey = _lruOrder.first;
      _removeFromMemoryCache(oldestKey);
    }

    // Agregar nueva entrada
    final entry = _CacheEntry(
      data: data,
      expiryDate: DateTime.now().add(cacheExpiry),
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
      final file = File('${_cacheDirectory!.path}/$cacheKey');
      if (!await file.exists()) return null;

      // Verificar expiración
      final stat = await file.stat();
      final age = DateTime.now().difference(stat.modified);
      if (age > cacheExpiry) {
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
      final file = File('${_cacheDirectory!.path}/$cacheKey');
      await file.writeAsBytes(data);
    } catch (e) {
      _logger.error('Error guardando en caché de disco $cacheKey: $e');
    }
  }

  Future<Uint8List?> _downloadImage(String url) async {
    // Verificar si ya hay una descarga en progreso
    if (_activeDownloads.containsKey(url)) {
      return await _activeDownloads[url];
    }

    // Limitar descargas concurrentes
    if (_activeDownloads.length >= maxConcurrentDownloads) {
      await Future.any(_activeDownloads.values);
    }

    // Iniciar descarga
    final downloadFuture = _performDownload(url);
    _activeDownloads[url] = downloadFuture;

    try {
      final result = await downloadFuture;
      return result;
    } finally {
      _activeDownloads.remove(url);
    }
  }

  Future<Uint8List?> _performDownload(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'PeliculasApp/1.0',
        },
      ).timeout(downloadTimeout);

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        _logger.warning('Error HTTP ${response.statusCode} descargando $url');
        return null;
      }
    } catch (e) {
      _logger.error('Error descargando imagen $url: $e');
      return null;
    }
  }

  Future<void> _cleanExpiredCache() async {
    if (_cacheDirectory == null) return;

    try {
      final now = DateTime.now();
      int deletedFiles = 0;

      await for (final file in _cacheDirectory!.list()) {
        if (file is File) {
          final stat = await file.stat();
          final age = now.difference(stat.modified);

          if (age > cacheExpiry) {
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
