import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peliculas/domain/datasources/theme_datasource.dart';
import 'package:peliculas/domain/repositories/theme_repository.dart';
import 'package:peliculas/infrastructure/datasources/theme_shared_preferences_datasource.dart';
import 'package:peliculas/infrastructure/repositories/theme_repository_impl.dart';

final themeDatasourceProvider = Provider<ThemeDatasource>((ref) {
  return ThemeSharedPreferencesDatasource();
});

final themeRepositoryProvider = Provider<ThemeRepository>((ref) {
  final datasource = ref.watch(themeDatasourceProvider);
  return ThemeRepositoryImpl(datasource);
});
