import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'user_monetization_preferences_service.dart';

/// Servicio avanzado para la gestión de AdMob con optimización de revenue
class AdvancedAdMobService {
  AdvancedAdMobService._();
  static AdvancedAdMobService? _instance;

  static AdvancedAdMobService get instance {
    _instance ??= AdvancedAdMobService._();
    return _instance!;
  }

  // IDs de anuncios (usar IDs de prueba en desarrollo)
  static const String _bannerAdUnitId = kDebugMode
      ? 'ca-app-pub-3940256099942544/6300978111' // Test ID
      : 'ca-app-pub-XXXXXXXXXX/XXXXXXXXXX'; // Production ID

  static const String _interstitialAdUnitId = kDebugMode
      ? 'ca-app-pub-3940256099942544/1033173712' // Test ID
      : 'ca-app-pub-XXXXXXXXXX/XXXXXXXXXX'; // Production ID

  static const String _rewardedAdUnitId = kDebugMode
      ? 'ca-app-pub-3940256099942544/5224354917' // Test ID
      : 'ca-app-pub-XXXXXXXXXX/XXXXXXXXXX'; // Production ID

  // Estado interno
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  bool _isInitialized = false;
  int _interstitialAdCounter = 0;
  DateTime? _lastInterstitialShown;

  // Configuración
  static const int _interstitialShowInterval = 3; // Mostrar cada 3 acciones
  static const Duration _interstitialCooldown = Duration(minutes: 2);

  /// Inicializa el servicio de AdMob
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      if (kIsWeb) {
        debugPrint('🚫 AdMob no está disponible en Web');
        return false;
      }

      await MobileAds.instance.initialize();

      // Configurar configuración de solicitudes
      final requestConfiguration = RequestConfiguration(
        // App de audiencia general: sin señales de tratamiento por edad
        // (migración v9: reemplaza tagForChildDirectedTreatment/tagForUnderAgeOfConsent en .no)
        ageRestrictedTreatment: AgeRestrictedTreatment.unspecified,
        testDeviceIds: kDebugMode ? ['TEST_DEVICE_ID'] : null,
      );

      MobileAds.instance.updateRequestConfiguration(requestConfiguration);

      _isInitialized = true;
      debugPrint('✅ AdMob inicializado correctamente');

