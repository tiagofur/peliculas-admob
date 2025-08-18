import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/datasources/local_storage_datasource.dart';
import '../../infrastructure/datasources/custom_lists_shared_preferences_datasource.dart';
import '../../infrastructure/datasources/favorite_movies_shared_preferences_datasource.dart';
import '../../infrastructure/datasources/isar_datasource.dart';
import '../../infrastructure/datasources/watched_movies_hive_datasource.dart';
import '../../infrastructure/repositories/hybrid_custom_lists_repository.dart';
import '../../infrastructure/repositories/hybrid_favorites_repository.dart';
import '../../infrastructure/repositories/hybrid_watched_repository.dart';

// Provider para el repositorio híbrido de favoritos
final hybridFavoritesRepositoryProvider =
    Provider<HybridFavoritesRepository>((ref) {
  // Usar el MISMO datasource que favoriteMoviesProvider para consistencia
  LocalStorageDatasource datasource;

  if (kIsWeb) {
    datasource = FavoriteMoviesSharedPreferencesDatasource();
  } else {
    datasource = HiveDatasource();
  }

  return HybridFavoritesRepository(
    datasource: datasource,
    ref: ref,
  );
});

// Provider para el repositorio híbrido de películas vistas
final hybridWatchedRepositoryProvider =
    Provider<HybridWatchedRepository>((ref) {
  final watchedHiveDatasource = ref.watch(watchedMoviesHiveDatasourceProvider);

  return HybridWatchedRepository(
    hiveDatasource: watchedHiveDatasource,
    ref: ref,
  );
});

// Provider para el datasource de Hive de favoritos
final hiveDatasourceProvider = Provider<HiveDatasource>((ref) {
  return HiveDatasource();
});

// Provider para el datasource de Hive de películas vistas
final watchedMoviesHiveDatasourceProvider =
    Provider<WatchedMoviesHiveDatasource>((ref) {
  return WatchedMoviesHiveDatasource();
});

// Provider para el repositorio híbrido de listas personalizadas
final hybridCustomListsRepositoryProvider =
    Provider<HybridCustomListsRepository>((ref) {
  final localDatasource = ref.watch(customListsLocalDatasourceProvider);

  return HybridCustomListsRepository(
    localDatasource: localDatasource,
    ref: ref,
  );
});

// Provider para el datasource local de listas personalizadas
final customListsLocalDatasourceProvider =
    Provider<CustomListsSharedPreferencesDatasource>((ref) {
  return CustomListsSharedPreferencesDatasource();
});
