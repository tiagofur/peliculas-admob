/// Achievement model for the gamification system
class Achievement {
  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.iconPath,
    required this.points,
    required this.category,
    required this.rarity,
    this.isUnlocked = false,
    this.unlockedAt,
    this.progress = 0,
    this.maxProgress = 1,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      iconPath: json['iconPath'] as String,
      points: json['points'] as int,
      category: AchievementCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => AchievementCategory.general,
      ),
      rarity: AchievementRarity.values.firstWhere(
        (e) => e.name == json['rarity'],
        orElse: () => AchievementRarity.common,
      ),
      isUnlocked: json['isUnlocked'] as bool? ?? false,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt'] as String)
          : null,
      progress: json['progress'] as int? ?? 0,
      maxProgress: json['maxProgress'] as int? ?? 1,
    );
  }

  final String id;
  final String name;
  final String description;
  final String iconPath;
  final int points;
  final AchievementCategory category;
  final AchievementRarity rarity;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final int progress;
  final int maxProgress;

  /// Progress percentage (0.0 to 1.0)
  double get progressPercentage =>
      maxProgress > 0 ? progress / maxProgress : 0.0;

  /// Whether the achievement is completed
  bool get isCompleted => progress >= maxProgress;

  Achievement copyWith({
    String? id,
    String? name,
    String? description,
    String? iconPath,
    int? points,
    AchievementCategory? category,
    AchievementRarity? rarity,
    bool? isUnlocked,
    DateTime? unlockedAt,
    int? progress,
    int? maxProgress,
  }) {
    return Achievement(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconPath: iconPath ?? this.iconPath,
      points: points ?? this.points,
      category: category ?? this.category,
      rarity: rarity ?? this.rarity,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progress: progress ?? this.progress,
      maxProgress: maxProgress ?? this.maxProgress,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconPath': iconPath,
      'points': points,
      'category': category.name,
      'rarity': rarity.name,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt?.toIso8601String(),
      'progress': progress,
      'maxProgress': maxProgress,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Achievement && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Achievement(id: $id, name: $name, isUnlocked: $isUnlocked, progress: $progress/$maxProgress)';
  }
}

/// Categories of achievements
enum AchievementCategory {
  general,
  movies,
  social,
  discovery,
  collection,
  engagement,
}

/// Rarity levels for achievements
enum AchievementRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
}
