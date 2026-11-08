/// Configuración de monetización optimizada para experiencia de usuario
/// Este archivo define las mejores prácticas para mostrar anuncios sin afectar negativamente la UX
library;

import '../../core/logging/logger_factory.dart';
import '../../services/monetization/user_monetization_preferences_service.dart';

/// Estrategia de monetización enfocada en la satisfacción del usuario
class UXFirstMonetizationStrategy {
  UXFirstMonetizationStrategy._();
  static UXFirstMonetizationStrategy? _instance;

  static UXFirstMonetizationStrategy get instance {
    _instance ??= UXFirstMonetizationStrategy._();
    return _instance!;
  }

  /// Configuración base para todos los tipos de anuncios
  static const UXMonetizationRules _baseRules = UXMonetizationRules(
    // PRINCIPIO 1: Menos es más - La calidad de los usuarios es más importante que la cantidad de impresiones
    maxInterstitialsPerSession:
        2, // Máximo 2 intersticiales por sesión completa
    maxInterstitialsPerHour: 1, // Solo 1 intersticial por hora
    minTimeBetweenInterstitials:
        Duration(minutes: 10), // Mínimo 10 minutos entre intersticiales

    // PRINCIPIO 2: Respetar el flujo natural del usuario
    bannersMaxPerScreen: 1, // Solo 1 banner por pantalla
    nativeAdsInterval: 8, // Anuncios nativos cada 8 elementos en listas
    firstNativeAdPosition: 4, // Primer anuncio nativo después del 4to elemento

    // PRINCIPIO 3: Dar control al usuario
    allowUserToDisableAds:
        true, // Permitir desactivar anuncios (versión premium)
    respectDoNotTrack: true, // Respetar configuración DNT
    respectUserConsent: true, // Respetar consentimiento GDPR/CCPA

    // PRINCIPIO 4: Ser transparente
    alwaysLabelAds: true, // Siempre etiquetar contenido publicitario
    useNativeAdLabeling:
        true, // Usar etiquetas apropiadas ("Patrocinado", "Anuncio", etc.)

    // PRINCIPIO 5: Optimizar para retención
    disableAdsForNewUsers:
        true, // No mostrar anuncios a usuarios nuevos los primeros días
    newUserGracePeriod:
        Duration(days: 3), // 3 días sin anuncios para nuevos usuarios
    reducedAdsForPowerUsers: true, // Menos anuncios para usuarios muy activos

    // PRINCIPIO 6: Contextualidad y relevancia
    respectAppContext: true, // No mostrar anuncios en momentos críticos
    avoidAdsInCriticalFlows:
        true, // No interrumpir flujos importantes (login, payment, etc.)

    // PRINCIPIO 7: Performance first
    preloadAdsInBackground: true, // Precargar anuncios para evitar delays
    timeoutForAdLoad:
        Duration(seconds: 3), // Timeout corto para carga de anuncios
    fallbackToContent:
        true, // Mostrar contenido si los anuncios no cargan rápido
  );

  /// Reglas específicas por tipo de anuncio
  final Map<AdTypeUX, AdTypeRules> _adTypeRules = {
    AdTypeUX.banner: const AdTypeRules(
      enabled: true,
      maxPerSession: 20, // Banners son menos intrusivos
      respectScrollPosition: true, // Posicionar inteligentemente
      stickyBehavior: StickyBehavior
          .topOnly, // Solo sticky en la parte superior si es necesario
      minViewportVisibility: 0.7, // 70% visible para contar como impresión
    ),
    AdTypeUX.interstitial: const AdTypeRules(
      enabled: true,
      maxPerSession: 2, // MUY limitado - solo en transiciones naturales
      showOnlyAfterUserAction: true, // Solo después de acciones del usuario
      contextualTriggers: [
        'movie_detail_viewed', // Después de ver detalles de película
        'search_completed', // Después de una búsqueda exitosa
        'list_created', // Después de crear una lista
      ],
      avoidInFlows: [
        'authentication', // Nunca durante login/register
        'first_time_setup', // Nunca durante onboarding
        'error_state', // Nunca durante errores
        'loading_state', // Nunca durante carga de contenido crítico
      ],
    ),
    AdTypeUX.rewarded: const AdTypeRules(
      enabled: true,
      maxPerSession: 10, // Usuario-iniciado, más permisivo
      requireUserConsent: true, // Siempre requerir consentimiento explícito
      clearValueProposition: true, // Explicar claramente la recompensa
      contextualOffers: [
        'unlock_premium_content', // Desbloquear contenido premium
        'remove_ads_temporarily', // Remover anuncios por un tiempo
        'extra_recommendations', // Más recomendaciones personalizadas
        'early_access_features', // Acceso temprano a funciones
      ],
    ),
    AdTypeUX.native: const AdTypeRules(
      enabled: true,
      maxPerSession: 30, // Nativos son menos intrusivos
      blendWithContent: true, // Integrar naturalmente con el contenido
      respectContentDensity: true, // Más ads si hay más contenido
      dynamicSpacing: true, // Espaciado dinámico basado en engagement
    ),
  };

