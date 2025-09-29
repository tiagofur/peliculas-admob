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

class UserProfileModel extends UserProfile {
  const UserProfileModel({
    required super.id,
    required super.userId,
    required super.fullName,
    super.bio,
    super.avatarUrl,
    required super.createdAt,
    required super.updatedAt,
  });

  factory UserProfileModel.create({
    required String userId,
    required String fullName,
    String? bio,
    String? avatarUrl,
  }) {
    final now = DateTime.now();
    return UserProfileModel(
      id: '', // Se generará en la base de datos
      userId: userId,
      fullName: fullName,
      bio: bio,
      avatarUrl: avatarUrl,
      createdAt: now,
      updatedAt: now,
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

    final rawFullName = json['full_name'];
    final fullName = rawFullName == null
        ? 'Usuario'
        : rawFullName.toString().trim().isEmpty
            ? 'Usuario'
            : rawFullName.toString().trim();

    if (rawFullName == null || rawFullName.toString().trim().isEmpty) {
      LoggerFactory.warning(
        'UserProfileModel: missing full_name for user $userId, applying fallback.',
      );
    }

    return UserProfileModel(
      id: dynamicId == null ? '' : dynamicId.toString(),
      userId: userId,
      fullName: fullName,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: _parseDate(json['created_at'], 'created_at', userId),
      updatedAt: _parseDate(json['updated_at'], 'updated_at', userId),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'bio': bio,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'full_name': fullName,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'full_name': fullName,
      'bio': bio,
      'avatar_url': avatarUrl,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  UserProfileModel copyWithModel({
    String? id,
    String? userId,
    String? fullName,
    String? bio,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
