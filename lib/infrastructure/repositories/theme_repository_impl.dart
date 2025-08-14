import '../../domain/datasources/theme_datasource.dart';
import '../../domain/repositories/theme_repository.dart';

class ThemeRepositoryImpl implements ThemeRepository {
  final ThemeDatasource datasource;

  ThemeRepositoryImpl(this.datasource);

  @override
  Future<(bool, int)> getTheme() {
    return datasource.getTheme();
  }

  @override
  Future<void> saveTheme(bool isDarkMode, int colorIndex) {
    return datasource.saveTheme(isDarkMode, colorIndex);
  }
}
