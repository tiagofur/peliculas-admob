import 'package:flutter/material.dart' as material;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme/app_theme.dart';
import '../../../domain/repositories/theme_repository.dart';
import 'theme_repository_provider.dart';

// Provider for the list of available colors
final colorListProvider = Provider<List<material.Color>>((ref) => colorList);

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

// Theme notifier handling the state and persistence
class ThemeNotifier extends Notifier<ThemeState> {
  late final ThemeRepository _themeRepository;

  @override
  ThemeState build() {
    _themeRepository = ref.watch(themeRepositoryProvider);
    _loadInitialTheme();
    return ThemeState();
  }

  void _loadInitialTheme() {
    Future<void>(() async {
      final (themeMode, selectedColor) = await _themeRepository.getTheme();
      state = state.copyWith(
        themeMode: themeMode,
        selectedColor: selectedColor,
      );
    });
  }

  ThemeMode get themeMode => state.themeMode;
  int get selectedColor => state.selectedColor;
  bool get isDarkMode => state.isDarkMode;

  Future<void> setThemeMode(ThemeMode themeMode) async {
    state = state.copyWith(themeMode: themeMode);
    await _themeRepository.saveTheme(themeMode, state.selectedColor);
  }

  Future<void> toggleDarkMode() async {
    final newMode =
        state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }

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
    await _themeRepository.saveTheme(state.themeMode, colorIndex);
  }
}

final themeNotifierProvider = NotifierProvider<ThemeNotifier, ThemeState>(
  ThemeNotifier.new,
);

final themeControllerProvider = Provider<ThemeNotifier>((ref) {
  return ref.watch(themeNotifierProvider.notifier);
});

final themeStateProvider = Provider<ThemeState>((ref) {
  return ref.watch(themeNotifierProvider);
});
