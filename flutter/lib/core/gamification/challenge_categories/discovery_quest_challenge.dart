import '../models/badge_type.dart';
import '../models/challenge.dart';
import '../models/challenge_enums.dart';

/// Discovery Quest Challenge Implementation
class DiscoveryQuestChallenge {
  static const String challengeId = 'discovery_quest';

  /// Generate a Discovery Quest challenge based on user behavior
  static Challenge generateChallenge({
    required ChallengeDifficulty difficulty,
    required ChallengeDuration duration,
  }) {
    final targetCount = _calculateTargetCount(difficulty, duration);
    final questType = _getQuestType(difficulty);

    return Challenge(
      id: '${challengeId}_${DateTime.now().millisecondsSinceEpoch}',
      title: _generateTitle(targetCount, questType),
      description: _generateDescription(targetCount, questType),
      pointsReward: _calculateRewardPoints(difficulty, targetCount),
      startDate: DateTime.now(),
      endDate: DateTime.now().add(_getDurationTime(duration)),
      targetValue: targetCount,
      challengeType: challengeId,
      currentProgress: 0,
      rewardBadges: _generateRewardBadges(difficulty, targetCount),
    );
  }

  /// Calculate target count based on difficulty and duration
  static int _calculateTargetCount(
      ChallengeDifficulty difficulty, ChallengeDuration duration) {
    int baseCount;

    switch (difficulty) {
      case ChallengeDifficulty.easy:
        baseCount = 3; // 3 new movies
        break;
      case ChallengeDifficulty.medium:
        baseCount = 2; // 2 special category movies
        break;
      case ChallengeDifficulty.hard:
        baseCount = 3; // 3 different discovery sources
        break;
      case ChallengeDifficulty.expert:
        baseCount = 5; // 5 diverse discoveries with all categories
        break;
    }

    switch (duration) {
      case ChallengeDuration.daily:
        return 1; // Always 1 for daily
      case ChallengeDuration.weekly:
        return baseCount;
      case ChallengeDuration.monthly:
        return (baseCount * 2).ceil();
    }
  }

  /// Get quest type description
  static String _getQuestType(ChallengeDifficulty difficulty) {
    switch (difficulty) {
      case ChallengeDifficulty.easy:
        return 'new movies';
      case ChallengeDifficulty.medium:
        return 'special films';
      case ChallengeDifficulty.hard:
        return 'discovery sources';
      case ChallengeDifficulty.expert:
        return 'diverse discoveries';
    }
  }

  /// Generate challenge title
  static String _generateTitle(int targetCount, String questType) {
    switch (questType) {
      case 'new movies':
        return 'Movie Explorer: Discover $targetCount New Films';
      case 'special films':
        return 'Cinema Adventurer: Find $targetCount Special Films';
      case 'discovery sources':
        return 'Discovery Master: Use $targetCount Different Sources';
      default:
        return 'Discovery Quest Challenge';
    }
  }

  /// Generate challenge description
  static String _generateDescription(int targetCount, String questType) {
    switch (questType) {
      case 'new movies':
        return 'Expand your cinematic horizons by discovering $targetCount movies you\'ve never seen before!';
      case 'special films':
        return 'Seek out $targetCount special films: new releases, indie gems, or foreign cinema treasures.';
      case 'discovery sources':
        return 'Become a true film explorer by discovering movies through $targetCount different sources and methods!';
      default:
        return 'Embark on a quest to discover amazing films and expand your movie knowledge!';
    }
  }

  /// Calculate reward points
  static int _calculateRewardPoints(
      ChallengeDifficulty difficulty, int targetCount) {
    int basePoints;

    switch (difficulty) {
      case ChallengeDifficulty.easy:
        basePoints = 50;
        break;
      case ChallengeDifficulty.medium:
        basePoints = 80;
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

    if (targetCount >= 3) {
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

  /// Update progress for Discovery Quest challenge
  static Challenge? updateProgress(
    Challenge challenge,
    String movieId,
    String discoverySource, {
    bool isNewRelease = false,
  }) {
    if (challenge.challengeType != challengeId ||
        challenge.currentProgress >= challenge.targetValue) {
      return null;
    }

    final newProgress = challenge.currentProgress + 1;

    return challenge.copyWith(
      currentProgress: newProgress,
    );
  }
}
