import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../config/monetization/ux_first_monetization_strategy.dart';
import '../../core/logging/logger_factory.dart';
import '../analytics/analytics_manager.dart';
// Conditional import para AdSense (solo web)
import 'adsense_service.dart' if (dart.library.io) 'adsense_service_stub.dart';
import 'advanced_admob_service.dart';
import 'user_monetization_preferences_service.dart';

/// Gestor de monetización adaptativo que usa AdMob en móviles y AdSense en web/desktop
/// con enfoque prioritario en la experiencia de usuario
class AdaptiveMonetizationManager {
  AdaptiveMonetizationManager._();
  static AdaptiveMonetizationManager? _instance;

  static AdaptiveMonetizationManager get instance {
    _instance ??= AdaptiveMonetizationManager._();
    return _instance!;
  }

  bool _isInitialized = false;
  late MonetizationPlatform _currentPlatform;

  // Servicios específicos por plataforma
  AdvancedAdMobService? _admobService;
  AdSenseService? _adsenseService;

  // Estrategia UX-first
  final UXFirstMonetizationStrategy _uxStrategy =
      UXFirstMonetizationStrategy.instance;
  final UserMonetizationPreferencesService _userPrefs =
      UserMonetizationPreferencesService.instance;

  /// Inicializa el sistema de monetización adaptativo
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _currentPlatform = _detectPlatform();
      LoggerFactory.info(
          'Inicializando monetización para plataforma: $_currentPlatform');

      // Inicializar servicio de preferencias de usuario
      await _userPrefs.initialize();

      switch (_currentPlatform) {
        case MonetizationPlatform.mobile:
          _admobService = AdvancedAdMobService.instance;
          final admobResult = await _admobService!.initialize();
          if (!admobResult) {
            LoggerFactory.warning('AdMob falló al inicializar');
            return false;
          }
          break;

        case MonetizationPlatform.web:
        case MonetizationPlatform.desktop:
          _adsenseService = AdSenseService.instance;
          await _adsenseService!.initialize();
          break;
      }

      _isInitialized = true;
      LoggerFactory.info('Sistema de monetización inicializado exitosamente');

      // Registrar sesión de usuario
      await _userPrefs.recordUserSession();

      // Registrar inicialización en analytics
      AnalyticsManager.instance.logAdInteraction(
        adType: 'system',
        action: 'initialized',
        context: _currentPlatform.toString(),
      );

