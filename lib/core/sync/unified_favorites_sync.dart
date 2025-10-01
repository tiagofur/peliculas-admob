import '../../domain/entities/movie.dart';
import '../../domain/entities/syncable_favorite.dart';
import 'unified_sync_base.dart';

/// Implementación unificada para sincronización de Favorites
///
/// Proporciona sincronización offline-first para películas favoritas:
/// - CRUD operations con Supabase
/// - Real-time sync
/// - Conflict resolution automática
/// - Batch operations
class UnifiedFavoritesSync extends UnifiedSyncBase<SyncableFavorite> {
  UnifiedFavoritesSync._internal()
      : super(
          tableName: 'user_favorites',
          entityName: 'Favorites',
        );

  static final UnifiedFavoritesSync _instance =
      UnifiedFavoritesSync._internal();
  static UnifiedFavoritesSync get instance => _instance;

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
      'added_at': extraData?['added_at'] ?? now,
      'created_at': extraData?['created_at'] ?? now,
      // Campos adicionales opcionales
      'personal_rating': extraData?['personal_rating'],
      'personal_notes': extraData?['personal_notes'],
      'tags': extraData?['tags'] ?? [],
    };
  }

  @override
  SyncableFavorite supabaseDataToEntity(Map<String, dynamic> data) {
    return SyncableFavorite.fromJson(data);
  }

  @override
  String getUniqueId(String userId, int movieId) {
    return '${userId}_favorite_$movieId';
  }

  /// Helper: Agrega un favorito desde Movie directamente
  Future<void> addFavorite(String userId, Movie movie) async {
    await addOrUpdateItem(userId, movie);
  }

  /// Helper: Remueve un favorito
  Future<void> removeFavorite(String userId, int movieId) async {
    await removeItem(userId, movieId);
  }

  /// Helper: Toggle favorito
  Future<void> toggleFavorite(String userId, Movie movie) async {
    final exists = await itemExists(userId, movie.id);
    if (exists) {
      await removeFavorite(userId, movie.id);
    } else {
      await addFavorite(userId, movie);
    }
  }

  /// Helper: Verifica si es favorito
  Future<bool> isFavorite(String userId, int movieId) async {
    return await itemExists(userId, movieId);
  }

  /// Helper: Obtiene todos los favoritos como Movies
  Future<List<Movie>> getFavoriteMovies(String userId) async {
    final items = await getUserItems(userId);
    return items.map((data) {
      final favorite = supabaseDataToEntity(data);
      return favorite.toMovie();
    }).toList();
  }
}
