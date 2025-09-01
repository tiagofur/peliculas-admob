import 'package:flutter/material.dart';

import '../analytics/analytics_service.dart';
import '../services/logger_factory.dart';
import 'challenge_categories/discovery_quest_challenge.dart';
import 'challenge_categories/genre_explorer_challenge.dart';
import 'challenge_categories/marathon_weekend_challenge.dart';
import 'challenge_categories/review_master_challenge.dart';
import 'challenge_categories/social_sharer_challenge.dart';
import 'challenge_system.dart' as system;
import 'models/challenge.dart';
import 'models/challenge_enums.dart';

/// Tracks user actions and updates challenge progress
class ChallengeTracker extends ChangeNotifier {
  factory ChallengeTracker() => _instance;
  ChallengeTracker._internal();
  static final ChallengeTracker _instance = ChallengeTracker._internal();
  static ChallengeTracker get instance => _instance;

  final system.ChallengeSystem _challengeSystem = system.ChallengeSystem();
  final AnalyticsService _analytics = AnalyticsService();

  // Context for showing celebrations
  BuildContext? _currentContext;

  // Track user behavior for challenge generation
  final Map<String, int> _genreWatchCount = {};
  final Map<String, int> _dailyWatchCount = {};
  final Map<String, int> _weeklyWatchCount = {};
  final Map<String, int> _monthlyWatchCount = {};
  int _totalMoviesWatched = 0;
  int _totalReviewsWritten = 0;
  int _totalMoviesShared = 0;
  int _totalGenresExplored = 0;
  DateTime _lastActivityDate = DateTime.now();

  /// Initialize the tracker
  void initialize() {
    _updateUserBehaviorPattern();
    LoggerFactory.info('ChallengeTracker initialized');
  }

  /// Set the current context for showing celebrations
  void setContext(BuildContext? context) {
    _currentContext = context;
  }

  /// Track when a user watches a movie
  void trackMovieWatched({
    required String movieId,
    required String movieTitle,
    required List<String> genres,
    DateTime? watchedAt,
  }) {
    final date = watchedAt ?? DateTime.now();
    _lastActivityDate = date;
    _totalMoviesWatched++;

    // Update genre tracking
    for (final genre in genres) {
      _genreWatchCount[genre] = (_genreWatchCount[genre] ?? 0) + 1;
    }
    _totalGenresExplored = _genreWatchCount.keys.length;

    // Update time-based tracking
    final dateKey = _getDateKey(date);
    final weekKey = _getWeekKey(date);
    final monthKey = _getMonthKey(date);

    _dailyWatchCount[dateKey] = (_dailyWatchCount[dateKey] ?? 0) + 1;
    _weeklyWatchCount[weekKey] = (_weeklyWatchCount[weekKey] ?? 0) + 1;
    _monthlyWatchCount[monthKey] = (_monthlyWatchCount[monthKey] ?? 0) + 1;

    // Update relevant challenges
    _updateGenreExplorerChallenges(genres);
    _updateMarathonChallenges(date);
    _updateDiscoveryChallenges(movieId);

    // Update user behavior pattern
    _updateUserBehaviorPattern();

    // Log analytics
    _analytics.trackEvent(AnalyticsEventType.movieView, {
      'movie_id': movieId,
      'movie_title': movieTitle,
      'genres': genres,
      'total_watched': _totalMoviesWatched,
    });

    LoggerFactory.info('Movie watched tracked: $movieTitle');
    notifyListeners();
  }

  /// Track when a user writes a review
  void trackReviewWritten({
    required String movieId,
    required String movieTitle,
    required double rating,
    required String reviewText,
    DateTime? reviewedAt,
  }) {
    final date = reviewedAt ?? DateTime.now();
    _lastActivityDate = date;
    _totalReviewsWritten++;

    // Update review master challenges
    _updateReviewMasterChallenges(movieId, reviewText);

    // Update user behavior pattern
    _updateUserBehaviorPattern();

    // Log analytics
    _analytics.trackEvent(AnalyticsEventType.userEngagement, {
      'movie_id': movieId,
      'movie_title': movieTitle,
      'rating': rating,
      'review_length': reviewText.length,
      'total_reviews': _totalReviewsWritten,
    });

    LoggerFactory.info('Review written tracked: $movieTitle');
    notifyListeners();
  }

