import 'user_level.dart';

/// User progress model for tracking gamification metrics
class UserProgress {
  const UserProgress({
    required this.userId,
    required this.totalPoints,
    required this.currentLevel,
    required this.moviesWatched,
    required this.moviesFavorited,
    required this.contentShared,
    required this.reviewsWritten,
    required this.watchlistsCompleted,
    required this.genresExplored,
    required this.streakDays,
    required this.lastActivityDate,
    this.weeklyGoalProgress = 0,
    this.monthlyGoalProgress = 0,
    this.totalTimeWatched = 0,
    this.genreStats = const {},
    this.favoritesAdded = 0,
    this.moviesShared = 0,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      userId: json['userId'] as String,
      totalPoints: json['totalPoints'] as int? ?? 0,
      currentLevel: json['currentLevel'] as int? ?? 1,
      moviesWatched: json['moviesWatched'] as int? ?? 0,
      moviesFavorited: json['moviesFavorited'] as int? ?? 0,
      contentShared: json['contentShared'] as int? ?? 0,
      reviewsWritten: json['reviewsWritten'] as int? ?? 0,
      watchlistsCompleted: json['watchlistsCompleted'] as int? ?? 0,
      genresExplored: json['genresExplored'] as int? ?? 0,
      streakDays: json['streakDays'] as int? ?? 0,
      lastActivityDate: DateTime.parse(json['lastActivityDate'] as String),
      weeklyGoalProgress: json['weeklyGoalProgress'] as int? ?? 0,
      monthlyGoalProgress: json['monthlyGoalProgress'] as int? ?? 0,
      totalTimeWatched: json['totalTimeWatched'] as int? ?? 0,
      genreStats: Map<String, int>.from(json['genreStats'] as Map? ?? {}),
      favoritesAdded: json['favoritesAdded'] as int? ?? 0,
      moviesShared: json['moviesShared'] as int? ?? 0,
    );
  }

  /// Create initial progress for a new user
  factory UserProgress.initial(String userId) {
    return UserProgress(
      userId: userId,
      totalPoints: 0,
      currentLevel: 1,
      moviesWatched: 0,
      moviesFavorited: 0,
      contentShared: 0,
      reviewsWritten: 0,
      watchlistsCompleted: 0,
      genresExplored: 0,
      streakDays: 0,
      lastActivityDate: DateTime.now(),
    );
  }

  final String userId;
  final int totalPoints;
  final int currentLevel;
  final int moviesWatched;
  final int moviesFavorited;
  final int contentShared;
  final int reviewsWritten;
  final int watchlistsCompleted;
  final int genresExplored;
  final int streakDays;
  final DateTime lastActivityDate;
  final int weeklyGoalProgress;
  final int monthlyGoalProgress;
  final int totalTimeWatched; // in minutes
  final Map<String, int> genreStats;
  final int favoritesAdded;
  final int moviesShared;

  /// Calculate points needed for next level
  int get pointsForNextLevel {
    const basePoints = 100;
    const multiplier = 1.5;
    return (basePoints * (currentLevel * multiplier)).round();
  }

  /// Calculate progress to next level (0.0 to 1.0)
  double get levelProgress {
    final currentLevelPoints =
        currentLevel > 1 ? (100 * ((currentLevel - 1) * 1.5)).round() : 0;
    final nextLevelPoints = pointsForNextLevel;
    final progressPoints = totalPoints - currentLevelPoints;
    final neededPoints = nextLevelPoints - currentLevelPoints;

    return neededPoints > 0
        ? (progressPoints / neededPoints).clamp(0.0, 1.0)
        : 1.0;
  }

  /// Check if user is active (activity within last 7 days)
  bool get isActive {
    final now = DateTime.now();
    final difference = now.difference(lastActivityDate).inDays;
    return difference <= 7;
  }

  /// Calculate engagement score (0.0 to 1.0)
  double get engagementScore {
    final factors = [
      (moviesWatched / 100.0).clamp(0.0, 1.0),
      (reviewsWritten / 50.0).clamp(0.0, 1.0),
      (contentShared / 25.0).clamp(0.0, 1.0),
      (streakDays / 30.0).clamp(0.0, 1.0),
      (genresExplored / 20.0).clamp(0.0, 1.0),
    ];

    return factors.reduce((a, b) => a + b) / factors.length;
  }

  /// Convert currentLevel to UserLevel enum
  UserLevel get level {
    if (totalPoints >= 5000) return UserLevel.legend;
    if (totalPoints >= 3000) return UserLevel.master;
    if (totalPoints >= 1500) return UserLevel.expert;
    if (totalPoints >= 500) return UserLevel.enthusiast;
    return UserLevel.novice;
  }

  UserProgress copyWith({
    String? userId,
    int? totalPoints,
    int? currentLevel,
    int? moviesWatched,
    int? moviesFavorited,
    int? contentShared,
    int? reviewsWritten,
    int? watchlistsCompleted,
    int? genresExplored,
    int? streakDays,
    DateTime? lastActivityDate,
    int? weeklyGoalProgress,
    int? monthlyGoalProgress,
    int? totalTimeWatched,
    Map<String, int>? genreStats,
    int? favoritesAdded,
    int? moviesShared,
  }) {
    return UserProgress(
      userId: userId ?? this.userId,
      totalPoints: totalPoints ?? this.totalPoints,
      currentLevel: currentLevel ?? this.currentLevel,
      moviesWatched: moviesWatched ?? this.moviesWatched,
      moviesFavorited: moviesFavorited ?? this.moviesFavorited,
      contentShared: contentShared ?? this.contentShared,
      reviewsWritten: reviewsWritten ?? this.reviewsWritten,
      watchlistsCompleted: watchlistsCompleted ?? this.watchlistsCompleted,
      genresExplored: genresExplored ?? this.genresExplored,
      streakDays: streakDays ?? this.streakDays,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      weeklyGoalProgress: weeklyGoalProgress ?? this.weeklyGoalProgress,
      monthlyGoalProgress: monthlyGoalProgress ?? this.monthlyGoalProgress,
      totalTimeWatched: totalTimeWatched ?? this.totalTimeWatched,
      genreStats: genreStats ?? this.genreStats,
      favoritesAdded: favoritesAdded ?? this.favoritesAdded,
      moviesShared: moviesShared ?? this.moviesShared,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'totalPoints': totalPoints,
      'currentLevel': currentLevel,
      'moviesWatched': moviesWatched,
      'moviesFavorited': moviesFavorited,
      'contentShared': contentShared,
      'reviewsWritten': reviewsWritten,
      'watchlistsCompleted': watchlistsCompleted,
      'genresExplored': genresExplored,
      'streakDays': streakDays,
      'lastActivityDate': lastActivityDate.toIso8601String(),
      'weeklyGoalProgress': weeklyGoalProgress,
      'monthlyGoalProgress': monthlyGoalProgress,
      'totalTimeWatched': totalTimeWatched,
      'genreStats': genreStats,
      'favoritesAdded': favoritesAdded,
      'moviesShared': moviesShared,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProgress && other.userId == userId;
  }

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() {
    return 'UserProgress(userId: $userId, totalPoints: $totalPoints, level: $currentLevel, moviesWatched: $moviesWatched)';
  }
}
