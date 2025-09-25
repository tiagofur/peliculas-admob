import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../../config/constants/environment.dart';
import '../../core/logging/logger_factory.dart';

// JavaScript interop definitions for AdSense
@JS()
external JSObject get window;

@JS('window.adsbygoogle')
external JSArray<JSObject>? get adsbygoogle;

@JS()
external void eval(String script);

/// Servicio de AdSense para monetización en web y desktop
/// Implementa Google AdSense con enfoque en experiencia de usuario
class AdSenseService {
  AdSenseService._();
  static AdSenseService? _instance;

  static AdSenseService get instance {
    _instance ??= AdSenseService._();
    return _instance!;
  }

  bool _isInitialized = false;
  String? _publisherId;

  // Estado de anuncios
  final Map<String, bool> _activeAds = {};
  int _adCounter = 0;

  /// Inicializa AdSense para web/desktop
  Future<void> initialize({String? publisherId}) async {
    if (_isInitialized) return;

    if (!kIsWeb) {
      LoggerFactory.warning('AdSense solo funciona en plataforma web');
      return;
    }

    try {
      // Usar ID del environment o el pasado como parámetro
      _publisherId = publisherId ?? Environment.adsenseClientId;

      LoggerFactory.info(
          'Inicializando AdSense con Publisher ID: $_publisherId');

      // Verificar si AdSense ya está cargado
      if (!_isAdSenseLoaded()) {
        await _loadAdSenseScript();
      }

      // Configurar AdSense
      _configureAdSense();

      _isInitialized = true;
      LoggerFactory.info('AdSense inicializado exitosamente');
    } catch (e) {
      LoggerFactory.error('Error inicializando AdSense: $e');
    }
  }

  /// Verifica si AdSense está cargado
  bool _isAdSenseLoaded() {
    try {
      return adsbygoogle != null;
    } catch (e) {
      return false;
    }
  }

  /// Carga el script de AdSense
  Future<void> _loadAdSenseScript() async {
    final completer = Completer<void>();

    final script =
        web.document.createElement('script') as web.HTMLScriptElement;
    script.src =
        'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=$_publisherId';
    script.async = true;
    script.crossOrigin = 'anonymous';

    script.addEventListener(
        'load',
        (web.Event event) {
          LoggerFactory.info('Script AdSense cargado exitosamente');
          completer.complete();
        }.toJS);

    script.addEventListener(
        'error',
        (web.Event event) {
          LoggerFactory.error('Error cargando script AdSense');
          completer.completeError('Failed to load AdSense script');
        }.toJS);

    web.document.head?.appendChild(script);
    return completer.future;
  }

  /// Configura AdSense con opciones UX-friendly
  void _configureAdSense() {
    try {
      if (adsbygoogle != null) {
        // Configuración global de AdSense
        eval('''
          (window.adsbygoogle = window.adsbygoogle || []).push({
            google_ad_client: "$_publisherId",
            enable_page_level_ads: false,
            overlays: {bottom: false, top: false},
            auto_ads: false
          });
        ''');
      }
    } catch (e) {
      LoggerFactory.error('Error configurando AdSense: $e');
    }
  }

  /// Verifica si AdSense está inicializado
  bool get isInitialized => _isInitialized;

  /// Verifica si se puede mostrar un banner
  bool canShowBannerAd() {
    return _isInitialized;
  }

  /// Verifica si se puede mostrar un intersticial
  bool canShowInterstitialAd() {
    return _isInitialized;
  }

  /// Crea un banner AdSense
  String createBannerAd({
    required String slotId,
    String width = 'auto',
    String height = '280',
    String format = 'auto',
    bool responsive = true,
  }) {
    if (!_isInitialized) return '';

    final adId = 'adsense-banner-${++_adCounter}';
    _activeAds[adId] = true;

    final responsiveAttr =
        responsive ? 'data-full-width-responsive="true"' : '';

    return '''
      <div id="$adId">
        <ins class="adsbygoogle"
             style="display:block"
             data-ad-client="$_publisherId"
             data-ad-slot="$slotId"
             data-ad-format="$format"
             ${width != 'auto' ? 'data-ad-width="$width"' : ''}
             ${height != 'auto' ? 'data-ad-height="$height"' : ''}
             $responsiveAttr>
        </ins>
      </div>
    ''';
  }

