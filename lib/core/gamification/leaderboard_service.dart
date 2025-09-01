import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// Service for managing leaderboards
class LeaderboardService {
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();
  static final LeaderboardService _instance = LeaderboardService._internal();

  final Map<String, List<LeaderboardEntry>> _leaderboards = {};
  final StreamController<LeaderboardUpdate> _updateController =
      StreamController<LeaderboardUpdate>.broadcast();

  Stream<LeaderboardUpdate> get updateStream => _updateController.stream;

  /// Get leaderboard for specific category and time period
  Future<List<LeaderboardEntry>> getLeaderboard(
    LeaderboardQuery query,
  ) async {
    final key = '${query.category.name}_${query.timePeriod.name}';

    if (!_leaderboards.containsKey(key)) {
      await _loadLeaderboard(query.category, query.timePeriod);
    }

    final entries = _leaderboards[key] ?? [];
    return entries.take(query.limit).toList();
  }

  /// Get user's position in leaderboard
  Future<LeaderboardPosition?> getUserPosition(
    UserLeaderboardQuery query,
  ) async {
    final leaderboard = await getLeaderboard(
      LeaderboardQuery(
        category: query.category,
        timePeriod: query.timePeriod,
      ),
    );

    for (int i = 0; i < leaderboard.length; i++) {
      if (leaderboard[i].userId == query.userId) {
        return LeaderboardPosition(
          rank: i + 1,
          entry: leaderboard[i],
          totalParticipants: leaderboard.length,
        );
      }
    }

    return null;
  }

  /// Update user's score in leaderboard
  Future<void> updateUserScore({
    required String userId,
    required String username,
    required String? avatarUrl,
    required LeaderboardCategory category,
    required LeaderboardTimePeriod timePeriod,
    required int score,
  }) async {
    final key = '${category.name}_${timePeriod.name}';

    if (!_leaderboards.containsKey(key)) {
      _leaderboards[key] = [];
    }

    final entries = _leaderboards[key]!;
    final existingIndex = entries.indexWhere((e) => e.userId == userId);

    final newEntry = LeaderboardEntry(
      userId: userId,
      username: username,
      avatarUrl: avatarUrl,
      score: score,
      lastUpdated: DateTime.now(),
    );

    if (existingIndex >= 0) {
      // Update existing entry
      final oldEntry = entries[existingIndex];
      entries[existingIndex] = newEntry;

      // Check if position changed significantly
      _sortLeaderboard(entries);
      final newIndex = entries.indexWhere((e) => e.userId == userId);

      if ((existingIndex - newIndex).abs() > 2) {
        _updateController.add(LeaderboardUpdate(
          category: category,
          timePeriod: timePeriod,
          type: LeaderboardUpdateType.positionChanged,
          userId: userId,
          oldRank: existingIndex + 1,
          newRank: newIndex + 1,
          scoreChange: score - oldEntry.score,
        ));
      }
    } else {
      // Add new entry
      entries.add(newEntry);
      _sortLeaderboard(entries);

      final newIndex = entries.indexWhere((e) => e.userId == userId);
      _updateController.add(LeaderboardUpdate(
        category: category,
        timePeriod: timePeriod,
        type: LeaderboardUpdateType.newEntry,
        userId: userId,
        newRank: newIndex + 1,
        scoreChange: score,
      ));
    }
  }

  /// Load leaderboard data (simulated for now)
  Future<void> _loadLeaderboard(
      LeaderboardCategory category, LeaderboardTimePeriod timePeriod) async {
    final key = '${category.name}_${timePeriod.name}';

    // Simulate loading from database/API
    await Future.delayed(const Duration(milliseconds: 500));

    // Generate mock data for demonstration
    final entries = _generateMockLeaderboardData(category, timePeriod);
    _leaderboards[key] = entries;
  }

