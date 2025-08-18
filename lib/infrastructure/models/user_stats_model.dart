import '../../domain/entities/user_stats.dart';

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

  factory UserStatsModel.fromJson(Map<String, dynamic> json) {
    return UserStatsModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      moviesWatched: json['movies_watched'] as int? ?? 0,
      favoritesCount: json['favorites_count'] as int? ?? 0,
      listsCount: json['lists_count'] as int? ?? 0,
      lastActivity: DateTime.parse(json['last_activity'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
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