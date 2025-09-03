import 'dart:async';

import 'package:http/http.dart' as http;

import '../../../domain/entities/movie.dart';
import '../../../domain/entities/streaming_availability.dart';
import '../../../domain/entities/streaming_platform.dart';
import '../../analytics/analytics_service.dart';
import '../../logging/app_logger.dart';
import 'netflix_service.dart'; // For SubscriptionPlan

/// HBO Max streaming service implementation
class HBOMaxService {
  HBOMaxService({
    http.Client? httpClient,
    AnalyticsService? analyticsService,
    AppLogger? logger,
  })  : _httpClient = httpClient ?? http.Client(),
        _analyticsService = analyticsService ?? AnalyticsService(),
        _logger = logger ?? AppLogger.instance;
  static const String _baseUrl = 'https://api.hbomax.com';
  static const String _deepLinkScheme = 'hbomax://';

  final http.Client _httpClient;
  final AnalyticsService _analyticsService;
  final AppLogger _logger;

  /// Check if a movie is available on HBO Max
  Future<PlatformAvailability?> checkMovieAvailability({
    required String movieId,
    required String tmdbId,
    String region = 'US',
  }) async {
    try {
      _logger.info('Checking HBO Max availability for movie: $movieId');

      final availability = await _simulateHBOAvailability(
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
          'action': 'hbo_max_availability_checked',
        },
      );

      return availability;
    } catch (e) {
      _logger.error('Error checking HBO Max availability: $e');
      _analyticsService.trackEvent(
        AnalyticsEventType.error,
        {
          'movie_id': movieId,
          'error': e.toString(),
          'action': 'hbo_max_availability_error',
        },
      );
      return null;
    }
  }

  /// Search for content on HBO Max
  Future<List<Movie>> searchContent({
    required String query,
    String region = 'US',
    int limit = 20,
  }) async {
    try {
      _logger.info('Searching HBO Max content: $query');

      final results = await _simulateHBOSearch(
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
          'action': 'hbo_max_search_performed',
        },
      );

      return results;
    } catch (e) {
      _logger.error('Error searching HBO Max content: $e');
      _analyticsService.trackEvent(
        AnalyticsEventType.error,
        {
          'platform': 'HBO Max',
          'action': 'search_failed',
          'query': query,
          'error': e.toString(),
        },
      );
      return [];
    }
  }

  /// Get HBO Max originals
  Future<List<Movie>> getOriginals({
    String region = 'US',
    int limit = 20,
    HBOContentType? contentType,
  }) async {
    try {
      _logger.info('Getting HBO Max originals');

      final originals = await _simulateHBOOriginals(
        region: region,
        limit: limit,
        contentType: contentType,
      );

      _analyticsService.trackEvent(
        AnalyticsEventType.userEngagement,
        {
          'platform': 'HBO Max',
          'action': 'originals_fetched',
          'region': region,
          'content_type': contentType?.name,
          'results_count': originals.length,
        },
      );

      return originals;
    } catch (e) {
      _logger.error('Error getting HBO Max originals: $e');
      return [];
    }
  }

  /// Get premium movie releases
  Future<List<Movie>> getPremiumReleases({
    String region = 'US',
    int limit = 20,
  }) async {
    try {
      _logger.info('Getting HBO Max premium releases');

      final releases = await _simulateHBOPremiumReleases(
        region: region,
        limit: limit,
      );

      _analyticsService.trackEvent(
        AnalyticsEventType.userEngagement,
        {
          'platform': 'HBO Max',
          'action': 'premium_releases_fetched',
          'region': region,
          'results_count': releases.length,
        },
      );

      return releases;
    } catch (e) {
      _logger.error('Error getting HBO Max premium releases: $e');
      return [];
    }
  }

  /// Get content by HBO network/brand
  Future<List<Movie>> getContentByNetwork({
    required HBONetwork network,
    String region = 'US',
    int limit = 20,
  }) async {
    try {
      _logger.info('Getting HBO Max content for network: ${network.name}');

      final content = await _simulateHBONetworkContent(
        network: network,
        region: region,
        limit: limit,
      );

      _analyticsService.trackEvent(
        AnalyticsEventType.userEngagement,
        {
          'platform': 'HBO Max',
          'action': 'network_content_fetched',
          'network': network.name,
          'region': region,
          'results_count': content.length,
        },
      );

      return content;
    } catch (e) {
      _logger.error('Error getting HBO Max network content: $e');
      return [];
    }
  }

  /// Get trending content on HBO Max
  Future<List<Movie>> getTrendingContent({
    String region = 'US',
    int limit = 20,
    HBOContentType? contentType,
  }) async {
    try {
      _logger.info('Getting HBO Max trending content');

      final trending = await _simulateHBOTrending(
        region: region,
        limit: limit,
        contentType: contentType,
      );

      _analyticsService.trackEvent(
        AnalyticsEventType.userEngagement,
        {
          'platform': 'HBO Max',
          'action': 'trending_fetched',
          'region': region,
          'content_type': contentType?.name,
          'results_count': trending.length,
        },
      );

      return trending;
    } catch (e) {
      _logger.error('Error getting HBO Max trending: $e');
      return [];
    }
  }

  /// Launch HBO Max app with deep link
  String generateDeepLink({
    required String movieId,
    String? tmdbId,
  }) {
    // HBO Max deep link format: hbomax://content/{content_id}
    final deepLink = '${_deepLinkScheme}content/$movieId';

    _analyticsService.trackEvent(
      AnalyticsEventType.userEngagement,
      {
        'platform': 'HBO Max',
        'action': 'deep_link_generated',
        'movie_id': movieId,
        'tmdb_id': tmdbId,
        'deep_link': deepLink,
      },
    );

    return deepLink;
  }

  /// Get HBO Max subscription plans
  Future<List<SubscriptionPlan>> getSubscriptionPlans({
    String region = 'US',
  }) async {
    try {
      return [
        const SubscriptionPlan(
          id: 'hbo_max_ads',
          name: 'HBO Max (With Ads)',
          price: 9.99,
          currency: 'USD',
          features: [
            'HBO Max content library',
            'Warner Bros. same-day premieres',
            'Limited ads',
            'HD streaming'
          ],
          quality: 'HD',
        ),
        const SubscriptionPlan(
          id: 'hbo_max_no_ads',
          name: 'HBO Max (Ad-Free)',
          price: 15.99,
          currency: 'USD',
          features: [
            'HBO Max content library',
            'Warner Bros. same-day premieres',
            'No ads',
            '4K Ultra HD streaming',
            'Download for offline viewing',
            'Dolby Atmos audio'
          ],
          quality: '4K Ultra HD',
        ),
      ];
    } catch (e) {
      _logger.error('Error getting HBO Max subscription plans: $e');
      return [];
    }
  }

  /// Check if content is a same-day Warner Bros. release
  Future<bool> isSameDayRelease({
    required String movieId,
    DateTime? releaseDate,
  }) async {
    try {
      // Simulate checking if movie is a Warner Bros. same-day release
      await Future.delayed(const Duration(milliseconds: 200));

      // Check if release date is recent and from Warner Bros.
      if (releaseDate == null) return false;

      final now = DateTime.now();
      final daysSinceRelease = now.difference(releaseDate).inDays;

      // Same-day releases are available for 31 days
      return daysSinceRelease >= 0 && daysSinceRelease <= 31;
    } catch (e) {
      _logger.error('Error checking same-day release status: $e');
      return false;
    }
  }

  // Simulation methods
  Future<PlatformAvailability?> _simulateHBOAvailability({
    required String tmdbId,
    required String region,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    // HBO Max has premium content, moderate availability
    final isAvailable =
        int.parse(tmdbId.replaceAll(RegExp(r'[^0-9]'), '')) % 4 == 0;

    if (!isAvailable) return null;

    return PlatformAvailability(
      platform: StreamingPlatform.hboMax,
      isAvailable: true,
      isFree: false,
      requiresSubscription: true,
      canRent: false,
      canPurchase: false,
      currency: 'USD',
      quality: '4K Ultra HD',
      deepLink: generateDeepLink(movieId: tmdbId),
      audioLanguages: ['en', 'es', 'fr'],
      subtitleLanguages: ['en', 'es', 'fr', 'de', 'it'],
    );
  }

  Future<List<Movie>> _simulateHBOSearch({
    required String query,
    required String region,
    required int limit,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return [];
  }

  Future<List<Movie>> _simulateHBOOriginals({
    required String region,
    required int limit,
    HBOContentType? contentType,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [];
  }

  Future<List<Movie>> _simulateHBOPremiumReleases({
    required String region,
    required int limit,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [];
  }

  Future<List<Movie>> _simulateHBONetworkContent({
    required HBONetwork network,
    required String region,
    required int limit,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [];
  }

  Future<List<Movie>> _simulateHBOTrending({
    required String region,
    required int limit,
    HBOContentType? contentType,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [];
  }

  void dispose() {
    _httpClient.close();
  }
}

/// HBO Max content types
enum HBOContentType {
  movies,
  series,
  documentaries,
  specials,
  kids,
}

extension HBOContentTypeExtension on HBOContentType {
  String get displayName {
    switch (this) {
      case HBOContentType.movies:
        return 'Movies';
      case HBOContentType.series:
        return 'Series';
      case HBOContentType.documentaries:
        return 'Documentaries';
      case HBOContentType.specials:
        return 'Specials';
      case HBOContentType.kids:
        return 'Kids & Family';
    }
  }
}

/// HBO network brands
enum HBONetwork {
  hbo,
  hboMax,
  warnerBros,
  dcComics,
  cartoonNetwork,
  adultSwim,
  cnn,
  tnt,
  tbs,
}

extension HBONetworkExtension on HBONetwork {
  String get displayName {
    switch (this) {
      case HBONetwork.hbo:
        return 'HBO';
      case HBONetwork.hboMax:
        return 'HBO Max Originals';
      case HBONetwork.warnerBros:
        return 'Warner Bros.';
      case HBONetwork.dcComics:
        return 'DC Comics';
      case HBONetwork.cartoonNetwork:
        return 'Cartoon Network';
      case HBONetwork.adultSwim:
        return 'Adult Swim';
      case HBONetwork.cnn:
        return 'CNN';
      case HBONetwork.tnt:
        return 'TNT';
      case HBONetwork.tbs:
        return 'TBS';
    }
  }

  bool get isPremium {
    switch (this) {
      case HBONetwork.hbo:
      case HBONetwork.hboMax:
      case HBONetwork.warnerBros:
        return true;
      default:
        return false;
    }
  }
}
