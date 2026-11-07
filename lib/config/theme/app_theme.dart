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

  /// System San Francisco font on Apple platforms (iOS/macOS resolve
  /// `.SF Pro Text` to the native typeface). Null elsewhere so every
  /// other platform keeps its default Roboto/Noto stack.
  static String? _appleSystemFont() {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return '.SF Pro Text';
    }
    return null;
  }

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
      // Apple TV app look: pure-black canvas in dark mode. The seeded
      // tonal containers stay slightly lifted so cards read as layered
      // surfaces, like tvOS focus rows.
      if (isDark) {
        colorScheme = colorScheme.copyWith(surface: Colors.black);
      }
    }

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      // Apple TV is dark-first; iOS light mode uses the grouped
      // background so white cards sit on system gray, like Settings.
      scaffoldBackgroundColor:
          isDark ? Colors.black : const Color(0xFFF2F2F7),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
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
    final defaultTheme =
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    // Native San Francisco voice on Apple platforms; the fallback stack
    // below keeps emoji and missing glyphs covered everywhere.
    final baseTheme = _appleSystemFont() == null
        ? defaultTheme
        : defaultTheme.apply(fontFamily: _appleSystemFont());

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

    // Apply fallback fonts to regular theme as well. Titles get the
    // Apple large-title voice: semibold with tight tracking.
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
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
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
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
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
