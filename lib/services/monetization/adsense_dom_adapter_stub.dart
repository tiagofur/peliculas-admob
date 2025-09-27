import 'dart:async';

class AdSenseDomAdapter {
  const AdSenseDomAdapter();

  bool get isLocalhost => false;

  bool elementExistsById(String elementId) => false;

  Future<void> injectScript({
    required String scriptId,
    required String scriptSrc,
    String? crossOrigin,
  }) async {}
}
