import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/datasources/local_storage_datasource.dart';
import '../../domain/repositories/custom_lists_repository.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../../domain/repositories/watched_movies_repository.dart';
import '../../domain/repositories/watchlist_repository.dart';
import '../../infrastructure/datasources/custom_lists_shared_preferences_datasource.dart';
import '../../infrastructure/datasources/favorite_movies_shared_preferences_datasource.dart';
import '../../infrastructure/datasources/isar_datasource.dart';
import '../../infrastructure/datasources/watched_movies_hive_datasource.dart';
import '../../infrastructure/repositories/hybrid_custom_lists_repository.dart';
import '../../infrastructure/repositories/hybrid_favorites_repository.dart';
import '../../infrastructure/repositories/hybrid_watched_repository.dart';
import '../../infrastructure/repositories/hybrid_watchlist_repository.dart';

// Provider for the unified favorites repository interface
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  // Use the SAME datasource as favoriteMoviesProvider for consistency
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

// Provider for the unified watched movies repository interface
final watchedMoviesRepositoryProvider =
    Provider<WatchedMoviesRepository>((ref) {
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

// Provider for the unified custom lists repository interface
final customListsRepositoryProvider = Provider<CustomListsRepository>((ref) {
  final localDatasource = ref.watch(customListsLocalDatasourceProvider);

  return HybridCustomListsRepository(
    localDatasource: localDatasource,
    ref: ref,
  ) as CustomListsRepository;
});

// Provider for the unified watchlist repository interface
final watchlistRepositoryProvider = Provider<WatchlistRepository>((ref) {
  // Use the same datasource as favorites for consistency
  LocalStorageDatasource datasource;

  if (kIsWeb) {
    datasource = FavoriteMoviesSharedPreferencesDatasource();
  } else {
    datasource = HiveDatasource();
  }

  return HybridWatchlistRepository(
    datasource: datasource,
    ref: ref,
  ) as WatchlistRepository;
});

// Provider específico para HybridWatchlistRepository
final hybridWatchlistRepositoryProvider =
    Provider<HybridWatchlistRepository>((ref) {
  // Use the same datasource as favorites for consistency
  LocalStorageDatasource datasource;

  if (kIsWeb) {
    datasource = FavoriteMoviesSharedPreferencesDatasource();
  } else {
    datasource = HiveDatasource();
  }

  return HybridWatchlistRepository(
    datasource: datasource,
    ref: ref,
  );
});

// Additional datasource providers

final customListsLocalDatasourceProvider =
    Provider<CustomListsSharedPreferencesDatasource>((ref) {
  return CustomListsSharedPreferencesDatasource();
});

// Providers específicos para tipos concretos híbridos (requeridos por SyncService)
// Estos providers devuelven los tipos concretos necesarios para SyncableRepository

final hybridFavoritesRepositoryProvider =
    Provider<HybridFavoritesRepository>((ref) {
  // Use the SAME datasource as favoriteMoviesProvider for consistency
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

final hybridWatchedRepositoryProvider =
    Provider<HybridWatchedRepository>((ref) {
  final watchedHiveDatasource = ref.watch(watchedMoviesHiveDatasourceProvider);

  return HybridWatchedRepository(
    hiveDatasource: watchedHiveDatasource,
    ref: ref,
  );
});

final hybridCustomListsRepositoryProvider =
    Provider<HybridCustomListsRepository>((ref) {
  final localDatasource = ref.watch(customListsLocalDatasourceProvider);

  return HybridCustomListsRepository(
    localDatasource: localDatasource,
    ref: ref,
  );
});
// hybridWatchlistRepositoryProvider is now defined above with correct type
