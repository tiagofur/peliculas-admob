import 'dart:async';

import 'package:http/http.dart' as http;

import '../../../domain/entities/movie.dart';
import '../../../domain/entities/streaming_availability.dart';
import '../../../domain/entities/streaming_platform.dart';
import '../../analytics/analytics_service.dart';
import '../../logging/app_logger.dart';
import 'netflix_service.dart'; // For SubscriptionPlan

/// Disney+ streaming service implementation
class DisneyPlusService {
  DisneyPlusService({
    http.Client? httpClient,
    AnalyticsService? analyticsService,
    AppLogger? logger,
  })  : _httpClient = httpClient ?? http.Client(),
        _analyticsService = analyticsService ?? AnalyticsService(),
        _logger = logger ?? AppLogger.instance;
  static const String _baseUrl = 'https://api.disneyplus.com';
  static const String _deepLinkScheme = 'disneyplus://';

  final http.Client _httpClient;
  final AnalyticsService _analyticsService;
  final AppLogger _logger;

  /// Check if a movie is available on Disney+
  Future<PlatformAvailability?> checkMovieAvailability({
    required String movieId,
    required String tmdbId,
    String region = 'US',
  }) async {
    try {
      _logger.info('Checking Disney+ availability for movie: $movieId');

      final availability = await _simulateDisneyAvailability(
        tmdbId: tmdbId,
        region: region,
      );

      _analyticsService.trackEvent(
        AnalyticsEventType.userEngagement,
        {
          'movie_id': movieId,
          'tmdb_id': tmdbId,
          'region': region,
          'is_available': availability?.isAvailable ?? false,
          'action': 'disney_plus_availability_checked',
        },
      );

      return availability;
    } catch (e) {
      _logger.error('Error checking Disney+ availability: $e');
      _analyticsService.trackEvent(
        AnalyticsEventType.error,
        {
          'movie_id': movieId,
          'error': e.toString(),
          'action': 'disney_plus_availability_error',
        },
      );
      return null;
    }
  }

  /// Search for content on Disney+
  Future<List<Movie>> searchContent({
    required String query,
    String region = 'US',
    int limit = 20,
  }) async {
    try {
      _logger.info('Searching Disney+ content: $query');

      final results = await _simulateDisneySearch(
        query: query,
        region: region,
        limit: limit,
      );

      _analyticsService.trackEvent(
        AnalyticsEventType.userEngagement,
        {
          'query': query,
          'region': region,
          'results_count': results.length,
          'action': 'disney_plus_search_performed',
        },
      );

      return results;
    } catch (e) {
      _logger.error('Error searching Disney+ content: $e');
      _analyticsService.trackEvent(
        AnalyticsEventType.error,
        {
          'query': query,
          'error': e.toString(),
          'action': 'disney_plus_search_error',
        },
      );
      return [];
    }
  }

  /// Get content by Disney brand/collection
  Future<List<Movie>> getContentByBrand({
    required DisneyBrand brand,
    String region = 'US',
    int limit = 20,
  }) async {
    try {
      _logger.info('Getting Disney+ content for brand: ${brand.name}');

      final content = await _simulateDisneyBrandContent(
        brand: brand,
        region: region,
        limit: limit,
      );

      _analyticsService.trackEvent(
        AnalyticsEventType.userEngagement,
        {
          'brand': brand.name,
          'region': region,
          'results_count': content.length,
          'action': 'disney_plus_brand_content_fetched',
        },
      );

      return content;
    } catch (e) {
      _logger.error('Error getting Disney+ brand content: $e');
      return [];
    }
  }

  /// Get family-friendly recommendations
  Future<List<Movie>> getFamilyRecommendations({
    String region = 'US',
    int limit = 20,
    AgeRating? maxRating,
  }) async {
    try {
      _logger.info('Getting Disney+ family recommendations');

      final recommendations = await _simulateDisneyFamilyContent(
        region: region,
        limit: limit,
        maxRating: maxRating,
      );

      _analyticsService.trackEvent(
        AnalyticsEventType.userEngagement,
        {
          'region': region,
          'max_rating': maxRating?.name,
          'results_count': recommendations.length,
          'action': 'disney_plus_family_recommendations_fetched',
        },
      );

      return recommendations;
    } catch (e) {
      _logger.error('Error getting Disney+ family recommendations: $e');
      return [];
    }
  }

  /// Get new releases on Disney+
  Future<List<Movie>> getNewReleases({
    String region = 'US',
    int limit = 20,
    DisneyBrand? brand,
  }) async {
    try {
      _logger.info('Getting Disney+ new releases');

      final newReleases = await _simulateDisneyNewReleases(
        region: region,
        limit: limit,
        brand: brand,
      );

      _analyticsService.trackEvent(
        AnalyticsEventType.userEngagement,
        {
          'region': region,
          'brand': brand?.name,
          'results_count': newReleases.length,
          'action': 'disney_plus_new_releases_fetched',
        },
      );

      return newReleases;
    } catch (e) {
      _logger.error('Error getting Disney+ new releases: $e');
      return [];
    }
  }

  /// Launch Disney+ app with deep link
  String generateDeepLink({
    required String movieId,
    String? tmdbId,
  }) {
    // Disney+ deep link format: disneyplus://content/{content_id}
    final deepLink = '${_deepLinkScheme}content/$movieId';

    _analyticsService.trackEvent(
      AnalyticsEventType.userEngagement,
      {
        'movie_id': movieId,
        'tmdb_id': tmdbId,
        'deep_link': deepLink,
        'action': 'disney_plus_deep_link_generated',
      },
    );

    return deepLink;
  }

