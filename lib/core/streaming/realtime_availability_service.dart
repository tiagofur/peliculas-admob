import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../analytics/analytics_service.dart';
import '../logging/logger_factory.dart';
import 'streaming.dart';

/// Service for real-time streaming availability detection with optimized caching
class RealtimeAvailabilityService {
  RealtimeAvailabilityService({
    required NetflixService netflixService,
    required PrimeVideoService primeVideoService,
    required DisneyPlusService disneyPlusService,
    required HboMaxService hboMaxService,
    required AnalyticsService analytics,
  })  : _netflixService = netflixService,
        _primeVideoService = primeVideoService,
        _disneyPlusService = disneyPlusService,
        _hboMaxService = hboMaxService,
        _analytics = analytics {
    _initializeCache();
  }

  final NetflixService _netflixService;
  final PrimeVideoService _primeVideoService;
  final DisneyPlusService _disneyPlusService;
  final HboMaxService _hboMaxService;
  final AnalyticsService _analytics;
  // Using LoggerFactory for logging

  // Cache configuration
  static const Duration _cacheExpiration = Duration(hours: 6);
  static const Duration _realtimeUpdateInterval = Duration(minutes: 15);
  static const String _cacheKeyPrefix = 'streaming_availability_';

  // Real-time update timers
  final Map<String, Timer> _updateTimers = {};
  final Map<String,
          StreamController<Map<StreamingPlatform, PlatformAvailability?>>>
      _streamControllers = {};

  // Cache storage
  SharedPreferences? _prefs;
  final Map<String, CachedAvailability> _memoryCache = {};

