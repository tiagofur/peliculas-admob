import 'dart:async';

import 'package:http/http.dart' as http;

import '../../domain/entities/streaming_availability.dart';
import '../../domain/entities/streaming_platform.dart';
import '../../domain/entities/subscription.dart';
import '../analytics/analytics_service.dart';
import '../cache/cache_service.dart';
import '../logging/app_logger.dart';
import 'availability_checker.dart';
import 'deep_linking_service.dart';
import 'platform_services/platform_services.dart';
import 'real_availability_service.dart';
import 'realtime_availability_service.dart';

/// Main service for managing streaming platform integrations
class StreamingServiceManager {
  StreamingServiceManager({
    required this.analytics,
    required this.cache,
    AppLogger? logger,
    http.Client? httpClient,
  })  : logger = logger ?? AppLogger.instance,
        _httpClient = httpClient ?? http.Client(),
        _availabilityChecker = AvailabilityChecker(
          analyticsService: analytics,
          cacheService: cache,
        ),
        _deepLinkingService = DeepLinkingService(
          analyticsService: analytics,
        ) {
    _initializeServices();
  }
  final AnalyticsService analytics;
  final CacheService cache;
  final AppLogger logger;
  final http.Client _httpClient;
  final DeepLinkingService _deepLinkingService;
  final AvailabilityChecker _availabilityChecker;

  // Real-time availability services
  late final RealAvailabilityService _realAvailabilityService;
  late final RealtimeAvailabilityService _realtimeAvailabilityService;

  // Platform services
  late final NetflixService _netflixService;
  late final PrimeVideoService _primeVideoService;
  late final DisneyPlusService _disneyPlusService;
  late final HboMaxService _hboMaxService;
  final Map<String, StreamingPlatformService> _platformServices = {};
  final StreamController<StreamingEvent> _eventController =
      StreamController<StreamingEvent>.broadcast();

  /// Initialize all streaming services
  void _initializeServices() {
    // Initialize real availability service
    _realAvailabilityService = RealAvailabilityService(
      httpClient: _httpClient,
      analyticsService: analytics,
      logger: logger,
    );

    // Initialize platform services first
    _netflixService = NetflixService(
      httpClient: _httpClient,
      analytics: analytics,
      availabilityService: _realAvailabilityService,
    );

    _primeVideoService = PrimeVideoService(
      httpClient: _httpClient,
      analytics: analytics,
      availabilityService: _realAvailabilityService,
    );

    _disneyPlusService = DisneyPlusService(
      httpClient: _httpClient,
      analytics: analytics,
      availabilityService: _realAvailabilityService,
    );

    _hboMaxService = HboMaxService(
      httpClient: _httpClient,
      analytics: analytics,
      availabilityService: _realAvailabilityService,
    );

    // Initialize real-time availability service
    _realtimeAvailabilityService = RealtimeAvailabilityService(
      netflixService: _netflixService,
      primeVideoService: _primeVideoService,
      disneyPlusService: _disneyPlusService,
      hboMaxService: _hboMaxService,
      analytics: analytics,
    );
  }

  // Cache duration for availability data
  static const Duration _availabilityCacheDuration = Duration(hours: 6);

  /// Get real-time availability service
  RealtimeAvailabilityService get realtimeAvailability =>
      _realtimeAvailabilityService;

  /// Get real availability service
  RealAvailabilityService get realAvailability => _realAvailabilityService;

  /// Get platform service by platform ID
  StreamingPlatformServiceInterface? getPlatformService(String platformId) {
    switch (platformId) {
      case 'netflix':
        return _netflixService;
      case 'amazon_prime':
        return _primeVideoService;
      case 'disney_plus':
        return _disneyPlusService;
      case 'hbo_max':
        return _hboMaxService;
      default:
        return null;
    }
  }

  static const Duration _subscriptionCacheDuration = Duration(hours: 1);

  bool _isInitialized = false;
  String _currentRegion = 'US';
  final Map<int, StreamingAvailability> _availabilityCache = {};
  final Map<String, List<Subscription>> _userSubscriptions = {};

  /// Stream of streaming-related events
  Stream<StreamingEvent> get events => _eventController.stream;

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  /// Get current region
  String get currentRegion => _currentRegion;

