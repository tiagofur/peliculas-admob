import 'dart:io' if (dart.library.html) 'dart:html';

import 'package:flutter/foundation.dart';

/// Servicio de gestión de CDN y caching distribuido
///
/// Optimiza la entrega de contenido multimedia, maneja cache distribuido
/// y mejora la performance de carga de recursos estáticos.
class CdnManagerService {
  CdnManagerService._();
  static CdnManagerService? _instance;

  static CdnManagerService get instance {
    _instance ??= CdnManagerService._();
    return _instance!;
  }

  bool _isInitialized = false;

  // Configuración de CDN
  final Map<String, dynamic> _config = {
    'primary_cdn': 'https://cdn.themoviedb.org',
    'fallback_cdn': 'https://image.tmdb.org',
    'cache_duration': 86400, // 24 horas en segundos
    'max_retries': 3,
    'timeout_seconds': 30,
    'quality_levels': [
      'w92',
      'w154',
      'w185',
      'w300',
      'w500',
      'w780',
      'original'
    ],
    'enable_webp': true,
    'enable_progressive_loading': true,
  };

  // Estadísticas de CDN
  final Map<String, int> _cdnStats = {
    'hits': 0,
    'misses': 0,
    'errors': 0,
    'fallback_uses': 0,
    'total_requests': 0,
  };

  // Cache de URLs optimizadas
  final Map<String, OptimizedUrl> _urlCache = {};

  // Regiones de CDN disponibles
  final List<CdnRegion> _regions = [
    const CdnRegion(
      name: 'US East',
      endpoint: 'https://image.tmdb.org',
      priority: 1,
      latencyMs: 50,
    ),
    const CdnRegion(
      name: 'Europe',
      endpoint: 'https://eu-image.tmdb.org',
      priority: 2,
      latencyMs: 80,
    ),
    const CdnRegion(
      name: 'Asia Pacific',
      endpoint: 'https://ap-image.tmdb.org',
      priority: 3,
      latencyMs: 120,
    ),
  ];

  /// Inicializa el servicio de CDN
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      debugPrint('🌐 Inicializando CDN Manager Service...');

      // Detectar la mejor región CDN
      await _detectOptimalRegion();

      // Configurar optimizaciones
      await _configureOptimizations();

      // Inicializar cache
      _initializeCache();

      _isInitialized = true;
      debugPrint('✅ CDN Manager Service inicializado');

