import 'package:flutter/material.dart' as material;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../config/theme/app_theme.dart';
import '../../../domain/repositories/theme_repository.dart';
import 'theme_repository_provider.dart';

// Provider for the list of available colors
final colorListProvider = Provider<List<material.Color>>((ref) => colorList);

// Provider for managing the theme state
final themeNotifierProvider = StateNotifierProvider<ThemeNotifier, ThemeState>(
  (ref) {
    final themeRepository = ref.watch(themeRepositoryProvider);
    return ThemeNotifier(themeRepository: themeRepository);
  },
);

// Notifier for theme state changes
class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier({required this.themeRepository}) : super(ThemeState()) {
    _loadTheme();
  }
  final ThemeRepository themeRepository;

  Future<void> _loadTheme() async {
    final (themeMode, selectedColor) = await themeRepository.getTheme();
    state = state.copyWith(
      themeMode: themeMode,
      selectedColor: selectedColor,
    );
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    state = state.copyWith(themeMode: themeMode);
    await themeRepository.saveTheme(themeMode, state.selectedColor);
  }

  Future<void> toggleDarkMode() async {
    // Para mantener compatibilidad con el comportamiento anterior
    final newMode =
        state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }

  // Método de conversión para compatibilidad con Flutter ThemeMode
  material.ThemeMode get flutterThemeMode {
    switch (state.themeMode) {
      case ThemeMode.system:
        return material.ThemeMode.system;
      case ThemeMode.light:
        return material.ThemeMode.light;
      case ThemeMode.dark:
        return material.ThemeMode.dark;
    }
  }

  Future<void> changeColorIndex(int colorIndex) async {
    state = state.copyWith(selectedColor: colorIndex);
    await themeRepository.saveTheme(state.themeMode, colorIndex);
  }

  @override
  void dispose() {
    // Limpiar recursos si es necesario
    super.dispose();
  }
}

// State class for the theme
class ThemeState {
  ThemeState({
    this.themeMode = ThemeMode.system,
    this.selectedColor = 0,
  });

  final ThemeMode themeMode;
  final int selectedColor;

  // Compatibilidad con la implementación anterior
  bool get isDarkMode => themeMode == ThemeMode.dark;

  ThemeState copyWith({
    ThemeMode? themeMode,
    int? selectedColor,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      selectedColor: selectedColor ?? this.selectedColor,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ThemeState &&
        other.themeMode == themeMode &&
        other.selectedColor == selectedColor;
  }

  @override
  int get hashCode => themeMode.hashCode ^ selectedColor.hashCode;
}
