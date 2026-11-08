// Streaming Services Export File
// This file provides a centralized export for all streaming-related services and entities

// Core streaming services
import '../../domain/entities/streaming_availability.dart';
import '../../domain/entities/streaming_platform.dart';

export '../../domain/entities/streaming_availability.dart';
// Domain entities
export '../../domain/entities/streaming_platform.dart';
export '../../domain/entities/subscription.dart';
export 'availability_checker.dart';
export 'deep_linking_service.dart';
export 'platform_services/disney_plus_service.dart';
export 'platform_services/hbo_max_service.dart';
export 'platform_services/netflix_service.dart';
// Platform-specific services
export 'platform_services/platform_services.dart';
export 'platform_services/prime_video_service.dart';
export 'streaming_service_manager.dart';

// Streaming utilities and helpers
class StreamingUtils {
  /// Get all supported streaming platforms
  static List<StreamingPlatform> getAllPlatforms() {
    return [
      StreamingPlatform.netflix,
      StreamingPlatform.amazonPrime,
      StreamingPlatform.disneyPlus,
      StreamingPlatform.hboMax,
      StreamingPlatform.hulu,
      StreamingPlatform.appleTV,
    ];
  }

  /// Get platforms that require subscription
  static List<StreamingPlatform> getSubscriptionPlatforms() {
    return getAllPlatforms()
        .where((platform) => platform.requiresSubscription)
        .toList();
  }

  /// Get platforms by region
  static List<StreamingPlatform> getPlatformsByRegion(String region) {
    return getAllPlatforms()
        .where((platform) => platform.supportedCountries.contains(region))
        .toList();
  }

  /// Check if platform is available in region
  static bool isPlatformAvailableInRegion(
    StreamingPlatform platform,
    String region,
  ) {
    return platform.supportedCountries.contains(region);
  }

  /// Get platform by ID
  static StreamingPlatform? getPlatformById(String id) {
    try {
      return getAllPlatforms().firstWhere((platform) => platform.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Format price for display
  static String formatPrice(double? price, String currency) {
    if (price == null) return 'N/A';

    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$${price.toStringAsFixed(2)}';
      case 'EUR':
        return '€${price.toStringAsFixed(2)}';
      case 'GBP':
        return '£${price.toStringAsFixed(2)}';
      default:
        return '${price.toStringAsFixed(2)} $currency';
    }
  }

  /// Get availability summary text
  static String getAvailabilitySummary(StreamingAvailability availability) {
    final availablePlatforms =
        availability.platforms.where((p) => p.isAvailable).toList();

    if (availablePlatforms.isEmpty) {
      return 'Not available on any streaming platform';
    }

    final freePlatforms = availablePlatforms.where((p) => p.isFree).length;
    final subscriptionPlatforms = availablePlatforms
        .where((p) => p.requiresSubscription && !p.isFree)
        .length;
    final rentalPlatforms = availablePlatforms.where((p) => p.canRent).length;

    final List<String> parts = [];

    if (freePlatforms > 0) {
      parts.add(
          'Free on $freePlatforms platform${freePlatforms > 1 ? 's' : ''}');
    }

    if (subscriptionPlatforms > 0) {
      parts.add(
          'Subscription on $subscriptionPlatforms platform${subscriptionPlatforms > 1 ? 's' : ''}');
    }

    if (rentalPlatforms > 0) {
      parts.add(
          'Rental on $rentalPlatforms platform${rentalPlatforms > 1 ? 's' : ''}');
    }

    return parts.join(' • ');
  }

  /// Get best availability option (prioritizes free, then subscription, then rental)
  static PlatformAvailability? getBestAvailability(
    StreamingAvailability availability,
  ) {
    final availablePlatforms =
        availability.platforms.where((p) => p.isAvailable).toList();

    if (availablePlatforms.isEmpty) return null;

    // Prioritize free content
    final freePlatforms = availablePlatforms.where((p) => p.isFree).toList();
    if (freePlatforms.isNotEmpty) {
      return freePlatforms.first;
    }

    // Then subscription content
    final subscriptionPlatforms = availablePlatforms
        .where((p) => p.requiresSubscription && !p.isFree)
        .toList();
    if (subscriptionPlatforms.isNotEmpty) {
      return subscriptionPlatforms.first;
    }

    // Finally rental content
    final rentalPlatforms = availablePlatforms.where((p) => p.canRent).toList();
    if (rentalPlatforms.isNotEmpty) {
      // Sort by rental price (lowest first)
      rentalPlatforms.sort((a, b) {
        final priceA = a.rentalPrice ?? double.infinity;
        final priceB = b.rentalPrice ?? double.infinity;
        return priceA.compareTo(priceB);
      });
      return rentalPlatforms.first;
    }

    return availablePlatforms.first;
  }
}

// Streaming constants
class StreamingConstants {
  static const String defaultRegion = 'US';
  static const Duration availabilityCacheDuration = Duration(hours: 6);
  static const Duration subscriptionCacheDuration = Duration(hours: 1);
  static const int maxConcurrentAvailabilityChecks = 5;

  // Deep link schemes
  static const Map<String, String> deepLinkSchemes = {
    'netflix': 'netflix://',
    'amazon_prime': 'aiv://',
    'disney_plus': 'disneyplus://',
    'hbo_max': 'hbomax://',
    'hulu': 'hulu://',
    'apple_tv': 'videos://',
  };

  // Quality options
  static const List<String> supportedQualities = [
    'SD',
    'HD',
    '4K',
    '8K',
  ];

  // Supported languages
  static const List<String> commonLanguages = [
    'en', // English
    'es', // Spanish
    'fr', // French
    'de', // German
    'it', // Italian
    'pt', // Portuguese
    'ja', // Japanese
    'ko', // Korean
    'zh', // Chinese
  ];
}
