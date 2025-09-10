import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../domain/entities/movie.dart';
import '../../../domain/entities/streaming_availability.dart';
import '../../../domain/entities/streaming_platform.dart';
import '../streaming_api_config.dart';
import '../real_availability_service.dart';
import 'platform_services.dart';
import '../../analytics/analytics_service.dart';


/// Disney+ streaming service implementation
class DisneyPlusService implements StreamingPlatformServiceInterface {
  DisneyPlusService({
    required http.Client httpClient,
    required AnalyticsService analytics,
    required RealAvailabilityService availabilityService,
  })  : _httpClient = httpClient,
        _analytics = analytics,
        _availabilityService = availabilityService;
  final String _baseUrl = StreamingApiConfig.disneyPlusBaseUrl;
  static const String _deepLinkScheme = 'disneyplus://';

  final http.Client _httpClient;
  final AnalyticsService _analytics;
  final RealAvailabilityService _availabilityService;

  @override
  Future<PlatformAvailability?> checkMovieAvailability({
    required String movieId,
    required String tmdbId,
    String region = 'US',
  }) async {
    try {
      _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'action': 'disney_availability_check',
        'movie_id': movieId,
        'region': region,
        'api_used': StreamingApiConfig.isDisneyPlusConfigured ? 'real' : 'simulated',
      });

      // Try real availability service first
      final availabilityList = await _availabilityService.checkAvailability(
        movieId,
        region: region,
      );

      if (availabilityList.isNotEmpty) {
        return availabilityList.first;
      }

      // If Disney+ API is configured, try direct API call
      if (StreamingApiConfig.isDisneyPlusConfigured) {
        final directAvailability = await _checkDirectDisneyAvailability(
          tmdbId: movieId,
          region: region,
        );
        
        if (directAvailability != null) {
          return directAvailability;
        }
      }

