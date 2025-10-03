import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

import '../../config/constants/environment.dart';
import '../../domain/entities/streaming_availability.dart';
import '../../domain/entities/streaming_platform.dart';
import '../analytics/analytics_service.dart';
import '../logging/app_logger.dart';
import '../logging/logger_factory.dart';
import 'streaming_api_config.dart';

/// Real streaming availability service using TMDB Watch Providers API and third-party APIs
///
/// Primary source: TMDB Watch Providers (free, official, comprehensive)
/// Fallback: Watchmode API (optional, requires API key)
class RealAvailabilityService {
  RealAvailabilityService({
    http.Client? httpClient,
    AnalyticsService? analyticsService,
    AppLogger? logger,
  })  : _httpClient = httpClient ?? http.Client(),
        _analyticsService = analyticsService ?? AnalyticsService(),
        _logger = logger ?? AppLogger.instance {
    // Initialize Dio for TMDB API calls
    _dio = Dio(BaseOptions(
      baseUrl: 'https://api.themoviedb.org/3',
      queryParameters: {
        'api_key': Environment.theMovieDbKey,
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));
  }

  final http.Client _httpClient;
  final AnalyticsService _analyticsService;
  final AppLogger _logger;
  late final Dio _dio;
  final Map<String, CachedAvailability> _cache = {};

  /// Check availability across multiple platforms (generic method)
  Future<List<PlatformAvailability>> checkAvailability(
    String tmdbId, {
    String region = 'US',
  }) async {
    return checkMovieAvailability(tmdbId: tmdbId, region: region);
  }

  /// Check movie availability across all streaming platforms
  ///
  /// Uses TMDB Watch Providers API as primary source (free, official)
  /// Falls back to Watchmode API if configured
  /// Returns simulated data if all APIs fail (for testing)
  Future<List<PlatformAvailability>> checkMovieAvailability({
    required String tmdbId,
    String region = 'US',
    bool useCache = true,
  }) async {
    final cacheKey = '${tmdbId}_$region';

    // Check cache first
    if (useCache && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (DateTime.now().difference(cached.timestamp) <
          StreamingApiConfig.availabilityCacheExpiration) {
        LoggerFactory.info('Returning cached availability for movie: $tmdbId');
        return cached.availability;
      }
    }

    try {
      List<PlatformAvailability> availability = [];

      // Primary: Use TMDB Watch Providers API (free, official)
      availability = await _checkTmdbWatchProviders(tmdbId, region);

      // Fallback to Watchmode API if TMDB returns no results and Watchmode is configured
      if (availability.isEmpty && StreamingApiConfig.isWatchmodeConfigured) {
        LoggerFactory.info(
            'TMDB returned no providers, trying Watchmode API...');
        availability = await _checkWatchmodeAvailability(tmdbId, region);
      }

      // Fallback to simulated data only in development mode
      if (availability.isEmpty) {
        LoggerFactory.warning(
            'No streaming providers found for movie: $tmdbId in region: $region');
        // Don't return simulated data - return empty list instead
        // availability = await _getSimulatedAvailability(tmdbId, region);
      }

      // Cache the results
      _cache[cacheKey] = CachedAvailability(
        availability: availability,
        timestamp: DateTime.now(),
      );

      // Clean cache if it gets too large
      if (_cache.length > StreamingApiConfig.maxCacheSize) {
        _cleanCache();
      }

      _analyticsService.trackEvent(
        AnalyticsEventType.userEngagement,
        {
          'action': 'availability_checked',
          'tmdb_id': tmdbId,
          'region': region,
          'platforms_found': availability.length,
          'cache_used': false,
          'source': 'tmdb_watch_providers',
        },
      );

      return availability;
    } catch (e, stackTrace) {
      LoggerFactory.error('Error checking movie availability: $e',
          stackTrace: stackTrace);
      _analyticsService.trackEvent(
        AnalyticsEventType.error,
        {
          'action': 'availability_check_failed',
          'tmdb_id': tmdbId,
          'error': e.toString(),
        },
      );

      // Return empty list on error instead of simulated data
      return [];
    }
  }

  /// Check availability using TMDB Watch Providers API
  ///
  /// This is the primary source - free, official, and comprehensive
  /// API endpoint: /movie/{movie_id}/watch/providers
  ///
  /// Returns availability for multiple regions with:
  /// - Streaming (flatrate)
  /// - Rental (rent)
  /// - Purchase (buy)
  /// - Free viewing (free)
  Future<List<PlatformAvailability>> _checkTmdbWatchProviders(
    String tmdbId,
    String region,
  ) async {
    try {
      LoggerFactory.info(
          'Fetching TMDB watch providers for movie: $tmdbId, region: $region');

      final response = await _dio.get('/movie/$tmdbId/watch/providers');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return _parseTmdbWatchProvidersResponse(data, region);
      } else {
        LoggerFactory.warning(
            'TMDB Watch Providers API error: ${response.statusCode}');
        return [];
      }
    } on DioException catch (e) {
      LoggerFactory.error(
          'TMDB Watch Providers API request failed: ${e.message}');
      return [];
    } catch (e, stackTrace) {
      LoggerFactory.error('Unexpected error in TMDB Watch Providers: $e',
          stackTrace: stackTrace);
      return [];
    }
  }

