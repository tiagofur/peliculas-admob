import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/deep_links/deep_link_handler.dart';
import '../core/analytics/analytics_service.dart';
import '../core/gamification/gamification_integration_service.dart';
import '../domain/entities/movie.dart';
import '../infrastructure/models/moviedb/movie_moviedb.dart';
import '../models/shareable_content.dart';

/// Service for handling sharing functionality across the app
class ShareService {
  static const String _baseUrl = 'https://peliculas.creapolis.dev';
  static const String _appName = 'Películas';
  static const String _appDescription =
      'Descubre, organiza y comparte tus películas favoritas';

  static GamificationIntegrationService? _gamificationService;

  /// Initialize the service with required dependencies
  static void initialize(GamificationIntegrationService gamificationService) {
    _gamificationService = gamificationService;
  }

  /// Shares a movie with its details
  static Future<void> shareMovie({
    required BuildContext context,
    required Movie movie,
    String? customMessage,
  }) async {
    final shareableContent = ShareableContent.movie(
      movieTitle: movie.title,
      movieDescription: movie.overview,
      movieId: movie.id,
      posterUrl: movie.posterPath.isNotEmpty
          ? 'https://image.tmdb.org/t/p/w500${movie.posterPath}'
          : null,
      additionalData: {
        'releaseDate': movie.releaseDate.toIso8601String(),
        'voteAverage': movie.voteAverage,
        'popularity': movie.popularity,
      },
    );

    await showShareOptions(context: context, content: shareableContent);
  }

  /// Shares a movie from MovieDB model
  static Future<void> shareMovieFromMovieDB({
    required BuildContext context,
    required MovieMovieDB movie,
    String? customMessage,
  }) async {
    final shareableContent = ShareableContent.movie(
      movieTitle: movie.title,
      movieDescription: movie.overview,
      movieId: movie.id,
      posterUrl: movie.posterPath.isNotEmpty
          ? 'https://image.tmdb.org/t/p/w500${movie.posterPath}'
          : null,
      additionalData: {
        'releaseDate': movie.releaseDate?.toIso8601String(),
        'voteAverage': movie.voteAverage,
        'popularity': movie.popularity,
      },
    );

    await showShareOptions(context: context, content: shareableContent);
  }

  /// Shares a movie list
  static Future<void> shareMovieList({
    required BuildContext context,
    required String listId,
    required String listName,
    required String listDescription,
    required int movieCount,
    String? coverImageUrl,
    String? customMessage,
  }) async {
    final shareableContent = ShareableContent.movieList(
      listName: listName,
      listDescription: listDescription,
      listId: listId,
      movieCount: movieCount,
      coverImageUrl: coverImageUrl,
    );

    await showShareOptions(context: context, content: shareableContent);
  }

  /// Shares recommendations (category or mood based)
  static Future<void> shareRecommendation({
    required BuildContext context,
    required String recommendationType, // 'category' or 'mood'
    required String recommendationId,
    required String title,
    required String description,
    String? imageUrl,
    String? customMessage,
  }) async {
    final shareableContent = ShareableContent.recommendation(
      recommendationType: recommendationType,
      recommendationId: recommendationId,
      title: title,
      description: description,
      imageUrl: imageUrl,
    );

    await showShareOptions(context: context, content: shareableContent);
  }

  static Future<void> showShareOptions({
    required BuildContext context,
    required ShareableContent content,
  }) async {
    try {
      final result = await SharePlus.instance.share(ShareParams(
        subject: _appName,
        text: content.shareText,
      ));

      // Rastrear evento de compartir exitoso
      if (result.status == ShareResultStatus.success) {
        await _trackShareEvent(content, 'native_share');
        await _trackGamificationShare(content, 'native_share');
      }

      if (result.status == ShareResultStatus.unavailable) {
        _showFallbackShareSheet(context, content);
        return;
      }
    } catch (e) {
      _showFallbackShareSheet(context, content);
    }
  }

