import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../../core/logging/logger_factory.dart';
import '../../core/monetization/adsense_slots.dart';
import 'adsense_dom_adapter_stub.dart'
    if (dart.library.js_interop) 'adsense_dom_adapter_web.dart';
import 'adsense_dom_models.dart';

@JS('window.adsbygoogle')
external JSArray<JSObject>? get adsbygoogle;

/// Service to manage AdSense integration.
///
/// This service handles:
/// - Dynamic injection of the AdSense script.
/// - Initialization of ads.
/// - Creation of different ad widgets.
/// - Refreshing ads.
class AdSenseService {
  factory AdSenseService() => _instance;
  AdSenseService._internal();
  static final AdSenseService _instance = AdSenseService._internal();

  static AdSenseDomAdapter _domAdapter = const AdSenseDomAdapter();
  static const String _scriptElementId = 'adsense-script';

  static AdSenseService get instance => _instance;

  String? _publisherId;
  bool _isInitialized = false;
  bool _scriptInjected = false;
  final Map<String, int> _adLoadFailures = {};
  static const int _maxLoadFailures = 3;
  bool _interstitialReady = false;
  int _interstitialFailureCount = 0;
  static const int _interstitialMaxFailures = 3;
  int _rewardedFailureCount = 0;
  static const int _rewardedMaxFailures = 3;
  static JSArray<JSObject>? Function()? _adsbygoogleGetterOverride;

  /// Initializes the AdSense service and injects the script if needed.
  ///
  /// [publisherId] is your AdSense publisher ID (e.g., 'ca-pub-1234567890').
  Future<void> initialize({String? publisherId}) async {
    if (_isInitialized) return;

    // Don't initialize AdSense on localhost to avoid 403 errors during development
    if (kIsWeb && _domAdapter.isLocalhost) {
      LoggerFactory.info('AdSense initialization skipped on localhost.');
      _isInitialized =
          true; // Pretend it's initialized to not block other logic
      return;
    }

    _publisherId = publisherId ?? AdSenseSlots.publisherId;

    if (kIsWeb) {
      try {
        await _injectAdSenseScript();
        _isInitialized = true;
        LoggerFactory.info(
            'AdSense Service Initialized with Publisher ID: $_publisherId');
      } catch (e) {
        LoggerFactory.error('Failed to initialize AdSense Service: $e');
        _isInitialized = false;
      }
    } else {
      LoggerFactory.warning(
          'AdSense Service can only be initialized on the web.');
      _isInitialized = false;
    }
  }

  /// Checks if the AdSense script is loaded and ready.
  bool isAdSenseReady() {
    if (!kIsWeb) return false;
    try {
      return _getAdsByGoogleQueue() != null;
    } catch (e) {
      return false;
    }
  }

  /// Injects the AdSense script into the document's head if not already present.
  Future<void> _injectAdSenseScript() async {
    if (_scriptInjected || !kIsWeb) return;

    const scriptId = _scriptElementId;
    if (_domAdapter.elementExistsById(scriptId)) {
      _scriptInjected = true;
      LoggerFactory.debug(
          'AdSense script already present; skipping injection.');
      return;
    }

    await _domAdapter.injectScript(
      scriptId: scriptId,
      scriptSrc:
          'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=$_publisherId',
      crossOrigin: 'anonymous',
    );

    _scriptInjected = true;
    LoggerFactory.info('AdSense script injected and loaded.');
  }

  /// Returns the AdSense publisher ID.
  String? get publisherId => _publisherId;

  /// Returns true if the service has been initialized.
  bool get isInitialized => _isInitialized;

  bool canShowBannerAd() {
    if (!_isInitialized) {
      return false;
    }

    if (!_hasCommonAdSensePrerequisites('adsense_banner')) {
      return false;
    }

    if (_hasReachedFailureThreshold()) {
      LoggerFactory.warning(
        'AdSense banner disabled: failure threshold reached.',
        data: {
          'feature': 'adsense_banner',
          'reason': 'max_failures',
          'failures': Map<String, int>.from(_adLoadFailures),
        },
      );
      return false;
    }

    return isAdSenseReady();
  }

