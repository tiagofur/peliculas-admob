import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
      case ThemeMode.light:
        return false;
      case ThemeMode.dark:
        return true;
    }
  }

  ThemeData getTheme([BuildContext? context]) {
    final isDark = _shouldUseDarkMode(context);
    
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorSchemeSeed: colorList[selectedColor],
      appBarTheme: const AppBarTheme(
        centerTitle: false,
      ),
    );
  }

  // Configurar el color de la barra de estado
  void updateSystemUIOverlay([BuildContext? context]) {
    final isDark = _shouldUseDarkMode(context);
    
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isDark ? Colors.black : Colors.white,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
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
