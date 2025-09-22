import '../entities/watch_provider.dart';

class AffiliateService {
  // API Keys para plataformas de afiliados (se cargarán desde .env)
  static String? _amazonAffiliateId;
  static String? _disneyAffiliateId;
  static String? _hboMaxAffiliateId;
  static String? _paramountAffiliateId;
  static String? _appleTvAffiliateId;

  // IDs de proveedores de TMDB para cada plataforma
  static const Map<int, String> _providerIds = {
    8: 'netflix', // Netflix
    119: 'amazon_prime', // Amazon Prime Video
    337: 'disney_plus', // Disney+
    384: 'hbo_max', // HBO Max
    531: 'paramount', // Paramount+
    350: 'apple_tv', // Apple TV+
  };

  // URLs base para cada plataforma
  static const Map<String, String> _baseUrls = {
    'netflix': 'https://www.netflix.com',
    'amazon_prime': 'https://www.amazon.com/gp/video/detail',
    'disney_plus': 'https://www.disneyplus.com',
    'hbo_max': 'https://www.hbomax.com',
    'paramount': 'https://www.paramountplus.com',
    'apple_tv': 'https://tv.apple.com',
  };

  /// Inicializa el servicio con las API keys desde variables de entorno
  static void initialize({
    String? amazonAffiliateId,
    String? disneyAffiliateId,
    String? hboMaxAffiliateId,
    String? paramountAffiliateId,
    String? appleTvAffiliateId,
  }) {
    _amazonAffiliateId = amazonAffiliateId;
    _disneyAffiliateId = disneyAffiliateId;
    _hboMaxAffiliateId = hboMaxAffiliateId;
    _paramountAffiliateId = paramountAffiliateId;
    _appleTvAffiliateId = appleTvAffiliateId;
  }

  /// Genera un enlace de afiliado para un proveedor específico
  static String generateAffiliateLink(
    WatchProvider provider, {
    String? movieTitle,
    String? imdbId,
    String country = 'MX',
  }) {
    // PRIMERA PRIORIDAD: Usar el link directo de TMDB si está disponible
    if (provider.link != null && provider.link!.isNotEmpty) {
      return _enhanceWithAffiliateParams(provider.link!, provider.providerId);
    }

    // SEGUNDA PRIORIDAD: Generar URL basada en la plataforma conocida
    final platformKey = _providerIds[provider.providerId];
    if (platformKey == null) {
      // Plataforma no reconocida, usar URL genérica de búsqueda
      return _generateSearchUrl(provider.providerName, movieTitle);
    }

    final baseUrl = _baseUrls[platformKey];
    if (baseUrl == null) {
      return _generateSearchUrl(provider.providerName, movieTitle);
    }

    return _generatePlatformUrl(platformKey, baseUrl, movieTitle, imdbId);
  }

  /// Mejora un URL existente con parámetros de afiliado si es posible
  static String _enhanceWithAffiliateParams(String originalUrl, int providerId) {
    final platformKey = _providerIds[providerId];

    switch (platformKey) {
      case 'amazon_prime':
        if (_amazonAffiliateId != null && !originalUrl.contains('tag=')) {
          final separator = originalUrl.contains('?') ? '&' : '?';
          return '$originalUrl${separator}tag=$_amazonAffiliateId';
        }
        break;

      case 'disney_plus':
        if (_disneyAffiliateId != null && !originalUrl.contains('affiliate_id=')) {
          final separator = originalUrl.contains('?') ? '&' : '?';
          return '$originalUrl${separator}affiliate_id=$_disneyAffiliateId';
        }
        break;

      case 'apple_tv':
        if (_appleTvAffiliateId != null && !originalUrl.contains('at=')) {
          final separator = originalUrl.contains('?') ? '&' : '?';
          return '$originalUrl${separator}at=$_appleTvAffiliateId';
        }
        break;
    }

    return originalUrl; // Devolver URL original si no se puede mejorar
  }

  /// Genera URL para plataformas conocidas
  static String _generatePlatformUrl(String platformKey, String baseUrl, String? movieTitle, String? imdbId) {
    switch (platformKey) {
      case 'netflix':
        return baseUrl;

      case 'amazon_prime':
        if (imdbId != null) {
          final url = '$baseUrl/$imdbId';
          return _amazonAffiliateId != null ? '$url?tag=$_amazonAffiliateId' : url;
        }
        return baseUrl;

      case 'disney_plus':
        return _disneyAffiliateId != null
            ? '$baseUrl?affiliate_id=$_disneyAffiliateId'
            : baseUrl;

      case 'hbo_max':
        return _hboMaxAffiliateId != null
            ? '$baseUrl?ref=$_hboMaxAffiliateId'
            : baseUrl;

      case 'paramount':
        return _paramountAffiliateId != null
            ? '$baseUrl?partner=$_paramountAffiliateId'
            : baseUrl;

      case 'apple_tv':
        return _appleTvAffiliateId != null
            ? '$baseUrl?at=$_appleTvAffiliateId'
            : baseUrl;

      default:
        return baseUrl;
    }
  }

  /// Genera URL de búsqueda genérica para plataformas no reconocidas
  static String _generateSearchUrl(String providerName, String? movieTitle) {
    if (movieTitle == null || movieTitle.isEmpty) {
      return 'https://www.google.com/search?q=${Uri.encodeComponent(providerName)}';
    }

    final searchQuery = Uri.encodeComponent('$providerName $movieTitle movie watch');
    return 'https://www.google.com/search?q=$searchQuery';
  }

  /// Verifica si una plataforma tiene soporte para enlaces de afiliados
  static bool hasAffiliateSupport(int providerId) {
    final platformKey = _providerIds[providerId];
    if (platformKey == null) return false;

    switch (platformKey) {
      case 'netflix':
        return false; // Netflix no tiene programa de afiliados público
      case 'amazon_prime':
        return _amazonAffiliateId != null;
      case 'disney_plus':
        return _disneyAffiliateId != null;
      case 'hbo_max':
        return _hboMaxAffiliateId != null;
      case 'paramount':
        return _paramountAffiliateId != null;
      case 'apple_tv':
        return _appleTvAffiliateId != null;
      default:
        return false;
    }
  }

  /// Obtiene el nombre de la plataforma por su ID
  static String? getPlatformName(int providerId) {
    return _providerIds[providerId];
  }

  /// Obtiene todos los proveedores soportados
  static List<int> getSupportedProviders() {
    return _providerIds.keys.toList();
  }

  /// Genera un enlace de atribución a JustWatch
  static String getJustWatchAttributionLink() {
    return 'https://www.justwatch.com';
  }

  /// Obtiene el texto de atribución requerido
  static String getAttributionText() {
    return 'Datos de disponibilidad proporcionados por JustWatch';
  }
}
