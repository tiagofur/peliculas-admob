class UserProfile {
  const UserProfile({
    required this.id,
    required this.userId,
    required this.fullName,
    this.username,
    this.bio,
    this.avatarUrl,
    this.avatarHash,
    Map<String, dynamic>? stats,
    Map<String, bool>? preferences,
    required this.createdAt,
    required this.updatedAt,
    this.lastSyncedAt,
  })  : stats = stats ?? const <String, dynamic>{},
        preferences = preferences ?? const <String, bool>{};
  final String id;
  final String userId;
  final String fullName;
  final String? username;
  final String? bio;
  final String? avatarUrl;
  final String? avatarHash;
  final Map<String, dynamic> stats;
  final Map<String, bool> preferences;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSyncedAt;

  UserProfile copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? username,
    String? bio,
    String? avatarUrl,
    String? avatarHash,
    Map<String, dynamic>? stats,
    Map<String, bool>? preferences,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSyncedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarHash: avatarHash ?? this.avatarHash,
      stats: stats ?? this.stats,
      preferences: preferences ?? this.preferences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  bool get hasBio => bio != null && bio!.isNotEmpty;
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;
  bool get hasUsername => username != null && username!.isNotEmpty;
  String get displayName => hasUsername ? '@$username' : fullName;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.id == id &&
        other.userId == userId &&
        other.fullName == fullName &&
        other.username == username &&
        other.bio == bio &&
        other.avatarUrl == avatarUrl &&
        other.avatarHash == avatarHash &&
        _deepEquals(other.stats, stats) &&
        _deepEquals(other.preferences, preferences) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.lastSyncedAt == lastSyncedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      fullName,
      username,
      bio,
      avatarUrl,
      avatarHash,
      Object.hashAll(stats.entries
          .map((entry) => Object.hash(entry.key, entry.value))
          .toList()),
      Object.hashAll(preferences.entries
          .map((entry) => Object.hash(entry.key, entry.value))
          .toList()),
      createdAt,
      updatedAt,
      lastSyncedAt,
    );
  }

  @override
  String toString() {
    return 'UserProfile(id: $id, userId: $userId, fullName: $fullName, bio: $bio, avatarUrl: $avatarUrl, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  bool _deepEquals(Map<dynamic, dynamic> a, Map<dynamic, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || b[key] != a[key]) {
        return false;
      }
    }
    return true;
  }
}
