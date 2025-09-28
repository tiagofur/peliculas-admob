import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/cache/image_cache_manager.dart';
import '../core/logging/logger_factory.dart';
import '../core/utils/tmdb_image_utils.dart';

/// Servicio híbrido para gestión inteligente de imágenes
class HybridImageService {
  HybridImageService._();
  static HybridImageService? _instance;
  static HybridImageService get instance =>
      _instance ??= HybridImageService._();

  final _logger = LoggerFactory.logger;
  final _cacheManager = ImageCacheManager.instance;

  bool _isInitialized = false;

  /// Inicializa el servicio
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _cacheManager.initialize();
      _isInitialized = true;
      _logger.info('HybridImageService inicializado correctamente');
    } catch (e) {
      _logger.error('Error inicializando HybridImageService: $e');
    }
  }

  /// Normaliza rutas relativas (especialmente de TMDB) para asegurar URLs válidas.
  String normalizeImageUrl(String imageUrl, {String size = 'w500'}) {
    final trimmed = imageUrl.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:')) {
      return trimmed;
    }

    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }

    return resolveTmdbImageUrl(trimmed, size: size);
  }

  /// Obtiene un ImageProvider optimizado para la URL dada
  Future<ImageProvider> getOptimizedImageProvider(
    String imageUrl, {
    String size = 'w500',
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final normalizedUrl = normalizeImageUrl(imageUrl, size: size);

    if (normalizedUrl.isEmpty) {
      return const AssetImage('assets/images/no-image.jpg');
    }

    try {
      // Intentar obtener de caché
      final cachedProvider = await _cacheManager.getCachedImage(normalizedUrl);
      if (cachedProvider != null) {
        return cachedProvider;
      }

      // Fallback a NetworkImage con retry automático
      return NetworkImageWithRetry(normalizedUrl);
    } catch (e) {
      _logger.error('Error obteniendo imagen optimizada $normalizedUrl: $e');
      return const AssetImage('assets/images/no-image.jpg');
    }
  }

  /// Precarga imágenes populares basadas en el contexto
  Future<void> preloadPopularImages({
    List<String>? moviePosters,
    List<String>? personImages,
    List<String>? backdropImages,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final allUrls = <String>[
      ...?moviePosters,
      ...?personImages,
      ...?backdropImages,
    ];

    final normalizedUrls = allUrls
        .map((url) => normalizeImageUrl(url))
        .where((url) => url.isNotEmpty)
        .toList();

    if (normalizedUrls.isNotEmpty) {
      _logger.info('Precargando ${normalizedUrls.length} imágenes populares');
      await _cacheManager.preloadImages(normalizedUrls);
    }
  }

  /// Precarga imágenes de una película específica
  Future<void> preloadMovieImages({
    String? posterUrl,
    String? backdropUrl,
    List<String>? actorImages,
  }) async {
    final urls = <String>[
      if (posterUrl != null && posterUrl.isNotEmpty)
        normalizeImageUrl(posterUrl),
      if (backdropUrl != null && backdropUrl.isNotEmpty)
        normalizeImageUrl(backdropUrl, size: 'w780'),
      ...?actorImages
          ?.where((url) => url.isNotEmpty)
          .map((url) => normalizeImageUrl(url, size: 'w300')),
    ];

    final filteredUrls = urls.where((url) => url.isNotEmpty).toList();

    if (filteredUrls.isNotEmpty) {
      await _cacheManager.preloadImages(filteredUrls);
    }
  }

  /// Limpia caché expirado
  Future<void> cleanExpiredCache() async {
    await _cacheManager.cleanExpiredCache();
  }

  /// Obtiene estadísticas del caché
  Future<EnhancedCacheStats> getCacheStats() async {
    return await _cacheManager.getEnhancedStats();
  }

  /// Limpia todo el caché
  Future<void> clearAllCache() async {
    await _cacheManager.clearCache();
  }
}

/// NetworkImage con reintentos automáticos
class NetworkImageWithRetry extends ImageProvider<NetworkImageWithRetry> {
  const NetworkImageWithRetry(
    this.url, {
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
  });
  final String url;
  final int maxRetries;
  final Duration retryDelay;

  @override
  Future<NetworkImageWithRetry> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<NetworkImageWithRetry>(this);
  }

  @override
  ImageStreamCompleter loadImage(
      NetworkImageWithRetry key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(
      _loadImageAsync(key),
    );
  }

  Future<ImageInfo> _loadImageAsync(NetworkImageWithRetry key) async {
    final bytes = await _loadAsyncBytes(key);
    final image = await decodeImageFromList(bytes);
    return ImageInfo(image: image);
  }

  Future<Uint8List> _loadAsyncBytes(NetworkImageWithRetry key) async {
    Exception? lastException;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await http.get(Uri.parse(key.url));

        if (response.statusCode == 200) {
          return response.bodyBytes;
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());

        if (attempt < maxRetries) {
          await Future.delayed(retryDelay * (attempt + 1));
        }
      }
    }

    throw lastException ??
        Exception('Failed to load image after $maxRetries attempts');
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is NetworkImageWithRetry && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'NetworkImageWithRetry("$url")';
}

