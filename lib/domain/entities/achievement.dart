import 'package:hive/hive.dart';

@HiveType(typeId: 2)
class Achievement {
  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.targetValue,
    this.currentValue = 0,
    this.isUnlocked = false,
    this.unlockedDate,
    required this.category,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String iconName;

  @HiveField(4)
  final int targetValue;

  @HiveField(5)
  final int currentValue;

  @HiveField(6)
  final bool isUnlocked;

  @HiveField(7)
  final DateTime? unlockedDate;

  @HiveField(8)
  final AchievementCategory category;

  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    String? iconName,
    int? targetValue,
    int? currentValue,
    bool? isUnlocked,
    DateTime? unlockedDate,
    AchievementCategory? category,
  }) {
    return Achievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedDate: unlockedDate ?? this.unlockedDate,
      category: category ?? this.category,
    );
  }

  double get progress => currentValue / targetValue;

  bool get isCompleted => currentValue >= targetValue;
}

@HiveType(typeId: 3)
enum AchievementCategory {
  @HiveField(0)
  movies,

  @HiveField(1)
  favorites,

  @HiveField(2)
  exploration,

  @HiveField(3)
  social,
}
