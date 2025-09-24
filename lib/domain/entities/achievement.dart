import 'package:hive/hive.dart';

part 'achievement.g.dart';

/// Tipos de logros disponibles en el sistema
@HiveType(typeId: 51)
enum AchievementType {
  @HiveField(0)
  moviesWatched, // Basado en cantidad de películas vistas
  @HiveField(1)
  genreExplorer, // Basado en variedad de géneros
  @HiveField(2)
  yearStreak, // Basado en actividad anual
  @HiveField(3)
  socialInteraction, // Basado en ratings y reviews
  @HiveField(4)
  qualityViewer, // Basado en calidad de películas vistas
  @HiveField(5)
  timeSpent, // Basado en tiempo total de visualización
  @HiveField(6)
  discovery, // Basado en encontrar películas raras/antiguas
}

/// Rareza del logro que afecta rewards y prestigio
@HiveType(typeId: 52)
enum AchievementRarity {
  @HiveField(0)
  common, // 70% de usuarios pueden obtenerlo
  @HiveField(1)
  uncommon, // 40% de usuarios pueden obtenerlo
  @HiveField(2)
  rare, // 15% de usuarios pueden obtenerlo
  @HiveField(3)
  epic, // 5% de usuarios pueden obtenerlo
  @HiveField(4)
  legendary, // 1% de usuarios pueden obtenerlo
}

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
    this.type = AchievementType.moviesWatched,
    this.rarity = AchievementRarity.common,
    this.points = 10,
    this.unlockMessage,
    this.isRepeatable = false,
    this.isHidden = false,
    this.prerequisites = const [],
    this.metadata = const {},
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

  @HiveField(9)
  final AchievementType type;

  @HiveField(10)
  final AchievementRarity rarity;

  @HiveField(11)
  final int points;

  @HiveField(12)
  final String? unlockMessage;

  @HiveField(13)
  final bool isRepeatable;

  @HiveField(14)
  final bool isHidden;

  @HiveField(15)
  final List<String> prerequisites;

  @HiveField(16)
  final Map<String, dynamic> metadata;

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
    AchievementType? type,
    AchievementRarity? rarity,
    int? points,
    String? unlockMessage,
    bool? isRepeatable,
    bool? isHidden,
    List<String>? prerequisites,
    Map<String, dynamic>? metadata,
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
      type: type ?? this.type,
      rarity: rarity ?? this.rarity,
      points: points ?? this.points,
      unlockMessage: unlockMessage ?? this.unlockMessage,
      isRepeatable: isRepeatable ?? this.isRepeatable,
      isHidden: isHidden ?? this.isHidden,
      prerequisites: prerequisites ?? this.prerequisites,
      metadata: metadata ?? this.metadata,
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
