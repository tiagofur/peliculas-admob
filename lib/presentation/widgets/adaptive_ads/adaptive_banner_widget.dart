import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../services/monetization/adaptive_monetization_manager.dart';

/// Widget adaptativo de banner que funciona con AdMob (móvil) y AdSense (web/desktop)
/// Prioriza la experiencia de usuario y se integra naturalmente en la UI
class AdaptiveBannerWidget extends StatefulWidget {
  const AdaptiveBannerWidget({
    super.key,
    this.margin = const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    this.borderRadius = 12.0,
    this.showLabel = false,
    this.adSlotId,
    this.maxHeight = 280,
    this.backgroundColor,
  });

  /// Margin alrededor del anuncio
  final EdgeInsetsGeometry margin;

  /// Radio de borde para el contenedor
  final double borderRadius;

  /// Si mostrar etiqueta "Anuncio" o "Contenido patrocinado"
  final bool showLabel;

  /// ID del slot de AdSense (opcional, usa valor por defecto si no se especifica)
  final String? adSlotId;

  /// Altura máxima del anuncio
  final double maxHeight;

  /// Color de fondo personalizado
  final Color? backgroundColor;

  @override
  State<AdaptiveBannerWidget> createState() => _AdaptiveBannerWidgetState();
}

class _AdaptiveBannerWidgetState extends State<AdaptiveBannerWidget> {
  final AdaptiveMonetizationManager _monetization =
      AdaptiveMonetizationManager.instance;
  bool _isLoading = true;
  bool _hasError = false;
  String? _adHtml;
  String? _adId;

  @override
  void initState() {
    super.initState();
    _initializeAd();
  }

