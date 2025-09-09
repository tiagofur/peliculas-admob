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
    final platformKey = _providerIds[provider.providerId];
    if (platformKey == null) {
      return provider.link ?? _baseUrls.values.first;
    }

    final baseUrl = _baseUrls[platformKey];
    if (baseUrl == null) {
      return provider.link ?? '';
    }

    switch (platformKey) {
      case 'netflix':
        // Netflix no tiene programa de afiliados público, solo enlace directo
        return baseUrl;

      case 'amazon_prime':
        if (_amazonAffiliateId != null && imdbId != null) {
          return '$baseUrl/$imdbId?tag=$_amazonAffiliateId';
        }
        return baseUrl;

      case 'disney_plus':
        if (_disneyAffiliateId != null) {
          return '$baseUrl?affiliate_id=$_disneyAffiliateId';
        }
        return baseUrl;

      case 'hbo_max':
        if (_hboMaxAffiliateId != null) {
          return '$baseUrl?ref=$_hboMaxAffiliateId';
        }
        return baseUrl;

      case 'paramount':
        if (_paramountAffiliateId != null) {
          return '$baseUrl?partner=$_paramountAffiliateId';
        }
        return baseUrl;

      case 'apple_tv':
        if (_appleTvAffiliateId != null) {
          return '$baseUrl?at=$_appleTvAffiliateId';
        }
        return baseUrl;

      default:
        return provider.link ?? baseUrl;
    }
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
