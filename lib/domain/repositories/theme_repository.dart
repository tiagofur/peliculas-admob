abstract class ThemeRepository {
  Future<void> saveTheme(bool isDarkMode, int colorIndex);
  Future<(bool, int)> getTheme();
}