/// Widget helper para imágenes optimizadas
class OptimizedImage extends StatelessWidget {
  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.enableHeroAnimation = false,
    this.heroTag,
    this.tmdbSize = 'w500',
  });
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final bool enableHeroAnimation;
  final String? heroTag;
  final String tmdbSize;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl =
        HybridImageService.instance.normalizeImageUrl(imageUrl, size: tmdbSize);

    if (normalizedUrl.isEmpty) {
      return errorWidget ?? _buildDefaultErrorWidget();
    }

    Widget imageWidget = CachedNetworkImageWidget(
      imageUrl: normalizedUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      placeholder: placeholder ?? _buildDefaultPlaceholder(),
      errorWidget: errorWidget ?? _buildDefaultErrorWidget(),
    );

    if (enableHeroAnimation && heroTag != null) {
      imageWidget = Hero(
        tag: heroTag!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(Colors.grey),
        ),
      ),
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }
}

/// Extensión para facilitar el uso del servicio
extension ImageUrlExtension on String {
  /// Convierte una URL en un ImageProvider optimizado
  Future<ImageProvider> toOptimizedImageProvider({String size = 'w500'}) async {
    return await HybridImageService.instance
        .getOptimizedImageProvider(this, size: size);
  }

  /// Crea un widget OptimizedImage
  Widget toOptimizedImage({
    double? width,
    double? height,
    BoxFit? fit,
    Widget? placeholder,
    Widget? errorWidget,
    BorderRadius? borderRadius,
    bool enableHeroAnimation = false,
    String? heroTag,
    String tmdbSize = 'w500',
  }) {
    return OptimizedImage(
      imageUrl: this,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder,
      errorWidget: errorWidget,
      borderRadius: borderRadius,
      enableHeroAnimation: enableHeroAnimation,
      heroTag: heroTag,
      tmdbSize: tmdbSize,
    );
  }
}

/// Mixin para widgets que necesitan precargar imágenes
mixin ImagePreloadMixin<T extends StatefulWidget> on State<T> {
  final _cacheManager = ImageCacheManager.instance;

  /// Precarga una lista de URLs de imágenes
  Future<void> preloadImages(List<String> imageUrls) async {
    for (final url in imageUrls) {
      try {
        final normalizedUrl =
            HybridImageService.instance.normalizeImageUrl(url);
        if (normalizedUrl.isEmpty) continue;
        await _cacheManager.getCachedImage(normalizedUrl);
      } catch (e) {
        // Ignorar errores de precarga
      }
    }
  }

  /// Precarga imágenes de película
  Future<void> preloadMovieImages({
    String? posterUrl,
    String? backdropUrl,
    List<String>? actorImages,
  }) async {
    final urls = <String>[];
    if (posterUrl != null) {
      urls.add(HybridImageService.instance.normalizeImageUrl(posterUrl));
    }
    if (backdropUrl != null) {
      urls.add(HybridImageService.instance
          .normalizeImageUrl(backdropUrl, size: 'w780'));
    }
    if (actorImages != null) {
      urls.addAll(actorImages.map((url) =>
          HybridImageService.instance.normalizeImageUrl(url, size: 'w300')));
    }

    await preloadImages(urls);
  }
}
