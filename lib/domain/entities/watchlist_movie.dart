import 'package:hive/hive.dart';

part 'watchlist_movie.g.dart';

/// Enum para las prioridades de la watchlist
@HiveType(typeId: 100)
enum WatchlistPriority {
  @HiveField(0)
  alta,
  @HiveField(1)
  normal,
  @HiveField(2)
  baja;

  String get displayName {
    switch (this) {
      case WatchlistPriority.alta:
        return 'Alta';
      case WatchlistPriority.normal:
        return 'Normal';
      case WatchlistPriority.baja:
        return 'Baja';
    }
  }

  String get value {
    switch (this) {
      case WatchlistPriority.alta:
        return 'alta';
      case WatchlistPriority.normal:
        return 'normal';
      case WatchlistPriority.baja:
        return 'baja';
    }
  }

  static WatchlistPriority fromString(String value) {
    switch (value.toLowerCase()) {
      case 'alta':
        return WatchlistPriority.alta;
      case 'normal':
        return WatchlistPriority.normal;
      case 'baja':
        return WatchlistPriority.baja;
      default:
        return WatchlistPriority.normal;
    }
  }

  static WatchlistPriority fromValue(String value) {
    return fromString(value);
  }
}

/// Entidad que representa una película en la watchlist del usuario
@HiveType(typeId: 101)
class WatchlistMovie {
  const WatchlistMovie({
    required this.id,
    required this.movieId,
    required this.movieTitle,
    this.moviePosterPath,
    this.movieBackdropPath,
    this.movieOverview,
    this.movieReleaseDate,
    this.movieVoteAverage,
    required this.priority,
    required this.addedAt,
    required this.lastModifiedAt,
    this.isDeleted = false,
    this.syncStatus = 'synced',
  });
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int movieId;

  @HiveField(2)
  final String movieTitle;

  @HiveField(3)
  final String? moviePosterPath;

  @HiveField(4)
  final String? movieBackdropPath;

  @HiveField(5)
  final String? movieOverview;

  @HiveField(6)
  final DateTime? movieReleaseDate;

  @HiveField(7)
  final double? movieVoteAverage;

  @HiveField(8)
  final WatchlistPriority priority;

  @HiveField(9)
  final DateTime addedAt;

  @HiveField(10)
  final DateTime lastModifiedAt;

  @HiveField(11)
  final bool isDeleted;

  @HiveField(12)
  final String syncStatus;

  WatchlistMovie copyWith({
    String? id,
    int? movieId,
    String? movieTitle,
    String? moviePosterPath,
    String? movieBackdropPath,
    String? movieOverview,
    DateTime? movieReleaseDate,
    double? movieVoteAverage,
    WatchlistPriority? priority,
    DateTime? addedAt,
    DateTime? lastModifiedAt,
    bool? isDeleted,
    String? syncStatus,
  }) {
    return WatchlistMovie(
      id: id ?? this.id,
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      moviePosterPath: moviePosterPath ?? this.moviePosterPath,
      movieBackdropPath: movieBackdropPath ?? this.movieBackdropPath,
      movieOverview: movieOverview ?? this.movieOverview,
      movieReleaseDate: movieReleaseDate ?? this.movieReleaseDate,
      movieVoteAverage: movieVoteAverage ?? this.movieVoteAverage,
      priority: priority ?? this.priority,
      addedAt: addedAt ?? this.addedAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WatchlistMovie &&
        other.id == id &&
        other.movieId == movieId &&
        other.priority == priority &&
        other.isDeleted == isDeleted;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        movieId.hashCode ^
        priority.hashCode ^
        isDeleted.hashCode;
  }

  @override
  String toString() {
    return 'WatchlistMovie(id: $id, movieId: $movieId, title: $movieTitle, priority: $priority)';
  }
}
