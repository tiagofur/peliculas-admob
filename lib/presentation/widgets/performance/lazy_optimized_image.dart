import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../services/hybrid_image_service.dart';

/// Widget de imagen con lazy loading inteligente y optimizaciones de memoria
class LazyOptimizedImage extends StatefulWidget {
  const LazyOptimizedImage({
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
    this.loadingIndicator,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.enableMemoryOptimization = true,
    this.cacheWidth,
    this.cacheHeight,
    this.loadOnlyWhenVisible = true,
    this.visibilityThreshold = 0.1,
    this.tmdbSize = 'w500',
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final bool enableHeroAnimation;
  final String? heroTag;
  final Widget? loadingIndicator;
  final Duration fadeInDuration;
  final bool enableMemoryOptimization;
  final int? cacheWidth;
  final int? cacheHeight;
  final bool loadOnlyWhenVisible;
  final double visibilityThreshold;
  final String tmdbSize;

  @override
  State<LazyOptimizedImage> createState() => _LazyOptimizedImageState();
}

class _LazyOptimizedImageState extends State<LazyOptimizedImage>
    with SingleTickerProviderStateMixin {
  final _logger = LoggerFactory.logger;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  ImageProvider? _imageProvider;
  bool _isLoading = false;
  bool _hasError = false;
  bool _isVisible = false;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.fadeInDuration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    if (!widget.loadOnlyWhenVisible) {
      _loadImage();
    }
  }

  @override
  void didUpdateWidget(LazyOptimizedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resetState();
      if (_isVisible || !widget.loadOnlyWhenVisible) {
        _loadImage();
      }
    }
  }

  void _resetState() {
    _imageProvider = null;
    _isLoading = false;
    _hasError = false;
    _currentImageUrl = null;
    _animationController.reset();
  }

  Future<void> _loadImage() async {
    if (_isLoading ||
        widget.imageUrl.isEmpty ||
        widget.imageUrl == _currentImageUrl) {
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _currentImageUrl = widget.imageUrl;
    });

    try {
      _logger.debug('Cargando imagen lazy: ${widget.imageUrl}');

      final provider = await HybridImageService.instance
          .getOptimizedImageProvider(widget.imageUrl, size: widget.tmdbSize);

      if (mounted && widget.imageUrl == _currentImageUrl) {
        setState(() {
          _imageProvider = provider;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      _logger.error('Error cargando imagen lazy ${widget.imageUrl}: $e');
      if (mounted && widget.imageUrl == _currentImageUrl) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  void _onVisibilityChanged(bool isVisible) {
    if (_isVisible == isVisible) return;

    _isVisible = isVisible;

    if (isVisible &&
        widget.loadOnlyWhenVisible &&
        _imageProvider == null &&
        !_isLoading) {
      _loadImage();
    }
  }

  Widget _buildImageWidget() {
    if (_hasError) {
      return widget.errorWidget ?? _buildDefaultErrorWidget();
    }

    if (_imageProvider == null) {
      return widget.placeholder ?? _buildDefaultPlaceholder();
    }

    Widget imageWidget = Image(
      image: _imageProvider!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          return child;
        }

        return AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, _) {
            return Opacity(
              opacity: frame == null ? 0.0 : _fadeAnimation.value,
              child: child,
            );
          },
        );
      },
      errorBuilder: (context, error, stackTrace) {
        _logger.error('Error renderizando imagen ${widget.imageUrl}: $error');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _hasError = true;
            });
          }
        });
        return widget.errorWidget ?? _buildDefaultErrorWidget();
      },
    );

    if (widget.enableHeroAnimation && widget.heroTag != null) {
      imageWidget = Hero(
        tag: widget.heroTag!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: widget.borderRadius,
      ),
      child: widget.loadingIndicator ??
          const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
            ),
          ),
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: widget.borderRadius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: widget.height != null ? widget.height! * 0.3 : 48,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 8),
          Text(
            'Imagen no\ndisponible',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = _buildImageWidget();

    if (widget.borderRadius != null) {
      child = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: child,
      );
    }

    if (widget.loadOnlyWhenVisible) {
      return VisibilityDetector(
        key: Key(
          'lazy_image_${HybridImageService.instance.normalizeImageUrl(widget.imageUrl, size: widget.tmdbSize)}',
        ),
        onVisibilityChanged: (info) {
          _onVisibilityChanged(
              info.visibleFraction >= widget.visibilityThreshold);
        },
        child: child,
      );
    }

    return child;
  }
}

