import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/datasources/local_storage_datasource.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/watchlist_movie.dart';
import 'watchlist_hive_datasource.dart';

class FavoriteMoviesSharedPreferencesDatasource extends LocalStorageDatasource {
  static const String _favoriteMoviesKey = 'favorite_movies';
  
  // Usamos el datasource de Hive para watchlist
  final WatchlistHiveDatasource _watchlistDatasource = WatchlistHiveDatasource();

  @override
  Future<bool> isMovieFavorite(int movieId) async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteMoviesJson = prefs.getStringList(_favoriteMoviesKey) ?? [];

    return favoriteMoviesJson.any((movieJson) {
      final movieData = jsonDecode(movieJson);
      return movieData['id'] == movieId;
    });
  }

  @override
  Future<void> toggleFavorite(Movie movie) async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteMoviesJson = prefs.getStringList(_favoriteMoviesKey) ?? [];

    final existingIndex = favoriteMoviesJson.indexWhere((movieJson) {
      final movieData = jsonDecode(movieJson);
      return movieData['id'] == movie.id;
    });

    if (existingIndex != -1) {
      // Remover de favoritos
      favoriteMoviesJson.removeAt(existingIndex);
    } else {
      // Agregar a favoritos
      favoriteMoviesJson.add(jsonEncode(_movieToJson(movie)));
    }

    await prefs.setStringList(_favoriteMoviesKey, favoriteMoviesJson);
  }

  @override
  Future<List<Movie>> loadMovies({int limit = 10, offset = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteMoviesJson = prefs.getStringList(_favoriteMoviesKey) ?? [];

    final allMovies = favoriteMoviesJson
        .map((movieJson) => _movieFromJson(jsonDecode(movieJson)))
        .toList();

    final endIndex = (offset + limit).clamp(0, allMovies.length);

    if (offset >= allMovies.length) return [];

    return allMovies.sublist(offset, endIndex);
  }

  // Métodos de serialización
  Map<String, dynamic> _movieToJson(Movie movie) {
    return {
      'id': movie.id,
      'adult': movie.adult,
      'backdropPath': movie.backdropPath,
      'genreIds': movie.genreIds,
      'originalLanguage': movie.originalLanguage,
      'originalTitle': movie.originalTitle,
      'overview': movie.overview,
      'popularity': movie.popularity,
      'posterPath': movie.posterPath,
      'releaseDate': movie.releaseDate.toIso8601String(),
      'title': movie.title,
      'video': movie.video,
      'voteAverage': movie.voteAverage,
      'voteCount': movie.voteCount,
    };
  }

  Movie _movieFromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] as int,
      adult: json['adult'] as bool,
      backdropPath: json['backdropPath'] as String,
      genreIds: List<String>.from(json['genreIds'] as List),
      originalLanguage: json['originalLanguage'] as String,
      originalTitle: json['originalTitle'] as String,
      overview: json['overview'] as String,
      popularity: (json['popularity'] as num).toDouble(),
      posterPath: json['posterPath'] as String,
      releaseDate: json['releaseDate'] != null
          ? DateTime.parse(json['releaseDate'] as String)
          : DateTime(1900),
      title: json['title'] as String,
      video: json['video'] as bool,
      voteAverage: (json['voteAverage'] as num).toDouble(),
      voteCount: json['voteCount'] as int,
    );
  }

  // Implementación de métodos de watchlist usando Hive
  @override
  Future<void> addToWatchlist(Movie movie, WatchlistPriority priority) async {
    await _watchlistDatasource.addToWatchlist(movie, priority);
  }

  @override
  Future<void> removeFromWatchlist(int movieId) async {
    await _watchlistDatasource.removeFromWatchlist(movieId);
  }

  @override
  Future<void> updateWatchlistPriority(int movieId, WatchlistPriority priority) async {
    await _watchlistDatasource.updateWatchlistPriority(movieId, priority);
  }

  @override
  Future<bool> isMovieInWatchlist(int movieId) async {
    return await _watchlistDatasource.isMovieInWatchlist(movieId);
  }

  @override
  Future<List<WatchlistMovie>> loadWatchlistMovies({
    int limit = 10,
    int offset = 0,
    WatchlistPriority? priority,
  }) async {
    return await _watchlistDatasource.loadWatchlistMovies(
      limit: limit,
      offset: offset,
      priority: priority,
    );
  }

  @override
  Future<WatchlistMovie?> getWatchlistMovie(int movieId) async {
    return await _watchlistDatasource.getWatchlistMovie(movieId);
  }

  @override
  Future<int> getWatchlistCount() async {
    return await _watchlistDatasource.getWatchlistCount();
  }

  // ================== OFFLINE CACHE METHODS ==================
  // For web platform, we implement cache using SharedPreferences

  static const String _cachePrefix = 'cached_movie_';
  static const String _cacheMetadataPrefix = 'cache_metadata_';
  static const String _categoryPrefix = 'category_';
  static const Duration _defaultCacheExpiry = Duration(days: 7);
  static const int _maxCacheSize = 500; // Reduced for web storage limits

  @override
  Future<bool> cacheMovie(Movie movie) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check cache size and enforce limit
      await _enforceCacheLimit();
      
      // Store movie data
      final movieKey = '$_cachePrefix${movie.id}';
      final movieJson = jsonEncode(_movieToJson(movie));
      await prefs.setString(movieKey, movieJson);
      
      // Store metadata
      final metadataKey = '$_cacheMetadataPrefix${movie.id}';
      final metadata = {
        'cached_at': DateTime.now().millisecondsSinceEpoch,
        'expires_at': DateTime.now().add(_defaultCacheExpiry).millisecondsSinceEpoch,
      };
      await prefs.setString(metadataKey, jsonEncode(metadata));
      
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Movie?> getCachedMovie(int movieId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if cache is valid
      if (!await _isCacheValid(movieId)) {
        await _removeCachedMovie(movieId);
        return null;
      }
      
      // Get movie data
      final movieKey = '$_cachePrefix$movieId';
      final movieJson = prefs.getString(movieKey);
      if (movieJson == null) return null;
      
      final movieData = jsonDecode(movieJson);
      return _movieFromJson(movieData);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> cacheMovies(List<Movie> movies, String category) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Cache individual movies
      for (final movie in movies) {
        await cacheMovie(movie);
      }
      
      // Store category mapping
      final categoryKey = '$_categoryPrefix$category';
      final categoryData = {
        'movie_ids': movies.map((m) => m.id).toList(),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(categoryKey, jsonEncode(categoryData));
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  Future<List<Movie>> getCachedMoviesByCategory(String category) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get category mapping
      final categoryKey = '$_categoryPrefix$category';
      final categoryJson = prefs.getString(categoryKey);
      if (categoryJson == null) return [];
      
      final categoryData = jsonDecode(categoryJson);
      final movieIds = (categoryData['movie_ids'] as List).cast<int>();
      
      // Get individual movies
      final movies = <Movie>[];
      for (final movieId in movieIds) {
        final movie = await getCachedMovie(movieId);
        if (movie != null) {
          movies.add(movie);
        }
      }
      
      return movies;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> clearExpiredCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      for (final key in keys) {
        if (key.startsWith(_cacheMetadataPrefix)) {
          final metadataJson = prefs.getString(key);
          if (metadataJson != null) {
            final metadata = jsonDecode(metadataJson);
            final expiresAt = metadata['expires_at'] as int;
            if (now > expiresAt) {
              // Remove metadata and corresponding movie data
              final movieId = key.replaceFirst(_cacheMetadataPrefix, '');
              await prefs.remove(key);
              await prefs.remove('$_cachePrefix$movieId');
            }
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  Future<int> getCacheSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      return keys.where((key) => key.startsWith(_cachePrefix)).length;
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().toList();
      
      for (final key in keys) {
        if (key.startsWith(_cachePrefix) || 
            key.startsWith(_cacheMetadataPrefix) || 
            key.startsWith(_categoryPrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }

  /// Check if cached movie is still valid
  Future<bool> _isCacheValid(int movieId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadataKey = '$_cacheMetadataPrefix$movieId';
      final metadataJson = prefs.getString(metadataKey);
      if (metadataJson == null) return false;
      
      final metadata = jsonDecode(metadataJson);
      final expiresAt = metadata['expires_at'] as int;
      return DateTime.now().millisecondsSinceEpoch < expiresAt;
    } catch (e) {
      return false;
    }
  }

  /// Remove cached movie and its metadata
  Future<void> _removeCachedMovie(int movieId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_cachePrefix$movieId');
      await prefs.remove('$_cacheMetadataPrefix$movieId');
    } catch (e) {
      // Ignore errors
    }
  }

  /// Enforce cache size limit by removing oldest entries
  Future<void> _enforceCacheLimit() async {
    try {
      final currentSize = await getCacheSize();
      if (currentSize < _maxCacheSize) return;
      
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      // Get all cache entries with timestamps
      final cacheEntries = <MapEntry<String, int>>[];
      
      for (final key in keys) {
        if (key.startsWith(_cacheMetadataPrefix)) {
          final metadataJson = prefs.getString(key);
          if (metadataJson != null) {
            final metadata = jsonDecode(metadataJson);
            final cachedAt = metadata['cached_at'] as int;
            cacheEntries.add(MapEntry(key, cachedAt));
          }
        }
      }
      
      // Sort by timestamp (oldest first)
      cacheEntries.sort((a, b) => a.value.compareTo(b.value));
      
      // Remove oldest entries to get under limit
      final entriesToRemove = currentSize - (_maxCacheSize * 0.8).round();
      
      for (int i = 0; i < entriesToRemove && i < cacheEntries.length; i++) {
        final metadataKey = cacheEntries[i].key;
        final movieId = metadataKey.replaceFirst(_cacheMetadataPrefix, '');
        await prefs.remove(metadataKey);
        await prefs.remove('$_cachePrefix$movieId');
      }
    } catch (e) {
      // Ignore errors
    }
  }
}