  /// Parse TMDB Watch Providers API response
  ///
  /// Response format:
  /// {
  ///   "results": {
  ///     "US": {
  ///       "flatrate": [{"provider_id": 8, "provider_name": "Netflix", ...}],
  ///       "rent": [...],
  ///       "buy": [...],
  ///       "free": [...]
  ///     }
  ///   }
  /// }
  List<PlatformAvailability> _parseTmdbWatchProvidersResponse(
    Map<String, dynamic> data,
    String region,
  ) {
    final List<PlatformAvailability> availability = [];

    try {
      final results = data['results'] as Map<String, dynamic>?;
      if (results == null) return [];

      final regionData = results[region] as Map<String, dynamic>?;
      if (regionData == null) {
        LoggerFactory.info('No watch providers found for region: $region');
        return [];
      }

      // Process streaming (flatrate) providers
      final flatrate = regionData['flatrate'] as List?;
      if (flatrate != null) {
        for (final provider in flatrate) {
          final platformAvailability = _parseTmdbProvider(
            provider as Map<String, dynamic>,
            isFree: false,
            requiresSubscription: true,
          );
          if (platformAvailability != null) {
            availability.add(platformAvailability);
          }
        }
      }

      // Process free providers
      final free = regionData['free'] as List?;
      if (free != null) {
        for (final provider in free) {
          final platformAvailability = _parseTmdbProvider(
            provider as Map<String, dynamic>,
            isFree: true,
            requiresSubscription: false,
          );
          if (platformAvailability != null) {
            availability.add(platformAvailability);
          }
        }
      }

      // Process rental providers
      final rent = regionData['rent'] as List?;
      if (rent != null) {
        for (final provider in rent) {
          final platformAvailability = _parseTmdbProvider(
            provider as Map<String, dynamic>,
            canRent: true,
          );
          if (platformAvailability != null) {
            availability.add(platformAvailability);
          }
        }
      }

      // Process purchase providers
      final buy = regionData['buy'] as List?;
      if (buy != null) {
        for (final provider in buy) {
          final platformAvailability = _parseTmdbProvider(
            provider as Map<String, dynamic>,
            canPurchase: true,
          );
          if (platformAvailability != null) {
            availability.add(platformAvailability);
          }
        }
      }

      LoggerFactory.info(
          'Parsed ${availability.length} providers from TMDB for region $region');
    } catch (e, stackTrace) {
      LoggerFactory.error('Error parsing TMDB watch providers response: $e',
          stackTrace: stackTrace);
    }

    return availability;
  }

  /// Parse individual TMDB provider into PlatformAvailability
  PlatformAvailability? _parseTmdbProvider(
    Map<String, dynamic> provider, {
    bool isFree = false,
    bool requiresSubscription = false,
    bool canRent = false,
    bool canPurchase = false,
  }) {
    try {
      final providerId = provider['provider_id'] as int?;
      final providerName = provider['provider_name'] as String?;
      final logoPath = provider['logo_path'] as String?;

      if (providerId == null || providerName == null) return null;

      final platform = _mapTmdbProviderId(providerId, providerName);
      if (platform == null) {
        LoggerFactory.debug(
            'Unknown TMDB provider: $providerName (ID: $providerId)');
        return null;
      }

      return PlatformAvailability(
        platform: platform,
        isAvailable: true,
        isFree: isFree,
        requiresSubscription: requiresSubscription,
        canRent: canRent,
        canPurchase: canPurchase,
        rentalPrice: null, // TMDB doesn't provide pricing details
        purchasePrice: null,
        currency: 'USD',
        quality: 'HD', // Default quality
        deepLink: logoPath != null
            ? 'https://image.tmdb.org/t/p/original$logoPath'
            : null,
        audioLanguages: ['en'],
        subtitleLanguages: ['en'],
      );
    } catch (e) {
      LoggerFactory.error('Error parsing TMDB provider: $e');
      return null;
    }
  }

