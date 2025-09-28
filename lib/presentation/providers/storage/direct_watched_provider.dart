import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../core/sync/trigger_free_watched_sync.dart';
import '../../../domain/entities/movie.dart';
import '../../../domain/entities/syncable_movie.dart';
import '../achievements/achievements_provider.dart';
import '../watched_movies_provider.dart';
import 'direct_sync_provider.dart';

class DirectWatchedService extends DirectSyncService {
  DirectWatchedService()
      : super(
          onMovieAdded: (Movie movie) {
            // Note: We can't access ref here, so we'll handle this in the provider
          },
          sync: TriggerFreeWatchedSync.instance,
          logPrefix: 'DirectWatched',
          tableName: 'user_watched_movies',
        );

  @override
  Map<int, SyncableMovie> build() {
    // Call parent build first
    final result = super.build();

    // Setup callback to track achievements
    // This will be handled in the provider instantiation

    return result;
  }

  /// Alias para toggleMovie para mantener compatibilidad
  Future<void> toggleWatched(Movie movie) async {
    final wasWatched = state.containsKey(movie.id);

    await super.toggleMovie(movie);

    if (!ref.mounted) {
      return;
    }

    try {
      if (!wasWatched && state.containsKey(movie.id)) {
        await ref
            .read(achievementsProvider.notifier)
            .trackMovieWatched(movie);
      }

      await ref.read(watchedMoviesProvider.notifier).refresh();
    } catch (error, stackTrace) {
      LoggerFactory.error(
        'DirectWatched: Failed to refresh watched movies after toggle: $error',
        stackTrace: stackTrace,
      );
    }
  }
}

final directWatchedMoviesProvider =
    NotifierProvider<DirectWatchedService, Map<int, SyncableMovie>>(
  () => DirectWatchedService(),
);

final directIsWatchedProvider = Provider.family<bool, int>((ref, movieId) {
  return ref.watch(directWatchedMoviesProvider).containsKey(movieId);
});

final directWatchedCountProvider = Provider<int>((ref) {
  return ref.watch(directWatchedMoviesProvider).length;
});
