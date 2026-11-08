import 'package:hive/hive.dart';

part 'achievement_progress.g.dart';

/// Representa el progreso detallado de un logro específico
@HiveType(typeId: 54)
class AchievementProgress {
  AchievementProgress({
    required this.achievementId,
    required this.userId,
    this.currentValue = 0,
    this.isUnlocked = false,
    this.unlockedDate,
    this.progressHistory = const [],
    this.lastUpdated,
    this.metadata = const {},
  });

  @HiveField(0)
  final String achievementId;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final int currentValue;

  @HiveField(3)
  final bool isUnlocked;

  @HiveField(4)
  final DateTime? unlockedDate;

  @HiveField(5)
  final List<ProgressEntry> progressHistory;

  @HiveField(6)
  final DateTime? lastUpdated;

  @HiveField(7)
  final Map<String, dynamic> metadata;

  AchievementProgress copyWith({
    String? achievementId,
    String? userId,
    int? currentValue,
    bool? isUnlocked,
    DateTime? unlockedDate,
    List<ProgressEntry>? progressHistory,
    DateTime? lastUpdated,
    Map<String, dynamic>? metadata,
  }) {
    return AchievementProgress(
      achievementId: achievementId ?? this.achievementId,
      userId: userId ?? this.userId,
      currentValue: currentValue ?? this.currentValue,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedDate: unlockedDate ?? this.unlockedDate,
      progressHistory: progressHistory ?? this.progressHistory,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Calcula el progreso como porcentaje basado en el valor objetivo
  double getProgressPercentage(int targetValue) {
    if (targetValue == 0) return 0.0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }

  /// Verifica si el logro está completado pero aún no desbloqueado
  bool isReadyToUnlock(int targetValue) {
    return !isUnlocked && currentValue >= targetValue;
  }

  /// Obtiene el progreso realizado en los últimos N días
  int getRecentProgress(int days) {
    if (progressHistory.isEmpty) return 0;

    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return progressHistory
        .where((entry) => entry.timestamp.isAfter(cutoffDate))
        .fold(0, (sum, entry) => sum + entry.progressAmount);
  }

  /// Obtiene la velocidad de progreso (progreso por día)
  double getProgressVelocity() {
    if (progressHistory.length < 2) return 0.0;

    final now = DateTime.now();
    final firstEntry = progressHistory.first;
    final daysDiff = now.difference(firstEntry.timestamp).inDays;

    if (daysDiff == 0) return 0.0;

    return currentValue / daysDiff;
  }

  @override
  String toString() {
    return 'AchievementProgress(id: $achievementId, user: $userId, '
        'progress: $currentValue, unlocked: $isUnlocked)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AchievementProgress &&
        other.achievementId == achievementId &&
        other.userId == userId &&
        other.currentValue == currentValue;
  }

  @override
  int get hashCode {
    return achievementId.hashCode ^ userId.hashCode ^ currentValue.hashCode;
  }
}

/// Representa una entrada individual de progreso en el historial
@HiveType(typeId: 55)
class ProgressEntry {
  ProgressEntry({
    required this.timestamp,
    required this.progressAmount,
    this.triggerEvent,
    this.metadata = const {},
  });

  @HiveField(0)
  final DateTime timestamp;

  @HiveField(1)
  final int progressAmount;

  @HiveField(2)
  final String? triggerEvent; // Qué acción causó este progreso

  @HiveField(3)
  final Map<String, dynamic> metadata;

  ProgressEntry copyWith({
    DateTime? timestamp,
    int? progressAmount,
    String? triggerEvent,
    Map<String, dynamic>? metadata,
  }) {
    return ProgressEntry(
      timestamp: timestamp ?? this.timestamp,
      progressAmount: progressAmount ?? this.progressAmount,
      triggerEvent: triggerEvent ?? this.triggerEvent,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'ProgressEntry(time: $timestamp, amount: $progressAmount, '
        'event: $triggerEvent)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProgressEntry &&
        other.timestamp == timestamp &&
        other.progressAmount == progressAmount &&
        other.triggerEvent == triggerEvent;
  }

  @override
  int get hashCode {
    return timestamp.hashCode ^ progressAmount.hashCode ^ triggerEvent.hashCode;
  }
}
