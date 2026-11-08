/// Level model for the gamification system
class Level {
  const Level({
    required this.level,
    required this.name,
    required this.description,
    required this.pointsRequired,
    required this.iconPath,
    required this.color,
    this.rewards = const [],
    this.perks = const [],
  });

  factory Level.fromJson(Map<String, dynamic> json) {
    return Level(
      level: json['level'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      pointsRequired: json['pointsRequired'] as int,
      iconPath: json['iconPath'] as String,
      color: json['color'] as String,
      rewards: (json['rewards'] as List<dynamic>? ?? [])
          .map((r) => LevelReward.fromJson(r as Map<String, dynamic>))
          .toList(),
      perks: (json['perks'] as List<dynamic>? ?? [])
          .map((p) => p as String)
          .toList(),
    );
  }

  final int level;
  final String name;
  final String description;
  final int pointsRequired;
  final String iconPath;
  final String color; // Hex color code
  final List<LevelReward> rewards;
  final List<String> perks;

  /// Calculate points needed for this level from previous level
  int get pointsFromPrevious {
    if (level <= 1) return pointsRequired;
    const basePoints = 100;
    const multiplier = 1.5;
    final previousLevelPoints =
        level > 1 ? (basePoints * ((level - 1) * multiplier)).round() : 0;
    return pointsRequired - previousLevelPoints;
  }

  Level copyWith({
    int? level,
    String? name,
    String? description,
    int? pointsRequired,
    String? iconPath,
    String? color,
    List<LevelReward>? rewards,
    List<String>? perks,
  }) {
    return Level(
      level: level ?? this.level,
      name: name ?? this.name,
      description: description ?? this.description,
      pointsRequired: pointsRequired ?? this.pointsRequired,
      iconPath: iconPath ?? this.iconPath,
      color: color ?? this.color,
      rewards: rewards ?? this.rewards,
      perks: perks ?? this.perks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'name': name,
      'description': description,
      'pointsRequired': pointsRequired,
      'iconPath': iconPath,
      'color': color,
      'rewards': rewards.map((r) => r.toJson()).toList(),
      'perks': perks,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Level && other.level == level;
  }

  @override
  int get hashCode => level.hashCode;

  @override
  String toString() {
    return 'Level(level: $level, name: $name, pointsRequired: $pointsRequired)';
  }

  /// Predefined levels for the gamification system
  static List<Level> get defaultLevels => [
        const Level(
          level: 1,
          name: 'Movie Newbie',
          description: 'Welcome to your movie journey!',
          pointsRequired: 0,
          iconPath: 'assets/icons/levels/newbie.png',
          color: '#8E8E93',
          perks: ['Basic movie recommendations'],
        ),
        const Level(
          level: 2,
          name: 'Film Explorer',
          description: 'You\'re starting to explore the world of cinema',
          pointsRequired: 150,
          iconPath: 'assets/icons/levels/explorer.png',
          color: '#34C759',
          perks: ['Enhanced recommendations', 'Basic statistics'],
        ),
        const Level(
          level: 3,
          name: 'Cinema Enthusiast',
          description: 'Your passion for movies is growing',
          pointsRequired: 400,
          iconPath: 'assets/icons/levels/enthusiast.png',
          color: '#007AFF',
          perks: ['Advanced filters', 'Watchlist sharing'],
        ),
        const Level(
          level: 4,
          name: 'Movie Buff',
          description: 'You know your way around different genres',
          pointsRequired: 800,
          iconPath: 'assets/icons/levels/buff.png',
          color: '#FF9500',
          perks: ['Genre insights', 'Advanced statistics', 'Priority support'],
        ),
        const Level(
          level: 5,
          name: 'Film Critic',
          description: 'Your reviews and opinions matter',
          pointsRequired: 1500,
          iconPath: 'assets/icons/levels/critic.png',
          color: '#FF3B30',
          perks: ['Review highlights', 'Critic badge', 'Early access features'],
        ),
        const Level(
          level: 6,
          name: 'Cinema Master',
          description: 'You\'ve mastered the art of movie appreciation',
          pointsRequired: 2500,
          iconPath: 'assets/icons/levels/master.png',
          color: '#AF52DE',
          perks: ['Master badge', 'Exclusive content', 'Beta features'],
        ),
        const Level(
          level: 7,
          name: 'Movie Legend',
          description: 'Your movie knowledge is legendary',
          pointsRequired: 4000,
          iconPath: 'assets/icons/levels/legend.png',
          color: '#FFD60A',
          perks: [
            'Legend status',
            'All premium features',
            'Community recognition'
          ],
        ),
      ];
}

/// Reward given when reaching a level
class LevelReward {
  const LevelReward({
    required this.type,
    required this.name,
    required this.description,
    this.value,
  });

  factory LevelReward.fromJson(Map<String, dynamic> json) {
    return LevelReward(
      type: LevelRewardType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LevelRewardType.badge,
      ),
      name: json['name'] as String,
      description: json['description'] as String,
      value: json['value'],
    );
  }

  final LevelRewardType type;
  final String name;
  final String description;
  final dynamic value;

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'name': name,
      'description': description,
      'value': value,
    };
  }

  @override
  String toString() {
    return 'LevelReward(type: $type, name: $name)';
  }
}

/// Types of level rewards
enum LevelRewardType {
  badge,
  points,
  feature,
  cosmetic,
  privilege,
}
