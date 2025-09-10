import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/movie.dart';
import '../../domain/entities/streaming_platform.dart';
import '../analytics/analytics_service.dart';
import '../logging/logger_factory.dart';

/// Service for handling deep links to streaming platforms
class DeepLinkService {
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  static final DeepLinkService _instance = DeepLinkService._internal();
  final AnalyticsService _analytics = AnalyticsService();

  /// Launch a streaming platform with optional movie context
  Future<bool> launchPlatform({
    required StreamingPlatform platform,
    Movie? movie,
    String? deepLink,
    Map<String, dynamic>? additionalParams,
  }) async {
    try {
      await _analytics.trackEvent(
        AnalyticsEventType.userEngagement,
        {
          'action': 'deep_link_launch_attempt',
          'platform': platform.name,
          'platform_id': platform.id,
          'movie_title': movie?.title ?? 'none',
          'has_deep_link': deepLink != null,
          'has_additional_params': additionalParams?.isNotEmpty ?? false,
        },
      );

      // Try deep link first if provided
      if (deepLink != null) {
        final success = await _launchUrl(deepLink, 'deep_link');
        if (success) {
          await _trackSuccessfulLaunch(platform, movie, 'deep_link');
          return true;
        }
      }

      // Try platform-specific deep link
      final platformDeepLink = _buildPlatformDeepLink(
        platform: platform,
        movie: movie,
        additionalParams: additionalParams,
      );

      if (platformDeepLink != null) {
        final success =
            await _launchUrl(platformDeepLink, 'platform_deep_link');
        if (success) {
          await _trackSuccessfulLaunch(platform, movie, 'platform_deep_link');
          return true;
        }
      }

      // Try app store link
      final appStoreLink = _getAppStoreLink(platform);
      if (appStoreLink != null) {
        final success = await _launchUrl(appStoreLink, 'app_store');
        if (success) {
          await _trackSuccessfulLaunch(platform, movie, 'app_store');
          return true;
        }
      }

      // Fallback to web URL
      final webUrl = _getWebFallbackUrl(platform);
      if (webUrl != null) {
        final success = await _launchUrl(webUrl, 'web_fallback');
        if (success) {
          await _trackSuccessfulLaunch(platform, movie, 'web_fallback');
          return true;
        }
      }

      LoggerFactory.warning(
          'No launch method succeeded for platform: ${platform.name}');
      return false;
    } catch (e) {
      LoggerFactory.error('Failed to launch platform ${platform.name}: $e');
      await _analytics.trackEvent(
        AnalyticsEventType.error,
        {
          'action': 'deep_link_launch_error',
          'platform': platform.name,
          'error': e.toString(),
        },
      );
      return false;
    }
  }

  /// Build platform-specific deep link
  String? _buildPlatformDeepLink({
    required StreamingPlatform platform,
    Movie? movie,
    Map<String, dynamic>? additionalParams,
  }) {
    switch (platform.id.toLowerCase()) {
      case 'netflix':
        return _buildNetflixDeepLink(movie, additionalParams);
      case 'prime_video':
      case 'amazon_prime':
        return _buildPrimeVideoDeepLink(movie, additionalParams);
      case 'disney_plus':
      case 'disneyplus':
        return _buildDisneyPlusDeepLink(movie, additionalParams);
      case 'hbo_max':
      case 'hbomax':
        return _buildHBOMaxDeepLink(movie, additionalParams);
      case 'apple_tv':
      case 'appletv':
        return _buildAppleTVDeepLink(movie, additionalParams);
      case 'hulu':
        return _buildHuluDeepLink(movie, additionalParams);
      case 'paramount_plus':
      case 'paramountplus':
        return _buildParamountPlusDeepLink(movie, additionalParams);
      default:
        return null;
    }
  }

