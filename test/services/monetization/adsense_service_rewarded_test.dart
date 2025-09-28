@TestOn('browser')
// ignore: unnecessary_library_name
library adsense_service_rewarded_test;

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

  test('showRewardedAd returns false when service not initialized', () async {
    service.reset();
    var rewardEarned = false;

    final result = await service.showRewardedAd(
      onRewardEarned: (_) => rewardEarned = true,
      context: 'not_initialized',
    );

    expect(result, isFalse);
    expect(rewardEarned, isFalse);
  });

  test('showRewardedAd returns false and records failure when queue missing',
      () async {
    final fakeAdapter = _FakeRewardedDomAdapter();
    AdSenseService.debugOverrideDomAdapter(fakeAdapter);
    AdSenseService.debugOverrideAdsByGoogleQueue(() => null);

    final result = await service.showRewardedAd(
      onRewardEarned: (_) {},
      context: 'queue_missing',
    );

    expect(result, isFalse);
    expect(service.debugRewardedFailureCount, 1);
    expect(fakeAdapter.mountCalls, 0);
    expect(fakeAdapter.removedElements, isEmpty);
  });

  test('showRewardedAd returns true and grants reward when overlay loaded',
      () async {
    final fakeAdapter = _FakeRewardedDomAdapter(
      result: const AdSenseOverlayResult.loaded(),
      invokeLoaded: true,
      invokeClose: true,
    );
    AdSenseService.debugOverrideDomAdapter(fakeAdapter);

    final queue = <JSObject>[].toJS;
    AdSenseService.debugOverrideAdsByGoogleQueue(() => queue);

    var rewardEarned = false;
    AdSenseReward? lastReward;

    final result = await service.showRewardedAd(
      onRewardEarned: (reward) {
        rewardEarned = true;
        lastReward = reward;
      },
      context: 'overlay_success',
    );

    expect(result, isTrue);
    expect(rewardEarned, isTrue);
    expect(lastReward, isNotNull);
    expect(lastReward!.amount, 1);
    expect(lastReward!.type, 'engagement');
    expect(service.debugRewardedFailureCount, 0);
    expect(fakeAdapter.mountCalls, 1);
    expect(fakeAdapter.removedElements, isEmpty);
  });

  test('showRewardedAd records failure when overlay dismissed before load',
      () async {
    final fakeAdapter = _FakeRewardedDomAdapter(
      result: const AdSenseOverlayResult.dismissed(),
      invokeLoaded: false,
      invokeClose: true,
    );
    AdSenseService.debugOverrideDomAdapter(fakeAdapter);

    final queue = <JSObject>[].toJS;
    AdSenseService.debugOverrideAdsByGoogleQueue(() => queue);

    var rewardEarned = false;

    final result = await service.showRewardedAd(
      onRewardEarned: (_) => rewardEarned = true,
      context: 'overlay_dismissed',
    );

    expect(result, isFalse);
    expect(rewardEarned, isFalse);
    expect(service.debugRewardedFailureCount, 1);
    expect(fakeAdapter.mountCalls, 1);
    expect(fakeAdapter.removedElements, isEmpty);
  });

  test('showRewardedAd records failure when overlay mount throws', () async {
    final fakeAdapter = _FakeRewardedDomAdapter(
      throwOnMount: true,
    );
    AdSenseService.debugOverrideDomAdapter(fakeAdapter);

    final queue = <JSObject>[].toJS;
    AdSenseService.debugOverrideAdsByGoogleQueue(() => queue);

    var rewardEarned = false;

    final result = await service.showRewardedAd(
      onRewardEarned: (_) => rewardEarned = true,
      context: 'overlay_exception',
    );

    expect(result, isFalse);
    expect(rewardEarned, isFalse);
    expect(service.debugRewardedFailureCount, 1);
    expect(fakeAdapter.mountCalls, 1);
  });
}

class _FakeRewardedDomAdapter extends AdSenseDomAdapter {
  _FakeRewardedDomAdapter({
    AdSenseOverlayResult? result,
    this.invokeLoaded = false,
    this.invokeClose = false,
    this.throwOnMount = false,
  }) : result = result ?? const AdSenseOverlayResult.failure('not_configured');

  final AdSenseOverlayResult result;
  final bool invokeLoaded;
  final bool invokeClose;
  final bool throwOnMount;

  int mountCalls = 0;
  final List<String> removedElements = <String>[];

  @override
  bool elementExistsById(String elementId) {
    if (elementId == 'adsense-script') {
      return true;
    }
    return removedElements.contains(elementId) == false;
  }

  @override
  Future<AdSenseOverlayResult> mountRewardedOverlay({
    required String overlayId,
    required String adElementId,
    required String adHtml,
    required String closeButtonLabel,
    Duration timeout = const Duration(seconds: 8),
    void Function()? onLoaded,
    void Function()? onClose,
  }) async {
    mountCalls++;
    if (throwOnMount) {
      throw StateError('mount_failed');
    }
    if (invokeLoaded) {
      onLoaded?.call();
    }
    if (invokeClose) {
      onClose?.call();
    }
    return result;
  }

  @override
  void removeElementById(String elementId) {
    removedElements.add(elementId);
  }

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
    return const AdSenseOverlayResult.failure('not_implemented_for_test');
  }
}
