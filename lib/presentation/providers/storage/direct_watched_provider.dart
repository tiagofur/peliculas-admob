import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/sync/trigger_free_watched_sync.dart';
import '../../../domain/entities/movie.dart';
import '../../../domain/entities/syncable_movie.dart';
import '../achievements/achievements_provider.dart';
import 'direct_sync_provider.dart';

final directWatchedMoviesProvider =
    StateNotifierProvider<DirectWatchedNotifier, Map<int, SyncableMovie>>(
        (ref) {
  return DirectWatchedNotifier(
    ref: ref,
  );
});

class DirectWatchedNotifier extends DirectSyncNotifier {
  DirectWatchedNotifier({required Ref ref})
      : super(
          onMovieAdded: (Movie movie) {
            ref.read(achievementsProvider.notifier).trackMovieWatched(movie);
          },
          sync: TriggerFreeWatchedSync.instance,
          logPrefix: 'DirectWatched',
          tableName: 'user_watched_movies',
        );

  @override
  Future<void> toggleMovie(Movie movie) async {
    await super.toggleMovie(movie);
  }

  /// Alias para toggleMovie para mantener compatibilidad
  Future<void> toggleWatched(Movie movie) async {
    await toggleMovie(movie);
  }
}

final directIsWatchedProvider = Provider.family<bool, int>((ref, movieId) {
  return ref.watch(directWatchedMoviesProvider).containsKey(movieId);
});

final directWatchedCountProvider = Provider<int>((ref) {
  return ref.watch(directWatchedMoviesProvider).length;
});
