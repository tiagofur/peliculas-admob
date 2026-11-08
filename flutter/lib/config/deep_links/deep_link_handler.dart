import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

import '../../core/analytics/analytics_service.dart';

/// Service for handling deep links and URL-based navigation
class DeepLinkHandler {
  static final _logger = Logger('DeepLinkHandler');
  static const String _appScheme = 'peliculas';
  static final _analytics = AnalyticsService();
  static bool _initialized = false;

  /// Get the initialization status
  static bool get isInitialized => _initialized;

  /// Initialize deep link handling for the application
  static void initialize(GoRouter router) {
    if (_initialized) {
      _logger.info('DeepLinkHandler already initialized, skipping');
      return;
    }

    if (kIsWeb) {
      _handleWebDeepLinks(router);
      _initialized = true;
    }
  }

  /// Handle deep links on web platform
  static void _handleWebDeepLinks(GoRouter router) {
    try {
      // Check if we're on web and handle URL-based deep links
      if (kIsWeb) {
        final currentUrl = Uri.base.toString();
        _logger.info('Current URL: $currentUrl');

        // Only parse URLs that are not the root path to avoid infinite loops
        final uri = Uri.parse(currentUrl);
        if (uri.path != '/' && uri.path.isNotEmpty) {
          _parseAndHandleUrl(currentUrl, router);
        } else {
          _logger.info('Skipping root path to avoid infinite loop');
        }
      }
    } catch (e) {
      _logger.severe('Error handling web deep links: $e');
    }
  }

  /// Parse URL and navigate to appropriate route
  static void _parseAndHandleUrl(String url, GoRouter router) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;

      _logger.info('Parsing URL path: $path');

      // Skip processing for root path or empty path
      if (path == '/' || path.isEmpty) {
        _logger.info('Skipping root/empty path: $path');
        return;
      }

