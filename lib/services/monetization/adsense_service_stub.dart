/// Stub para AdSenseService en plataformas que no son web
class AdSenseService {
  static AdSenseService get instance => AdSenseService();

  bool get isInitialized => false;

  Future<void> initialize() async {
    // No-op en plataformas no web
  }

  bool canShowBannerAd() => false;
  bool canShowInterstitialAd() => false;

  Future<bool> showInterstitialAd({String? context}) async => false;

  Future<bool> showRewardedAd({
    required Function(AdSenseReward) onRewardEarned,
    String? context,
  }) async =>
      false;

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
