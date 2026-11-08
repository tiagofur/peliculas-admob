import '../../analytics/analytics_service.dart';
import '../challenge_system.dart' as system;
import '../models/badge_type.dart';
import '../models/challenge.dart';
import '../models/challenge_enums.dart';

/// Marathon Weekend Challenge Implementation
class MarathonWeekendChallenge {
  static const String challengeId = 'marathon_weekend';

  /// Generate a Marathon Weekend challenge based on user behavior
  static Challenge generateChallenge({
    required system.UserBehaviorPattern userBehavior,
    required ChallengeDifficulty difficulty,
    required ChallengeDuration duration,
  }) {
    final targetCount = _calculateTargetCount(difficulty, duration);
    final timeFrame = _getTimeFrame(duration);

    return Challenge(
      id: '${challengeId}_${DateTime.now().millisecondsSinceEpoch}',
      title: _generateTitle(targetCount, timeFrame),
      description: _generateDescription(targetCount, timeFrame),
      pointsReward: _calculateRewardPoints(difficulty, targetCount),
      startDate: DateTime.now(),
      endDate: DateTime.now().add(_getDurationTime(duration)),
      targetValue: targetCount,
      challengeType: challengeId,
      currentProgress: 0,
      rewardBadges: _generateRewardBadges(difficulty, targetCount),
    );
  }

  /// Update progress for Marathon Weekend challenge
  static Challenge? updateProgress(Challenge challenge, DateTime watchDate) {
    if (challenge.challengeType != challengeId ||
        challenge.currentProgress >= challenge.targetValue) {
      return null;
    }

    final newProgress = challenge.currentProgress + 1;
    final isCompleted = newProgress >= challenge.targetValue;

    // Track completion analytics if challenge is completed
    if (isCompleted) {
      final analyticsService = AnalyticsService();
      analyticsService.trackEvent(
        AnalyticsEventType.gamificationActivity,
        {
          'challenge_type': 'marathon_weekend',
          'movies_watched': newProgress,
          'watch_date': watchDate.toIso8601String(),
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
    switch (duration) {
      case ChallengeDuration.daily:
        switch (difficulty) {
          case ChallengeDifficulty.easy:
            return 2; // 2 movies in one day
          case ChallengeDifficulty.medium:
            return 3; // 3 movies in one day
          case ChallengeDifficulty.hard:
            return 4; // 4 movies in one day
          case ChallengeDifficulty.expert:
            return 6; // 6 movies in one day
        }

      case ChallengeDuration.weekly:
        switch (difficulty) {
          case ChallengeDifficulty.easy:
            return 5; // 5 movies in a week
          case ChallengeDifficulty.medium:
            return 8; // 8 movies in a week
          case ChallengeDifficulty.hard:
            return 5; // 5 consecutive days of watching
          case ChallengeDifficulty.expert:
            return 7; // 7 consecutive days of watching
        }

      case ChallengeDuration.monthly:
        switch (difficulty) {
          case ChallengeDifficulty.easy:
            return 15; // 15 movies in a month
          case ChallengeDifficulty.medium:
            return 25; // 25 movies in a month
          case ChallengeDifficulty.hard:
            return 10; // 10 consecutive days of watching
          case ChallengeDifficulty.expert:
            return 15; // 15 consecutive days of watching
        }
    }
  }

  /// Get time frame description
  static String _getTimeFrame(ChallengeDuration duration) {
    switch (duration) {
      case ChallengeDuration.daily:
        return 'today';
      case ChallengeDuration.weekly:
        return 'this week';
      case ChallengeDuration.monthly:
        return 'this month';
    }
  }

  /// Generate challenge title
  static String _generateTitle(int targetCount, String timeFrame) {
    if (timeFrame == 'today') {
      return 'Movie Marathon: $targetCount Films Today';
    } else {
      return 'Movie Marathon: $targetCount Films $timeFrame';
    }
  }

  /// Generate challenge description
  static String _generateDescription(int targetCount, String timeFrame) {
    if (timeFrame == 'today') {
      return 'Challenge yourself to watch $targetCount movies in a single day! Perfect for a cozy movie marathon.';
    } else {
      return 'Watch $targetCount movies $timeFrame and become a true cinema marathon champion!';
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
        basePoints = 50;
        break;
      case ChallengeDifficulty.hard:
        basePoints = 100;
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

    // Assign badges based on difficulty
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
    if (targetCount >= 10) {
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
