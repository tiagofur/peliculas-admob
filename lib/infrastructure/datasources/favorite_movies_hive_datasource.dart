
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
        .where((item) => item is Movie)
        .cast<Movie>()
        .any((movie) => movie.id == movieId);
  }

  @override
  Future<List<Movie>> loadMovies({int limit = 10, offset = 0}) async {
    final box = await _getBox();
    
    // 🐛 DEBUG: Log raw data from box
    LoggerFactory.info('🔍 FavoriteMoviesHiveDatasource box contains ${box.length} raw items');
    
    // ✅ Validación de tipos para evitar corrupción
    final allMovies = box.values
        .where((item) => item is Movie && item.id != null && item.title.isNotEmpty)
        .cast<Movie>()
        .toList();
    
    // 🐛 DEBUG: Log processed movies
    LoggerFactory.info('🔍 After validation: ${allMovies.length} valid movies: ${allMovies.map((m) => '${m.id}:${m.title}').toList()}');
    
    final endIndex = (offset + limit).clamp(0, allMovies.length);
    if (offset >= allMovies.length) return [];
    
    final result = allMovies.sublist(offset, endIndex);
    LoggerFactory.info('🔍 Returning ${result.length} movies (offset: $offset, limit: $limit)');
    return result;
  }

  @override
  Future<void> toggleFavorite(Movie movie) async {
    final box = await _getBox();
    
    // 🐛 DEBUG: Log before operation
    LoggerFactory.info('🔍 toggleFavorite for movie: ${movie.id}:${movie.title}');
    LoggerFactory.info('🔍 Box before operation: ${box.length} items');
    
    final existingMovieIndex =
        box.values.toList().indexWhere((m) => m.id == movie.id);

    if (existingMovieIndex != -1) {
      await box.deleteAt(existingMovieIndex);
      LoggerFactory.info('✅ Removed movie ${movie.id} from favorites (was at index $existingMovieIndex)');
    } else {
      await box.add(movie);
      LoggerFactory.info('✅ Added movie ${movie.id} to favorites');
    }
    
    // 🐛 DEBUG: Log after operation  
    LoggerFactory.info('🔍 Box after operation: ${box.length} items');
  }

  @override
  Future<void> addToWatchlist(Movie movie, WatchlistPriority priority) {
    throw UnimplementedError();
  }

  @override
  Future<List<WatchlistMovie>> getAllWatchlistMovies() {
    throw UnimplementedError();
  }

  @override
  Future<int> getWatchlistCount() {
    throw UnimplementedError();
  }

  @override
  Future<WatchlistMovie?> getWatchlistMovie(int movieId) {
    throw UnimplementedError();
  }

  @override
  Future<bool> isMovieInWatchlist(int movieId) {
    throw UnimplementedError();
  }

  @override
  Future<List<WatchlistMovie>> loadWatchlistMovies(
      {int limit = 10, int offset = 0, WatchlistPriority? priority}) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeFromWatchlist(int movieId) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateWatchlistPriority(
      int movieId, WatchlistPriority priority) {
    throw UnimplementedError();
  }

  @override
  Future<bool> cacheMovie(Movie movie) async {
    throw UnimplementedError('FavoriteMoviesHiveDatasource should not cache individual movies - only favorites');
  }

  @override
  Future<void> cacheMovies(List<Movie> movies, String category) async {
    throw UnimplementedError('FavoriteMoviesHiveDatasource should not cache all movies - only favorites');
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
      return box.values.firstWhere((movie) => movie.id == movieId);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<Movie>> getCachedMoviesByCategory(String category) async {
    final box = await _getBox();
    return box.values.toList();
  }
  
  @override
  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
  }
}
