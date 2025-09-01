import 'dart:async';

import 'package:http/http.dart' as http;

import '../../domain/entities/movie.dart';
import '../../domain/entities/streaming_availability.dart';
import '../../domain/entities/streaming_platform.dart';
import '../analytics/analytics_service.dart';
import '../cache/cache_service.dart';
import '../logging/logger_factory.dart';

/// Service for checking movie availability across streaming platforms
class AvailabilityChecker {
  AvailabilityChecker({
    AnalyticsService? analyticsService,
    http.Client? httpClient,
    CacheService? cacheService,
  })  : _analyticsService = analyticsService ?? AnalyticsService(),
        _httpClient = httpClient ?? http.Client(),
        _cacheService = cacheService ?? CacheService.instance;
  final AnalyticsService _analyticsService;
  final http.Client _httpClient;
  final CacheService _cacheService;

  // Use LoggerFactory static logger
  static final _logger = LoggerFactory.logger;

  // Cache duration for availability data
  static const Duration _cacheDuration = Duration(hours: 6);

  /// Check availability for a single movie across all platforms
  Future<StreamingAvailability?> checkMovieAvailability({
    required String movieId,
    required String movieTitle,
    String? tmdbId,
    String region = 'US',
    bool useCache = true,
  }) async {
    try {
      _logger.info('Checking availability for movie: $movieTitle ($movieId)');

      // TODO: Implement caching when cache service is available
      // Cache functionality temporarily disabled

      // Check availability across all platforms
      final platforms = [
        StreamingPlatform.netflix,
        StreamingPlatform.amazonPrime,
        StreamingPlatform.disneyPlus,
        StreamingPlatform.hboMax,
        StreamingPlatform.hulu,
        StreamingPlatform.appleTV,
      ];

      final List<PlatformAvailability> availabilities = [];

      for (final platform in platforms) {
        try {
          final availability = await _checkPlatformAvailability(
            platform: platform,
            movieId: movieId,
            movieTitle: movieTitle,
            tmdbId: tmdbId,
            region: region,
          );

          if (availability != null) {
            availabilities.add(availability);
          }
        } catch (e) {
          _logger.warning('Error checking ${platform.name} availability: $e');
          // Continue with other platforms
        }
      }

      final streamingAvailability = StreamingAvailability(
        movieId: int.parse(movieId),
        movieTitle: movieTitle,
        platforms: availabilities,
        lastUpdated: DateTime.now(),
        region: region,
      );

      // TODO: Cache the result when cache service is available
      // Cache functionality temporarily disabled

      _analyticsService.trackEvent(
        AnalyticsEventType.movieView,
        {
          'movie_id': movieId,
          'movie_title': movieTitle,
          'region': region,
          'platforms_found': availabilities.length,
          'available_platforms': availabilities
              .where((a) => a.isAvailable)
              .map((a) => a.platform.id)
              .toList(),
        },
      );

      return streamingAvailability;
    } catch (e) {
      _logger.error('Error checking movie availability: $e');
      _analyticsService.trackEvent(
        AnalyticsEventType.error,
        {
          'movie_id': movieId,
          'error': e.toString(),
        },
      );
      return null;
    }
  }

