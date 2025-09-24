// lib/services/ux_community/theme/advanced_theme_manager.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/logger_factory.dart';

enum ThemeMode {
  system,
  light,
  dark,
  auto, // Changes based on time of day
  custom,
}

enum AccentColor {
  blue,
  green,
  red,
  purple,
  orange,
  teal,
  pink,
  indigo,
}

class CustomTheme {
  const CustomTheme({
    required this.id,
    required this.name,
    required this.lightColorScheme,
    required this.darkColorScheme,
    required this.textTheme,
    this.customProperties = const {},
    required this.createdAt,
    this.isUserCreated = true,
  });

  factory CustomTheme.fromJson(Map<String, dynamic> json) {
    return CustomTheme(
      id: json['id'],
      name: json['name'],
      lightColorScheme: ColorScheme.light(
        primary: Color(json['lightColorScheme']['primary']),
        secondary: Color(json['lightColorScheme']['secondary']),
        surface: Color(json['lightColorScheme']['surface']),
        error: Color(json['lightColorScheme']['error']),
      ),
      darkColorScheme: ColorScheme.dark(
        primary: Color(json['darkColorScheme']['primary']),
        secondary: Color(json['darkColorScheme']['secondary']),
        surface: Color(json['darkColorScheme']['surface']),
        error: Color(json['darkColorScheme']['error']),
      ),
      textTheme: const TextTheme(), // Simplified for example
      customProperties: json['customProperties'] ?? {},
      createdAt: DateTime.parse(json['createdAt']),
      isUserCreated: json['isUserCreated'] ?? true,
    );
  }
  final String id;
  final String name;
  final ColorScheme lightColorScheme;
  final ColorScheme darkColorScheme;
  final TextTheme textTheme;
  final Map<String, dynamic> customProperties;
  final DateTime createdAt;
  final bool isUserCreated;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lightColorScheme': {
        'primary': lightColorScheme.primary.toARGB32(),
        'secondary': lightColorScheme.secondary.toARGB32(),
        'surface': lightColorScheme.surface.toARGB32(),
        'background': lightColorScheme.surface.toARGB32(),
        'error': lightColorScheme.error.toARGB32(),
      },
      'darkColorScheme': {
        'primary': darkColorScheme.primary.toARGB32(),
        'secondary': darkColorScheme.secondary.toARGB32(),
        'surface': darkColorScheme.surface.toARGB32(),
        'background': darkColorScheme.surface.toARGB32(),
        'error': darkColorScheme.error.toARGB32(),
      },
      'customProperties': customProperties,
      'createdAt': createdAt.toIso8601String(),
      'isUserCreated': isUserCreated,
    };
  }
}

class ThemeSettings {
  const ThemeSettings({
    this.mode = ThemeMode.system,
    this.accentColor = AccentColor.blue,
    this.adaptiveColors = true,
    this.highContrast = false,
    this.fontScale = 1.0,
    this.followSystemAccent = true,
    this.autoLightStart = const TimeOfDay(hour: 6, minute: 0),
    this.autoDarkStart = const TimeOfDay(hour: 18, minute: 0),
    this.customThemeId,
    this.enableAnimations = true,
    this.enableHapticFeedback = true,
  });

  factory ThemeSettings.fromJson(Map<String, dynamic> json) {
    return ThemeSettings(
      mode: ThemeMode.values.firstWhere(
        (e) => e.toString() == json['mode'],
        orElse: () => ThemeMode.system,
      ),
      accentColor: AccentColor.values.firstWhere(
        (e) => e.toString() == json['accentColor'],
        orElse: () => AccentColor.blue,
      ),
      adaptiveColors: json['adaptiveColors'] ?? true,
      highContrast: json['highContrast'] ?? false,
      fontScale: json['fontScale']?.toDouble() ?? 1.0,
      followSystemAccent: json['followSystemAccent'] ?? true,
      autoLightStart: _parseTimeOfDay(json['autoLightStart'] ?? '6:0'),
      autoDarkStart: _parseTimeOfDay(json['autoDarkStart'] ?? '18:0'),
      customThemeId: json['customThemeId'],
      enableAnimations: json['enableAnimations'] ?? true,
      enableHapticFeedback: json['enableHapticFeedback'] ?? true,
    );
  }
  final ThemeMode mode;
  final AccentColor accentColor;
  final bool adaptiveColors;
  final bool highContrast;
  final double fontScale;
  final bool followSystemAccent;
  final TimeOfDay autoLightStart;
  final TimeOfDay autoDarkStart;
  final String? customThemeId;
  final bool enableAnimations;
  final bool enableHapticFeedback;

