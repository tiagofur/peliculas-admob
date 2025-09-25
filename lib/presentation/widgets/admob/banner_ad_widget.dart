import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../config/helpers/ad_helper.dart';
import '../../../core/logging/logger_factory.dart';
import '../../../core/monetization/monetization_analytics_service.dart';
import '../../../widgets/ads/ad_placeholder_widget.dart';
import 'web_safe_ad_widgets.dart';

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
    // En web, usar el sistema web-safe
    if (kIsWeb) {
      LoggerFactory.info('Usando AdSense para banner ads en web');
      return;
    }

    // En modo debug, no cargar anuncios reales
    if (kDebugMode) {
      LoggerFactory.info(
          'Modo debug: usando placeholder en lugar de AdMob real');
      return;
    }

    // Solo cargar AdMob si la plataforma lo soporta
    if (!AdHelper.isAdMobSupported) {
      LoggerFactory.warning('AdMob no soportado en esta plataforma');
      return;
    }

    try {
      _bannerAd = BannerAd(
        adUnitId: AdHelper.bannerAdUnitId,
        request: const AdRequest(),
        size: AdSize.banner,
        listener: BannerAdListener(
          onAdLoaded: (_) {
            LoggerFactory.info('Banner ad cargado exitosamente');
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
            LoggerFactory.error('Error cargando banner ad: $err');
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
            LoggerFactory.info('Banner ad clicked');
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
    } catch (e) {
      LoggerFactory.error('Excepción cargando banner ad: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // En web, usar el widget web-safe
    if (kIsWeb) {
      return const WebSafeBannerAdWidget();
    }

    // En móvil modo debug, usar placeholder
    if (kDebugMode) {
      return const AdPlaceholderWidget(
        type: AdPlaceholderType.banner,
        customText: 'AdMob Banner\n(Debug Mode)\nProducción: ID real',
      );
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
