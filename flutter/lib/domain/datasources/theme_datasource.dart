import '../../../config/theme/app_theme.dart';

abstract class ThemeDatasource {
  Future<void> saveTheme(ThemeMode themeMode, int colorIndex);
  Future<(ThemeMode, int)> getTheme();
}
