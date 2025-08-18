import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme/app_theme.dart';
import '../../../domain/repositories/theme_repository.dart';
import 'theme_repository_provider.dart';

// Provider for the list of available colors
final colorListProvider = Provider<List<Color>>((ref) => colorList);

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
    final (isDarkMode, selectedColor) = await themeRepository.getTheme();
    state = state.copyWith(
      isDarkMode: isDarkMode,
      selectedColor: selectedColor,
    );
  }

  Future<void> toggleDarkMode() async {
    final newDarkMode = !state.isDarkMode;
    state = state.copyWith(isDarkMode: newDarkMode);
    await themeRepository.saveTheme(newDarkMode, state.selectedColor);
  }

  Future<void> changeColorIndex(int colorIndex) async {
    state = state.copyWith(selectedColor: colorIndex);
    await themeRepository.saveTheme(state.isDarkMode, colorIndex);
  }
}

// State class for the theme
class ThemeState {
  ThemeState({
    this.isDarkMode = false,
    this.selectedColor = 0,
  });
  final bool isDarkMode;
  final int selectedColor;

  ThemeState copyWith({
    bool? isDarkMode,
    int? selectedColor,
  }) {
    return ThemeState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      selectedColor: selectedColor ?? this.selectedColor,
    );
  }
}
