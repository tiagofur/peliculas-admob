import 'dart:async';
import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/logging/logger_factory.dart';
import 'advanced_admob_service.dart';

/// Stub para AdSenseService en plataformas que no son web
///
/// Cuando AdSense no está disponible, delegamos la monetización a AdMob siempre
/// que el SDK nativo esté soportado. Si la plataforma no soporta AdMob todavía
/// (por ejemplo, escritorio), se mantiene el modo degradado con logs
/// informativos.
class AdSenseService {
  factory AdSenseService() => _instance;
  AdSenseService._();
  static final AdSenseService _instance = AdSenseService._();
  static AdSenseService get instance => _instance;

  final AdvancedAdMobService _admobService = AdvancedAdMobService.instance;

  bool _isInitialized = false;
  bool _bridgeAnnounced = false;

  Future<void> _logBridgeInfoOnce({required bool success}) async {
    if (_bridgeAnnounced) return;
    _bridgeAnnounced = true;

    if (success) {
      await LoggerFactory.info(
        'AdSense bridge activo: delegando monetización en AdMob para plataformas no web.',
        data: {
          'platform': Platform.operatingSystem,
          'bridge': 'adsense_to_admob',
        },
      );
    } else {
      await LoggerFactory.warning(
        'AdSense bridge no disponible: se mantiene modo degradado sin anuncios.',
        data: {
          'platform': Platform.operatingSystem,
          'bridge': 'adsense_to_admob',
        },
      );
    }
  }

  bool get isInitialized => _isInitialized;

  Future<void> initialize({String? publisherId}) async {
    if (_isInitialized) {
      return;
    }

    try {
      final success = await _admobService.initialize();
      if (!success) {
        await _logBridgeInfoOnce(success: false);
        return;
      }

      _isInitialized = true;
      await _logBridgeInfoOnce(success: true);
    } catch (error, stackTrace) {
      await LoggerFactory.error(
        'Error inicializando bridge AdSense->AdMob: $error',
        data: {
          'platform': Platform.operatingSystem,
          'bridge': 'adsense_to_admob',
        },
        stackTrace: stackTrace,
      );
      await _logBridgeInfoOnce(success: false);
    }
  }

  bool isAdSenseReady() => false;

  bool canShowBannerAd() {
    if (!_isInitialized) {
      return false;
    }

    return _admobService.hasBannerAd;
  }

  bool canShowInterstitialAd() {
    if (!_isInitialized) {
      return false;
    }

    return _admobService.hasInterstitialAd;
  }

  Future<bool> showInterstitialAd({String? context}) async {
    if (!_isInitialized) {
      await LoggerFactory.warning(
        'AdSense bridge intentó mostrar interstitial sin inicializar.',
        data: {
          'platform': Platform.operatingSystem,
          'bridge': 'adsense_to_admob',
          'context': context,
        },
      );
      return false;
    }

    return _admobService.showInterstitialAdSmart(context: context);
  }

  Future<bool> showRewardedAd({
    required Function(AdSenseReward) onRewardEarned,
    String? context,
  }) async {
    if (!_isInitialized) {
      await LoggerFactory.warning(
        'AdSense bridge intentó mostrar rewarded sin inicializar.',
        data: {
          'platform': Platform.operatingSystem,
          'bridge': 'adsense_to_admob',
          'context': context,
        },
      );
      return false;
    }

    return _admobService.showRewardedAd(
      onUserEarnedReward: (RewardItem reward) {
        onRewardEarned(
          AdSenseReward(
            amount: reward.amount.toInt(),
            type: reward.type,
          ),
        );
      },
      context: context,
    );
  }

  AdSenseMetrics getMetrics() {
    final metrics = _admobService.getAdMetrics();

    return AdSenseMetrics(
      isInitialized: _isInitialized,
      hasActiveBanner: metrics.hasBannerLoaded,
      hasActiveInterstitial: metrics.hasInterstitialLoaded,
      hasActiveRewarded: metrics.hasRewardedLoaded,
      totalAdsCreated: 0,
      activeAdsCount: 0,
    );
  }

  Future<void> dispose() async {
    if (_isInitialized) {
      _admobService.dispose();
    }
    _isInitialized = false;
    _bridgeAnnounced = false;
  }
}

class AdSenseMetrics {
  const AdSenseMetrics({
    required this.isInitialized,
    required this.hasActiveBanner,
    required this.hasActiveInterstitial,
    required this.hasActiveRewarded,
    required this.totalAdsCreated,
    required this.activeAdsCount,
    this.impressions = 0,
    this.clicks = 0,
    this.estimatedRevenue = 0.0,
    this.publisherId,
  });

  final bool isInitialized;
  final bool hasActiveBanner;
  final bool hasActiveInterstitial;
  final bool hasActiveRewarded;
  final int totalAdsCreated;
  final int activeAdsCount;
  final int impressions;
  final int clicks;
  final double estimatedRevenue;
  final String? publisherId;
}

class AdSenseReward {
  const AdSenseReward({
    required this.amount,
    required this.type,
  });

  final int amount;
  final String type;
}