      // Handle share URLs - redirect to main app routes
      if (path.contains('/share')) {
        final cleanPath = path.replaceAll('/share', '');
        _handleShareUrl(cleanPath, router);
      }
      // Handle direct movie URLs
      else if (path.startsWith('/movie/')) {
        _handleMovieUrl(path, router);
      }
      // Handle list URLs
      else if (path.startsWith('/list/')) {
        _handleListUrl(path, router);
      }
      // Handle recommendation URLs
      else if (path.startsWith('/recommendations/')) {
        _handleRecommendationUrl(path, router);
      } else {
        _logger.info('No special handling needed for path: $path');
      }
    } catch (e) {
      _logger.warning('Error parsing URL: $url, error: $e');
    }
  }

  /// Handle share URLs by redirecting to main app routes
  static void _handleShareUrl(String cleanPath, GoRouter router) {
    try {
      if (cleanPath.startsWith('/movie/')) {
        final movieId = _extractMovieId(cleanPath);
        if (movieId != null) {
          _logger.info('Redirecting from share URL to movie: $movieId');
          router.go('/movie/$movieId');
          _trackDeepLinkEvent('movie_share_redirect', {'movie_id': movieId});
        }
      } else if (cleanPath.startsWith('/list/')) {
        final listId = _extractListId(cleanPath);
        if (listId != null) {
          _logger.info('Redirecting from share URL to list: $listId');
          router.go('/my-library/lists/$listId');
          _trackDeepLinkEvent('list_share_redirect', {'list_id': listId});
        }
      } else if (cleanPath.startsWith('/recommendations/')) {
        final pathSegments = cleanPath.split('/');
        if (pathSegments.length >= 4) {
          final type = pathSegments[2];
          final id = pathSegments[3];
          _logger
              .info('Redirecting from share URL to recommendation: $type/$id');
          router.go('/recommendations/$type/$id');
          _trackDeepLinkEvent('recommendation_share_redirect', {
            'type': type,
            'id': id,
          });
        }
      }
    } catch (e) {
      _logger.warning('Error handling share URL: $cleanPath, error: $e');
    }
  }

  /// Handle direct movie URLs
  static void _handleMovieUrl(String path, GoRouter router) {
    try {
      final movieId = _extractMovieId(path);
      if (movieId != null) {
        _logger.info('Handling direct movie URL: $movieId');
        router.go('/movie/$movieId');
        _trackDeepLinkEvent('movie_direct_link', {'movie_id': movieId});
      }
    } catch (e) {
      _logger.warning('Error handling movie URL: $path, error: $e');
    }
  }

  /// Handle list URLs
  static void _handleListUrl(String path, GoRouter router) {
    try {
      final listId = _extractListId(path);
      if (listId != null) {
        _logger.info('Handling direct list URL: $listId');
        router.go('/my-library/lists/$listId');
        _trackDeepLinkEvent('list_direct_link', {'list_id': listId});
      }
    } catch (e) {
      _logger.warning('Error handling list URL: $path, error: $e');
    }
  }

  /// Handle recommendation URLs
  static void _handleRecommendationUrl(String path, GoRouter router) {
    try {
      final pathSegments = path.split('/');
      if (pathSegments.length >= 4) {
        final type = pathSegments[2];
        final id = pathSegments[3];
        _logger.info('Handling direct recommendation URL: $type/$id');
        router.go('/recommendations/$type/$id');
        _trackDeepLinkEvent('recommendation_direct_link', {
          'type': type,
          'id': id,
        });
      }
    } catch (e) {
      _logger.warning('Error handling recommendation URL: $path, error: $e');
    }
  }

  /// Extract movie ID from path
  static String? _extractMovieId(String path) {
    try {
      final pathSegments = path.split('/');
      if (pathSegments.length >= 3 && pathSegments[1] == 'movie') {
        return pathSegments[2];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Extract list ID from path
  static String? _extractListId(String path) {
    try {
      final pathSegments = path.split('/');
      if (pathSegments.length >= 3 && pathSegments[1] == 'list') {
        return pathSegments[2];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Generate app scheme deep link URL
  static String generateAppDeepLink({
    required String contentType, // 'movie', 'list', 'recommendations'
    required String contentId,
    String? action,
    Map<String, String>? parameters,
  }) {
    final buffer = StringBuffer('$_appScheme://$contentType/$contentId');

    if (action != null) {
      buffer.write('/$action');
    }

    if (parameters != null && parameters.isNotEmpty) {
      final params = parameters.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      buffer.write('?$params');
    }

    return buffer.toString();
  }

  /// Generate movie deep link
  static String generateMovieDeepLink(String movieId, {String? action}) {
    return generateAppDeepLink(
      contentType: 'movie',
      contentId: movieId,
      action: action,
    );
  }

  /// Generate list deep link
  static String generateListDeepLink(String listId, {String? action}) {
    return generateAppDeepLink(
      contentType: 'list',
      contentId: listId,
      action: action,
    );
  }

  /// Generate recommendation deep link
  static String generateRecommendationDeepLink(
    String type,
    String id, {
    String? action,
  }) {
    return generateAppDeepLink(
      contentType: 'recommendations/$type',
      contentId: id,
      action: action,
    );
  }

  /// Validate if URL is a valid app deep link
  static bool isValidDeepLink(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.scheme == _appScheme;
    } catch (e) {
      return false;
    }
  }

  /// Check if URL is a share URL that should redirect to main app
  static bool isShareUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.path.contains('/share');
    } catch (e) {
      return false;
    }
  }

  /// Track deep link analytics event
  static void _trackDeepLinkEvent(
      String eventName, Map<String, dynamic> parameters) {
    try {
      _analytics.trackEvent(
        AnalyticsEventType.userEngagement,
        {
          'event_name': eventName,
          'source': 'deep_link',
          ...parameters,
        },
      );
    } catch (e) {
      _logger.warning('Error tracking deep link event: $e');
    }
  }
}