      return true;
    } catch (e) {
      LoggerFactory.error('Error inicializando sistema de monetización: $e');
      return false;
    }
  }

  /// Detecta la plataforma actual para monetización
  MonetizationPlatform _detectPlatform() {
    if (kIsWeb) {
      return MonetizationPlatform.web;
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return MonetizationPlatform.desktop;
    } else {
      return MonetizationPlatform.mobile;
    }
  }

  /// Obtiene la plataforma de monetización actual
  MonetizationPlatform get currentPlatform => _currentPlatform;

  /// Verifica si el sistema está inicializado
  bool get isInitialized => _isInitialized;

  /// Verifica si la monetización está disponible en la plataforma actual
  bool get isMonetizationAvailable {
    if (!_isInitialized) return false;

    switch (_currentPlatform) {
      case MonetizationPlatform.mobile:
        return _admobService?.getAdMetrics().isInitialized ?? false;
      case MonetizationPlatform.web:
      case MonetizationPlatform.desktop:
        return _adsenseService?.isInitialized ?? false;
    }
  }

  /// Verifica si se puede mostrar un anuncio banner
  Future<bool> canShowBannerAd(
      {AppContextUX context = AppContextUX.browsing}) async {
    if (!isMonetizationAvailable) return false;

    // Evaluar con estrategia UX-first
    final userType = await _userPrefs.getUserType();
    final decision = await _uxStrategy.shouldShowAd(
      adType: AdTypeUX.banner,
      userType: userType,
      appContext: context,
    );

    if (decision != AdDecisionResult.approved) {
      LoggerFactory.debug('Banner ad bloqueado: $decision');
      return false;
    }

    switch (_currentPlatform) {
      case MonetizationPlatform.mobile:
        return _admobService?.hasBannerAd ?? false;
      case MonetizationPlatform.web:
      case MonetizationPlatform.desktop:
        return _adsenseService?.canShowBannerAd() ?? false;
    }
  }

  /// Verifica si se puede mostrar un anuncio intersticial
  Future<bool> canShowInterstitialAd(
      {AppContextUX context = AppContextUX.browsing}) async {
    if (!isMonetizationAvailable) return false;

    // Evaluar con estrategia UX-first (más estricta para intersticiales)
    final userType = await _userPrefs.getUserType();
    final decision = await _uxStrategy.shouldShowAd(
      adType: AdTypeUX.interstitial,
      userType: userType,
      appContext: context,
    );

    if (decision != AdDecisionResult.approved) {
      LoggerFactory.debug('Intersticial ad bloqueado: $decision');
      return false;
    }

    switch (_currentPlatform) {
      case MonetizationPlatform.mobile:
        return _admobService?.hasInterstitialAd ?? false;
      case MonetizationPlatform.web:
      case MonetizationPlatform.desktop:
        return _adsenseService?.canShowInterstitialAd() ?? false;
    }
  }

  /// Muestra un anuncio intersticial con límites UX
  Future<bool> showInterstitialAd({
    String? context,
    AppContextUX appContext = AppContextUX.browsing,
  }) async {
    final canShow = await canShowInterstitialAd(context: appContext);
    if (!canShow) return false;

    try {
      bool result = false;

      switch (_currentPlatform) {
        case MonetizationPlatform.mobile:
          result =
              await _admobService!.showInterstitialAdSmart(context: context);
          break;
        case MonetizationPlatform.web:
        case MonetizationPlatform.desktop:
          result = await _adsenseService!.showInterstitialAd(context: context);
          break;
      }

      if (result) {
        // Registrar interacción con anuncio
        await _userPrefs.recordAdInteraction(
          AdInteractionType.viewed,
          AdTypeUX.interstitial,
        );

        // Analytics
        AnalyticsManager.instance.logAdInteraction(
          adType: 'interstitial',
          action: 'shown',
          context: context,
        );
      }

      return result;
    } catch (e) {
      LoggerFactory.error('Error mostrando anuncio intersticial: $e');
      return false;
    }
  }

  /// Muestra un anuncio de recompensa (siempre permitido - usuario lo solicita)
  Future<bool> showRewardedAd({
    required Function(UnifiedRewardItem) onRewardEarned,
    String? context,
    AppContextUX appContext = AppContextUX.browsing,
  }) async {
    if (!isMonetizationAvailable) return false;

    // Los anuncios de recompensa siempre están permitidos (usuario los solicita)
    final userType = await _userPrefs.getUserType();
    final decision = await _uxStrategy.shouldShowAd(
      adType: AdTypeUX.rewarded,
      userType: userType,
      appContext: appContext,
    );

    if (decision != AdDecisionResult.approved) {
      LoggerFactory.warning('Rewarded ad bloqueado inesperadamente: $decision');
      return false;
    }

    try {
      bool result = false;

      switch (_currentPlatform) {
        case MonetizationPlatform.mobile:
          result = await _admobService!.showRewardedAd(
            onUserEarnedReward: (reward) {
              final unifiedReward = UnifiedRewardItem.fromAdMob(reward);
              onRewardEarned(unifiedReward);
            },
            context: context,
          );
          break;
        case MonetizationPlatform.web:
        case MonetizationPlatform.desktop:
          result = await _adsenseService!.showRewardedAd(
            onRewardEarned: (reward) {
              final unifiedReward = UnifiedRewardItem.fromAdSense(reward);
              onRewardEarned(unifiedReward);
            },
            context: context,
          );
          break;
      }

      if (result) {
        // Registrar interacción positiva con anuncio
        await _userPrefs.recordAdInteraction(
          AdInteractionType.completed,
          AdTypeUX.rewarded,
        );

        // Analytics
        AnalyticsManager.instance.logAdInteraction(
          adType: 'rewarded',
          action: 'completed',
          context: context,
        );
      }

      return result;
    } catch (e) {
      LoggerFactory.error('Error mostrando anuncio de recompensa: $e');
      return false;
    }
  }

  /// Obtiene métricas de monetización unificadas
  UnifiedAdMetrics getMetrics() {
    switch (_currentPlatform) {
      case MonetizationPlatform.mobile:
        final admobMetrics = _admobService?.getAdMetrics();
        return UnifiedAdMetrics.fromAdMob(admobMetrics);

      case MonetizationPlatform.web:
      case MonetizationPlatform.desktop:
        final adsenseMetrics = _adsenseService?.getMetrics();
        return UnifiedAdMetrics.fromAdSense(adsenseMetrics);
    }
  }

  /// Obtiene las preferencias actuales del usuario
  Future<UserMonetizationPreferences> getUserPreferences() async {
    return await _userPrefs.getUserPreferences();
  }

  /// Obtiene estadísticas de uso del usuario
  Future<UserUsageStats> getUserUsageStats() async {
    return await _userPrefs.getUserUsageStats();
  }

  /// Permite al usuario actualizar sus preferencias de anuncios
  Future<void> updateUserAdPreference(
      AdPreferenceType type, bool enabled) async {
    await _userPrefs.updateAdPreference(type, enabled);
  }

  /// Libera recursos
  Future<void> dispose() async {
    try {
      _admobService?.dispose();
      await _adsenseService?.dispose();
      _isInitialized = false;
      LoggerFactory.info('Sistema de monetización disposed');
    } catch (e) {
      LoggerFactory.error('Error disposing sistema de monetización: $e');
    }
  }
}

