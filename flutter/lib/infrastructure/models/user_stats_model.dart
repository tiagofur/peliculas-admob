import '../../core/logging/logger_factory.dart';
import '../../domain/entities/user_stats.dart';

DateTime _parseStatsDate(dynamic value, String fieldName, String userId) {
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
    'UserStatsModel: invalid "$fieldName" for user $userId, using DateTime.now()',
  );
  return DateTime.now();
}

class UserStatsModel extends UserStats {
  const UserStatsModel({
    required super.id,
    required super.userId,
    required super.moviesWatched,
    required super.favoritesCount,
    required super.listsCount,
    required super.lastActivity,
    required super.createdAt,
    required super.updatedAt,
  });

  factory UserStatsModel.create({
    required String userId,
    int moviesWatched = 0,
    int favoritesCount = 0,
    int listsCount = 0,
  }) {
    final now = DateTime.now();
    return UserStatsModel(
      id: '', // Se generará en la base de datos
      userId: userId,
      moviesWatched: moviesWatched,
      favoritesCount: favoritesCount,
      listsCount: listsCount,
      lastActivity: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory UserStatsModel.fromJson(Map<String, dynamic> json) {
    final dynamicId = json['id'];
    final userId = (json['user_id'] ?? '').toString();

    if (userId.isEmpty) {
      LoggerFactory.error(
        'UserStatsModel: received stats without user_id. Raw payload: $json',
      );
    }

    return UserStatsModel(
      id: dynamicId == null ? '' : dynamicId.toString(),
      userId: userId,
      moviesWatched: json['movies_watched'] as int? ?? 0,
      favoritesCount: json['favorites_count'] as int? ?? 0,
      listsCount: json['lists_count'] as int? ?? 0,
      lastActivity:
          _parseStatsDate(json['last_activity'], 'last_activity', userId),
      createdAt: _parseStatsDate(json['created_at'], 'created_at', userId),
      updatedAt: _parseStatsDate(json['updated_at'], 'updated_at', userId),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'movies_watched': moviesWatched,
      'favorites_count': favoritesCount,
      'lists_count': listsCount,
      'last_activity': lastActivity.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'movies_watched': moviesWatched,
      'favorites_count': favoritesCount,
      'lists_count': listsCount,
      'last_activity': lastActivity.toIso8601String(),
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'movies_watched': moviesWatched,
      'favorites_count': favoritesCount,
      'lists_count': listsCount,
      'last_activity': lastActivity.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  UserStatsModel copyWithModel({
    String? id,
    String? userId,
    int? moviesWatched,
    int? favoritesCount,
    int? listsCount,
    DateTime? lastActivity,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserStatsModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      moviesWatched: moviesWatched ?? this.moviesWatched,
      favoritesCount: favoritesCount ?? this.favoritesCount,
      listsCount: listsCount ?? this.listsCount,
      lastActivity: lastActivity ?? this.lastActivity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Métodos de conveniencia que devuelven UserStatsModel
  @override
  UserStatsModel incrementMoviesWatched() {
    return copyWithModel(
      moviesWatched: moviesWatched + 1,
      lastActivity: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  UserStatsModel incrementFavorites() {
    return copyWithModel(
      favoritesCount: favoritesCount + 1,
      lastActivity: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  UserStatsModel decrementFavorites() {
    return copyWithModel(
      favoritesCount: favoritesCount > 0 ? favoritesCount - 1 : 0,
      lastActivity: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  UserStatsModel incrementLists() {
    return copyWithModel(
      listsCount: listsCount + 1,
      lastActivity: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  UserStatsModel decrementLists() {
    return copyWithModel(
      listsCount: listsCount > 0 ? listsCount - 1 : 0,
      lastActivity: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  UserStatsModel updateActivity() {
    return copyWithModel(
      lastActivity: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