  ThemeSettings copyWith({
    ThemeMode? mode,
    AccentColor? accentColor,
    bool? adaptiveColors,
    bool? highContrast,
    double? fontScale,
    bool? followSystemAccent,
    TimeOfDay? autoLightStart,
    TimeOfDay? autoDarkStart,
    String? customThemeId,
    bool? enableAnimations,
    bool? enableHapticFeedback,
  }) {
    return ThemeSettings(
      mode: mode ?? this.mode,
      accentColor: accentColor ?? this.accentColor,
      adaptiveColors: adaptiveColors ?? this.adaptiveColors,
      highContrast: highContrast ?? this.highContrast,
      fontScale: fontScale ?? this.fontScale,
      followSystemAccent: followSystemAccent ?? this.followSystemAccent,
      autoLightStart: autoLightStart ?? this.autoLightStart,
      autoDarkStart: autoDarkStart ?? this.autoDarkStart,
      customThemeId: customThemeId ?? this.customThemeId,
      enableAnimations: enableAnimations ?? this.enableAnimations,
      enableHapticFeedback: enableHapticFeedback ?? this.enableHapticFeedback,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.toString(),
      'accentColor': accentColor.toString(),
      'adaptiveColors': adaptiveColors,
      'highContrast': highContrast,
      'fontScale': fontScale,
      'followSystemAccent': followSystemAccent,
      'autoLightStart': '${autoLightStart.hour}:${autoLightStart.minute}',
      'autoDarkStart': '${autoDarkStart.hour}:${autoDarkStart.minute}',
      'customThemeId': customThemeId,
      'enableAnimations': enableAnimations,
      'enableHapticFeedback': enableHapticFeedback,
    };
  }

  static TimeOfDay _parseTimeOfDay(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }
}

class AdvancedThemeManager {
  static const String _settingsKey = 'theme_settings';
  static const String _customThemesKey = 'custom_themes';
  static const String _themeHistoryKey = 'theme_history';

  final ValueNotifier<ThemeData> _lightThemeNotifier =
      ValueNotifier(ThemeData.light());
  final ValueNotifier<ThemeData> _darkThemeNotifier =
      ValueNotifier(ThemeData.dark());
  final ValueNotifier<ThemeSettings> _settingsNotifier =
      ValueNotifier(const ThemeSettings());
  final ValueNotifier<bool> _isDarkModeNotifier = ValueNotifier(false);

  Timer? _autoThemeTimer;
  SharedPreferences? _prefs;
  final Map<String, CustomTheme> _customThemes = {};
  final List<String> _themeHistory = [];

  // Getters
  ValueNotifier<ThemeData> get lightThemeNotifier => _lightThemeNotifier;
  ValueNotifier<ThemeData> get darkThemeNotifier => _darkThemeNotifier;
  ValueNotifier<ThemeSettings> get settingsNotifier => _settingsNotifier;
  ValueNotifier<bool> get isDarkModeNotifier => _isDarkModeNotifier;

  ThemeData get lightTheme => _lightThemeNotifier.value;
  ThemeData get darkTheme => _darkThemeNotifier.value;
  ThemeSettings get settings => _settingsNotifier.value;
  bool get isDarkMode => _isDarkModeNotifier.value;
  Map<String, CustomTheme> get customThemes => Map.unmodifiable(_customThemes);
  List<String> get themeHistory => List.unmodifiable(_themeHistory);

  // Initialize
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSettings();
      await _loadCustomThemes();
      await _loadThemeHistory();
      await _updateThemes();
      _setupAutoThemeScheduler();

      // Listen for system theme changes
      SchedulerBinding.instance.platformDispatcher.onPlatformBrightnessChanged =
          () {
        _handleSystemThemeChange();
      };

