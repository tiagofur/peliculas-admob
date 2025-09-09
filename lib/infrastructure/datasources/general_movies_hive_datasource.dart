import 'package:hive/hive.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/datasources/local_storage_datasource.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/watchlist_movie.dart';

/// Datasource específico para cache general de películas (no favoritos)
class GeneralMoviesHiveDatasource extends LocalStorageDatasource {
  static const String _boxPrefix = 'movies_cache_';

  Future<Box<Movie>> _getBoxForCategory(String category) async {
    return await Hive.openBox<Movie>('$_boxPrefix$category');
  }

  @override
  Future<bool> cacheMovie(Movie movie) async {
    // For individual movies, use a general cache
    final box = await _getBoxForCategory('general');
    await box.add(movie);
    return true;
  }

  @override
  Future<void> cacheMovies(List<Movie> movies, String category) async {
    final box = await _getBoxForCategory(category);
    // Clear existing cache for this category first
    await box.clear();
    // Add new movies
    await box.addAll(movies);
    LoggerFactory.info(
        '✅ Cached ${movies.length} movies for category: $category');
  }

  @override
  Future<List<Movie>> getCachedMoviesByCategory(String category) async {
    final box = await _getBoxForCategory(category);
    final movies = box.values.toList();
    LoggerFactory.info(
        '🔍 Retrieved ${movies.length} movies from cache for category: $category');
    return movies;
  }

  @override
  Future<Movie?> getCachedMovie(int movieId) async {
    // Search in all category boxes (including page variations)
    final categories = [
      'general',
      'now_playing_1',
      'popular_1',
      'top_rated_1',
      'upcoming_1'
    ];

    for (final category in categories) {
      try {
        final box = await _getBoxForCategory(category);
        final movie =
            box.values.toList().firstWhere((movie) => movie.id == movieId);
        return movie;
      } catch (e) {
        // Continue to next category
      }
    }
    return null;
  }

  @override
  Future<void> clearAllCache() async {
    // Clear all possible cache boxes
    final categoryPatterns = [
      'general',
      'now_playing_',
      'popular_',
      'top_rated_',
      'upcoming_',
      'movie_'
    ];

    for (int page = 1; page <= 5; page++) {
      for (final pattern in categoryPatterns) {
        try {
          final category = pattern.endsWith('_') ? '$pattern$page' : pattern;
          final box = await _getBoxForCategory(category);
          await box.clear();
        } catch (e) {
          // Continue if box doesn't exist
        }
      }
    }
    LoggerFactory.info('🧹 Cleared all movie cache');
  }

  @override
  Future<void> clearExpiredCache() async {
    await clearAllCache();
  }

  @override
  Future<int> getCacheSize() async {
    final categoryPatterns = [
      'general',
      'now_playing_',
      'popular_',
      'top_rated_',
      'upcoming_',
      'movie_'
    ];
    int totalSize = 0;

    for (int page = 1; page <= 5; page++) {
      for (final pattern in categoryPatterns) {
        try {
          final category = pattern.endsWith('_') ? '$pattern$page' : pattern;
          final box = await _getBoxForCategory(category);
          totalSize += box.length;
        } catch (e) {
          // Continue if box doesn't exist
        }
      }
    }
    return totalSize;
  }

  @override
  Future<void> clearAll() async {
    await clearAllCache();
  }

  // Favoritos methods - not implemented for general cache
  @override
  Future<bool> isMovieFavorite(int movieId) {
    throw UnimplementedError('Use FavoriteMoviesHiveDatasource for favorites');
  }

  @override
  Future<List<Movie>> loadMovies({int limit = 10, offset = 0}) {
    throw UnimplementedError('Use FavoriteMoviesHiveDatasource for favorites');
  }

  @override
  Future<void> toggleFavorite(Movie movie) {
    throw UnimplementedError('Use FavoriteMoviesHiveDatasource for favorites');
  }

  // Watchlist methods - not implemented for general cache
  @override
  Future<void> addToWatchlist(Movie movie, WatchlistPriority priority) {
    throw UnimplementedError('Use WatchlistHiveDatasource for watchlist');
  }

  @override
  Future<List<WatchlistMovie>> getAllWatchlistMovies() {
    throw UnimplementedError('Use WatchlistHiveDatasource for watchlist');
  }

  @override
  Future<int> getWatchlistCount() {
    throw UnimplementedError('Use WatchlistHiveDatasource for watchlist');
  }

  @override
  Future<WatchlistMovie?> getWatchlistMovie(int movieId) {
    throw UnimplementedError('Use WatchlistHiveDatasource for watchlist');
  }

  @override
  Future<bool> isMovieInWatchlist(int movieId) {
    throw UnimplementedError('Use WatchlistHiveDatasource for watchlist');
  }

  @override
  Future<List<WatchlistMovie>> loadWatchlistMovies(
      {int limit = 10, int offset = 0, WatchlistPriority? priority}) {
    throw UnimplementedError('Use WatchlistHiveDatasource for watchlist');
  }

  @override
  Future<void> removeFromWatchlist(int movieId) {
    throw UnimplementedError('Use WatchlistHiveDatasource for watchlist');
  }

  @override
  Future<void> updateWatchlistPriority(
      int movieId, WatchlistPriority priority) {
    throw UnimplementedError('Use WatchlistHiveDatasource for watchlist');
  }
}