  /// Initialize the streaming service manager
  Future<void> initialize({
    String region = 'US',
    Map<String, String>? apiKeys,
  }) async {
    try {
      logger.info('Initializing StreamingServiceManager for region: $region');

      _currentRegion = region;

      // Initialize platform services
      await _initializePlatformServices(apiKeys ?? {});

      _isInitialized = true;

      analytics.trackEvent(AnalyticsEventType.appLaunch, {
        'region': region,
        'platforms_count': _platformServices.length,
      });

      _eventController.add(StreamingEvent.initialized(region));

      logger.info('StreamingServiceManager initialized successfully');
    } catch (e, stackTrace) {
      logger.error('Failed to initialize StreamingServiceManager: $e');
      analytics.trackEvent(AnalyticsEventType.error, {
        'error': e.toString(),
        'region': region,
      });
      rethrow;
    }
  }

  /// Initialize platform services
  Future<void> _initializePlatformServices(Map<String, String> apiKeys) async {
    final platforms = StreamingPlatform.allPlatforms;

    for (final platform in platforms) {
      if (platform.supportedCountries.contains(_currentRegion)) {
        final service = StreamingPlatformService(
          platform: platform,
          apiKey: apiKeys[platform.id],
          region: _currentRegion,
        );

        await service.initialize();
        _platformServices[platform.id] = service;

        logger.debug('Initialized service for platform: ${platform.name}');
      }
    }
  }

  /// Check movie availability across all platforms
  Future<StreamingAvailability?> checkMovieAvailability({
    required String movieId,
    required String movieTitle,
    String? tmdbId,
    String region = 'US',
    bool useCache = true,
  }) async {
    return await _availabilityChecker.checkMovieAvailability(
      movieId: movieId,
      movieTitle: movieTitle,
      tmdbId: tmdbId,
      region: region,
      useCache: useCache,
    );
  }

