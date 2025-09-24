import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/sync/trigger_free_favorites_sync.dart';
import '../../../domain/entities/movie.dart';
import '../../../domain/entities/syncable_movie.dart';
import '../achievements/achievements_provider.dart';
import 'direct_sync_provider.dart';

final directFavoriteMoviesProvider =
    StateNotifierProvider<DirectFavoritesNotifier, Map<int, SyncableMovie>>(
        (ref) {
  return DirectFavoritesNotifier(
    ref: ref,
  );
});

class DirectFavoritesNotifier extends DirectSyncNotifier {
  DirectFavoritesNotifier({required Ref ref})
      : super(
          onMovieAdded: (Movie movie) {
            ref.read(achievementsProvider.notifier).trackMovieFavorited();
          },
          sync: TriggerFreeFavoritesSync.instance,
          logPrefix: 'DirectFavorites',
          tableName: 'user_favorites',
        );

  @override
  Future<void> toggleMovie(Movie movie) async {
    await super.toggleMovie(movie);
  }

  /// Alias para toggleMovie para mantener compatibilidad
  Future<void> toggleFavorite(Movie movie) async {
    await toggleMovie(movie);
  }
}

final directIsFavoriteProvider = Provider.family<bool, int>((ref, movieId) {
  return ref.watch(directFavoriteMoviesProvider).containsKey(movieId);
});

final directFavoritesCountProvider = Provider<int>((ref) {
  return ref.watch(directFavoriteMoviesProvider).length;
});
