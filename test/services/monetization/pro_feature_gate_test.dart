// ignore: unnecessary_library_name
library pro_feature_gate_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:peliculas/services/monetization/pro_feature_gate.dart';
import 'package:peliculas/services/monetization/user_monetization_preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final prefs = UserMonetizationPreferencesService.instance;
  final gate = ProFeatureGate.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await prefs.initialize();
    await prefs.clearUserData();
  });

  test('sin Pro todos los gates niegan sin cambiar nada', () async {
    expect(await gate.isPro(), isFalse);
    expect(await gate.canCreateCustomThemes(), isFalse);
    expect(await gate.hasUnlimitedLists(), isFalse);
    expect(await gate.canSeeAdvancedStats(), isFalse);
  });

  test('con Pro todos los gates permiten', () async {
    await prefs.setProActive(true);

    expect(await gate.isPro(), isTrue);
    expect(await gate.canCreateCustomThemes(), isTrue);
    expect(await gate.hasUnlimitedLists(), isTrue);
    expect(await gate.canSeeAdvancedStats(), isTrue);
  });
}
