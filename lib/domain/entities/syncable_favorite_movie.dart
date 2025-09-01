import '../../core/sync/conflict_resolution/soft_delete_manager.dart';
import 'movie.dart';

/// Entidad específica para favoritos que implementa SoftDeletable
/// para ser usada con el sistema de resolución de conflictos
class SyncableFavoriteMovie implements SoftDeletable {
  const SyncableFavoriteMovie({
    required this.id,
    required this.userId,
    required this.movieId,
    required this.movieTitle,
    this.moviePosterPath,
    this.movieBackdropPath,
    this.movieOverview,
    this.movieReleaseDate,
    this.movieVoteAverage,
    required this.addedAt,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  /// Crea desde Map (deserialización)
  factory SyncableFavoriteMovie.fromJson(Map<String, dynamic> json) {
    return SyncableFavoriteMovie(
      id: json['id'] as String,
      userId: json['userId'] as String,
      movieId: json['movieId'] as int,
      movieTitle: json['movieTitle'] as String,
      moviePosterPath: json['moviePosterPath'] as String?,
      movieBackdropPath: json['movieBackdropPath'] as String?,
      movieOverview: json['movieOverview'] as String?,
      movieReleaseDate: json['movieReleaseDate'] != null
          ? DateTime.parse(json['movieReleaseDate'] as String)
          : null,
      movieVoteAverage: json['movieVoteAverage']?.toDouble(),
      addedAt: DateTime.parse(json['addedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }

  /// Crea desde Movie
  factory SyncableFavoriteMovie.fromMovie({
    required String userId,
    required Movie movie,
    String? customId,
    DateTime? addedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    return SyncableFavoriteMovie(
      id: customId ?? '${userId}_${movie.id}',
      userId: userId,
      movieId: movie.id,
      movieTitle: movie.title,
      moviePosterPath: movie.posterPath,
      movieBackdropPath: movie.backdropPath,
      movieOverview: movie.overview,
      movieReleaseDate: movie.releaseDate,
      movieVoteAverage: movie.voteAverage,
      addedAt: addedAt ?? now,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      isDeleted: false,
    );
  }
  @override
  final String id;

  final String userId;
  final int movieId;
  final String movieTitle;
  final String? moviePosterPath;
  final String? movieBackdropPath;
  final String? movieOverview;
  final DateTime? movieReleaseDate;
  final double? movieVoteAverage;
  final DateTime addedAt;

  @override
  final DateTime createdAt;

  @override
  final DateTime updatedAt;

  @override
  final bool isDeleted;

  /// Implementa SoftDeletable - crea copia marcada como eliminada
  @override
  SoftDeletable copyWithDeleted(bool isDeleted, DateTime updatedAt) {
    return copyWith(
      isDeleted: isDeleted,
      updatedAt: updatedAt,
    );
  }

  /// Crea una copia con campos modificados
  SyncableFavoriteMovie copyWith({
    String? id,
    String? userId,
    int? movieId,
    String? movieTitle,
    String? moviePosterPath,
    String? movieBackdropPath,
    String? movieOverview,
    DateTime? movieReleaseDate,
    double? movieVoteAverage,
    DateTime? addedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return SyncableFavoriteMovie(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      moviePosterPath: moviePosterPath ?? this.moviePosterPath,
      movieBackdropPath: movieBackdropPath ?? this.movieBackdropPath,
      movieOverview: movieOverview ?? this.movieOverview,
      movieReleaseDate: movieReleaseDate ?? this.movieReleaseDate,
      movieVoteAverage: movieVoteAverage ?? this.movieVoteAverage,
      addedAt: addedAt ?? this.addedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// Convierte a Map para serialización
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'movieId': movieId,
      'movieTitle': movieTitle,
      'moviePosterPath': moviePosterPath,
      'movieBackdropPath': movieBackdropPath,
      'movieOverview': movieOverview,
      'movieReleaseDate': movieReleaseDate?.toIso8601String(),
      'movieVoteAverage': movieVoteAverage,
      'addedAt': addedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isDeleted': isDeleted,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncableFavoriteMovie &&
        other.id == id &&
        other.userId == userId &&
        other.movieId == movieId &&
        other.movieTitle == movieTitle &&
        other.moviePosterPath == moviePosterPath &&
        other.movieBackdropPath == movieBackdropPath &&
        other.movieOverview == movieOverview &&
        other.movieReleaseDate == movieReleaseDate &&
        other.movieVoteAverage == movieVoteAverage &&
        other.addedAt == addedAt &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.isDeleted == isDeleted;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      movieId,
      movieTitle,
      moviePosterPath,
      movieBackdropPath,
      movieOverview,
      movieReleaseDate,
      movieVoteAverage,
      addedAt,
      createdAt,
      updatedAt,
      isDeleted,
    );
  }

  @override
  String toString() {
    return 'SyncableFavoriteMovie(id: $id, userId: $userId, movieId: $movieId, '
        'movieTitle: $movieTitle, isDeleted: $isDeleted, '
        'createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
