import 'dart:async';

import 'package:http/http.dart' as http;

import '../../../domain/entities/movie.dart';
import '../../../domain/entities/streaming_availability.dart';
import '../../../domain/entities/streaming_platform.dart';
import '../../analytics/analytics_service.dart';
import '../../logging/app_logger.dart';
import 'netflix_service.dart'; // For SubscriptionPlan

/// Amazon Prime Video streaming service implementation
class PrimeVideoService {
  PrimeVideoService({
    http.Client? httpClient,
    AnalyticsService? analyticsService,
    AppLogger? logger,
  })  : _httpClient = httpClient ?? http.Client(),
        _analyticsService = analyticsService ?? AnalyticsService(),
        _logger = logger ?? AppLogger.instance;
  static const String _baseUrl = 'https://api.primevideo.com';
  static const String _deepLinkScheme = 'aiv://';

  final http.Client _httpClient;
  final AnalyticsService _analyticsService;
  final AppLogger _logger;

  /// Check if a movie is available on Prime Video
  Future<PlatformAvailability?> checkMovieAvailability({
    required String movieId,
    required String tmdbId,
    String region = 'US',
  }) async {
    try {
      _logger.info('Checking Prime Video availability for movie: $movieId');

      final availability = await _simulatePrimeAvailability(
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
          'platform': 'prime_video',
          'action': 'availability_checked',
        },
      );

      return availability;
    } catch (e) {
      _logger.error('Error checking Prime Video availability: $e');
      _analyticsService.trackEvent(
        AnalyticsEventType.error,
        {
          'movie_id': movieId,
          'error': e.toString(),
          'platform': 'prime_video',
        },
      );
      return null;
    }
  }

  /// Search for content on Prime Video
  Future<List<Movie>> searchContent({
    required String query,
    String region = 'US',
    int limit = 20,
  }) async {
    try {
      _logger.info('Searching Prime Video content: $query');

      final results = await _simulatePrimeSearch(
        query: query,
        region: region,
        limit: limit,
      );

      _analyticsService.trackEvent(
        AnalyticsEventType.searchQuery,
        {
          'query': query,
          'region': region,
          'results_count': results.length,
          'platform': 'prime_video',
        },
      );

      return results;
    } catch (e) {
      _logger.error('Error searching Prime Video content: $e');
      _analyticsService.trackEvent(
        AnalyticsEventType.error,
        {
          'query': query,
          'error': e.toString(),
          'platform': 'prime_video',
        },
      );
      return [];
    }
  }

  /// Get trending content from Prime Video
  Future<List<Movie>> getTrendingContent({
    String region = 'US',
    int limit = 20,
  }) async {
    try {
      _logger.info('Getting Prime Video trending content');

      final trending = await _simulatePrimeTrending(
        region: region,
        limit: limit,
      );

      _analyticsService.trackEvent(
        AnalyticsEventType.userEngagement,
        {
          'platform': 'prime_video',
          'content_type': 'trending',
          'region': region,
          'results_count': trending.length,
        },
      );

      return trending;
    } catch (e) {
      _logger.error('Error getting Prime Video trending: $e');
      return [];
    }
  }

  /// Get Prime Video originals
  Future<List<Movie>> getOriginals({
    String region = 'US',
    int limit = 20,
  }) async {
    try {
      _logger.info('Getting Prime Video originals');

      final originals = await _simulatePrimeOriginals(
        region: region,
        limit: limit,
      );

      _analyticsService.trackEvent(
        AnalyticsEventType.userEngagement,
        {
          'platform': 'prime_video',
          'content_type': 'originals',
          'region': region,
          'results_count': originals.length,
        },
      );

      return originals;
    } catch (e) {
      _logger.error('Error getting Prime Video originals: $e');
      return [];
    }
  }

  /// Launch Prime Video app with deep link
  String generateDeepLink({
    required String movieId,
    String? tmdbId,
  }) {
    // Prime Video deep link format: aiv://aiv/resume?asin={asin}
    final deepLink = '${_deepLinkScheme}aiv/resume?asin=$movieId';

    _analyticsService.trackEvent(
      AnalyticsEventType.userEngagement,
      {
        'platform': 'prime_video',
        'movie_id': movieId,
        'tmdb_id': tmdbId,
        'deep_link': deepLink,
        'action': 'deep_link_generated',
      },
    );

    return deepLink;
  }

  /// Get Prime Video subscription plans
  Future<List<SubscriptionPlan>> getSubscriptionPlans({
    String region = 'US',
  }) async {
    try {
      // Prime Video subscription plans
      return [
        SubscriptionPlan(
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
        SubscriptionPlan(
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
      _logger.error('Error getting Prime Video subscription plans: $e');
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
      _logger.error('Error checking Prime Video content type: $e');
      return PrimeContentType.unavailable;
    }
  }

  // Simulation methods
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
