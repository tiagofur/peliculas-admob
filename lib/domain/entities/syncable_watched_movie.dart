import '../../core/sync/conflict_resolution/soft_delete_manager.dart';
import '../repositories/syncable_repository.dart';
import 'movie.dart';

/// Entidad sincronizable para películas vistas que implementa SoftDeletable y Syncable
class SyncableWatchedMovie implements SoftDeletable, Syncable {
  const SyncableWatchedMovie({
    required this.id,
    required this.userId,
    required this.movieId,
    required this.movieTitle,
    this.moviePosterPath,
    this.movieBackdropPath,
    this.movieOverview,
    this.movieReleaseDate,
    this.movieVoteAverage,
    required this.watchedAt,
    required this.createdAt,
    required this.updatedAt,
    this.rating,
    this.review,
    this.isDeleted = false,
    this.deletedAt,
    this.traktId,
    this.syncStatus = SyncStatus.synced,
  });

  /// Crea desde WatchedMovie
  factory SyncableWatchedMovie.fromWatchedMovie(dynamic watchedMovie, String userId) {
    final now = DateTime.now();
    return SyncableWatchedMovie(
      id: '${userId}_${watchedMovie.movie.id}_watched',
      userId: userId,
      movieId: watchedMovie.movie.id,
      movieTitle: watchedMovie.movie.title,
      moviePosterPath: watchedMovie.movie.posterPath,
      movieBackdropPath: watchedMovie.movie.backdropPath,
      movieOverview: watchedMovie.movie.overview,
      movieReleaseDate: watchedMovie.movie.releaseDate,
      movieVoteAverage: watchedMovie.movie.voteAverage,
      watchedAt: watchedMovie.watchedDate ?? now,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Crea desde JSON
  factory SyncableWatchedMovie.fromJson(Map<String, dynamic> json) {
    return SyncableWatchedMovie(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      movieId: json['movie_id'] as int,
      movieTitle: json['movie_title'] as String,
      moviePosterPath: json['movie_poster_path'] as String?,
      movieBackdropPath: json['movie_backdrop_path'] as String?,
      movieOverview: json['movie_overview'] as String?,
      movieReleaseDate: json['movie_release_date'] != null
          ? DateTime.parse(json['movie_release_date'] as String)
          : null,
      movieVoteAverage: json['movie_vote_average'] as double?,
      watchedAt: DateTime.parse(json['watched_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      rating: json['rating'] as double?,
      review: json['review'] as String?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      traktId: json['trakt_id'] as int?,
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
  final DateTime watchedAt;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final double? rating;
  final String? review;
  @override
  final bool isDeleted;
  final DateTime? deletedAt;
  final int? traktId;
  @override
  final SyncStatus syncStatus;

  /// Implementa SoftDeletable - crea copia marcada como eliminada
  @override
  SoftDeletable copyWithDeleted(bool isDeleted, DateTime updatedAt) {
    return copyWith(
      isDeleted: isDeleted,
      deletedAt: isDeleted ? updatedAt : null,
      updatedAt: updatedAt,
    );
  }

  /// Crea una copia con los campos especificados modificados
  SyncableWatchedMovie copyWith({
    String? id,
    String? userId,
    int? movieId,
    String? movieTitle,
    String? moviePosterPath,
    String? movieBackdropPath,
    String? movieOverview,
    DateTime? movieReleaseDate,
    double? movieVoteAverage,
    DateTime? watchedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? rating,
    String? review,
    bool? isDeleted,
    DateTime? deletedAt,
    int? traktId,
    SyncStatus? syncStatus,
  }) {
    return SyncableWatchedMovie(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      moviePosterPath: moviePosterPath ?? this.moviePosterPath,
      movieBackdropPath: movieBackdropPath ?? this.movieBackdropPath,
      movieOverview: movieOverview ?? this.movieOverview,
      movieReleaseDate: movieReleaseDate ?? this.movieReleaseDate,
      movieVoteAverage: movieVoteAverage ?? this.movieVoteAverage,
      watchedAt: watchedAt ?? this.watchedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      traktId: traktId ?? this.traktId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  /// Convierte a JSON para serialización
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'movie_id': movieId,
      'movie_title': movieTitle,
      'movie_poster_path': moviePosterPath,
      'movie_backdrop_path': movieBackdropPath,
      'movie_overview': movieOverview,
      'movie_release_date': movieReleaseDate?.toIso8601String(),
      'movie_vote_average': movieVoteAverage,
      'watched_at': watchedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'rating': rating,
      'review': review,
      'is_deleted': isDeleted,
      'deleted_at': deletedAt?.toIso8601String(),
      'trakt_id': traktId,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncableWatchedMovie &&
        other.id == id &&
        other.userId == userId &&
        other.movieId == movieId &&
        other.movieTitle == movieTitle &&
        other.moviePosterPath == moviePosterPath &&
        other.movieBackdropPath == movieBackdropPath &&
        other.movieOverview == movieOverview &&
        other.movieReleaseDate == movieReleaseDate &&
        other.movieVoteAverage == movieVoteAverage &&
        other.watchedAt == watchedAt &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.rating == rating &&
        other.review == review &&
        other.isDeleted == isDeleted &&
        other.deletedAt == deletedAt &&
        other.traktId == traktId;
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
      watchedAt,
      createdAt,
      updatedAt,
      rating,
      review,
      isDeleted,
      deletedAt,
      traktId,
    );
  }

  /// Convierte a Movie
  Movie toMovie() {
    return Movie(
      id: movieId,
      title: movieTitle,
      posterPath: moviePosterPath ?? '',
      backdropPath: movieBackdropPath ?? '',
      overview: movieOverview ?? '',
      releaseDate: movieReleaseDate ?? DateTime.now(),
      voteAverage: movieVoteAverage ?? 0.0,
      genreIds: [],
      adult: false,
      originalLanguage: 'en',
      originalTitle: movieTitle,
      popularity: 0.0,
      video: false,
      voteCount: 0,
    );
  }

  @override
  String toString() {
    return 'SyncableWatchedMovie('
        'id: $id, '
        'userId: $userId, '
        'movieId: $movieId, '
        'movieTitle: $movieTitle, '
        'watchedAt: $watchedAt, '
        'rating: $rating, '
        'isDeleted: $isDeleted'
        ')';
  }
}