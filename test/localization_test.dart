import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peliculas/generated/app_localizations.dart';
import 'package:peliculas/presentation/providers/locale/locale_provider.dart';

void main() {
  group('Localization Tests', () {
    testWidgets('AppLocalizations should work with English locale', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context)!;
                return Scaffold(
                  appBar: AppBar(title: Text(l10n.settings)),
                  body: Text(l10n.home),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('AppLocalizations should work with Spanish locale', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context)!;
                return Scaffold(
                  appBar: AppBar(title: Text(l10n.settings)),
                  body: Text(l10n.home),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Configuración'), findsOneWidget);
      expect(find.text('Inicio'), findsOneWidget);
    });

    testWidgets('LocaleNotifier should save and load locale preference', (tester) async {
      final container = ProviderContainer();
      final localeNotifier = container.read(localeNotifierProvider.notifier);

      // Test setting locale
      await localeNotifier.setLocale(const Locale('es'));
      final state = container.read(localeNotifierProvider);
      
      expect(state.locale?.languageCode, equals('es'));

      container.dispose();
    });

    test('Supported locales should include Spanish and English', () {
      const supportedLocales = AppLocalizations.supportedLocales;
      
      expect(supportedLocales, contains(const Locale('es')));
      expect(supportedLocales, contains(const Locale('en')));
      expect(supportedLocales.length, equals(2));
    });

    testWidgets('Theme mode strings should be localized correctly', (tester) async {
      // Test English
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return Column(
                children: [
                  Text(l10n.system),
                  Text(l10n.light),
                  Text(l10n.dark),
                ],
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);

      // Test Spanish
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return Column(
                children: [
                  Text(l10n.system),
                  Text(l10n.light),
                  Text(l10n.dark),
                ],
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sistema'), findsOneWidget);
      expect(find.text('Claro'), findsOneWidget);
      expect(find.text('Oscuro'), findsOneWidget);
    });

    testWidgets('Navigation labels should be localized correctly', (tester) async {
      // Test English navigation labels
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return Column(
                children: [
                  Text(l10n.home),
                  Text(l10n.myLibrary),
                  Text(l10n.statistics),
                  Text(l10n.streaming),
                  Text(l10n.challenges),
                ],
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('My Library'), findsOneWidget);
      expect(find.text('Statistics'), findsOneWidget);
      expect(find.text('Streaming'), findsOneWidget);
      expect(find.text('Challenges'), findsOneWidget);

      // Test Spanish navigation labels
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return Column(
                children: [
                  Text(l10n.home),
                  Text(l10n.myLibrary),
                  Text(l10n.statistics),
                  Text(l10n.streaming),
                  Text(l10n.challenges),
                ],
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Mi Biblioteca'), findsOneWidget);
      expect(find.text('Estadísticas'), findsOneWidget);
      expect(find.text('Streaming'), findsOneWidget);
      expect(find.text('Desafíos'), findsOneWidget);
    });
  });
}