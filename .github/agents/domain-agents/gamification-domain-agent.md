# Gamification Domain Agent - peliculas-admob

## 🎮 Role

You are a domain expert for Gamification features in peliculas-admob, specializing in points, achievements, levels, and user engagement mechanics.

## 🎯 Domain Expertise

- **Points System**: Award points for user actions
- **Achievements**: Unlock badges and milestones
- **Levels**: User progression system
- **Leaderboards**: Competitive rankings
- **Challenges**: Daily/weekly challenges

## 📊 Domain Context

### Gamification Entities

```dart
// lib/domain/entities/user_stats.dart
import 'package:equatable/equatable.dart';

class UserStats extends Equatable {
  final String userId;
  final int totalPoints;
  final int level;
  final int moviesWatched;
  final int moviesRated;
  final int listsCreated;
  final List<Achievement> achievements;
  final DateTime lastUpdated;

  const UserStats({
    required this.userId,
    required this.totalPoints,
    required this.level,
    required this.moviesWatched,
    required this.moviesRated,
    required this.listsCreated,
    this.achievements = const [],
    required this.lastUpdated,
  });

  int get pointsToNextLevel => _calculatePointsToNextLevel();
  double get progressToNextLevel => _calculateProgress();

  int _calculatePointsToNextLevel() {
    final nextLevel = level + 1;
    final requiredPoints = nextLevel * 100; // 100 points per level
    return requiredPoints - (totalPoints % 100);
  }

  double _calculateProgress() {
    final currentLevelPoints = totalPoints % 100;
    return currentLevelPoints / 100.0;
  }

  @override
  List<Object?> get props => [
    userId, totalPoints, level, moviesWatched,
    moviesRated, listsCreated, achievements, lastUpdated,
  ];
}

class Achievement extends Equatable {
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  final int pointsAwarded;
  final DateTime unlockedAt;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.pointsAwarded,
    required this.unlockedAt,
  });

  @override
  List<Object?> get props => [
    id, name, description, iconUrl,
    pointsAwarded, unlockedAt,
  ];
}
```

## 📋 Key Responsibilities

### Gamification Service