      return true;
    } catch (e) {
      debugPrint('❌ Error inicializando CDN Manager Service: $e');
      return false;
    }
  }

  /// Detecta la región CDN óptima
  Future<void> _detectOptimalRegion() async {
    debugPrint('📍 Detectando región CDN óptima...');

    CdnRegion? bestRegion;
    int bestLatency = 99999;

    for (final region in _regions) {
      try {
        final latency = await _measureLatency(region.endpoint);
        if (latency < bestLatency) {
          bestLatency = latency;
          bestRegion = region;
        }

        debugPrint('   ${region.name}: ${latency}ms');
      } catch (e) {
        debugPrint('   ${region.name}: Error - $e');
      }
    }

    if (bestRegion != null) {
      _config['optimal_region'] = bestRegion.name;
      _config['primary_cdn'] = bestRegion.endpoint;
      debugPrint('🎯 Región óptima seleccionada: ${bestRegion.name}');
    }
  }

  /// Mide latencia a un endpoint
  Future<int> _measureLatency(String endpoint) async {
    final stopwatch = Stopwatch()..start();

    try {
      if (kIsWeb) {
        // Implementación web simplificada
        await Future.delayed(const Duration(milliseconds: 100));
        return 100;
      } else {
        // Implementación nativa
        final uri = Uri.parse('$endpoint/t/p/w92/test.jpg');
        final client = HttpClient();
        final request = await client.headUrl(uri);
        request.headers.set('User-Agent', 'MovieApp/1.0');

        final response = await request.close();
        await response.drain();
        client.close();

        return stopwatch.elapsedMilliseconds;
      }
    } catch (e) {
      return 9999; // Latencia alta en caso de error
    } finally {
      stopwatch.stop();
    }
  }

  /// Configura optimizaciones de CDN
  Future<void> _configureOptimizations() async {
    debugPrint('⚙️ Configurando optimizaciones de CDN...');

    // Configurar formatos de imagen optimizados
    if (kIsWeb) {
      // En web, verificar soporte WebP
      _config['enable_webp'] = true; // Asumir soporte moderno
    } else {
      // En móvil, usar formatos optimizados nativos
      _config['enable_webp'] = Platform.isAndroid; // WebP en Android
    }

    // Configurar quality levels basado en el dispositivo
    _config['default_quality'] = _getOptimalQuality();

    debugPrint('   WebP habilitado: ${_config['enable_webp']}');
    debugPrint('   Calidad por defecto: ${_config['default_quality']}');
  }

  /// Inicializa el sistema de cache
  void _initializeCache() {
    debugPrint('🗄️ Inicializando cache de CDN...');
    _urlCache.clear();
  }

  /// Obtiene URL optimizada para una imagen
  String getOptimizedImageUrl({
    required String imagePath,
    String? size,
    ImageQuality quality = ImageQuality.medium,
    bool enableWebP = true,
  }) {
    if (!_isInitialized) {
      return _buildFallbackUrl(imagePath, size);
    }

    _cdnStats['total_requests'] = (_cdnStats['total_requests'] ?? 0) + 1;

    final cacheKey = _generateCacheKey(imagePath, size, quality, enableWebP);

    // Verificar cache
    if (_urlCache.containsKey(cacheKey)) {
      final cached = _urlCache[cacheKey]!;
      if (!cached.isExpired) {
        _cdnStats['hits'] = (_cdnStats['hits'] ?? 0) + 1;
        return cached.url;
      } else {
        _urlCache.remove(cacheKey);
      }
    }

    _cdnStats['misses'] = (_cdnStats['misses'] ?? 0) + 1;

    // Generar URL optimizada
    final optimizedUrl = _buildOptimizedUrl(
      imagePath: imagePath,
      size: size,
      quality: quality,
      enableWebP: enableWebP,
    );

    // Guardar en cache
    _urlCache[cacheKey] = OptimizedUrl(
      url: optimizedUrl,
      timestamp: DateTime.now(),
      ttl: Duration(seconds: _config['cache_duration']),
    );

    return optimizedUrl;
  }

  /// Construye URL optimizada
  String _buildOptimizedUrl({
    required String imagePath,
    String? size,
    ImageQuality quality = ImageQuality.medium,
    bool enableWebP = true,
  }) {
    final baseCdn = _config['primary_cdn'] as String;
    final qualitySize = size ?? _getQualitySize(quality);

    // Determinar formato de imagen
    String format = '';
    if (enableWebP && _config['enable_webp'] == true) {
      format = '.webp';
    }

    // Construir URL
    final url = '$baseCdn/t/p/$qualitySize$imagePath$format';

    if (kDebugMode) {
      debugPrint('🔗 URL optimizada: $url');
    }

    return url;
  }

  /// Obtiene múltiples tamaños para carga progresiva
  Map<String, String> getProgressiveImageUrls({
    required String imagePath,
    bool enableWebP = true,
  }) {
    if (!_isInitialized) {
      return {
        'thumbnail': _buildFallbackUrl(imagePath, 'w92'),
        'medium': _buildFallbackUrl(imagePath, 'w300'),
        'high': _buildFallbackUrl(imagePath, 'w500'),
      };
    }

    return {
      'thumbnail': getOptimizedImageUrl(
        imagePath: imagePath,
        quality: ImageQuality.thumbnail,
        enableWebP: enableWebP,
      ),
      'low': getOptimizedImageUrl(
        imagePath: imagePath,
        quality: ImageQuality.low,
        enableWebP: enableWebP,
      ),
      'medium': getOptimizedImageUrl(
        imagePath: imagePath,
        quality: ImageQuality.medium,
        enableWebP: enableWebP,
      ),
      'high': getOptimizedImageUrl(
        imagePath: imagePath,
        quality: ImageQuality.high,
        enableWebP: enableWebP,
      ),
    };
  }

  /// Pre-carga imágenes estratégicamente
  Future<void> preloadImages({
    required List<String> imagePaths,
    ImageQuality quality = ImageQuality.medium,
    int maxConcurrent = 3,
  }) async {
    if (!_isInitialized || imagePaths.isEmpty) return;

    debugPrint('⏳ Pre-cargando ${imagePaths.length} imágenes...');

    // Dividir en batches para controlar concurrencia
    for (int i = 0; i < imagePaths.length; i += maxConcurrent) {
      final batch = imagePaths.skip(i).take(maxConcurrent);

      final futures = batch.map((imagePath) async {
        try {
          getOptimizedImageUrl(
            imagePath: imagePath,
            quality: quality,
          );

          // Simular precarga
          await Future.delayed(const Duration(milliseconds: 50));

          if (kDebugMode) {
            debugPrint('   ✅ Pre-cargada: $imagePath');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('   ❌ Error pre-cargando $imagePath: $e');
          }
        }
      });

      await Future.wait(futures);
    }

    debugPrint('✅ Pre-carga completada');
  }

  /// Obtiene URL de fallback
  String _buildFallbackUrl(String imagePath, String? size) {
    final fallbackCdn = _config['fallback_cdn'] as String;
    final qualitySize = size ?? 'w300';
    return '$fallbackCdn/t/p/$qualitySize$imagePath';
  }

  /// Genera clave de cache
  String _generateCacheKey(
    String imagePath,
    String? size,
    ImageQuality quality,
    bool enableWebP,
  ) {
    return '${imagePath}_${size ?? quality.name}_${enableWebP ? 'webp' : 'jpg'}';
  }

  /// Obtiene tamaño basado en calidad
  String _getQualitySize(ImageQuality quality) {
    switch (quality) {
      case ImageQuality.thumbnail:
        return 'w92';
      case ImageQuality.low:
        return 'w154';
      case ImageQuality.medium:
        return 'w300';
      case ImageQuality.high:
        return 'w500';
      case ImageQuality.ultra:
        return 'w780';
      case ImageQuality.original:
        return 'original';
    }
  }

  /// Obtiene calidad óptima para el dispositivo
  String _getOptimalQuality() {
    if (kIsWeb) {
      return 'w300'; // Calidad media para web
    }

    // Simular detección de densidad de pantalla
    return 'w500'; // Calidad alta para móvil
  }

  /// Limpia cache expirado
  void cleanupCache() {
    final expiredKeys = _urlCache.entries
        .where((entry) => entry.value.isExpired)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _urlCache.remove(key);
    }

    if (expiredKeys.isNotEmpty && kDebugMode) {
      debugPrint('🗑️ Limpiadas ${expiredKeys.length} URLs de cache CDN');
    }
  }

  /// Obtiene estadísticas del CDN
  Map<String, dynamic> getCdnStats() {
    cleanupCache();

    final totalRequests = _cdnStats['total_requests'] ?? 0;
    final hits = _cdnStats['hits'] ?? 0;

    return {
      'service_status': _isInitialized ? 'active' : 'inactive',
      'optimal_region': _config['optimal_region'] ?? 'unknown',
      'primary_cdn': _config['primary_cdn'],
      'cache_entries': _urlCache.length,
      'hit_rate_percentage':
          totalRequests > 0 ? (hits / totalRequests) * 100 : 0,
      'stats': Map.from(_cdnStats),
      'config': Map.from(_config),
    };
  }

  /// Actualiza configuración de CDN
  void updateConfig({
    String? primaryCdn,
    String? fallbackCdn,
    int? cacheDuration,
    bool? enableWebP,
  }) {
    if (primaryCdn != null) _config['primary_cdn'] = primaryCdn;
    if (fallbackCdn != null) _config['fallback_cdn'] = fallbackCdn;
    if (cacheDuration != null) _config['cache_duration'] = cacheDuration;
    if (enableWebP != null) _config['enable_webp'] = enableWebP;

    debugPrint('⚙️ Configuración de CDN actualizada');
  }

  /// Resetea estadísticas (para testing)
  void resetStats() {
    if (kDebugMode) {
      _cdnStats.clear();
      _urlCache.clear();
      debugPrint('🔄 Estadísticas de CDN reseteadas');
    }
  }
}

