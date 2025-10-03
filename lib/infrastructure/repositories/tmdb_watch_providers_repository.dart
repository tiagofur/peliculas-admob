import '../../core/cache/cache_service.dart';
import '../../core/logging/logger_factory.dart';
import '../../domain/entities/watch_providers.dart';
import '../datasources/tmdb_watch_providers_datasource.dart';

/// Repository for managing watch providers with caching
/// Provides 24-hour cache for better performance and reduced API calls
class TmdbWatchProvidersRepository {
  TmdbWatchProvidersRepository({
    required this.cacheService,
    TmdbWatchProvidersDatasource? datasource,
  }) : _datasource = datasource ?? TmdbWatchProvidersDatasource();

  final CacheService cacheService;
  final TmdbWatchProvidersDatasource _datasource;

  // Cache TTL: 24 hours (providers don't change frequently)
  static const Duration _cacheTTL = Duration(hours: 24);

  /// Get watch providers for a movie with caching
  ///
  /// [movieId] - TMDB movie ID
  /// [region] - ISO 3166-1 country code (default: 'MX')
  /// [forceRefresh] - Skip cache and fetch fresh data
  ///
  /// Returns [WatchProviders] or null if not available
  Future<WatchProviders?> getWatchProviders(
    int movieId, {
    String region = 'MX',
    bool forceRefresh = false,
  }) async {
    final cacheKey = _getCacheKey(movieId, region);

    // Check cache first (unless force refresh)
    if (!forceRefresh) {
      final cached = await cacheService.get<Map<String, dynamic>>(cacheKey);

      if (cached != null) {
        LoggerFactory.debug(
          '📦 Cache hit for watch providers: movie $movieId, region $region',
        );
        try {
          return WatchProviders.fromJson(cached);
        } catch (e) {
          LoggerFactory.error('Error parsing cached watch providers: $e');
          await cacheService.remove(cacheKey);
        }
      }
    }

    // Fetch from API
    LoggerFactory.debug(
      '🌐 Cache miss for watch providers: movie $movieId, region $region',
    );

    final providers = await _datasource.getWatchProviders(
      movieId,
      region: region,
    );

    // Cache the result (even if null, to avoid repeated failed requests)
    if (providers != null) {
      await cacheService.set(
        cacheKey,
        providers.toJson(),
        expiration: _cacheTTL,
      );

      LoggerFactory.debug(
        '💾 Cached watch providers for movie $movieId',
      );
    } else {
      // Cache null result for shorter time (1 hour) to retry sooner
      await cacheService.set(
        cacheKey,
        {'_null': true}, // Mark as intentionally null
        expiration: const Duration(hours: 1),
      );
    }

    return providers;
  }

  /// Get watch providers for multiple movies
  /// Uses batch operation for better performance
  Future<Map<int, WatchProviders?>> getBatchWatchProviders(
    List<int> movieIds, {
    String region = 'MX',
    bool forceRefresh = false,
  }) async {
    final results = <int, WatchProviders?>{};
    final uncachedIds = <int>[];

    // Check cache for each movie
    if (!forceRefresh) {
      for (final id in movieIds) {
        final cacheKey = _getCacheKey(id, region);
        final cached = await cacheService.get<Map<String, dynamic>>(cacheKey);

        if (cached != null && !cached.containsKey('_null')) {
          try {
            results[id] = WatchProviders.fromJson(cached);
          } catch (e) {
            LoggerFactory.error('Error parsing cached watch providers: $e');
            uncachedIds.add(id);
          }
        } else {
          uncachedIds.add(id);
        }
      }

      LoggerFactory.debug(
        '📦 Batch cache: ${results.length} hits, ${uncachedIds.length} misses',
      );
    } else {
      uncachedIds.addAll(movieIds);
    }

    // Fetch uncached movies from API
    if (uncachedIds.isNotEmpty) {
      final freshData = await _datasource.getBatchWatchProviders(
        uncachedIds,
        region: region,
      );

      // Cache and merge results
      for (final entry in freshData.entries) {
        final cacheKey = _getCacheKey(entry.key, region);
        if (entry.value != null) {
          await cacheService.set(
            cacheKey,
            entry.value!.toJson(),
            expiration: _cacheTTL,
          );
        } else {
          await cacheService.set(
            cacheKey,
            {'_null': true},
            expiration: const Duration(hours: 1),
          );
        }
        results[entry.key] = entry.value;
      }
    }

    return results;
  }

  /// Preload watch providers for upcoming movies
  /// Useful for prefetching data before user navigates
  Future<void> preloadWatchProviders(
    List<int> movieIds, {
    String region = 'MX',
  }) async {
    LoggerFactory.info(
      '⚡ Preloading watch providers for ${movieIds.length} movies',
    );

    // Use batch operation for efficiency
    await getBatchWatchProviders(movieIds, region: region);
  }

  /// Clear cache for specific movie
  Future<void> clearCache(int movieId, {String region = 'MX'}) async {
    final cacheKey = _getCacheKey(movieId, region);
    await cacheService.remove(cacheKey);
    LoggerFactory.debug('🗑️ Cleared cache for movie $movieId');
  }

  /// Clear all watch providers cache
  Future<void> clearAllCache() async {
    // CacheService should support pattern-based deletion
    // For now, we'll just log (cache will expire naturally)
    LoggerFactory.info('🗑️ Watch providers cache will expire naturally');
  }

  /// Get cache key for movie and region
  String _getCacheKey(int movieId, String region) {
    return 'watch_providers_${movieId}_$region';
  }

  /// Get available regions
  Future<List<String>> getAvailableRegions() async {
    return await _datasource.getAvailableRegions();
  }

  /// Dispose resources
  void dispose() {
    _datasource.dispose();
  }
}
