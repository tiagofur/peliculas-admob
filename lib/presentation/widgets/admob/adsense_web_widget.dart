import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../config/helpers/ad_helper.dart';
import '../../../core/logging/base_logger.dart';
import '../../../core/logging/logger_factory.dart';

/// Widget para mostrar anuncios de Google AdSense en la web
class AdSenseWebWidget extends StatefulWidget {
  const AdSenseWebWidget({
    super.key,
    required this.adSlot,
    this.width = 320,
    this.height = 100,
    this.adFormat = 'auto',
    this.isResponsive = true,
    this.showLabel = true,
    this.borderRadius = 12,
    this.margin,
  });

  final String adSlot;
  final double width;
  final double height;
  final String adFormat;
  final bool isResponsive;
  final bool showLabel;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  @override
  State<AdSenseWebWidget> createState() => _AdSenseWebWidgetState();
}

class _AdSenseWebWidgetState extends State<AdSenseWebWidget> {
  static final BaseLogger _logger = LoggerFactory.getLogger('AdSenseWebWidget');
  late String _adId;
  bool _isAdLoaded = false;
  bool _isAdFailed = false;

  @override
  void initState() {
    super.initState();
    _adId = 'adsense-${widget.adSlot}-${DateTime.now().millisecondsSinceEpoch}';
    if (kIsWeb) {
      _createAdSenseAd();
    } else {
      _logger.warning('AdSenseWebWidget should only be used on web platform');
    }
  }

  void _createAdSenseAd() {
    if (!kIsWeb) return;

    try {
      // Create the HTML element for the ad
      final adElement = web.document.createElement('div') as web.HTMLDivElement;
      adElement.id = _adId;
      adElement.style.width =
          widget.isResponsive ? '100%' : '${widget.width}px';
      adElement.style.height =
          widget.isResponsive ? 'auto' : '${widget.height}px';
      adElement.style.display = 'block';
      adElement.style.textAlign = 'center';

      // Create the ins element for AdSense
      final insElement = web.document.createElement('ins') as web.HTMLElement;
      insElement.className = 'adsbygoogle';
      insElement.style.display = widget.isResponsive ? 'block' : 'inline-block';
      insElement.style.width =
          widget.isResponsive ? '100%' : '${widget.width}px';
      insElement.style.height =
          widget.isResponsive ? 'auto' : '${widget.height}px';
      insElement.setAttribute('data-ad-client', AdHelper.adSenseClientId);
      insElement.setAttribute('data-ad-slot', widget.adSlot);

      if (widget.isResponsive) {
        insElement.setAttribute('data-ad-format', 'auto');
        insElement.setAttribute('data-full-width-responsive', 'true');
      } else {
        insElement.setAttribute('data-ad-format', widget.adFormat);
      }

      adElement.appendChild(insElement);

      // Register the element with Flutter's platform view registry
      ui_web.platformViewRegistry.registerViewFactory(
        _adId,
        (int viewId) {
          _logger.debug('Creating AdSense view for slot: ${widget.adSlot}');
          return adElement;
        },
      );

      // Push the ad after a slight delay to ensure DOM is ready
      Future.delayed(const Duration(milliseconds: 100), () {
        _pushAdSenseAd();
      });

      if (mounted) {
        setState(() {
          _isAdLoaded = true;
          _isAdFailed = false;
        });
      }
    } catch (e) {
      _logger.error('Error creating AdSense ad: $e');
      if (mounted) {
        setState(() {
          _isAdLoaded = false;
          _isAdFailed = true;
        });
      }
    }
  }