  /// Configuración específica para diferentes tipos de usuarios
  final Map<UserTypeUX, UXMonetizationRules> _userTypeOverrides = {
    UserTypeUX.newUser: const UXMonetizationRules(
      maxInterstitialsPerSession: 0, // Sin intersticiales para nuevos usuarios
      maxInterstitialsPerHour: 0,
      bannersMaxPerScreen: 0, // Sin banners inicialmente
      nativeAdsInterval: 0, // Sin anuncios nativos
      newUserGracePeriod: Duration(days: 3),
    ),

    UserTypeUX.casualUser: _baseRules, // Usar configuración base

    UserTypeUX.powerUser: const UXMonetizationRules(
      maxInterstitialsPerSession:
          1, // Menos intersticiales para usuarios activos
      maxInterstitialsPerHour: 0, // Muy restrictivo
      minTimeBetweenInterstitials:
          Duration(minutes: 30), // Más tiempo entre anuncios
      nativeAdsInterval: 12, // Menos anuncios nativos
      respectDoNotTrack: true,
    ),

    UserTypeUX.premiumUser: const UXMonetizationRules(
      maxInterstitialsPerSession: 0, // Sin anuncios para usuarios premium
      maxInterstitialsPerHour: 0,
      bannersMaxPerScreen: 0,
      nativeAdsInterval: 0,
      allowUserToDisableAds: true,
    ),
  };

  /// Obtiene las reglas UX para un tipo de usuario específico
  UXMonetizationRules getRulesForUser(UserTypeUX userType) {
    return _userTypeOverrides[userType] ?? _baseRules;
  }

  /// Obtiene las reglas para un tipo de anuncio específico
  AdTypeRules getRulesForAdType(AdTypeUX adType) {
    return _adTypeRules[adType] ?? const AdTypeRules(enabled: false);
  }

  /// Evalúa si se debe mostrar un anuncio basado en el contexto completo
  Future<AdDecisionResult> shouldShowAd({
    required AdTypeUX adType,
    required UserTypeUX userType,
    required AppContextUX appContext,
    Map<String, dynamic>? additionalContext,
  }) async {
    try {
      // 1. Verificar reglas de usuario
      final userRules = getRulesForUser(userType);
      if (!await _checkUserRules(userRules, adType)) {
        return AdDecisionResult.blockedByUserRules;
      }

      // 2. Verificar reglas de tipo de anuncio
      final adTypeRules = getRulesForAdType(adType);
      if (!adTypeRules.enabled) {
        return AdDecisionResult.adTypeDisabled;
      }

      // 3. Verificar contexto de aplicación
      if (!_checkAppContext(appContext, adTypeRules)) {
        return AdDecisionResult.blockedByAppContext;
      }

      // 4. Verificar límites de frecuencia
      if (!_checkFrequencyLimits(adType, userRules)) {
        return AdDecisionResult.blockedByFrequencyLimits;
      }

      // 5. Verificar consentimiento y privacidad
      if (!_checkPrivacyConsent(userRules, additionalContext)) {
        return AdDecisionResult.blockedByPrivacySettings;
      }

      LoggerFactory.debug(
          'Anuncio $adType aprobado para usuario $userType en contexto $appContext');
      return AdDecisionResult.approved;
    } catch (e) {
      LoggerFactory.error('Error evaluando decisión de anuncio: $e');
      return AdDecisionResult.error;
    }
  }

  Future<bool> _checkUserRules(
      UXMonetizationRules rules, AdTypeUX adType) async {
    // Verificar período de gracia para nuevos usuarios
    if (rules.newUserGracePeriod != null) {
      if (await _isNewUser() && rules.disableAdsForNewUsers) {
        LoggerFactory.debug(
            'Anuncio bloqueado: usuario nuevo en período de gracia');
        return false;
      }
    }

    // Verificar límites específicos del tipo de anuncio
    switch (adType) {
      case AdTypeUX.interstitial:
        return rules.maxInterstitialsPerSession > 0;
      case AdTypeUX.banner:
        return rules.bannersMaxPerScreen > 0;
      case AdTypeUX.native:
        return rules.nativeAdsInterval > 0;
      case AdTypeUX.rewarded:
        return true; // Los anuncios de recompensa son siempre permitidos si el usuario los solicita
    }
  }