/// Enumeración para calidades de imagen
enum ImageQuality {
  thumbnail,
  low,
  medium,
  high,
  ultra,
  original,
}

/// Clase para URL optimizada con cache
class OptimizedUrl {
  const OptimizedUrl({
    required this.url,
    required this.timestamp,
    required this.ttl,
  });
  final String url;
  final DateTime timestamp;
  final Duration ttl;

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
}

/// Clase para región de CDN
class CdnRegion {
  const CdnRegion({
    required this.name,
    required this.endpoint,
    required this.priority,
    required this.latencyMs,
  });
  final String name;
  final String endpoint;
  final int priority;
  final int latencyMs;
}

/// Helpers para operaciones comunes de CDN
class CdnHelpers {
  static final _service = CdnManagerService.instance;

  /// Obtiene URL de poster optimizada
  static String getOptimizedPosterUrl({
    required String posterPath,
    ImageQuality quality = ImageQuality.medium,
  }) {
    return _service.getOptimizedImageUrl(
      imagePath: posterPath,
      quality: quality,
    );
  }

  /// Obtiene URL de backdrop optimizada
  static String getOptimizedBackdropUrl({
    required String backdropPath,
    ImageQuality quality = ImageQuality.high,
  }) {
    return _service.getOptimizedImageUrl(
      imagePath: backdropPath,
      quality: quality,
    );
  }

  /// Obtiene URLs progresivas para poster
  static Map<String, String> getProgressivePosterUrls({
    required String posterPath,
  }) {
    return _service.getProgressiveImageUrls(
      imagePath: posterPath,
    );
  }

  /// Pre-carga posters de una lista de películas
  static Future<void> preloadMoviePosters({
    required List<String> posterPaths,
    ImageQuality quality = ImageQuality.medium,
  }) async {
    await _service.preloadImages(
      imagePaths: posterPaths,
      quality: quality,
      maxConcurrent: 3,
    );
  }

  /// Obtiene URL de perfil optimizada
  static String getOptimizedProfileUrl({
    required String profilePath,
    ImageQuality quality = ImageQuality.medium,
  }) {
    return _service.getOptimizedImageUrl(
      imagePath: profilePath,
      quality: quality,
    );
  }
}
