import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/datasources/theme_datasource.dart';

class ThemeSharedPreferencesDatasource implements ThemeDatasource {
  Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  @override
  Future<(bool, int)> getTheme() async {
    final prefs = await _getPrefs();
    final isDarkMode = prefs.getBool('isDarkMode') ?? false;
    final selectedColor = prefs.getInt('selectedColor') ?? 0;
    return (isDarkMode, selectedColor);
  }

  @override
  Future<void> saveTheme(bool isDarkMode, int colorIndex) async {
    final prefs = await _getPrefs();
    await prefs.setBool('isDarkMode', isDarkMode);
    await prefs.setInt('selectedColor', colorIndex);
  }
}
