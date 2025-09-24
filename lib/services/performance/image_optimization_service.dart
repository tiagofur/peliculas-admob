import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'advanced_cache_manager.dart';

/// Servicio para optimización de imágenes con lazy loading y cache inteligente
class ImageOptimizationService {
  ImageOptimizationService._();
  static ImageOptimizationService? _instance;

  static ImageOptimizationService get instance {
    _instance ??= ImageOptimizationService._();
    return _instance!;
  }

  /// Widget optimizado para posters de películas
  Widget buildOptimizedPoster({
    required String? imageUrl,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    bool enableMemoryCache = true,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return errorWidget ?? _buildDefaultPosterPlaceholder(width, height);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      cacheManager: AdvancedCacheManager.moviePosters,
      memCacheWidth: enableMemoryCache ? width.toInt() : null,
      memCacheHeight: enableMemoryCache ? height.toInt() : null,
      placeholder: (context, url) =>
          placeholder ?? _buildLoadingPlaceholder(width, height),
      errorWidget: (context, url, error) =>
          errorWidget ?? _buildErrorPlaceholder(width, height),
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
    );
  }

  /// Widget optimizado para avatares de usuario
  Widget buildOptimizedAvatar({
    required String? imageUrl,
    required double radius,
    Widget? placeholder,
    Widget? child,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        child: child ?? const Icon(Icons.person),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: AdvancedCacheManager.userData,
      memCacheWidth: (radius * 2).toInt(),
      memCacheHeight: (radius * 2).toInt(),
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundImage: imageProvider,
      ),
      placeholder: (context, url) => CircleAvatar(
        radius: radius,
        child: placeholder ?? const CircularProgressIndicator(strokeWidth: 2),
      ),
      errorWidget: (context, url, error) => CircleAvatar(
        radius: radius,
        child: child ?? const Icon(Icons.person),
      ),
    );
  }

  /// Lista optimizada con lazy loading para películas
  Widget buildOptimizedMovieList({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    ScrollController? scrollController,
    EdgeInsetsGeometry? padding,
    bool shrinkWrap = false,
  }) {
    return ListView.builder(
      controller: scrollController,
      padding: padding,
      shrinkWrap: shrinkWrap,
      itemCount: itemCount,
      // Configuración de optimización
      cacheExtent: 1000.0, // Pre-cache items fuera de la vista
      physics: const BouncingScrollPhysics(), // Suavizar scroll
      itemBuilder: (context, index) {
        // Wrapper para lazy loading
        return _LazyLoadWrapper(
          key: ValueKey('movie_item_$index'),
          child: itemBuilder(context, index),
        );
      },
    );
  }

  /// Grid optimizado para películas
  Widget buildOptimizedMovieGrid({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    int crossAxisCount = 2,
    double childAspectRatio = 0.7,
    EdgeInsetsGeometry? padding,
    ScrollController? scrollController,
  }) {
    return GridView.builder(
      controller: scrollController,
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: itemCount,
      cacheExtent: 1500.0, // Más cache para grids
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        return _LazyLoadWrapper(
          key: ValueKey('movie_grid_item_$index'),
          child: itemBuilder(context, index),
        );
      },
    );
  }

  /// Pre-carga imágenes importantes
  Future<void> preloadImportantImages(List<String> imageUrls) async {
    final futures = imageUrls.take(10).map((url) async {
      try {
        await AdvancedCacheManager.moviePosters.getSingleFile(url);
      } catch (e) {
        // Ignorar errores de pre-carga
        debugPrint('Error preloading image $url: $e');
      }
    });

    await Future.wait(futures);
  }

  /// Limpia cache de imágenes si es necesario
  Future<void> clearImageCache() async {
    await AdvancedCacheManager.clearExpiredCaches();
  }

  // Widgets internos de placeholder
  Widget _buildDefaultPosterPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.movie,
        color: Colors.grey,
        size: 40,
      ),
    );
  }

  Widget _buildLoadingPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildErrorPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, color: Colors.grey, size: 30),
          SizedBox(height: 4),
          Text(
            'Error',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Widget wrapper para lazy loading
class _LazyLoadWrapper extends StatefulWidget {
  const _LazyLoadWrapper({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  State<_LazyLoadWrapper> createState() => _LazyLoadWrapperState();
}

class _LazyLoadWrapperState extends State<_LazyLoadWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