  /// Crea un anuncio nativo AdSense
  String createNativeAd({
    required String slotId,
    String format = 'fluid',
    String layoutKey = '-gw-1+2a-9x+5c',
  }) {
    if (!_isInitialized) return '';

    final adId = 'adsense-native-${++_adCounter}';
    _activeAds[adId] = true;

    return '''
      <div id="$adId">
        <ins class="adsbygoogle"
             style="display:block"
             data-ad-format="$format"
             data-ad-layout-key="$layoutKey"
             data-ad-client="$_publisherId"
             data-ad-slot="$slotId">
        </ins>
      </div>
    ''';
  }

  /// Activa un anuncio AdSense (push al array)
  void pushAd(String adId) {
    if (!_isInitialized) return;

    try {
      eval('''
        if (window.adsbygoogle && document.getElementById('$adId')) {
          (window.adsbygoogle = window.adsbygoogle || []).push({});
        }
      ''');

      LoggerFactory.debug('Anuncio AdSense activado: $adId');
    } catch (e) {
      LoggerFactory.error('Error activando anuncio AdSense: $e');
    }
  }

  /// Muestra un intersticial (implementación simplificada)
  Future<bool> showInterstitialAd({String? context}) async {
    if (!_isInitialized) return false;

    LoggerFactory.info('Intersticial AdSense solicitado: $context');

    // En AdSense, los intersticiales son más complejos de implementar
    // Por ahora retornamos false, pero se puede expandir
    return false;
  }

  /// Muestra un anuncio de recompensa (no soportado nativamente en AdSense)
  Future<bool> showRewardedAd({
    required Function(AdSenseReward) onRewardEarned,
    String? context,
  }) async {
    LoggerFactory.warning('Anuncios de recompensa no soportados en AdSense');
    return false;
  }

  /// Obtiene métricas de AdSense
  AdSenseMetrics getMetrics() {
    return AdSenseMetrics(
      isInitialized: _isInitialized,
      hasActiveBanner: _activeAds.values.any((active) => active),
      hasActiveInterstitial: false,
      hasActiveRewarded: false,
      totalAdsCreated: _adCounter,
      activeAdsCount: _activeAds.values.where((active) => active).length,
      publisherId: _publisherId,
    );
  }

  /// Libera recursos
  Future<void> dispose() async {
    _activeAds.clear();
    _adCounter = 0;
    _isInitialized = false;
    LoggerFactory.info('AdSenseService disposed');
  }

  // Métodos helper para crear anuncios con configuración del Environment

  /// Crea un banner con el slot configurado
  String createConfiguredBannerAd({
    String width = 'auto',
    String height = '280',
    String format = 'auto',
    bool responsive = true,
  }) {
    return createBannerAd(
      slotId: Environment.adsenseBannerSlot,
      width: width,
      height: height,
      format: format,
      responsive: responsive,
    );
  }

  /// Crea un anuncio nativo con el slot configurado
  String createConfiguredNativeAd({
    String format = 'fluid',
    String layoutKey = '-gw-1+2a-9x+5c',
  }) {
    return createNativeAd(
      slotId: Environment.adsenseNativeSlot,
      format: format,
      layoutKey: layoutKey,
    );
  }

  /// Crea un anuncio de ancho completo con el slot configurado
  String createConfiguredFullWidthAd({
    String format = 'auto',
    bool responsive = true,
  }) {
    return createBannerAd(
      slotId: Environment.adsenseFullwidthSlot,
      format: format,
      responsive: responsive,
    );
  }
}

/// Métricas de AdSense
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

  Map<String, dynamic> toJson() => {
        'isInitialized': isInitialized,
        'hasActiveBanner': hasActiveBanner,
        'hasActiveInterstitial': hasActiveInterstitial,
        'hasActiveRewarded': hasActiveRewarded,
        'totalAdsCreated': totalAdsCreated,
        'activeAdsCount': activeAdsCount,
        'impressions': impressions,
        'clicks': clicks,
        'estimatedRevenue': estimatedRevenue,
        'publisherId': publisherId,
      };
}

/// Recompensa de AdSense (placeholder)
class AdSenseReward {
  const AdSenseReward({
    required this.amount,
    required this.type,
  });

  final int amount;
  final String type;

  @override
  String toString() => 'AdSenseReward(amount: $amount, type: $type)';
}