  bool _hasReachedFailureThreshold() {
    if (_adLoadFailures.isEmpty) {
      return false;
    }

    return _adLoadFailures.values.every(
      (failureCount) => failureCount >= _maxLoadFailures,
    );
  }

  bool _hasCommonAdSensePrerequisites(String feature) {
    if (_publisherId == null || _publisherId!.isEmpty) {
      LoggerFactory.debug(
        'AdSense $feature disabled: missing publisher ID.',
        data: {
          'feature': feature,
          'reason': 'missing_publisher_id',
        },
      );
      return false;
    }

    final scriptInjected = _scriptInjected &&
        (!kIsWeb || _domAdapter.elementExistsById(_scriptElementId));
    if (!scriptInjected) {
      LoggerFactory.debug(
        'AdSense $feature disabled: script not injected.',
        data: {
          'feature': feature,
          'reason': 'script_not_injected',
        },
      );
      return false;
    }

    return true;
  }

  bool _hasReachedInterstitialFailureThreshold() {
    return _interstitialFailureCount >= _interstitialMaxFailures;
  }

  bool _hasReachedRewardedFailureThreshold() {
    return _rewardedFailureCount >= _rewardedMaxFailures;
  }

  bool canShowInterstitialAd() {
    if (!_isInitialized) {
      return false;
    }

    if (!_hasCommonAdSensePrerequisites('adsense_interstitial')) {
      return false;
    }

    if (_hasReachedInterstitialFailureThreshold()) {
      LoggerFactory.warning(
        'AdSense interstitial disabled: failure threshold reached.',
        data: {
          'feature': 'adsense_interstitial',
          'reason': 'max_failures',
          'failures': _interstitialFailureCount,
        },
      );
      return false;
    }

    if (!_interstitialReady) {
      LoggerFactory.debug(
        'AdSense interstitial not ready yet.',
        data: {
          'feature': 'adsense_interstitial',
          'reason': 'not_ready',
          'failures': _interstitialFailureCount,
        },
      );
      return false;
    }

    return true;
  }

  void markInterstitialReady() {
    _interstitialReady = true;
    _interstitialFailureCount = 0;
  }

  void markInterstitialFailure({String? reason}) {
    _interstitialReady = false;
    if (_interstitialFailureCount < _interstitialMaxFailures) {
      _interstitialFailureCount++;
    }

    LoggerFactory.warning(
      'AdSense interstitial load failure registered.',
      data: {
        'feature': 'adsense_interstitial',
        'reason': reason ?? 'load_failure',
        'failures': _interstitialFailureCount,
        'maxFailures': _interstitialMaxFailures,
      },
    );
  }

  void markRewardedFailure({String? reason}) {
    if (_rewardedFailureCount < _rewardedMaxFailures) {
      _rewardedFailureCount++;
    }

    LoggerFactory.warning(
      'AdSense rewarded load failure registered.',
      data: {
        'feature': 'adsense_rewarded',
        'reason': reason ?? 'load_failure',
        'failures': _rewardedFailureCount,
        'maxFailures': _rewardedMaxFailures,
      },
    );
  }