      LoggerFactory.info('AdvancedThemeManager initialized successfully');
    } catch (e) {
      LoggerFactory.error('Error initializing AdvancedThemeManager: $e');
      // Use default settings if initialization fails
      _settingsNotifier.value = const ThemeSettings();
      await _updateThemes();
    }
  }

  // Settings Management
  Future<void> updateSettings(ThemeSettings newSettings) async {
    try {
      final oldSettings = _settingsNotifier.value;
      _settingsNotifier.value = newSettings;

      await _saveSettings();
      await _updateThemes();

      // Add to history if theme changed
      if (oldSettings.mode != newSettings.mode ||
          oldSettings.customThemeId != newSettings.customThemeId) {
        _addToThemeHistory(newSettings);
      }

      _setupAutoThemeScheduler();
      LoggerFactory.info('Theme settings updated successfully');
    } catch (e) {
      LoggerFactory.error('Error updating theme settings: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await updateSettings(settings.copyWith(mode: mode));
  }

  Future<void> setAccentColor(AccentColor color) async {
    await updateSettings(settings.copyWith(accentColor: color));
  }

  Future<void> setFontScale(double scale) async {
    if (scale < 0.5 || scale > 2.0) return;
    await updateSettings(settings.copyWith(fontScale: scale));
  }

  Future<void> setHighContrast(bool enabled) async {
    await updateSettings(settings.copyWith(highContrast: enabled));
  }

  Future<void> setAdaptiveColors(bool enabled) async {
    await updateSettings(settings.copyWith(adaptiveColors: enabled));
  }

  Future<void> setAutoThemeSchedule({
    required TimeOfDay lightStart,
    required TimeOfDay darkStart,
  }) async {
    await updateSettings(settings.copyWith(
      autoLightStart: lightStart,
      autoDarkStart: darkStart,
    ));
  }

  // Custom Theme Management
  Future<void> createCustomTheme(CustomTheme theme) async {
    try {
      _customThemes[theme.id] = theme;
      await _saveCustomThemes();
      LoggerFactory.info('Custom theme "${theme.name}" created successfully');
    } catch (e) {
      LoggerFactory.error('Error creating custom theme: $e');
    }
  }

  Future<void> deleteCustomTheme(String themeId) async {
    try {
      _customThemes.remove(themeId);
      await _saveCustomThemes();

      // If this was the active theme, switch to system
      if (settings.customThemeId == themeId) {
        await updateSettings(settings.copyWith(
          mode: ThemeMode.system,
          customThemeId: null,
        ));
      }

      LoggerFactory.info('Custom theme deleted successfully');
    } catch (e) {
      LoggerFactory.error('Error deleting custom theme: $e');
    }
  }

  Future<void> applyCustomTheme(String themeId) async {
    if (_customThemes.containsKey(themeId)) {
      await updateSettings(settings.copyWith(
        mode: ThemeMode.custom,
        customThemeId: themeId,
      ));
    }
  }

  // Theme Building
  Future<void> _updateThemes() async {
    try {
      final newLightTheme = await _buildTheme(Brightness.light);
      final newDarkTheme = await _buildTheme(Brightness.dark);

      _lightThemeNotifier.value = newLightTheme;
      _darkThemeNotifier.value = newDarkTheme;

      _updateDarkModeState();
    } catch (e) {
      LoggerFactory.error('Error updating themes: $e');
    }
  }

  Future<ThemeData> _buildTheme(Brightness brightness) async {
    ColorScheme colorScheme;

    if (settings.mode == ThemeMode.custom && settings.customThemeId != null) {
      final customTheme = _customThemes[settings.customThemeId];
      if (customTheme != null) {
        colorScheme = brightness == Brightness.light
            ? customTheme.lightColorScheme
            : customTheme.darkColorScheme;
      } else {
        colorScheme = brightness == Brightness.light
            ? ColorScheme.fromSeed(seedColor: _getAccentColor())
            : ColorScheme.fromSeed(
                seedColor: _getAccentColor(), brightness: brightness);
      }
    } else {
      final seedColor = settings.followSystemAccent
          ? await _getSystemAccentColor() ?? _getAccentColor()
          : _getAccentColor();

      colorScheme = ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      );
    }

    // Apply high contrast if enabled
    if (settings.highContrast) {
      colorScheme = _applyHighContrast(colorScheme);
    }

    // Apply adaptive colors if enabled
    if (settings.adaptiveColors && brightness == Brightness.dark) {
      colorScheme = _applyAdaptiveColors(colorScheme);
    }

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      textTheme: _buildTextTheme(colorScheme),
      appBarTheme: _buildAppBarTheme(colorScheme),
      cardTheme: _buildCardTheme(colorScheme),
      elevatedButtonTheme: _buildElevatedButtonTheme(colorScheme),
      navigationBarTheme: _buildNavigationBarTheme(colorScheme),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      platform: Theme.of(WidgetsBinding.instance.rootElement!).platform,
    );
  }

  TextTheme _buildTextTheme(ColorScheme colorScheme) {
    final baseTextTheme = ThemeData(colorScheme: colorScheme).textTheme;

    return baseTextTheme.apply(
      fontSizeFactor: settings.fontScale,
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );
  }

  AppBarTheme _buildAppBarTheme(ColorScheme colorScheme) {
    return AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 4,
      titleTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 20 * settings.fontScale,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  CardThemeData _buildCardTheme(ColorScheme colorScheme) {
    return CardThemeData(
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  ElevatedButtonThemeData _buildElevatedButtonTheme(ColorScheme colorScheme) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  NavigationBarThemeData _buildNavigationBarTheme(ColorScheme colorScheme) {
    return NavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.secondaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          fontSize: 12 * settings.fontScale,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
        );
      }),
    );
  }

  ColorScheme _applyHighContrast(ColorScheme colorScheme) {
    return colorScheme.copyWith(
      primary: colorScheme.brightness == Brightness.light
          ? Colors.black
          : Colors.white,
      onPrimary: colorScheme.brightness == Brightness.light
          ? Colors.white
          : Colors.black,
      surface: colorScheme.brightness == Brightness.light
          ? Colors.white
          : Colors.black,
      onSurface: colorScheme.brightness == Brightness.light
          ? Colors.black
          : Colors.white,
    );
  }

  ColorScheme _applyAdaptiveColors(ColorScheme colorScheme) {
    // Apply adaptive colors for dark theme (softer, warmer colors)
    return colorScheme.copyWith(
      surface: Color.alphaBlend(
        colorScheme.primary.withValues(alpha: 0.05),
        colorScheme.surface,
      ),
    );
  }

  Color _getAccentColor() {
    switch (settings.accentColor) {
      case AccentColor.blue:
        return Colors.blue;
      case AccentColor.green:
        return Colors.green;
      case AccentColor.red:
        return Colors.red;
      case AccentColor.purple:
        return Colors.purple;
      case AccentColor.orange:
        return Colors.orange;
      case AccentColor.teal:
        return Colors.teal;
      case AccentColor.pink:
        return Colors.pink;
      case AccentColor.indigo:
        return Colors.indigo;
    }
  }

  Future<Color?> _getSystemAccentColor() async {
    // This would require platform-specific implementation
    // For now, return null to fallback to app accent color
    return null;
  }

  // Auto Theme Management
  void _setupAutoThemeScheduler() {
    _autoThemeTimer?.cancel();

    if (settings.mode == ThemeMode.auto) {
      _autoThemeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        _updateDarkModeState();
      });
      _updateDarkModeState();
    }
  }

  void _updateDarkModeState() {
    bool shouldBeDark;

    switch (settings.mode) {
      case ThemeMode.light:
        shouldBeDark = false;
        break;
      case ThemeMode.dark:
        shouldBeDark = true;
        break;
      case ThemeMode.system:
        shouldBeDark =
            SchedulerBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark;
        break;
      case ThemeMode.auto:
        shouldBeDark = _shouldBeAutoThemeDark();
        break;
      case ThemeMode.custom:
        shouldBeDark =
            SchedulerBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark;
        break;
    }

    if (_isDarkModeNotifier.value != shouldBeDark) {
      _isDarkModeNotifier.value = shouldBeDark;
    }
  }

  bool _shouldBeAutoThemeDark() {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final lightStartMinutes =
        settings.autoLightStart.hour * 60 + settings.autoLightStart.minute;
    final darkStartMinutes =
        settings.autoDarkStart.hour * 60 + settings.autoDarkStart.minute;

    if (lightStartMinutes < darkStartMinutes) {
      // Normal day (e.g., 6:00 - 18:00 light)
      return nowMinutes < lightStartMinutes || nowMinutes >= darkStartMinutes;
    } else {
      // Overnight light period (e.g., 18:00 - 6:00 dark)
      return nowMinutes >= darkStartMinutes && nowMinutes < lightStartMinutes;
    }
  }

  void _handleSystemThemeChange() {
    if (settings.mode == ThemeMode.system) {
      _updateDarkModeState();
    }
  }

  // Persistence
  Future<void> _loadSettings() async {
    final json = _prefs?.getString(_settingsKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _settingsNotifier.value = ThemeSettings.fromJson(data);
    }
  }

  Future<void> _saveSettings() async {
    final json = jsonEncode(settings.toJson());
    await _prefs?.setString(_settingsKey, json);
  }

  Future<void> _loadCustomThemes() async {
    final json = _prefs?.getString(_customThemesKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _customThemes.clear();
      data.forEach((key, value) {
        _customThemes[key] = CustomTheme.fromJson(value);
      });
    }
  }

  Future<void> _saveCustomThemes() async {
    final data = <String, dynamic>{};
    _customThemes.forEach((key, theme) {
      data[key] = theme.toJson();
    });
    final json = jsonEncode(data);
    await _prefs?.setString(_customThemesKey, json);
  }

  Future<void> _loadThemeHistory() async {
    final json = _prefs?.getString(_themeHistoryKey);
    if (json != null) {
      final data = jsonDecode(json) as List<dynamic>;
      _themeHistory.clear();
      _themeHistory.addAll(data.cast<String>());
    }
  }

  Future<void> _saveThemeHistory() async {
    final json = jsonEncode(_themeHistory);
    await _prefs?.setString(_themeHistoryKey, json);
  }

  void _addToThemeHistory(ThemeSettings settings) {
    final historyEntry =
        '${settings.mode}_${settings.customThemeId ?? settings.accentColor}';
    _themeHistory.remove(historyEntry);
    _themeHistory.insert(0, historyEntry);

    // Keep only last 10 entries
    if (_themeHistory.length > 10) {
      _themeHistory.removeRange(10, _themeHistory.length);
    }

    _saveThemeHistory();
  }

  // Utility Methods
  ThemeData getThemeForBrightness(Brightness brightness) {
    return brightness == Brightness.light ? lightTheme : darkTheme;
  }

  Future<void> resetToDefaults() async {
    await updateSettings(const ThemeSettings());
  }

  Future<void> exportThemeSettings() async {
    // Export current theme settings as JSON for backup/sharing
    final export = {
      'settings': settings.toJson(),
      'customThemes': _customThemes.map((k, v) => MapEntry(k, v.toJson())),
      'exportDate': DateTime.now().toIso8601String(),
    };

    // This would typically save to file or share
    LoggerFactory.debug('Theme settings exported: ${jsonEncode(export)}');
  }

  Future<void> importThemeSettings(Map<String, dynamic> importData) async {
    try {
      if (importData.containsKey('settings')) {
        final newSettings = ThemeSettings.fromJson(importData['settings']);
        await updateSettings(newSettings);
      }

      if (importData.containsKey('customThemes')) {
        final themesData = importData['customThemes'] as Map<String, dynamic>;
        themesData.forEach((key, value) {
          _customThemes[key] = CustomTheme.fromJson(value);
        });
        await _saveCustomThemes();
      }

      LoggerFactory.info('Theme settings imported successfully');
    } catch (e) {
      LoggerFactory.error('Error importing theme settings: $e');
    }
  }

  // Dispose
  void dispose() {
    _autoThemeTimer?.cancel();
    _lightThemeNotifier.dispose();
    _darkThemeNotifier.dispose();
    _settingsNotifier.dispose();
    _isDarkModeNotifier.dispose();
  }
}
