import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/movie.dart';
import '../analytics/analytics_service.dart';
import '../logging/logger_factory.dart';
import 'gamification_manager.dart';
import 'models/activity_type.dart';

import 'models/user_progress.dart';
import 'models/achievement.dart';
import 'models/challenge.dart';

/// Service that integrates gamification with existing app features
class GamificationIntegrationService {
  GamificationIntegrationService({
    required GamificationManager gamificationManager,
    required AnalyticsService analyticsService,
    required Ref ref,
  })  : _gamificationManager = gamificationManager,
        _analyticsService = analyticsService,
        _ref = ref;
  static final _logger = LoggerFactory.logger;

  final GamificationManager _gamificationManager;
  final AnalyticsService _analyticsService;
  final Ref _ref;

  /// Initialize gamification integration
  Future<void> initialize() async {
    try {
      await _gamificationManager.initialize();
      _logger.info('Gamification integration service initialized');
    } catch (e) {
      _logger.error('Failed to initialize gamification integration: $e');
      rethrow;
    }
  }

  /// Track when user adds a movie to favorites
  Future<void> trackMovieFavorited(Movie movie) async {
    try {
      await _gamificationManager.trackActivity(
        ActivityType.addToFavorites,
        metadata: {
          'movie_id': movie.id,
          'movie_title': movie.title,
          'genre_ids': movie.genreIds,
          'release_year': movie.releaseDate.year,
        },
      );

      await _analyticsService.trackEvent(
        AnalyticsEventType.gamificationActivity,
        {
          'activity_type': 'movie_favorited',
          'movie_id': movie.id,
          'movie_title': movie.title,
        },
      );

      _logger.info('Tracked movie favorited: ${movie.title}');
    } catch (e) {
      _logger.error('Failed to track movie favorited: $e');
    }
  }

  /// Track when user watches a movie
  Future<void> trackMovieWatched(Movie movie) async {
    try {
      await _gamificationManager.trackActivity(
        ActivityType.watchMovie,
        metadata: {
          'movie_id': movie.id,
          'movie_title': movie.title,
          'genre_ids': movie.genreIds,
          'release_year': movie.releaseDate.year,
          'runtime': movie.runtime ?? 0,
        },
      );

      await _analyticsService.trackEvent(
        AnalyticsEventType.gamificationActivity,
        {
          'activity_type': 'movie_watched',
          'movie_id': movie.id,
          'movie_title': movie.title,
        },
      );

      _logger.info('Tracked movie watched: ${movie.title}');
    } catch (e) {
      _logger.error('Failed to track movie watched: $e');
    }
  }

  /// Track when user shares content
  Future<void> trackContentShared({
    required String contentType,
    required String platform,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _gamificationManager.trackActivity(
        ActivityType.shareContent,
        metadata: {
          'content_type': contentType,
          'platform': platform,
          ...?metadata,
        },
      );

      await _analyticsService.trackEvent(
        AnalyticsEventType.gamificationActivity,
        {
          'activity_type': 'content_shared',
          'content_type': contentType,
          'platform': platform,
        },
      );

      _logger.info('Tracked content shared: $contentType on $platform');
    } catch (e) {
      _logger.error('Failed to track content shared: $e');
    }
  }

  /// Track when user writes a review
  Future<void> trackReviewWritten({
    required int movieId,
    required String movieTitle,
    required double rating,
    required int reviewLength,
  }) async {
    try {
      await _gamificationManager.trackActivity(
        ActivityType.writeReview,
        metadata: {
          'movie_id': movieId,
          'movie_title': movieTitle,
          'rating': rating,
          'review_length': reviewLength,
        },
      );

      await _analyticsService.trackEvent(
        AnalyticsEventType.gamificationActivity,
        {
          'activity_type': 'review_written',
          'movie_id': movieId,
          'movie_title': movieTitle,
          'rating': rating,
          'review_length': reviewLength,
        },
      );

      _logger.info('Tracked review written for: $movieTitle');
    } catch (e) {
      _logger.error('Failed to track review written: $e');
    }
  }

  /// Track when user completes a watchlist
  Future<void> trackWatchlistCompleted({
    required String listId,
    required String listName,
    required int movieCount,
  }) async {
    try {
      await _gamificationManager.trackActivity(
        ActivityType.completeWatchlist,
        metadata: {
          'list_id': listId,
          'list_name': listName,
          'movie_count': movieCount,
        },
      );

      await _analyticsService.trackEvent(
        AnalyticsEventType.gamificationActivity,
        {
          'activity_type': 'watchlist_completed',
          'list_id': listId,
          'list_name': listName,
          'movie_count': movieCount,
        },
      );

      _logger.info('Tracked watchlist completed: $listName');
    } catch (e) {
      _logger.error('Failed to track watchlist completed: $e');
    }
  }

  /// Track when user shares a movie
  Future<void> trackMovieShared(String movieId) async {
    try {
      await _gamificationManager.trackActivity(
        ActivityType.shareContent,
        metadata: {
          'content_type': 'movie',
          'movie_id': movieId,
        },
      );

      await _analyticsService.trackEvent(
        AnalyticsEventType.gamificationActivity,
        {
          'activity_type': 'movie_shared',
          'movie_id': movieId,
        },
      );

      _logger.info('Tracked movie shared: $movieId');
    } catch (e) {
      _logger.error('Failed to track movie shared: $e');
    }
  }

