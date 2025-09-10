/// Streaming platform services for individual platform integrations
///
/// This library provides specialized services for each major streaming platform,
/// including availability checking, content search, deep linking, and subscription management.
library;

import 'package:http/http.dart' as http;
import '../../../domain/entities/movie.dart';
import '../../../domain/entities/streaming_availability.dart';
import '../../analytics/analytics_service.dart';

import '../real_availability_service.dart';
import 'disney_plus_service.dart';
import 'hbo_max_service.dart';
// SubscriptionPlan is defined in netflix_service.dart
import 'netflix_service.dart';
import 'prime_video_service.dart';

export 'disney_plus_service.dart';
export 'hbo_max_service.dart';
export 'netflix_service.dart';
export 'prime_video_service.dart';

/// Platform service factory for creating streaming service instances
class StreamingPlatformServiceFactory {
  /// Create a Netflix service instance
  static NetflixService createNetflixService({
    required AnalyticsService analytics,
    required RealAvailabilityService availabilityService,
  }) {
    return NetflixService(
      analytics: analytics,
      availabilityService: availabilityService,
    );
  }

  /// Create a Prime Video service instance
  static PrimeVideoService createPrimeVideoService({
    required AnalyticsService analytics,
    required RealAvailabilityService availabilityService,
  }) {
    return PrimeVideoService(
      analytics: analytics,
      availabilityService: availabilityService,
    );
  }

  /// Create a Disney+ service instance
  static DisneyPlusService createDisneyPlusService({
    required http.Client httpClient,
    required AnalyticsService analytics,
    required RealAvailabilityService availabilityService,
  }) {
    return DisneyPlusService(
      httpClient: httpClient,
      analytics: analytics,
      availabilityService: availabilityService,
    );
  }

  /// Create an HBO Max service instance
  static HboMaxService createHBOMaxService({
    required AnalyticsService analytics,
    required RealAvailabilityService availabilityService,
  }) {
    return HboMaxService(
      analytics: analytics,
      availabilityService: availabilityService,
    );
  }

  /// Create all platform services
  static Map<String, dynamic> createAllServices({
    required AnalyticsService analytics,
    required RealAvailabilityService availabilityService,
    http.Client? httpClient,
  }) {
    final client = httpClient ?? http.Client();
    
    return {
      'netflix': createNetflixService(
        analytics: analytics,
        availabilityService: availabilityService,
      ),
      'prime_video': createPrimeVideoService(
        analytics: analytics,
        availabilityService: availabilityService,
      ),
      'disney_plus': createDisneyPlusService(
        httpClient: client,
        analytics: analytics,
        availabilityService: availabilityService,
      ),
      'hbo_max': createHBOMaxService(
        analytics: analytics,
        availabilityService: availabilityService,
      ),
    };
  }

  /// Get supported platform IDs
  static List<String> getSupportedPlatforms() {
    return ['netflix', 'prime_video', 'disney_plus', 'hbo_max'];
  }

  /// Check if a platform is supported
  static bool isPlatformSupported(String platformId) {
    return getSupportedPlatforms().contains(platformId.toLowerCase());
  }
}

/// Platform service interface for common operations
abstract class StreamingPlatformServiceInterface {
  /// Check movie availability on the platform
  Future<PlatformAvailability?> checkMovieAvailability({
    required String movieId,
    required String tmdbId,
    String region = 'US',
  });

  /// Search for content on the platform
  Future<List<Movie>> searchContent({
    required String query,
    String region = 'US',
    int limit = 20,
  });

  /// Generate deep link to the platform
  String generateDeepLink({
    required String movieId,
    String? tmdbId,
  });

  /// Get subscription plans for the platform
  Future<List<SubscriptionPlan>> getSubscriptionPlans({
    String region = 'US',
  });

  /// Dispose resources
  void dispose();
}

