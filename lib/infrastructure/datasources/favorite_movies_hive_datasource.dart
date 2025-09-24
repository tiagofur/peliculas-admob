import 'package:hive/hive.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/datasources/local_storage_datasource.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/watchlist_movie.dart';

class FavoriteMoviesHiveDatasource extends LocalStorageDatasource {
  static const String _boxName = 'favorite_movies';

  Future<Box<Movie>> _getBox() async {
    return await Hive.openBox<Movie>(_boxName);
  }

  @override
  Future<bool> isMovieFavorite(int movieId) async {
    final box = await _getBox();
    // ✅ Validación de tipos para evitar corrupción
    return box.values
        .whereType<Movie>()
        .cast<Movie>()
        .any((movie) => movie.id == movieId);
  }

  @override
  Future<List<Movie>> loadMovies({int limit = 10, offset = 0}) async {
    final box = await _getBox();

    final allMovies = box.values.cast<Movie>().toList();

    final endIndex = (offset + limit).clamp(0, allMovies.length);
    if (offset >= allMovies.length) return [];

    final result = allMovies.sublist(offset, endIndex);
    LoggerFactory.info(
        '🔍 Returning ${result.length} movies (offset: $offset, limit: $limit)');
    return result;
  }

  @override
  Future<void> toggleFavorite(Movie movie) async {
    final box = await _getBox();

    await box.put(movie.id, movie);
  }

  // NOTA: Esta clase se enfoca en favoritos. Los métodos de watchlist
  // deberían ser manejados por WatchlistHiveDatasource, pero implementamos
  // funcionalidad básica para evitar crashes

  @override
  Future<void> addToWatchlist(Movie movie, WatchlistPriority priority) async {
    LoggerFactory.warning(
        '⚠️ addToWatchlist llamado en FavoriteMoviesHiveDatasource - usar WatchlistHiveDatasource');
    // Implementación básica para evitar crashes
    return;
  }

  @override
  Future<List<WatchlistMovie>> getAllWatchlistMovies() async {
    LoggerFactory.warning(
        '⚠️ getAllWatchlistMovies llamado en FavoriteMoviesHiveDatasource - usar WatchlistHiveDatasource');
    return [];
  }

  @override
  Future<int> getWatchlistCount() async {
    LoggerFactory.warning(
        '⚠️ getWatchlistCount llamado en FavoriteMoviesHiveDatasource - usar WatchlistHiveDatasource');
    return 0;
  }

  @override
  Future<WatchlistMovie?> getWatchlistMovie(int movieId) async {
    LoggerFactory.warning(
        '⚠️ getWatchlistMovie llamado en FavoriteMoviesHiveDatasource - usar WatchlistHiveDatasource');
    return null;
  }

  @override
  Future<bool> isMovieInWatchlist(int movieId) async {
    LoggerFactory.warning(
        '⚠️ isMovieInWatchlist llamado en FavoriteMoviesHiveDatasource - usar WatchlistHiveDatasource');
    return false;
  }

  @override
  Future<List<WatchlistMovie>> loadWatchlistMovies(
      {int limit = 10, int offset = 0, WatchlistPriority? priority}) async {
    LoggerFactory.warning(
        '⚠️ loadWatchlistMovies llamado en FavoriteMoviesHiveDatasource - usar WatchlistHiveDatasource');
    return [];
  }

  @override
  Future<void> removeFromWatchlist(int movieId) async {
    LoggerFactory.warning(
        '⚠️ removeFromWatchlist llamado en FavoriteMoviesHiveDatasource - usar WatchlistHiveDatasource');
    return;
  }

  @override
  Future<void> updateWatchlistPriority(
      int movieId, WatchlistPriority priority) async {
    LoggerFactory.warning(
        '⚠️ updateWatchlistPriority llamado en FavoriteMoviesHiveDatasource - usar WatchlistHiveDatasource');
    return;
  }

  @override
  Future<bool> cacheMovie(Movie movie) async {
    throw UnimplementedError(
        'FavoriteMoviesHiveDatasource should not cache individual movies - only favorites');
  }

  @override
  Future<void> cacheMovies(List<Movie> movies, String category) async {
    throw UnimplementedError(
        'FavoriteMoviesHiveDatasource should not cache all movies - only favorites');
  }

  @override
  Future<void> clearAllCache() async {
    final box = await _getBox();
    await box.clear();
  }

  @override
  Future<void> clearExpiredCache() async {
    final box = await _getBox();
    await box.clear();
  }

  @override
  Future<int> getCacheSize() async {
    final box = await _getBox();
    return box.length;
  }

  @override
  Future<Movie?> getCachedMovie(int movieId) async {
    final box = await _getBox();
    try {
      return box.values.toList().firstWhere((movie) => movie.id == movieId);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<Movie>> getCachedMoviesByCategory(String category) async {
    final box = await _getBox();
    return box.values.toList();
  }

  Future<void> removeFavoriteById(int movieId) async {
    final box = await _getBox();
    final existingMovieIndex =
        box.values.toList().indexWhere((m) => m.id == movieId);

    if (existingMovieIndex != -1) {
      await box.deleteAt(existingMovieIndex);
      LoggerFactory.info('✅ Removed movie $movieId from favorites via ID');
    }
  }

  Future<void> saveFavorite(Movie movie) async {
    final box = await _getBox();
    final isAlreadyFavorite = box.values.toList().any((m) => m.id == movie.id);

    if (!isAlreadyFavorite) {
      await box.add(movie);
      LoggerFactory.info('✅ Saved movie ${movie.id} to favorites');
    }
  }

  @override
  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
  }
}