  /// Get streaming availability for a movie
  Future<StreamingAvailability?> getAvailability(
    int movieId,
    String movieTitle, {
    String region = 'US',
    bool forceRefresh = false,
  }) async {
    try {
      // Use real-time availability service for better performance
      return await _realtimeAvailabilityService.getAvailability(
        movieId,
        movieTitle,
        region: region,
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      logger.error('Failed to get availability for movie $movieId: $e');
      // Fallback to availability checker
      try {
        return await _availabilityChecker.checkAvailability(
          movieId,
          movieTitle,
          region: region,
          useCache: !forceRefresh,
        );
      } catch (fallbackError) {
        logger.error('Fallback availability check also failed: $fallbackError');
        return null;
      }
    }
  }

  /// Stream real-time availability updates for a movie
  Stream<StreamingAvailability?> streamAvailability(
    int movieId,
    String movieTitle, {
    String region = 'US',
  }) {
    return _realtimeAvailabilityService.streamAvailability(
      movieId,
      movieTitle,
      region: region,
    );
  }

  /// Preload availability for multiple movies
  Future<void> preloadAvailability(
    List<int> movieIds,
    List<String> movieTitles, {
    String region = 'US',
  }) async {
    try {
      await _realtimeAvailabilityService.preloadAvailability(
        movieIds: movieIds.map((id) => id.toString()).toList(),
        region: region,
      );
    } catch (e) {
      logger.error('Failed to preload availability: $e');
    }
  }

  /// Clear availability cache
  Future<void> clearAvailabilityCache() async {
    try {
      await _realtimeAvailabilityService.clearCache();
    } catch (e) {
      logger.error('Failed to clear availability cache: $e');
    }
  }

  /// Get user subscriptions
  List<Subscription> getUserSubscriptions(String userId) {
    return _userSubscriptions[userId] ?? [];
  }

  /// Add or update user subscription
  Future<void> updateUserSubscription(Subscription subscription) async {
    try {
      final userId = subscription.userId;
      final userSubs = _userSubscriptions[userId] ?? [];

      // Remove existing subscription for the same platform
      userSubs.removeWhere((s) => s.platform.id == subscription.platform.id);

      // Add the new/updated subscription
      userSubs.add(subscription);
      _userSubscriptions[userId] = userSubs;

      analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'user_id': userId,
        'platform': subscription.platform.id,
        'status': subscription.status.name,
        'tier': subscription.tier.name,
      });

      _eventController.add(StreamingEvent.subscriptionUpdated(subscription));

      logger.info('Updated subscription for ${subscription.platform.name}');
    } catch (e, stackTrace) {
      logger.error('Failed to update subscription: $e');
      rethrow;
    }
  }

  /// Remove user subscription
  Future<void> removeUserSubscription(String userId, String platformId) async {
    try {
      final userSubs = _userSubscriptions[userId] ?? [];
      userSubs.removeWhere((s) => s.platform.id == platformId);
      _userSubscriptions[userId] = userSubs;

      analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'user_id': userId,
        'platform': platformId,
      });

      logger.info('Removed subscription for platform: $platformId');
    } catch (e, stackTrace) {
      logger.error('Failed to remove subscription: $e');
      rethrow;
    }
  }

  /// Get subscription summary for user
  SubscriptionSummary getUserSubscriptionSummary(String userId) {
    final subscriptions = getUserSubscriptions(userId);
    return SubscriptionSummary.fromSubscriptions(
      userId: userId,
      subscriptions: subscriptions,
      currency: _getCurrencyForRegion(_currentRegion),
    );
  }

  /// Launch streaming app for specific content
  Future<bool> launchStreamingApp({
    required StreamingPlatform platform,
    required String movieId,
    String? tmdbId,
    Map<String, String>? additionalParams,
  }) async {
    return await _deepLinkingService.launchStreamingApp(
      platform: platform,
      movieId: movieId,
      tmdbId: tmdbId,
      additionalParams: additionalParams,
    );
  }

  /// Launch streaming platform's main app
  Future<bool> launchPlatformApp(StreamingPlatform platform) async {
    return await _deepLinkingService.launchPlatformApp(platform);
  }

  /// Check if streaming app is installed
  Future<bool> isAppInstalled(StreamingPlatform platform) async {
    return await _deepLinkingService.isAppInstalled(platform);
  }

  /// Launch app store to install streaming app
  Future<bool> launchAppStore(StreamingPlatform platform) async {
    return await _deepLinkingService.launchAppStore(platform);
  }

  /// Search for content across platforms
  Future<List<StreamingSearchResult>> searchContent({
    required String query,
    List<String>? platformIds,
    ContentType? contentType,
  }) async {
    try {
      logger.info('Searching for content: $query');

      final targetServices = platformIds != null
          ? _platformServices.values
              .where((s) => platformIds.contains(s.platform.id))
          : _platformServices.values;

      final List<StreamingSearchResult> results = [];

      final futures = targetServices.map((service) async {
        try {
          return await service.searchContent(query, contentType);
        } catch (e) {
          logger.warning('Search failed on ${service.platform.name}: $e');
          return <StreamingSearchResult>[];
        }
      });

      final searchResults = await Future.wait(futures);

      for (final platformResults in searchResults) {
        results.addAll(platformResults);
      }

      analytics.trackEvent(AnalyticsEventType.searchQuery, {
        'query': query,
        'platforms_searched': targetServices.length,
        'results_found': results.length,
      });

      return results;
    } catch (e, stackTrace) {
      logger.error('Failed to search content: $e');
      return [];
    }
  }

  /// Clear availability cache
  void clearCache() {
    _availabilityCache.clear();
    logger.info('Streaming availability cache cleared');
  }

  /// Get all available platforms
  List<StreamingPlatform> getAvailablePlatforms() {
    return _platformServices.values.map((s) => s.platform).toList();
  }

  String _getCurrencyForRegion(String region) {
    switch (region.toUpperCase()) {
      case 'US':
      case 'CA':
        return 'USD';
      case 'GB':
        return 'GBP';
      case 'JP':
        return 'JPY';
      case 'DE':
      case 'FR':
      case 'ES':
      case 'IT':
        return 'EUR';
      default:
        return 'USD';
    }
  }

  /// Dispose resources
  void dispose() {
    _eventController.close();
    _realtimeAvailabilityService.dispose();
    _httpClient.close();

    for (final service in _platformServices.values) {
      service.dispose();
    }
    _platformServices.clear();

    logger.info('StreamingServiceManager disposed');
  }
}

/// Individual streaming platform service
class StreamingPlatformService {
  StreamingPlatformService({
    required this.platform,
    this.apiKey,
    required this.region,
  }) : _logger = AppLogger.instance;
  final StreamingPlatform platform;
  final String? apiKey;
  final String region;
  final AppLogger _logger;

