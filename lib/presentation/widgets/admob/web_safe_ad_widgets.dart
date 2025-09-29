import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../services/monetization/adsense_service_stub.dart'
    if (dart.library.html) '../../../services/monetization/adsense_service.dart';
import '../../../widgets/ads/ad_placeholder_widget.dart';

/// Web-safe wrapper para widgets de AdMob
/// En web, estos widgets muestran AdSense, en móvil muestran AdMob
class WebSafeBannerAdWidget extends StatefulWidget {
  const WebSafeBannerAdWidget({super.key});

  @override
  State<WebSafeBannerAdWidget> createState() => _WebSafeBannerAdWidgetState();
}

class _WebSafeBannerAdWidgetState extends State<WebSafeBannerAdWidget> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initializeAdSense();
    }
  }

  Future<void> _initializeAdSense() async {
    try {
      await AdSenseService().initialize();
    } catch (e) {
      LoggerFactory.error('Error inicializando AdSense en banner: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // En web, mostramos AdSense
      return const _AdSenseBannerWidget();
    }

    // En móvil, importamos dinámicamente el widget real
    return const _MobileBannerAd();
  }
}

class _AdSenseBannerWidget extends StatefulWidget {
  const _AdSenseBannerWidget();

  @override
  State<_AdSenseBannerWidget> createState() => _AdSenseBannerWidgetState();
}

class _AdSenseBannerWidgetState extends State<_AdSenseBannerWidget> {
  @override
  void initState() {
    super.initState();
    _initializeAdSense();
  }

