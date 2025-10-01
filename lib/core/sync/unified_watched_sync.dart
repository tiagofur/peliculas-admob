import '../../domain/entities/movie.dart';
import '../../domain/entities/syncable_watched_movie.dart';
import 'unified_sync_base.dart';

/// Implementación unificada para sincronización de Watched Movies
///
/// Proporciona sincronización offline-first para películas vistas:
/// - CRUD operations con Supabase
/// - Real-time sync
/// - Conflict resolution automática
/// - Batch operations
/// - Tracking de rewatch count
class UnifiedWatchedSync extends UnifiedSyncBase<SyncableWatchedMovie> {
  UnifiedWatchedSync._internal()
      : super(
          tableName: 'user_watched',
          entityName: 'Watched',
        );

  static final UnifiedWatchedSync _instance = UnifiedWatchedSync._internal();
  static UnifiedWatchedSync get instance => _instance;

  @override
  Map<String, dynamic> movieToSupabaseData(
    String userId,
    Movie movie, [
    Map<String, dynamic>? extraData,
  ]) {
    final now = DateTime.now().toUtc().toIso8601String();

    return {
      'user_id': userId,
      'movie_id': movie.id,
      'movie_title': movie.title,
      'movie_poster_path': movie.posterPath,
      'movie_backdrop_path': movie.backdropPath,
      'movie_overview': movie.overview,
      'movie_release_date': movie.releaseDate.toIso8601String(),
      'movie_vote_average': movie.voteAverage,
      'watched_at': extraData?['watched_at'] ?? now,
      'created_at': extraData?['created_at'] ?? now,
      // Campos adicionales opcionales
      'personal_rating': extraData?['personal_rating'],
      'personal_notes': extraData?['personal_notes'],
      'watched_location': extraData?['watched_location'],
      'rewatch_count': extraData?['rewatch_count'] ?? 1,
    };
  }

  @override
  SyncableWatchedMovie supabaseDataToEntity(Map<String, dynamic> data) {
    return SyncableWatchedMovie.fromJson(data);
  }

  @override
  String getUniqueId(String userId, int movieId) {
    return '${userId}_watched_$movieId';
  }

  /// Helper: Marca una película como vista
  Future<void> markAsWatched(String userId, Movie movie,
      {Map<String, dynamic>? extraData}) async {
    await addOrUpdateItem(userId, movie, extraData);
  }

  /// Helper: Remueve una película de vistas
  Future<void> removeWatched(String userId, int movieId) async {
    await removeItem(userId, movieId);
  }

  /// Helper: Toggle watched
  Future<void> toggleWatched(String userId, Movie movie) async {
    final exists = await itemExists(userId, movie.id);
    if (exists) {
      await removeWatched(userId, movie.id);
    } else {
      await markAsWatched(userId, movie);
    }
  }

  /// Helper: Verifica si está marcada como vista
  Future<bool> isWatched(String userId, int movieId) async {
    return await itemExists(userId, movieId);
  }

  /// Helper: Obtiene todas las películas vistas como Movies
  Future<List<Movie>> getWatchedMovies(String userId) async {
    final items = await getUserItems(userId);
    return items.map((data) {
      final watched = supabaseDataToEntity(data);
      return watched.toMovie();
    }).toList();
  }

  /// Helper: Incrementa el rewatch count
  Future<void> incrementRewatchCount(String userId, int movieId) async {
    try {
      final item = await getItem(userId, movieId);
      if (item != null) {
        final movie = item.toMovie();
        await addOrUpdateItem(userId, movie, {
          'rewatch_count': item.rewatchCount + 1,
          'watched_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    } catch (e) {
      rethrow;
    }
  }
}