  void _pushAdSenseAd() {
    if (!kIsWeb) return;

    try {
      // Check if adsbygoogle is available and push ad
      try {
        // Create a script element to execute the AdSense push
        final script =
            web.document.createElement('script') as web.HTMLScriptElement;
        script.text = '''
          try {
            if (typeof window.adsbygoogle !== 'undefined') {
              (adsbygoogle = window.adsbygoogle || []).push({});
              console.log('AdSense ad pushed for slot: ${widget.adSlot}');
            } else {
              console.warn('AdSense script not loaded for slot: ${widget.adSlot}');
            }
          } catch (e) {
            console.error('Error pushing AdSense ad:', e);
          }
        ''';

        // Append and remove the script to execute it
        web.document.head!.appendChild(script);
        web.document.head!.removeChild(script);

        _logger.debug('AdSense ad push script executed');
      } catch (e) {
        _logger.warning('AdSense not available: $e');
        if (mounted) {
          setState(() {
            _isAdFailed = true;
          });
        }
      }
      _logger.debug('AdSense ad pushed successfully');
    } catch (e) {
      _logger.error('Error pushing AdSense ad: $e');
      if (mounted) {
        setState(() {
          _isAdFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return Container(
      margin: widget.margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label opcional
          if (widget.showLabel) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.ads_click,
                    size: 12,
                    color: colors.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Publicidad',
                    style: textStyles.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Contenedor del anuncio
          Container(
            width: widget.isResponsive ? double.infinity : widget.width,
            height: widget.isResponsive ? null : widget.height,
            constraints: widget.isResponsive
                ? const BoxConstraints(minHeight: 100, maxHeight: 300)
                : null,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
              border: Border.all(
                color: colors.outline.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: _buildAdContent(colors, textStyles),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdContent(ColorScheme colors, TextTheme textStyles) {
    if (_isAdLoaded && !_isAdFailed) {
      return HtmlElementView(viewType: _adId);
    }

    if (_isAdFailed) {
      return _buildErrorState(colors, textStyles);
    }

    return _buildLoadingState(colors);
  }

  Widget _buildLoadingState(ColorScheme colors) {
    return Container(
      width: double.infinity,
      height: widget.isResponsive ? 100 : widget.height,
      color: colors.surfaceContainerHighest.withValues(alpha: 0.1),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              colors.primary.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colors, TextTheme textStyles) {
    return Container(
      width: double.infinity,
      height: widget.isResponsive ? 100 : widget.height,
      color: colors.surfaceContainerHighest.withValues(alpha: 0.05),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 4),
            Text(
              'Espacio publicitario',
              style: textStyles.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.4),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up if needed
    super.dispose();
  }
}

/// Widget de anuncio AdSense responsivo para banners
class AdSenseBannerWidget extends StatelessWidget {
  const AdSenseBannerWidget({
    super.key,
    this.showLabel = true,
    this.margin,
  });

  final bool showLabel;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    return AdSenseWebWidget(
      adSlot: AdHelper.adSenseBannerSlot,
      width: 728,
      height: 90,
      isResponsive: true,
      showLabel: showLabel,
      margin: margin ?? const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    );
  }
}

/// Widget de anuncio AdSense para contenido nativo/responsivo
class AdSenseNativeWidget extends StatelessWidget {
  const AdSenseNativeWidget({
    super.key,
    this.height = 120,
    this.showLabel = false,
    this.margin,
    this.borderRadius = 12,
  });

  final double height;
  final bool showLabel;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    return AdSenseWebWidget(
      adSlot: AdHelper.adSenseNativeSlot,
      height: height,
      isResponsive: true,
      showLabel: showLabel,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      borderRadius: borderRadius,
    );
  }
}

/// Widget de anuncio AdSense de ancho completo
class AdSenseFullWidthWidget extends StatelessWidget {
  const AdSenseFullWidthWidget({
    super.key,
    this.height = 120,
    this.margin,
    this.showLabel = true,
    this.borderRadius = 12,
  });

  final double height;
  final EdgeInsets? margin;
  final bool showLabel;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    return AdSenseWebWidget(
      adSlot: AdHelper.adSenseFullWidthSlot,
      height: height,
      isResponsive: true,
      showLabel: showLabel,
      margin: margin ?? const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      borderRadius: borderRadius,
    );
  }
}
