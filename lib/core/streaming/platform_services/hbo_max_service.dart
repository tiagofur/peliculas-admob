import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../../../domain/entities/streaming_availability.dart';
import '../../../domain/entities/streaming_platform.dart';

import '../streaming_api_config.dart';
import '../real_availability_service.dart';
import 'platform_services.dart';
import '../../analytics/analytics_service.dart';
import '../../../domain/entities/movie.dart';

/// Service for HBO Max streaming platform integration
class HboMaxService implements StreamingPlatformServiceInterface {
  HboMaxService({
    http.Client? httpClient,
    required AnalyticsService analytics,
    required RealAvailabilityService availabilityService,
  })  : _httpClient = httpClient ?? http.Client(),
        _analytics = analytics,
        _availabilityService = availabilityService {
    _baseUrl = StreamingApiConfig.hboMaxBaseUrl;
  }

  final http.Client _httpClient;
  final AnalyticsService _analytics;

  final RealAvailabilityService _availabilityService;

  late final String _baseUrl;

  /// Check if a movie is available on HBO Max
  @override
  Future<PlatformAvailability?> checkMovieAvailability({
    required String movieId,
    required String tmdbId,
    String region = 'US',
  }) async {
    try {
      // Checking HBO Max availability for movie

      // Try RealAvailabilityService first
      final availabilityList = await _availabilityService.checkAvailability(
        movieId,
        region: region,
      );

      if (availabilityList.isNotEmpty) {
        final realAvailability = availabilityList.first;
        _analytics.trackEvent(AnalyticsEventType.userEngagement, {
          'movie_id': movieId,
          'region': region,
          'available': realAvailability.isAvailable,
          'api_used': 'real_availability_service',
        });
        return realAvailability;
      }

      // Try direct HBO Max API if configured
      if (StreamingApiConfig.isHboMaxConfigured) {
        final directAvailability = await _checkDirectHboMaxAvailability(
          tmdbId: movieId,
          region: region,
        );

        if (directAvailability != null) {
          _analytics.trackEvent(AnalyticsEventType.userEngagement, {
            'movie_id': movieId,
            'region': region,
            'available': directAvailability.isAvailable,
            'api_used': 'direct_hbo_max',
          });
          return directAvailability;
        }
      }

      // Fallback to simulation
      final simulatedAvailability = await _simulateHboMaxAvailability(
        tmdbId: movieId,
        region: region,
      );

      _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'movie_id': movieId,
        'region': region,
        'available': simulatedAvailability?.isAvailable ?? false,
        'api_used': 'simulation',
      });