  /// Map TMDB provider ID to StreamingPlatform
  ///
  /// Reference: https://api.themoviedb.org/3/watch/providers/movie
  StreamingPlatform? _mapTmdbProviderId(int providerId, String providerName) {
    switch (providerId) {
      case 8:
        return StreamingPlatform.netflix;
      case 9:
      case 119: // Prime Video (alternate ID)
        return StreamingPlatform.primeVideo;
      case 337:
        return StreamingPlatform.disneyPlus;
      case 384:
      case 425: // HBO Max (alternate ID)
        return StreamingPlatform.hboMax;
      case 15:
        return StreamingPlatform.hulu;
      case 350:
        return StreamingPlatform.appleTV;
      case 531:
        return StreamingPlatform.paramountPlus;
      case 387:
        return StreamingPlatform.peacock;
      // Note: TMDB has more providers, but we only map those defined in StreamingPlatform
      default:
        // Log unknown providers for future mapping
        LoggerFactory.debug(
            'Unmapped TMDB provider: $providerName (ID: $providerId)');
        return null;
    }
  }

  /// Check availability using Watchmode API (fallback)
  Future<List<PlatformAvailability>> _checkWatchmodeAvailability(
    String tmdbId,
    String region,
  ) async {
    try {
      final url = Uri.parse(
              '${StreamingApiConfig.watchmodeBaseUrl}/title/$tmdbId/sources')
          .replace(queryParameters: {
        'regions': region,
        'source_types': 'sub,free,rent,buy',
      });

      final response = await _httpClient
          .get(url, headers: StreamingApiConfig.watchmodeHeaders)
          .timeout(StreamingApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        return _parseWatchmodeResponse(data);
      } else {
        _logger.warning('Watchmode API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      _logger.error('Watchmode API request failed: $e');
      return [];
    }
  }

  /// Parse Watchmode API response
  List<PlatformAvailability> _parseWatchmodeResponse(List data) {
    final List<PlatformAvailability> availability = [];

    for (final source in data) {
      final platformName = source['name'] as String?;
      final platform = _mapPlatformName(platformName);

      if (platform != null) {
        availability.add(PlatformAvailability(
          platform: platform,
          isAvailable: true,
          isFree: source['type'] == 'free',
          requiresSubscription: source['type'] == 'sub',
          canRent: source['type'] == 'rent',
          canPurchase: source['type'] == 'buy',
          rentalPrice: source['price']?.toDouble(),
          purchasePrice: source['price']?.toDouble(),
          currency: 'USD',
          quality: source['format'] ?? 'HD',
          deepLink: source['web_url'],
          audioLanguages: ['en'],
          subtitleLanguages: ['en'],
        ));
      }
    }

    return availability;
  }

  /// Map platform names to StreamingPlatform (used by Watchmode fallback)
  StreamingPlatform? _mapPlatformName(String? platformName) {
    if (platformName == null) return null;

    final name = platformName.toLowerCase();

    if (name.contains('netflix')) return StreamingPlatform.netflix;
    if (name.contains('prime') || name.contains('amazon')) {
      return StreamingPlatform.primeVideo;
    }
    if (name.contains('disney')) return StreamingPlatform.disneyPlus;
    if (name.contains('hbo') || name.contains('max')) {
      return StreamingPlatform.hboMax;
    }
    if (name.contains('hulu')) return StreamingPlatform.hulu;
    if (name.contains('apple')) return StreamingPlatform.appleTv;
    if (name.contains('paramount')) return StreamingPlatform.paramountPlus;
    if (name.contains('peacock')) return StreamingPlatform.peacock;

    return null;
  }

  /// Clean old cache entries
  void _cleanCache() {
    final now = DateTime.now();
    _cache.removeWhere((key, value) =>
        now.difference(value.timestamp) >
        StreamingApiConfig.availabilityCacheExpiration);
  }

  /// Clear all cache
  void clearCache() {
    _cache.clear();
  }

  void dispose() {
    _httpClient.close();
  }
}

/// Cached availability data
class CachedAvailability {
  const CachedAvailability({
    required this.availability,
    required this.timestamp,
  });

  final List<PlatformAvailability> availability;
  final DateTime timestamp;
}
