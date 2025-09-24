import 'package:flutter/material.dart';

import '../../../core/cache/image_cache_manager.dart';
import '../../../core/logging/logger_factory.dart';

/// Widget optimizado para imágenes con cache mejorado y manejo de memoria
///
/// ✅ PERFORMANCE OPTIMIZATION:
/// - Uses adaptive image cache manager
/// - Implements proper lifecycle management
/// - Reduces memory leaks from image loading
/// - Provides loading and error states
class OptimizedCachedImage extends StatefulWidget {
  const OptimizedCachedImage({
    super.key,
    required this.imageUrl,
    this.placeholder,
    this.errorWidget,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.alignment = Alignment.center,
    this.memoryOptimized = true,
  });

  final String imageUrl;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Duration fadeInDuration;
  final Alignment alignment;
  final bool memoryOptimized;

  @override
  State<OptimizedCachedImage> createState() => _OptimizedCachedImageState();
}

class _OptimizedCachedImageState extends State<OptimizedCachedImage>
    with SingleTickerProviderStateMixin {
  ImageProvider? _imageProvider;
  bool _isLoading = true;
  bool _hasError = false;
  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _loadImage();
  }

  @override
  void didUpdateWidget(OptimizedCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resetState();
      _loadImage();
    }
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    super.dispose();
  }

  void _initializeAnimation() {
    _fadeController = AnimationController(
      duration: widget.fadeInDuration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController!, curve: Curves.easeInOut),
    );
  }

  void _resetState() {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _imageProvider = null;
      });
      _fadeController?.reset();
    }
  }

  Future<void> _loadImage() async {
    if (!mounted || widget.imageUrl.isEmpty) return;

    try {
      LoggerFactory.debug('🖼️ Loading optimized image: ${widget.imageUrl}');

      final imageProvider =
          await ImageCacheManager.instance.getCachedImage(widget.imageUrl);

      if (!mounted) return;

      setState(() {
        _imageProvider = imageProvider;
        _isLoading = false;
        _hasError = imageProvider == null;
      });

      // Start fade-in animation if image loaded successfully
      if (imageProvider != null && _fadeController != null) {
        _fadeController!.forward();
      }

      if (imageProvider != null) {
        LoggerFactory.debug(
            '✅ Optimized image loaded successfully: ${widget.imageUrl}');
      } else {
        LoggerFactory.warning(
            '⚠️ Failed to load optimized image: ${widget.imageUrl}');
      }
    } catch (e) {
      LoggerFactory.error(
          '❌ Error loading optimized image: ${widget.imageUrl} - $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Widget _buildPlaceholder() {
    return widget.placeholder ??
        Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[100],
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
            ),
          ),
        );
  }

  Widget _buildErrorWidget() {
    return widget.errorWidget ??
        Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[200],
          child: const Center(
            child: Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 32,
            ),
          ),
        );
  }

  Widget _buildImage() {
    if (_imageProvider == null) return _buildErrorWidget();

    Widget image = Image(
      image: _imageProvider!,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      alignment: widget.alignment,
      // Memory optimization: don't cache images that are too large
      filterQuality:
          widget.memoryOptimized ? FilterQuality.medium : FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        LoggerFactory.error('❌ Image provider error: $error');
        return _buildErrorWidget();
      },
    );

    // Add fade-in animation if available
    if (_fadeAnimation != null) {
      image = FadeTransition(
        opacity: _fadeAnimation!,
        child: image,
      );
    }

    return image;
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (_isLoading) {
      child = _buildPlaceholder();
    } else if (_hasError || _imageProvider == null) {
      child = _buildErrorWidget();
    } else {
      child = _buildImage();
    }

    // Apply border radius if provided
    if (widget.borderRadius != null) {
      child = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: child,
      );
    }

    // Wrap in SizedBox for consistent sizing
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: child,
    );
  }
}

/// Optimized variant for movie posters with predefined sizing
class OptimizedMoviePosterImage extends StatelessWidget {
  const OptimizedMoviePosterImage({
    super.key,
    required this.imageUrl,
    this.width = 150,
    this.height = 225,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  final String imageUrl;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return OptimizedCachedImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      borderRadius: borderRadius,
      fit: BoxFit.cover,
      memoryOptimized: true,
      placeholder: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: borderRadius,
        ),
        child: const Center(
          child: Icon(
            Icons.movie,
            color: Colors.grey,
            size: 40,
          ),
        ),
      ),
      errorWidget: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: borderRadius,
        ),
        child: const Center(
          child: Icon(
            Icons.broken_image,
            color: Colors.grey,
            size: 40,
          ),
        ),
      ),
    );
  }
}

/// Performance metrics for image loading
class ImageLoadingMetrics {
  static final Map<String, DateTime> _loadStartTimes = {};
  static final List<Duration> _loadTimes = [];

  static void recordLoadStart(String url) {
    _loadStartTimes[url] = DateTime.now();
  }

  static void recordLoadComplete(String url) {
    final startTime = _loadStartTimes.remove(url);
    if (startTime != null) {
      final loadTime = DateTime.now().difference(startTime);
      _loadTimes.add(loadTime);

      // Keep only last 100 measurements
      if (_loadTimes.length > 100) {
        _loadTimes.removeRange(0, _loadTimes.length - 100);
      }

      LoggerFactory.debug(
          '📊 Image load time: ${loadTime.inMilliseconds}ms for $url');
    }
  }

  static double get averageLoadTimeMs {
    if (_loadTimes.isEmpty) return 0.0;
    final totalMs =
        _loadTimes.fold(0, (sum, duration) => sum + duration.inMilliseconds);
    return totalMs / _loadTimes.length;
  }

  static int get activeTasks => _loadStartTimes.length;
}