      return simulatedAvailability;
    } catch (e) {
      // Error checking HBO Max availability
      _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'movie_id': movieId,
        'error': e.toString(),
      });
      return null;
    }
  }

  /// Search for content on HBO Max
  @override
  Future<List<Movie>> searchContent({
    required String query,
    String region = 'US',
    int limit = 20,
  }) async {
    try {
      // Searching HBO Max content

      // Try real API if configured
      if (StreamingApiConfig.isHboMaxConfigured) {
        final realResults = await _searchHboMaxContent(
          query: query,
          region: region,
          limit: limit,
        );

        if (realResults.isNotEmpty) {
          _analytics.trackEvent(AnalyticsEventType.userEngagement, {
            'query': query,
            'results_count': realResults.length,
            'api_used': 'real',
          });
          return realResults;
        }
      }

      // Fallback to simulation
      final simulatedResults = await _simulateHboMaxSearch(
        query: query,
        region: region,
        limit: limit,
      );

      _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'query': query,
        'results_count': simulatedResults.length,
        'api_used': 'simulation',
      });

      return simulatedResults;
    } catch (e) {
      // Error searching HBO Max content
      return [];
    }
  }

  /// Get trending content from HBO Max
  Future<List<Movie>> getTrendingContent({
    String region = 'US',
    int limit = 20,
  }) async {
    try {
      // Getting HBO Max trending content

      // Try real API if configured
      if (StreamingApiConfig.isHboMaxConfigured) {
        final realResults = await _getTrendingHboMaxContent(
          region: region,
          limit: limit,
        );

        if (realResults.isNotEmpty) {
          _analytics.trackEvent(AnalyticsEventType.userEngagement, {
            'results_count': realResults.length,
            'api_used': 'real',
          });
          return realResults;
        }
      }

      // Fallback to simulation
      final simulatedResults = await _simulateHboMaxTrending(
        region: region,
        limit: limit,
      );

      _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'results_count': simulatedResults.length,
        'api_used': 'simulation',
      });

      return simulatedResults;
    } catch (e) {
      // Error getting HBO Max trending content
      return [];
    }
  }

  /// Generate deep link for HBO Max content
  @override
  String generateDeepLink({
    required String movieId,
    String? tmdbId,
  }) {
    return 'https://play.hbomax.com/feature/urn:hbo:feature:$movieId';
  }

  /// Get available subscription plans
  @override
  Future<List<SubscriptionPlan>> getSubscriptionPlans(
      {String region = 'US'}) async {
    return [
      const SubscriptionPlan(
        id: 'hbo_max_monthly',
        name: 'HBO Max Monthly',
        price: 14.99,
        currency: 'USD',
        features: [
          'All HBO Max content',
          '4K Ultra HD',
          'Dolby Atmos audio',
          'Download for offline viewing',
          'Stream on 3 devices simultaneously',
        ],
        quality: '4K Ultra HD',
      ),
      const SubscriptionPlan(
        id: 'hbo_max_yearly',
        name: 'HBO Max Yearly',
        price: 149.99,
        currency: 'USD',
        features: [
          'All HBO Max content',
          '4K Ultra HD',
          'Dolby Atmos audio',
          'Download for offline viewing',
          'Stream on 3 devices simultaneously',
          'Save 16% vs monthly',
        ],
        quality: '4K Ultra HD',
      ),
    ];
  }

  // Real API methods
  /// Check availability directly with HBO Max API
  Future<PlatformAvailability?> _checkDirectHboMaxAvailability({
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
          .get(url, headers: StreamingApiConfig.hboMaxHeaders)
          .timeout(StreamingApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parseHboMaxAvailability(data, tmdbId);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        // HBO Max API error
        return null;
      }
    } catch (e) {
      // HBO Max direct API call failed
      return null;
    }
  }

  /// Search HBO Max content using real API
  Future<List<Movie>> _searchHboMaxContent({
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
          .get(url, headers: StreamingApiConfig.hboMaxHeaders)
          .timeout(StreamingApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parseHboMaxMovies(data['results'] as List? ?? []);
      } else {
        // HBO Max search API error
        return [];
      }
    } catch (e) {
      // HBO Max search API call failed
      return [];
    }
  }

  /// Get trending HBO Max content using real API
  Future<List<Movie>> _getTrendingHboMaxContent({
    required String region,
    required int limit,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/trending').replace(queryParameters: {
        'region': region,
        'limit': limit.toString(),
        'content_type': 'movie',
        'category': 'popular',
      });

      final response = await _httpClient
          .get(url, headers: StreamingApiConfig.hboMaxHeaders)
          .timeout(StreamingApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parseHboMaxMovies(data['results'] as List? ?? []);
      } else {
        // HBO Max trending API error
        return [];
      }
    } catch (e) {
      // HBO Max trending API call failed
      return [];
    }
  }

  /// Parse HBO Max availability response
  PlatformAvailability _parseHboMaxAvailability(
      Map<String, dynamic> data, String tmdbId) {
    final availability = data['availability'] as Map<String, dynamic>? ?? {};
    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};

    return PlatformAvailability(
      platform: StreamingPlatform.hboMax,
      isAvailable: availability['is_available'] as bool? ?? false,
      isFree: false,
      requiresSubscription: true,
      canRent: false,
      canPurchase: false,
      currency: 'USD',
      quality: metadata['video_quality'] as String? ?? '4K Dolby Vision',
      deepLink: generateDeepLink(movieId: tmdbId),
      audioLanguages:
          List<String>.from(metadata['audio_languages'] as List? ?? ['en']),
      subtitleLanguages:
          List<String>.from(metadata['subtitle_languages'] as List? ?? ['en']),
    );
  }

  /// Parse HBO Max movies response
  List<Movie> _parseHboMaxMovies(List data) {
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
  Future<PlatformAvailability?> _simulateHboMaxAvailability({
    required String tmdbId,
    required String region,
  }) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Simulate availability based on movie ID
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
      quality: '4K Dolby Vision',
      deepLink: generateDeepLink(movieId: tmdbId),
      audioLanguages: ['en', 'es', 'fr', 'de', 'pt'],
      subtitleLanguages: ['en', 'es', 'fr', 'de', 'pt', 'it'],
    );
  }

  Future<List<Movie>> _simulateHboMaxSearch({
    required String query,
    required String region,
    required int limit,
  }) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 600));

    // Generate simulated search results
    final random = math.Random();
    final resultCount = random.nextInt(limit) + 1;

    return List.generate(resultCount, (index) {
      final movieId = (random.nextInt(900000) + 100000).toString();
      final month = (index % 12 + 1).toString().padLeft(2, '0');
      return Movie(
        id: int.parse(movieId),
        title: 'HBO Max Movie ${index + 1} - $query',
        overview: 'Simulated HBO Max movie matching "$query" search query.',
        posterPath: '/simulated_poster_$movieId.jpg',
        backdropPath: '/simulated_backdrop_$movieId.jpg',
        releaseDate: DateTime.parse('2023-$month-15'),
        voteAverage: 6.0 + (random.nextDouble() * 3.0),
        voteCount: random.nextInt(5000) + 100,
        genreIds: ['28', '12', '878'], // Action, Adventure, Sci-Fi
        adult: false,
        originalLanguage: 'en',
        originalTitle: 'HBO Max Movie ${index + 1} - $query',
        popularity: random.nextDouble() * 100,
        video: false,
      );
    });
  }

  Future<List<Movie>> _simulateHboMaxTrending({
    required String region,
    required int limit,
  }) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Generate simulated trending content
    final random = math.Random();
    final trendingTitles = [
      'Game of Thrones: The Movie',
      'Succession: Origins',
      'The Last of Us: Prequel',
      'Euphoria: The Beginning',
      'True Detective: Case Zero',
      'Westworld: Genesis',
      'The White Lotus: Paradise',
      'Mare of Easttown: Before',
      'Chernobyl: Aftermath',
      'Band of Brothers: Reunion',
    ];

    final resultCount = math.min(limit, trendingTitles.length);
    return List.generate(resultCount, (index) {
      final movieId = (random.nextInt(900000) + 100000).toString();
      final month = (index % 12 + 1).toString().padLeft(2, '0');
      return Movie(
        id: int.parse(movieId),
        title: trendingTitles[index],
        overview:
            'Trending HBO Max exclusive content with premium production values.',
        posterPath: '/trending_hbo_$movieId.jpg',
        backdropPath: '/trending_hbo_backdrop_$movieId.jpg',
        releaseDate: DateTime.parse('2023-$month-01'),
        voteAverage: 7.5 + (random.nextDouble() * 2.0),
        voteCount: random.nextInt(10000) + 1000,
        genreIds: ['18', '80', '9648'], // Drama, Crime, Mystery
        adult: false,
        originalLanguage: 'en',
        originalTitle: trendingTitles[index],
        popularity: 90.0 + (random.nextDouble() * 10.0),
        video: false,
      );
    });
  }

  @override
  void dispose() {
    _httpClient.close();
  }
}
