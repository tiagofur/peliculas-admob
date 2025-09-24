import 'dart:io';
import 'package:flutter/foundation.dart';

class AdHelper {
  // IDs de prueba - REEMPLAZA con tus IDs reales cuando publiques
  static String get bannerAdUnitId {
    if (kIsWeb) {
      return ''; // Web no soporta anuncios
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Test ID Android
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // Test ID iOS
    }
    throw UnsupportedError('Plataforma no soportada');
  }

  static String get nativeAdUnitId {
    if (kIsWeb) {
      return ''; // Web no soporta anuncios
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/2247696110'; // Test ID Android
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/3986624511'; // Test ID iOS
    }
    throw UnsupportedError('Plataforma no soportada');
  }

  static String get interstitialAdUnitId {
    if (kIsWeb) {
      return ''; // Web no soporta anuncios
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Test ID Android
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910'; // Test ID iOS
    }
    throw UnsupportedError('Plataforma no soportada');
  }

  static String get rewardedAdUnitId {
    if (kIsWeb) {
      return ''; // Web no soporta anuncios
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // Test ID Android
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // Test ID iOS
    }
    throw UnsupportedError('Plataforma no soportada');
  }
}
