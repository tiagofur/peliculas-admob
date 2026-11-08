import 'badge_type.dart';

class Badge {
  const Badge({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.iconPath,
    this.unlockedAt,
    this.isUnlocked = false,
  });
  final String id;
  final String title;
  final String description;
  final BadgeType type;
  final String iconPath;
  final DateTime? unlockedAt;
  final bool isUnlocked;

  Badge copyWith({
    String? id,
    String? title,
    String? description,
    BadgeType? type,
    String? iconPath,
    DateTime? unlockedAt,
    bool? isUnlocked,
  }) {
    return Badge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      iconPath: iconPath ?? this.iconPath,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Badge && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Badge(id: $id, title: $title, type: $type, isUnlocked: $isUnlocked)';
  }
}
