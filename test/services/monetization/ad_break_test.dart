// ignore: unnecessary_library_name
library ad_break_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:peliculas/services/monetization/advanced_admob_service.dart';
import 'package:peliculas/services/monetization/user_monetization_preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final prefs = UserMonetizationPreferencesService.instance;
  final admob = AdvancedAdMobService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await prefs.initialize();
    await prefs.clearUserData();
  });

  test('sin grant no hay break activo', () async {
    expect(await prefs.isAdBreakActive(), isFalse);
  });

  test('grant activa el break y sobrevive sesiones sin marcar Pro', () async {
    await prefs.grantAdBreak(const Duration(hours: 24));

    expect(await prefs.isAdBreakActive(), isTrue);
    expect(UserMonetizationPreferencesService.isAdBreakCached, isTrue);

    await prefs.recordUserSession();

    expect(await prefs.isAdBreakActive(), isTrue);
    expect(await prefs.isPro(), isFalse);
  });

  test('break expirado vuelve a inactivo', () async {
    await prefs.grantAdBreak(const Duration(seconds: -1));

    expect(await prefs.isAdBreakActive(), isFalse);
    expect(UserMonetizationPreferencesService.isAdBreakCached, isFalse);
  });

  test('contador de intersticiales no acumula durante el break', () async {
    await prefs.grantAdBreak(const Duration(hours: 24));
    final before = admob.getAdMetrics().interstitialCounter;

    admob.incrementInterstitialCounter(action: 'screen_enter_home');

    expect(admob.getAdMetrics().interstitialCounter, before);
  });
}
