import 'package:flutter/material.dart';

import '../../../core/logging/logger_factory.dart';

class YouTubeThumbnail extends StatefulWidget {
  const YouTubeThumbnail({
    super.key,
    required this.youtubeId,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorPlaceholder,
  });

  final String youtubeId;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorPlaceholder;

  @override
  State<YouTubeThumbnail> createState() => _YouTubeThumbnailState();
}

class _YouTubeThumbnailState extends State<YouTubeThumbnail> {
  static const List<String> _resolutions = <String>[
    'maxresdefault.jpg',
    'sddefault.jpg',
    'hqdefault.jpg',
    'mqdefault.jpg',
    'default.jpg',
  ];

  int _currentResolutionIndex = 0;
  bool _isAdvancing = false;
  bool _hasLoggedFinalFailure = false;
  bool _isDisposed = false;

  String get _currentUrl =>
      'https://img.youtube.com/vi/${widget.youtubeId}/${_resolutions[_currentResolutionIndex]}';

  void _scheduleAdvanceResolution() {
    if (_isAdvancing ||
        _currentResolutionIndex >= _resolutions.length - 1 ||
        _isDisposed ||
        !mounted) {
      return;
    }

    _isAdvancing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed || !mounted) {
        return;
      }
      setState(() {
        _currentResolutionIndex++;
        _isAdvancing = false;
      });
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    LoggerFactory.info(
        '🧹 YouTubeThumbnail disposed for video: ${widget.youtubeId}');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget image = Image.network(
      _currentUrl,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      loadingBuilder: (BuildContext context, Widget child,
          ImageChunkEvent? loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return widget.placeholder ?? _buildPlaceholder();
      },
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
        if (_currentResolutionIndex < _resolutions.length - 1) {
          _scheduleAdvanceResolution();
          return widget.placeholder ?? _buildPlaceholder();
        }

        if (!_hasLoggedFinalFailure) {
          _hasLoggedFinalFailure = true;
          LoggerFactory.warning(
              '⚠️ No se pudo cargar thumbnail de YouTube para ${widget.youtubeId}: $error');
        }

        return widget.errorPlaceholder ?? _buildErrorPlaceholder();
      },
    );

    final BorderRadius? radius = widget.borderRadius;
    if (radius != null) {
      image = ClipRRect(
        borderRadius: radius,
        child: image,
      );
    }

    return image;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.black.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: const Icon(
        Icons.play_circle_outline,
        color: Colors.white24,
        size: 48,
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.black.withValues(alpha: 0.4),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.white54,
        size: 40,
      ),
    );
  }
}
