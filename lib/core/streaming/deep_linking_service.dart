import 'dart:async';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/streaming_platform.dart';
import '../analytics/analytics_service.dart';
import '../logging/logger_factory.dart';

/// Service for handling deep links to streaming platforms
class DeepLinkingService {
  DeepLinkingService({
    AnalyticsService? analyticsService,
  }) : _analyticsService = analyticsService ?? AnalyticsService();
  final AnalyticsService _analyticsService;
  static final _logger = LoggerFactory.logger;

  /// Launch streaming app with deep link
  Future<bool> launchStreamingApp({
    required StreamingPlatform platform,
    required String movieId,
    String? tmdbId,
    Map<String, String>? additionalParams,
  }) async {
    try {
      _logger.info('Launching ${platform.name} app for movie: $movieId');

      final deepLink = _generateDeepLink(
        platform: platform,
        movieId: movieId,
        tmdbId: tmdbId,
        additionalParams: additionalParams,
      );

      final launched = await _launchUrl(deepLink);

      if (launched) {
        _analyticsService.trackEvent(
          AnalyticsEventType.appLaunch,
          {
            'platform': platform.id,
            'movie_id': movieId,
            'tmdb_id': tmdbId,
            'deep_link': deepLink,
            'success': true,
          },
        );
      } else {
        // Try fallback to web version
        final webLaunched = await _launchWebFallback(
          platform: platform,
          movieId: movieId,
          tmdbId: tmdbId,
        );

        _analyticsService.trackEvent(
          AnalyticsEventType.error,
          {
            'platform': platform.id,
            'movie_id': movieId,
            'deep_link': deepLink,
            'web_fallback_success': webLaunched,
          },
        );

        return webLaunched;
      }

      return launched;
    } catch (e) {
      _logger.error('Error launching streaming app: $e');
      _analyticsService.trackEvent(
        AnalyticsEventType.error,
        {
          'platform': platform.id,
          'movie_id': movieId,
          'error': e.toString(),
        },
      );
      return false;
    }
  }

  /// Launch streaming platform's main app
  Future<bool> launchPlatformApp(StreamingPlatform platform) async {
    try {
      _logger.info('Launching ${platform.name} main app');

      final appScheme = _getPlatformAppScheme(platform);
      final launched = await _launchUrl(appScheme);

      if (!launched) {
        // Fallback to web version
        final webUrl = platform.baseUrl;
        return await _launchUrl(webUrl);
      }

      _analyticsService.trackEvent(
        AnalyticsEventType.appLaunch,
        {
          'platform': platform.id,
          'success': launched,
        },
      );

      return launched;
    } catch (e) {
      _logger.error('Error launching platform app: $e');
      return false;
    }
  }

  /// Check if streaming app is installed
  Future<bool> isAppInstalled(StreamingPlatform platform) async {
    try {
      final appScheme = _getPlatformAppScheme(platform);
      return await canLaunchUrl(Uri.parse(appScheme));
    } catch (e) {
      _logger.error('Error checking app installation: $e');
      return false;
    }
  }

  /// Get app store URL for installing streaming app
  String getAppStoreUrl(StreamingPlatform platform) {
    if (Platform.isIOS) {
      return _getIOSAppStoreUrl(platform);
    } else if (Platform.isAndroid) {
      return _getAndroidAppStoreUrl(platform);
    } else {
      return platform.baseUrl; // Fallback to web version
    }
  }

  /// Launch app store to install streaming app
  Future<bool> launchAppStore(StreamingPlatform platform) async {
    try {
      final storeUrl = getAppStoreUrl(platform);
      final launched = await _launchUrl(storeUrl);

      _analyticsService.trackEvent(
        AnalyticsEventType.appLaunch,
        {
          'platform': platform.id,
          'store_url': storeUrl,
          'success': launched,
        },
      );

      return launched;
    } catch (e) {
      _logger.error('Error launching app store: $e');
      return false;
    }
  }

  /// Generate deep link for specific content
  String _generateDeepLink({
    required StreamingPlatform platform,
    required String movieId,
    String? tmdbId,
    Map<String, String>? additionalParams,
  }) {
    final baseScheme = platform.deepLinkScheme;

    switch (platform.id) {
      case 'netflix':
        return '${baseScheme}title/$movieId';

      case 'amazon_prime':
        return '${baseScheme}aiv/resume?asin=$movieId';

      case 'disney_plus':
        return '${baseScheme}content/$movieId';

      case 'hbo_max':
        return '${baseScheme}content/$movieId';

      case 'hulu':
        return '${baseScheme}watch/$movieId';

      case 'apple_tv':
        return '${baseScheme}movie/$movieId';

      default:
        // Generic deep link format
        var deepLink = '${baseScheme}content/$movieId';

        // Add additional parameters if provided
        if (additionalParams != null && additionalParams.isNotEmpty) {
          final params = additionalParams.entries
              .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
              .join('&');
          deepLink += '?$params';
        }

        return deepLink;
    }
  }