  /// Track when a user shares a movie
  void trackMovieShared({
    required String movieId,
    required String movieTitle,
    required String platform,
    DateTime? sharedAt,
  }) {
    final date = sharedAt ?? DateTime.now();
    _lastActivityDate = date;
    _totalMoviesShared++;

    // Update social sharer challenges
    _updateSocialSharerChallenges(movieId, platform);

    // Update user behavior pattern
    _updateUserBehaviorPattern();

    // Log analytics
    _analytics.trackEvent(AnalyticsEventType.movieShare, {
      'movie_id': movieId,
      'movie_title': movieTitle,
      'platform': platform,
      'total_shared': _totalMoviesShared,
    });

    LoggerFactory.info('Movie shared tracked: $movieTitle on $platform');
    notifyListeners();
  }

  /// Track when a user discovers a new release
  void trackNewReleaseDiscovered({
    required String movieId,
    required String movieTitle,
    required DateTime releaseDate,
    DateTime? discoveredAt,
  }) {
    final date = discoveredAt ?? DateTime.now();
    _lastActivityDate = date;

    // Update discovery quest challenges
    _updateDiscoveryChallenges(movieId, isNewRelease: true);

    // Log analytics
    _analytics.trackEvent(AnalyticsEventType.userEngagement, {
      'movie_id': movieId,
      'movie_title': movieTitle,
      'release_date': releaseDate.toIso8601String(),
    });

    LoggerFactory.info('New release discovered: $movieTitle');
    notifyListeners();
  }

  /// Update genre explorer challenges
  void _updateGenreExplorerChallenges(List<String> genres) {
    final challenges =
        _challengeSystem.getChallengesByType(ChallengeType.genreExplorer);

    for (final challenge in challenges) {
      if (challenge.isCompleted || challenge.isExpired) continue;

      // Update progress using specific challenge implementation
      for (final genre in genres) {
        GenreExplorerChallenge.updateProgress(challenge, genre);
        // Check if challenge was completed and update system
        if (challenge.isCompleted) {
          _challengeSystem.updateChallengeProgress(
              challenge.id, challenge.currentProgress, _currentContext);
        }
      }
    }
  }

  /// Update marathon challenges
  void _updateMarathonChallenges(DateTime watchDate) {
    final challenges =
        _challengeSystem.getChallengesByType(ChallengeType.marathonWeekend);

    for (final challenge in challenges) {
      if (challenge.isCompleted || challenge.isExpired) continue;

      // Update progress using specific challenge implementation
      MarathonWeekendChallenge.updateProgress(challenge, watchDate);
      // Check if challenge was completed and update system
      if (challenge.isCompleted) {
        _challengeSystem.updateChallengeProgress(
            challenge.id, challenge.currentProgress, _currentContext);
      }
    }
  }

  /// Update review master challenges
  void _updateReviewMasterChallenges(String movieId, String reviewText) {
    final challenges =
        _challengeSystem.getChallengesByType(ChallengeType.reviewMaster);

    for (final challenge in challenges) {
      if (challenge.isCompleted || challenge.isExpired) continue;

      // Update progress using specific challenge implementation
      final updatedChallenge = ReviewMasterChallenge.updateProgress(challenge, DateTime.now());
      if (updatedChallenge != null) {
        // Update the challenge in the system
        _challengeSystem.updateChallengeProgress(
            updatedChallenge.id, updatedChallenge.currentProgress, _currentContext);
      }
      // Check if challenge was completed and update system
      if (challenge.isCompleted) {
        _challengeSystem.updateChallengeProgress(
            challenge.id, challenge.currentProgress, _currentContext);
      }
    }
  }