  /// Generate mock leaderboard data
  List<LeaderboardEntry> _generateMockLeaderboardData(
      LeaderboardCategory category, LeaderboardTimePeriod timePeriod) {
    final random = Random();
    final entries = <LeaderboardEntry>[];

    final usernames = [
      'MovieMaster',
      'CinemaLover',
      'FilmBuff',
      'ScreenQueen',
      'ReelExpert',
      'MovieNinja',
      'FilmFanatic',
      'CinephileX',
      'ScreenStar',
      'MovieGuru',
      'FilmWizard',
      'CinemaKing',
      'MovieMaven',
      'ScreenLegend',
      'FilmHero',
      'CinemaChamp',
      'MoviePro',
      'FilmGenius',
      'ScreenMaster',
      'CinemaElite',
    ];

    for (int i = 0; i < usernames.length; i++) {
      final baseScore = _getBaseScoreForCategory(category);
      final variance = (baseScore * 0.3).round();
      final score = baseScore + random.nextInt(variance) - (variance ~/ 2);

      entries.add(LeaderboardEntry(
        userId: 'user_${i + 1}',
        username: usernames[i],
        avatarUrl:
            'https://api.dicebear.com/7.x/avataaars/svg?seed=${usernames[i]}',
        score: max(0, score - (i * 50)), // Decrease score for lower ranks
        lastUpdated:
            DateTime.now().subtract(Duration(hours: random.nextInt(24))),
      ));
    }

    _sortLeaderboard(entries);
    return entries;
  }

  /// Get base score for category
  int _getBaseScoreForCategory(LeaderboardCategory category) {
    switch (category) {
      case LeaderboardCategory.totalPoints:
        return 5000;
      case LeaderboardCategory.moviesWatched:
        return 150;
      case LeaderboardCategory.achievementsUnlocked:
        return 25;
      case LeaderboardCategory.streakDays:
        return 30;
      case LeaderboardCategory.genresExplored:
        return 15;
      case LeaderboardCategory.socialShares:
        return 50;
      case LeaderboardCategory.reviewsWritten:
        return 20;
    }
  }

  /// Sort leaderboard entries by score
  void _sortLeaderboard(List<LeaderboardEntry> entries) {
    entries.sort((a, b) => b.score.compareTo(a.score));
  }

  /// Get leaderboard statistics
  Future<LeaderboardStats> getLeaderboardStats(
    LeaderboardQuery query,
  ) async {
    final entries = await getLeaderboard(query);

    if (entries.isEmpty) {
      return LeaderboardStats(
        totalParticipants: 0,
        averageScore: 0,
        topScore: 0,
        scoreDistribution: {},
      );
    }

    final scores = entries.map((e) => e.score).toList();
    final totalScore = scores.reduce((a, b) => a + b);
    final averageScore = totalScore / scores.length;

    // Calculate score distribution
    final distribution = <String, int>{};
    for (final score in scores) {
      final range = _getScoreRange(score);
      distribution[range] = (distribution[range] ?? 0) + 1;
    }

    return LeaderboardStats(
      totalParticipants: entries.length,
      averageScore: averageScore,
      topScore: scores.first,
      scoreDistribution: distribution,
    );
  }

  /// Get score range for distribution
  String _getScoreRange(int score) {
    if (score < 100) return '0-99';
    if (score < 500) return '100-499';
    if (score < 1000) return '500-999';
    if (score < 2500) return '1000-2499';
    if (score < 5000) return '2500-4999';
    return '5000+';
  }

  /// Reset leaderboard for time period
  Future<void> resetLeaderboard({
    required LeaderboardCategory category,
    required LeaderboardTimePeriod timePeriod,
  }) async {
    final key = '${category.name}_${timePeriod.name}';
    _leaderboards.remove(key);

    _updateController.add(LeaderboardUpdate(
      category: category,
      timePeriod: timePeriod,
      type: LeaderboardUpdateType.reset,
    ));
  }

  /// Dispose resources
  void dispose() {
    _updateController.close();
  }
}

/// Leaderboard categories
enum LeaderboardCategory {
  totalPoints,
  moviesWatched,
  achievementsUnlocked,
  streakDays,
  genresExplored,
  socialShares,
  reviewsWritten,
}

/// Leaderboard time periods
enum LeaderboardTimePeriod {
  daily,
  weekly,
  monthly,
  allTime,
}

