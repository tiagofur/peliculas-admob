import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/logging/logger_factory.dart';
import '../constants/environment.dart';

class AdHelper {
  // IDs reales desde configuración del .env
  static String get bannerAdUnitId {
    if (kIsWeb) {
      LoggerFactory.warning('AdMob no soportado en web - usando AdSense');
      return ''; // Web usa AdSense, no AdMob
    } else if (Platform.isAndroid) {
      return Environment.admobAndroidBanner;
    } else if (Platform.isIOS) {
      return Environment.admobIosBanner;
    }
    LoggerFactory.warning(
        'Plataforma no soportada para anuncios: ${Platform.operatingSystem}');
    return '';
  }

  static String get nativeAdUnitId {
    if (kIsWeb) {
      LoggerFactory.warning('AdMob no soportado en web - usando AdSense');
      return ''; // Web usa AdSense, no AdMob
    } else if (Platform.isAndroid) {
      return Environment.admobAndroidNative;
    } else if (Platform.isIOS) {
      return Environment.admobIosNative;
    }
    LoggerFactory.warning(
        'Plataforma no soportada para anuncios: ${Platform.operatingSystem}');
    return '';
  }

  static String get interstitialAdUnitId {
    if (kIsWeb) {
      LoggerFactory.warning('AdMob no soportado en web - usando AdSense');
      return ''; // Web usa AdSense, no AdMob
    } else if (Platform.isAndroid) {
      // Usar IDs de test por defecto para interstitial (agregar al .env si tienes reales)
      return 'ca-app-pub-3940256099942544/1033173712'; // Test ID Android
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910'; // Test ID iOS
    }
    LoggerFactory.warning(
        'Plataforma no soportada para anuncios: ${Platform.operatingSystem}');
    return '';
  }

  static String get rewardedAdUnitId {
    if (kIsWeb) {
      LoggerFactory.warning('AdMob no soportado en web - usando AdSense');
      return ''; // Web usa AdSense, no AdMob
    } else if (Platform.isAndroid) {
      // Usar IDs de test por defecto para rewarded (agregar al .env si tienes reales)
      return 'ca-app-pub-3940256099942544/5224354917'; // Test ID Android
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // Test ID iOS
    }
    LoggerFactory.warning(
        'Plataforma no soportada para anuncios: ${Platform.operatingSystem}');
    return '';
  }

  /// Verifica si la plataforma actual soporta AdMob
  static bool get isAdMobSupported {
    return !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  }

  /// Verifica si la plataforma actual soporta AdSense
  static bool get isAdSenseSupported {
    return kIsWeb;
  }

  /// Obtiene el tipo de monetización para la plataforma actual
  static String get monetizationType {
    if (kIsWeb) return 'AdSense';
    if (Platform.isAndroid || Platform.isIOS) return 'AdMob';
    return 'None';
  }
}