  bool _checkAppContext(AppContextUX context, AdTypeRules rules) {
    // Verificar flujos críticos donde no se deben mostrar anuncios
    final criticalFlows = [
      AppContextUX.authentication,
      AppContextUX.firstTimeSetup,
      AppContextUX.errorState,
      AppContextUX.loadingCritical,
    ];

    if (criticalFlows.contains(context)) {
      LoggerFactory.debug('Anuncio bloqueado por contexto crítico: $context');
      return false;
    }

    return true;
  }

  bool _checkFrequencyLimits(AdTypeUX adType, UXMonetizationRules rules) {
    try {
      final now = DateTime.now();
      final frequencyTracker = _getFrequencyTracker();

      switch (adType) {
        case AdTypeUX.interstitial:
          // Verificar límites por sesión
          if (frequencyTracker.interstitialsThisSession >=
              rules.maxInterstitialsPerSession) {
            LoggerFactory.debug(
                'Límite de intersticiales por sesión alcanzado');
            return false;
          }

          // Verificar tiempo mínimo entre anuncios
          final lastInterstitial = frequencyTracker.lastInterstitialTime;
          if (lastInterstitial != null) {
            final timeSinceLastAd = now.difference(lastInterstitial);
            if (timeSinceLastAd < rules.minTimeBetweenInterstitials) {
              LoggerFactory.debug(
                  'Tiempo mínimo entre intersticiales no cumplido');
              return false;
            }
          }
          break;

        case AdTypeUX.banner:
        case AdTypeUX.native:
        case AdTypeUX.rewarded:
          // Los demás tipos tienen menos restricciones de frecuencia
          break;
      }

      return true;
    } catch (e) {
      LoggerFactory.error('Error verificando límites de frecuencia: $e');
      return true; // En caso de error, permitir el anuncio
    }
  }

  bool _checkPrivacyConsent(
      UXMonetizationRules rules, Map<String, dynamic>? context) {
    if (!rules.respectUserConsent) return true;

    try {
      // Verificar consentimiento GDPR/CCPA desde el contexto
      final hasConsent = context?['user_consent'] as bool? ?? true;

      // También verificar configuración Do Not Track
      final doNotTrack = context?['do_not_track'] as bool? ?? false;
      if (rules.respectDoNotTrack && doNotTrack) {
        LoggerFactory.debug('Anuncio bloqueado por configuración Do Not Track');
        return false;
      }

      if (!hasConsent) {
        LoggerFactory.debug(
            'Anuncio bloqueado por falta de consentimiento de privacidad');
        return false;
      }

      return true;
    } catch (e) {
      LoggerFactory.error('Error verificando consentimiento de privacidad: $e');
      return true; // En caso de error, permitir el anuncio
    }
  }

  // Métodos auxiliares para tracking de usuarios y frecuencia
  Future<bool> _isNewUser() async {
    try {
      final service = UserMonetizationPreferencesService.instance;
      final userType = await service.getUserType();
      return userType == UserTypeUX.newUser || await service.isInGracePeriod();
    } catch (e) {
      LoggerFactory.warning('Error verificando si es usuario nuevo: $e');
      return false; // Por seguridad, asumir que no es usuario nuevo
    }
  }

  _AdFrequencyTracker _getFrequencyTracker() {
    return _AdFrequencyTracker();
  }

  /// Configuración recomendada para obtener la mejor experiencia de usuario
  static const Map<String, dynamic> recommendedSettings = {
    'philosophy': 'User satisfaction over short-term revenue',
    'principles': [
      'Less is more: Quality users > quantity of impressions',
      'Respect user flow: Never interrupt critical actions',
      'Give control: Allow users to disable ads',
      'Be transparent: Always label sponsored content',
      'Optimize for retention: Happy users spend more long-term',
      'Context matters: Right ad, right time, right place',
      'Performance first: Fast app > ad revenue',
    ],
    'metrics_to_optimize': [
      'User retention (7-day, 30-day)',
      'Session length',
      'User satisfaction score',
      'App store rating',
      'Organic growth rate',
      'Lifetime value per user',
    ],
    'metrics_to_monitor': [
      'Ad click-through rate',
      'Revenue per user',
      'Ad load time',
      'App crash rate during ads',
      'User complaints about ads',
    ],
  };
}

/// Reglas base de monetización UX
class UXMonetizationRules {
  const UXMonetizationRules({
    this.maxInterstitialsPerSession = 2,
    this.maxInterstitialsPerHour = 1,
    this.minTimeBetweenInterstitials = const Duration(minutes: 10),
    this.bannersMaxPerScreen = 1,
    this.nativeAdsInterval = 8,
    this.firstNativeAdPosition = 4,
    this.allowUserToDisableAds = true,
    this.respectDoNotTrack = true,
    this.respectUserConsent = true,
    this.alwaysLabelAds = true,
    this.useNativeAdLabeling = true,
    this.disableAdsForNewUsers = true,
    this.newUserGracePeriod,
    this.reducedAdsForPowerUsers = true,
    this.respectAppContext = true,
    this.avoidAdsInCriticalFlows = true,
    this.preloadAdsInBackground = true,
    this.timeoutForAdLoad = const Duration(seconds: 3),
    this.fallbackToContent = true,
  });

