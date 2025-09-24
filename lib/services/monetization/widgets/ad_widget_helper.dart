import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../advanced_admob_service.dart';

/// Widget helper para integrar anuncios de manera fácil y consistente
class AdWidget extends StatefulWidget {
  const AdWidget({
    super.key,
    required this.adType,
    this.margin,
    this.onRewardEarned,
    this.context,
    this.placeholderWidget,
  });

  /// Constructor para banner ad
  const AdWidget.banner({
    super.key,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
    this.placeholderWidget,
  })  : adType = AdType.banner,
        onRewardEarned = null,
        context = null;

  /// Constructor para banner ad en lista
  const AdWidget.listBanner({
    super.key,
    this.placeholderWidget,
  })  : adType = AdType.banner,
        margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onRewardEarned = null,
        context = null;
  final AdType adType;
  final EdgeInsetsGeometry? margin;
  final Function(RewardItem)? onRewardEarned;
  final String? context;
  final Widget? placeholderWidget;

  @override
  State<AdWidget> createState() => _AdWidgetState();
}

class _AdWidgetState extends State<AdWidget> {
  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return widget.placeholderWidget ?? const SizedBox.shrink();
    }

    switch (widget.adType) {
      case AdType.banner:
        return _buildBannerAd();
      case AdType.interstitial:
        // Los interstitials no se muestran como widgets
        return const SizedBox.shrink();
      case AdType.rewarded:
        // Los rewarded tampoco se muestran como widgets
        return const SizedBox.shrink();
    }
  }

  Widget _buildBannerAd() {
    final adService = AdvancedAdMobService.instance;

    if (!adService.hasBannerAd) {
      return widget.placeholderWidget ?? const SizedBox.shrink();
    }

    return Container(
      margin: widget.margin ?? EdgeInsets.zero,
      child: adService.createBannerAdWidget(
        margin: EdgeInsets.zero,
      ),
    );
  }
}

/// Tipos de anuncios
enum AdType {
  banner,
  interstitial,
  rewarded,
}

/// Widget que añade funcionalidad de anuncios a una pantalla
class AdAwareScreen extends StatefulWidget {
  const AdAwareScreen({
    super.key,
    required this.child,
    this.enableInterstitialAds = true,
    this.enableBannerAds = true,
    this.screenName,
    this.interstitialTriggerActions,
  });
  final Widget child;
  final bool enableInterstitialAds;
  final bool enableBannerAds;
  final String? screenName;
  final List<String>? interstitialTriggerActions;

  @override
  State<AdAwareScreen> createState() => _AdAwareScreenState();
}

class _AdAwareScreenState extends State<AdAwareScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Registrar entrada a la pantalla
    if (widget.screenName != null) {
      AdvancedAdMobService.instance.incrementInterstitialCounter(
        action: 'screen_enter_${widget.screenName}',
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Mostrar interstitial cuando la app vuelve del background
    if (state == AppLifecycleState.resumed &&
        widget.enableInterstitialAds &&
        widget.screenName != null) {
      Future.delayed(const Duration(seconds: 1), () {
        AdvancedAdMobService.instance.showInterstitialAdSmart(
          context: 'app_resume_${widget.screenName}',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Helper para triggering de anuncios interstitials
class AdTrigger {
  /// Trigger para navegación entre pantallas
  static void onNavigation(String fromScreen, String toScreen) {
    AdvancedAdMobService.instance.incrementInterstitialCounter(
      action: 'navigation_$fromScreen-to-$toScreen',
    );

    // Mostrar interstitial si es apropiado
    AdvancedAdMobService.instance.showInterstitialAdSmart(
      context: 'navigation',
    );
  }

  /// Trigger para acciones del usuario
  static void onUserAction(String action) {
    AdvancedAdMobService.instance.incrementInterstitialCounter(
      action: action,
    );
  }

  /// Trigger para completar acciones importantes
  static void onActionComplete(String action) {
    AdvancedAdMobService.instance.showInterstitialAdSmart(
      context: 'action_complete_$action',
    );
  }

  /// Mostrar rewarded ad con callback
  static Future<bool> showRewardedAd({
    required Function(RewardItem) onRewardEarned,
    String? context,
  }) {
    return AdvancedAdMobService.instance.showRewardedAd(
      onUserEarnedReward: onRewardEarned,
      context: context,
    );
  }
}

/// Widget para mostrar anuncios en listas de manera inteligente
class ListAdInserter {
  /// Inserta anuncios en una lista de manera inteligente
  static List<Widget> insertAdsInList({
    required List<Widget> items,
    int adInterval = 5,
    Widget? customAdWidget,
  }) {
    if (kIsWeb || items.isEmpty) return items;

    final List<Widget> result = [];

    for (int i = 0; i < items.length; i++) {
      result.add(items[i]);

      // Insertar anuncio cada cierto intervalo
      if ((i + 1) % adInterval == 0 && i < items.length - 1) {
        result.add(
          customAdWidget ?? const AdWidget.listBanner(),
        );
      }
    }

    return result;
  }

  /// Widget separador con anuncio
  static Widget adSeparator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: AdWidget.banner(),
    );
  }
}

/// Configuración de anuncios para diferentes pantallas
class ScreenAdConfig {
  static const Map<String, Map<String, dynamic>> _screenConfigs = {
    'movie_list': {
      'banners': true,
      'interstitials': true,
      'interstitial_actions': [
        'movie_tap',
        'filter_applied',
        'search_performed'
      ],
    },
    'movie_detail': {
      'banners': true,
      'interstitials': false, // No interrumpir la experiencia de detalle
      'interstitial_actions': ['add_to_watchlist', 'rate_movie'],
    },
    'search': {
      'banners': true,
      'interstitials': true,
      'interstitial_actions': ['search_performed', 'result_tap'],
    },
    'profile': {
      'banners': false, // Mantener limpio el perfil
      'interstitials': false,
      'interstitial_actions': [],
    },
  };

  /// Obtiene configuración para una pantalla
  static Map<String, dynamic>? getConfigForScreen(String screenName) {
    return _screenConfigs[screenName];
  }

  /// Verifica si una pantalla debe mostrar banners
  static bool shouldShowBanners(String screenName) {
    final config = getConfigForScreen(screenName);
    return config?['banners'] ?? false;
  }

  /// Verifica si una pantalla debe mostrar interstitials
  static bool shouldShowInterstitials(String screenName) {
    final config = getConfigForScreen(screenName);
    return config?['interstitials'] ?? false;
  }

  /// Obtiene acciones que triggean interstitials para una pantalla
  static List<String> getInterstitialActions(String screenName) {
    final config = getConfigForScreen(screenName);
    final actions = config?['interstitial_actions'] as List<dynamic>?;
    return actions?.cast<String>() ?? [];
  }
}