  Future<bool> showInterstitialAd({String? context}) async {
    if (!_isInitialized) {
      LoggerFactory.warning(
        'Attempted to show AdSense interstitial before initialization.',
        data: {'context': context},
      );
      return false;
    }

    if (!kIsWeb) {
      LoggerFactory.warning(
        'Attempted to show AdSense interstitial on non-web platform.',
        data: {'context': context},
      );
      return false;
    }

    if (!canShowInterstitialAd()) {
      LoggerFactory.debug(
        'AdSense interstitial prerequisites not satisfied.',
        data: {
          'context': context,
          'feature': 'adsense_interstitial',
          'ready': _interstitialReady,
          'failures': _interstitialFailureCount,
        },
      );
      return false;
    }

    const overlayId = 'adsense_interstitial_overlay';
    final adElementId =
        'adsense_interstitial_${DateTime.now().millisecondsSinceEpoch}';

    final config = AdSenseSlots.getConfigForType(AdSenseAdType.interstitial);
    final adHtml = _buildConfiguredAdHtml(
      elementId: adElementId,
      config: config,
    );

    Future<AdSenseOverlayResult> overlayFuture;
    var interstitialLoaded = false;
    try {
      overlayFuture = _domAdapter.mountInterstitialOverlay(
        overlayId: overlayId,
        adElementId: adElementId,
        adHtml: adHtml,
        closeButtonLabel: 'Close ad',
        timeout: const Duration(seconds: 12),
        onLoaded: () {
          interstitialLoaded = true;
          LoggerFactory.debug(
            'AdSense interstitial creative loaded into overlay.',
            data: {
              'context': context,
              'feature': 'adsense_interstitial',
            },
          );
        },
        onClose: () {
          LoggerFactory.debug(
            'AdSense interstitial overlay closed by user.',
            data: {
              'context': context,
              'feature': 'adsense_interstitial',
              'loaded': interstitialLoaded,
            },
          );
        },
      );
    } catch (error, stackTrace) {
      LoggerFactory.error(
        'Failed to mount AdSense interstitial overlay: $error',
        data: {
          'context': context,
          'feature': 'adsense_interstitial',
        },
        stackTrace: stackTrace,
      );
      markInterstitialFailure(reason: 'overlay_mount_failure');
      return false;
    }

    try {
      final queue = _getAdsByGoogleQueue();
      if (queue == null) {
        LoggerFactory.warning(
          'AdSense queue not available when attempting interstitial render.',
          data: {
            'context': context,
            'feature': 'adsense_interstitial',
          },
        );
        markInterstitialFailure(reason: 'queue_unavailable');
        _domAdapter.removeElementById(overlayId);
        return false;
      }

      queue.add({}.jsify() as JSObject);
    } catch (error, stackTrace) {
      LoggerFactory.error(
        'Failed to request AdSense interstitial rendering: $error',
        data: {
          'context': context,
          'feature': 'adsense_interstitial',
        },
        stackTrace: stackTrace,
      );
      markInterstitialFailure(reason: 'queue_push_failure');
      _domAdapter.removeElementById(overlayId);
      return false;
    }

    final result = await overlayFuture;

    if (result.isLoaded) {
      _interstitialReady = false;
      LoggerFactory.info(
        'AdSense interstitial completed successfully.',
        data: {
          'context': context,
          'feature': 'adsense_interstitial',
        },
      );
      return true;
    }

    if (result.isDismissed) {
      _interstitialReady = false;
      markInterstitialFailure(reason: 'closed_before_load');
      return false;
    }

    final failureReason = result.reason;
    markInterstitialFailure(reason: failureReason);
    LoggerFactory.warning(
      'AdSense interstitial failed to render.',
      data: {
        'context': context,
        'feature': 'adsense_interstitial',
        'state': result.state.name,
        'reason': failureReason,
      },
    );
    return false;
  }

