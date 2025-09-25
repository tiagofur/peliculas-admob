import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provider for managing the locale state
final localeNotifierProvider = NotifierProvider<LocaleNotifier, LocaleState>(
  () => LocaleNotifier(),
);

// State class for locale
class LocaleState {
  const LocaleState({
    this.locale,
    this.isLoading = false,
  });
  final Locale? locale;
  final bool isLoading;

  LocaleState copyWith({
    Locale? locale,
    bool? isLoading,
  }) {
    return LocaleState(
      locale: locale ?? this.locale,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Notifier for locale state changes
class LocaleNotifier extends Notifier<LocaleState> {
  LocaleNotifier();

  static const String _localeKey = 'app_locale';

  @override
  LocaleState build() {
    // Return initial state without loading - let initialization happen later
    return const LocaleState();
  }

  /// Initialize the locale provider (call this from UI)
  Future<void> initialize() async {
    await _loadLocale();
  }

  Future<void> _loadLocale() async {
    state = state.copyWith(isLoading: true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final localeCode = prefs.getString(_localeKey);

      if (localeCode != null) {
        final locale = Locale(localeCode);
        state = state.copyWith(locale: locale, isLoading: false);
      } else {
        // No saved locale, use system default
        state = state.copyWith(locale: null, isLoading: false);
      }
    } catch (e) {
      // Handle error, use system default
      state = state.copyWith(locale: null, isLoading: false);
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, locale.languageCode);
    } catch (e) {
      // Handle error - could show a snackbar or log
    }
  }

  Future<void> clearLocale() async {
    state = state.copyWith(locale: null);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localeKey);
    } catch (e) {
      // Handle error
    }
  }

  // Get supported locales
  List<Locale> get supportedLocales => const [
        Locale('es'), // Spanish
        Locale('en'), // English
      ];
}
