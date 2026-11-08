import 'dart:async';
import 'dart:convert';

import '../../domain/entities/movie.dart';
import '../../domain/entities/streaming_availability.dart';
import '../../domain/entities/streaming_platform.dart';
import '../../domain/entities/watch_providers.dart';
import '../../infrastructure/repositories/tmdb_watch_providers_repository.dart';
import '../analytics/analytics_service.dart';
import '../cache/cache_service.dart';
import '../logging/logger_factory.dart';
import 'tmdb_provider_mapper.dart';

/// Service for checking movie availability across streaming platforms
class AvailabilityChecker {
  AvailabilityChecker({
    AnalyticsService? analyticsService,
    CacheService? cacheService,
    TmdbWatchProvidersRepository? tmdbRepository,
  }) : _analyticsService = analyticsService ?? AnalyticsService(),
       _cacheService = cacheService ?? CacheService.instance,
       _tmdbRepository =
           tmdbRepository ??
           TmdbWatchProvidersRepository(
             cacheService: cacheService ?? CacheService.instance,
           );
  final AnalyticsService _analyticsService;
  final CacheService _cacheService;
  final TmdbWatchProvidersRepository _tmdbRepository;

  // Cache duration for availability data
  static const Duration _cacheDuration = Duration(hours: 6);

  /// Check availability for a movie (compatibility method)
  Future<StreamingAvailability?> checkAvailability(
    int movieId,
    String movieTitle, {
    String region = 'US',
    bool useCache = true,
  }) async {
    return checkMovieAvailability(
      movieId: movieId.toString(),
      movieTitle: movieTitle,
      region: region,
      useCache: useCache,
    );
  }

