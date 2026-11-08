import 'dart:async';

import 'adsense_dom_models.dart';

class AdSenseDomAdapter {
  const AdSenseDomAdapter();

  bool get isLocalhost => false;

  bool elementExistsById(String elementId) => false;

  Future<void> injectScript({
    required String scriptId,
    required String scriptSrc,
    String? crossOrigin,
  }) async {}

  Future<AdSenseOverlayResult> mountInterstitialOverlay({
    required String overlayId,
    required String adElementId,
    required String adHtml,
    required String closeButtonLabel,
    Duration timeout = const Duration(seconds: 8),
    void Function()? onLoaded,
    void Function()? onClose,
  }) async {
    return const AdSenseOverlayResult.failure('not_supported');
  }

  Future<AdSenseOverlayResult> mountRewardedOverlay({
    required String overlayId,
    required String adElementId,
    required String adHtml,
    required String closeButtonLabel,
    Duration timeout = const Duration(seconds: 8),
    void Function()? onLoaded,
    void Function()? onClose,
  }) async {
    return const AdSenseOverlayResult.failure('not_supported');
  }

  void removeElementById(String elementId) {}
}
