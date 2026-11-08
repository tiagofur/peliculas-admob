/// Configuración de slots de AdSense para diferentes tipos de anuncios
class AdSenseSlots {
  AdSenseSlots._();

  // Publisher ID de AdSense
  static const String publisherId = 'ca-pub-4576016092724628';

  // Slots específicos para diferentes tipos de anuncio
  // Nota: Estos slots necesitan ser creados en la consola de AdSense

  /// Banner horizontal típico (728x90, 320x50, responsive)
  static const String bannerSlot = '1234567890';

  /// Anuncio nativo/in-feed para listas de películas
  static const String nativeSlot = '2345678901';

  /// Anuncio de ancho completo para separadores de sección
  static const String fullWidthSlot = '3456789012';

  /// Anuncio cuadrado para grillas de películas
  static const String gridSlot = '4567890123';

  /// Anuncio de artículo para páginas de detalles
  static const String articleSlot = '5678901234';

  /// Anuncio responsive grande para home
  static const String homeHeroSlot = '6789012345';

  /// Interstitial overlay responsive slot
  static const String interstitialSlot = '7890123456';

  /// Rewarded overlay slot (video reward)
  static const String rewardedSlot = '8901234567';

  /// Obtener slot por tipo de anuncio
  static String getSlotForType(AdSenseAdType type) {
    switch (type) {
      case AdSenseAdType.banner:
        return bannerSlot;
      case AdSenseAdType.native:
        return nativeSlot;
      case AdSenseAdType.fullWidth:
        return fullWidthSlot;
      case AdSenseAdType.grid:
        return gridSlot;
      case AdSenseAdType.article:
        return articleSlot;
      case AdSenseAdType.homeHero:
        return homeHeroSlot;
      case AdSenseAdType.interstitial:
        return interstitialSlot;
      case AdSenseAdType.rewarded:
        return rewardedSlot;
    }
  }

  /// Obtener configuración completa para un tipo de anuncio
  static AdSenseConfig getConfigForType(AdSenseAdType type) {
    switch (type) {
      case AdSenseAdType.banner:
        return const AdSenseConfig(
          slot: bannerSlot,
          format: 'auto',
          responsive: true,
          style: 'display:block',
        );
      case AdSenseAdType.native:
        return const AdSenseConfig(
          slot: nativeSlot,
          format: 'fluid',
          responsive: true,
          style: 'display:block',
          layoutKey: '-gw-1+2a-9x+5c',
        );
      case AdSenseAdType.fullWidth:
        return const AdSenseConfig(
          slot: fullWidthSlot,
          format: 'auto',
          responsive: true,
          style: 'display:block',
        );
      case AdSenseAdType.grid:
        return const AdSenseConfig(
          slot: gridSlot,
          format: 'auto',
          responsive: false,
          style: 'display:inline-block;width:300px;height:250px',
        );
      case AdSenseAdType.article:
        return const AdSenseConfig(
          slot: articleSlot,
          format: 'fluid',
          responsive: true,
          style: 'display:block; text-align:center;',
          layoutKey: '-fb+5w+4e-db+86',
        );
      case AdSenseAdType.homeHero:
        return const AdSenseConfig(
          slot: homeHeroSlot,
          format: 'auto',
          responsive: true,
          style: 'display:block',
        );
      case AdSenseAdType.interstitial:
        return const AdSenseConfig(
          slot: interstitialSlot,
          format: 'auto',
          responsive: true,
          style: 'display:block;width:100%;height:100%;min-height:320px;',
          layoutKey: '-gw-1+2a-9x+5c',
          width: '320',
          height: '480',
        );
      case AdSenseAdType.rewarded:
        return const AdSenseConfig(
          slot: rewardedSlot,
          format: 'rewarded',
          responsive: true,
          style: 'display:block;width:100%;height:100%;min-height:360px;',
          layoutKey: '-gw-1+2a-9x+5c',
          width: '360',
          height: '640',
        );
    }
  }
}

/// Tipos de anuncios AdSense disponibles
enum AdSenseAdType {
  banner,
  native,
  fullWidth,
  grid,
  article,
  homeHero,
  interstitial,
  rewarded,
}

/// Configuración específica de un anuncio AdSense
class AdSenseConfig {
  const AdSenseConfig({
    required this.slot,
    required this.format,
    required this.responsive,
    required this.style,
    this.layoutKey,
    this.width,
    this.height,
  });

  final String slot;
  final String format;
  final bool responsive;
  final String style;
  final String? layoutKey;
  final String? width;
  final String? height;

  /// Generar HTML para el anuncio
  String generateHtml({required String publisherId}) {
    final responsiveAttr =
        responsive ? 'data-full-width-responsive="true"' : '';
    final layoutKeyAttr =
        layoutKey != null ? 'data-ad-layout-key="$layoutKey"' : '';
    final widthAttr = width != null ? 'data-ad-width="$width"' : '';
    final heightAttr = height != null ? 'data-ad-height="$height"' : '';

    return '''
      <ins class="adsbygoogle"
           style="$style"
           data-ad-client="$publisherId"
           data-ad-slot="$slot"
           data-ad-format="$format"
           $layoutKeyAttr
           $widthAttr
           $heightAttr
           $responsiveAttr>
      </ins>
    ''';
  }
}
