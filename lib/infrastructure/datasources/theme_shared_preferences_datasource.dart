import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme/app_theme.dart';
import '../../domain/datasources/theme_datasource.dart';

class ThemeSharedPreferencesDatasource implements ThemeDatasource {
  Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  @override
  Future<(ThemeMode, int)> getTheme() async {
    final prefs = await _getPrefs();

    // Migrar de la configuración anterior si existe
    if (prefs.containsKey('isDarkMode') && !prefs.containsKey('themeMode')) {
      final oldIsDarkMode = prefs.getBool('isDarkMode') ?? false;
      final selectedColor = prefs.getInt('selectedColor') ?? 0;

      // Migrar a nuevo formato
      final newThemeMode = oldIsDarkMode ? ThemeMode.dark : ThemeMode.light;
      await saveTheme(newThemeMode, selectedColor);

      // Limpiar configuración antigua
      await prefs.remove('isDarkMode');

      return (newThemeMode, selectedColor);
    }

    final themeModeString = prefs.getString('themeMode') ?? 'system';
    final selectedColor = prefs.getInt('selectedColor') ?? 0;

    // Convertir string a ThemeMode
    ThemeMode themeMode;
    switch (themeModeString) {
      case 'light':
        themeMode = ThemeMode.light;
        break;
      case 'dark':
        themeMode = ThemeMode.dark;
        break;
      case 'system':
      default:
        themeMode = ThemeMode.system;
        break;
    }

    return (themeMode, selectedColor);
  }

  @override
  Future<void> saveTheme(ThemeMode themeMode, int colorIndex) async {
    final prefs = await _getPrefs();

    // Convertir ThemeMode a string
    String themeModeString;
    switch (themeMode) {
      case ThemeMode.light:
        themeModeString = 'light';
        break;
      case ThemeMode.dark:
        themeModeString = 'dark';
        break;
      case ThemeMode.system:
        themeModeString = 'system';
        break;
    }

    await prefs.setString('themeMode', themeModeString);
    await prefs.setInt('selectedColor', colorIndex);
  }
}
