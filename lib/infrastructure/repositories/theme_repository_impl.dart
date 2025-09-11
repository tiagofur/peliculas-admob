import '../../config/theme/app_theme.dart';
import '../../domain/datasources/theme_datasource.dart';
import '../../domain/repositories/theme_repository.dart';

class ThemeRepositoryImpl implements ThemeRepository {
  const ThemeRepositoryImpl(this.datasource);
  final ThemeDatasource datasource;

  @override
  Future<(ThemeMode, int)> getTheme() {
    return datasource.getTheme();
  }

  @override
  Future<void> saveTheme(ThemeMode themeMode, int colorIndex) {
    return datasource.saveTheme(themeMode, colorIndex);
  }
}