  /// Get platform app scheme for launching main app
  String _getPlatformAppScheme(StreamingPlatform platform) {
    switch (platform.id) {
      case 'netflix':
        return 'netflix://';
      case 'amazon_prime':
        return 'aiv://';
      case 'disney_plus':
        return 'disneyplus://';
      case 'hbo_max':
        return 'hbomax://';
      case 'hulu':
        return 'hulu://';
      case 'apple_tv':
        return 'videos://';
      default:
        return platform.deepLinkScheme;
    }
  }

  /// Launch web fallback when app is not available
  Future<bool> _launchWebFallback({
    required StreamingPlatform platform,
    required String movieId,
    String? tmdbId,
  }) async {
    try {
      String webUrl;

      switch (platform.id) {
        case 'netflix':
          webUrl = '${platform.baseUrl}/title/$movieId';
          break;
        case 'amazon_prime':
          webUrl = '${platform.baseUrl}/detail/$movieId';
          break;
        case 'disney_plus':
          webUrl = '${platform.baseUrl}/movies/$movieId';
          break;
        case 'hbo_max':
          webUrl = '${platform.baseUrl}/feature/$movieId';
          break;
        default:
          webUrl = platform.baseUrl;
      }

      return await _launchUrl(webUrl);
    } catch (e) {
      _logger.error('Error launching web fallback: $e');
      return false;
    }
  }

  /// Get iOS App Store URL
  String _getIOSAppStoreUrl(StreamingPlatform platform) {
    switch (platform.id) {
      case 'netflix':
        return 'https://apps.apple.com/app/netflix/id363590051';
      case 'amazon_prime':
        return 'https://apps.apple.com/app/amazon-prime-video/id545519333';
      case 'disney_plus':
        return 'https://apps.apple.com/app/disney/id1446075923';
      case 'hbo_max':
        return 'https://apps.apple.com/app/hbo-max/id971265422';
      case 'hulu':
        return 'https://apps.apple.com/app/hulu/id376510438';
      case 'apple_tv':
        return 'https://apps.apple.com/app/apple-tv/id1174078549';
      default:
        return 'https://apps.apple.com';
    }
  }

  /// Get Android Play Store URL
  String _getAndroidAppStoreUrl(StreamingPlatform platform) {
    switch (platform.id) {
      case 'netflix':
        return 'https://play.google.com/store/apps/details?id=com.netflix.mediaclient';
      case 'amazon_prime':
        return 'https://play.google.com/store/apps/details?id=com.amazon.avod.thirdpartyclient';
      case 'disney_plus':
        return 'https://play.google.com/store/apps/details?id=com.disney.disneyplus';
      case 'hbo_max':
        return 'https://play.google.com/store/apps/details?id=com.hbo.hbonow';
      case 'hulu':
        return 'https://play.google.com/store/apps/details?id=com.hulu.plus';
      case 'apple_tv':
        return 'https://play.google.com/store/apps/details?id=com.apple.atve.androidtv.appletv';
      default:
        return 'https://play.google.com/store';
    }
  }

  /// Launch URL with proper error handling
  Future<bool> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      _logger.error('Error launching URL $url: $e');
      return false;
    }
  }

  /// Create deep link with custom parameters
  DeepLink createCustomDeepLink({
    required StreamingPlatform platform,
    required String contentId,
    DeepLinkAction? action,
    Map<String, String>? parameters,
  }) {
    final baseScheme = platform.deepLinkScheme;
    var url = baseScheme;

    // Add action if specified
    if (action != null) {
      url += action.path;
    }

    // Add content ID
    url += contentId;

    // Add parameters
    if (parameters != null && parameters.isNotEmpty) {
      final params = parameters.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      url += '?$params';
    }

    return DeepLink(
      platform: platform,
      url: url,
      contentId: contentId,
      action: action,
      parameters: parameters ?? {},
    );
  }
}

/// Deep link model
class DeepLink {
  const DeepLink({
    required this.platform,
    required this.url,
    required this.contentId,
    this.action,
    required this.parameters,
  });
  final StreamingPlatform platform;
  final String url;
  final String contentId;
  final DeepLinkAction? action;
  final Map<String, String> parameters;

  /// Launch this deep link
  Future<bool> launch() async {
    final service = DeepLinkingService();
    return await service._launchUrl(url);
  }

  @override
  String toString() => url;
}

/// Deep link actions
enum DeepLinkAction {
  play,
  watch,
  resume,
  details,
  search,
  home,
}

extension DeepLinkActionExtension on DeepLinkAction {
  String get path {
    switch (this) {
      case DeepLinkAction.play:
        return 'play/';
      case DeepLinkAction.watch:
        return 'watch/';
      case DeepLinkAction.resume:
        return 'resume/';
      case DeepLinkAction.details:
        return 'details/';
      case DeepLinkAction.search:
        return 'search/';
      case DeepLinkAction.home:
        return '';
    }
  }
}