  final int maxInterstitialsPerSession;
  final int maxInterstitialsPerHour;
  final Duration minTimeBetweenInterstitials;
  final int bannersMaxPerScreen;
  final int nativeAdsInterval;
  final int firstNativeAdPosition;
  final bool allowUserToDisableAds;
  final bool respectDoNotTrack;
  final bool respectUserConsent;
  final bool alwaysLabelAds;
  final bool useNativeAdLabeling;
  final bool disableAdsForNewUsers;
  final Duration? newUserGracePeriod;
  final bool reducedAdsForPowerUsers;
  final bool respectAppContext;
  final bool avoidAdsInCriticalFlows;
  final bool preloadAdsInBackground;
  final Duration timeoutForAdLoad;
  final bool fallbackToContent;
}

/// Reglas específicas por tipo de anuncio
class AdTypeRules {
  const AdTypeRules({
    required this.enabled,
    this.maxPerSession = 0,
    this.respectScrollPosition = false,
    this.stickyBehavior = StickyBehavior.none,
    this.minViewportVisibility = 0.5,
    this.showOnlyAfterUserAction = false,
    this.contextualTriggers = const [],
    this.avoidInFlows = const [],
    this.requireUserConsent = false,
    this.clearValueProposition = false,
    this.contextualOffers = const [],
    this.blendWithContent = false,
    this.respectContentDensity = false,
    this.dynamicSpacing = false,
  });

  final bool enabled;
  final int maxPerSession;
  final bool respectScrollPosition;
  final StickyBehavior stickyBehavior;
  final double minViewportVisibility;
  final bool showOnlyAfterUserAction;
  final List<String> contextualTriggers;
  final List<String> avoidInFlows;
  final bool requireUserConsent;
  final bool clearValueProposition;
  final List<String> contextualOffers;
  final bool blendWithContent;
  final bool respectContentDensity;
  final bool dynamicSpacing;
}

/// Tipos de anuncios para UX
enum AdTypeUX {
  banner,
  interstitial,
  rewarded,
  native,
}

/// Tipos de usuarios
enum UserTypeUX {
  newUser, // Usuario nuevo (< 3 días)
  casualUser, // Usuario casual (uso esporádico)
  powerUser, // Usuario avanzado (uso frecuente)
  premiumUser, // Usuario premium (ha pagado)
}

/// Contextos de aplicación
enum AppContextUX {
  browsing, // Navegando películas
  searching, // Buscando contenido
  authentication, // Login/register
  firstTimeSetup, // Onboarding
  errorState, // Error en la aplicación
  loadingCritical, // Cargando contenido crítico
  settingsOrProfile, // Configuraciones o perfil
  socialSharing, // Compartiendo contenido
}

/// Comportamiento de anuncios sticky
enum StickyBehavior {
  none, // No sticky
  topOnly, // Solo en la parte superior
  bottomOnly, // Solo en la parte inferior
  both, // Ambos (no recomendado para UX)
}

/// Resultado de decisión de anuncio
enum AdDecisionResult {
  approved,
  blockedByUserRules,
  adTypeDisabled,
  blockedByAppContext,
  blockedByFrequencyLimits,
  blockedByPrivacySettings,
  error,
}

/// Clase para tracking de frecuencia de anuncios
class _AdFrequencyTracker {
  int get interstitialsThisSession {
    // Por ahora devolvemos un valor por defecto hasta implementar tracking completo
    return 0;
  }

  DateTime? get lastInterstitialTime {
    // Por ahora devolvemos null hasta implementar tracking completo
    return null;
  }

  Future<void> recordInterstitialShown() async {
    try {
      final service = UserMonetizationPreferencesService.instance;
      await service.recordAdInteraction(
          AdInteractionType.viewed, AdTypeUX.interstitial);
      LoggerFactory.debug(
          'Intersticial registrado usando servicio de preferencias');
    } catch (e) {
      LoggerFactory.error('Error registrando intersticial mostrado: $e');
    }
  }

  Future<void> resetSessionCounters() async {
    try {
      LoggerFactory.debug(
          'Reset de contadores de sesión - usando sistema de preferencias');
      // El servicio de preferencias maneja automáticamente las sesiones
    } catch (e) {
      LoggerFactory.error('Error reseteando contadores de sesión: $e');
    }
  }
}
