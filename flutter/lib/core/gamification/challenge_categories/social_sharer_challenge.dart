import '../../analytics/analytics_service.dart';
import '../challenge_system.dart' as system;
import '../models/badge_type.dart';
import '../models/challenge.dart' as models;
import '../models/challenge_enums.dart';

/// Social Sharer Challenge Implementation
class SocialSharerChallenge {
  static const String challengeId = 'social_sharer';

  /// Generate a Social Sharer challenge based on user behavior
  static models.Challenge generateChallenge({
    required system.UserBehaviorPattern userBehavior,
    required ChallengeDifficulty difficulty,
    required ChallengeDuration duration,
  }) {
    final targetCount = _calculateTargetCount(difficulty, duration);
    final shareType = _getShareType(difficulty);

    return models.Challenge(
      id: '${challengeId}_${DateTime.now().millisecondsSinceEpoch}',
      title: _generateTitle(targetCount, shareType),
      description: _generateDescription(targetCount, shareType),
      pointsReward: _calculateRewardPoints(difficulty, targetCount),
      startDate: DateTime.now(),
      endDate: DateTime.now().add(_getDurationTime(duration)),
      targetValue: targetCount,
      challengeType: challengeId,
      currentProgress: 0,
      rewardBadges: _generateRewardBadges(difficulty, targetCount),
    );
  }

  /// Update progress for Social Sharer challenge
  static models.Challenge? updateProgress(
      models.Challenge challenge, String movieId, String platform) {
    if (challenge.challengeType != challengeId ||
        challenge.currentProgress >= challenge.targetValue) {
      return null;
    }

    final newProgress = challenge.currentProgress + 1;
    final isCompleted = newProgress >= challenge.targetValue;

    // Track completion analytics
    if (isCompleted) {
      final analyticsService = AnalyticsService();
      analyticsService.trackEvent(
        AnalyticsEventType.gamificationActivity,
        {
          'challenge_type': 'social_sharer',
          'difficulty': challenge.challengeType,
          'total_shares': newProgress,
          'completion_time':
              DateTime.now().difference(challenge.startDate).inHours,
        },
      );
    }

    return challenge.copyWith(
      currentProgress: newProgress,
    );
  }

  /// Update progress for recommendation sharing
  static models.Challenge? updateRecommendationProgress(
      models.Challenge challenge, String movieId, List<String> recipients) {
    if (challenge.challengeType != challengeId ||
        challenge.currentProgress >= challenge.targetValue) {
      return null;
    }

    final newProgress = challenge.currentProgress + recipients.length;
    final isCompleted = newProgress >= challenge.targetValue;

    // Track completion analytics
    if (isCompleted) {
      final analyticsService = AnalyticsService();
      analyticsService.trackEvent(
        AnalyticsEventType.gamificationActivity,
        {
          'challenge_type': 'social_sharer',
          'difficulty': challenge.challengeType,
          'total_recommendations': recipients.length,
          'completion_time':
              DateTime.now().difference(challenge.startDate).inHours,
        },
      );
    }

    return challenge.copyWith(
      currentProgress: newProgress,
    );
  }

  /// Calculate target count based on difficulty and duration
  static int _calculateTargetCount(
      ChallengeDifficulty difficulty, ChallengeDuration duration) {
    int baseCount;

    switch (difficulty) {
      case ChallengeDifficulty.easy:
        baseCount = 3; // 3 shares
        break;
      case ChallengeDifficulty.medium:
        baseCount = 5; // 5 unique movies
        break;
      case ChallengeDifficulty.hard:
        baseCount = 3; // 3 different platforms
        break;
      case ChallengeDifficulty.expert:
        baseCount = 8; // 8 combined unique movies and platforms
        break;
    }

    switch (duration) {
      case ChallengeDuration.daily:
        return (baseCount * 0.3).ceil();
      case ChallengeDuration.weekly:
        return baseCount;
      case ChallengeDuration.monthly:
        return (baseCount * 2).ceil();
    }
  }

  /// Get share type description
  static String _getShareType(ChallengeDifficulty difficulty) {
    switch (difficulty) {
      case ChallengeDifficulty.easy:
        return 'movies';
      case ChallengeDifficulty.medium:
        return 'different movies';
      case ChallengeDifficulty.hard:
        return 'platforms';
      case ChallengeDifficulty.expert:
        return 'diverse shares';
    }
  }

  /// Generate challenge title
  static String _generateTitle(int targetCount, String shareType) {
    switch (shareType) {
      case 'movies':
        return 'Social Butterfly: Share $targetCount Movies';
      case 'different movies':
        return 'Movie Curator: Share $targetCount Different Films';
      case 'platforms':
        return 'Multi-Platform Sharer: Use $targetCount Platforms';
      default:
        return 'Social Sharer Challenge';
    }
  }

  /// Generate challenge description
  static String _generateDescription(int targetCount, String shareType) {
    switch (shareType) {
      case 'movies':
        return 'Share $targetCount movies with your friends and spread the love of cinema!';
      case 'different movies':
        return 'Curate and share $targetCount different movies to showcase your diverse taste in films.';
      case 'platforms':
        return 'Share movies across $targetCount different social platforms and maximize your reach!';
      default:
        return 'Share movies with friends and become a social cinema influencer!';
    }
  }

  /// Calculate reward points
  static int _calculateRewardPoints(
      ChallengeDifficulty difficulty, int targetCount) {
    int basePoints;

    switch (difficulty) {
      case ChallengeDifficulty.easy:
        basePoints = 40;
        break;
      case ChallengeDifficulty.medium:
        basePoints = 60;
        break;
      case ChallengeDifficulty.hard:
        basePoints = 100;
        break;
      case ChallengeDifficulty.expert:
        basePoints = 150;
        break;
    }

    return basePoints * targetCount;
  }

  /// Generate reward badges
  static List<String> _generateRewardBadges(
      ChallengeDifficulty difficulty, int targetCount) {
    List<BadgeType> badges = [];

    switch (difficulty) {
      case ChallengeDifficulty.easy:
        badges.add(BadgeType.bronze);
        break;
      case ChallengeDifficulty.medium:
        badges.add(BadgeType.silver);
        break;
      case ChallengeDifficulty.hard:
        badges.add(BadgeType.gold);
        break;
      case ChallengeDifficulty.expert:
        badges.add(BadgeType.platinum);
        break;
    }

    if (targetCount >= 5) {
      badges.add(BadgeType.diamond);
    }

    return badges.map((badge) => badge.name).toList();
  }

  /// Get duration time
  static Duration _getDurationTime(ChallengeDuration duration) {
    switch (duration) {
      case ChallengeDuration.daily:
        return const Duration(days: 1);
      case ChallengeDuration.weekly:
        return const Duration(days: 7);
      case ChallengeDuration.monthly:
        return const Duration(days: 30);
    }
  }
}
