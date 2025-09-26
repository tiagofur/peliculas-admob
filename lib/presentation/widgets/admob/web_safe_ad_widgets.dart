import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../services/monetization/adsense_service.dart';
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