/// Leaderboard entry
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.score,
    required this.lastUpdated,
  });
  final String userId;
  final String username;
  final String? avatarUrl;
  final int score;
  final DateTime lastUpdated;

  LeaderboardEntry copyWith({
    String? userId,
    String? username,
    String? avatarUrl,
    int? score,
    DateTime? lastUpdated,
  }) {
    return LeaderboardEntry(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      score: score ?? this.score,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// User's position in leaderboard
class LeaderboardPosition {
  const LeaderboardPosition({
    required this.rank,
    required this.entry,
    required this.totalParticipants,
  });
  final int rank;
  final LeaderboardEntry entry;
  final int totalParticipants;

  double get percentile => (totalParticipants - rank + 1) / totalParticipants;
}

/// Leaderboard update event
class LeaderboardUpdate {
  const LeaderboardUpdate({
    required this.category,
    required this.timePeriod,
    required this.type,
    this.userId,
    this.oldRank,
    this.newRank,
    this.scoreChange,
  });
  final LeaderboardCategory category;
  final LeaderboardTimePeriod timePeriod;
  final LeaderboardUpdateType type;
  final String? userId;
  final int? oldRank;
  final int? newRank;
  final int? scoreChange;
}

/// Leaderboard update types
enum LeaderboardUpdateType {
  newEntry,
  positionChanged,
  scoreUpdated,
  reset,
}

/// Leaderboard statistics
class LeaderboardStats {
  const LeaderboardStats({
    required this.totalParticipants,
    required this.averageScore,
    required this.topScore,
    required this.scoreDistribution,
  });
  final int totalParticipants;
  final double averageScore;
  final int topScore;
  final Map<String, int> scoreDistribution;
}

/// Extension for leaderboard category display
extension LeaderboardCategoryExtension on LeaderboardCategory {
  String get displayName {
    switch (this) {
      case LeaderboardCategory.totalPoints:
        return 'Total Points';
      case LeaderboardCategory.moviesWatched:
        return 'Movies Watched';
      case LeaderboardCategory.achievementsUnlocked:
        return 'Achievements';
      case LeaderboardCategory.streakDays:
        return 'Streak Days';
      case LeaderboardCategory.genresExplored:
        return 'Genres Explored';
      case LeaderboardCategory.socialShares:
        return 'Social Shares';
      case LeaderboardCategory.reviewsWritten:
        return 'Reviews Written';
    }
  }

  IconData get icon {
    switch (this) {
      case LeaderboardCategory.totalPoints:
        return Icons.stars;
      case LeaderboardCategory.moviesWatched:
        return Icons.movie;
      case LeaderboardCategory.achievementsUnlocked:
        return Icons.emoji_events;
      case LeaderboardCategory.streakDays:
        return Icons.local_fire_department;
      case LeaderboardCategory.genresExplored:
        return Icons.explore;
      case LeaderboardCategory.socialShares:
        return Icons.share;
      case LeaderboardCategory.reviewsWritten:
        return Icons.rate_review;
    }
  }
}

/// Extension for time period display
extension LeaderboardTimePeriodExtension on LeaderboardTimePeriod {
  String get displayName {
    switch (this) {
      case LeaderboardTimePeriod.daily:
        return 'Today';
      case LeaderboardTimePeriod.weekly:
        return 'This Week';
      case LeaderboardTimePeriod.monthly:
        return 'This Month';
      case LeaderboardTimePeriod.allTime:
        return 'All Time';
    }
  }
}

/// Query classes
class LeaderboardQuery {
  const LeaderboardQuery({
    required this.category,
    required this.timePeriod,
    this.limit = 100,
  });
  final LeaderboardCategory category;
  final LeaderboardTimePeriod timePeriod;
  final int limit;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LeaderboardQuery &&
        other.category == category &&
        other.timePeriod == timePeriod &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(category, timePeriod, limit);
}

class UserLeaderboardQuery {
  const UserLeaderboardQuery({
    required this.userId,
    required this.category,
    required this.timePeriod,
  });
  final String userId;
  final LeaderboardCategory category;
  final LeaderboardTimePeriod timePeriod;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserLeaderboardQuery &&
        other.userId == userId &&
        other.category == category &&
        other.timePeriod == timePeriod;
  }

  @override
  int get hashCode => Object.hash(userId, category, timePeriod);
}