  String? _buildNetflixDeepLink(Movie? movie, Map<String, dynamic>? params) {
    if (movie?.externalIds?['netflix'] != null) {
      return 'netflix://title/${movie!.externalIds!['netflix']}';
    }
    if (movie?.title != null) {
      final query = Uri.encodeComponent(movie!.title);
      return 'netflix://search?q=$query';
    }
    return 'netflix://home';
  }

  String? _buildPrimeVideoDeepLink(Movie? movie, Map<String, dynamic>? params) {
    if (movie?.externalIds?['amazon'] != null) {
      return 'aiv://aiv/view?gti=${movie!.externalIds!['amazon']}';
    }
    if (movie?.title != null) {
      final query = Uri.encodeComponent(movie!.title);
      return 'aiv://aiv/search?phrase=$query';
    }
    return 'aiv://aiv/home';
  }

  String? _buildDisneyPlusDeepLink(Movie? movie, Map<String, dynamic>? params) {
    if (movie?.externalIds?['disney'] != null) {
      return 'disneyplus://content/${movie!.externalIds!['disney']}';
    }
    if (movie?.title != null) {
      final query = Uri.encodeComponent(movie!.title);
      return 'disneyplus://search?q=$query';
    }
    return 'disneyplus://home';
  }

  String? _buildHBOMaxDeepLink(Movie? movie, Map<String, dynamic>? params) {
    if (movie?.externalIds?['hbo'] != null) {
      return 'hbomax://content/${movie!.externalIds!['hbo']}';
    }
    if (movie?.title != null) {
      final query = Uri.encodeComponent(movie!.title);
      return 'hbomax://search?q=$query';
    }
    return 'hbomax://home';
  }

  String? _buildAppleTVDeepLink(Movie? movie, Map<String, dynamic>? params) {
    if (movie?.externalIds?['apple'] != null) {
      return 'com.apple.tv://content/${movie!.externalIds!['apple']}';
    }
    if (movie?.title != null) {
      final query = Uri.encodeComponent(movie!.title);
      return 'com.apple.tv://search?term=$query';
    }
    return 'com.apple.tv://home';
  }

  String? _buildHuluDeepLink(Movie? movie, Map<String, dynamic>? params) {
    if (movie?.externalIds?['hulu'] != null) {
      return 'hulu://content/${movie!.externalIds!['hulu']}';
    }
    if (movie?.title != null) {
      final query = Uri.encodeComponent(movie!.title);
      return 'hulu://search?q=$query';
    }
    return 'hulu://home';
  }

  String? _buildParamountPlusDeepLink(
      Movie? movie, Map<String, dynamic>? params) {
    if (movie?.externalIds?['paramount'] != null) {
      return 'paramountplus://content/${movie!.externalIds!['paramount']}';
    }
    if (movie?.title != null) {
      final query = Uri.encodeComponent(movie!.title);
      return 'paramountplus://search?q=$query';
    }
    return 'paramountplus://home';
  }

  /// Get app store link for platform
  String? _getAppStoreLink(StreamingPlatform platform) {
    if (Platform.isIOS) {
      return _getIOSAppStoreLink(platform);
    } else if (Platform.isAndroid) {
      return _getAndroidAppStoreLink(platform);
    }
    return null;
  }

  String? _getIOSAppStoreLink(StreamingPlatform platform) {
    switch (platform.id.toLowerCase()) {
      case 'netflix':
        return 'https://apps.apple.com/app/netflix/id363590051';
      case 'prime_video':
      case 'amazon_prime':
        return 'https://apps.apple.com/app/amazon-prime-video/id545519333';
      case 'disney_plus':
      case 'disneyplus':
        return 'https://apps.apple.com/app/disney/id1446075923';
      case 'hbo_max':
      case 'hbomax':
        return 'https://apps.apple.com/app/hbo-max/id971265422';
      case 'apple_tv':
      case 'appletv':
        return 'https://apps.apple.com/app/apple-tv/id1174078549';
      case 'hulu':
        return 'https://apps.apple.com/app/hulu/id376510438';
      case 'paramount_plus':
      case 'paramountplus':
        return 'https://apps.apple.com/app/paramount/id1320318421';
      default:
        return null;
    }
  }