/// Detector de visibilidad simple para imágenes lazy
class VisibilityDetector extends StatefulWidget {
  const VisibilityDetector({
    super.key,
    required this.child,
    required this.onVisibilityChanged,
  });

  final Widget child;
  final ValueChanged<VisibilityInfo> onVisibilityChanged;

  @override
  State<VisibilityDetector> createState() => _VisibilityDetectorState();
}

class _VisibilityDetectorState extends State<VisibilityDetector> {
  final GlobalKey _key = GlobalKey();
  bool _wasVisible = false;
  Timer? _visibilityTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_checkVisibility);
  }

  void _checkVisibility(Duration? _) {
    if (!mounted) return;

    final context = _key.currentContext;
    if (context == null) return;

    // ✅ WEB FIX: Safe casting for Flutter Web compatibility
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return;
    if (!renderObject.attached) return;

    final position = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    final screenSize = MediaQuery.of(context).size;

    final visibleArea = _calculateVisibleArea(position, size, screenSize);
    final totalArea = size.width * size.height;
    final visibleFraction = totalArea > 0 ? visibleArea / totalArea : 0.0;

    final isVisible = visibleFraction > 0;
    if (isVisible != _wasVisible) {
      _wasVisible = isVisible;
      widget.onVisibilityChanged(VisibilityInfo(visibleFraction));
    }

    // Programar siguiente check con timer cancelable
    if (mounted) {
      _visibilityTimer?.cancel();
      _visibilityTimer = Timer(const Duration(milliseconds: 100), () {
        _checkVisibility(null);
      });
    }
  }

  double _calculateVisibleArea(Offset position, Size size, Size screenSize) {
    final left = position.dx.clamp(0.0, screenSize.width);
    final top = position.dy.clamp(0.0, screenSize.height);
    final right = (position.dx + size.width).clamp(0.0, screenSize.width);
    final bottom = (position.dy + size.height).clamp(0.0, screenSize.height);

    final visibleWidth = (right - left).clamp(0.0, size.width);
    final visibleHeight = (bottom - top).clamp(0.0, size.height);

    return visibleWidth * visibleHeight;
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _key,
      child: widget.child,
    );
  }
}

/// Información de visibilidad para el detector
class VisibilityInfo {
  const VisibilityInfo(this.visibleFraction);

  final double visibleFraction;
}

/// Widget de imagen con precarga inteligente para listas
class PreloadOptimizedImage extends StatefulWidget {
  const PreloadOptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.preloadDistance = 500.0,
    this.tmdbSize = 'w500',
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final double preloadDistance;
  final String tmdbSize;

  @override
  State<PreloadOptimizedImage> createState() => _PreloadOptimizedImageState();
}

class _PreloadOptimizedImageState extends State<PreloadOptimizedImage> {
  bool _hasPreloaded = false;

  void _preloadIfNeeded(double visibleFraction) {
    if (!_hasPreloaded && visibleFraction > 0) {
      _hasPreloaded = true;
      // Precargar la imagen
      HybridImageService.instance
          .getOptimizedImageProvider(widget.imageUrl, size: widget.tmdbSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('preload_${widget.imageUrl}'),
      onVisibilityChanged: (info) => _preloadIfNeeded(info.visibleFraction),
      child: LazyOptimizedImage(
        imageUrl: widget.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        borderRadius: widget.borderRadius,
        loadOnlyWhenVisible: false, // Ya manejamos la visibilidad aquí
        tmdbSize: widget.tmdbSize,
      ),
    );
  }
}
