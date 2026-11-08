// ignore: unnecessary_library_name
library pro_paywall_test;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:peliculas/generated/app_localizations.dart';
import 'package:peliculas/presentation/screens/pro_paywall_screen.dart';
import 'package:peliculas/services/monetization/purchases_service.dart';
import 'package:peliculas/services/monetization/user_monetization_preferences_service.dart';

Widget _harness() => const MaterialApp(
      locale: Locale('es'),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: ProPaywallScreen(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final purchases = LocalPurchasesService.instance;
  final prefs = UserMonetizationPreferencesService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await purchases.initialize();
    await prefs.clearUserData();
  });

  testWidgets('comprar activa Pro y muestra el estado', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(FilledButton, 'Conseguir Pro'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Conseguir Pro'));
    await tester.pumpAndSettle();

    expect(find.text('Pro activo'), findsWidgets);
    expect(await purchases.isPro(), isTrue);
  });

  testWidgets('restaurar sin compras informa y sigue sin Pro',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Restaurar compras'));
    await tester.pumpAndSettle();

    expect(find.text('No se encontraron compras'), findsOneWidget);
    expect(await purchases.isPro(), isFalse);
  });

  testWidgets('ver anuncio sin inventario informa no disponible',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver anuncio'));
    await tester.pumpAndSettle();

    expect(find.text('Anuncio no disponible ahora'), findsOneWidget);
    expect(await prefs.isAdBreakActive(), isFalse);
  });

  testWidgets('con break previo muestra el banner sin marcar Pro',
      (tester) async {
    await prefs.grantAdBreak(const Duration(hours: 24));

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('Tienes 24 h sin anuncios'), findsWidgets);
    expect(await purchases.isPro(), isFalse);
  });

  testWidgets('con Pro previo muestra estado y restaurar lo mantiene',
      (tester) async {
    await prefs.setProActive(true);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('Pro activo'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Conseguir Pro'), findsNothing);

    await tester.tap(find.text('Restaurar compras'));
    await tester.pumpAndSettle();

    expect(await purchases.isPro(), isTrue);
  });
}