  /// Check availability for multiple movies
  Future<List<StreamingAvailability>> checkMultipleMoviesAvailability({
    required List<Movie> movies,
    String region = 'US',
    bool useCache = true,
  }) async {
    try {
      _logger.info('Checking availability for ${movies.length} movies');

      final List<StreamingAvailability> results = [];

      // Process movies in batches to avoid overwhelming the APIs
      const batchSize = 5;
      for (int i = 0; i < movies.length; i += batchSize) {
        final batch = movies.skip(i).take(batchSize).toList();

        final batchFutures = batch.map((movie) => checkMovieAvailability(
              movieId: movie.id.toString(),
              movieTitle: movie.title,
              tmdbId: movie.id.toString(),
              region: region,
              useCache: useCache,
            ));

        final batchResults = await Future.wait(batchFutures);
        results.addAll(batchResults.whereType<StreamingAvailability>());

        // Small delay between batches
        if (i + batchSize < movies.length) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      _analyticsService.trackEvent(
        AnalyticsEventType.movieView,
        {
          'movies_count': movies.length,
          'results_count': results.length,
          'region': region,
        },
      );

      return results;
    } catch (e) {
      _logger.error('Error checking multiple movies availability: $e');
      return [];
    }
  }

  /// Check availability on a specific platform
  Future<PlatformAvailability?> _checkPlatformAvailability({
    required StreamingPlatform platform,
    required String movieId,
    required String movieTitle,
    String? tmdbId,
    String region = 'US',
  }) async {
    try {
      // This would typically call the platform's API or a third-party service
      // For now, we'll simulate the availability check

      switch (platform.id) {
        case 'netflix':
          return await _checkNetflixAvailability(
            movieId: movieId,
            movieTitle: movieTitle,
            region: region,
          );

        case 'amazon_prime':
          return await _checkPrimeVideoAvailability(
            movieId: movieId,
            movieTitle: movieTitle,
            region: region,
          );

        case 'disney_plus':
          return await _checkDisneyPlusAvailability(
            movieId: movieId,
            movieTitle: movieTitle,
            region: region,
          );

        case 'hbo_max':
          return await _checkHBOMaxAvailability(
            movieId: movieId,
            movieTitle: movieTitle,
            region: region,
          );

        case 'hulu':
          return await _checkHuluAvailability(
            movieId: movieId,
            movieTitle: movieTitle,
            region: region,
          );

        case 'apple_tv':
          return await _checkAppleTVAvailability(
            movieId: movieId,
            movieTitle: movieTitle,
            region: region,
          );

        default:
          return await _checkGenericPlatformAvailability(
            platform: platform,
            movieId: movieId,
            movieTitle: movieTitle,
            region: region,
          );
      }
    } catch (e) {
      _logger.error('Error checking ${platform.name} availability: $e');
      return null;
    }
  }

  /// Check Netflix availability
  Future<PlatformAvailability?> _checkNetflixAvailability({
    required String movieId,
    required String movieTitle,
    required String region,
  }) async {
    // Simulate Netflix API call
    // In a real implementation, this would call Netflix's API or a service like JustWatch

    return PlatformAvailability(
      platform: StreamingPlatform.netflix,
      isAvailable: _simulateAvailability(),
      isFree: false,
      requiresSubscription: true,
      canRent: false,
      canPurchase: false,
      currency: 'USD',
      quality: '4K',
      deepLink: 'netflix://title/$movieId',
      audioLanguages: ['en', 'es', 'fr'],
      subtitleLanguages: ['en', 'es', 'fr', 'de'],
      metadata: {
        'subscription_price': 15.99,
        'web_link': 'https://www.netflix.com/title/$movieId'
      },
    );
  }

  /// Check Prime Video availability
  Future<PlatformAvailability?> _checkPrimeVideoAvailability({
    required String movieId,
    required String movieTitle,
    required String region,
  }) async {
    final isAvailable = _simulateAvailability();
    final isFree = isAvailable && _simulateAvailability(probability: 0.3);

    return PlatformAvailability(
      platform: StreamingPlatform.amazonPrime,
      isAvailable: isAvailable,
      isFree: isFree,
      requiresSubscription: isFree,
      canRent: !isFree && isAvailable,
      canPurchase: !isFree && isAvailable,
      rentalPrice: !isFree && isAvailable ? 3.99 : null,
      purchasePrice: !isFree && isAvailable ? 14.99 : null,
      currency: 'USD',
      quality: '4K',
      deepLink: 'aiv://aiv/resume?asin=$movieId',
      audioLanguages: ['en', 'es', 'fr'],
      subtitleLanguages: ['en', 'es', 'fr', 'de'],
      metadata: {
        'subscription_price': isFree ? 8.99 : null,
        'web_link': 'https://www.amazon.com/dp/$movieId'
      },
    );
  }

  /// Check Disney+ availability
  Future<PlatformAvailability?> _checkDisneyPlusAvailability({
    required String movieId,
    required String movieTitle,
    required String region,
  }) async {
    return PlatformAvailability(
      platform: StreamingPlatform.disneyPlus,
      isAvailable: _simulateAvailability(probability: 0.4),
      isFree: false,
      requiresSubscription: true,
      canRent: false,
      canPurchase: false,
      currency: 'USD',
      quality: '4K',
      deepLink: 'disneyplus://content/$movieId',
      audioLanguages: ['en', 'es', 'fr'],
      subtitleLanguages: ['en', 'es', 'fr', 'de'],
      metadata: {
        'subscription_price': 7.99,
        'web_link': 'https://www.disneyplus.com/movies/$movieId'
      },
    );
  }

  /// Check HBO Max availability
  Future<PlatformAvailability?> _checkHBOMaxAvailability({
    required String movieId,
    required String movieTitle,
    required String region,
  }) async {
    return PlatformAvailability(
      platform: StreamingPlatform.hboMax,
      isAvailable: _simulateAvailability(probability: 0.3),
      isFree: false,
      requiresSubscription: true,
      canRent: false,
      canPurchase: false,
      currency: 'USD',
      quality: '4K',
      deepLink: 'hbomax://content/$movieId',
      audioLanguages: ['en', 'es'],
      subtitleLanguages: ['en', 'es', 'fr'],
      metadata: {
        'subscription_price': 14.99,
        'web_link': 'https://www.hbomax.com/feature/$movieId'
      },
    );
  }

  /// Check Hulu availability
  Future<PlatformAvailability?> _checkHuluAvailability({
    required String movieId,
    required String movieTitle,
    required String region,
  }) async {
    return PlatformAvailability(
      platform: StreamingPlatform.hulu,
      isAvailable: _simulateAvailability(probability: 0.35),
      isFree: false,
      requiresSubscription: true,
      canRent: false,
      canPurchase: false,
      currency: 'USD',
      quality: 'HD',
      deepLink: 'hulu://watch/$movieId',
      audioLanguages: ['en', 'es'],
      subtitleLanguages: ['en', 'es'],
      metadata: {
        'subscription_price': 7.99,
        'web_link': 'https://www.hulu.com/watch/$movieId'
      },
    );
  }

  /// Check Apple TV+ availability
  Future<PlatformAvailability?> _checkAppleTVAvailability({
    required String movieId,
    required String movieTitle,
    required String region,
  }) async {
    final isAvailable = _simulateAvailability(probability: 0.25);
    final isFree = isAvailable && _simulateAvailability(probability: 0.2);

    return PlatformAvailability(
      platform: StreamingPlatform.appleTV,
      isAvailable: isAvailable,
      isFree: isFree,
      requiresSubscription: isFree,
      canRent: !isFree && isAvailable,
      canPurchase: !isFree && isAvailable,
      rentalPrice: !isFree && isAvailable ? 4.99 : null,
      purchasePrice: !isFree && isAvailable ? 19.99 : null,
      currency: 'USD',
      quality: '4K',
      deepLink: 'videos://movie/$movieId',
      audioLanguages: ['en', 'es', 'fr'],
      subtitleLanguages: ['en', 'es', 'fr', 'de'],
      metadata: {
        'subscription_price': isFree ? 6.99 : null,
        'web_link': 'https://tv.apple.com/movie/$movieId'
      },
    );
  }

  /// Check generic platform availability
  Future<PlatformAvailability?> _checkGenericPlatformAvailability({
    required StreamingPlatform platform,
    required String movieId,
    required String movieTitle,
    required String region,
  }) async {
    return PlatformAvailability(
      platform: platform,
      isAvailable: _simulateAvailability(probability: 0.3),
      isFree: false,
      requiresSubscription: platform.requiresSubscription,
      canRent: false,
      canPurchase: false,
      deepLink: '${platform.deepLinkScheme}content/$movieId',
      audioLanguages: ['en'],
      subtitleLanguages: ['en'],
      metadata: {'web_link': '${platform.baseUrl}/movie/$movieId'},
    );
  }

  /// Simulate availability for demo purposes
  bool _simulateAvailability({double probability = 0.4}) {
    return DateTime.now().millisecondsSinceEpoch % 100 < (probability * 100);
  }

  /// Clear availability cache
  Future<void> clearCache() async {
    try {
      await _cacheService.clear();
      _logger.info('Availability cache cleared');
    } catch (e) {
      _logger.error('Error clearing availability cache: $e');
    }
  }

  /// Get cached availability
  Future<StreamingAvailability?> getCachedAvailability({
    required String movieId,
    String region = 'US',
  }) async {
    try {
      final cacheKey = 'availability_${movieId}_$region';
      final cached = await _cacheService.get<Map<String, dynamic>>(cacheKey);

      if (cached != null) {
        return StreamingAvailability.fromJson(cached);
      }

      return null;
    } catch (e) {
      _logger.error('Error getting cached availability: $e');
      return null;
    }
  }

  /// Refresh availability for a movie
  Future<StreamingAvailability?> refreshAvailability({
    required String movieId,
    required String movieTitle,
    String? tmdbId,
    String region = 'US',
  }) async {
    // Clear cache for this movie
    final cacheKey = 'availability_${movieId}_$region';
    await _cacheService.remove(cacheKey);

    // Check availability again
    return await checkMovieAvailability(
      movieId: movieId,
      movieTitle: movieTitle,
      tmdbId: tmdbId,
      region: region,
      useCache: false,
    );
  }
}
