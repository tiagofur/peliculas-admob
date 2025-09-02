import '../entities/movie.dart';

/// Repository interface for managing user's favorite movies
/// Supports both local storage and remote sync with Supabase
abstract class FavoritesRepository {
  /// Get all favorite movies for the current user
  Future<Map<int, Movie>> getFavoriteMovies();

  /// Toggle a movie as favorite/unfavorite
  Future<void> toggleFavorite(Movie movie);

  /// Check if a movie is marked as favorite
  Future<bool> isMovieFavorite(int movieId);

  /// Sync favorites with remote storage (if user is authenticated)
  Future<void> syncWithRemote();

  /// Clear all local favorites data (useful for logout)
  Future<void> clearLocalData();

  /// Check if there are pending sync operations
  Future<bool> hasPendingSync();
}