  /// Initialize the platform service
  Future<void> initialize() async {
    _logger.info('Initializing ${platform.name} service for region: $region');
    // Platform-specific initialization logic would go here
  }

  /// Check movie availability on this platform
  Future<PlatformAvailability?> checkMovieAvailability(
      int movieId, String movieTitle) async {
    try {
      // This would integrate with actual platform APIs
      // For now, return mock data based on platform
      return _getMockAvailability(movieId, movieTitle);
    } catch (e) {
      _logger.error('Failed to check availability on ${platform.name}',
          error: e);
      return null;
    }
  }

  /// Launch the platform app
  Future<bool> launchApp({String? movieId, String? deepLink}) async {
    try {
      // This would use url_launcher or similar to open the app
      final url = deepLink ?? _buildDeepLink(movieId);
      _logger.info('Launching ${platform.name} with URL: $url');

      // Mock implementation - would use actual URL launcher
      return true;
    } catch (e) {
      _logger.error('Failed to launch ${platform.name} app', error: e);
      return false;
    }
  }

  /// Search for content on this platform
  Future<List<StreamingSearchResult>> searchContent(
      String query, ContentType? contentType) async {
    try {
      // This would integrate with platform search APIs
      return _getMockSearchResults(query, contentType);
    } catch (e) {
      _logger.error('Failed to search on ${platform.name}', error: e);
      return [];
    }
  }

  /// Build deep link URL
  String _buildDeepLink(String? movieId) {
    if (movieId == null) return platform.baseUrl;

    switch (platform.id) {
      case 'netflix':
        return '${platform.deepLinkScheme}://title/$movieId';
      case 'amazon_prime':
        return '${platform.deepLinkScheme}://dp/$movieId';
      case 'disney_plus':
        return '${platform.deepLinkScheme}://content/$movieId';
      default:
        return '${platform.baseUrl}/watch/$movieId';
    }
  }

  /// Get mock availability data (replace with real API integration)
  PlatformAvailability _getMockAvailability(int movieId, String movieTitle) {
    // Mock data - in real implementation, this would call platform APIs
    final random = movieId % 4;

    return PlatformAvailability(
      platform: platform,
      isAvailable: random > 0,
      isFree: random == 1,
      requiresSubscription: random == 2,
      canRent: random == 3,
      canPurchase: random == 3,
      rentalPrice: random == 3 ? 3.99 : null,
      purchasePrice: random == 3 ? 12.99 : null,
      currency: 'USD',
      quality: 'HD',
      audioLanguages: ['en', 'es'],
      subtitleLanguages: ['en', 'es', 'fr'],
    );
  }

  /// Get mock search results (replace with real API integration)
  List<StreamingSearchResult> _getMockSearchResults(
      String query, ContentType? contentType) {
    // Mock implementation
    return [];
  }

  /// Dispose resources
  void dispose() {
    _logger.info('Disposing ${platform.name} service');
  }
}

/// Streaming-related events
class StreamingEvent {
  StreamingEvent._(this.type, this.data) : timestamp = DateTime.now();

  factory StreamingEvent.initialized(String region) {
    return StreamingEvent._(StreamingEventType.initialized, {'region': region});
  }

  factory StreamingEvent.availabilityUpdated(
      StreamingAvailability availability) {
    return StreamingEvent._(StreamingEventType.availabilityUpdated, {
      'movie_id': availability.movieId,
      'platforms_count': availability.platforms.length,
    });
  }

  factory StreamingEvent.subscriptionUpdated(Subscription subscription) {
    return StreamingEvent._(StreamingEventType.subscriptionUpdated, {
      'platform': subscription.platform.id,
      'status': subscription.status.name,
    });
  }
  final StreamingEventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
}

enum StreamingEventType {
  initialized,
  availabilityUpdated,
  subscriptionUpdated,
}

/// Search result from streaming platforms
class StreamingSearchResult {
  const StreamingSearchResult({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    required this.type,
    required this.platform,
    required this.availability,
    this.rating,
    this.year,
  });
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final ContentType type;
  final StreamingPlatform platform;
  final PlatformAvailability availability;
  final double? rating;
  final int? year;
}

enum ContentType {
  movie,
  tvShow,
  documentary,
  anime,
}
