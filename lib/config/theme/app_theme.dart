import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/accessibility_service.dart';

const colorList = <Color>[
  Colors.blue,
  Colors.teal,
  Colors.green,
  Colors.red,
  Colors.purple,
  Colors.orange,
];

enum ThemeMode {
  system,
  light,
  dark,
}

class AppTheme {
  AppTheme({
    this.selectedColor = 0,
    this.themeMode = ThemeMode.system,
  })  : assert(selectedColor >= 0, 'Selected color must be greater then 0'),
        assert(selectedColor < colorList.length,
            'Selected color must be less or equal than ${colorList.length - 1}');

  final int selectedColor;
  final ThemeMode themeMode;

  // Determinar si debe usar tema oscuro basado en el modo y brillo del sistema
  bool _shouldUseDarkMode(BuildContext? context) {
    switch (themeMode) {
      case ThemeMode.system:
        if (context != null) {
          return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        }
        // Fallback si no hay contexto disponible
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
      case ThemeMode.light:
        return false;
      case ThemeMode.dark:
        return true;
    }
  }

  ThemeData getTheme([BuildContext? context]) {
    final isDark = _shouldUseDarkMode(context);
    final isHighContrast =
        context != null && AccessibilityService.isHighContrastEnabled(context);

    ColorScheme colorScheme;

    if (isHighContrast) {
      // High contrast theme for WCAG AA compliance
      colorScheme = isDark
          ? const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              secondary: Colors.white,
              onSecondary: Colors.black,
              surface: Colors.black,
              onSurface: Colors.white,
              error: Colors.red,
              onError: Colors.white,
            )
          : const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              secondary: Colors.black,
              onSecondary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
              error: Colors.red,
              onError: Colors.white,
            );
    } else {
      colorScheme = ColorScheme.fromSeed(
        seedColor: colorList[selectedColor],
        brightness: isDark ? Brightness.dark : Brightness.light,
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
      ),
      // Enhanced button theme for accessibility
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(44, 44), // WCAG AA minimum touch target
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44), // WCAG AA minimum touch target
        ),
      ),
      // Enhanced text theme for better readability
      textTheme: _buildAccessibleTextTheme(isDark, isHighContrast),
    );
  }

  /// Build text theme with accessibility enhancements
  TextTheme _buildAccessibleTextTheme(bool isDark, bool isHighContrast) {
    final baseTheme =
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;

    // Define fallback fonts for missing characters
    const fontFallbacks = ['NotoSans', 'NotoColorEmoji'];

    if (isHighContrast) {
      // Enhanced contrast and weight for high contrast mode
      return baseTheme.copyWith(
        bodyLarge: baseTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
          fontFamilyFallback: fontFallbacks,
        ),
        bodyMedium: baseTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black,
          fontFamilyFallback: fontFallbacks,
        ),
        bodySmall: baseTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black,
          fontFamilyFallback: fontFallbacks,
        ),
        titleLarge: baseTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black,
          fontFamilyFallback: fontFallbacks,
        ),
        titleMedium: baseTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
          fontFamilyFallback: fontFallbacks,
        ),
        titleSmall: baseTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
          fontFamilyFallback: fontFallbacks,
        ),
      );
    }

    // Apply fallback fonts to regular theme as well
    return baseTheme.copyWith(
      bodyLarge: baseTheme.bodyLarge?.copyWith(
        fontFamilyFallback: fontFallbacks,
      ),
      bodyMedium: baseTheme.bodyMedium?.copyWith(
        fontFamilyFallback: fontFallbacks,
      ),
      bodySmall: baseTheme.bodySmall?.copyWith(
        fontFamilyFallback: fontFallbacks,
      ),
      titleLarge: baseTheme.titleLarge?.copyWith(
        fontFamilyFallback: fontFallbacks,
      ),
      titleMedium: baseTheme.titleMedium?.copyWith(
        fontFamilyFallback: fontFallbacks,
      ),
      titleSmall: baseTheme.titleSmall?.copyWith(
        fontFamilyFallback: fontFallbacks,
      ),
      headlineLarge: baseTheme.headlineLarge?.copyWith(
        fontFamilyFallback: fontFallbacks,
      ),
      headlineMedium: baseTheme.headlineMedium?.copyWith(
        fontFamilyFallback: fontFallbacks,
      ),
      headlineSmall: baseTheme.headlineSmall?.copyWith(
        fontFamilyFallback: fontFallbacks,
      ),
      displayLarge: baseTheme.displayLarge?.copyWith(
        fontFamilyFallback: fontFallbacks,
      ),
      displayMedium: baseTheme.displayMedium?.copyWith(
        fontFamilyFallback: fontFallbacks,
      ),
      displaySmall: baseTheme.displaySmall?.copyWith(
        fontFamilyFallback: fontFallbacks,
      ),
      labelLarge: baseTheme.labelLarge?.copyWith(
        fontFamilyFallback: fontFallbacks,
      ),
      labelMedium: baseTheme.labelMedium?.copyWith(
        fontFamilyFallback: fontFallbacks,
      ),
      labelSmall: baseTheme.labelSmall?.copyWith(
        fontFamilyFallback: fontFallbacks,
      ),
    );
  }

  // Configurar el color de la barra de estado
  void updateSystemUIOverlay([BuildContext? context]) {
    // SystemChrome no es compatible con web
    if (kIsWeb) return;
    
    final isDark = _shouldUseDarkMode(context);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isDark ? Colors.black : Colors.white,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  // Método de conveniencia para verificar si está en modo oscuro
  bool get isDarkMode => themeMode == ThemeMode.dark;

  // Método de conveniencia para verificar si sigue el sistema
  bool get isSystemMode => themeMode == ThemeMode.system;

  AppTheme copyWith({
    int? selectedColor,
    ThemeMode? themeMode,
  }) {
    return AppTheme(
      selectedColor: selectedColor ?? this.selectedColor,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}
