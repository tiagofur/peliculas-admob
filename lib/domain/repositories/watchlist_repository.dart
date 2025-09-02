import '../entities/movie.dart';

/// Repository interface for managing user's watchlist (movies to watch later)
/// Supports both local storage and remote sync with Supabase
abstract class WatchlistRepository {
  /// Get all movies in the user's watchlist
  Future<List<Movie>> getWatchlistMovies();

  /// Add a movie to the watchlist
  Future<void> addToWatchlist(Movie movie);

  /// Remove a movie from the watchlist
  Future<void> removeFromWatchlist(int movieId);

  /// Check if a movie is in the watchlist
  Future<bool> isInWatchlist(int movieId);

  /// Get watchlist movies with pagination
  Future<List<Movie>> getWatchlistMoviesPaginated({
    int limit = 20,
    int offset = 0,
  });

  /// Sync watchlist with remote storage (if user is authenticated)
  Future<void> syncWithRemote();

  /// Clear all local watchlist data (useful for logout)
  Future<void> clearLocalData();

  /// Check if there are pending sync operations
  Future<bool> hasPendingSync();
}