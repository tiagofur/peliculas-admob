import '../../analytics/analytics_service.dart';
import '../challenge_system.dart' as system;
import '../models/badge_type.dart';
import '../models/challenge.dart';
import '../models/challenge_enums.dart';

/// Review Master Challenge Implementation
class ReviewMasterChallenge {
  static const String challengeId = 'review_master';

  /// Generate a Review Master challenge based on user behavior
  static Challenge generateChallenge({
    required system.UserBehaviorPattern userBehavior,
    required ChallengeDifficulty difficulty,
    required ChallengeDuration duration,
  }) {
    final targetCount = _calculateTargetCount(difficulty, duration);
    final reviewType = _getReviewType(difficulty);

    return Challenge(
      id: '${challengeId}_${DateTime.now().millisecondsSinceEpoch}',
      title: _generateTitle(targetCount, reviewType),
      description: _generateDescription(targetCount, reviewType),
      pointsReward: _calculateRewardPoints(difficulty, targetCount),
      startDate: DateTime.now(),
      endDate: DateTime.now().add(_getDurationTime(duration)),
      targetValue: targetCount,
      challengeType: challengeId,
      currentProgress: 0,
      rewardBadges: _generateRewardBadges(difficulty, targetCount),
    );
  }

  /// Update progress for Review Master challenge
  static Challenge? updateProgress(Challenge challenge, DateTime reviewDate) {
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
          'challenge_type': 'review_master',
          'total_reviews': newProgress,
          'completion_time':
              DateTime.now().difference(challenge.startDate).inHours,
        },
      );
    }

    return challenge.copyWith(
      currentProgress: newProgress,
    );
  }

  /// Update progress for review editing/updating
  static Challenge? updateReviewEdit(
      Challenge challenge, String movieId, String updatedReviewText) {
    if (challenge.challengeType != challengeId ||
        challenge.currentProgress >= challenge.targetValue) {
      return null;
    }

    return challenge;
  }




  /// Calculate target count based on difficulty and duration
  static int _calculateTargetCount(
      ChallengeDifficulty difficulty, ChallengeDuration duration) {
    int baseCount;

    switch (difficulty) {
      case ChallengeDifficulty.easy:
        baseCount = 3; // 3 reviews
        break;
      case ChallengeDifficulty.medium:
        baseCount = 2; // 2 detailed reviews
        break;
      case ChallengeDifficulty.hard:
        baseCount = 1; // 1 quality review
        break;
      case ChallengeDifficulty.expert:
        baseCount = 2; // 2 comprehensive reviews
        break;
    }

    switch (duration) {
      case ChallengeDuration.daily:
        return 1; // Always 1 for daily
      case ChallengeDuration.weekly:
        return baseCount;
      case ChallengeDuration.monthly:
        return (baseCount * 2.5).ceil();
    }
  }

  /// Get review type description
  static String _getReviewType(ChallengeDifficulty difficulty) {
    switch (difficulty) {
      case ChallengeDifficulty.easy:
        return 'reviews';
      case ChallengeDifficulty.medium:
        return 'detailed reviews';
      case ChallengeDifficulty.hard:
        return 'quality reviews';
      case ChallengeDifficulty.expert:
        return 'comprehensive reviews';
    }
  }

  /// Generate challenge title
  static String _generateTitle(int targetCount, String reviewType) {
    switch (reviewType) {
      case 'reviews':
        return 'Review Writer: Write $targetCount Reviews';
      case 'detailed reviews':
        return 'Detailed Critic: Write $targetCount Detailed Reviews';
      case 'quality reviews':
        return 'Master Critic: Write $targetCount Quality Reviews';
      default:
        return 'Review Master Challenge';
    }
  }

  /// Generate challenge description
  static String _generateDescription(int targetCount, String reviewType) {
    switch (reviewType) {
      case 'reviews':
        return 'Share your thoughts by writing $targetCount movie reviews and help others discover great films!';
      case 'detailed reviews':
        return 'Write $targetCount detailed reviews (50+ words) with thoughtful analysis and insights.';
      case 'quality reviews':
        return 'Craft $targetCount high-quality reviews that analyze multiple aspects of the films and engage emotionally.';
      default:
        return 'Become a master movie critic by writing thoughtful and engaging reviews!';
    }
  }

  /// Calculate reward points
  static int _calculateRewardPoints(
      ChallengeDifficulty difficulty, int targetCount) {
    int basePoints;

    switch (difficulty) {
      case ChallengeDifficulty.easy:
        basePoints = 30;
        break;
      case ChallengeDifficulty.medium:
        basePoints = 60;
        break;
      case ChallengeDifficulty.hard:
        basePoints = 120;
        break;
      case ChallengeDifficulty.expert:
        basePoints = 200;
        break;
    }

    return basePoints * targetCount;
  }

  /// Generate reward badges
  static List<String> _generateRewardBadges(
      ChallengeDifficulty difficulty, int targetCount) {
    List<BadgeType> badges = [];

    // Assign badge based on difficulty level
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

    // Add diamond badge for high target counts
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
