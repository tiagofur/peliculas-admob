class UserProfile {
  const UserProfile({
    required this.id,
    required this.userId,
    required this.fullName,
    this.bio,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String userId;
  final String fullName;
  final String? bio;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? bio,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get hasBio => bio != null && bio!.isNotEmpty;
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.id == id &&
        other.userId == userId &&
        other.fullName == fullName &&
        other.bio == bio &&
        other.avatarUrl == avatarUrl &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      fullName,
      bio,
      avatarUrl,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserProfile(id: $id, userId: $userId, fullName: $fullName, bio: $bio, avatarUrl: $avatarUrl, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
