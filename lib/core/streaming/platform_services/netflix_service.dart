import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../domain/entities/movie.dart';
import '../../../domain/entities/streaming_availability.dart';
import '../../../domain/entities/streaming_platform.dart';
import '../../analytics/analytics_service.dart';
import '../real_availability_service.dart';
import '../streaming_api_config.dart';
import 'platform_services.dart';

/// Netflix-specific streaming service implementation
class NetflixService implements StreamingPlatformServiceInterface {
  NetflixService({
    http.Client? httpClient,
    required AnalyticsService analytics,
    required RealAvailabilityService availabilityService,
  })  : _httpClient = httpClient ?? http.Client(),
        _analytics = analytics,
        _availabilityService = availabilityService;
  static const String _baseUrl = StreamingApiConfig.netflixBaseUrl;
  static const String _deepLinkScheme = 'netflix://';

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
        'movie_id': movieId,
        'region': region,
        'api_used': StreamingApiConfig.hasNetflixApiKey ? 'real' : 'simulated',
      });

      // Try real availability service first
      final availabilityList = await _availabilityService.checkAvailability(
        movieId,
        region: region,
      );

      if (availabilityList.isNotEmpty) {
        return availabilityList.first;
      }

      // If Netflix API is configured, try direct API call
      if (StreamingApiConfig.isNetflixConfigured) {
        final directAvailability = await _checkDirectNetflixAvailability(
          tmdbId: movieId,
          region: region,
        );

        if (directAvailability != null) {
          return directAvailability;
        }
      }

      // Fallback to simulation
      return await _simulateNetflixAvailability(
        tmdbId: movieId,
        region: region,
      );
    } catch (e) {
      // Error checking Netflix availability: $e
      return null;
    }
  }

  /// Search for content on Netflix
  @override
  Future<List<Movie>> searchContent({
    required String query,
    String region = 'US',
    int limit = 20,
  }) async {
    try {
      // Searching Netflix content: $query

      List<Movie> results = [];

      // Try real Netflix API if configured
      if (StreamingApiConfig.isNetflixConfigured) {
        results = await _searchNetflixContent(
          query: query,
          region: region,
          limit: limit,
        );
      }

      // Fallback to simulation if no real API or no results
      if (results.isEmpty) {
        results = await _simulateNetflixSearch(
          query: query,
          region: region,
          limit: limit,
        );
      }

      _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'platform': 'Netflix',
        'query': query,
        'region': region,
        'results_count': results.length,
        'api_used':
            StreamingApiConfig.isNetflixConfigured ? 'real' : 'simulated',
      });

      return results;
    } catch (e) {
      // Error searching Netflix content: $e
      _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'platform': 'Netflix',
        'action': 'search_failed',
        'query': query,
        'error': e.toString(),
      });
      return [];
    }
  }

  /// Get trending content from Netflix
  Future<List<Movie>> getTrendingContent({
    String region = 'US',
    int limit = 20,
  }) async {
    try {
      // Getting Netflix trending content

      List<Movie> trending = [];

      // Try real Netflix API if configured
      if (StreamingApiConfig.isNetflixConfigured) {
        trending = await _getTrendingNetflixContent(
          region: region,
          limit: limit,
        );
      }

      // Fallback to simulation if no real API or no results
      if (trending.isEmpty) {
        trending = await _simulateNetflixTrending(
          region: region,
          limit: limit,
        );
      }

      _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'platform': 'Netflix',
        'action': 'trending_fetched',
        'region': region,
        'results_count': trending.length,
        'api_used':
            StreamingApiConfig.isNetflixConfigured ? 'real' : 'simulated',
      });

      return trending;
    } catch (e) {
      // Error getting Netflix trending: $e
      return [];
    }
  }

  /// Launch Netflix app with deep link
  @override
  String generateDeepLink({
    required String movieId,
    String? tmdbId,
  }) {
    // Netflix deep link format: netflix://title/{netflix_id}
    // For simulation, we'll use the movieId
    final deepLink = '${_deepLinkScheme}title/$movieId';

    _analytics.trackEvent(AnalyticsEventType.userEngagement, {
      'platform': 'Netflix',
      'action': 'deep_link_generated',
      'movie_id': movieId,
      'tmdb_id': tmdbId,
      'deep_link': deepLink,
    });

    return deepLink;
  }

  /// Get Netflix subscription plans
  @override
  Future<List<SubscriptionPlan>> getSubscriptionPlans({
    String region = 'US',
  }) async {
    try {
      // Simulate Netflix subscription plans
      return [
        const SubscriptionPlan(
          id: 'netflix_basic',
          name: 'Basic',
          price: 8.99,
          currency: 'USD',
          features: ['1 Screen', 'Mobile & Tablet', 'Unlimited Movies & TV'],
          quality: 'Good',
        ),
        const SubscriptionPlan(
          id: 'netflix_standard',
          name: 'Standard',
          price: 13.99,
          currency: 'USD',
          features: ['2 Screens', 'HD Available', 'Unlimited Movies & TV'],
          quality: 'Better',
        ),
        const SubscriptionPlan(
          id: 'netflix_premium',
          name: 'Premium',
          price: 17.99,
          currency: 'USD',
          features: [
            '4 Screens',
            'Ultra HD Available',
            'Unlimited Movies & TV'
          ],
          quality: 'Best',
        ),
      ];
    } catch (e) {
      // Error getting Netflix subscription plans: $e
      return [];
    }
  }

  // Real API methods
  /// Check availability directly with Netflix API
  Future<PlatformAvailability?> _checkDirectNetflixAvailability({
    required String tmdbId,
    required String region,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/titles/$tmdbId/availability')
          .replace(queryParameters: {
        'region': region,
        'include_metadata': 'true',
      });

      final response = await _httpClient
          .get(url, headers: StreamingApiConfig.netflixHeaders)
          .timeout(StreamingApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parseNetflixAvailability(data, tmdbId);
      } else if (response.statusCode == 404) {
        // Movie not available on Netflix
        return null;
      } else {
        // Netflix API error: ${response.statusCode}
        return null;
      }
    } catch (e) {
      // Netflix direct API call failed: $e
      return null;
    }
  }

  /// Search Netflix content using real API
  Future<List<Movie>> _searchNetflixContent({
    required String query,
    required String region,
    required int limit,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/search').replace(queryParameters: {
        'q': query,
        'region': region,
        'limit': limit.toString(),
        'type': 'movie',
      });

      final response = await _httpClient
          .get(url, headers: StreamingApiConfig.netflixHeaders)
          .timeout(StreamingApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parseNetflixMovies(data['results'] as List? ?? []);
      } else {
        // Netflix search API error: ${response.statusCode}
        return [];
      }
    } catch (e) {
      // Netflix search API call failed: $e
      return [];
    }
  }

  /// Get trending Netflix content using real API
  Future<List<Movie>> _getTrendingNetflixContent({
    required String region,
    required int limit,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/trending').replace(queryParameters: {
        'region': region,
        'limit': limit.toString(),
        'type': 'movie',
        'time_window': 'week',
      });

      final response = await _httpClient
          .get(url, headers: StreamingApiConfig.netflixHeaders)
          .timeout(StreamingApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parseNetflixMovies(data['results'] as List? ?? []);
      } else {
        // Netflix trending API error: ${response.statusCode}
        return [];
      }
    } catch (e) {
      // Netflix trending API call failed: $e
      return [];
    }
  }

  /// Parse Netflix availability response
  PlatformAvailability _parseNetflixAvailability(
      Map<String, dynamic> data, String tmdbId) {
    final availability = data['availability'] as Map<String, dynamic>? ?? {};
    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};

    return PlatformAvailability(
      platform: StreamingPlatform.netflix,
      isAvailable: availability['is_available'] as bool? ?? false,
      isFree: false,
      requiresSubscription: true,
      canRent: false,
      canPurchase: false,
      currency: 'USD',
      quality: metadata['video_quality'] as String? ?? 'HD',
      deepLink: generateDeepLink(movieId: tmdbId),
      audioLanguages:
          List<String>.from(metadata['audio_languages'] as List? ?? ['en']),
      subtitleLanguages:
          List<String>.from(metadata['subtitle_languages'] as List? ?? ['en']),
    );
  }

  /// Parse Netflix movies response
  List<Movie> _parseNetflixMovies(List data) {
    return data.map((item) {
      final movie = item as Map<String, dynamic>;
      return Movie(
        id: movie['id'] as int? ?? 0,
        title: movie['title'] as String? ?? '',
        overview: movie['overview'] as String? ?? '',
        posterPath: movie['poster_path'] as String? ?? '',
        backdropPath: movie['backdrop_path'] as String? ?? '',
        releaseDate: movie['release_date'] != null
            ? DateTime.tryParse(movie['release_date'] as String) ??
                DateTime.now()
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

  // Simulation methods (fallback when real APIs are not available)
  Future<PlatformAvailability?> _simulateNetflixAvailability({
    required String tmdbId,
    required String region,
  }) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Simulate availability based on movie ID
    final isAvailable =
        int.parse(tmdbId.replaceAll(RegExp(r'[^0-9]'), '')) % 3 == 0;

    if (!isAvailable) return null;

    return PlatformAvailability(
      platform: StreamingPlatform.netflix,
      isAvailable: true,
      isFree: false,
      requiresSubscription: true,
      canRent: false,
      canPurchase: false,
      currency: 'USD',
      quality: 'Ultra HD',
      deepLink: generateDeepLink(movieId: tmdbId),
      audioLanguages: ['en', 'es', 'fr'],
      subtitleLanguages: ['en', 'es', 'fr', 'de'],
    );
  }

  Future<List<Movie>> _simulateNetflixSearch({
    required String query,
    required String region,
    required int limit,
  }) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Return empty list for simulation
    return [];
  }

  Future<List<Movie>> _simulateNetflixTrending({
    required String region,
    required int limit,
  }) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 600));

    // Return empty list for simulation
    return [];
  }

  @override
  void dispose() {
    _httpClient.close();
  }
}

/// Netflix subscription plan model
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.features,
    required this.quality,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlan(
        id: json['id'] as String,
        name: json['name'] as String,
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency'] as String,
        features: List<String>.from(json['features'] as List),
        quality: json['quality'] as String,
      );
  final String id;
  final String name;
  final double price;
  final String currency;
  final List<String> features;
  final String quality;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'currency': currency,
        'features': features,
        'quality': quality,
      };
}
