import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'achievement_categories.dart';
import 'models/achievement.dart';

/// Service for managing achievements
class AchievementSystemService {
  final List<Achievement> _achievements = [];
  final List<Achievement> _unlockedAchievements = [];

  /// Initialize achievements from categories
  void initializeAchievements() {
    _achievements.clear();
    _achievements.addAll(AchievementCategories.allAchievements);
  }

  /// Get all achievements
  List<Achievement> getAllAchievements() {
    return List.unmodifiable(_achievements);
  }

  /// Get unlocked achievements
  List<Achievement> getUnlockedAchievements() {
    return List.unmodifiable(_unlockedAchievements);
  }

  /// Get locked achievements
  List<Achievement> getLockedAchievements() {
    return _achievements
        .where((achievement) => !achievement.isUnlocked)
        .toList();
  }

  /// Get recent achievements (last 10)
  List<Achievement> getRecentAchievements() {
    final recent = _unlockedAchievements
        .where((achievement) => achievement.unlockedAt != null)
        .toList()
      ..sort((a, b) => (b.unlockedAt ?? DateTime(1970)).compareTo(a.unlockedAt ?? DateTime(1970)));
    return recent.take(10).toList();
  }

  /// Check if achievement is unlocked
  bool isAchievementUnlocked(String achievementId) {
    return _unlockedAchievements
        .any((achievement) => achievement.id == achievementId);
  }

  /// Unlock achievement
  bool unlockAchievement(String achievementId) {
    final achievementIndex =
        _achievements.indexWhere((a) => a.id == achievementId);
    if (achievementIndex == -1) {
      throw Exception('Achievement not found: $achievementId');
    }

    final achievement = _achievements[achievementIndex];

    if (achievement.isUnlocked) {
      return false; // Already unlocked
    }

    final updatedAchievement = achievement.copyWith(
      isUnlocked: true,
      unlockedAt: DateTime.now(),
    );

    _achievements[achievementIndex] = updatedAchievement;
    _unlockedAchievements.add(updatedAchievement);
    return true;
  }

  /// Update achievement progress
  void updateAchievementProgress(String achievementId, int progress) {
    final achievementIndex =
        _achievements.indexWhere((a) => a.id == achievementId);
    if (achievementIndex == -1) {
      throw Exception('Achievement not found: $achievementId');
    }
    final achievement = _achievements[achievementIndex];

    _achievements[achievementIndex] =
        achievement.copyWith(progress: progress);

    // Auto-unlock if target reached
    if (progress >= achievement.maxProgress && !achievement.isUnlocked) {
      unlockAchievement(achievementId);
    }
  }

  /// Get achievement progress percentage
  double getAchievementProgress(String achievementId) {
    final achievement = _achievements.firstWhere(
      (a) => a.id == achievementId,
      orElse: () => throw Exception('Achievement not found: $achievementId'),
    );

    if (achievement.isUnlocked) return 1.0;
    return (achievement.progress / achievement.maxProgress).clamp(0.0, 1.0);
  }

  /// Get achievements by category
  List<Achievement> getAchievementsByCategory(AchievementCategory category) {
    return _achievements
        .where((achievement) => achievement.category == category)
        .toList();
  }

  /// Get total points earned from achievements
  int getTotalAchievementPoints() {
    return _unlockedAchievements.fold(
        0, (sum, achievement) => sum + achievement.points);
  }

  /// Get achievement statistics
  AchievementStats getAchievementStats() {
    final total = _achievements.length;
    final unlocked = _unlockedAchievements.length;
    final locked = total - unlocked;
    final totalPoints = getTotalAchievementPoints();

    return AchievementStats(
      totalAchievements: total,
      unlockedAchievements: unlocked,
      lockedAchievements: locked,
      totalPoints: totalPoints,
      completionPercentage: total > 0 ? (unlocked / total) * 100 : 0,
    );
  }
}

/// Achievement statistics model
class AchievementStats {
  const AchievementStats({
    required this.totalAchievements,
    required this.unlockedAchievements,
    required this.lockedAchievements,
    required this.totalPoints,
    required this.completionPercentage,
  });
  final int totalAchievements;
  final int unlockedAchievements;
  final int lockedAchievements;
  final int totalPoints;
  final double completionPercentage;
}

/// Providers
final achievementSystemProvider = Provider<AchievementSystemService>((ref) {
  final service = AchievementSystemService();
  service.initializeAchievements();
  return service;
});

final allAchievementsProvider = Provider<List<Achievement>>((ref) {
  final service = ref.watch(achievementSystemProvider);
  return service.getAllAchievements();
});

final unlockedAchievementsProvider = Provider<List<Achievement>>((ref) {
  final service = ref.watch(achievementSystemProvider);
  return service.getUnlockedAchievements();
});

final recentAchievementsProvider = Provider<List<Achievement>>((ref) {
  final service = ref.watch(achievementSystemProvider);
  return service.getRecentAchievements();
});

final achievementStatsProvider = Provider<AchievementStats>((ref) {
  final service = ref.watch(achievementSystemProvider);
  return service.getAchievementStats();
});