  /// Update social sharer challenges
  void _updateSocialSharerChallenges(String movieId, String platform) {
    final challenges =
        _challengeSystem.getChallengesByType(ChallengeType.socialSharer);

    for (final challenge in challenges) {
      if (challenge.isCompleted || challenge.isExpired) continue;

      // Update progress using specific challenge implementation
      final updatedChallenge = SocialSharerChallenge.updateProgress(challenge, movieId, platform);
      if (updatedChallenge != null) {
        // Update the challenge in the system
        _challengeSystem.updateChallengeProgress(
            updatedChallenge.id, updatedChallenge.currentProgress, _currentContext);
      }
      // Check if challenge was completed and update system
      if (challenge.isCompleted) {
        _challengeSystem.updateChallengeProgress(
            challenge.id, challenge.currentProgress, _currentContext);
      }
    }
  }

  /// Update discovery challenges
  void _updateDiscoveryChallenges(String movieId, {bool isNewRelease = false}) {
    final challenges =
        _challengeSystem.getChallengesByType(ChallengeType.discoveryQuest);

    for (final challenge in challenges) {
      if (challenge.isCompleted || challenge.isExpired) continue;

      // Update progress using specific challenge implementation
      DiscoveryQuestChallenge.updateProgress(
        challenge,
        movieId,
        'user_discovery',
        isNewRelease: isNewRelease,
      );
      // Check if challenge was completed and update system
      if (challenge.isCompleted) {
        _challengeSystem.updateChallengeProgress(
            challenge.id, challenge.currentProgress, _currentContext);
      }
    }
  }

  /// Get unique genres watched since a specific date
  Set<String> _getUniqueGenresSince(DateTime since) {
    // This would typically query a database or local storage
    // For now, return current genre count as approximation
    return _genreWatchCount.keys.toSet();
  }

  /// Get movies watched in a specific period
  int _getMoviesWatchedInPeriod(DateTime start, DateTime end) {
    // This would typically query a database or local storage
    // For now, return approximation based on current data
    int count = 0;

    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    for (var date = startDate;
        date.isBefore(endDate) || date.isAtSameMomentAs(endDate);
        date = date.add(const Duration(days: 1))) {
      final dateKey = _getDateKey(date);
      count += _dailyWatchCount[dateKey] ?? 0;
    }

    return count;
  }

  /// Get reviews written in a specific period
  int _getReviewsWrittenInPeriod(DateTime start, DateTime end) {
    // This would typically query a database or local storage
    // For now, return approximation
    final daysDiff = end.difference(start).inDays;
    final avgReviewsPerDay = _totalReviewsWritten /
        DateTime.now().difference(_lastActivityDate).inDays.clamp(1, 365);
    return (avgReviewsPerDay * daysDiff).round();
  }

  /// Get shares in a specific period
  int _getSharesInPeriod(DateTime start, DateTime end) {
    // This would typically query a database or local storage
    // For now, return approximation
    final daysDiff = end.difference(start).inDays;
    final avgSharesPerDay = _totalMoviesShared /
        DateTime.now().difference(_lastActivityDate).inDays.clamp(1, 365);
    return (avgSharesPerDay * daysDiff).round();
  }

  /// Get discoveries in a specific period
  int _getDiscoveriesInPeriod(DateTime start, DateTime end,
      {bool newReleasesOnly = false}) {
    // This would typically query a database or local storage
    // For now, return approximation
    final daysDiff = end.difference(start).inDays;
    final avgDiscoveriesPerDay = _totalMoviesWatched /
        DateTime.now().difference(_lastActivityDate).inDays.clamp(1, 365);
    return (avgDiscoveriesPerDay * daysDiff * (newReleasesOnly ? 0.3 : 1.0))
        .round();
  }

