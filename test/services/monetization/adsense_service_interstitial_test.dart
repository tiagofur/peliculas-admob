@TestOn('browser')
// ignore: unnecessary_library_name
library adsense_service_interstitial_test;

import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/services/monetization/adsense_dom_adapter_stub.dart'
    if (dart.library.js_interop) 'package:peliculas/services/monetization/adsense_dom_adapter_web.dart';
import 'package:peliculas/services/monetization/adsense_dom_models.dart';
import 'package:peliculas/services/monetization/adsense_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AdSenseService service;

  setUp(() {
    service = AdSenseService.instance;
    service.reset();
    service.debugSetInitializationState(
      isInitialized: true,
      publisherId: 'ca-pub-test',
      scriptInjected: true,
    );
  });

  tearDown(() {
    service.reset();
    AdSenseService.debugOverrideAdsByGoogleQueue(null);
  });

  test('returns false when service is not initialized', () {
    service.reset();
    expect(service.canShowInterstitialAd(), isFalse);
  });

  test('returns false when publisher id is missing', () {
    service.debugSetInitializationState(publisherId: '');
    expect(service.canShowInterstitialAd(), isFalse);
  });

  test('returns false when script has not been injected', () {
    service.debugSetInitializationState(scriptInjected: false);
    expect(service.canShowInterstitialAd(), isFalse);
  });

  test('returns false when interstitial is not ready', () {
    expect(service.canShowInterstitialAd(), isFalse);
  });

  test('returns false when failure threshold reached', () {
    service.debugSetInterstitialState(failureCount: 3);
    expect(service.canShowInterstitialAd(), isFalse);
  });

  test('returns true when interstitial is ready and prerequisites satisfied',
      () {
    service.markInterstitialReady();
    expect(service.canShowInterstitialAd(), isTrue);
  });

  test('markInterstitialFailure toggles readiness and increments failures', () {
    service.markInterstitialReady();
    expect(service.debugInterstitialReady, isTrue);

    service.markInterstitialFailure();
    expect(service.debugInterstitialReady, isFalse);
    expect(service.debugInterstitialFailureCount, 1);
  });

  test('showInterstitialAd returns true when overlay succeeds', () async {
    final fakeAdapter = _FakeInterstitialDomAdapter(
      result: const AdSenseOverlayResult.loaded(),
    );
    AdSenseService.debugOverrideDomAdapter(fakeAdapter);

    service.markInterstitialReady();
    final queue = <JSObject>[].toJS;
    AdSenseService.debugOverrideAdsByGoogleQueue(() => queue);

    final result = await service.showInterstitialAd(context: 'test_success');

    expect(result, isTrue);
    expect(service.debugInterstitialReady, isFalse);
    expect(fakeAdapter.mountCalls, 1);
    expect(fakeAdapter.removedElements, isEmpty);
  });

  test(
      'showInterstitialAd returns false and records failure when queue missing',
      () async {
    final fakeAdapter = _FakeInterstitialDomAdapter(
      result: const AdSenseOverlayResult.loaded(),
    );
    AdSenseService.debugOverrideDomAdapter(fakeAdapter);

    service.markInterstitialReady();
    AdSenseService.debugOverrideAdsByGoogleQueue(() => null);

    final result = await service.showInterstitialAd(context: 'queue_missing');

    expect(result, isFalse);
    expect(service.debugInterstitialFailureCount, 1);
    expect(
        fakeAdapter.removedElements, contains('adsense_interstitial_overlay'));
  });

  test('showInterstitialAd records failure when overlay times out', () async {
    final fakeAdapter = _FakeInterstitialDomAdapter(
      result: const AdSenseOverlayResult.timeout(),
    );
    AdSenseService.debugOverrideDomAdapter(fakeAdapter);

    service.markInterstitialReady();
    final queue = <JSObject>[].toJS;
    AdSenseService.debugOverrideAdsByGoogleQueue(() => queue);

    final result = await service.showInterstitialAd(context: 'timeout_case');

    expect(result, isFalse);
    expect(service.debugInterstitialFailureCount, 1);
    expect(fakeAdapter.mountCalls, 1);
  });
}

class _FakeInterstitialDomAdapter extends AdSenseDomAdapter {
  _FakeInterstitialDomAdapter({required this.result});

  final AdSenseOverlayResult result;
  int mountCalls = 0;
  final List<String> removedElements = <String>[];

  @override
  Future<AdSenseOverlayResult> mountInterstitialOverlay({
    required String overlayId,
    required String adElementId,
    required String adHtml,
    required String closeButtonLabel,
    Duration timeout = const Duration(seconds: 8),
    void Function()? onLoaded,
    void Function()? onClose,
  }) async {
    mountCalls++;
    onLoaded?.call();
    onClose?.call();
    return result;
  }

  @override
  void removeElementById(String elementId) {
    removedElements.add(elementId);
  }

  @override
  bool elementExistsById(String elementId) => true;

  @override
  bool get isLocalhost => false;
}
