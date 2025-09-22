import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../config/helpers/ad_helper.dart';
import 'adsense_web_widget.dart';

class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({
    super.key,
    this.height = 120,
    this.showLabel = false,
    this.margin,
    this.borderRadius = 12,
  });

  final double height;
  final bool showLabel;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _nativeAdIsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadNativeAd();
  }

  void _loadNativeAd() {
    if (kIsWeb) {
      // AdMob no es compatible con web
      return;
    }

    _nativeAd = NativeAd(
      adUnitId: AdHelper.nativeAdUnitId,
      factoryId: 'listTile',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _nativeAdIsLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    _nativeAd?.load();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // En web, usar AdSense
      return AdSenseNativeWidget(
        height: widget.height,
        showLabel: widget.showLabel,
        margin: widget.margin,
        borderRadius: widget.borderRadius,
      );
    }

    final nativeAd = _nativeAd;
    if (_nativeAdIsLoaded && nativeAd != null) {
      final adWidget = Container(
        height: widget.height,
        margin: widget.margin ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.3),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: AdWidget(ad: nativeAd),
      );

      if (widget.showLabel) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Text(
                'Publicidad',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
            ),
            adWidget,
          ],
        );
      }

      return adWidget;
    }
    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }
}
