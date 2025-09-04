import '../../core/exceptions/sync_exceptions.dart';
import '../../core/logging/logger_factory.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/sync_models.dart';
import '../../domain/entities/sync_operation.dart';
import '../../domain/entities/syncable_entity.dart';
import '../../domain/entities/watched_movie.dart';
import '../../domain/repositories/watched_movies_repository.dart';
import '../datasources/watched_movies_hive_datasource.dart';
import 'base_hybrid_repository.dart';

/// Hybrid repository for watched movies that supports local storage and Supabase sync
class HybridWatchedRepository extends BaseHybridRepository<SyncableWatchedMovie>
    implements WatchedMoviesRepository {
  HybridWatchedRepository({
    required WatchedMoviesHiveDatasource hiveDatasource,
    required super.ref,
  }) : _hiveDatasource = hiveDatasource;

  final WatchedMoviesHiveDatasource _hiveDatasource;

  // Implements BaseHybridRepository abstract methods
  @override
  String get tableName => 'user_watched_movies';

  @override
  SyncableWatchedMovie mapFromSupabase(Map<String, dynamic> data) {
    return SyncableWatchedMovie(
      id: data['id'] ?? '${data['user_id']}_${data['movie_id']}_watched',
      userId: data['user_id'],
      movieId: data['movie_id'],
      movieTitle: data['movie_title'],
      moviePosterPath: data['movie_poster_path'],
      movieBackdropPath: data['movie_backdrop_path'],
      movieOverview: data['movie_overview'],
      movieReleaseDate: data['movie_release_date'] != null
          ? DateTime.parse(data['movie_release_date'])
          : null,
      movieVoteAverage: data['movie_vote_average']?.toDouble(),
      watchedAt: DateTime.parse(data['watched_at']),
      createdAt: DateTime.parse(data['created_at']),
      updatedAt: DateTime.parse(data['last_modified_at']),
      deletedAt: data['deleted_at'] != null ? DateTime.parse(data['deleted_at']) : null,
      syncStatus: SyncItemStatus.synced,
      syncVersion: data['sync_version'] ?? 1,
      deviceId: data['device_id'],
      rating: data['rating']?.toDouble(),
      review: data['review'],
      traktId: data['trakt_id'],
    );
  }

  @override
  Map<String, dynamic> mapToSupabase(SyncableWatchedMovie watchedMovie) {
    return {
      'user_id': watchedMovie.userId,
      'movie_id': watchedMovie.movieId,
      'movie_title': watchedMovie.movieTitle,
      'movie_poster_path': watchedMovie.moviePosterPath,
      'movie_backdrop_path': watchedMovie.movieBackdropPath,
      'movie_overview': watchedMovie.movieOverview,
      'movie_release_date':
          watchedMovie.movieReleaseDate?.toIso8601String().split('T')[0],
      'movie_vote_average': watchedMovie.movieVoteAverage,
      'watched_at': watchedMovie.watchedAt.toIso8601String(),
      'rating': watchedMovie.rating,
      'review': watchedMovie.review,
      'trakt_id': watchedMovie.traktId,
      'is_deleted': false,
      'last_modified_at': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<void> clearRepositoryData() async {
    await _hiveDatasource.clearAll();
  }

  // Implements WatchedMoviesRepository interface
  @override
  Future<void> markAsWatched(Movie movie) async {
    LoggerFactory.info('🎬 MARK AS WATCHED called for: ${movie.title}');

    try {
      // 1. Update locally first (Local First)
      await _hiveDatasource.markAsWatched(movie);
      LoggerFactory.info('✅ Movie marked as watched locally: ${movie.title}');
    } catch (e) {
      LoggerFactory.error('❌ Error marking as watched locally: $e');
      throw LocalStorageException('Error marking movie as watched: $e');
    }

    // 2. Add to sync queue
    final userId = getCurrentUserId();
    if (userId != null) {
      final operation =
          SyncOperationFactory.markWatched(userId: userId, movieId: movie.id);
      await syncQueue.addItem(operation.id);
    }

    // 3. Sync if online and authenticated
    if (isAuthenticated()) {
      try {
        await checkOnline();
        await _syncSingleWatchedItem(movie);
      } on SyncException catch (e) {
        LoggerFactory.error('❌ Error syncing watched movie: $e');
      }
    }
  }

  @override
  Future<void> removeFromWatched(int movieId) async {
    LoggerFactory.info('🗑️ REMOVE FROM WATCHED called for movie ID: $movieId');

    try {
      await _hiveDatasource.removeFromWatched(movieId);
      LoggerFactory.info('✅ Movie removed from watched locally');
    } catch (e) {
      LoggerFactory.error('❌ Error removing from watched locally: $e');
      throw LocalStorageException('Error removing movie from watched: $e');
    }

    // Sync if authenticated
    final userId = getCurrentUserId();
    if (userId != null && isAuthenticated()) {
      final operation =
          SyncOperationFactory.unmarkWatched(userId: userId, movieId: movieId);
      await syncQueue.addItem(operation.id);

      try {
        await checkOnline();
        await _syncSingleWatchedRemoval(movieId);
      } on SyncException catch (e) {
        LoggerFactory.error('❌ Error syncing removal: $e');
      }
    }
  }

  @override
  Future<bool> isMovieWatched(int movieId) async {
    try {
      return await _hiveDatasource.isMovieWatched(movieId);
    } catch (e) {
      throw LocalStorageException('Error checking if movie is watched: $e');
    }
  }

  @override
  Future<List<WatchedMovie>> loadWatchedMovies(
      {int limit = 10, int offset = 0}) async {
    if (isAuthenticated()) {
      try {
        await checkOnline();
        await syncWithSupabase();
      } on SyncException catch (e) {
        LoggerFactory.error('Error in automatic sync: $e');
      }
    }

    try {
      return await _hiveDatasource.loadWatchedMovies();
    } catch (e) {
      throw LocalStorageException('Error loading watched movies: $e');
    }
  }

  // Helper sync methods
  Future<void> _syncSingleWatchedItem(Movie movie) async {
    final userId = getCurrentUserId();
    if (userId == null) return;

    try {
      await supabase.from('user_watched_movies').upsert({
        'user_id': userId,
        'movie_id': movie.id,
        'movie_title': movie.title,
        'movie_poster_path': movie.posterPath,
        'movie_backdrop_path': movie.backdropPath,
        'movie_overview': movie.overview,
        'movie_release_date': movie.releaseDate.toIso8601String().split('T')[0],
        'movie_vote_average': movie.voteAverage,
        'watched_at': DateTime.now().toIso8601String(),
        'last_modified_at': DateTime.now().toIso8601String(),
        'deleted_at': null,
      }, onConflict: 'user_id,movie_id');

      LoggerFactory.info(
          '✅ ${movie.title} added to watched movies in Supabase');
    } catch (e) {
      throw SupabaseSyncException(
          'Error syncing watched movie ${movie.title}: $e');
    }
  }

  Future<void> _syncSingleWatchedRemoval(int movieId) async {
    final userId = getCurrentUserId();
    if (userId == null) return;

    try {
      await supabase
          .from('user_watched_movies')
          .update({
            'deleted_at': DateTime.now().toIso8601String(),
            'last_modified_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('movie_id', movieId);

      LoggerFactory.info('✅ Movie ID $movieId marked as deleted in Supabase');
    } catch (e) {
      throw SupabaseSyncException('Error removing watched movie $movieId: $e');
    }
  }

  // Implements SyncableRepository methods
  @override
  Future<List<SyncableWatchedMovie>> getLocalData() async {
    try {
      final watchedMovies = await _hiveDatasource.loadWatchedMovies();
      final userId = getCurrentUserId();
      if (userId == null) return [];

      return watchedMovies
          .map((watchedMovie) =>
              SyncableWatchedMovie.fromWatchedMovie(watchedMovie, userId))
          .toList();
    } catch (e) {
      throw LocalStorageException(
          'Error getting local watched movies data: $e');
    }
  }

  @override
  Future<List<SyncableWatchedMovie>> getRemoteData() async {
    final userId = getCurrentUserId();
    if (userId == null) return [];

    try {
      await checkOnline();
      final response = await supabase
          .from('user_watched_movies')
          .select()
          .eq('user_id', userId)
          .isFilter('deleted_at', null)
          .order('watched_at', ascending: false);

      return (response as List).map((data) => mapFromSupabase(data)).toList();
    } catch (e) {
      throw SupabaseSyncException(
          'Error getting remote watched movies data: $e');
    }
  }

  @override
  Future<void> upload(List<SyncableWatchedMovie> watchedMovies) async {
    if (watchedMovies.isEmpty) return;

    for (final watchedMovie in watchedMovies) {
      try {
        await supabase.from('user_watched_movies').upsert(
            mapToSupabase(watchedMovie),
            onConflict: 'user_id,movie_id');
      } catch (e) {
        throw SupabaseSyncException(
            'Error uploading watched movie ${watchedMovie.movieTitle}: $e');
      }
    }
  }

  @override
  Future<void> download(List<SyncableWatchedMovie> watchedMovies) async {
    for (final watchedMovie in watchedMovies) {
      try {
        final movie = watchedMovie.toMovie();
        await _hiveDatasource.markAsWatched(movie);
      } catch (e) {
        throw LocalStorageException(
            'Error downloading watched movie ${watchedMovie.id}: $e');
      }
    }
  }

  @override
  Future<void> resolveConflicts(List<SyncableWatchedMovie> local,
      List<SyncableWatchedMovie> remote) async {
    // Simple conflict resolution: remote wins
    for (final remoteItem in remote) {
      final localItem =
          local.where((item) => item.id == remoteItem.id).firstOrNull;
      if (localItem != null) {
        final movie = remoteItem.toMovie();
        await _hiveDatasource.markAsWatched(movie);
      }
    }
  }
}

// Extension to convert SyncableWatchedMovie to Movie
extension SyncableWatchedMovieExtension on SyncableWatchedMovie {
  Movie toMovie() {
    return Movie(
      id: movieId,
      title: movieTitle,
      posterPath: moviePosterPath ?? '',
      backdropPath: movieBackdropPath ?? '',
      overview: movieOverview ?? '',
      releaseDate: movieReleaseDate ?? DateTime.now(),
      voteAverage: movieVoteAverage ?? 0.0,
      genreIds: [],
      adult: false,
      originalLanguage: 'en',
      originalTitle: movieTitle,
      popularity: 0.0,
      video: false,
      voteCount: 0,
    );
  }
}
