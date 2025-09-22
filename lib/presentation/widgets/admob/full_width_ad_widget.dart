import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../config/helpers/ad_helper.dart';
import 'adsense_web_widget.dart';

/// Widget de anuncio que ocupa toda la línea horizontal en listas verticales
/// Se inserta cada X películas (múltiplo de 3) para mantener el flujo visual
class FullWidthAdWidget extends StatefulWidget {
  const FullWidthAdWidget({
    super.key,
    this.height = 120,
    this.margin = const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    this.showLabel = true,
    this.borderRadius = 12,
  });

  final double height;
  final EdgeInsets margin;
  final bool showLabel;
  final double borderRadius;

  @override
  State<FullWidthAdWidget> createState() => _FullWidthAdWidgetState();
}

class _FullWidthAdWidgetState extends State<FullWidthAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isAdFailed = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    // En web se usa AdSense, no AdMob
    if (kIsWeb) {
      return;
    }

    _nativeAd = NativeAd(
      adUnitId: AdHelper.nativeAdUnitId,
      factoryId: 'listTile', // Usando el factory existente
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
              _isAdFailed = false;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          if (mounted) {
            setState(() {
              _isAdFailed = true;
              _isAdLoaded = false;
            });
          }
          ad.dispose();
        },
      ),
      request: const AdRequest(),
    );

    _nativeAd?.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // En web, usar AdSense
    if (kIsWeb) {
      return AdSenseFullWidthWidget(
        height: widget.height,
        margin: widget.margin,
        showLabel: widget.showLabel,
        borderRadius: widget.borderRadius,
      );
    }

    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return Container(
      margin: widget.margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Etiqueta opcional en la parte superior
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
                    'Contenido patrocinado',
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

          // Contenedor principal del anuncio
          Container(
            width: double.infinity,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              color: colors.surfaceContainerHighest,
              border: Border.all(
                color: colors.outline.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
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
    final nativeAd = _nativeAd;
    if (_isAdLoaded && nativeAd != null) {
      return AdWidget(ad: nativeAd);
    }

    if (_isAdFailed) {
      return _buildErrorState(colors, textStyles);
    }

    return _buildLoadingState(colors, textStyles);
  }

  Widget _buildLoadingState(ColorScheme colors, TextTheme textStyles) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            colors.surfaceContainerHighest,
            colors.surfaceContainer,
            colors.surfaceContainerHighest,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cargando anuncio...',
                style: textStyles.bodyMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Por favor espera un momento',
                style: textStyles.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colors, TextTheme textStyles) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            colors.errorContainer.withValues(alpha: 0.08),
            colors.surfaceContainer,
            colors.errorContainer.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 24,
            color: colors.error.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Error al cargar anuncio',
                style: textStyles.bodyMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Contenido no disponible',
                style: textStyles.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Variante compacta del FullWidthAdWidget
class CompactFullWidthAdWidget extends StatelessWidget {
  const CompactFullWidthAdWidget({
    super.key,
    this.margin = const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
  });

  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return FullWidthAdWidget(
      height: 80,
      margin: margin,
      showLabel: false,
      borderRadius: 8,
    );
  }
}

/// Variante premium del FullWidthAdWidget con más altura
class PremiumFullWidthAdWidget extends StatelessWidget {
  const PremiumFullWidthAdWidget({
    super.key,
    this.margin = const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
  });

  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return FullWidthAdWidget(
      height: 160,
      margin: margin,
      showLabel: true,
      borderRadius: 16,
    );
  }
}

/// Widget separador que incluye un anuncio de ancho completo
/// Útil para insertar entre secciones de contenido
class AdSeparatorWidget extends StatelessWidget {
  const AdSeparatorWidget({
    super.key,
    this.topPadding = 24,
    this.bottomPadding = 16,
  });

  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: topPadding),
        const CompactFullWidthAdWidget(),
        SizedBox(height: bottomPadding),
      ],
    );
  }
}
