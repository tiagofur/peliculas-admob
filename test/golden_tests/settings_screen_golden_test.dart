import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peliculas/presentation/screens/settings_screen.dart';
import 'package:peliculas/presentation/providers/theme/theme_provider.dart';
import 'package:peliculas/presentation/providers/locale/locale_provider.dart';

void main() {
  group('Settings Screen Golden Tests', () {
    testWidgets('Settings screen renders correctly in light theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Mock theme provider
            themeNotifierProvider.overrideWith((ref) => ThemeState(
              selectedColor: 0,
              themeMode: ThemeMode.light,
            )),
            // Mock locale provider
            localeNotifierProvider.overrideWith((ref) => const LocaleState(
              locale: Locale('es', 'ES'),
            )),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: const SettingsScreen(),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Take golden test screenshot
      await expectLater(
        find.byType(SettingsScreen),
        matchesGoldenFile('golden_tests/settings_screen_light.png'),
      );
    });

    testWidgets('Settings screen renders correctly in dark theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Mock theme provider with dark theme
            themeNotifierProvider.overrideWith((ref) => ThemeState(
              selectedColor: 0,
              themeMode: ThemeMode.dark,
            )),
            // Mock locale provider
            localeNotifierProvider.overrideWith((ref) => const LocaleState(
              locale: Locale('es', 'ES'),
            )),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const SettingsScreen(),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Take golden test screenshot
      await expectLater(
        find.byType(SettingsScreen),
        matchesGoldenFile('golden_tests/settings_screen_dark.png'),
      );
    });

    testWidgets('Settings screen with system theme renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Mock theme provider with system theme
            themeNotifierProvider.overrideWith((ref) => ThemeState(
              selectedColor: 2, // Different color scheme
              themeMode: ThemeMode.system,
            )),
            // Mock locale provider with English
            localeNotifierProvider.overrideWith((ref) => const LocaleState(
              locale: Locale('en', 'US'),
            )),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: const SettingsScreen(),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Take golden test screenshot
      await expectLater(
        find.byType(SettingsScreen),
        matchesGoldenFile('golden_tests/settings_screen_system_theme.png'),
      );
    });
  });
}

// Mock ThemeState for testing
class ThemeState {
  final int selectedColor;
  final ThemeMode themeMode;

  const ThemeState({
    required this.selectedColor,
    required this.themeMode,
  });

  bool get isDarkMode => themeMode == ThemeMode.dark;
}

// Mock LocaleState for testing
class LocaleState {
  final Locale locale;

  const LocaleState({
    required this.locale,
  });
}