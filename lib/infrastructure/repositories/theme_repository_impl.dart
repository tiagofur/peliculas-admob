import '../../domain/datasources/theme_datasource.dart';
import '../../domain/repositories/theme_repository.dart';

class ThemeRepositoryImpl implements ThemeRepository {
  ThemeRepositoryImpl(this.datasource);
  final ThemeDatasource datasource;

  @override
  Future<(bool, int)> getTheme() {
    return datasource.getTheme();
  }

  @override
  Future<void> saveTheme(bool isDarkMode, int colorIndex) {
    return datasource.saveTheme(isDarkMode, colorIndex);
  }
}
