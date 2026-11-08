import '../../../config/theme/app_theme.dart';

abstract class ThemeRepository {
  Future<void> saveTheme(ThemeMode themeMode, int colorIndex);
  Future<(ThemeMode, int)> getTheme();
}
