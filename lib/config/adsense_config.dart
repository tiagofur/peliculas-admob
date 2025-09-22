/// Configuración específica de AdSense para la plataforma web
///
/// Este archivo contiene todas las configuraciones necesarias para integrar
/// Google AdSense en la versión web de la aplicación.
///
/// IMPORTANTE: Antes de usar en producción, debes:
/// 1. Crear una cuenta de AdSense en https://adsense.google.com
/// 2. Verificar tu sitio web
/// 3. Crear unidades de anuncios
/// 4. Reemplazar los valores placeholder con tus IDs reales
library;

class AdSenseConfig {
  // ========================================================================
  // CONFIGURACIÓN PRINCIPAL - REEMPLAZAR CON TUS VALORES REALES
  // ========================================================================

  /// ID de cliente de AdSense (ej: "ca-pub-1234567890123456")
  /// Obtener desde: AdSense Dashboard > Configuración > ID del editor
  static const String clientId = 'ca-pub-0000000000000000';

  /// URL del sitio web verificado en AdSense
  static const String siteUrl = 'https://peliculas.creapolis.dev';

  // ========================================================================
  // SLOTS DE ANUNCIOS - CREAR EN ADSENSE DASHBOARD
  // ========================================================================

  /// Banner horizontal (728x90 o responsivo)
  /// Para: Headers, footers, separadores entre contenido
  static const String bannerSlot = '0000000000';

  /// Anuncios nativos/responsivos
  /// Para: Integrados en listas de películas, grids
  static const String nativeSlot = '1111111111';

  /// Anuncios de ancho completo
  /// Para: Entre secciones, páginas de detalles
  static const String fullWidthSlot = '2222222222';

  /// Anuncios verticales (300x250)
  /// Para: Sidebars, contenido lateral
  static const String rectangleSlot = '3333333333';

  // ========================================================================
  // CONFIGURACIONES DE LAYOUT
  // ========================================================================

  /// Configuraciones para anuncios responsivos
  static const Map<String, Map<String, dynamic>> responsiveLayouts = {
    'banner': {
      'format': 'auto',
      'fullWidth': true,
      'minHeight': 90,
      'maxHeight': 120,
    },
    'native': {
      'format': 'fluid',
      'fullWidth': true,
      'minHeight': 100,
      'maxHeight': 300,
    },
    'fullWidth': {
      'format': 'auto',
      'fullWidth': true,
      'minHeight': 120,
      'maxHeight': 250,
    },
    'rectangle': {
      'format': 'rectangle',
      'fullWidth': false,
      'width': 300,
      'height': 250,
    },
  };

  // ========================================================================
  // CONFIGURACIONES AVANZADAS
  // ========================================================================

  /// Habilitar anuncios responsivos automáticamente
  static const bool autoResponsive = true;

  /// Tiempo de espera para cargar anuncios (en milisegundos)
  static const int adLoadTimeout = 5000;

  /// Habilitar lazy loading de anuncios
  static const bool enableLazyLoading = true;

  /// Margen desde el viewport para iniciar lazy loading
  static const String lazyLoadMargin = '50px';

  /// Configuración para páginas con contenido sensible
  static const Map<String, dynamic> contentPolicy = {
    'safeFrame': true,
    'adTest': false, // Cambiar a true solo en desarrollo
    'familySafe': true,
  };

  // ========================================================================
  // MÉTODOS UTILITARIOS
  // ========================================================================

  /// Obtiene la configuración de layout para un tipo de anuncio
  static Map<String, dynamic>? getLayoutConfig(String adType) {
    return responsiveLayouts[adType];
  }

  /// Valida si la configuración de AdSense está completa
  static bool isConfigurationValid() {
    return clientId != 'ca-pub-0000000000000000' &&
        bannerSlot != '0000000000' &&
        nativeSlot != '1111111111' &&
        fullWidthSlot != '2222222222';
  }

  /// Genera el script tag para el cliente de AdSense
  static String getAdSenseScriptTag() {
    return '''
    <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=$clientId"
         crossorigin="anonymous"></script>
    ''';
  }

  /// Configuración para anuncios de prueba (desarrollo)
  static Map<String, String> get testConfiguration => {
        'clientId': 'ca-pub-3940256099942544', // Test client ID de Google
        'bannerSlot': '6300978111',
        'nativeSlot': '2247696110',
        'fullWidthSlot': '1033173712',
      };

  // ========================================================================
  // INSTRUCCIONES DE CONFIGURACIÓN
  // ========================================================================

  static const String setupInstructions = '''
  PASOS PARA CONFIGURAR ADSENSE:
  
  1. CREAR CUENTA ADSENSE:
     - Ve a https://adsense.google.com
     - Registra tu sitio: $siteUrl
     - Espera la aprobación
  
  2. VERIFICAR SITIO:
     - Añade el código de AdSense al <head> de index.html
     - Verifica la propiedad del sitio
  
  3. CREAR UNIDADES DE ANUNCIO:
     - Banner: 728x90 responsivo
     - Nativo: Fluido responsivo  
     - Ancho completo: Auto responsivo
     - Rectángulo: 300x250
  
  4. ACTUALIZAR CONFIGURACIÓN:
     - Reemplaza clientId con tu ID real
     - Reemplaza cada slot con los IDs de tus unidades
  
  5. PROBAR:
     - Usa flutter build web --release
     - Verifica que aparezcan los anuncios
     - Revisa la consola por errores
  
  IMPORTANTE: 
  - NO uses clicks falsos para probar
  - Los anuncios pueden tardar hasta 24h en aparecer
  - Revisa las políticas de contenido de AdSense
  ''';
}

/// Enum para los tipos de anuncio soportados
enum AdSenseAdType {
  banner('banner'),
  native('native'),
  fullWidth('fullWidth'),
  rectangle('rectangle');

  const AdSenseAdType(this.configKey);
  final String configKey;

  /// Obtiene la configuración de layout para este tipo
  Map<String, dynamic>? get layoutConfig =>
      AdSenseConfig.responsiveLayouts[configKey];
}