  /// Get Disney+ subscription plans
  Future<List<SubscriptionPlan>> getSubscriptionPlans({
    String region = 'US',
  }) async {
    try {
      return [
        const SubscriptionPlan(
          id: 'disney_plus_monthly',
          name: 'Disney+ Monthly',
          price: 7.99,
          currency: 'USD',
          features: [
            'Unlimited streaming',
            'Disney, Pixar, Marvel, Star Wars, National Geographic',
            '4K Ultra HD and HDR',
            'Download on up to 10 devices'
          ],
          quality: '4K Ultra HD',
        ),
        const SubscriptionPlan(
          id: 'disney_plus_annual',
          name: 'Disney+ Annual',
          price: 79.99,
          currency: 'USD',
          features: [
            'Unlimited streaming',
            'Disney, Pixar, Marvel, Star Wars, National Geographic',
            '4K Ultra HD and HDR',
            'Download on up to 10 devices',
            'Save over 15% vs monthly'
          ],
          quality: '4K Ultra HD',
        ),
        const SubscriptionPlan(
          id: 'disney_bundle',
          name: 'Disney Bundle',
          price: 13.99,
          currency: 'USD',
          features: [
            'Disney+, Hulu, ESPN+ included',
            'Best value for families',
            'Live sports and breaking news',
            'Award-winning originals'
          ],
          quality: '4K Ultra HD',
        ),
      ];
    } catch (e) {
      _logger.error('Error getting Disney+ subscription plans: $e');
      return [];
    }
  }

  /// Check parental controls and age rating
  Future<bool> isContentAppropriate({
    required String movieId,
    required AgeRating userMaxRating,
  }) async {
    try {
      // Simulate content rating check
      await Future.delayed(const Duration(milliseconds: 200));

      // Disney+ is generally family-friendly, so most content should be appropriate
      final movieRating = await _getMovieRating(movieId);
      return movieRating.index <= userMaxRating.index;
    } catch (e) {
      _logger.error('Error checking content appropriateness: $e');
      return false;
    }
  }

  // Simulation methods
  Future<PlatformAvailability?> _simulateDisneyAvailability({
    required String tmdbId,
    required String region,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    // Disney+ has a more curated library, so lower availability rate
    final isAvailable =
        int.parse(tmdbId.replaceAll(RegExp(r'[^0-9]'), '')) % 5 == 0;

    if (!isAvailable) return null;

    return PlatformAvailability(
      platform: StreamingPlatform.disneyPlus,
      isAvailable: true,
      isFree: false,
      requiresSubscription: true,
      canRent: false,
      canPurchase: false,
      currency: 'USD',
      quality: '4K Ultra HD',
      deepLink: generateDeepLink(movieId: tmdbId),
      audioLanguages: ['en', 'es', 'fr', 'de', 'it', 'pt'],
      subtitleLanguages: ['en', 'es', 'fr', 'de', 'it', 'pt', 'nl'],
    );
  }

  Future<List<Movie>> _simulateDisneySearch({
    required String query,
    required String region,
    required int limit,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [];
  }

  Future<List<Movie>> _simulateDisneyBrandContent({
    required DisneyBrand brand,
    required String region,
    required int limit,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return [];
  }

  Future<List<Movie>> _simulateDisneyFamilyContent({
    required String region,
    required int limit,
    AgeRating? maxRating,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [];
  }

  Future<List<Movie>> _simulateDisneyNewReleases({
    required String region,
    required int limit,
    DisneyBrand? brand,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [];
  }

  Future<AgeRating> _getMovieRating(String movieId) async {
    // Simulate getting movie rating
    await Future.delayed(const Duration(milliseconds: 100));

    final hash = movieId.hashCode;
    if (hash % 4 == 0) return AgeRating.g;
    if (hash % 4 == 1) return AgeRating.pg;
    if (hash % 4 == 2) return AgeRating.pg13;
    return AgeRating.r;
  }

  void dispose() {
    _httpClient.close();
  }
}

/// Disney+ brand collections
enum DisneyBrand {
  disney,
  pixar,
  marvel,
  starWars,
  nationalGeographic,
  star, // International content
}

extension DisneyBrandExtension on DisneyBrand {
  String get name {
    switch (this) {
      case DisneyBrand.disney:
        return 'Disney';
      case DisneyBrand.pixar:
        return 'Pixar';
      case DisneyBrand.marvel:
        return 'Marvel';
      case DisneyBrand.starWars:
        return 'Star Wars';
      case DisneyBrand.nationalGeographic:
        return 'National Geographic';
      case DisneyBrand.star:
        return 'Star';
    }
  }

  String get displayName {
    switch (this) {
      case DisneyBrand.disney:
        return 'Disney Classics';
      case DisneyBrand.pixar:
        return 'Pixar Animation';
      case DisneyBrand.marvel:
        return 'Marvel Studios';
      case DisneyBrand.starWars:
        return 'Star Wars Saga';
      case DisneyBrand.nationalGeographic:
        return 'National Geographic';
      case DisneyBrand.star:
        return 'Star Originals';
    }
  }
}

/// Age rating system for family-friendly content
enum AgeRating {
  g, // General Audiences
  pg, // Parental Guidance
  pg13, // Parents Strongly Cautioned
  r, // Restricted
}

extension AgeRatingExtension on AgeRating {
  String get displayName {
    switch (this) {
      case AgeRating.g:
        return 'G - General Audiences';
      case AgeRating.pg:
        return 'PG - Parental Guidance';
      case AgeRating.pg13:
        return 'PG-13 - Parents Strongly Cautioned';
      case AgeRating.r:
        return 'R - Restricted';
    }
  }

  String get shortName => name.toUpperCase();

  bool get isFamilyFriendly => this == AgeRating.g || this == AgeRating.pg;
}
