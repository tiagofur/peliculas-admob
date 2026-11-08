import '../models/badge_type.dart';
import '../models/challenge.dart';
import '../models/challenge_enums.dart';
import '../models/user_progress.dart';

/// Genre Explorer Challenge Implementation
class GenreExplorerChallenge {
  static const String challengeId = 'genre_explorer';

  /// Generate a Genre Explorer challenge based on user behavior
  static Challenge generateChallenge({
    required UserProgress userBehavior,
    required ChallengeDifficulty difficulty,
    required ChallengeDuration duration,
  }) {
    final targetGenres = _selectTargetGenres(userBehavior, difficulty);
    final targetCount = _calculateTargetCount(difficulty, duration);

    return Challenge(
      id: '${challengeId}_${DateTime.now().millisecondsSinceEpoch}',
      title: _generateTitle(targetGenres, targetCount),
      description: _generateDescription(targetGenres, targetCount),
      pointsReward: _calculateRewardPoints(difficulty, targetCount),
      startDate: DateTime.now(),
      endDate: DateTime.now().add(_getDurationTime(duration)),
      targetValue: targetCount,
      challengeType: challengeId,
      currentProgress: 0,
      rewardBadges: _generateRewardBadges(difficulty, targetCount),
    );
  }

  /// Select target genres based on user behavior and difficulty
  static List<String> _selectTargetGenres(
      UserProgress userBehavior, ChallengeDifficulty difficulty) {
    final allGenres = [
      'Action',
      'Adventure',
      'Animation',
      'Comedy',
      'Crime',
      'Documentary',
      'Drama',
      'Family',
      'Fantasy',
      'History',
      'Horror',
      'Music',
      'Mystery',
      'Romance',
      'Science Fiction',
      'TV Movie',
      'Thriller',
      'War',
      'Western'
    ];

    // Since UserProgress doesn't have genreStats, we'll use a mock approach
    // based on the number of genres explored to simulate favorite genres
    final favoriteGenres = _getMockFavoriteGenres(userBehavior.genresExplored);
    final unexploredGenres =
        allGenres.where((genre) => !favoriteGenres.contains(genre)).toList();

    List<String> targetGenres = [];

    switch (difficulty) {
      case ChallengeDifficulty.easy:
        // Mix of favorite and 1-2 new genres
        targetGenres.addAll(favoriteGenres.take(2));
        if (unexploredGenres.isNotEmpty) {
          targetGenres.add(unexploredGenres.first);
        }
        break;

      case ChallengeDifficulty.medium:
        // Mostly new genres with 1 favorite
        if (favoriteGenres.isNotEmpty) {
          targetGenres.add(favoriteGenres.first);
        }
        targetGenres.addAll(unexploredGenres.take(3));
        break;

      case ChallengeDifficulty.hard:
        // All new genres
        targetGenres.addAll(unexploredGenres.take(5));
        break;

      case ChallengeDifficulty.expert:
        // All unexplored genres with specific criteria
        targetGenres.addAll(unexploredGenres.take(7));
        break;
    }

    return targetGenres.take(5).toList();
  }

  /// Calculate target count based on difficulty and duration
  static int _calculateTargetCount(
      ChallengeDifficulty difficulty, ChallengeDuration duration) {
    int baseCount;

    switch (difficulty) {
      case ChallengeDifficulty.easy:
        baseCount = 2;
        break;
      case ChallengeDifficulty.medium:
        baseCount = 3;
        break;
      case ChallengeDifficulty.hard:
        baseCount = 5;
        break;
      case ChallengeDifficulty.expert:
        baseCount = 7;
        break;
    }

    switch (duration) {
      case ChallengeDuration.daily:
        return (baseCount * 0.5).ceil();
      case ChallengeDuration.weekly:
        return baseCount;
      case ChallengeDuration.monthly:
        return (baseCount * 2).ceil();
    }
  }

  /// Generate challenge title
  static String _generateTitle(List<String> targetGenres, int targetCount) {
    if (targetGenres.length <= 2) {
      return 'Explore ${targetGenres.join(' & ')} Movies';
    } else {
      return 'Genre Explorer: Discover $targetCount New Genres';
    }
  }

  /// Generate challenge description
  static String _generateDescription(
      List<String> targetGenres, int targetCount) {
    if (targetGenres.length <= 2) {
      return 'Watch movies from ${targetGenres.join(' and ')} genres to expand your cinematic horizons!';
    } else {
      return 'Discover $targetCount different movie genres: ${targetGenres.join(', ')}. Each genre you explore brings you closer to becoming a true cinema connoisseur!';
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
        basePoints = 100;
        break;
      case ChallengeDifficulty.hard:
        basePoints = 200;
        break;
      case ChallengeDifficulty.expert:
        basePoints = 350;
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

  /// Update progress for Genre Explorer challenge
  static Challenge? updateProgress(Challenge challenge, String genre) {
    if (challenge.challengeType != challengeId ||
        challenge.currentProgress >= challenge.targetValue) {
      return null;
    }

    final newProgress = challenge.currentProgress + 1;

    return challenge.copyWith(
      currentProgress: newProgress,
    );
  }

  /// Generate mock favorite genres based on genres explored count
  static List<String> _getMockFavoriteGenres(int genresExplored) {
    final allGenres = [
      'Action',
      'Adventure',
      'Animation',
      'Comedy',
      'Crime',
      'Documentary',
      'Drama',
      'Family',
      'Fantasy',
      'History',
      'Horror',
      'Music',
      'Mystery',
      'Romance',
      'Science Fiction',
      'TV Movie',
      'Thriller',
      'War',
      'Western'
    ];

    // Return a subset of genres based on how many the user has explored
    final favoriteCount =
        (genresExplored * 0.6).ceil().clamp(0, allGenres.length);
    return allGenres.take(favoriteCount).toList();
  }
}
