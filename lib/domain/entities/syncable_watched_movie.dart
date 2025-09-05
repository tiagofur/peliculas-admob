
import '../../core/sync/sync_utilities.dart';
import 'movie.dart';
import 'syncable_entity.dart';
import 'watched_movie.dart';

/// Entidad de película vista que implementa SyncableEntity
/// para el sistema de sincronización offline-first
class SyncableWatchedMovie extends SyncableEntity {
  SyncableWatchedMovie({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.lastModifiedAt,
    this.isDeleted = false,
    this.syncVersion = 0,
    this.deviceId,
    required this.movieId,
    required this.movieTitle,
    this.moviePosterPath,
    this.movieBackdropPath,
    this.movieOverview,
    this.movieReleaseDate,
    this.movieVoteAverage,
    required this.watchedDate,
    this.personalRating,
    this.personalNotes,
    this.watchedLocation,
    this.rewatchCount = 0,
  });

  /// Factory constructor desde Movie
  factory SyncableWatchedMovie.fromMovie({
    required String userId,
    required Movie movie,
    String? customId,
    DateTime? watchedDate,
    double? personalRating,
    String? personalNotes,
    String? watchedLocation,
    int rewatchCount = 0,
    String? deviceId,
  }) {
    final now = SyncUtilities.utcNow();
    return SyncableWatchedMovie(
      id: customId ?? SyncUtilities.generateUuid(),
      userId: userId,
      movieId: movie.id,
      movieTitle: movie.title,
      moviePosterPath: movie.posterPath,
      movieBackdropPath: movie.backdropPath,
      movieOverview: movie.overview,
      movieReleaseDate: movie.releaseDate,
      movieVoteAverage: movie.voteAverage,
      watchedDate: watchedDate ?? now,
      createdAt: now,
      lastModifiedAt: now,
      personalRating: personalRating,
      personalNotes: personalNotes,
      watchedLocation: watchedLocation,
      rewatchCount: rewatchCount,
      deviceId: deviceId,
    );
  }

  /// Factory constructor desde WatchedMovie existente
  factory SyncableWatchedMovie.fromWatchedMovie({
    required String userId,
    required WatchedMovie watchedMovie,
    String? deviceId,
  }) {
    final now = SyncUtilities.utcNow();
    return SyncableWatchedMovie(
      id: SyncUtilities.generateUuid(),
      userId: userId,
      movieId: watchedMovie.movie.id,
      movieTitle: watchedMovie.movie.title,
      moviePosterPath: watchedMovie.movie.posterPath,
      movieBackdropPath: watchedMovie.movie.backdropPath,
      movieOverview: watchedMovie.movie.overview,
      movieReleaseDate: watchedMovie.movie.releaseDate,
      movieVoteAverage: watchedMovie.movie.voteAverage,
      watchedDate: watchedMovie.watchedDate,
      createdAt: now,
      lastModifiedAt: watchedMovie.lastModifiedAt ?? now,
      isDeleted: watchedMovie.isDeleted ?? false,
      deviceId: deviceId,
    );
  }

  /// Factory constructor desde JSON
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
      movieVoteAverage: json['movie_vote_average']?.toDouble(),
      watchedDate: DateTime.parse(json['watched_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      lastModifiedAt: DateTime.parse(json['last_modified_at'] as String),
      isDeleted: json['is_deleted'] as bool? ?? false,
      syncVersion: json['sync_version'] as int? ?? 0,
      deviceId: json['device_id'] as String?,
      personalRating: json['personal_rating']?.toDouble(),
      personalNotes: json['personal_notes'] as String?,
      watchedLocation: json['watched_location'] as String?,
      rewatchCount: json['rewatch_count'] as int? ?? 0,
    );
  }

  /// Factory constructor desde string JSON
  factory SyncableWatchedMovie.fromJsonString(String jsonString) {
    final json = SyncUtilities.decodeJson(jsonString);
    return SyncableWatchedMovie.fromJson(json);
  }

  // Implementación de getters de SyncableEntity
  @override
  final String id;
  
  @override
  final String userId;
  
  @override
  final DateTime createdAt;
  
  @override
  final DateTime lastModifiedAt;
  
  @override
  final bool isDeleted;
  
  @override
  final int syncVersion;
  
  @override
  final String? deviceId;

  /// ID de la película en TMDB
  final int movieId;

  /// Título de la película
  final String movieTitle;

  /// Ruta del poster de la película
  final String? moviePosterPath;

  /// Ruta del backdrop de la película
  final String? movieBackdropPath;

  /// Sinopsis de la película
  final String? movieOverview;

  /// Fecha de lanzamiento de la película
  final DateTime? movieReleaseDate;

  /// Puntuación promedio de la película
  final double? movieVoteAverage;

