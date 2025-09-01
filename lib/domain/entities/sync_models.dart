import '../repositories/syncable_repository.dart';
import 'custom_list.dart';
import 'movie.dart';
import 'watched_movie.dart';
import '../../core/sync/conflict_resolution/soft_delete_manager.dart';

// Enum para identificar la fuente de datos de la película
enum MovieDataSource {
  tmdb,
  trakt,
}

// Modelo base para elementos sincronizables
abstract class SyncableEntity implements Syncable, Identifiable, Timestamped, SoftDeletable {
  const SyncableEntity({
    required this.id,
    required this.updatedAt,
    required this.createdAt,
    this.deletedAt, // ✅ Soft delete support
    this.syncStatus = SyncStatus.synced,
  });
  @override
  final String id;
  @override
  final DateTime updatedAt;
  @override
  final SyncStatus syncStatus;
  @override
  final DateTime createdAt;
  final DateTime? deletedAt; // ✅ Soft delete timestamp

  // ✅ Helper methods for soft delete
  @override
  bool get isDeleted => deletedAt != null;
  bool get isActive => deletedAt == null;

  // ✅ Implementación de SoftDeletable - debe ser sobrescrita por subclases
  @override
  SoftDeletable copyWithDeleted(bool isDeleted, DateTime updatedAt);
}

// Modelo para favoritos con información de sincronización
class SyncableFavorite extends SyncableEntity {
  const SyncableFavorite({
    required super.id,
    required super.updatedAt,
    required super.createdAt,
    super.deletedAt, // ✅ Pass to parent
    required this.userId,
    required this.movieId,
    required this.movieTitle,
    required this.addedAt,
    this.traktId, // ✅ Trakt ID for hybrid support
    this.moviePosterPath,
    this.movieBackdropPath,
    this.movieOverview,
    this.movieReleaseDate,
    this.movieVoteAverage,
    super.syncStatus = SyncStatus.synced,
  });

