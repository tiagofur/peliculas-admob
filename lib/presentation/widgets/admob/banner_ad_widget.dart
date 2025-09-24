import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../config/helpers/ad_helper.dart';
import '../../../core/monetization/monetization_analytics_service.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  final MonetizationAnalyticsService _analytics =
      MonetizationAnalyticsService.instance;
  final DateTime _loadStartTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    // No cargar anuncios en web
    if (kIsWeb) {
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });

          // Track successful load
          final loadTime = DateTime.now().difference(_loadStartTime);
          _analytics.trackAdLoadTime(
            adType: 'banner',
            adUnitId: AdHelper.bannerAdUnitId,
            loadTime: loadTime,
            successful: true,
            placement: 'general',
          );

          // Track impression
          _analytics.trackAdImpression(
            adType: 'banner',
            adUnitId: AdHelper.bannerAdUnitId,
            placement: 'general',
          );
        },
        onAdFailedToLoad: (ad, err) {
          _isBannerAdReady = false;
          ad.dispose();

          // Track error
          final loadTime = DateTime.now().difference(_loadStartTime);
          _analytics.trackAdLoadTime(
            adType: 'banner',
            adUnitId: AdHelper.bannerAdUnitId,
            loadTime: loadTime,
            successful: false,
            placement: 'general',
          );

          _analytics.trackAdLoadError(
            adType: 'banner',
            adUnitId: AdHelper.bannerAdUnitId,
            errorCode: err.code.toString(),
            errorMessage: err.message,
            placement: 'general',
          );
        },
        onAdClicked: (_) {
          // Track click
          _analytics.trackAdClick(
            adType: 'banner',
            adUnitId: AdHelper.bannerAdUnitId,
            placement: 'general',
            estimatedRevenue: 0.01, // Estimated revenue per click
          );
        },
      ),
    );

    _bannerAd?.load();
  }

  @override
  Widget build(BuildContext context) {
    // No mostrar anuncios en web
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    final bannerAd = _bannerAd;
    if (_isBannerAdReady && bannerAd != null) {
      return Container(
        width: bannerAd.size.width.toDouble(),
        height: bannerAd.size.height.toDouble(),
        margin: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.3),
        ),
        child: AdWidget(ad: bannerAd),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}