  Future<bool> showRewardedAd({
    required Function(AdSenseReward) onRewardEarned,
    String? context,
  }) async {
    if (!_isInitialized) {
      LoggerFactory.warning(
        'Attempted to show AdSense rewarded ad before initialization.',
        data: {'context': context},
      );
      return false;
    }

    if (!kIsWeb) {
      LoggerFactory.warning(
        'Attempted to show AdSense rewarded ad on non-web platform.',
        data: {'context': context},
      );
      return false;
    }

    if (!_hasCommonAdSensePrerequisites('adsense_rewarded')) {
      return false;
    }

    if (_hasReachedRewardedFailureThreshold()) {
      LoggerFactory.warning(
        'AdSense rewarded disabled: failure threshold reached.',
        data: {
          'feature': 'adsense_rewarded',
          'reason': 'max_failures',
          'failures': _rewardedFailureCount,
        },
      );
      return false;
    }

    final queue = _getAdsByGoogleQueue();
    if (queue == null) {
      LoggerFactory.warning(
        'AdSense queue not available when attempting rewarded render.',
        data: {
          'context': context,
          'feature': 'adsense_rewarded',
        },
      );
      markRewardedFailure(reason: 'queue_unavailable');
      return false;
    }

    const overlayId = 'adsense_rewarded_overlay';
    final adElementId =
        'adsense_rewarded_${DateTime.now().millisecondsSinceEpoch}';

    final config = AdSenseSlots.getConfigForType(AdSenseAdType.rewarded);
    final adHtml = _buildConfiguredAdHtml(
      elementId: adElementId,
      config: config,
    );

    var rewardLoaded = false;
    var rewardDelivered = false;

    Future<AdSenseOverlayResult> overlayFuture;
    try {
      overlayFuture = _domAdapter.mountRewardedOverlay(
        overlayId: overlayId,
        adElementId: adElementId,
        adHtml: adHtml,
        closeButtonLabel: 'Claim reward',
        timeout: const Duration(seconds: 20),
        onLoaded: () {
          rewardLoaded = true;
          LoggerFactory.debug(
            'AdSense rewarded creative loaded into overlay.',
            data: {
              'context': context,
              'feature': 'adsense_rewarded',
            },
          );
        },
        onClose: () {
          if (rewardLoaded && !rewardDelivered) {
            rewardDelivered = true;
            const reward = AdSenseReward(amount: 1, type: 'engagement');
            onRewardEarned(reward);
            LoggerFactory.info(
              'AdSense rewarded engagement granted to user.',
              data: {
                'context': context,
                'feature': 'adsense_rewarded',
                'rewardType': reward.type,
                'rewardAmount': reward.amount,
              },
            );
          }
        },
      );
    } catch (error, stackTrace) {
      LoggerFactory.error(
        'Failed to mount AdSense rewarded overlay: $error',
        data: {
          'context': context,
          'feature': 'adsense_rewarded',
        },
        stackTrace: stackTrace,
      );
      markRewardedFailure(reason: 'overlay_mount_failure');
      return false;
    }

    try {
      queue.add({}.jsify() as JSObject);
    } catch (error, stackTrace) {
      LoggerFactory.error(
        'Failed to request AdSense rewarded rendering: $error',
        data: {
          'context': context,
          'feature': 'adsense_rewarded',
        },
        stackTrace: stackTrace,
      );
      markRewardedFailure(reason: 'queue_push_failure');
      _domAdapter.removeElementById(overlayId);
      return false;
    }

    final result = await overlayFuture;

    if (result.isLoaded) {
      if (rewardLoaded && !rewardDelivered) {
        rewardDelivered = true;
        const reward = AdSenseReward(amount: 1, type: 'engagement');
        onRewardEarned(reward);
        LoggerFactory.info(
          'AdSense rewarded engagement granted (deferred).',
          data: {
            'context': context,
            'feature': 'adsense_rewarded',
            'rewardType': reward.type,
            'rewardAmount': reward.amount,
          },
        );
      }

      if (rewardDelivered) {
        _rewardedFailureCount = 0;
        return true;
      }

      markRewardedFailure(reason: 'missing_reward_delivery');
      return false;
    }

    if (result.isDismissed) {
      markRewardedFailure(reason: 'closed_before_load');
      return false;
    }

    markRewardedFailure(reason: result.reason);
    return false;
  }

  /// Generates the HTML for a standard ad unit.
  String getAdHtml(String slotId,
      {String format = 'auto',
      bool responsive = true,
      String style = 'display:block'}) {
    if (!_isInitialized) return '';
    return '''
      <ins class="adsbygoogle"
           style="$style"
           data-ad-client="$_publisherId"
           data-ad-slot="$slotId"
           data-ad-format="$format"
           data-full-width-responsive="$responsive"></ins>
    ''';
  }