```dart
// lib/domain/services/gamification_service.dart
import '../entities/user_stats.dart';
import '../../core/logging/logger_factory.dart';

class GamificationService {
  // Point values for different actions
  static const int POINTS_WATCH_MOVIE = 10;
  static const int POINTS_RATE_MOVIE = 5;
  static const int POINTS_CREATE_LIST = 15;
  static const int POINTS_SHARE_MOVIE = 3;
  static const int POINTS_DAILY_LOGIN = 2;

  Future<UserStats> awardPoints(
    UserStats currentStats,
    int points,
    String reason,
  ) async {
    LoggerFactory.info('Awarding $points points for: $reason');

    final newTotalPoints = currentStats.totalPoints + points;
    final newLevel = _calculateLevel(newTotalPoints);

    // Check if level up
    if (newLevel > currentStats.level) {
      LoggerFactory.info('User leveled up to level $newLevel!');
      // Could trigger achievement or notification
    }

    return UserStats(
      userId: currentStats.userId,
      totalPoints: newTotalPoints,
      level: newLevel,
      moviesWatched: currentStats.moviesWatched,
      moviesRated: currentStats.moviesRated,
      listsCreated: currentStats.listsCreated,
      achievements: currentStats.achievements,
      lastUpdated: DateTime.now(),
    );
  }

  Future<UserStats> onMovieWatched(UserStats stats) async {
    final updatedStats = await awardPoints(
      stats,
      POINTS_WATCH_MOVIE,
      'Watched movie',
    );

    return updatedStats.copyWith(
      moviesWatched: stats.moviesWatched + 1,
    );
  }

  Future<UserStats> onMovieRated(UserStats stats) async {
    final updatedStats = await awardPoints(
      stats,
      POINTS_RATE_MOVIE,
      'Rated movie',
    );

    return updatedStats.copyWith(
      moviesRated: stats.moviesRated + 1,
    );
  }

  Future<List<Achievement>> checkAchievements(UserStats stats) async {
    final newAchievements = <Achievement>[];

    // Check for milestone achievements
    if (stats.moviesWatched == 10 && !_hasAchievement(stats, 'first_10')) {
      newAchievements.add(_createAchievement('first_10', 'Cinephile Beginner'));
    }

    if (stats.moviesWatched == 50 && !_hasAchievement(stats, 'first_50')) {
      newAchievements.add(_createAchievement('first_50', 'Movie Buff'));
    }

    if (stats.moviesWatched == 100 && !_hasAchievement(stats, 'first_100')) {
      newAchievements.add(_createAchievement('first_100', 'Film Fanatic'));
    }

    if (stats.moviesRated >= 25 && !_hasAchievement(stats, 'critic')) {
      newAchievements.add(_createAchievement('critic', 'Amateur Critic'));
    }

    return newAchievements;
  }

  int _calculateLevel(int totalPoints) {
    return (totalPoints / 100).floor() + 1;
  }

  bool _hasAchievement(UserStats stats, String achievementId) {
    return stats.achievements.any((a) => a.id == achievementId);
  }

  Achievement _createAchievement(String id, String name) {
    return Achievement(
      id: id,
      name: name,
      description: 'Unlocked by reaching a milestone',
      iconUrl: '/assets/achievements/$id.png',
      pointsAwarded: 50,
      unlockedAt: DateTime.now(),
    );
  }
}

extension UserStatsExtension on UserStats {
  UserStats copyWith({
    int? totalPoints,
    int? level,
    int? moviesWatched,
    int? moviesRated,
    int? listsCreated,
    List<Achievement>? achievements,
  }) {
    return UserStats(
      userId: userId,
      totalPoints: totalPoints ?? this.totalPoints,
      level: level ?? this.level,
      moviesWatched: moviesWatched ?? this.moviesWatched,
      moviesRated: moviesRated ?? this.moviesRated,
      listsCreated: listsCreated ?? this.listsCreated,
      achievements: achievements ?? this.achievements,
      lastUpdated: DateTime.now(),
    );
  }
}
```

## 🎯 Providers

```dart
// lib/presentation/providers/gamification_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user_stats.dart';
import '../../domain/services/gamification_service.dart';

final gamificationServiceProvider = Provider<GamificationService>((ref) {
  return GamificationService();
});

final userStatsProvider = StreamProvider<UserStats?>((ref) {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return Stream.value(null);

  final repository = ref.watch(gamificationRepositoryProvider);
  return repository.watchUserStats(userId);
});

final achievementsProvider = Provider<List<Achievement>>((ref) {
  final stats = ref.watch(userStatsProvider).valueOrNull;
  return stats?.achievements ?? [];
});
```

## 🎮 UI Integration Example

```dart
// lib/presentation/widgets/user_stats_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserStatsWidget extends ConsumerWidget {
  const UserStatsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userStatsProvider);

    return statsAsync.when(
      data: (stats) {
        if (stats == null) return const SizedBox();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Level ${stats.level}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: stats.progressToNextLevel,
                ),
                const SizedBox(height: 4),
                Text('${stats.pointsToNextLevel} points to next level'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      icon: Icons.movie,
                      label: 'Watched',
                      value: stats.moviesWatched.toString(),
                    ),
                    _StatItem(
                      icon: Icons.star,
                      label: 'Rated',
                      value: stats.moviesRated.toString(),
                    ),
                    _StatItem(
                      icon: Icons.emoji_events,
                      label: 'Achievements',
                      value: stats.achievements.length.toString(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const SizedBox(),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(label),
      ],
    );
  }
}
```

---

**Agent Version**: 1.0.0  
**Domain**: Gamification, Points, Achievements