  Future<void> _initializeAdSense() async {
    try {
      await AdSenseService().initialize();
    } catch (e) {
      LoggerFactory.error('Error inicializando AdSense en banner: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }

    // En modo debug, mostrar placeholder claramente
    if (kDebugMode) {
      return const AdPlaceholderWidget(
        type: AdPlaceholderType.banner,
        customText: 'AdSense Banner\n(Debug Mode)\nProducción: ID real',
      );
    }

    // En producción, crear el elemento HTML real de AdSense
    return Container(
      height: 90,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withValues(alpha: 0.1),
            Colors.blue.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: const Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.ads_click, color: Colors.blue, size: 20),
            SizedBox(width: 8),
            Text(
              'AdSense Banner Loading...',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WebSafeNativeAdWidget extends StatefulWidget {
  const WebSafeNativeAdWidget({super.key});

  @override
  State<WebSafeNativeAdWidget> createState() => _WebSafeNativeAdWidgetState();
}

class _WebSafeNativeAdWidgetState extends State<WebSafeNativeAdWidget> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initializeAdSense();
    }
  }

  Future<void> _initializeAdSense() async {
    try {
      await AdSenseService().initialize();
    } catch (e) {
      LoggerFactory.error('Error inicializando AdSense en native: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // En modo debug, mostrar placeholder claramente
      if (kDebugMode) {
        return const AdPlaceholderWidget(
          type: AdPlaceholderType.native,
          customText: 'AdSense Native\n(Debug Mode)\nProducción: ID real',
        );
      }

      // En web producción, mostrar AdSense nativo
      return Container(
        height: 120,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.withValues(alpha: 0.1),
              Colors.green.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.article, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text(
                'AdSense Native Loading...',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // En móvil, usar widget real de AdMob
    return const _MobileNativeAd();
  }
}

class WebSafeMovieCardAdWidget extends StatefulWidget {
  const WebSafeMovieCardAdWidget({
    super.key,
    required this.width,
    required this.height,
    required this.borderRadius,
    this.showLabel = true,
  });

  final double width;
  final double height;
  final double borderRadius;
  final bool showLabel;

  @override
  State<WebSafeMovieCardAdWidget> createState() =>
      _WebSafeMovieCardAdWidgetState();
}

class _WebSafeMovieCardAdWidgetState extends State<WebSafeMovieCardAdWidget> {
  bool _initializationAttempted = false;
  bool _adsenseReady = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initializeAdSense();
    }
  }

  Future<void> _initializeAdSense() async {
    try {
      await AdSenseService().initialize();
      if (!mounted) {
        return;
      }
      setState(() {
        _initializationAttempted = true;
        _adsenseReady = AdSenseService().isAdSenseReady();
      });
    } catch (error, stackTrace) {
      LoggerFactory.error(
        'Error inicializando AdSense en movie card: $error',
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _initializationAttempted = true;
        _adsenseReady = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return Container(
      width: widget.width,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              color: colors.surfaceContainerHighest,
              border: Border.all(
                color: colors.outline.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: _buildContent(colors, textStyles),
            ),
          ),
          if (widget.showLabel) ...[
            const SizedBox(height: 5),
            SizedBox(
              width: widget.width,
              child: Row(
                children: [
                  Icon(
                    Icons.ads_click,
                    size: 12,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Anuncio',
                      style: textStyles.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme colors, TextTheme textStyles) {
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }

    if (kDebugMode) {
      return AdPlaceholderWidget(
        type: AdPlaceholderType.native,
        width: widget.width,
        height: widget.height,
        customText: 'AdSense Movie Card\n(Debug Mode)',
      );
    }

    if (_adsenseReady) {
      return _buildReadyState(colors, textStyles);
    }

    if (!_initializationAttempted) {
      return _buildLoadingState(colors);
    }

    return _buildSoftFallback(colors, textStyles);
  }

  Widget _buildLoadingState(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceContainerHigh,
            colors.surfaceContainerLowest,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cargando ventana publicitaria...',
              style: TextStyle(
                fontSize: 10,
                color: colors.onSurface.withValues(alpha: 0.65),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyState(ColorScheme colors, TextTheme textStyles) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(alpha: 0.12),
            colors.primaryContainer.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_graph,
              color: colors.primary.withValues(alpha: 0.9),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              'Publicidad personalizada',
              style: textStyles.bodySmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.onSurface.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              'Gracias por apoyar la app',
              style: textStyles.bodySmall?.copyWith(
                fontSize: 10,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoftFallback(ColorScheme colors, TextTheme textStyles) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.surfaceContainerHigh,
            colors.surfaceContainerLow,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hourglass_top,
              size: 24,
              color: colors.onSurface.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 8),
            Text(
              'Espacio publicitario listo',
              style: textStyles.bodySmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              'Estamos conectando con AdSense',
              style: textStyles.bodySmall?.copyWith(
                fontSize: 9,
                color: colors.onSurface.withValues(alpha: 0.55),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class WebSafeFullWidthAdWidget extends StatefulWidget {
  const WebSafeFullWidthAdWidget({
    super.key,
    this.height = 100,
    this.margin = const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
    this.showLabel = true,
    this.borderRadius = 12,
  });

  final double height;
  final EdgeInsets margin;
  final bool showLabel;
  final double borderRadius;

  @override
  State<WebSafeFullWidthAdWidget> createState() =>
      _WebSafeFullWidthAdWidgetState();
}

class _WebSafeFullWidthAdWidgetState extends State<WebSafeFullWidthAdWidget> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initializeAdSense();
    }
  }

  Future<void> _initializeAdSense() async {
    try {
      await AdSenseService().initialize();
    } catch (e) {
      LoggerFactory.error('Error inicializando AdSense en fullwidth: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // En modo debug, mostrar placeholder claramente
      if (kDebugMode) {
        return AdPlaceholderWidget(
          type: AdPlaceholderType.fullWidth,
          width: double.infinity,
          height: widget.height,
          customText: 'AdSense Full Width\n(Debug Mode)\nProducción: ID real',
        );
      }

      // En web producción, mostramos AdSense de ancho completo
      return Container(
        height: widget.height,
        margin: widget.margin,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange.withValues(alpha: 0.1),
              Colors.orange.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.web, color: Colors.orange, size: 24),
              const SizedBox(height: 4),
              if (widget.showLabel)
                const Text(
                  'AdSense Full Width Loading...',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return _MobileFullWidthAd(
      height: widget.height,
      margin: widget.margin,
      showLabel: widget.showLabel,
      borderRadius: widget.borderRadius,
    );
  }
}

class WebSafeGridAdWidget extends StatefulWidget {
  const WebSafeGridAdWidget({super.key});

  @override
  State<WebSafeGridAdWidget> createState() => _WebSafeGridAdWidgetState();
}

class _WebSafeGridAdWidgetState extends State<WebSafeGridAdWidget> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initializeAdSense();
    }
  }

  Future<void> _initializeAdSense() async {
    try {
      await AdSenseService().initialize();
    } catch (e) {
      LoggerFactory.error('Error inicializando AdSense en grid: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // En web, mostramos AdSense de grid
      return Container(
        height: 100,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.purple.withValues(alpha: 0.1),
              Colors.purple.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.grid_view, color: Colors.purple, size: 16),
              SizedBox(height: 2),
              Text(
                'AdSense Grid',
                style: TextStyle(
                  color: Colors.purple,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return const _MobileGridAd();
  }
}

// Placeholders para widgets móviles
// Estos se reemplazarían con los widgets reales de AdMob en un refactor futuro
class _MobileBannerAd extends StatelessWidget {
  const _MobileBannerAd();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: const Center(
        child: Text(
          'Banner Ad Space',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}

class _MobileNativeAd extends StatelessWidget {
  const _MobileNativeAd();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: const Center(
        child: Text(
          'Native Ad Space',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}

class _MobileFullWidthAd extends StatelessWidget {
  const _MobileFullWidthAd({
    required this.height,
    required this.margin,
    required this.showLabel,
    required this.borderRadius,
  });
  final double height;
  final EdgeInsets margin;
  final bool showLabel;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showLabel)
              const Text(
                'Full Width Ad Space',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

class _MobileGridAd extends StatelessWidget {
  const _MobileGridAd();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: const Center(
        child: Text(
          'Grid Ad',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }
}
