import 'package:hive/hive.dart';

import 'achievement.dart';

part 'user_achievements.g.dart';

/// Representa el progreso y estado de logros de un usuario
@HiveType(typeId: 53)
class UserAchievements {
  UserAchievements({
    required this.userId,
    this.totalPoints = 0,
    this.unlockedAchievements = const [],
    this.achievementProgress = const {},
    this.lastUpdated,
    this.streaks = const {},
    this.milestones = const {},
  });

  @HiveField(0)
  final String userId;

  @HiveField(1)
  final int totalPoints;

  @HiveField(2)
  final List<String> unlockedAchievements;

  @HiveField(3)
  final Map<String, int> achievementProgress;

  @HiveField(4)
  final DateTime? lastUpdated;

  @HiveField(5)
  final Map<String, int> streaks; // Para tracking de rachas

  @HiveField(6)
  final Map<String, dynamic> milestones; // Para tracking de hitos especiales

  UserAchievements copyWith({
    String? userId,
    int? totalPoints,
    List<String>? unlockedAchievements,
    Map<String, int>? achievementProgress,
    DateTime? lastUpdated,
    Map<String, int>? streaks,
    Map<String, dynamic>? milestones,
  }) {
    return UserAchievements(
      userId: userId ?? this.userId,
      totalPoints: totalPoints ?? this.totalPoints,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
      achievementProgress: achievementProgress ?? this.achievementProgress,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      streaks: streaks ?? this.streaks,
      milestones: milestones ?? this.milestones,
    );
  }

  /// Verifica si un logro específico está desbloqueado
  bool isAchievementUnlocked(String achievementId) {
    return unlockedAchievements.contains(achievementId);
  }

  /// Obtiene el progreso actual de un logro específico
  int getAchievementProgress(String achievementId) {
    return achievementProgress[achievementId] ?? 0;
  }

  /// Obtiene el progreso como porcentaje para un logro
  double getProgressPercentage(Achievement achievement) {
    if (achievement.targetValue == 0) return 0.0;
    final currentProgress = getAchievementProgress(achievement.id);
    return (currentProgress / achievement.targetValue).clamp(0.0, 1.0);
  }

  /// Obtiene la racha actual para una categoría específica
  int getStreak(String category) {
    return streaks[category] ?? 0;
  }

  /// Lista de logros desbloqueados recientemente (últimos 30 días)
  List<String> getRecentUnlocks() {
    if (lastUpdated == null) return [];

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    if (lastUpdated!.isAfter(thirtyDaysAgo)) {
      return unlockedAchievements;
    }
    return [];
  }

  @override
  String toString() {
    return 'UserAchievements(userId: $userId, totalPoints: $totalPoints, '
        'unlockedCount: ${unlockedAchievements.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserAchievements &&
        other.userId == userId &&
        other.totalPoints == totalPoints;
  }

  @override
  int get hashCode {
    return userId.hashCode ^ totalPoints.hashCode;
  }
}
