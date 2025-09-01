import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/config/theme/app_theme.dart';

void main() {
  group('Accessibility Theme Tests', () {
    testWidgets('should generate high contrast theme when enabled', (WidgetTester tester) async {
      Widget testWidget = MediaQuery(
        data: const MediaQueryData(highContrast: true),
        child: Builder(
          builder: (context) {
            final appTheme = AppTheme();
            final theme = appTheme.getTheme(context);
            
            // Verify high contrast colors are applied
            expect(theme.colorScheme.primary, equals(Colors.black));
            expect(theme.colorScheme.onPrimary, equals(Colors.white));
            expect(theme.colorScheme.surface, equals(Colors.white));
            expect(theme.colorScheme.onSurface, equals(Colors.black));
            
            return Container();
          },
        ),
      );

      await tester.pumpWidget(testWidget);
    });

    testWidgets('should generate high contrast dark theme when enabled', (WidgetTester tester) async {
      Widget testWidget = MediaQuery(
        data: const MediaQueryData(
          highContrast: true,
          platformBrightness: Brightness.dark,
        ),
        child: Builder(
          builder: (context) {
            final appTheme = AppTheme(themeMode: ThemeMode.dark);
            final theme = appTheme.getTheme(context);
            
            // Verify high contrast dark colors are applied
            expect(theme.colorScheme.primary, equals(Colors.white));
            expect(theme.colorScheme.onPrimary, equals(Colors.black));
            expect(theme.colorScheme.surface, equals(Colors.black));
            expect(theme.colorScheme.onSurface, equals(Colors.white));
            
            return Container();
          },
        ),
      );

      await tester.pumpWidget(testWidget);
    });

    testWidgets('should provide accessible button sizes', (WidgetTester tester) async {
      Widget testWidget = Builder(
        builder: (context) {
          final appTheme = AppTheme();
          final theme = appTheme.getTheme(context);
          
          // Check elevated button theme has minimum size
          final elevatedButtonTheme = theme.elevatedButtonTheme;
          expect(
            elevatedButtonTheme.style?.minimumSize?.resolve({}),
            equals(const Size(44, 44)),
          );
          
          // Check icon button theme has minimum size
          final iconButtonTheme = theme.iconButtonTheme;
          expect(
            iconButtonTheme.style?.minimumSize?.resolve({}),
            equals(const Size(44, 44)),
          );
          
          return Container();
        },
      );

      await tester.pumpWidget(testWidget);
    });

    testWidgets('should enhance text theme for high contrast', (WidgetTester tester) async {
      Widget testWidget = MediaQuery(
        data: const MediaQueryData(highContrast: true),
        child: Builder(
          builder: (context) {
            final appTheme = AppTheme();
            final theme = appTheme.getTheme(context);
            
            // Check that text styles have enhanced weights for high contrast
            expect(
              theme.textTheme.bodyLarge?.fontWeight,
              equals(FontWeight.w600),
            );
            expect(
              theme.textTheme.bodyMedium?.fontWeight,
              equals(FontWeight.w500),
            );
            expect(
              theme.textTheme.titleLarge?.fontWeight,
              equals(FontWeight.w700),
            );
            
            // Check high contrast colors
            expect(
              theme.textTheme.bodyLarge?.color,
              equals(Colors.black),
            );
            
            return Container();
          },
        ),
      );

      await tester.pumpWidget(testWidget);
    });

    testWidgets('should use normal theme when high contrast is disabled', (WidgetTester tester) async {
      Widget testWidget = MediaQuery(
        data: const MediaQueryData(highContrast: false),
        child: Builder(
          builder: (context) {
            final appTheme = AppTheme();
            final theme = appTheme.getTheme(context);
            
            // Verify normal color scheme is used (not pure black/white)
            expect(theme.colorScheme.primary, isNot(equals(Colors.black)));
            expect(theme.colorScheme.primary, isNot(equals(Colors.white)));
            
            return Container();
          },
        ),
      );

      await tester.pumpWidget(testWidget);
    });

    test('should detect dark mode correctly', () {
      final lightTheme = AppTheme(themeMode: ThemeMode.light);
      final darkTheme = AppTheme(themeMode: ThemeMode.dark);
      final systemTheme = AppTheme(themeMode: ThemeMode.system);
      
      expect(lightTheme.isDarkMode, isFalse);
      expect(darkTheme.isDarkMode, isTrue);
      expect(systemTheme.isSystemMode, isTrue);
    });

    testWidgets('should respond to system brightness changes', (WidgetTester tester) async {
      // Test light system mode
      Widget lightWidget = MediaQuery(
        data: const MediaQueryData(
          platformBrightness: Brightness.light,
          highContrast: false,
        ),
        child: Builder(
          builder: (context) {
            final appTheme = AppTheme(themeMode: ThemeMode.system);
            final theme = appTheme.getTheme(context);
            
            expect(theme.brightness, equals(Brightness.light));
            return Container();
          },
        ),
      );

      await tester.pumpWidget(lightWidget);

      // Test dark system mode  
      Widget darkWidget = MediaQuery(
        data: const MediaQueryData(
          platformBrightness: Brightness.dark,
          highContrast: false,
        ),
        child: Builder(
          builder: (context) {
            final appTheme = AppTheme(themeMode: ThemeMode.system);
            final theme = appTheme.getTheme(context);
            
            expect(theme.brightness, equals(Brightness.dark));
            return Container();
          },
        ),
      );

      await tester.pumpWidget(darkWidget);
    });

    test('should validate color list bounds', () {
      expect(() => AppTheme(selectedColor: -1), throwsAssertionError);
      expect(() => AppTheme(selectedColor: 10), throwsAssertionError); // assuming colorList has < 10 items
      expect(() => AppTheme(selectedColor: 0), returnsNormally);
    });

    test('should copy theme with new values', () {
      final originalTheme = AppTheme(
        selectedColor: 0,
        themeMode: ThemeMode.light,
      );
      
      final copiedTheme = originalTheme.copyWith(
        selectedColor: 1,
        themeMode: ThemeMode.dark,
      );
      
      expect(copiedTheme.selectedColor, equals(1));
      expect(copiedTheme.themeMode, equals(ThemeMode.dark));
      expect(originalTheme.selectedColor, equals(0));
      expect(originalTheme.themeMode, equals(ThemeMode.light));
    });
  });
}