      // Pro: solo precargar rewarded opt-in (S3); cero inventario forzado.
      // Sin Pro: precarga completa como antes.
      final isPro =
          await UserMonetizationPreferencesService.instance.isPro();
      if (isPro) {
        await _loadRewardedAd();
      } else {
        await _preloadAds();
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error inicializando AdMob: $e');
      return false;
    }
  }

  /// Pre-carga anuncios para mejor performance
  Future<void> _preloadAds() async {
    await Future.wait([
      _loadBannerAd(),
      _loadInterstitialAd(),
      _loadRewardedAd(),
    ]);
  }

  /// Carga un banner ad
  Future<void> _loadBannerAd() async {
    if (kIsWeb) return;

    try {
      _bannerAd = BannerAd(
        adUnitId: _bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            debugPrint('✅ Banner Ad cargado');
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('❌ Error cargando Banner Ad: $error');
            ad.dispose();
            _bannerAd = null;
          },
          onAdClicked: (ad) {
            _trackAdInteraction('banner_click');
          },
        ),
      );

      await _bannerAd?.load();
    } catch (e) {
      debugPrint('❌ Error creando Banner Ad: $e');
    }
  }

  /// Carga un interstitial ad
  Future<void> _loadInterstitialAd() async {
    if (kIsWeb) return;

    try {
      await InterstitialAd.load(
        adUnitId: _interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            debugPrint('✅ Interstitial Ad cargado');

            _interstitialAd?.fullScreenContentCallback =
                FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                _trackAdInteraction('interstitial_show');
              },
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _interstitialAd = null;
                _loadInterstitialAd(); // Pre-cargar el siguiente
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                debugPrint('❌ Error mostrando Interstitial: $error');
                ad.dispose();
                _interstitialAd = null;
                _loadInterstitialAd(); // Intentar cargar otro
              },
            );
          },
          onAdFailedToLoad: (error) {
            debugPrint('❌ Error cargando Interstitial Ad: $error');
            _interstitialAd = null;
          },
        ),
      );
    } catch (e) {
      debugPrint('❌ Error creando Interstitial Ad: $e');
    }
  }

  /// Carga un rewarded ad
  Future<void> _loadRewardedAd() async {
    if (kIsWeb) return;

    try {
      await RewardedAd.load(
        adUnitId: _rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            debugPrint('✅ Rewarded Ad cargado');

            _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                _trackAdInteraction('rewarded_show');
              },
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _rewardedAd = null;
                _loadRewardedAd(); // Pre-cargar el siguiente
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                debugPrint('❌ Error mostrando Rewarded: $error');
                ad.dispose();
                _rewardedAd = null;
                _loadRewardedAd();
              },
            );
          },
          onAdFailedToLoad: (error) {
            debugPrint('❌ Error cargando Rewarded Ad: $error');
            _rewardedAd = null;
          },
        ),
      );
    } catch (e) {
      debugPrint('❌ Error creando Rewarded Ad: $e');
    }
  }

  /// Widget para mostrar banner ad
  Widget createBannerAdWidget({
    EdgeInsetsGeometry margin = const EdgeInsets.symmetric(vertical: 8),
  }) {
    if (kIsWeb || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: margin,
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }

  /// Muestra un interstitial ad de manera inteligente
  Future<bool> showInterstitialAdSmart({
    bool forceShow = false,
    String? context,
  }) async {
    if (kIsWeb || !_isInitialized) return false;

    // Pro: nunca intersticiales, ni siquiera forzados (S1).
    if (await UserMonetizationPreferencesService.instance.isPro()) {
      return false;
    }

    // Ad-break por rewarded: pausa temporal de forzados (S2).
    if (await UserMonetizationPreferencesService.instance.isAdBreakActive()) {
      return false;
    }

    // Verificar si se debe mostrar el anuncio
    if (!forceShow && !_shouldShowInterstitial()) {
      return false;
    }

    if (_interstitialAd == null) {
      debugPrint('⚠️ Interstitial Ad no está listo');
      return false;
    }

    try {
      await _interstitialAd?.show();
      _lastInterstitialShown = DateTime.now();
      _interstitialAdCounter = 0;

      if (context != null) {
        _trackAdInteraction('interstitial_context', context: context);
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error mostrando Interstitial: $e');
      return false;
    }
  }

  /// Muestra un rewarded ad
  Future<bool> showRewardedAd({
    required Function(RewardItem) onUserEarnedReward,
    String? context,
  }) async {
    if (kIsWeb || !_isInitialized) return false;

    if (_rewardedAd == null) {
      debugPrint('⚠️ Rewarded Ad no está listo');
      return false;
    }

    try {
      await _rewardedAd?.show(
        onUserEarnedReward: (ad, reward) {
          _trackAdInteraction('rewarded_earned', context: context);
          onUserEarnedReward(reward);
        },
      );

      return true;
    } catch (e) {
      debugPrint('❌ Error mostrando Rewarded Ad: $e');
      return false;
    }
  }

  /// Incrementa el contador para interstitials inteligentes
  void incrementInterstitialCounter({String? action}) {
    // Pro y ad-break: no acumular triggers (S1, S2). Cache síncrono
    // porque los llamados son contextos void (initState, navegación).
    if (UserMonetizationPreferencesService.isProCached ||
        UserMonetizationPreferencesService.isAdBreakCached) {
      return;
    }

    _interstitialAdCounter++;

    if (action != null) {
      _trackAdInteraction('user_action', context: action);
    }
  }

  /// Determina si se debe mostrar un interstitial
  bool _shouldShowInterstitial() {
    // Verificar cooldown
    if (_lastInterstitialShown != null) {
      final timeSinceLastAd =
          DateTime.now().difference(_lastInterstitialShown!);
      if (timeSinceLastAd < _interstitialCooldown) {
        return false;
      }
    }

    // Verificar contador
    return _interstitialAdCounter >= _interstitialShowInterval;
  }

  /// Verifica si hay anuncios disponibles
  bool get hasBannerAd => _bannerAd != null;
  bool get hasInterstitialAd => _interstitialAd != null;
  bool get hasRewardedAd => _rewardedAd != null;

  /// Obtiene métricas de ads
  AdMetrics getAdMetrics() {
    return AdMetrics(
      hasBannerLoaded: hasBannerAd,
      hasInterstitialLoaded: hasInterstitialAd,
      hasRewardedLoaded: hasRewardedAd,
      interstitialCounter: _interstitialAdCounter,
      lastInterstitialShown: _lastInterstitialShown,
      isInitialized: _isInitialized,
    );
  }

  /// Registra interacciones con anuncios para analytics
  void _trackAdInteraction(String event, {String? context}) {
    if (kDebugMode) {
      debugPrint('📊 Ad Event: $event${context != null ? ' ($context)' : ''}');
    }

    // Aquí se podría integrar con Firebase Analytics
    // FirebaseAnalytics.instance.logEvent(
    //   name: 'ad_interaction',
    //   parameters: {
    //     'ad_event': event,
    //     if (context != null) 'context': context,
    //   },
    // );
  }

  /// Limpia recursos
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();

    _bannerAd = null;
    _interstitialAd = null;
    _rewardedAd = null;

    debugPrint('🧹 AdMob resources disposed');
  }
}

/// Métricas de anuncios
class AdMetrics {
  const AdMetrics({
    required this.hasBannerLoaded,
    required this.hasInterstitialLoaded,
    required this.hasRewardedLoaded,
    required this.interstitialCounter,
    required this.lastInterstitialShown,
    required this.isInitialized,
  });
  final bool hasBannerLoaded;
  final bool hasInterstitialLoaded;
  final bool hasRewardedLoaded;
  final int interstitialCounter;
  final DateTime? lastInterstitialShown;
  final bool isInitialized;

  @override
  String toString() {
    return 'AdMetrics('
        'initialized: $isInitialized, '
        'banner: $hasBannerLoaded, '
        'interstitial: $hasInterstitialLoaded, '
        'rewarded: $hasRewardedLoaded, '
        'counter: $interstitialCounter)';
  }
}
