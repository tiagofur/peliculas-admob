// ignore: unnecessary_library_name
library pro_entitlement_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:peliculas/config/monetization/ux_first_monetization_strategy.dart';
import 'package:peliculas/services/monetization/purchases_service.dart';
import 'package:peliculas/services/monetization/user_monetization_preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final prefsService = UserMonetizationPreferencesService.instance;
  final purchases = LocalPurchasesService.instance;
  final uxStrategy = UXFirstMonetizationStrategy.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await prefsService.initialize();
    await prefsService.clearUserData();
  });

  group('Pro entitlement en preferencias', () {
    test('setProActive(true) sincroniza premiumUser + optedOutOfAds', () async {
      await prefsService.setProActive(true);

      expect(await prefsService.isPro(), isTrue);
      expect(UserMonetizationPreferencesService.isProCached, isTrue);
      expect(await prefsService.getUserType(), UserTypeUX.premiumUser);

      final prefs = await prefsService.getUserPreferences();
      expect(prefs.optedOutOfAds, isTrue);
    });

    test('el tipo Pro sobrevive a sesiones y uso intensivo', () async {
      await prefsService.setProActive(true);

      await prefsService.recordUserSession();
      await prefsService.recordUsageTime(400);
      await prefsService.recordUserSession();

      expect(await prefsService.isPro(), isTrue);
      expect(await prefsService.getUserType(), UserTypeUX.premiumUser);
    });

    test('premiumUser bloquea forzados pero permite rewarded opt-in', () async {
      await prefsService.setProActive(true);
      final userType = await prefsService.getUserType();

      final banner = await uxStrategy.shouldShowAd(
        adType: AdTypeUX.banner,
        userType: userType,
        appContext: AppContextUX.browsing,
      );
      final interstitial = await uxStrategy.shouldShowAd(
        adType: AdTypeUX.interstitial,
        userType: userType,
        appContext: AppContextUX.browsing,
      );
      final rewarded = await uxStrategy.shouldShowAd(
        adType: AdTypeUX.rewarded,
        userType: userType,
        appContext: AppContextUX.browsing,
      );

      expect(banner, isNot(AdDecisionResult.approved));
      expect(interstitial, isNot(AdDecisionResult.approved));
      expect(rewarded, AdDecisionResult.approved);
    });

    test('setProActive(false) vuelve al tipo por uso', () async {
      await prefsService.setProActive(true);
      await prefsService.setProActive(false);

      expect(await prefsService.isPro(), isFalse);
      expect(await prefsService.getUserType(), isNot(UserTypeUX.premiumUser));

      final prefs = await prefsService.getUserPreferences();
      expect(prefs.optedOutOfAds, isFalse);
    });
  });

  group('LocalPurchasesService', () {
    test('purchasePro activa Pro y notifica el stream', () async {
      final events = <bool>[];
      final sub = purchases.onProChanged.listen(events.add);

      final entitlement = await purchases.purchasePro();

      expect(entitlement.isPro, isTrue);
      expect(entitlement.source, ProEntitlementSource.purchase);
      expect(entitlement.productId, proLifetimeProductId);
      expect(await purchases.isPro(), isTrue);
      expect(events, contains(true));

      await sub.cancel();
    });

    test('restorePurchases recupera Pro persistido', () async {
      await purchases.purchasePro();

      final restored = await purchases.restorePurchases();

      expect(restored.isPro, isTrue);
      expect(restored.source, ProEntitlementSource.restore);
      expect(await prefsService.getUserType(), UserTypeUX.premiumUser);
    });

    test('restore sin compra previa devuelve inactivo', () async {
      final restored = await purchases.restorePurchases();

      expect(restored.isPro, isFalse);
      expect(await purchases.isPro(), isFalse);
    });
  });
}
