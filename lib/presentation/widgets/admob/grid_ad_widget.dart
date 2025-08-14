import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../config/helpers/ad_helper.dart';

/// Widget de anuncio que ocupa el espacio de una tarjeta en grids verticales
/// Se integra perfectamente en MasonryGridView manteniendo el flujo visual
class GridAdWidget extends StatefulWidget {
  const GridAdWidget({
    super.key,
    this.aspectRatio = 0.7, // Ratio típico de posters de películas
    this.showLabel = true,
    this.borderRadius = 12,
  });

  final double aspectRatio;
  final bool showLabel;
  final double borderRadius;

  @override
  State<GridAdWidget> createState() => _GridAdWidgetState();
}

class _GridAdWidgetState extends State<GridAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isAdFailed = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    // No cargar anuncios en web
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _isAdFailed = true;
          _isAdLoaded = false;
        });
      }
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

    _nativeAd!.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = width / widget.aspectRatio;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Contenedor principal del anuncio
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                color: colors.surfaceContainerHighest,
                border: Border.all(
                  color: colors.outline.withValues(alpha: 0.15),
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
                child: _buildAdContent(colors, textStyles),
              ),
            ),
            
            // Etiqueta opcional
            if (widget.showLabel) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.ads_click,
                    size: 10,
                    color: colors.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Anuncio',
                    style: textStyles.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.5),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAdContent(ColorScheme colors, TextTheme textStyles) {
    if (_isAdLoaded && _nativeAd != null) {
      return AdWidget(ad: _nativeAd!);
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
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
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
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cargando...',
            style: TextStyle(
              fontSize: 9,
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
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
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
            size: 20,
            color: colors.error.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 6),
          Text(
            'Error',
            style: textStyles.bodySmall?.copyWith(
              fontSize: 9,
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Variante minimalista del GridAdWidget sin etiqueta
class MinimalGridAdWidget extends StatelessWidget {
  const MinimalGridAdWidget({
    super.key,
    this.aspectRatio = 0.7,
  });

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return GridAdWidget(
      aspectRatio: aspectRatio,
      showLabel: false,
      borderRadius: 10,
    );
  }
}

/// Variante cuadrada del GridAdWidget para layouts específicos
class SquareGridAdWidget extends StatelessWidget {
  const SquareGridAdWidget({
    super.key,
    this.showLabel = true,
  });

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return GridAdWidget(
      aspectRatio: 1.0, // Cuadrado
      showLabel: showLabel,
      borderRadius: 12,
    );
  }
}