  /// Initialize cache storage
  Future<void> _initializeCache() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      LoggerFactory.info('Realtime availability cache initialized');
    } catch (e) {
      LoggerFactory.error('Failed to initialize cache: $e');
    }
  }

  /// Get real-time availability stream for a movie
  Stream<Map<StreamingPlatform, PlatformAvailability?>>
      getRealtimeAvailability({
    required String movieId,
    String region = 'US',
  }) {
    final streamKey = '${movieId}_$region';

    // Return existing stream if available
    if (_streamControllers.containsKey(streamKey)) {
      return _streamControllers[streamKey]!.stream;
    }

    // Create new stream controller
    final controller = StreamController<
        Map<StreamingPlatform, PlatformAvailability?>>.broadcast(
      onCancel: () => _cleanupStream(streamKey),
    );
    _streamControllers[streamKey] = controller;

    // Start real-time updates
    _startRealtimeUpdates(
        movieId: movieId, region: region, controller: controller);

    return controller.stream;
  }

  /// Start real-time updates for a movie
  void _startRealtimeUpdates({
    required String movieId,
    required String region,
    required StreamController<Map<StreamingPlatform, PlatformAvailability?>>
        controller,
  }) async {
    final streamKey = '${movieId}_$region';

    // Initial availability check
    final initialAvailability = await _checkAllPlatformsAvailability(
      movieId: movieId,
      region: region,
    );

    if (!controller.isClosed) {
      controller.add(initialAvailability);
    }

    // Set up periodic updates
    _updateTimers[streamKey] =
        Timer.periodic(_realtimeUpdateInterval, (timer) async {
      if (controller.isClosed) {
        timer.cancel();
        return;
      }

      try {
        final updatedAvailability = await _checkAllPlatformsAvailability(
          movieId: movieId,
          region: region,
          forceRefresh: true,
        );

        if (!controller.isClosed) {
          controller.add(updatedAvailability);
        }

        _analytics.trackEvent(AnalyticsEventType.userEngagement, {
          'event': 'realtime_availability_update',
          'movie_id': movieId,
          'region': region,
          'platforms_available': updatedAvailability.values
              .where((a) => a?.isAvailable == true)
              .length,
        });
      } catch (e) {
        LoggerFactory.error('Error in realtime update for $movieId: $e');
      }
    });
  }

  /// Check availability across all platforms
  Future<Map<StreamingPlatform, PlatformAvailability?>>
      _checkAllPlatformsAvailability({
    required String movieId,
    required String region,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '$movieId-$region';

    // Check cache first (unless force refresh)
    if (!forceRefresh) {
      final cached = await _getCachedAvailability(cacheKey);
      if (cached != null && !cached.isExpired) {
        LoggerFactory.info('Using cached availability for $movieId');
        return cached.availability;
      }
    }

    // Fetch from all platforms concurrently
    final futures = <StreamingPlatform, Future<PlatformAvailability?>>{
      StreamingPlatform.netflix: _netflixService.checkMovieAvailability(
        movieId: movieId,
        tmdbId: movieId,
        region: region,
      ),
      StreamingPlatform.primeVideo: _primeVideoService.checkMovieAvailability(
        movieId: movieId,
        tmdbId: movieId,
        region: region,
      ),
      StreamingPlatform.disneyPlus: _disneyPlusService.checkMovieAvailability(
        movieId: movieId,
        tmdbId: movieId,
        region: region,
      ),
      StreamingPlatform.hboMax: _hboMaxService.checkMovieAvailability(
        movieId: movieId,
        tmdbId: movieId,
        region: region,
      ),
    };

    final results = <StreamingPlatform, PlatformAvailability?>{};

    // Wait for all results with timeout handling
    await Future.wait(
      futures.entries.map((entry) async {
        try {
          final result = await entry.value.timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              LoggerFactory.warning(
                  'Timeout checking ${entry.key.name} for $movieId');
              return null;
            },
          );
          results[entry.key] = result;
        } catch (e) {
          LoggerFactory.error(
              'Error checking ${entry.key.name} for $movieId: $e');
          results[entry.key] = null;
        }
      }),
    );

    // Cache the results
    await _cacheAvailability(cacheKey, results);

    _analytics.trackEvent(AnalyticsEventType.userEngagement, {
      'event': 'availability_check_completed',
      'movie_id': movieId,
      'region': region,
      'platforms_checked': results.length,
      'platforms_available':
          results.values.where((a) => a?.isAvailable == true).length,
      'cache_hit': false,
    });

    return results;
  }

  /// Get cached availability
  Future<CachedAvailability?> _getCachedAvailability(String cacheKey) async {
    // Check memory cache first
    final memoryResult = _memoryCache[cacheKey];
    if (memoryResult != null && !memoryResult.isExpired) {
      return memoryResult;
    }

    // Check persistent cache
    if (_prefs != null) {
      final cachedJson = _prefs!.getString('$_cacheKeyPrefix$cacheKey');
      if (cachedJson != null) {
        try {
          final cachedData = json.decode(cachedJson) as Map<String, dynamic>;
          final cached = CachedAvailability.fromJson(cachedData);

          if (!cached.isExpired) {
            // Update memory cache
            _memoryCache[cacheKey] = cached;
            return cached;
          } else {
            // Remove expired cache
            await _prefs!.remove('$_cacheKeyPrefix$cacheKey');
          }
        } catch (e) {
          LoggerFactory.error('Error parsing cached availability: $e');
          await _prefs!.remove('$_cacheKeyPrefix$cacheKey');
        }
      }
    }

    return null;
  }

  /// Cache availability results
  Future<void> _cacheAvailability(
    String cacheKey,
    Map<StreamingPlatform, PlatformAvailability?> availability,
  ) async {
    final cached = CachedAvailability(
      availability: availability,
      timestamp: DateTime.now(),
    );

    // Update memory cache
    _memoryCache[cacheKey] = cached;

    // Update persistent cache
    if (_prefs != null) {
      try {
        final cachedJson = json.encode(cached.toJson());
        await _prefs!.setString('$_cacheKeyPrefix$cacheKey', cachedJson);
      } catch (e) {
        LoggerFactory.error('Error caching availability: $e');
      }
    }
  }

  /// Get cached availability (non-realtime)
  Future<Map<StreamingPlatform, PlatformAvailability?>> getCachedAvailability({
    required String movieId,
    String region = 'US',
  }) async {
    final cacheKey = '$movieId-$region';
    final cached = await _getCachedAvailability(cacheKey);

    if (cached != null) {
      _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'event': 'availability_cache_hit',
        'movie_id': movieId,
        'region': region,
        'age_minutes': DateTime.now().difference(cached.timestamp).inMinutes,
      });
      return cached.availability;
    }

    return {};
  }

  /// Get availability for a single movie (compatibility method)
  Future<StreamingAvailability?> getAvailability(
    int movieId,
    String movieTitle, {
    String region = 'US',
    bool forceRefresh = false,
  }) async {
    try {
      final availability = await _checkAllPlatformsAvailability(
        movieId: movieId.toString(),
        region: region,
        forceRefresh: forceRefresh,
      );

      return StreamingAvailability(
        movieId: movieId,
        movieTitle: movieTitle,
        region: region,
        platforms:
            availability.values.whereType<PlatformAvailability>().toList(),
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      LoggerFactory.error('Error getting availability for movie $movieId: $e');
      return null;
    }
  }

  /// Stream availability updates for a movie (compatibility method)
  Stream<StreamingAvailability?> streamAvailability(
    int movieId,
    String movieTitle, {
    String region = 'US',
  }) {
    return getRealtimeAvailability(
      movieId: movieId.toString(),
      region: region,
    ).map((availability) => StreamingAvailability(
          movieId: movieId,
          movieTitle: movieTitle,
          region: region,
          platforms:
              availability.values.whereType<PlatformAvailability>().toList(),
          lastUpdated: DateTime.now(),
        ));
  }

  /// Clear all cache (compatibility method)
  Future<void> clearCache() async {
    // Clear memory cache
    _memoryCache.clear();

    // Clear persistent cache
    if (_prefs != null) {
      final keys =
          _prefs!.getKeys().where((key) => key.startsWith(_cacheKeyPrefix));
      for (final key in keys) {
        await _prefs!.remove(key);
      }
    }

    LoggerFactory.info('All availability cache cleared');
  }

  /// Preload availability for multiple movies
  Future<void> preloadAvailability({
    required List<String> movieIds,
    String region = 'US',
  }) async {
    LoggerFactory.info('Preloading availability for ${movieIds.length} movies');

    // Process in batches to avoid overwhelming APIs
    const batchSize = 5;
    for (int i = 0; i < movieIds.length; i += batchSize) {
      final batch = movieIds.skip(i).take(batchSize).toList();

      await Future.wait(
        batch.map((movieId) => _checkAllPlatformsAvailability(
              movieId: movieId,
              region: region,
            )),
      );

      // Small delay between batches
      if (i + batchSize < movieIds.length) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    _analytics.trackEvent(AnalyticsEventType.userEngagement, {
      'event': 'availability_preload_completed',
      'movies_count': movieIds.length,
      'region': region,
    });
  }

  /// Clear expired cache entries
  Future<void> clearExpiredCache() async {
    if (_prefs == null) return;

    final keys =
        _prefs!.getKeys().where((key) => key.startsWith(_cacheKeyPrefix));
    int removedCount = 0;

    for (final key in keys) {
      final cachedJson = _prefs!.getString(key);
      if (cachedJson != null) {
        try {
          final cachedData = json.decode(cachedJson) as Map<String, dynamic>;
          final cached = CachedAvailability.fromJson(cachedData);

          if (cached.isExpired) {
            await _prefs!.remove(key);
            removedCount++;
          }
        } catch (e) {
          // Remove corrupted cache entries
          await _prefs!.remove(key);
          removedCount++;
        }
      }
    }

    // Clear expired memory cache
    _memoryCache.removeWhere((key, cached) => cached.isExpired);

    LoggerFactory.info('Cleared $removedCount expired cache entries');
  }

  /// Clean up stream resources
  void _cleanupStream(String streamKey) {
    _updateTimers[streamKey]?.cancel();
    _updateTimers.remove(streamKey);
    _streamControllers[streamKey]?.close();
    _streamControllers.remove(streamKey);
  }

  /// Dispose all resources
  void dispose() {
    // Cancel all timers
    for (final timer in _updateTimers.values) {
      timer.cancel();
    }
    _updateTimers.clear();

    // Close all stream controllers
    for (final controller in _streamControllers.values) {
      controller.close();
    }
    _streamControllers.clear();

    // Clear memory cache
    _memoryCache.clear();
  }
}

/// Cached availability data with expiration
class CachedAvailability {
  const CachedAvailability({
    required this.availability,
    required this.timestamp,
  });

  factory CachedAvailability.fromJson(Map<String, dynamic> json) {
    final availabilityMap = <StreamingPlatform, PlatformAvailability?>{};
    final availabilityJson = json['availability'] as Map<String, dynamic>;

    for (final entry in availabilityJson.entries) {
      final platform = StreamingUtils.getAllPlatforms().firstWhere(
        (p) => p.name == entry.key,
        orElse: () => StreamingPlatform.netflix,
      );

      final availJson = entry.value as Map<String, dynamic>?;
      availabilityMap[platform] =
          availJson != null ? PlatformAvailability.fromJson(availJson) : null;
    }

    return CachedAvailability(
      availability: availabilityMap,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }
  final Map<StreamingPlatform, PlatformAvailability?> availability;
  final DateTime timestamp;

  bool get isExpired =>
      DateTime.now().difference(timestamp) >
      RealtimeAvailabilityService._cacheExpiration;

  Map<String, dynamic> toJson() {
    return {
      'availability': availability.map((platform, avail) => MapEntry(
            platform.name,
            avail?.toJson(),
          )),
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}