  /// Check availability for a single movie across all platforms
  Future<StreamingAvailability?> checkMovieAvailability({
    required String movieId,
    required String movieTitle,
    String? tmdbId,
    String region = 'US',
    bool useCache = true,
  }) async {
    final cacheKey = 'availability_${movieId}_$region';

    if (useCache) {
      try {
        final cachedData = await _cacheService.get<String>(cacheKey);
        if (cachedData != null) {
          LoggerFactory.info('Cache hit for movie: $movieTitle ($movieId)');
          return StreamingAvailability.fromJson(jsonDecode(cachedData));
        }
      } catch (e) {
        LoggerFactory.warning('Error reading from cache: $e');
      }
    }

    try {
      LoggerFactory.info(
        'Checking availability for movie: $movieTitle ($movieId)',
      );

      // Get real TMDB Watch Providers data instead of mock data
      LoggerFactory.info(
        'Fetching real TMDB watch providers data for movie $movieId',
      );

      final List<PlatformAvailability> availabilities = [];

      try {
        final watchProviders = await _tmdbRepository.getWatchProviders(
          int.parse(movieId),
          region: region,
        );

        if (watchProviders != null) {
          // Convert TMDB WatchProviders to PlatformAvailability objects
          availabilities.addAll(
            await _convertWatchProvidersToPlatformAvailability(watchProviders),
          );

          LoggerFactory.info(
            'Successfully fetched ${availabilities.length} platform availabilities from TMDB',
          );
        } else {
          LoggerFactory.info(
            'No watch providers found for movie $movieId in region $region',
          );
        }
      } catch (e) {
        LoggerFactory.error('Error fetching TMDB watch providers: $e');
        // TMDB is the only source: on error keep whatever was fetched
        // (possibly empty) instead of showing invented platforms.
      }

      final streamingAvailability = StreamingAvailability(
        movieId: int.parse(movieId),
        movieTitle: movieTitle,
        platforms: availabilities,
        lastUpdated: DateTime.now(),
        region: region,
      );

      // Cache the result
      try {
        await _cacheService.set(
          cacheKey,
          jsonEncode(streamingAvailability.toJson()),
          expiration: _cacheDuration,
        );
        LoggerFactory.info(
          'Cached availability for movie: $movieTitle ($movieId)',
        );
      } catch (e) {
        LoggerFactory.warning('Error writing to cache: $e');
      }

      _analyticsService.trackEvent(AnalyticsEventType.movieView, {
        'movie_id': movieId,
        'movie_title': movieTitle,
        'region': region,
        'platforms_found': availabilities.length,
        'available_platforms': availabilities
            .where((a) => a.isAvailable)
            .map((a) => a.platform.id)
            .toList(),
      });

      return streamingAvailability;
    } catch (e) {
      LoggerFactory.error('Error checking movie availability: $e');
      _analyticsService.trackEvent(AnalyticsEventType.error, {
        'movie_id': movieId,
        'error': e.toString(),
      });
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
      LoggerFactory.info('Checking availability for ${movies.length} movies');

      final List<StreamingAvailability> results = [];

      // Process movies in batches to avoid overwhelming the APIs
      const batchSize = 5;
      for (int i = 0; i < movies.length; i += batchSize) {
        final batch = movies.skip(i).take(batchSize).toList();

        final batchFutures = batch.map(
          (movie) => checkMovieAvailability(
            movieId: movie.id.toString(),
            movieTitle: movie.title,
            tmdbId: movie.id.toString(),
            region: region,
            useCache: useCache,
          ),
        );

        final batchResults = await Future.wait(batchFutures);
        results.addAll(batchResults.whereType<StreamingAvailability>());

        // Small delay between batches
        if (i + batchSize < movies.length) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      _analyticsService.trackEvent(AnalyticsEventType.movieView, {
        'movies_count': movies.length,
        'results_count': results.length,
        'region': region,
      });

      return results;
    } catch (e) {
      LoggerFactory.error('Error checking multiple movies availability: $e');
      return [];
    }
  }

  /// Convert TMDB WatchProviders to PlatformAvailability objects
  Future<List<PlatformAvailability>>
  _convertWatchProvidersToPlatformAvailability(
    WatchProviders watchProviders,
  ) async {
    final List<PlatformAvailability> availabilities = [];

    // Process streaming (flatrate) providers - included in subscription
    for (final provider in watchProviders.flatrate) {
      final platform = _mapProviderToPlatform(
        provider.providerId,
        provider.providerName,
      );
      if (platform != null) {
        availabilities.add(
          PlatformAvailability(
            platform: platform,
            isAvailable: true,
            isFree: false,
            requiresSubscription: true,
            canRent: false,
            canPurchase: false,
            quality: 'HD', // TMDB doesn't provide quality info
            deepLink: _buildPlatformDeepLink(
              platform,
              provider.providerId.toString(),
            ),
            audioLanguages: ['en', 'es'],
            subtitleLanguages: ['en', 'es'],
            metadata: {
              'provider_id': provider.providerId,
              'provider_name': provider.providerName,
              'logo_path': provider.logoPath,
              'display_priority': provider.displayPriority,
              'type': 'subscription',
            },
          ),
        );
      }
    }

    // Process rental providers
    for (final provider in watchProviders.rent) {
      final platform = _mapProviderToPlatform(
        provider.providerId,
        provider.providerName,
      );
      if (platform != null) {
        availabilities.add(
          PlatformAvailability(
            platform: platform,
            isAvailable: true,
            isFree: false,
            requiresSubscription: false,
            canRent: true,
            canPurchase: false,
            rentalPrice: 3.99, // TMDB doesn't provide pricing, use default
            currency: 'USD',
            quality: 'HD',
            deepLink: _buildPlatformDeepLink(
              platform,
              provider.providerId.toString(),
            ),
            audioLanguages: ['en', 'es'],
            subtitleLanguages: ['en', 'es'],
            metadata: {
              'provider_id': provider.providerId,
              'provider_name': provider.providerName,
              'logo_path': provider.logoPath,
              'display_priority': provider.displayPriority,
              'type': 'rent',
            },
          ),
        );
      }
    }

    // Process purchase providers
    for (final provider in watchProviders.buy) {
      final platform = _mapProviderToPlatform(
        provider.providerId,
        provider.providerName,
      );
      if (platform != null) {
        availabilities.add(
          PlatformAvailability(
            platform: platform,
            isAvailable: true,
            isFree: false,
            requiresSubscription: false,
            canRent: false,
            canPurchase: true,
            purchasePrice: 12.99, // TMDB doesn't provide pricing, use default
            currency: 'USD',
            quality: 'HD',
            deepLink: _buildPlatformDeepLink(
              platform,
              provider.providerId.toString(),
            ),
            audioLanguages: ['en', 'es'],
            subtitleLanguages: ['en', 'es'],
            metadata: {
              'provider_id': provider.providerId,
              'provider_name': provider.providerName,
              'logo_path': provider.logoPath,
              'display_priority': provider.displayPriority,
              'type': 'buy',
            },
          ),
        );
      }
    }

    return availabilities;
  }

  /// Map TMDB provider ID to StreamingPlatform.
  ///
  /// Single source of truth lives in [TmdbProviderMapper]: unknown IDs
  /// resolve to null and are skipped, never replaced with generic
  /// platforms pointing at placeholder URLs.
  StreamingPlatform? _mapProviderToPlatform(
    int providerId,
    String providerName,
  ) {
    return TmdbProviderMapper.mapProvider(providerId, providerName);
  }

  /// Build deep link for platform
  String _buildPlatformDeepLink(StreamingPlatform platform, String providerId) {
    switch (platform.id) {
      case 'netflix':
        return 'netflix://title/$providerId';
      case 'amazon_prime':
        return 'aiv://aiv/resume?asin=$providerId';
      case 'disney_plus':
        return 'disneyplus://content/$providerId';
      case 'hbo_max':
        return 'hbomax://content/$providerId';
      case 'hulu':
        return 'hulu://watch/$providerId';
      case 'apple_tv':
        return 'videos://movie/$providerId';
      default:
        // No invented deep-link scheme: fall back to the platform website.
        return platform.websiteUrl;
    }
  }

  /// Clear availability cache
  Future<void> clearCache() async {
    try {
      await _cacheService.clear();
      LoggerFactory.info('Availability cache cleared');
    } catch (e) {
      LoggerFactory.error('Error clearing availability cache: $e');
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
      LoggerFactory.error('Error getting cached availability: $e');
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
