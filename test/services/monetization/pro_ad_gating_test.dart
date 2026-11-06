// ignore: unnecessary_library_name
library pro_ad_gating_test;

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

  test('contador de intersticiales no acumula en Pro', () async {
    await prefs.setProActive(true);
    final before = admob.getAdMetrics().interstitialCounter;

    admob.incrementInterstitialCounter(action: 'screen_enter_home');
    admob.incrementInterstitialCounter(action: 'navigation_a-to-b');

    expect(admob.getAdMetrics().interstitialCounter, before);
  });

  test('contador de intersticiales acumula sin Pro', () async {
    final before = admob.getAdMetrics().interstitialCounter;

    admob.incrementInterstitialCounter(action: 'screen_enter_home');

    expect(admob.getAdMetrics().interstitialCounter, before + 1);
  });
}
