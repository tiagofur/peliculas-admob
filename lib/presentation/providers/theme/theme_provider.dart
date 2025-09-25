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

// Simple theme service
class ThemeService {
  ThemeService(this.themeRepository);
  final ThemeRepository themeRepository;

  ThemeState _state = ThemeState();
  final List<Function(ThemeState)> _listeners = [];

  ThemeState get state => _state;

  // Compatibility getters
  ThemeMode get themeMode => _state.themeMode;
  int get selectedColor => _state.selectedColor;
  bool get isDarkMode => _state.isDarkMode;

  void addListener(Function(ThemeState) listener) {
    _listeners.add(listener);
  }

  void removeListener(Function(ThemeState) listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener(_state);
    }
  }

  Future<void> loadTheme() async {
    final (themeMode, selectedColor) = await themeRepository.getTheme();
    _state = _state.copyWith(
      themeMode: themeMode,
      selectedColor: selectedColor,
    );
    _notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    _state = _state.copyWith(themeMode: themeMode);
    await themeRepository.saveTheme(themeMode, _state.selectedColor);
    _notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    final newMode =
        _state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }

  material.ThemeMode get flutterThemeMode {
    switch (_state.themeMode) {
      case ThemeMode.system:
        return material.ThemeMode.system;
      case ThemeMode.light:
        return material.ThemeMode.light;
      case ThemeMode.dark:
        return material.ThemeMode.dark;
    }
  }

  Future<void> changeColorIndex(int colorIndex) async {
    _state = _state.copyWith(selectedColor: colorIndex);
    await themeRepository.saveTheme(_state.themeMode, colorIndex);
    _notifyListeners();
  }
}

// Provider for theme service
final themeServiceProvider = Provider<ThemeService>((ref) {
  final themeRepository = ref.watch(themeRepositoryProvider);
  final service = ThemeService(themeRepository);
  service.loadTheme(); // Load initial theme
  return service;
});

// Provider for theme state
final themeStateProvider = Provider<ThemeState>((ref) {
  return ref.watch(themeServiceProvider).state;
});

// Compatibility provider that mimics old StateNotifierProvider behavior
class ThemeNotifierProviderRef {
  const ThemeNotifierProviderRef(this.service);
  final ThemeService service;

  ThemeService get notifier => service;
  ThemeService call() => service;
}

// Provider for theme notifier - returns ThemeService directly for backwards compatibility
final themeNotifierProvider = Provider<ThemeService>((ref) {
  return ref.watch(themeServiceProvider);
});

// Separate provider that provides .notifier access
final themeNotifierWithNotifierProvider =
    Provider<ThemeNotifierProviderRef>((ref) {
  final service = ref.watch(themeServiceProvider);
  return ThemeNotifierProviderRef(service);
});
