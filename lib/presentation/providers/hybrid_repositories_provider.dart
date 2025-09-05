import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/custom_lists_repository.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../../domain/repositories/watched_movies_repository.dart';
import '../../domain/repositories/watchlist_repository.dart';
import '../../infrastructure/datasources/custom_lists_shared_preferences_datasource.dart';
import '../../infrastructure/datasources/isar_datasource.dart';
import '../../infrastructure/datasources/watched_movies_hive_datasource.dart';
import '../../infrastructure/repositories/custom_lists_repository_impl.dart';
import '../../infrastructure/repositories/hybrid_custom_lists_repository.dart';
import '../../infrastructure/repositories/hybrid_favorites_repository.dart';
import '../../infrastructure/repositories/hybrid_watched_repository.dart';
import '../../infrastructure/repositories/hybrid_watchlist_repository.dart';
import '../../infrastructure/repositories/watched_movies_repository_impl.dart';
import 'auth_provider.dart';

// Provider para obtener el userId del usuario actual
final currentUserIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.id;
});

// Provider for the unified favorites repository interface
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider) ?? 'anonymous_user';

  return HybridFavoritesRepository(
    userId: userId,
  );
});

// Provider for the unified watched movies repository interface
final watchedMoviesRepositoryProvider =
    Provider<WatchedMoviesRepository>((ref) {
  final watchedHiveDatasource = ref.watch(watchedMoviesHiveDatasourceProvider);

  return WatchedMoviesRepositoryImpl(
    watchedHiveDatasource,
    ref,
  );
});

// Provider para el datasource de Hive
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

  return CustomListsRepositoryImpl(
    localDatasource,
    ref,
  );
});

// Provider for the unified watchlist repository interface
final watchlistRepositoryProvider = Provider<WatchlistRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider) ?? 'anonymous_user';

  return HybridWatchlistRepository(
    userId: userId,
  ) as WatchlistRepository;
});

// Provider específico para HybridWatchlistRepository
final hybridWatchlistRepositoryProvider =
    Provider<HybridWatchlistRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider) ?? 'anonymous_user';

  return HybridWatchlistRepository(
    userId: userId,
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
  final userId = ref.watch(currentUserIdProvider) ?? 'anonymous_user';

  return HybridFavoritesRepository(
    userId: userId,
  );
});

final hybridWatchedRepositoryProvider =
    Provider<HybridWatchedRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider) ?? 'anonymous_user';

  return HybridWatchedRepository(
    userId: userId,
  );
});

final hybridCustomListsRepositoryProvider =
    Provider<HybridCustomListsRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider) ?? 'anonymous_user';

  return HybridCustomListsRepository(
    userId: userId,
  );
});
// hybridWatchlistRepositoryProvider is now defined above with correct type