  /// Track when user shares a list
  Future<void> trackListShared(String listId) async {
    try {
      await _gamificationManager.trackActivity(
        ActivityType.shareContent,
        metadata: {
          'content_type': 'list',
          'list_id': listId,
        },
      );

      await _analyticsService.trackEvent(
        AnalyticsEventType.gamificationActivity,
        {
          'activity_type': 'list_shared',
          'list_id': listId,
        },
      );

      _logger.info('Tracked list shared: $listId');
    } catch (e) {
      _logger.error('Failed to track list shared: $e');
    }
  }

  /// Track when user shares a recommendation
  Future<void> trackRecommendationShared(String recommendationId) async {
    try {
      await _gamificationManager.trackActivity(
        ActivityType.shareContent,
        metadata: {
          'content_type': 'recommendation',
          'recommendation_id': recommendationId,
        },
      );

      await _analyticsService.trackEvent(
        AnalyticsEventType.gamificationActivity,
        {
          'activity_type': 'recommendation_shared',
          'recommendation_id': recommendationId,
        },
      );

      _logger.info('Tracked recommendation shared: $recommendationId');
    } catch (e) {
      _logger.error('Failed to track recommendation shared: $e');
    }
  }

  /// Get user's current gamification progress
  Future<UserProgress> getUserProgress() async {
    try {
      return await _gamificationManager.getUserProgress();
    } catch (e) {
      _logger.error('Failed to get user progress: $e');
      rethrow;
    }
  }

  /// Get user's achievements
  Future<List<Achievement>> getUserAchievements() async {
    try {
      return await _gamificationManager.getUserAchievements();
    } catch (e) {
      _logger.error('Failed to get user achievements: $e');
      rethrow;
    }
  }

  /// Get active challenges
  Future<List<Challenge>> getActiveChallenges() async {
    try {
      return _gamificationManager.getActiveChallenges();
    } catch (e) {
      _logger.error('Failed to get active challenges: $e');
      rethrow;
    }
  }

  /// Check for new achievements and notify user
  Future<List<Achievement>> checkForNewAchievements() async {
    try {
      final newAchievements = await _gamificationManager.checkAchievements();

      if (newAchievements.isNotEmpty) {
        await _analyticsService.trackEvent(
          AnalyticsEventType.gamificationActivity,
          {
            'activity_type': 'achievements_unlocked',
            'achievement_count': newAchievements.length,
            'achievement_ids': newAchievements.map((a) => a.id).toList(),
          },
        );

        _logger.info('New achievements unlocked: ${newAchievements.length}');
      }

      return newAchievements;
    } catch (e) {
      _logger.error('Failed to check for new achievements: $e');
      return [];
    }
  }

  /// Check for completed challenges
  Future<List<Challenge>> checkForCompletedChallenges() async {
    try {
      final completedChallenges = await _gamificationManager.checkChallenges();

      if (completedChallenges.isNotEmpty) {
        await _analyticsService.trackEvent(
          AnalyticsEventType.gamificationActivity,
          {
            'activity_type': 'challenges_completed',
            'challenge_count': completedChallenges.length,
            'challenge_ids': completedChallenges.map((c) => c.id).toList(),
          },
        );

        _logger.info('Challenges completed: ${completedChallenges.length}');
      }

      return completedChallenges;
    } catch (e) {
      _logger.error('Failed to check for completed challenges: $e');
      return [];
    }
  }

  /// Get user's current level and progress to next level
  Future<Map<String, dynamic>> getLevelProgress() async {
    try {
      final progress = await _gamificationManager.getUserProgress();
      final currentLevel = progress.currentLevel;
      final currentPoints = progress.totalPoints;

      // Calculate points needed for next level
      final nextLevelPoints = _calculatePointsForLevel(currentLevel + 1);
      final pointsToNext = nextLevelPoints - currentPoints;

      return {
        'current_level': currentLevel,
        'current_points': currentPoints,
        'points_to_next': pointsToNext,
        'next_level_points': nextLevelPoints,
        'progress_percentage':
            (currentPoints / nextLevelPoints * 100).clamp(0, 100),
      };
    } catch (e) {
      _logger.error('Failed to get level progress: $e');
      rethrow;
    }
  }

  /// Calculate points required for a specific level
  int _calculatePointsForLevel(int level) {
    // Progressive point system: each level requires more points
    return (level * 100) + (level * level * 50);
  }

  /// Reset user progress (for testing or user request)
  Future<void> resetProgress() async {
    try {
      await _gamificationManager.resetProgress();

      await _analyticsService.trackEvent(
        AnalyticsEventType.gamificationActivity,
        {'activity_type': 'progress_reset'},
      );

      _logger.info('User progress reset');
    } catch (e) {
      _logger.error('Failed to reset progress: $e');
      rethrow;
    }
  }
}

/// Provider for gamification integration service
final gamificationIntegrationServiceProvider =
    Provider<GamificationIntegrationService>((ref) {
  final gamificationManager = GamificationManager();
  final analyticsService = AnalyticsService();

  return GamificationIntegrationService(
    gamificationManager: gamificationManager,
    analyticsService: analyticsService,
    ref: ref,
  );
});
