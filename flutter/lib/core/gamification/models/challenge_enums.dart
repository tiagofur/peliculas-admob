/// Challenge-related enums used across the gamification system
library;

/// Represents different types of challenges
enum ChallengeType {
  genreExplorer,
  marathonWeekend,
  socialSharer,
  reviewMaster,
  discoveryQuest,
}

/// Represents challenge difficulty levels
enum ChallengeDifficulty {
  easy,
  medium,
  hard,
  expert,
}

/// Extension for ChallengeDifficulty to provide display names
extension ChallengeDifficultyExtension on ChallengeDifficulty {
  String get displayName {
    switch (this) {
      case ChallengeDifficulty.easy:
        return 'Easy';
      case ChallengeDifficulty.medium:
        return 'Medium';
      case ChallengeDifficulty.hard:
        return 'Hard';
      case ChallengeDifficulty.expert:
        return 'Expert';
    }
  }
}

/// Represents challenge duration
enum ChallengeDuration {
  daily,
  weekly,
  monthly,
}

/// Represents different types of user activities for gamification tracking
enum ActivityType {
  watchMovie,
  addToFavorites,
  shareContent,
  writeReview,
  completeWatchlist,
  discoverNewRelease,
}
