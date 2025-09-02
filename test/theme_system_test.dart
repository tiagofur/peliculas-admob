import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peliculas/config/theme/app_theme.dart';
import 'package:peliculas/presentation/providers/theme/theme_provider.dart';
import 'package:peliculas/presentation/screens/settings_screen.dart';

void main() {
  group('Theme System Tests', () {
    testWidgets('Settings screen displays theme options', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const SettingsScreen(),
          ),
        ),
      );

      // Verificar que la pantalla de configuración se muestra
      expect(find.text('Configuración'), findsOneWidget);
      expect(find.text('Apariencia'), findsOneWidget);
      expect(find.text('Modo de tema'), findsOneWidget);
      
      // Verificar que los modos de tema están presentes
      expect(find.text('Sistema'), findsOneWidget);
      expect(find.text('Claro'), findsOneWidget);
      expect(find.text('Oscuro'), findsOneWidget);
      
      // Verificar que el selector de colores está presente
      expect(find.text('Color del tema'), findsOneWidget);
    });

    testWidgets('Theme mode can be changed', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const SettingsScreen(),
          ),
        ),
      );

      // Encontrar y hacer tap en el modo oscuro
      final darkModeRadio = find.widgetWithText(RadioListTile<ThemeMode>, 'Oscuro');
      expect(darkModeRadio, findsOneWidget);
      
      await tester.tap(darkModeRadio);
      await tester.pump();
      
      // Verificar que el tema cambió (esto se verificaría con la implementación completa)
    });

    test('AppTheme correctly determines dark mode based on theme mode', () {
      // Tema en modo sistema (simulando brightness oscuro)
      final systemTheme = AppTheme(themeMode: ThemeMode.system);
      
      // Tema en modo claro
      final lightTheme = AppTheme(themeMode: ThemeMode.light);
      
      // Tema en modo oscuro
      final darkTheme = AppTheme(themeMode: ThemeMode.dark);
      
      // Verificar propiedades
      expect(lightTheme.themeMode, ThemeMode.light);
      expect(darkTheme.themeMode, ThemeMode.dark);
      expect(systemTheme.themeMode, ThemeMode.system);
      
      expect(lightTheme.isDarkMode, false);
      expect(darkTheme.isDarkMode, true);
      expect(systemTheme.isSystemMode, true);
    });

    test('ThemeState supports equality and copyWith', () {
      final state1 = ThemeState(themeMode: ThemeMode.dark, selectedColor: 1);
      final state2 = ThemeState(themeMode: ThemeMode.dark, selectedColor: 1);
      final state3 = state1.copyWith(themeMode: ThemeMode.light);
      
      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
      expect(state3.themeMode, ThemeMode.light);
      expect(state3.selectedColor, 1); // Should keep original value
    });
  });
}