      // Fallback to simulation
      return await _simulateDisneyAvailability(
        tmdbId: movieId,
        region: region,
      );
    } catch (e) {
      // Error checking Disney+ availability: $e
      return null;
    }
  }

  @override
  Future<List<Movie>> searchContent({
    required String query,
    String region = 'US',
    int limit = 20,
  }) async {
    try {
      _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'query': query,
        'region': region,
        'limit': limit,
        'api_used': StreamingApiConfig.isDisneyPlusConfigured ? 'real' : 'simulated',
      });

      // If Disney+ API is configured, use real API
      if (StreamingApiConfig.isDisneyPlusConfigured) {
        final realResults = await _searchDisneyContent(
          query: query,
          region: region,
          limit: limit,
        );
        
        if (realResults.isNotEmpty) {
          return realResults;
        }
      }

      // Fallback to simulation
      return await _simulateDisneySearch(
        query: query,
        region: region,
        limit: limit,
      );
    } catch (e) {
      // Error searching Disney+ content: $e
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
      // Getting Disney+ content for brand: ${brand.name}

      final content = await _simulateDisneyBrandContent(
        brand: brand,
        region: region,
        limit: limit,
      );

      _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'brand': brand.name,
        'region': region,
        'results_count': content.length,
        'action': 'disney_plus_brand_content_fetched',
      });

      return content;
    } catch (e) {
      // Error getting Disney+ brand content: $e
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
      // Getting Disney+ family recommendations

      final recommendations = await _simulateDisneyFamilyContent(
        region: region,
        limit: limit,
        maxRating: maxRating,
      );

      _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'region': region,
        'max_rating': maxRating?.name,
        'results_count': recommendations.length,
        'action': 'disney_plus_family_recommendations_fetched',
      });

      return recommendations;
    } catch (e) {
      // Error getting Disney+ family recommendations: $e
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
      // Getting Disney+ new releases

      final newReleases = await _simulateDisneyNewReleases(
        region: region,
        limit: limit,
        brand: brand,
      );

      _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'region': region,
        'brand': brand?.name,
        'results_count': newReleases.length,
        'action': 'disney_plus_new_releases_fetched',
      });

      return newReleases;
    } catch (e) {
      // Error getting Disney+ new releases: $e
      return [];
    }
  }

  /// Launch Disney+ app with deep link
  @override
  String generateDeepLink({
    required String movieId,
    String? tmdbId,
  }) {
    // Disney+ deep link format: disneyplus://content/{content_id}
    final deepLink = '${_deepLinkScheme}content/$movieId';

    _analytics.trackEvent(AnalyticsEventType.userEngagement, {
      'movie_id': movieId,
      'tmdb_id': tmdbId,
      'deep_link': deepLink,
      'action': 'disney_plus_deep_link_generated',
    });

    return deepLink;
  }

  /// Get Disney+ subscription plans
  @override
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
      // Error getting Disney+ subscription plans: $e
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
      // Error checking content appropriateness: $e
      return false;
    }
  }

  // Real API methods
  /// Check availability directly with Disney+ API
  Future<PlatformAvailability?> _checkDirectDisneyAvailability({
    required String tmdbId,
    required String region,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/content/$tmdbId/availability')
          .replace(queryParameters: {
        'region': region,
        'include_details': 'true',
      });

      final response = await _httpClient
          .get(url, headers: StreamingApiConfig.disneyPlusHeaders)
          .timeout(StreamingApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parseDisneyAvailability(data, tmdbId);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        // Disney+ API error: ${response.statusCode}
        return null;
      }
    } catch (e) {
      // Disney+ direct API call failed: $e
      return null;
    }
  }

  /// Search Disney+ content using real API
  Future<List<Movie>> _searchDisneyContent({
    required String query,
    required String region,
    required int limit,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/search')
          .replace(queryParameters: {
        'q': query,
        'region': region,
        'limit': limit.toString(),
        'content_type': 'movie',
      });

      final response = await _httpClient
          .get(url, headers: StreamingApiConfig.disneyPlusHeaders)
          .timeout(StreamingApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parseDisneyMovies(data['results'] as List? ?? []);
      } else {
        // Disney+ search API error: ${response.statusCode}
        return [];
      }
    } catch (e) {
      // Disney+ search API call failed: $e
      return [];
    }
  }



  /// Parse Disney+ availability response
  PlatformAvailability _parseDisneyAvailability(Map<String, dynamic> data, String tmdbId) {
    final availability = data['availability'] as Map<String, dynamic>? ?? {};
    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
    
    return PlatformAvailability(
      platform: StreamingPlatform.disneyPlus,
      isAvailable: availability['is_available'] as bool? ?? false,
      isFree: false,
      requiresSubscription: true,
      canRent: false,
      canPurchase: false,
      currency: 'USD',
      quality: metadata['video_quality'] as String? ?? '4K Dolby Vision',
      deepLink: generateDeepLink(movieId: tmdbId),
      audioLanguages: List<String>.from(metadata['audio_languages'] as List? ?? ['en']),
      subtitleLanguages: List<String>.from(metadata['subtitle_languages'] as List? ?? ['en']),
    );
  }

  /// Parse Disney+ movies response
  List<Movie> _parseDisneyMovies(List data) {
    return data.map((item) {
      final movie = item as Map<String, dynamic>;
      return Movie(
        id: movie['id'] as int? ?? 0,
        title: movie['title'] as String? ?? '',
        overview: movie['overview'] as String? ?? '',
        posterPath: movie['poster_path'] as String? ?? '',
        backdropPath: movie['backdrop_path'] as String? ?? '',
        releaseDate: movie['release_date'] != null 
            ? DateTime.tryParse(movie['release_date'] as String) ?? DateTime.now()
            : DateTime.now(),
        voteAverage: (movie['vote_average'] as num?)?.toDouble() ?? 0.0,
        voteCount: movie['vote_count'] as int? ?? 0,
        genreIds: List<String>.from(movie['genre_ids'] as List? ?? []),
        adult: movie['adult'] as bool? ?? false,
        originalLanguage: movie['original_language'] as String? ?? 'en',
        originalTitle: movie['original_title'] as String? ?? '',
        popularity: (movie['popularity'] as num?)?.toDouble() ?? 0.0,
        video: movie['video'] as bool? ?? false,
      );
    }).toList();
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

  @override
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
