import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../domain/entities/movie.dart';
import '../../../domain/entities/streaming_availability.dart';
import '../../../domain/entities/streaming_platform.dart';
import '../streaming_api_config.dart';
import '../real_availability_service.dart';
import '../../analytics/analytics_service.dart';
import 'platform_services.dart'; // For StreamingPlatformServiceInterface

/// Amazon Prime Video streaming service implementation
class PrimeVideoService implements StreamingPlatformServiceInterface {
  PrimeVideoService({
    http.Client? httpClient,
    required AnalyticsService analytics,
    required RealAvailabilityService availabilityService,
  })  : _httpClient = httpClient ?? http.Client(),
        _analytics = analytics,
        _availabilityService = availabilityService;
  final String _baseUrl = StreamingApiConfig.primeVideoBaseUrl;
  static const String _deepLinkScheme = 'aiv://';

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
        'api_used':
            StreamingApiConfig.hasPrimeVideoApiKey ? 'real' : 'simulated',
      });

      // Try real availability service first
      final availabilityList = await _availabilityService.checkAvailability(
        movieId,
        region: region,
      );

      if (availabilityList.isNotEmpty) {
        return availabilityList.first;
      }

      // If Prime Video API is configured, try direct API call
      if (StreamingApiConfig.hasPrimeVideoApiKey) {
        final directAvailability = await _checkDirectPrimeAvailability(
          tmdbId: movieId,
          region: region,
        );

        if (directAvailability != null) {
          return directAvailability;
        }
      }

      // Fallback to simulation
      return await _simulatePrimeAvailability(
        tmdbId: movieId,
        region: region,
      );
    } catch (e) {
      // Error checking Prime Video availability: $e
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
        'api_used':
            StreamingApiConfig.hasPrimeVideoApiKey ? 'real' : 'simulated',
      });

      // If Prime Video API is configured, use real API
      if (StreamingApiConfig.hasPrimeVideoApiKey) {
        final realResults = await _searchPrimeContent(
          query: query,
          region: region,
          limit: limit,
        );

        if (realResults.isNotEmpty) {
          return realResults;
        }
      }

      // Fallback to simulation
      return await _simulatePrimeSearch(
        query: query,
        region: region,
        limit: limit,
      );
    } catch (e) {
      // Error searching Prime Video content: $e
      return [];
    }
  }

  Future<List<Movie>> getTrendingContent({
    String region = 'US',
    int limit = 20,
  }) async {
    try {
      _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'region': region,
        'limit': limit,
        'api_used':
            StreamingApiConfig.hasPrimeVideoApiKey ? 'real' : 'simulated',
      });

      // If Prime Video API is configured, use real API
      if (StreamingApiConfig.hasPrimeVideoApiKey) {
        final realResults = await _getTrendingPrimeContent(
          region: region,
          limit: limit,
        );

        if (realResults.isNotEmpty) {
          return realResults;
        }
      }

      // Fallback to simulation
      return await _simulatePrimeTrending(
        region: region,
        limit: limit,
      );
    } catch (e) {
      // Error getting Prime Video trending content: $e
      return [];
    }
  }

  /// Get Prime Video originals
  Future<List<Movie>> getOriginals({
    String region = 'US',
    int limit = 20,
  }) async {
    try {
      // Getting Prime Video originals

      final originals = await _simulatePrimeOriginals(
        region: region,
        limit: limit,
      );

      _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'platform': 'prime_video',
        'content_type': 'originals',
        'region': region,
        'results_count': originals.length,
      });

      return originals;
    } catch (e) {
      // Error getting Prime Video originals: $e
      return [];
    }
  }

  /// Launch Prime Video app with deep link
  @override
  String generateDeepLink({
    required String movieId,
    String? tmdbId,
  }) {
    // Prime Video deep link format: aiv://aiv/resume?asin={asin}
    final deepLink = '${_deepLinkScheme}aiv/resume?asin=$movieId';

    _analytics.trackEvent(AnalyticsEventType.userEngagement, {
      'platform': 'prime_video',
      'movie_id': movieId,
      'tmdb_id': tmdbId,
      'deep_link': deepLink,
      'action': 'deep_link_generated',
    });

    return deepLink;
  }

  /// Get Prime Video subscription plans
  @override
  Future<List<SubscriptionPlan>> getSubscriptionPlans({
    String region = 'US',
  }) async {
    try {
      // Prime Video subscription plans
      return [
        const SubscriptionPlan(
          id: 'prime_video_standalone',
          name: 'Prime Video',
          price: 8.99,
          currency: 'USD',
          features: [
            'Unlimited streaming',
            'Prime Video Originals',
            'Ad-supported'
          ],
          quality: 'HD/4K',
        ),
        const SubscriptionPlan(
          id: 'amazon_prime',
          name: 'Amazon Prime',
          price: 14.98,
          currency: 'USD',
          features: [
            'Prime Video included',
            'Free shipping',
            'Prime Music',
            'Prime Reading',
            'Prime Gaming'
          ],
          quality: 'HD/4K',
        ),
      ];
    } catch (e) {
      // Error getting Prime Video subscription plans: $e
      return [];
    }
  }

  /// Check if content requires additional rental/purchase
  Future<PrimeContentType> getContentType({
    required String movieId,
    String region = 'US',
  }) async {
    try {
      // Simulate content type checking
      await Future.delayed(const Duration(milliseconds: 300));

      // Simulate different content types
      final hash = movieId.hashCode;
      if (hash % 4 == 0) return PrimeContentType.included;
      if (hash % 4 == 1) return PrimeContentType.rental;
      if (hash % 4 == 2) return PrimeContentType.purchase;
      return PrimeContentType.unavailable;
    } catch (e) {
      // Error checking Prime Video content type: $e
      return PrimeContentType.unavailable;
    }
  }

  // Real API methods
  /// Check availability directly with Prime Video API
  Future<PlatformAvailability?> _checkDirectPrimeAvailability({
    required String tmdbId,
    required String region,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/catalog/titles/$tmdbId')
          .replace(queryParameters: {
        'region': region,
        'include_availability': 'true',
      });

      final response = await _httpClient
          .get(url, headers: StreamingApiConfig.primeVideoHeaders)
          .timeout(StreamingApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parsePrimeAvailability(data, tmdbId);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        // Prime Video API error: ${response.statusCode}
        return null;
      }
    } catch (e) {
      // Prime Video direct API call failed: $e
      return null;
    }
  }

  /// Search Prime Video content using real API
  Future<List<Movie>> _searchPrimeContent({
    required String query,
    required String region,
    required int limit,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/search').replace(queryParameters: {
        'q': query,
        'region': region,
        'limit': limit.toString(),
        'content_type': 'movie',
      });

      final response = await _httpClient
          .get(url, headers: StreamingApiConfig.primeVideoHeaders)
          .timeout(StreamingApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parsePrimeMovies(data['results'] as List? ?? []);
      } else {
        // Prime Video search API error: ${response.statusCode}
        return [];
      }
    } catch (e) {
      // Prime Video search API call failed: $e
      return [];
    }
  }

  /// Get trending Prime Video content using real API
  Future<List<Movie>> _getTrendingPrimeContent({
    required String region,
    required int limit,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/trending').replace(queryParameters: {
        'region': region,
        'limit': limit.toString(),
        'content_type': 'movie',
        'time_period': 'week',
      });

      final response = await _httpClient
          .get(url, headers: StreamingApiConfig.primeVideoHeaders)
          .timeout(StreamingApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parsePrimeMovies(data['results'] as List? ?? []);
      } else {
        // Prime Video trending API error: ${response.statusCode}
        return [];
      }
    } catch (e) {
      // Prime Video trending API call failed: $e
      return [];
    }
  }

  /// Parse Prime Video availability response
  PlatformAvailability _parsePrimeAvailability(
      Map<String, dynamic> data, String tmdbId) {
    final availability = data['availability'] as Map<String, dynamic>? ?? {};
    final pricing = data['pricing'] as Map<String, dynamic>? ?? {};
    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};

    return PlatformAvailability(
      platform: StreamingPlatform.primeVideo,
      isAvailable: availability['is_available'] as bool? ?? false,
      isFree: availability['is_free'] as bool? ?? false,
      requiresSubscription:
          availability['requires_subscription'] as bool? ?? true,
      canRent: availability['can_rent'] as bool? ?? true,
      canPurchase: availability['can_purchase'] as bool? ?? true,
      rentalPrice: (pricing['rental_price'] as num?)?.toDouble(),
      purchasePrice: (pricing['purchase_price'] as num?)?.toDouble(),
      currency: pricing['currency'] as String? ?? 'USD',
      quality: metadata['video_quality'] as String? ?? '4K Ultra HD',
      deepLink: generateDeepLink(movieId: tmdbId),
      audioLanguages:
          List<String>.from(metadata['audio_languages'] as List? ?? ['en']),
      subtitleLanguages:
          List<String>.from(metadata['subtitle_languages'] as List? ?? ['en']),
    );
  }

  /// Parse Prime Video movies response
  List<Movie> _parsePrimeMovies(List data) {
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
  Future<PlatformAvailability?> _simulatePrimeAvailability({
    required String tmdbId,
    required String region,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final isAvailable =
        int.parse(tmdbId.replaceAll(RegExp(r'[^0-9]'), '')) % 4 != 0;

    if (!isAvailable) return null;

    final contentType = await getContentType(movieId: tmdbId, region: region);

    return PlatformAvailability(
      platform: StreamingPlatform.amazonPrime,
      isAvailable: true,
      isFree: contentType == PrimeContentType.included,
      requiresSubscription: contentType == PrimeContentType.included,
      canRent: contentType == PrimeContentType.rental,
      canPurchase: contentType == PrimeContentType.purchase,
      rentalPrice: contentType == PrimeContentType.rental ? 3.99 : null,
      purchasePrice: contentType == PrimeContentType.purchase ? 14.99 : null,
      currency: 'USD',
      quality: '4K',
      deepLink: generateDeepLink(movieId: tmdbId),
      audioLanguages: ['en', 'es', 'fr', 'de'],
      subtitleLanguages: ['en', 'es', 'fr', 'de', 'it'],
    );
  }

  Future<List<Movie>> _simulatePrimeSearch({
    required String query,
    required String region,
    required int limit,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));
    return [];
  }

  Future<List<Movie>> _simulatePrimeTrending({
    required String region,
    required int limit,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [];
  }

  Future<List<Movie>> _simulatePrimeOriginals({
    required String region,
    required int limit,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [];
  }

  @override
  void dispose() {
    _httpClient.close();
  }
}

/// Prime Video content types
enum PrimeContentType {
  included, // Included with Prime subscription
  rental, // Available for rent
  purchase, // Available for purchase
  unavailable, // Not available
}

extension PrimeContentTypeExtension on PrimeContentType {
  String get displayName {
    switch (this) {
      case PrimeContentType.included:
        return 'Included with Prime';
      case PrimeContentType.rental:
        return 'Rent';
      case PrimeContentType.purchase:
        return 'Buy';
      case PrimeContentType.unavailable:
        return 'Unavailable';
    }
  }

  bool get isFree => this == PrimeContentType.included;
  bool get requiresPayment =>
      this == PrimeContentType.rental || this == PrimeContentType.purchase;
}