/// Platform service capabilities
class PlatformCapabilities {
  const PlatformCapabilities({
    required this.supportsSearch,
    required this.supportsDeepLinking,
    required this.supportsSubscriptions,
    required this.supportsRental,
    required this.supportsPurchase,
    required this.supportsFreeContent,
    required this.supportsOfflineDownload,
    required this.supports4K,
    required this.supportsHDR,
    required this.supportsDolbyAtmos,
    required this.supportedRegions,
    required this.supportedLanguages,
  });
  final bool supportsSearch;
  final bool supportsDeepLinking;
  final bool supportsSubscriptions;
  final bool supportsRental;
  final bool supportsPurchase;
  final bool supportsFreeContent;
  final bool supportsOfflineDownload;
  final bool supports4K;
  final bool supportsHDR;
  final bool supportsDolbyAtmos;
  final List<String> supportedRegions;
  final List<String> supportedLanguages;

  /// Netflix capabilities
  static const netflix = PlatformCapabilities(
    supportsSearch: true,
    supportsDeepLinking: true,
    supportsSubscriptions: true,
    supportsRental: false,
    supportsPurchase: false,
    supportsFreeContent: false,
    supportsOfflineDownload: true,
    supports4K: true,
    supportsHDR: true,
    supportsDolbyAtmos: true,
    supportedRegions: [
      'US',
      'CA',
      'UK',
      'AU',
      'DE',
      'FR',
      'ES',
      'IT',
      'BR',
      'MX'
    ],
    supportedLanguages: ['en', 'es', 'fr', 'de', 'it', 'pt', 'ja', 'ko'],
  );

  /// Prime Video capabilities
  static const primeVideo = PlatformCapabilities(
    supportsSearch: true,
    supportsDeepLinking: true,
    supportsSubscriptions: true,
    supportsRental: true,
    supportsPurchase: true,
    supportsFreeContent: true,
    supportsOfflineDownload: true,
    supports4K: true,
    supportsHDR: true,
    supportsDolbyAtmos: true,
    supportedRegions: [
      'US',
      'CA',
      'UK',
      'AU',
      'DE',
      'FR',
      'ES',
      'IT',
      'BR',
      'MX',
      'IN',
      'JP'
    ],
    supportedLanguages: ['en', 'es', 'fr', 'de', 'it', 'pt', 'ja', 'ko', 'hi'],
  );

  /// Disney+ capabilities
  static const disneyPlus = PlatformCapabilities(
    supportsSearch: true,
    supportsDeepLinking: true,
    supportsSubscriptions: true,
    supportsRental: false,
    supportsPurchase: false,
    supportsFreeContent: false,
    supportsOfflineDownload: true,
    supports4K: true,
    supportsHDR: true,
    supportsDolbyAtmos: true,
    supportedRegions: [
      'US',
      'CA',
      'UK',
      'AU',
      'DE',
      'FR',
      'ES',
      'IT',
      'NL',
      'BE'
    ],
    supportedLanguages: ['en', 'es', 'fr', 'de', 'it', 'pt', 'nl'],
  );

  /// HBO Max capabilities
  static const hboMax = PlatformCapabilities(
    supportsSearch: true,
    supportsDeepLinking: true,
    supportsSubscriptions: true,
    supportsRental: false,
    supportsPurchase: false,
    supportsFreeContent: false,
    supportsOfflineDownload: true,
    supports4K: true,
    supportsHDR: true,
    supportsDolbyAtmos: true,
    supportedRegions: ['US', 'CA', 'MX', 'BR'],
    supportedLanguages: ['en', 'es', 'pt'],
  );

  /// Get capabilities for a platform
  static PlatformCapabilities? getCapabilities(String platformId) {
    switch (platformId.toLowerCase()) {
      case 'netflix':
        return netflix;
      case 'prime_video':
      case 'amazon_prime':
        return primeVideo;
      case 'disney_plus':
      case 'disneyplus':
        return disneyPlus;
      case 'hbo_max':
      case 'hbomax':
        return hboMax;
      default:
        return null;
    }
  }
}