  static void _showFallbackShareSheet(
      BuildContext context, ShareableContent content) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final encodedUrl = Uri.encodeComponent(content.url);
        final encodedText = Uri.encodeComponent(content.shareText);

        return Container(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy Link'),
                onTap: () async {
                  Clipboard.setData(ClipboardData(text: content.url));
                  await _trackShareEvent(content, 'copy_link');
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied to clipboard!')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('WhatsApp'),
                onTap: () async {
                  final whatsappUrl = 'whatsapp://send?text=$encodedText';
                  await _trackShareEvent(content, 'whatsapp');
                  await _trackGamificationShare(content, 'whatsapp');
                  launchUrl(Uri.parse(whatsappUrl));
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.flutter_dash),
                title: const Text('Twitter / X'),
                onTap: () async {
                  final twitterUrl =
                      'https://twitter.com/intent/tweet?text=$encodedText';
                  await _trackShareEvent(content, 'twitter');
                  await _trackGamificationShare(content, 'twitter');
                  launchUrl(Uri.parse(twitterUrl));
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.telegram),
                title: const Text('Telegram'),
                onTap: () async {
                  final telegramUrl =
                      'https://t.me/share/url?url=$encodedUrl&text=$encodedText';
                  await _trackShareEvent(content, 'telegram');
                  await _trackGamificationShare(content, 'telegram');
                  launchUrl(Uri.parse(telegramUrl));
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.facebook),
                title: const Text('Facebook'),
                onTap: () async {
                  final facebookUrl =
                      'https://www.facebook.com/sharer/sharer.php?u=$encodedUrl';
                  await _trackShareEvent(content, 'facebook');
                  await _trackGamificationShare(content, 'facebook');
                  launchUrl(Uri.parse(facebookUrl));
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Shares app download link
  static Future<void> shareApp({
    String? customMessage,
  }) async {
    try {
      final message = customMessage ??
          '📱 ¡Descarga $_appName!\n\n'
              '$_appDescription\n\n'
              '🔗 $_baseUrl';

      await SharePlus.instance.share(
        ShareParams(
          subject: _appName,
          text: message,
        ),
      );
    } catch (e) {
      throw ShareException('Error al compartir app: $e');
    }
  }

  /// Opens a shareable URL in the browser
  static Future<void> openShareableUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw ShareException('No se puede abrir la URL: $url');
      }
    } catch (e) {
      throw ShareException('Error al abrir URL: $e');
    }
  }

  /// Generates a deep link URL for a movie (web URL format)
  static String generateMovieDeepLink(int movieId) {
    return '$_baseUrl/movie/$movieId';
  }

  /// Generates an app deep link URL for a movie (app scheme format)
  static String generateMovieAppDeepLink(int movieId) {
    return DeepLinkHandler.generateMovieDeepLink(movieId.toString());
  }

  /// Generates a deep link URL for a movie list (web URL format)
  static String generateListDeepLink(String listId) {
    return '$_baseUrl/list/$listId';
  }

  /// Generates an app deep link URL for a movie list (app scheme format)
  static String generateListAppDeepLink(String listId) {
    return DeepLinkHandler.generateListDeepLink(listId);
  }

  /// Generates a deep link URL for recommendations (web URL format)
  static String generateRecommendationDeepLink(
    String type,
    String id,
  ) {
    return '$_baseUrl/recommendations/$type/$id';
  }

  /// Generates an app deep link URL for recommendations (app scheme format)
  static String generateRecommendationAppDeepLink(
    String type,
    String id,
  ) {
    return DeepLinkHandler.generateRecommendationDeepLink(type, id);
  }

  /// Generates a shareable URL for a movie
  static String generateMovieShareUrl(int movieId) {
    return '$_baseUrl/movie/$movieId/share';
  }

  /// Generates a shareable URL for a movie list
  static String generateListShareUrl(String listId) {
    return '$_baseUrl/list/$listId/share';
  }

  /// Generates a shareable URL for recommendations
  static String generateRecommendationShareUrl(
    String type,
    String id,
  ) {
    return '$_baseUrl/recommendations/$type/$id/share';
  }