  /// Update user behavior pattern for challenge generation
  void _updateUserBehaviorPattern() {
    final now = DateTime.now();
    final daysActive = now.difference(_lastActivityDate).inDays.clamp(1, 365);

    final behaviorPattern = system.UserBehaviorPattern(
      genrePreferences: Map<String, int>.from(_genreWatchCount),
      averageMoviesPerWeek: (_totalMoviesWatched * 7 / daysActive).round(),
      averageReviewsPerMonth: (_totalReviewsWritten * 30 / daysActive).round(),
      socialSharesPerMonth: (_totalMoviesShared * 30 / daysActive).round(),
      favoriteGenres: _getFavoriteGenres(),
      engagementScore: _calculateEngagementScore(),
      lastActiveDate: _lastActivityDate,
    );

    _challengeSystem.initialize(behaviorPattern);
  }

  /// Get user's favorite genres
  List<String> _getFavoriteGenres() {
    final sortedGenres = _genreWatchCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedGenres.take(5).map((e) => e.key).toList();
  }

  /// Calculate user engagement score
  double _calculateEngagementScore() {
    final now = DateTime.now();
    final daysActive = now.difference(_lastActivityDate).inDays.clamp(1, 365);

    // Base score on activity frequency
    double score = 0.0;

    // Movies watched score (0-0.4)
    final moviesPerDay = _totalMoviesWatched / daysActive;
    score += (moviesPerDay * 0.4).clamp(0.0, 0.4);

    // Reviews written score (0-0.3)
    final reviewsPerDay = _totalReviewsWritten / daysActive;
    score += (reviewsPerDay * 10 * 0.3).clamp(0.0, 0.3);

    // Social sharing score (0-0.2)
    final sharesPerDay = _totalMoviesShared / daysActive;
    score += (sharesPerDay * 5 * 0.2).clamp(0.0, 0.2);

    // Genre diversity score (0-0.1)
    final genreDiversity = (_totalGenresExplored / 20.0).clamp(0.0, 1.0);
    score += genreDiversity * 0.1;

    return score.clamp(0.0, 1.0);
  }

  /// Get date key for tracking
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get week key for tracking
  String _getWeekKey(DateTime date) {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    return '${startOfWeek.year}-W${_getWeekOfYear(startOfWeek)}';
  }

  /// Get month key for tracking
  String _getMonthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  /// Get week of year
  int _getWeekOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final daysDifference = date.difference(startOfYear).inDays;
    return (daysDifference / 7).ceil();
  }

  /// Get active challenges
  List<Challenge> get activeChallenges => _challengeSystem.activeChallenges;

  /// Get completed challenges
  List<Challenge> get completedChallenges =>
      _challengeSystem.completedChallenges;

  /// Get current user statistics
  Map<String, dynamic> getUserStatistics() {
    return {
      'totalMoviesWatched': _totalMoviesWatched,
      'totalReviewsWritten': _totalReviewsWritten,
      'totalMoviesShared': _totalMoviesShared,
      'totalGenresExplored': _totalGenresExplored,
      'favoriteGenres': _getFavoriteGenres(),
      'engagementScore': _calculateEngagementScore(),
      'lastActivityDate': _lastActivityDate.toIso8601String(),
      'activeChallenges': _challengeSystem.activeChallenges.length,
      'completedChallenges': _challengeSystem.completedChallenges.length,
    };
  }

  /// Reset user statistics (for testing or new users)
  void resetStatistics() {
    _genreWatchCount.clear();
    _dailyWatchCount.clear();
    _weeklyWatchCount.clear();
    _monthlyWatchCount.clear();
    _totalMoviesWatched = 0;
    _totalReviewsWritten = 0;
    _totalMoviesShared = 0;
    _totalGenresExplored = 0;
    _lastActivityDate = DateTime.now();

    _updateUserBehaviorPattern();
    notifyListeners();

    LoggerFactory.info('Challenge tracker statistics reset');
  }
}
