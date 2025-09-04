import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/datasources/local_storage_datasource.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/watchlist_movie.dart';

class HiveDatasource extends LocalStorageDatasource {
  HiveDatasource() {
    _initHive();
  }

  Box<Movie>? _moviesBox;
  Box<WatchlistMovie>? _watchlistBox;
  bool _isInitialized = false;

  /// Public getter for watchlist box
  Box<WatchlistMovie>? get watchlistBox => _watchlistBox;

  Future<void> _initHive() async {
    if (_isInitialized) return;

    try {
      // Inicializar Hive de manera compatible con Web
      if (kIsWeb) {
        // En Web, Hive usa IndexedDB automáticamente
        await Hive.initFlutter();
      } else {
        // En plataformas nativas, usar el directorio por defecto
        await Hive.initFlutter();
      }

      // Registrar adaptadores si no están registrados
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(MovieAdapter());
      }
      if (!Hive.isAdapterRegistered(100)) {
        Hive.registerAdapter(WatchlistPriorityAdapter());
      }
      if (!Hive.isAdapterRegistered(101)) {
        Hive.registerAdapter(WatchlistMovieAdapter());
      }

      _moviesBox = await Hive.openBox<Movie>('movies');
      _watchlistBox = await Hive.openBox<WatchlistMovie>('watchlist_movies');
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error inicializando Hive: $e');
      }
      // En caso de error, intentar con un nombre de box diferente
      try {
        _moviesBox = await Hive.openBox<Movie>('movies_fallback');
        _watchlistBox =
            await Hive.openBox<WatchlistMovie>('watchlist_movies_fallback');
        _isInitialized = true;
      } catch (e2) {
        if (kDebugMode) {
          LoggerFactory.error('Error inicializando Hive con fallback: $e2');
        }
        rethrow;
      }
    }
  }

  @override
  Future<bool> isMovieFavorite(int movieId) async {
    try {
      if (!_isInitialized) await _initHive();
      final moviesBox = _moviesBox;
      if (moviesBox == null) return false;

      final movies = moviesBox.values.where((movie) => movie.id == movieId);
      return movies.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error checking if movie is favorite: $e');
      }
      return false;
    }
  }

  @override
  Future<void> toggleFavorite(Movie movie) async {
    try {
      if (!_isInitialized) await _initHive();
      final moviesBox = _moviesBox;
      if (moviesBox == null) throw Exception('Movies box not available');

      final existingMovieKey = moviesBox.keys.cast<int>().firstWhere(
            (key) => moviesBox.get(key)?.id == movie.id,
            orElse: () => -1,
          );

      if (existingMovieKey != -1) {
        // Borrar
        await moviesBox.delete(existingMovieKey);
        return;
      }

      // Insertar
      await moviesBox.add(movie);
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error toggling favorite: $e');
      }
      rethrow;
    }
  }

  @override
  Future<List<Movie>> loadMovies({int limit = 10, offset = 0}) async {
    try {
      if (!_isInitialized) {
        LoggerFactory.info(
            '🔄 HiveDatasource no inicializado, inicializando...');
        await _initHive();
      }

      if (_moviesBox == null) {
        LoggerFactory.warning('❌ MoviesBox es null, retornando lista vacía');
        return [];
      }

      final allMovies = _moviesBox?.values.toList() ?? [];
      LoggerFactory.info(
          '📊 HiveDatasource: Total películas en box: ${allMovies.length}');
      LoggerFactory.info(
          '📊 HiveDatasource: Solicitado limit=$limit, offset=$offset');

      final endIndex = (offset + limit).clamp(0, allMovies.length);

      if (offset >= allMovies.length) {
        LoggerFactory.info(
            '📊 HiveDatasource: Offset mayor que total, retornando vacío');
        return [];
      }

      final result = allMovies.sublist(offset, endIndex);
      LoggerFactory.info(
          '📊 HiveDatasource: Retornando ${result.length} películas');
      return result;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('❌ Error loading movies: $e');
      }
      return [];
    }
  }

  // Método para limpiar todos los datos
  @override
  Future<void> clearAll() async {
    try {
      if (!_isInitialized) await _initHive();
      final moviesBox = _moviesBox;
      if (moviesBox != null) {
        await moviesBox.clear();
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error clearing all data: $e');
      }
    }
  }

  // Método para cerrar la base de datos
  Future<void> close() async {
    try {
      final moviesBox = _moviesBox;
      if (moviesBox?.isOpen == true) {
        await moviesBox?.close();
      }
      final cacheMetadataBox = _cacheMetadataBox;
      if (cacheMetadataBox?.isOpen == true) {
        await cacheMetadataBox?.close();
      }
      final watchlistBox = _watchlistBox;
      if (watchlistBox?.isOpen == true) {
        await watchlistBox?.close();
      }
      _isInitialized = false;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error closing database: $e');
      }
    }
  }

  // ================== OFFLINE CACHE METHODS ==================

  Box<dynamic>? _cacheMetadataBox;
  static const Duration _defaultCacheExpiry = Duration(days: 7);
  static const int _maxCacheSize = 1000; // Maximum number of cached movies

  /// Initialize cache metadata box
  Future<void> _initCacheMetadata() async {
    if (_cacheMetadataBox?.isOpen == true) return;

    try {
      _cacheMetadataBox = await Hive.openBox('cache_metadata');
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error initializing cache metadata: $e');
      }
    }
  }

  /// Store cache metadata for expiration management
  Future<void> _storeCacheMetadata(int movieId) async {
    try {
      await _initCacheMetadata();
      final cacheMetadataBox = _cacheMetadataBox;
      if (cacheMetadataBox == null) return;

      final metadata = {
        'cached_at': DateTime.now().millisecondsSinceEpoch,
        'expires_at':
            DateTime.now().add(_defaultCacheExpiry).millisecondsSinceEpoch,
      };

      await cacheMetadataBox.put('cache_$movieId', metadata);
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error storing cache metadata: $e');
      }
    }
  }

  /// Check if cached movie is still valid
  Future<bool> _isCacheValid(int movieId) async {
    try {
      await _initCacheMetadata();
      final cacheMetadataBox = _cacheMetadataBox;
      if (cacheMetadataBox == null) return false;

      final metadata =
          cacheMetadataBox.get('cache_$movieId') as Map<String, dynamic>?;
      if (metadata == null) return false;

      final expiresAt = metadata['expires_at'] as int;
      return DateTime.now().millisecondsSinceEpoch < expiresAt;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error checking cache validity: $e');
      }
      return false;
    }
  }

  /// Remove cached movie and its metadata
  Future<void> _removeCachedMovie(int movieId) async {
    try {
      if (!_isInitialized) await _initHive();
      await _initCacheMetadata();

      final moviesBox = _moviesBox;
      if (moviesBox != null) {
        await moviesBox.delete('cache_$movieId');
      }

      final cacheMetadataBox = _cacheMetadataBox;
      if (cacheMetadataBox != null) {
        await cacheMetadataBox.delete('cache_$movieId');
      }

      LoggerFactory.info('🗑️ Removed expired cached movie: $movieId');
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error removing cached movie: $e');
      }
    }
  }

  /// Store category mapping for offline browsing
  Future<void> _storeCategoryMapping(
      String category, List<int> movieIds) async {
    try {
      await _initCacheMetadata();
      final cacheMetadataBox = _cacheMetadataBox;
      if (cacheMetadataBox == null) return;

      final mapping = {
        'movie_ids': movieIds,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      };

      await cacheMetadataBox.put('category_$category', mapping);
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error storing category mapping: $e');
      }
    }
  }

  /// Get category mapping for offline browsing
  Future<List<int>> _getCategoryMapping(String category) async {
    try {
      await _initCacheMetadata();
      final cacheMetadataBox = _cacheMetadataBox;
      if (cacheMetadataBox == null) return [];

      final mapping =
          cacheMetadataBox.get('category_$category') as Map<String, dynamic>?;
      if (mapping == null) return [];

      final movieIds = (mapping['movie_ids'] as List).cast<int>();
      return movieIds;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error getting category mapping: $e');
      }
      return [];
    }
  }

  @override
  Future<bool> cacheMovie(Movie movie) async {
    try {
      if (!_isInitialized) await _initHive();
      final moviesBox = _moviesBox;
      if (moviesBox == null) return false;

      // Check cache size and clean if necessary
      await _enforceCacheLimit();

      // Use a special key format for cached movies vs favorites
      final cacheKey = 'cache_${movie.id}';
      await moviesBox.put(cacheKey, movie);

      // Also store cache metadata for expiration
      await _storeCacheMetadata(movie.id);

      LoggerFactory.info('📱 Movie cached for offline: ${movie.title}');
      return true;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error caching movie: $e');
      }
      return false;
    }
  }

  @override
  Future<Movie?> getCachedMovie(int movieId) async {
    try {
      if (!_isInitialized) await _initHive();
      final moviesBox = _moviesBox;
      if (moviesBox == null) return null;

      // Check if cache is still valid
      if (!await _isCacheValid(movieId)) {
        await _removeCachedMovie(movieId);
        return null;
      }

      final cacheKey = 'cache_$movieId';
      final movie = moviesBox.get(cacheKey);

      if (movie != null) {
        LoggerFactory.info('📱 Retrieved cached movie: ${movie.title}');
      }

      return movie;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error getting cached movie: $e');
      }
      return null;
    }
  }

  @override
  Future<void> cacheMovies(List<Movie> movies, String category) async {
    try {
      if (!_isInitialized) await _initHive();
      if (_moviesBox == null) return;

      for (final movie in movies) {
        await cacheMovie(movie);
      }

      // Store category mapping
      await _storeCategoryMapping(category, movies.map((m) => m.id).toList());

      LoggerFactory.info(
          '📱 Cached ${movies.length} movies for category: $category');
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error caching movies for category $category: $e');
      }
    }
  }

  @override
  Future<List<Movie>> getCachedMoviesByCategory(String category) async {
    try {
      if (!_isInitialized) await _initHive();
      if (_moviesBox == null) return [];

      final movieIds = await _getCategoryMapping(category);
      if (movieIds.isEmpty) return [];

      final cachedMovies = <Movie>[];
      for (final movieId in movieIds) {
        final movie = await getCachedMovie(movieId);
        if (movie != null) {
          cachedMovies.add(movie);
        }
      }

      LoggerFactory.info(
          '📱 Retrieved ${cachedMovies.length} cached movies for category: $category');
      return cachedMovies;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error(
            'Error getting cached movies for category $category: $e');
      }
      return [];
    }
  }

  @override
  Future<void> clearExpiredCache() async {
    try {
      if (!_isInitialized) await _initHive();
      await _initCacheMetadata();

      final cacheMetadataBox = _cacheMetadataBox;
      final moviesBox = _moviesBox;
      if (cacheMetadataBox == null || moviesBox == null) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final keysToRemove = <String>[];

      for (final key in cacheMetadataBox.keys) {
        if (key.toString().startsWith('cache_')) {
          final metadata = cacheMetadataBox.get(key) as Map<String, dynamic>?;
          if (metadata != null) {
            final expiresAt = metadata['expires_at'] as int;
            if (now > expiresAt) {
              keysToRemove.add(key.toString());
            }
          }
        }
      }

      for (final key in keysToRemove) {
        await cacheMetadataBox.delete(key);
        await moviesBox.delete(key);
      }

      LoggerFactory.info(
          '🧹 Cleared ${keysToRemove.length} expired cache entries');
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error clearing expired cache: $e');
      }
    }
  }

  @override
  Future<int> getCacheSize() async {
    try {
      if (!_isInitialized) await _initHive();
      final moviesBox = _moviesBox;
      if (moviesBox == null) return 0;

      int cacheCount = 0;
      for (final key in moviesBox.keys) {
        if (key.toString().startsWith('cache_')) {
          cacheCount++;
        }
      }

      return cacheCount;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error getting cache size: $e');
      }
      return 0;
    }
  }

  @override
  Future<void> clearAllCache() async {
    try {
      if (!_isInitialized) await _initHive();
      await _initCacheMetadata();

      final moviesBox = _moviesBox;
      final cacheMetadataBox = _cacheMetadataBox;
      if (moviesBox == null || cacheMetadataBox == null) return;

      // Get all cache keys
      final cacheKeys = <String>[];
      for (final key in moviesBox.keys) {
        if (key.toString().startsWith('cache_')) {
          cacheKeys.add(key.toString());
        }
      }

      // Remove all cache entries and metadata
      for (final key in cacheKeys) {
        await moviesBox.delete(key);
        await cacheMetadataBox.delete(key);
      }

      // Clear category mappings
      final categoryKeys = <String>[];
      for (final key in cacheMetadataBox.keys) {
        if (key.toString().startsWith('category_')) {
          categoryKeys.add(key.toString());
        }
      }

      for (final key in categoryKeys) {
        await cacheMetadataBox.delete(key);
      }

      LoggerFactory.info(
          '🗑️ Cleared all cache: ${cacheKeys.length} movies, ${categoryKeys.length} categories');
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error clearing all cache: $e');
      }
    }
  }

  /// Enforce cache size limit by removing oldest entries
  Future<void> _enforceCacheLimit() async {
    try {
      final currentSize = await getCacheSize();
      if (currentSize < _maxCacheSize) return;

      await _initCacheMetadata();
      final cacheMetadataBox = _cacheMetadataBox;
      final moviesBox = _moviesBox;
      if (cacheMetadataBox == null || moviesBox == null) return;

      // Get all cache entries with timestamps
      final cacheEntries = <MapEntry<String, int>>[];

      for (final key in cacheMetadataBox.keys) {
        if (key.toString().startsWith('cache_')) {
          final metadata = cacheMetadataBox.get(key) as Map<String, dynamic>?;
          if (metadata != null) {
            final cachedAt = metadata['cached_at'] as int;
            cacheEntries.add(MapEntry(key.toString(), cachedAt));
          }
        }
      }

      // Sort by timestamp (oldest first)
      cacheEntries.sort((a, b) => a.value.compareTo(b.value));

      // Remove oldest entries to get under limit
      final entriesToRemove = currentSize -
          (_maxCacheSize * 0.8).round(); // Remove 20% extra for buffer

      for (int i = 0; i < entriesToRemove && i < cacheEntries.length; i++) {
        final key = cacheEntries[i].key;
        await cacheMetadataBox.delete(key);
        await moviesBox.delete(key);
      }

      LoggerFactory.info(
          '🧹 Removed $entriesToRemove old cache entries to enforce limit');
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error enforcing cache limit: $e');
      }
    }
  }

  @override
  Future<void> addToWatchlist(Movie movie, WatchlistPriority priority) async {
    try {
      if (!_isInitialized) await _initHive();
      final watchlistBox = _watchlistBox;
      if (watchlistBox == null) throw Exception('Watchlist box not available');

      // Verificar si la película ya está en la watchlist
      final existingMovie = watchlistBox.values.firstWhere(
        (watchlistMovie) => watchlistMovie.movieId == movie.id,
        orElse: () => throw StateError('Not found'),
      );

      // Si ya existe, actualizar la prioridad
      final updatedMovie = existingMovie.copyWith(
        priority: priority,
        lastModifiedAt: DateTime.now(),
      );

      final key = watchlistBox.keys.firstWhere(
        (key) => watchlistBox.get(key)?.movieId == movie.id,
      );

      await watchlistBox.put(key, updatedMovie);
      LoggerFactory.info(
          '📝 Updated movie priority in watchlist: ${movie.title}');
      return;
    } catch (e) {
      // La película no existe, continuar con la inserción
    }

    try {
      // Crear nueva entrada en watchlist
      const uuid = Uuid();
      final watchlistMovie = WatchlistMovie(
        id: uuid.v4(),
        movieId: movie.id,
        movieTitle: movie.title,
        moviePosterPath: movie.posterPath,
        movieBackdropPath: movie.backdropPath,
        movieOverview: movie.overview,
        movieReleaseDate: movie.releaseDate,
        movieVoteAverage: movie.voteAverage,
        priority: priority,
        addedAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
      );

      final box = watchlistBox;
      if (box == null) {
        throw StateError('Watchlist box is not initialized');
      }
      await box.add(watchlistMovie);
      LoggerFactory.info(
          '✅ Added movie to watchlist: ${movie.title} with priority: ${priority.displayName}');
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error adding movie to watchlist: $e');
      }
      rethrow;
    }
  }

  @override
  Future<int> getWatchlistCount() async {
    try {
      if (!_isInitialized) await _initHive();
      final watchlistBox = _watchlistBox;
      if (watchlistBox == null) return 0;

      final count = watchlistBox.length;
      LoggerFactory.info('📊 Watchlist count: $count');
      return count;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('❌ Error getting watchlist count: $e');
      }
      return 0;
    }
  }

  @override
  Future<WatchlistMovie?> getWatchlistMovie(int movieId) async {
    try {
      if (!_isInitialized) await _initHive();
      final watchlistBox = _watchlistBox;
      if (watchlistBox == null) return null;

      final watchlistMovie = watchlistBox.values.firstWhere(
        (watchlistMovie) => watchlistMovie.movieId == movieId,
        orElse: () => throw StateError('Not found'),
      );

      return watchlistMovie;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error getting watchlist movie: $e');
      }
      return null;
    }
  }

  @override
  Future<bool> isMovieInWatchlist(int movieId) async {
    try {
      if (!_isInitialized) await _initHive();
      final watchlistBox = _watchlistBox;
      if (watchlistBox == null) return false;

      final watchlistMovies = watchlistBox.values.where(
        (watchlistMovie) => watchlistMovie.movieId == movieId,
      );

      return watchlistMovies.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error checking if movie is in watchlist: $e');
      }
      return false;
    }
  }

  @override
  Future<List<WatchlistMovie>> loadWatchlistMovies(
      {int limit = 10, int offset = 0, WatchlistPriority? priority}) async {
    try {
      if (!_isInitialized) await _initHive();
      final watchlistBox = _watchlistBox;
      if (watchlistBox == null) return [];

      var allWatchlistMovies = watchlistBox.values.toList();

      // Filtrar por prioridad si se especifica
      if (priority != null) {
        allWatchlistMovies = allWatchlistMovies
            .where((movie) => movie.priority == priority)
            .toList();
      }

      // Ordenar por fecha de agregado (más recientes primero)
      allWatchlistMovies.sort((a, b) => b.addedAt.compareTo(a.addedAt));

      LoggerFactory.info(
          '📊 HiveDatasource Watchlist: Total películas: ${allWatchlistMovies.length}');
      LoggerFactory.info(
          '📊 HiveDatasource Watchlist: Solicitado limit=$limit, offset=$offset, priority=$priority');

      final endIndex = (offset + limit).clamp(0, allWatchlistMovies.length);

      if (offset >= allWatchlistMovies.length) {
        LoggerFactory.info(
            '📊 HiveDatasource Watchlist: Offset mayor que total, retornando vacío');
        return [];
      }

      final result = allWatchlistMovies.sublist(offset, endIndex);
      LoggerFactory.info(
          '📊 HiveDatasource Watchlist: Retornando ${result.length} películas');
      return result;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('❌ Error loading watchlist movies: $e');
      }
      return [];
    }
  }

  @override
  Future<bool> removeFromWatchlist(int movieId) async {
    try {
      if (!_isInitialized) await _initHive();
      final watchlistBox = _watchlistBox;
      if (watchlistBox == null) return false;

      // Buscar la película en la watchlist
      String? keyToRemove;
      for (var entry in watchlistBox.toMap().entries) {
        if (entry.value.movieId == movieId) {
          keyToRemove = entry.key.toString();
          break;
        }
      }

      if (keyToRemove != null) {
        await watchlistBox.delete(keyToRemove);
        LoggerFactory.info('✅ Película removida de watchlist: $movieId');
        return true;
      } else {
        LoggerFactory.info('⚠️ Película no encontrada en watchlist: $movieId');
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('❌ Error removing from watchlist: $e');
      }
      return false;
    }
  }

  @override
  Future<bool> updateWatchlistPriority(
      int movieId, WatchlistPriority priority) async {
    try {
      if (!_isInitialized) await _initHive();
      final watchlistBox = _watchlistBox;
      if (watchlistBox == null) return false;

      // Buscar la película en la watchlist
      String? keyToUpdate;
      WatchlistMovie? movieToUpdate;
      for (var entry in watchlistBox.toMap().entries) {
        if (entry.value.movieId == movieId) {
          keyToUpdate = entry.key.toString();
          movieToUpdate = entry.value;
          break;
        }
      }

      if (keyToUpdate != null && movieToUpdate != null) {
        // Crear una nueva instancia con la prioridad actualizada
        final updatedMovie = WatchlistMovie(
          id: movieToUpdate.id,
          movieId: movieToUpdate.movieId,
          movieTitle: movieToUpdate.movieTitle,
          moviePosterPath: movieToUpdate.moviePosterPath,
          movieBackdropPath: movieToUpdate.movieBackdropPath,
          priority: priority,
          addedAt: movieToUpdate.addedAt,
          lastModifiedAt: DateTime.now(),
        );

        await watchlistBox.put(keyToUpdate, updatedMovie);
        LoggerFactory.info(
            '✅ Prioridad actualizada para película $movieId: $priority');
        return true;
      } else {
        LoggerFactory.info('⚠️ Película no encontrada en watchlist: $movieId');
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('❌ Error updating watchlist priority: $e');
      }
      return false;
    }
  }

  @override
  Future<List<WatchlistMovie>> getAllWatchlistMovies() async {
    try {
      if (!_isInitialized) await _initHive();
      final watchlistBox = _watchlistBox;
      if (watchlistBox == null) return [];

      final allWatchlistMovies = watchlistBox.values.toList();

      // Ordenar por fecha de agregado (más recientes primero)
      allWatchlistMovies.sort((a, b) => b.addedAt.compareTo(a.addedAt));

      LoggerFactory.info(
          '📊 HiveDatasource getAllWatchlistMovies: Retornando ${allWatchlistMovies.length} películas');
      return allWatchlistMovies;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('❌ Error getting all watchlist movies: $e');
      }
      return [];
    }
  }
}
