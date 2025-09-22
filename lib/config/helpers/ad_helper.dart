import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AdHelper {
  // AdSense configuration for web - Loaded from .env
  static String get adSenseClientId =>
      dotenv.env['ADSENSE_CLIENT_ID'] ?? 'ca-pub-4576016092724628';
  static String get adSenseBannerSlot =>
      dotenv.env['ADSENSE_BANNER_SLOT'] ?? '1234567890';
  static String get adSenseNativeSlot =>
      dotenv.env['ADSENSE_NATIVE_SLOT'] ?? '2345678901';
  static String get adSenseFullWidthSlot =>
      dotenv.env['ADSENSE_FULLWIDTH_SLOT'] ?? '3456789012';

  // AdMob IDs - Loaded from .env
  static String get bannerAdUnitId {
    if (kIsWeb) {
      return adSenseBannerSlot; // Web usa AdSense
    } else if (Platform.isAndroid) {
      return dotenv.env['ADMOB_ANDROID_BANNER'] ??
          'ca-app-pub-3940256099942544/6300978111';
    } else if (Platform.isIOS) {
      return dotenv.env['ADMOB_IOS_BANNER'] ??
          'ca-app-pub-3940256099942544/2934735716';
    }
    throw UnsupportedError('Plataforma no soportada');
  }

  static String get nativeAdUnitId {
    if (kIsWeb) {
      return adSenseNativeSlot; // Web usa AdSense
    } else if (Platform.isAndroid) {
      return dotenv.env['ADMOB_ANDROID_NATIVE'] ??
          'ca-app-pub-3940256099942544/2247696110';
    } else if (Platform.isIOS) {
      return dotenv.env['ADMOB_IOS_NATIVE'] ??
          'ca-app-pub-3940256099942544/3986624511';
    }
    throw UnsupportedError('Plataforma no soportada');
  }

  static String get interstitialAdUnitId {
    if (kIsWeb) {
      return ''; // Interstitial ads not typically used on web
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Test ID Android
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910'; // Test ID iOS
    }
    throw UnsupportedError('Plataforma no soportada');
  }

  static String get rewardedAdUnitId {
    if (kIsWeb) {
      return ''; // Rewarded ads not typically used on web
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // Test ID Android
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // Test ID iOS
    }
    throw UnsupportedError('Plataforma no soportada');
  }

  // AdSense utility methods
  static String get fullAdSenseClientId =>
      'ca-pub-${adSenseClientId.split('-').last}';

  static String getAdSenseSlotId(String adType) {
    switch (adType.toLowerCase()) {
      case 'banner':
        return adSenseBannerSlot;
      case 'native':
      case 'responsive':
        return adSenseNativeSlot;
      case 'fullwidth':
      case 'horizontal':
        return adSenseFullWidthSlot;
      default:
        return adSenseBannerSlot;
    }
  }
}