  /// Generates the HTML for a fluid ad unit (e.g., in-article).
  String getFluidAdHtml(String slotId, String layoutKey,
      {String style = 'display:block; text-align:center;'}) {
    if (!_isInitialized) return '';
    return '''
      <ins class="adsbygoogle"
           style="$style"
           data-ad-client="$_publisherId"
           data-ad-slot="$slotId"
           data-ad-format="fluid"
           data-ad-layout-key="$layoutKey"></ins>
    ''';
  }

  /// Manually refreshes an ad unit.
  /// This is useful for SPAs where content changes without a page reload.
  void refreshAd(String adId) {
    if (!isAdSenseReady() ||
        _adLoadFailures.containsKey(adId) &&
            _adLoadFailures[adId]! >= _maxLoadFailures) {
      LoggerFactory.warning(
          'Ad refresh skipped for $adId (max failures reached or AdSense not ready).');
      return;
    }

    try {
      final queue = _getAdsByGoogleQueue();
      if (queue != null && _domAdapter.elementExistsById(adId)) {
        queue.add({}.jsify() as JSObject);
        LoggerFactory.debug('Ad refreshed for adId: $adId');
      }
    } catch (e) {
      _adLoadFailures[adId] = (_adLoadFailures[adId] ?? 0) + 1;
      LoggerFactory.error('Failed to refresh ad for $adId: $e');
    }
  }

  /// Checks if an ad slot is visible within the viewport.
  bool isSlotVisible(GlobalKey adKey) {
    if (!_isInitialized) return false;

    final context = adKey.currentContext;
    if (context == null) return false;

    // ✅ WEB FIX: Safe casting for Flutter Web compatibility
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return false;
    if (!renderObject.hasSize) return false;

    final position = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;

    final mediaQuery = MediaQuery.maybeOf(context);
    final implicitView =
        WidgetsBinding.instance.platformDispatcher.implicitView;
    final screenHeight = mediaQuery?.size.height ??
        (implicitView != null
            ? implicitView.physicalSize.height / implicitView.devicePixelRatio
            : double.infinity);

    return position.dy < screenHeight && position.dy + size.height > 0;
  }

  /// Resets the initialization state of the service.
  @visibleForTesting
  void reset() {
    _isInitialized = false;
    _scriptInjected = false;
    _publisherId = null;
    _adLoadFailures.clear();
    _interstitialReady = false;
    _interstitialFailureCount = 0;
    _rewardedFailureCount = 0;
    _cleanupDomArtifacts();
    _domAdapter = const AdSenseDomAdapter();
    _adsbygoogleGetterOverride = null;
  }

  @visibleForTesting
  void debugSetInitializationState({
    bool? isInitialized,
    String? publisherId,
    bool? scriptInjected,
  }) {
    if (isInitialized != null) {
      _isInitialized = isInitialized;
    }
    if (publisherId != null) {
      _publisherId = publisherId;
    }
    if (scriptInjected != null) {
      _scriptInjected = scriptInjected;
    }
  }

  @visibleForTesting
  void debugSetInterstitialState({
    bool? ready,
    int? failureCount,
  }) {
    if (ready != null) {
      _interstitialReady = ready;
    }
    if (failureCount != null) {
      _interstitialFailureCount = failureCount;
    }
  }

  @visibleForTesting
  int get debugInterstitialFailureCount => _interstitialFailureCount;

  @visibleForTesting
  bool get debugInterstitialReady => _interstitialReady;

  @visibleForTesting
  static void debugOverrideDomAdapter(AdSenseDomAdapter adapter) {
    _domAdapter = adapter;
  }

  @visibleForTesting
  static void debugOverrideAdsByGoogleQueue(
    JSArray<JSObject>? Function()? override,
  ) {
    _adsbygoogleGetterOverride = override;
  }

