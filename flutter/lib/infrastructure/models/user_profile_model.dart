import '../../core/logging/logger_factory.dart';
import '../../domain/entities/user_profile.dart';

DateTime _parseDate(dynamic value, String fieldName, String userId) {
  if (value is DateTime) {
    return value;
  }

  if (value is String && value.isNotEmpty) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }

  LoggerFactory.warning(
    'UserProfileModel: invalid "$fieldName" for user $userId, using DateTime.now()',
  );
  return DateTime.now();
}

String? _normalizeUsername(String? value) {
  if (value == null) {
    return null;
  }

  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  return trimmed.toLowerCase();
}

class UserProfileModel extends UserProfile {
  const UserProfileModel({
    required super.id,
    required super.userId,
    required super.fullName,
    super.username,
    super.bio,
    super.avatarUrl,
    super.avatarHash,
    super.stats,
    super.preferences,
    required super.createdAt,
    required super.updatedAt,
    super.lastSyncedAt,
  });

  factory UserProfileModel.create({
    required String userId,
    required String fullName,
    String? bio,
    String? avatarUrl,
    String? username,
    Map<String, dynamic>? stats,
    Map<String, bool>? preferences,
  }) {
    final now = DateTime.now();
    return UserProfileModel(
      id: '', // Se generará en la base de datos
      userId: userId,
      fullName: fullName,
      username: _normalizeUsername(username),
      bio: bio,
      avatarUrl: avatarUrl,
      stats: stats,
      preferences: preferences,
      createdAt: now,
      updatedAt: now,
      lastSyncedAt: now,
    );
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final dynamicId = json['id'];
    final userId = (json['user_id'] ?? '').toString();

    if (userId.isEmpty) {
      LoggerFactory.error(
        'UserProfileModel: received profile without user_id. Raw payload: $json',
      );
    }

    final rawFullName = json['display_name'] ?? json['full_name'];
    final fullName = rawFullName == null
        ? 'Usuario'
        : rawFullName.toString().trim().isEmpty
            ? 'Usuario'
            : rawFullName.toString().trim();

    if (rawFullName == null || rawFullName.toString().trim().isEmpty) {
      LoggerFactory.warning(
        'UserProfileModel: missing full/display name for user $userId, applying fallback.',
      );
    }

    return UserProfileModel(
      id: dynamicId == null ? '' : dynamicId.toString(),
      userId: userId,
      fullName: fullName,
      username: _normalizeUsername(json['username']?.toString()),
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      avatarHash: json['avatar_hash'] as String?,
      stats: _parseMap(json['stats']),
      preferences: _parseBoolMap(json['preferences']),
      createdAt: _parseDate(
        json['joined_date'] ?? json['created_at'],
        'joined_date',
        userId,
      ),
      updatedAt: _parseDate(
        json['updated_at'] ??
            json['last_active_date'] ??
            json['joined_date'] ??
            json['created_at'],
        'updated_at',
        userId,
      ),
      lastSyncedAt: json['last_synced_at'] != null
          ? _parseDate(json['last_synced_at'], 'last_synced_at', userId)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'display_name': fullName,
      'username': username,
      'bio': bio,
      'avatar_url': avatarUrl,
      'avatar_hash': avatarHash,
      'stats': stats,
      'preferences': preferences,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_synced_at': lastSyncedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'display_name': fullName,
      if (username != null) 'username': username,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (avatarHash != null) 'avatar_hash': avatarHash,
      if (stats.isNotEmpty) 'stats': stats,
      if (preferences.isNotEmpty) 'preferences': preferences,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'display_name': fullName,
      'username': username,
      'bio': bio,
      'avatar_url': avatarUrl,
      'avatar_hash': avatarHash,
      'stats': stats,
      'preferences': preferences,
      'updated_at': DateTime.now().toIso8601String(),
      'last_synced_at': DateTime.now().toIso8601String(),
    };
  }

  UserProfileModel copyWithModel({
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
    return UserProfileModel(
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

  static Map<String, dynamic> _parseMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return const {};
  }

  static Map<String, bool> _parseBoolMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value.map(
        (key, val) => MapEntry(key, val is bool ? val : val == true),
      );
    }
    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), val is bool ? val : val == true),
      );
    }
    return const {};
  }
}