  /// Validates if a URL is a valid shareable URL
  static bool isValidShareableUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host == Uri.parse(_baseUrl).host &&
          (uri.path.contains('/share') ||
              uri.path.startsWith('/movie/') ||
              uri.path.startsWith('/list/') ||
              uri.path.startsWith('/recommendations/'));
    } catch (e) {
      return false;
    }
  }

  /// Extracts movie ID from a shareable movie URL
  static int? extractMovieIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      // Handle both /movie/:id and /movie/:id/share formats
      if (pathSegments.length >= 2 && pathSegments[0] == 'movie') {
        return int.tryParse(pathSegments[1]);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Extracts list ID from a shareable list URL
  static String? extractListIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      if (pathSegments.length >= 2 && pathSegments[0] == 'list') {
        return pathSegments[1];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Creates a ShareableContent from a Movie entity
  static ShareableContent createShareableContentFromMovie(Movie movie) {
    return ShareableContent.movie(
      movieTitle: movie.title,
      movieDescription: movie.overview,
      movieId: movie.id,
      posterUrl: movie.posterPath.isNotEmpty
          ? 'https://image.tmdb.org/t/p/w500${movie.posterPath}'
          : null,
      additionalData: {
        'releaseDate': movie.releaseDate.toIso8601String(),
        'voteAverage': movie.voteAverage,
        'popularity': movie.popularity,
      },
    );
  }

  /// Tracks share events for analytics
  static Future<void> _trackShareEvent(
    ShareableContent content,
    String platform,
  ) async {
    try {
      final analyticsService = AnalyticsService();

      String contentType;
      Map<String, dynamic> eventData = {
        'platform': platform,
        'timestamp': DateTime.now().toIso8601String(),
      };

      switch (content.type) {
        case ShareableContentType.movie:
          contentType = 'movie';
          eventData.addAll({
            'movie_id': content.metadata?['movieId'],
            'movie_title': content.metadata?['movieTitle'],
          });
          break;
        case ShareableContentType.movieList:
          contentType = 'movie_list';
          eventData.addAll({
            'list_id': content.metadata?['listId'],
            'list_name': content.metadata?['listName'],
            'movie_count': content.metadata?['movieCount'],
          });
          break;
        case ShareableContentType.recommendation:
          contentType = 'recommendation';
          eventData.addAll({
            'recommendation_type': content.metadata?['recommendationType'],
            'recommendation_id': content.metadata?['recommendationId'],
          });
          break;
      }

      await analyticsService.trackEvent(
        AnalyticsEventType.movieShare,
        {
          'content_type': contentType,
          'share_platform': platform,
          ...eventData,
        },
      );
    } catch (e) {
      // Silently handle analytics errors to not disrupt sharing functionality
      // Error tracking share event: $e
    }
  }

  static Future<void> _trackGamificationShare(
      ShareableContent content, String platform) async {
    try {
      if (_gamificationService == null) return;

      if (content.type == ShareableContentType.movie) {
        final movieId = content.metadata?['movieId']?.toString() ?? '';
        if (movieId.isNotEmpty) {
          await _gamificationService!.trackMovieShared(movieId);
        }
      } else if (content.type == ShareableContentType.movieList) {
        final listId = content.metadata?['listId']?.toString() ?? '';
        if (listId.isNotEmpty) {
          await _gamificationService!.trackListShared(listId);
        }
      } else if (content.type == ShareableContentType.recommendation) {
        final recommendationId =
            content.metadata?['recommendationId']?.toString() ?? '';
        if (recommendationId.isNotEmpty) {
          await _gamificationService!
              .trackRecommendationShared(recommendationId);
        }
      }
    } catch (e) {
      // Silently handle gamification errors
    }
  }
}

/// Custom exception for sharing errors
class ShareException implements Exception {
  const ShareException(this.message);

  final String message;

  @override
  String toString() => 'ShareException: $message';
}