  @visibleForTesting
  void debugSetRewardedFailures(int failureCount) {
    _rewardedFailureCount = failureCount;
  }

  @visibleForTesting
  int get debugRewardedFailureCount => _rewardedFailureCount;

  /// Simulates fetching ad configuration from a remote server.
  Future<AdSenseConfig> fetchRemoteAdConfig(String adType) async {
    try {
      // This is a placeholder for a real API call
      final response = await http
          .get(Uri.parse('https://your-config-server.com/ads/$adType'));
      if (response.statusCode == 200) {
        final config = json.decode(response.body);
        return AdSenseConfig(
          slot: config['slot'],
          format: config['format'],
          responsive: config['responsive'],
          style: config['style'],
          layoutKey: config['layoutKey'],
        );
      }
    } catch (e) {
      LoggerFactory.error('Failed to fetch remote ad config for $adType: $e');
    }
    // Fallback to local config
    return AdSenseSlots.getConfigForType(AdSenseAdType.values
        .firstWhere((e) => e.toString() == 'AdSenseAdType.$adType'));
  }

  AdSenseMetrics getMetrics() => AdSenseMetrics(
        isInitialized: _isInitialized,
        hasActiveBanner: false,
        hasActiveInterstitial: _interstitialReady,
        hasActiveRewarded:
            !_hasReachedRewardedFailureThreshold() && isAdSenseReady(),
        totalAdsCreated: _adLoadFailures.length,
        activeAdsCount: 0,
        publisherId: _publisherId,
      );

  void _cleanupDomArtifacts() {
    _domAdapter.removeElementById('adsense_interstitial_overlay');
    _domAdapter.removeElementById('adsense_rewarded_overlay');
    if (kIsWeb) {
      _domAdapter.removeElementById(_scriptElementId);
    }
  }

  Future<void> dispose() async {
    _isInitialized = false;
    _scriptInjected = false;
    _publisherId = null;
    _adLoadFailures.clear();
    _interstitialReady = false;
    _interstitialFailureCount = 0;
    _rewardedFailureCount = 0;
    _cleanupDomArtifacts();
    _domAdapter = const AdSenseDomAdapter();
    _adsbygoogleGetterOverride = null;
  }

  JSArray<JSObject>? _getAdsByGoogleQueue() {
    return _adsbygoogleGetterOverride?.call() ?? adsbygoogle;
  }

  String _buildConfiguredAdHtml({
    required String elementId,
    required AdSenseConfig config,
  }) {
    final layoutKeyAttr = config.layoutKey != null
        ? ' data-ad-layout-key="${config.layoutKey}"'
        : '';
    final widthAttr =
        config.width != null ? ' data-ad-width="${config.width}"' : '';
    final heightAttr =
        config.height != null ? ' data-ad-height="${config.height}"' : '';
    final responsiveAttr =
        config.responsive ? ' data-full-width-responsive="true"' : '';

    return '''
      <ins class="adsbygoogle"
           id="$elementId"
           style="${config.style}"
           data-ad-client="$_publisherId"
           data-ad-slot="${config.slot}"
           data-ad-format="${config.format}"$layoutKeyAttr$widthAttr$heightAttr$responsiveAttr>
      </ins>
    ''';
  }
}

/// Represents the state of an ad.
class AdState {
  AdState({
    required this.adId,
    required this.type,
    this.isLoaded = false,
    this.isVisible = false,
    required this.isInitialized,
  });
  final String adId;
  final AdSenseAdType type;
  final bool isLoaded;
  final bool isVisible;
  final bool isInitialized;

  AdState copyWith({
    bool? isLoaded,
    bool? isVisible,
  }) {
    return AdState(
      adId: adId,
      type: type,
      isLoaded: isLoaded ?? this.isLoaded,
      isVisible: isVisible ?? this.isVisible,
      isInitialized: isInitialized,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'adId': adId,
      'type': type.toString(),
      'isLoaded': isLoaded,
      'isVisible': isVisible,
      'isInitialized': isInitialized,
    };
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
