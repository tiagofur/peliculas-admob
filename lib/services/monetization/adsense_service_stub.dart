import 'dart:async';

import '../../core/logging/logger_factory.dart';

/// Stub para AdSenseService en plataformas que no son web
class AdSenseService {
  static AdSenseService get instance => AdSenseService();
  static bool _hasWarned = false;

  void _warnOnce() {
    if (_hasWarned) {
      return;
    }
    _hasWarned = true;

    // TODO(peliculas-admob): Implement AdSense bridge for non-web platforms when supported.
    unawaited(LoggerFactory.warning(
      'AdSenseService stub activo: no hay soporte de AdSense en esta plataforma.',
      data: const {
        'feature': 'adsense_non_web_stub',
        'action': 'skip_monetization',
      },
    ));
  }

  bool get isInitialized => false;

  Future<void> initialize() async {
    // No-op en plataformas no web
    _warnOnce();
  }

  bool canShowBannerAd() {
    _warnOnce();
    return false;
  }

  bool canShowInterstitialAd() {
    _warnOnce();
    return false;
  }

  Future<bool> showInterstitialAd({String? context}) async {
    _warnOnce();
    return false;
  }

  Future<bool> showRewardedAd({
    required Function(AdSenseReward) onRewardEarned,
    String? context,
  }) async {
    _warnOnce();
    return false;
  }

  AdSenseMetrics getMetrics() => const AdSenseMetrics(
        isInitialized: false,
        hasActiveBanner: false,
        hasActiveInterstitial: false,
        hasActiveRewarded: false,
        totalAdsCreated: 0,
        activeAdsCount: 0,
      );

  Future<void> dispose() async {
    // No-op
    _warnOnce();
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
