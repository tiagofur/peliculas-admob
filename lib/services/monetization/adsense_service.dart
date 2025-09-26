import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../../core/logging/logger_factory.dart';
import '../../core/monetization/adsense_slots.dart';

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

  String? _publisherId;
  bool _isInitialized = false;
  bool _scriptInjected = false;
  final Map<String, int> _adLoadFailures = {};
  static const int _maxLoadFailures = 3;

  /// Initializes the AdSense service and injects the script if needed.
  ///
  /// [publisherId] is your AdSense publisher ID (e.g., 'ca-pub-1234567890').
  Future<void> initialize({String? publisherId}) async {
    if (_isInitialized) return;

    // Don't initialize AdSense on localhost to avoid 403 errors during development
    if (kIsWeb && html.window.location.hostname == 'localhost') {
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
      return adsbygoogle != null;
    } catch (e) {
      return false;
    }
  }

  /// Injects the AdSense script into the document's head if not already present.
  Future<void> _injectAdSenseScript() async {
    if (_scriptInjected || !kIsWeb) return;

    const scriptId = 'adsense-script';
    if (html.document.getElementById(scriptId) != null) {
      _scriptInjected = true;
      return;
    }

    final script = html.ScriptElement()
      ..id = scriptId
      ..async = true
      ..src =
          'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=$_publisherId'
      ..crossOrigin = 'anonymous';

    html.document.head!.append(script);
    _scriptInjected = true;

    // Wait for the script to load
    await script.onLoad.first;
    LoggerFactory.info('AdSense script injected and loaded.');
  }

  /// Pushes an ad to the `adsbygoogle` queue to be processed.
  void _pushAd(String adId) {
    if (!isAdSenseReady()) {
      LoggerFactory.warning('AdSense not ready, cannot push ad for $adId.');
      return;
    }
    try {
      if (adsbygoogle != null) {
        LoggerFactory.debug('Pushing ad for adId: $adId');
        final adConfig = {
          'google_ad_client': _publisherId,
          'enable_page_level_ads': true,
        }.jsify() as JSObject;
        adsbygoogle!.add(adConfig);
      }
    } catch (e) {
      LoggerFactory.error('Failed to push ad for $adId: $e');
    }
  }

  /// Returns the AdSense publisher ID.
  String? get publisherId => _publisherId;

  /// Returns true if the service has been initialized.
  bool get isInitialized => _isInitialized;

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
      if (adsbygoogle != null && html.document.getElementById(adId) != null) {
        adsbygoogle!.add({}.jsify() as JSObject);
        LoggerFactory.debug('Ad refreshed for adId: $adId');
      }
    } catch (e) {
      _adLoadFailures[adId] = (_adLoadFailures[adId] ?? 0) + 1;
      LoggerFactory.error('Failed to refresh ad for $adId: $e');
    }
  }

  /// Checks if an ad slot is visible within the viewport.
  bool isSlotVisible(GlobalKey adKey) {
    if (!_isInitialized || adKey.currentContext == null) return false;
    final RenderBox? renderBox =
        adKey.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null) return false;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenHeight = WidgetsBinding.instance.window.physicalSize.height /
        WidgetsBinding.instance.window.devicePixelRatio;
    return (position.dy < screenHeight && position.dy + size.height > 0);
  }

  /// Resets the initialization state of the service.
  @visibleForTesting
  void reset() {
    _isInitialized = false;
    _scriptInjected = false;
    _publisherId = null;
    _adLoadFailures.clear();
  }

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