  // Crear desde JSON
  factory SyncableFavorite.fromJson(Map<String, dynamic> json) {
    return SyncableFavorite(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      movieId: json['movie_id'] as int,
      movieTitle: json['movie_title'] as String,
      traktId: json['trakt_id'] as int?,
      moviePosterPath: json['movie_poster_path'] as String?,
      movieBackdropPath: json['movie_backdrop_path'] as String?,
      movieOverview: json['movie_overview'] as String?,
      movieReleaseDate: json['movie_release_date'] != null
          ? DateTime.parse(json['movie_release_date'] as String)
          : null,
      movieVoteAverage: json['movie_vote_average'] as double?,
      addedAt: DateTime.parse(json['added_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }

  // Crear desde Movie
  factory SyncableFavorite.fromMovie({
    required String userId,
    required Movie movie,
    String? customId,
    int? traktId, // ✅ Optional Trakt ID
    DateTime? addedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    return SyncableFavorite(
      id: customId ?? '${userId}_${movie.id}',
      userId: userId,
      movieId: movie.id,
      movieTitle: movie.title,
      traktId: traktId, // ✅ Include Trakt ID
      moviePosterPath: movie.posterPath,
      movieBackdropPath: movie.backdropPath,
      movieOverview: movie.overview,
      movieReleaseDate: movie.releaseDate,
      movieVoteAverage: movie.voteAverage,
      addedAt: addedAt ?? now, // Usar timestamp real si está disponible
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
    );
  }
  final String userId;
  final int movieId;
  final String movieTitle;
  final int? traktId; // ✅ Nullable Trakt ID for gradual migration
  final String? moviePosterPath;
  final String? movieBackdropPath;
  final String? movieOverview;
  final DateTime? movieReleaseDate;
  final double? movieVoteAverage;
  final DateTime addedAt;

  // ✅ Getter para determinar la fuente de datos preferida
  MovieDataSource get preferredSource =>
      traktId != null ? MovieDataSource.trakt : MovieDataSource.tmdb;

  SyncableFavorite copyWith({
    String? id,
    String? userId,
    int? movieId,
    String? movieTitle,
    int? traktId, // ✅ Include Trakt ID parameter
    String? moviePosterPath,
    String? movieBackdropPath,
    String? movieOverview,
    DateTime? movieReleaseDate,
    double? movieVoteAverage,
    DateTime? addedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt, // ✅ Incluir deletedAt
    SyncStatus? syncStatus,
  }) {
    return SyncableFavorite(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      traktId: traktId ?? this.traktId, // ✅ Include Trakt ID
      moviePosterPath: moviePosterPath ?? this.moviePosterPath,
      movieBackdropPath: movieBackdropPath ?? this.movieBackdropPath,
      movieOverview: movieOverview ?? this.movieOverview,
      movieReleaseDate: movieReleaseDate ?? this.movieReleaseDate,
      movieVoteAverage: movieVoteAverage ?? this.movieVoteAverage,
      addedAt: addedAt ?? this.addedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt, // ✅ Incluir deletedAt
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  // Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'movie_id': movieId,
      'movie_title': movieTitle,
      'trakt_id': traktId,
      'movie_poster_path': moviePosterPath,
      'movie_backdrop_path': movieBackdropPath,
      'movie_overview': movieOverview,
      'movie_release_date': movieReleaseDate?.toIso8601String(),
      'movie_vote_average': movieVoteAverage,
      'added_at': addedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  // ✅ Implementación de SoftDeletable
  @override
  SoftDeletable copyWithDeleted(bool isDeleted, DateTime updatedAt) {
    return copyWith(
      deletedAt: isDeleted ? updatedAt : null,
      updatedAt: updatedAt,
    );
  }

  // Convertir a modelo de dominio Movie
  Movie toMovie() {
    return Movie(
      id: movieId,
      title: movieTitle,
      posterPath: moviePosterPath ?? '',
      backdropPath: movieBackdropPath ?? '',
      overview: movieOverview ?? '',
      releaseDate: movieReleaseDate ?? DateTime.now(),
      voteAverage: movieVoteAverage ?? 0.0,
      genreIds: [], // Los géneros no se almacenan en favoritos
      adult: false,
      originalLanguage: 'en',
      originalTitle: movieTitle,
      popularity: 0.0,
      video: false,
      voteCount: 0,
    );
  }
}

// Modelo para listas personalizadas con información de sincronización
class SyncableCustomList extends SyncableEntity {
  const SyncableCustomList({
    required super.id,
    required super.updatedAt,
    required super.createdAt,
    super.deletedAt, // ✅ Soft delete support
    required this.userId,
    required this.name,
    required this.description,
    required this.emoji,
    required this.color,
    required this.movieIds,
    this.isPublic = false,
    super.syncStatus = SyncStatus.synced,
  });

  // Crear desde JSON
  factory SyncableCustomList.fromJson(Map<String, dynamic> json) {
    return SyncableCustomList(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      emoji: json['emoji'] as String,
      color: json['color'] as String,
      movieIds: List<int>.from(json['movie_ids'] as List),
      isPublic: json['is_public'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }

  // Crear desde CustomList
  factory SyncableCustomList.fromCustomList(
      CustomList customList, String userId) {
    return SyncableCustomList(
      id: customList.id,
      userId: userId,
      name: customList.name,
      description: customList.description,
      emoji: customList.emoji,
      color: customList.color,
      movieIds: customList.movieIds,
      createdAt: customList.createdAt,
      updatedAt: customList.updatedAt,
    );
  }
  final String userId;
  final String name;
  final String description;
  final String emoji;
  final String color;
  final List<int> movieIds;
  final bool isPublic;

  // Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'emoji': emoji,
      'color': color,
      'movie_ids': movieIds,
      'is_public': isPublic,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  // Convertir a modelo de dominio CustomList
  CustomList toCustomList() {
    return CustomList(
      id: id,
      name: name,
      description: description,
      emoji: emoji,
      color: color,
      movieIds: movieIds,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isDefault: false,
    );
  }

  SyncableCustomList copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    String? emoji,
    String? color,
    List<int>? movieIds,
    bool? isPublic,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt, // ✅ Include deletedAt
    SyncStatus? syncStatus,
  }) {
    return SyncableCustomList(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      movieIds: movieIds ?? this.movieIds,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt, // ✅ Include deletedAt
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  // ✅ Implementación de SoftDeletable
  @override
  SoftDeletable copyWithDeleted(bool isDeleted, DateTime updatedAt) {
    return copyWith(
      deletedAt: isDeleted ? updatedAt : null,
      updatedAt: updatedAt,
    );
  }
}

// Modelo para películas vistas con información de sincronización
class SyncableWatchedMovie extends SyncableEntity {
  const SyncableWatchedMovie({
    required super.id,
    required super.updatedAt,
    required super.createdAt,
    super.deletedAt, // ✅ Soft delete support
    required this.userId,
    required this.movieId,
    required this.movieTitle,
    required this.watchedAt,
    this.traktId, // ✅ Trakt ID for hybrid support
    this.moviePosterPath,
    this.movieBackdropPath,
    this.movieOverview,
    this.movieReleaseDate,
    this.movieVoteAverage,
    super.syncStatus = SyncStatus.synced,
  });

  // Crear desde JSON
  factory SyncableWatchedMovie.fromJson(Map<String, dynamic> json) {
    return SyncableWatchedMovie(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      movieId: json['movie_id'] as int,
      movieTitle: json['movie_title'] as String,
      traktId: json['trakt_id'] as int?,
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
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }

  // Crear desde Movie
  factory SyncableWatchedMovie.fromMovie({
    required String userId,
    required Movie movie,
    String? customId,
    int? traktId, // ✅ Optional Trakt ID
  }) {
    final now = DateTime.now();
    return SyncableWatchedMovie(
      id: customId ?? '${userId}_${movie.id}',
      userId: userId,
      movieId: movie.id,
      movieTitle: movie.title,
      traktId: traktId, // ✅ Include Trakt ID
      moviePosterPath: movie.posterPath,
      movieBackdropPath: movie.backdropPath,
      movieOverview: movie.overview,
      movieReleaseDate: movie.releaseDate,
      movieVoteAverage: movie.voteAverage,
      watchedAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  // Crear desde WatchedMovie
  factory SyncableWatchedMovie.fromWatchedMovie(
      WatchedMovie watchedMovie, String userId,
      {int? traktId}) {
    return SyncableWatchedMovie(
      id: '${userId}_${watchedMovie.movie.id}',
      userId: userId,
      movieId: watchedMovie.movie.id,
      movieTitle: watchedMovie.movie.title,
      traktId: traktId, // ✅ Include Trakt ID
      moviePosterPath: watchedMovie.movie.posterPath,
      movieBackdropPath: watchedMovie.movie.backdropPath,
      movieOverview: watchedMovie.movie.overview,
      movieReleaseDate: watchedMovie.movie.releaseDate,
      movieVoteAverage: watchedMovie.movie.voteAverage,
      watchedAt: watchedMovie.watchedDate,
      createdAt: watchedMovie.watchedDate,
      updatedAt: watchedMovie.watchedDate,
    );
  }
  final String userId;
  final int movieId;
  final String movieTitle;
  final int? traktId; // ✅ Nullable Trakt ID for gradual migration
  final String? moviePosterPath;
  final String? movieBackdropPath;
  final String? movieOverview;
  final DateTime? movieReleaseDate;
  final double? movieVoteAverage;
  final DateTime watchedAt;

  // ✅ Getter para determinar la fuente de datos preferida
  MovieDataSource get preferredSource =>
      traktId != null ? MovieDataSource.trakt : MovieDataSource.tmdb;

  // Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'movie_id': movieId,
      'movie_title': movieTitle,
      'trakt_id': traktId,
      'movie_poster_path': moviePosterPath,
      'movie_backdrop_path': movieBackdropPath,
      'movie_overview': movieOverview,
      'movie_release_date': movieReleaseDate?.toIso8601String(),
      'movie_vote_average': movieVoteAverage,
      'watched_at': watchedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  // Convertir a Movie
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

  // Convertir a modelo de dominio WatchedMovie
  WatchedMovie toWatchedMovie() {
    final movie = toMovie();
    return WatchedMovie(
      movie: movie,
      watchedDate: watchedAt,
    );
  }

  SyncableWatchedMovie copyWith({
    String? id,
    String? userId,
    int? movieId,
    String? movieTitle,
    int? traktId, // ✅ Include Trakt ID parameter
    String? moviePosterPath,
    String? movieBackdropPath,
    String? movieOverview,
    DateTime? movieReleaseDate,
    double? movieVoteAverage,
    DateTime? watchedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt, // ✅ Include deletedAt
    SyncStatus? syncStatus,
  }) {
    return SyncableWatchedMovie(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      traktId: traktId ?? this.traktId, // ✅ Include Trakt ID
      moviePosterPath: moviePosterPath ?? this.moviePosterPath,
      movieBackdropPath: movieBackdropPath ?? this.movieBackdropPath,
      movieOverview: movieOverview ?? this.movieOverview,
      movieReleaseDate: movieReleaseDate ?? this.movieReleaseDate,
      movieVoteAverage: movieVoteAverage ?? this.movieVoteAverage,
      watchedAt: watchedAt ?? this.watchedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt, // ✅ Include deletedAt
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  // ✅ Implementación de SoftDeletable
  @override
  SoftDeletable copyWithDeleted(bool isDeleted, DateTime updatedAt) {
    return copyWith(
      deletedAt: isDeleted ? updatedAt : null,
      updatedAt: updatedAt,
    );
  }
}