  String? _getAndroidAppStoreLink(StreamingPlatform platform) {
    switch (platform.id.toLowerCase()) {
      case 'netflix':
        return 'https://play.google.com/store/apps/details?id=com.netflix.mediaclient';
      case 'prime_video':
      case 'amazon_prime':
        return 'https://play.google.com/store/apps/details?id=com.amazon.avod.thirdpartyclient';
      case 'disney_plus':
      case 'disneyplus':
        return 'https://play.google.com/store/apps/details?id=com.disney.disneyplus';
      case 'hbo_max':
      case 'hbomax':
        return 'https://play.google.com/store/apps/details?id=com.hbo.hbonow';
      case 'hulu':
        return 'https://play.google.com/store/apps/details?id=com.hulu.plus';
      case 'paramount_plus':
      case 'paramountplus':
        return 'https://play.google.com/store/apps/details?id=com.cbs.app';
      default:
        return null;
    }
  }

  /// Get web fallback URL
  String? _getWebFallbackUrl(StreamingPlatform platform) {
    switch (platform.id.toLowerCase()) {
      case 'netflix':
        return 'https://www.netflix.com';
      case 'prime_video':
      case 'amazon_prime':
        return 'https://www.amazon.com/Prime-Video';
      case 'disney_plus':
      case 'disneyplus':
        return 'https://www.disneyplus.com';
      case 'hbo_max':
      case 'hbomax':
        return 'https://www.hbomax.com';
      case 'apple_tv':
      case 'appletv':
        return 'https://tv.apple.com';
      case 'hulu':
        return 'https://www.hulu.com';
      case 'paramount_plus':
      case 'paramountplus':
        return 'https://www.paramountplus.com';
      default:
        return null;
    }
  }

  /// Launch URL with proper error handling
  Future<bool> _launchUrl(String url, String method) async {
    try {
      final uri = Uri.parse(url);

      // Check if URL can be launched
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        LoggerFactory.info('Successfully launched URL via $method: $url');
        return true;
      } else {
        LoggerFactory.warning('Cannot launch URL via $method: $url');
        return false;
      }
    } catch (e) {
      LoggerFactory.error('Error launching URL via $method ($url): $e');
      return false;
    }
  }

  /// Track successful launch for analytics
  Future<void> _trackSuccessfulLaunch(
      StreamingPlatform platform, Movie? movie, String method) async {
    await _analytics.trackEvent(
      AnalyticsEventType.userEngagement,
      {
        'action': 'deep_link_launch_success',
        'platform': platform.name,
        'platform_id': platform.id,
        'movie_title': movie?.title ?? 'none',
        'launch_method': method,
      },
    );
  }

  /// Check if a platform app is installed (Android only)
  Future<bool> isPlatformAppInstalled(StreamingPlatform platform) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final deepLink = _buildPlatformDeepLink(platform: platform);
      if (deepLink != null) {
        final uri = Uri.parse(deepLink);
        return await canLaunchUrl(uri);
      }
      return false;
    } catch (e) {
      LoggerFactory.error('Error checking if platform app is installed: $e');
      return false;
    }
  }

  /// Get available launch methods for a platform
  Future<List<String>> getAvailableLaunchMethods(
      StreamingPlatform platform) async {
    final methods = <String>[];

    // Check deep link
    final deepLink = _buildPlatformDeepLink(platform: platform);
    if (deepLink != null) {
      try {
        final uri = Uri.parse(deepLink);
        if (await canLaunchUrl(uri)) {
          methods.add('deep_link');
        }
      } catch (e) {
        // Ignore error
      }
    }

    // App store is always available
    if (_getAppStoreLink(platform) != null) {
      methods.add('app_store');
    }

    // Web fallback is always available
    if (_getWebFallbackUrl(platform) != null) {
      methods.add('web');
    }

    return methods;
  }
}