  Future<void> _initializeAd() async {
    if (!mounted) return;

    try {
      // Verificar si la monetización está disponible
      if (!_monetization.isInitialized) {
        await _monetization.initialize();
      }

      if (!_monetization.isMonetizationAvailable) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
        return;
      }

      // Crear anuncio según la plataforma
      switch (_monetization.currentPlatform) {
        case MonetizationPlatform.mobile:
          _setupMobileAd();
          break;

        case MonetizationPlatform.web:
        case MonetizationPlatform.desktop:
          _setupWebAd();
          break;
      }
    } catch (e) {
      LoggerFactory.error('Error inicializando anuncio adaptativo: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  void _setupMobileAd() {
    // Para móvil, usamos el sistema AdMob existente
    // El AdMob se maneja directamente en los widgets específicos
    setState(() {
      _isLoading = false;
    });
  }

  void _setupWebAd() {
    try {
      final slotId = widget.adSlotId ?? '1234567890'; // Default test slot

      // Para web, configuramos AdSense (simplificado por ahora)
      if (kIsWeb) {
        _adHtml = 'AdSense Banner - Slot: $slotId';
        _adId = 'adaptive-banner-${DateTime.now().millisecondsSinceEpoch}';

        LoggerFactory.info('AdSense banner configurado: $_adId');
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      LoggerFactory.error('Error configurando anuncio web: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    // No mostrar nada si está cargando y es móvil (AdMob maneja su propio loading)
    if (_isLoading &&
        _monetization.currentPlatform == MonetizationPlatform.mobile) {
      return const SizedBox.shrink();
    }

    // Para móvil, mostrar el widget AdMob existente
    if (_monetization.currentPlatform == MonetizationPlatform.mobile) {
      return _buildMobileAdWidget(colors, textStyles);
    }

    // Para web/desktop, mostrar nuestro widget personalizado
    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        color: widget.backgroundColor ??
            colors.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border.all(
          color: colors.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showLabel) _buildAdLabel(colors, textStyles),
          _buildAdContent(colors, textStyles),
        ],
      ),
    );
  }

  Widget _buildMobileAdWidget(ColorScheme colors, TextTheme textStyles) {
    // Importar y usar el widget AdMob existente
    // Por ahora, retornamos un placeholder
    return Container(
      margin: widget.margin,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border.all(
          color: colors.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: const Center(
        child: Text('AdMob Banner Placeholder'),
      ),
    );
  }

  Widget _buildAdLabel(ColorScheme colors, TextTheme textStyles) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.ads_click,
            size: 12,
            color: colors.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Text(
            'Contenido patrocinado',
            style: textStyles.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.6),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.info_outline,
            size: 12,
            color: colors.onSurface.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildAdContent(ColorScheme colors, TextTheme textStyles) {
    if (_isLoading) {
      return Container(
        height: widget.maxHeight,
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_hasError) {
      return Container(
        height: 80,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 20,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                'Anuncio no disponible',
                style: textStyles.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Mostrar anuncio web (simplificado)
    if (_adId != null && kIsWeb && _adHtml != null) {
      return Container(
        height: widget.maxHeight,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.ads_click,
                color: colors.primary.withValues(alpha: 0.7),
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                'AdSense Placeholder',
                style: textStyles.labelMedium?.copyWith(
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _adHtml!,
                style: textStyles.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Fallback
    return Container(
      height: 80,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          'Cargando anuncio...',
          style: textStyles.bodySmall?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Cleanup si es necesario
    super.dispose();
  }
}

/// Widget adaptativo nativo para listas de películas
class AdaptiveNativeAdWidget extends StatelessWidget {
  const AdaptiveNativeAdWidget({
    super.key,
    this.height = 120,
    this.margin,
    this.showLabel = true,
  });

  final double height;
  final EdgeInsetsGeometry? margin;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final monetization = AdaptiveMonetizationManager.instance;

    if (!monetization.isMonetizationAvailable) {
      return const SizedBox.shrink();
    }

    // Usar widget según la plataforma
    if (monetization.currentPlatform == MonetizationPlatform.mobile) {
      // Usar widget nativo AdMob existente (placeholder por ahora)
      return const SizedBox.shrink();
    } else {
      // Web o Desktop - usar AdSense
      return AdaptiveBannerWidget(
        margin: margin ?? const EdgeInsets.all(8),
        maxHeight: height,
        showLabel: showLabel,
        borderRadius: 8,
      );
    }
  }
}

/// Helper para insertar anuncios en listas de manera inteligente
class AdaptiveAdInserter {
  /// Inserta anuncios adaptativos en una lista
  static Widget buildListWithAds({
    required List<Widget> items,
    int adInterval = 8, // Más espaciado para mejor UX
    Widget? customAdWidget,
    bool respectUserPreference = true,
  }) {
    final monetization = AdaptiveMonetizationManager.instance;

    // No insertar ads si no está disponible
    if (!monetization.isMonetizationAvailable) {
      return ListView(children: items);
    }

    // Usar FutureBuilder para manejar las preferencias asíncronas
    return FutureBuilder(
      future: respectUserPreference ? monetization.getUserPreferences() : null,
      builder: (context, snapshot) {
        // Si estamos respetando preferencias y aún no cargan, mostrar sin ads
        if (respectUserPreference && !snapshot.hasData) {
          return ListView(children: items);
        }

        // Si el usuario ha deshabilitado anuncios nativos, no mostrar ads
        if (respectUserPreference &&
            snapshot.hasData &&
            !(snapshot.data!.allowNativeAds)) {
          return ListView(children: items);
        }

        // Construir lista con anuncios
        return ListView(
            children: _insertAdsInList(items, adInterval, customAdWidget));
      },
    );
  }

  /// Método privado para insertar anuncios en la lista
  static List<Widget> _insertAdsInList(
    List<Widget> items,
    int adInterval,
    Widget? customAdWidget,
  ) {
    final List<Widget> result = [];

    for (int i = 0; i < items.length; i++) {
      result.add(items[i]);

      // Insertar anuncio cada cierto intervalo (no al principio ni al final)
      if (i > 2 && // No en los primeros elementos
          i < items.length - 2 && // No en los últimos elementos
          (i + 1) % adInterval == 0) {
        final adWidget = customAdWidget ??
            const AdaptiveNativeAdWidget(
              height: 100,
              showLabel: true,
            );

        result.add(adWidget);
      }
    }

    return result;
  }
}