/// Plataformas de monetización soportadas
enum MonetizationPlatform {
  mobile, // Android/iOS - usa AdMob
  web, // Web - usa AdSense
  desktop, // Windows/macOS/Linux - usa AdSense
}

/// Tipos de anuncios unificados (mantenido para compatibilidad)
enum AdType {
  banner,
  interstitial,
  rewarded,
  native,
}

/// Métricas unificadas de monetización
class UnifiedAdMetrics {
  const UnifiedAdMetrics({
    required this.platform,
    required this.isInitialized,
    required this.hasActiveBanner,
    required this.hasActiveInterstitial,
    required this.hasActiveRewarded,
    this.impressions = 0,
    this.clicks = 0,
    this.estimatedRevenue = 0.0,
  });

  factory UnifiedAdMetrics.fromAdMob(dynamic admobMetrics) {
    if (admobMetrics == null) {
      return const UnifiedAdMetrics(
        platform: MonetizationPlatform.mobile,
        isInitialized: false,
        hasActiveBanner: false,
        hasActiveInterstitial: false,
        hasActiveRewarded: false,
      );
    }

    return UnifiedAdMetrics(
      platform: MonetizationPlatform.mobile,
      isInitialized: admobMetrics.isInitialized ?? false,
      hasActiveBanner: admobMetrics.hasBannerLoaded ?? false,
      hasActiveInterstitial: admobMetrics.hasInterstitialLoaded ?? false,
      hasActiveRewarded: admobMetrics.hasRewardedLoaded ?? false,
    );
  }

  factory UnifiedAdMetrics.fromAdSense(dynamic adsenseMetrics) {
    if (adsenseMetrics == null) {
      return const UnifiedAdMetrics(
        platform: MonetizationPlatform.web,
        isInitialized: false,
        hasActiveBanner: false,
        hasActiveInterstitial: false,
        hasActiveRewarded: false,
      );
    }

    return UnifiedAdMetrics(
      platform: MonetizationPlatform.web,
      isInitialized: adsenseMetrics.isInitialized ?? false,
      hasActiveBanner: adsenseMetrics.hasActiveBanner ?? false,
      hasActiveInterstitial: adsenseMetrics.hasActiveInterstitial ?? false,
      hasActiveRewarded: adsenseMetrics.hasActiveRewarded ?? false,
      impressions: adsenseMetrics.impressions ?? 0,
      clicks: adsenseMetrics.clicks ?? 0,
      estimatedRevenue: adsenseMetrics.estimatedRevenue ?? 0.0,
    );
  }

  final MonetizationPlatform platform;
  final bool isInitialized;
  final bool hasActiveBanner;
  final bool hasActiveInterstitial;
  final bool hasActiveRewarded;
  final int impressions;
  final int clicks;
  final double estimatedRevenue;

  Map<String, dynamic> toJson() => {
        'platform': platform.toString(),
        'isInitialized': isInitialized,
        'hasActiveBanner': hasActiveBanner,
        'hasActiveInterstitial': hasActiveInterstitial,
        'hasActiveRewarded': hasActiveRewarded,
        'impressions': impressions,
        'clicks': clicks,
        'estimatedRevenue': estimatedRevenue,
      };
}

/// Elemento de recompensa unificado entre AdMob y AdSense
class UnifiedRewardItem {
  const UnifiedRewardItem({
    required this.amount,
    required this.type,
  });

  factory UnifiedRewardItem.fromAdMob(dynamic admobReward) {
    return UnifiedRewardItem(
      amount: admobReward?.amount?.toInt() ?? 0,
      type: admobReward?.type ?? 'points',
    );
  }

  factory UnifiedRewardItem.fromAdSense(AdSenseReward adsenseReward) {
    return UnifiedRewardItem(
      amount: adsenseReward.amount,
      type: adsenseReward.type,
    );
  }

  final int amount;
  final String type;

  @override
  String toString() => 'UnifiedRewardItem(amount: $amount, type: $type)';
}
