abstract class ThemeDatasource {
  Future<void> saveTheme(bool isDarkMode, int colorIndex);
  Future<(bool, int)> getTheme();
}
