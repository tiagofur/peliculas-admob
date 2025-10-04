import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/trigger_free_favorites_sync.dart';
import '../../../domain/entities/movie.dart';
import '../../../domain/entities/syncable_movie.dart';
import 'direct_sync_provider.dart';

class DirectFavoritesService extends DirectSyncService {
  DirectFavoritesService()
      : super(
          onMovieAdded: (_) {},
          sync: TriggerFreeFavoritesSync.instance,
          logPrefix: 'DirectFavorites',
          tableName: 'user_favorites',
        );

  /// Alias para toggleMovie con lógica adicional para logros
  Future<void> toggleFavorite(Movie movie) async {
    await super.toggleMovie(movie);
  }

  /// Compatibilidad: mantener método original
  @override
  Future<void> toggleMovie(Movie movie) => toggleFavorite(movie);
}

final directFavoriteMoviesProvider =
    NotifierProvider<DirectFavoritesService, Map<int, SyncableMovie>>(
  () => DirectFavoritesService(),
);

final directIsFavoriteProvider = Provider.family<bool, int>((ref, movieId) {
  return ref.watch(directFavoriteMoviesProvider).containsKey(movieId);
});

final directFavoritesCountProvider = Provider<int>((ref) {
  return ref.watch(directFavoriteMoviesProvider).length;
});