  /// Fecha cuando se vio la película
  final DateTime watchedDate;

  /// Calificación personal del usuario (1-10)
  final double? personalRating;

  /// Notas personales del usuario
  final String? personalNotes;

  /// Ubicación donde se vio la película
  final String? watchedLocation;

  /// Número de veces que se ha visto la película
  final int rewatchCount;

  @override
  String get entityType => 'watched_movie';

  @override
  Map<String, dynamic> toSupabaseJson() {
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
      'watched_date': watchedDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'last_modified_at': lastModifiedAt.toIso8601String(),
      'is_deleted': isDeleted,
      'sync_version': syncVersion,
      'device_id': deviceId,
      'personal_rating': personalRating,
      'personal_notes': personalNotes,
      'watched_location': watchedLocation,
      'rewatch_count': rewatchCount,
    };
  }

  @override
  Map<String, dynamic> toLocalStorage() {
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
      'watchedDate': watchedDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'lastModifiedAt': lastModifiedAt.toIso8601String(),
      'isDeleted': isDeleted,
      'syncVersion': syncVersion,
      'deviceId': deviceId,
      'personalRating': personalRating,
      'personalNotes': personalNotes,
      'watchedLocation': watchedLocation,
      'rewatchCount': rewatchCount,
    };
  }

  @override
  String generateChecksum() {
    final contentData = {
      'movieId': movieId,
      'movieTitle': movieTitle,
      'moviePosterPath': moviePosterPath,
      'movieBackdropPath': movieBackdropPath,
      'movieOverview': movieOverview,
      'movieReleaseDate': movieReleaseDate?.toIso8601String(),
      'movieVoteAverage': movieVoteAverage,
      'watchedDate': watchedDate.toIso8601String(),
      'personalRating': personalRating,
      'personalNotes': personalNotes,
      'watchedLocation': watchedLocation,
      'rewatchCount': rewatchCount,
    };
    return SyncUtilities.generateChecksum(contentData);
  }

  @override
  bool hasSameContentAs(SyncableEntity other) {
    if (other is! SyncableWatchedMovie) return false;
    return movieId == other.movieId &&
        movieTitle == other.movieTitle &&
        moviePosterPath == other.moviePosterPath &&
        movieBackdropPath == other.movieBackdropPath &&
        movieOverview == other.movieOverview &&
        movieReleaseDate == other.movieReleaseDate &&
        movieVoteAverage == other.movieVoteAverage &&
        watchedDate == other.watchedDate &&
        personalRating == other.personalRating &&
        personalNotes == other.personalNotes &&
        watchedLocation == other.watchedLocation &&
        rewatchCount == other.rewatchCount;
  }

  @override
  SyncableEntity mergeWith(SyncableEntity other) {
    if (other is! SyncableWatchedMovie) {
      throw ArgumentError(
          'Cannot merge SyncableWatchedMovie with ${other.runtimeType}');
    }

    // Usar la versión más reciente como base
    final newer = lastModifiedAt.isAfter(other.lastModifiedAt) ? this : other;
    final older = lastModifiedAt.isAfter(other.lastModifiedAt) ? other : this;

    return SyncableWatchedMovie(
      id: id,
      userId: userId,
      movieId: movieId,
      movieTitle: newer.movieTitle,
      moviePosterPath: newer.moviePosterPath ?? older.moviePosterPath,
      movieBackdropPath: newer.movieBackdropPath ?? older.movieBackdropPath,
      movieOverview: newer.movieOverview ?? older.movieOverview,
      movieReleaseDate: newer.movieReleaseDate ?? older.movieReleaseDate,
      movieVoteAverage: newer.movieVoteAverage ?? older.movieVoteAverage,
      watchedDate: newer.watchedDate, // Usar la fecha más reciente
      createdAt: createdAt,
      lastModifiedAt: SyncUtilities.utcNow(),
      isDeleted: newer.isDeleted,
      syncVersion: syncVersion + 1,
      deviceId: deviceId,
      personalRating: newer.personalRating ?? older.personalRating,
      personalNotes: newer.personalNotes ?? older.personalNotes,
      watchedLocation: newer.watchedLocation ?? older.watchedLocation,
      rewatchCount: newer.rewatchCount > older.rewatchCount 
          ? newer.rewatchCount 
          : older.rewatchCount, // Mantener el mayor
    );
  }

  @override
  List<String> getValidationErrors() {
    final errors = <String>[];

    if (movieId <= 0) {
      errors.add('movieId must be positive');
    }

    if (movieTitle.trim().isEmpty) {
      errors.add('movieTitle cannot be empty');
    }

    if (personalRating != null &&
        (personalRating! < 1 || personalRating! > 10)) {
      errors.add('personalRating must be between 1 and 10');
    }

    if (rewatchCount < 0) {
      errors.add('rewatchCount cannot be negative');
    }

    return errors;
  }

  @override
  int get syncPriority => 4; // Prioridad media-alta para películas vistas

  /// Crea una copia con campos modificados (implementación de SyncableEntity)
  @override
  SyncableWatchedMovie copyWith({
    DateTime? lastModifiedAt,
    int? syncVersion,
    String? deviceId,
    bool? isDeleted,
  }) {
    return SyncableWatchedMovie(
      id: id,
      userId: userId,
      movieId: movieId,
      movieTitle: movieTitle,
      moviePosterPath: moviePosterPath,
      movieBackdropPath: movieBackdropPath,
      movieOverview: movieOverview,
      movieReleaseDate: movieReleaseDate,
      movieVoteAverage: movieVoteAverage,
      watchedDate: watchedDate,
      createdAt: createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncVersion: syncVersion ?? this.syncVersion,
      deviceId: deviceId ?? this.deviceId,
      personalRating: personalRating,
      personalNotes: personalNotes,
      watchedLocation: watchedLocation,
      rewatchCount: rewatchCount,
    );
  }

  /// Método copyWith extendido para uso interno
  SyncableWatchedMovie copyWithData({
    String? id,
    String? userId,
    int? movieId,
    String? movieTitle,
    String? moviePosterPath,
    String? movieBackdropPath,
    String? movieOverview,
    DateTime? movieReleaseDate,
    double? movieVoteAverage,
    DateTime? watchedDate,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    bool? isDeleted,
    int? syncVersion,
    String? deviceId,
    double? personalRating,
    String? personalNotes,
    String? watchedLocation,
    int? rewatchCount,
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
      watchedDate: watchedDate ?? this.watchedDate,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncVersion: syncVersion ?? this.syncVersion,
      deviceId: deviceId ?? this.deviceId,
      personalRating: personalRating ?? this.personalRating,
      personalNotes: personalNotes ?? this.personalNotes,
      watchedLocation: watchedLocation ?? this.watchedLocation,
      rewatchCount: rewatchCount ?? this.rewatchCount,
    );
  }

  /// Convierte a Movie para compatibilidad
  Movie toMovie() {
    return Movie(
      id: movieId,
      title: movieTitle,
      posterPath: moviePosterPath ?? '',
      backdropPath: movieBackdropPath ?? '',
      overview: movieOverview ?? '',
      releaseDate: movieReleaseDate ?? DateTime.now(),
      voteAverage: movieVoteAverage ?? 0.0,
      genreIds: [], // No disponible en watched movies
      adult: false, // Valor por defecto
      originalLanguage: '', // No disponible
      originalTitle: movieTitle, // Usar el título como fallback
      popularity: 0.0, // No disponible
      video: false, // Valor por defecto
      voteCount: 0, // No disponible
    );
  }

  /// Convierte a WatchedMovie para compatibilidad
  WatchedMovie toWatchedMovie() {
    return WatchedMovie(
      movie: toMovie(),
      watchedDate: watchedDate,
      lastModifiedAt: lastModifiedAt,
      isDeleted: isDeleted,
    );
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
        other.watchedDate == watchedDate &&
        other.createdAt == createdAt &&
        other.lastModifiedAt == lastModifiedAt &&
        other.isDeleted == isDeleted &&
        other.syncVersion == syncVersion &&
        other.deviceId == deviceId &&
        other.personalRating == personalRating &&
        other.personalNotes == personalNotes &&
        other.watchedLocation == watchedLocation &&
        other.rewatchCount == rewatchCount;
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
      watchedDate,
      createdAt,
      lastModifiedAt,
      isDeleted,
      syncVersion,
      deviceId,
      personalRating,
      personalNotes,
      watchedLocation,
      rewatchCount,
    );
  }

  @override
  String toString() {
    return 'SyncableWatchedMovie(id: $id, userId: $userId, movieId: $movieId, '
        'movieTitle: $movieTitle, watchedDate: $watchedDate, isDeleted: $isDeleted, '
        'syncVersion: $syncVersion, lastModifiedAt: $lastModifiedAt)';
  }

  // =============================================
  // CONVERSIÓN PARA REPOSITORIOS HÍBRIDOS
  // =============================================

  /// Convierte a string JSON para almacenamiento local
  String toJsonString() {
    return SyncUtilities.encodeJson(toLocalStorage());
  }

  // Propiedades de conveniencia para compatibilidad
  String? get posterPath => moviePosterPath;
  String? get overview => movieOverview;
  DateTime? get releaseDate => movieReleaseDate;
  double? get rating => movieVoteAverage;
}