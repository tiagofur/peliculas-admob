import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../config/helpers/ad_helper.dart';
import '../../../core/logging/logger_factory.dart';
import 'web_safe_ad_widgets.dart';

/// Widget de anuncio que imita el tamaño y estilo de las tarjetas de películas
/// para integrarse perfectamente en listas horizontales
class MovieCardAdWidget extends StatefulWidget {
  const MovieCardAdWidget({
    super.key,
    this.width = 150,
    this.height = 220,
    this.borderRadius = 20,
    this.showLabel = true,
  });

  final double width;
  final double height;
  final double borderRadius;
  final bool showLabel;

  @override
  State<MovieCardAdWidget> createState() => _MovieCardAdWidgetState();
}

class _MovieCardAdWidgetState extends State<MovieCardAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isAdFailed = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadAd();
    }
  }

  void _loadAd() {
    // No cargar anuncios en web
    if (kIsWeb) {
      return;
    }

    // Evitar cargar AdMob en plataformas no soportadas (ej. Windows, macOS, Linux)
    if (!AdHelper.isAdMobSupported) {
      LoggerFactory.warning('AdMob no soportado en esta plataforma');
      if (mounted) {
        setState(() {
          _isAdFailed = true;
          _isAdLoaded = false;
        });
      }
      return;
    }

    try {
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
            LoggerFactory.error('Error cargando movie card ad: $error');
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
    } catch (e) {
      LoggerFactory.error('Excepción inicializando movie card ad: $e');
      if (mounted) {
        setState(() {
          _isAdFailed = true;
          _isAdLoaded = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return WebSafeMovieCardAdWidget(
        width: widget.width,
        height: widget.height,
        borderRadius: widget.borderRadius,
        showLabel: widget.showLabel,
      );
    }

    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return Container(
      width: widget.width,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contenedor principal del anuncio
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
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: _buildAdContent(colors, textStyles),
            ),
          ),

          // Espacio y etiqueta opcional
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

  Widget _buildAdContent(ColorScheme colors, TextTheme textStyles) {
    final nativeAd = _nativeAd;
    if (_isAdLoaded && nativeAd != null) {
      return AdWidget(ad: nativeAd);
    }

    if (_isAdFailed) {
      return _buildErrorState(colors, textStyles);
    }

    return _buildLoadingState(colors);
  }

  Widget _buildLoadingState(ColorScheme colors) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceContainerHighest,
            colors.surfaceContainer,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cargando...',
            style: TextStyle(
              fontSize: 10,
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.errorContainer.withValues(alpha: 0.1),
            colors.surfaceContainer,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 24,
            color: colors.error.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 8),
          Text(
            'Error al cargar',
            style: textStyles.bodySmall?.copyWith(
              fontSize: 10,
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Variante compacta del MovieCardAdWidget para espacios más pequeños
class CompactMovieCardAdWidget extends StatelessWidget {
  const CompactMovieCardAdWidget({
    super.key,
    this.width = 120,
    this.height = 180,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return MovieCardAdWidget(
      width: width,
      height: height,
      borderRadius: 16,
      showLabel: false,
    );
  }
}
