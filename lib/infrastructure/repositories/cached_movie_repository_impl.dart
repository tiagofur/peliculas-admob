import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../core/exceptions/app_exceptions.dart';
import '../../core/logging/logger_factory.dart';
import '../../domain/datasources/local_storage_datasource.dart';
import '../../domain/datasources/movies_datasource.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/movies_repository.dart';

/// Enhanced movie repository with offline cache support
class CachedMovieRepositoryImpl extends MoviesRepository {
  CachedMovieRepositoryImpl({
    required MoviesDatasource networkDatasource,
    required LocalStorageDatasource localDatasource,
  })  : _networkDatasource = networkDatasource,
        _localDatasource = localDatasource;

  final MoviesDatasource _networkDatasource;
  final LocalStorageDatasource _localDatasource;

  final Map<String, List<Movie>> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Duration _memoryCacheTimeout = const Duration(minutes: 30);

  /// Check network connectivity
  Future<bool> _hasConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult.contains(ConnectivityResult.mobile) ||
          connectivityResult.contains(ConnectivityResult.wifi) ||
          connectivityResult.contains(ConnectivityResult.ethernet);
    } catch (e) {
      LoggerFactory.warning('Error checking connectivity: $e');
      return false;
    }
  }

  /// Check if memory cache is valid
  bool _isMemoryCacheValid(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _memoryCacheTimeout;
  }

  /// Save to memory cache
  void _saveToMemoryCache(String key, List<Movie> data) {
    _memoryCache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
  }

  /// Get from memory cache
  List<Movie>? _getFromMemoryCache(String key) {
    if (_isMemoryCacheValid(key)) {
      return _memoryCache[key];
    }
    return null;
  }

  /// Generic method to get movies with offline-first approach
  Future<List<Movie>> _getMoviesWithCache(
    String cacheKey,
    Future<List<Movie>> Function() networkCall,
  ) async {
    // 1. Check memory cache first (fastest)
    final memoryCached = _getFromMemoryCache(cacheKey);
    if (memoryCached != null) {
      LoggerFactory.info(
          '📱 Retrieved from memory cache: ${memoryCached.length} movies');
      return memoryCached;
    }

    // 2. Check offline cache
    final offlineCached =
        await _localDatasource.getCachedMoviesByCategory(cacheKey);
    if (offlineCached.isNotEmpty) {
      LoggerFactory.info(
          '📱 Retrieved from offline cache: ${offlineCached.length} movies');
      _saveToMemoryCache(cacheKey, offlineCached);
      return offlineCached;
    }

    // 3. Check connectivity before network call
    final hasConnection = await _hasConnectivity();
    if (!hasConnection) {
      LoggerFactory.warning('📱 No connectivity - returning empty list');
      return [];
    }

    // 4. Make network call
    try {
      LoggerFactory.info('🌐 Fetching from network: $cacheKey');
      final networkData = await networkCall();

      if (networkData.isNotEmpty) {
        // Save to both caches
        _saveToMemoryCache(cacheKey, networkData);
        await _localDatasource.cacheMovies(networkData, cacheKey);

        LoggerFactory.info('✅ Fetched and cached ${networkData.length} movies');
        return networkData;
      }
    } catch (e) {
      LoggerFactory.error('❌ Network error for $cacheKey: $e');
    }

    // 5. Last resort: try to get any cached data (even expired)
    final expiredCache =
        await _localDatasource.getCachedMoviesByCategory(cacheKey);
    if (expiredCache.isNotEmpty) {
      LoggerFactory.info(
          '📱 Using expired cache: ${expiredCache.length} movies');
      return expiredCache;
    }

    LoggerFactory.warning('❌ No data available for $cacheKey');
    return [];
  }

  @override
  Future<List<Movie>> getNowPlaying({int page = 1}) {
    return _getMoviesWithCache(
      'now_playing_$page',
      () => _networkDatasource.getNowPlaying(page: page),
    );
  }

  @override
  Future<List<Movie>> getPopular({int page = 1}) {
    return _getMoviesWithCache(
      'popular_$page',
      () => _networkDatasource.getPopular(page: page),
    );
  }

  @override
  Future<List<Movie>> getTopRated({int page = 1}) {
    return _getMoviesWithCache(
      'top_rated_$page',
      () => _networkDatasource.getTopRated(page: page),
    );
  }

  @override
  Future<List<Movie>> getUpcoming({int page = 1}) {
    return _getMoviesWithCache(
      'upcoming_$page',
      () => _networkDatasource.getUpcoming(page: page),
    );
  }

  @override
  Future<Movie> getMovieById(String id) async {
    final movieIdInt = int.tryParse(id) ?? 0;
    final cacheKey = 'movie_$id';

    // 1. Check memory cache (with credits)
    final memoryCached = _getFromMemoryCache(cacheKey);
    if (memoryCached != null && memoryCached.isNotEmpty) {
      final hasCredits = memoryCached.first.credits != null;
      LoggerFactory.info(
          '📱 Movie from memory cache: ${memoryCached.first.title} (credits: $hasCredits)');

      if (kDebugMode) {
        print('🔍 Memory Cache Movie Details:');
        print('  ID: ${memoryCached.first.id}');
        print('  Title: ${memoryCached.first.title}');
        print('  Has credits: ${memoryCached.first.credits != null}');
        if (memoryCached.first.credits != null) {
          print('  Credits keys: ${memoryCached.first.credits!.keys.toList()}');
          print(
              '  Cast length: ${(memoryCached.first.credits!['cast'] as List?)?.length ?? 0}');
        }
      }

      if (hasCredits) {
        return memoryCached.first;
      }

      // If memory cache exists but without credits, continue to fetch from network
      LoggerFactory.info(
          '⚠️ Memory cache exists but without credits - fetching from network');
    }

    // 2. Check connectivity
    final hasConnection = await _hasConnectivity();

    if (hasConnection) {
      // 3. Network call (preferred when online - includes credits)
      try {
        LoggerFactory.info('🌐 Fetching movie from network: $id');
        final movie = await _networkDatasource.getMovieById(id);

        // Save to both caches (basic data only - credits not persisted in Hive)
        _saveToMemoryCache(cacheKey, [movie]);
        await _localDatasource.cacheMovie(movie);

        LoggerFactory.info(
            '✅ Fetched and cached movie: ${movie.title} (credits: ${movie.credits != null})');
        return movie;
      } catch (e) {
        LoggerFactory.error('❌ Network error for movie $id: $e');

        // Fallback to offline cache if network fails
        final cachedMovie = await _localDatasource.getCachedMovie(movieIdInt);
        if (cachedMovie != null) {
          LoggerFactory.info(
              '📱 Fallback to offline cache: ${cachedMovie.title} (without credits)');
          return cachedMovie;
        }

        throw MovieException('Movie not found: $id', 'MOVIE_NOT_FOUND');
      }
    } else {
      // 4. Offline mode - use cache
      final cachedMovie = await _localDatasource.getCachedMovie(movieIdInt);
      if (cachedMovie != null) {
        LoggerFactory.info(
            '📱 Movie from offline cache: ${cachedMovie.title} (without credits - offline)');
        return cachedMovie;
      }

      throw MovieException(
        'Movie not available offline: $id',
        'MOVIE_OFFLINE_UNAVAILABLE',
      );
    }
  }

  @override
  Future<List<Movie>> searchMovies(String query) {
    if (query.trim().isEmpty) return Future.value([]);

    return _getMoviesWithCache(
      'search_${query.hashCode}',
      () => _networkDatasource.searchMovies(query),
    );
  }

  @override
  Future<List<Movie>> getSimilarMovies(int movieId) {
    return _getMoviesWithCache(
      'similar_$movieId',
      () => _networkDatasource.getSimilarMovies(movieId),
    );
  }

  @override
  Future<List<Video>> getYoutubeVideosById(int movieId) async {
    // Videos are not cached as they change frequently and are less critical for offline use
    final hasConnection = await _hasConnectivity();
    if (!hasConnection) {
      LoggerFactory.warning(
          '📱 No connectivity - videos not available offline');
      return [];
    }

    try {
      return await _networkDatasource.getYoutubeVideosById(movieId);
    } catch (e) {
      LoggerFactory.error('❌ Error fetching videos for movie $movieId: $e');
      return [];
    }
  }
}
