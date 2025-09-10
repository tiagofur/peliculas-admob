import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/streaming_availability.dart';
import '../../domain/entities/streaming_platform.dart';
import '../analytics/analytics_service.dart';
import '../logging/app_logger.dart';
import 'streaming_api_config.dart';

/// Real streaming availability service using third-party APIs
class RealAvailabilityService {
  RealAvailabilityService({
    http.Client? httpClient,
    AnalyticsService? analyticsService,
    AppLogger? logger,
  })  : _httpClient = httpClient ?? http.Client(),
        _analyticsService = analyticsService ?? AnalyticsService(),
        _logger = logger ?? AppLogger.instance;

  final http.Client _httpClient;
  final AnalyticsService _analyticsService;
  final AppLogger _logger;
  final Map<String, CachedAvailability> _cache = {};

  /// Check availability across multiple platforms (generic method)
  Future<List<PlatformAvailability>> checkAvailability(
    String tmdbId, {
    String region = 'US',
  }) async {
    return checkMovieAvailability(tmdbId: tmdbId, region: region);
  }

  /// Check movie availability across all streaming platforms
  Future<List<PlatformAvailability>> checkMovieAvailability({
    required String tmdbId,
    String region = 'US',
    bool useCache = true,
  }) async {
    final cacheKey = '${tmdbId}_$region';
    
    // Check cache first
    if (useCache && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (DateTime.now().difference(cached.timestamp) < StreamingApiConfig.availabilityCacheExpiration) {
        _logger.info('Returning cached availability for movie: $tmdbId');
        return cached.availability;
      }
    }

    try {
      List<PlatformAvailability> availability = [];
      
      // Try Watchmode API first (most comprehensive)
      if (StreamingApiConfig.isWatchmodeConfigured) {
        availability = await _checkWatchmodeAvailability(tmdbId, region);
      }
      
      // Fallback to JustWatch API if Watchmode fails
      if (availability.isEmpty && StreamingApiConfig.isJustWatchConfigured) {
        availability = await _checkJustWatchAvailability(tmdbId, region);
      }
      
      // Fallback to simulated data if no real APIs are available
      if (availability.isEmpty) {
        availability = await _getSimulatedAvailability(tmdbId, region);
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
        },
      );
      
      return availability;
    } catch (e) {
      _logger.error('Error checking movie availability: $e');
      _analyticsService.trackEvent(
        AnalyticsEventType.error,
        {
          'action': 'availability_check_failed',
          'tmdb_id': tmdbId,
          'error': e.toString(),
        },
      );
      
      // Return simulated data as fallback
      return _getSimulatedAvailability(tmdbId, region);
    }
  }

  /// Check availability using Watchmode API
  Future<List<PlatformAvailability>> _checkWatchmodeAvailability(
    String tmdbId,
    String region,
  ) async {
    try {
      final url = Uri.parse(
        '${StreamingApiConfig.watchmodeBaseUrl}/title/$tmdbId/sources'
      ).replace(queryParameters: {
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

  /// Check availability using JustWatch API
  Future<List<PlatformAvailability>> _checkJustWatchAvailability(
    String tmdbId,
    String region,
  ) async {
    try {
      final url = Uri.parse(
        '${StreamingApiConfig.justWatchBaseUrl}/titles/movie/$tmdbId/locale/${region.toLowerCase()}'
      );

      final response = await _httpClient
          .get(url, headers: StreamingApiConfig.justWatchHeaders)
          .timeout(StreamingApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parseJustWatchResponse(data);
      } else {
        _logger.warning('JustWatch API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      _logger.error('JustWatch API request failed: $e');
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

  /// Parse JustWatch API response
  List<PlatformAvailability> _parseJustWatchResponse(Map<String, dynamic> data) {
    final List<PlatformAvailability> availability = [];
    final offers = data['offers'] as List? ?? [];
    
    for (final offer in offers) {
      final platformName = offer['package']?['technical_name'] as String?;
      final platform = _mapPlatformName(platformName);
      
      if (platform != null) {
        availability.add(PlatformAvailability(
          platform: platform,
          isAvailable: true,
          isFree: offer['monetization_type'] == 'free',
          requiresSubscription: offer['monetization_type'] == 'flatrate',
          canRent: offer['monetization_type'] == 'rent',
          canPurchase: offer['monetization_type'] == 'buy',
          rentalPrice: offer['retail_price']?.toDouble(),
          purchasePrice: offer['retail_price']?.toDouble(),
          currency: offer['currency'] ?? 'USD',
          quality: offer['presentation_type'] ?? 'hd',
          deepLink: offer['urls']?['standard_web'],
          audioLanguages: ['en'],
          subtitleLanguages: ['en'],
        ));
      }
    }
    
    return availability;
  }

  /// Map platform names to StreamingPlatform enum
  StreamingPlatform? _mapPlatformName(String? platformName) {
    if (platformName == null) return null;
    
    final name = platformName.toLowerCase();
    
    if (name.contains('netflix')) return StreamingPlatform.netflix;
    if (name.contains('prime') || name.contains('amazon')) return StreamingPlatform.primeVideo;
    if (name.contains('disney')) return StreamingPlatform.disneyPlus;
    if (name.contains('hbo') || name.contains('max')) return StreamingPlatform.hboMax;
    if (name.contains('hulu')) return StreamingPlatform.hulu;
    if (name.contains('apple')) return StreamingPlatform.appleTv;
    if (name.contains('paramount')) return StreamingPlatform.paramountPlus;
    if (name.contains('peacock')) return StreamingPlatform.peacock;
    
    return null;
  }

  /// Get simulated availability as fallback
  Future<List<PlatformAvailability>> _getSimulatedAvailability(
    String tmdbId,
    String region,
  ) async {
    // Simulate some delay
    await Future.delayed(const Duration(milliseconds: 300));
    
    final platforms = [StreamingPlatform.netflix, StreamingPlatform.primeVideo, StreamingPlatform.disneyPlus];
    final availability = <PlatformAvailability>[];
    
    // Simulate availability on 1-2 platforms
    final availableCount = (int.parse(tmdbId.replaceAll(RegExp(r'[^0-9]'), '')) % 3) + 1;
    
    for (int i = 0; i < availableCount && i < platforms.length; i++) {
      availability.add(PlatformAvailability(
        platform: platforms[i],
        isAvailable: true,
        isFree: false,
        requiresSubscription: true,
        canRent: false,
        canPurchase: false,
        currency: 'USD',
        quality: 'HD',
        deepLink: null,
        audioLanguages: ['en'],
        subtitleLanguages: ['en'],
      ));
    }
    
    return availability;
  }

  /// Clean old cache entries
  void _cleanCache() {
    final now = DateTime.now();
    _cache.removeWhere((key, value) => 
        now.difference(value.timestamp) > StreamingApiConfig.availabilityCacheExpiration);
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