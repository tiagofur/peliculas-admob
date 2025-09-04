import '../../core/sync/sync_utilities.dart';
import 'movie.dart';
import 'syncable_entity.dart';

/// Entidad de favorito que implementa SyncableEntity
/// para el sistema de sincronización offline-first
class SyncableFavorite extends SyncableEntity {
  SyncableFavorite({
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
    required this.addedAt,
    this.tags = const [],
    this.personalRating,
    this.personalNotes,
  });

  /// Factory constructor desde Movie
  factory SyncableFavorite.fromMovie({
    required String userId,
    required Movie movie,
    String? customId,
    DateTime? addedAt,
    List<String> tags = const [],
    double? personalRating,
    String? personalNotes,
    String? deviceId,
  }) {
    final now = SyncUtilities.utcNow();
    return SyncableFavorite(
      id: customId ?? SyncUtilities.generateUuid(),
      userId: userId,
      movieId: movie.id,
      movieTitle: movie.title,
      moviePosterPath: movie.posterPath,
      movieBackdropPath: movie.backdropPath,
      movieOverview: movie.overview,
      movieReleaseDate: movie.releaseDate,
      movieVoteAverage: movie.voteAverage,
      addedAt: addedAt ?? now,
      createdAt: now,
      lastModifiedAt: now,
      tags: tags,
      personalRating: personalRating,
      personalNotes: personalNotes,
      deviceId: deviceId,
    );
  }

  /// Factory constructor desde JSON
  factory SyncableFavorite.fromJson(Map<String, dynamic> json) {
    return SyncableFavorite(
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
      addedAt: DateTime.parse(json['added_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      lastModifiedAt: DateTime.parse(json['last_modified_at'] as String),
      isDeleted: json['is_deleted'] as bool? ?? false,
      syncVersion: json['sync_version'] as int? ?? 0,
      deviceId: json['device_id'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      personalRating: json['personal_rating']?.toDouble(),
      personalNotes: json['personal_notes'] as String?,
    );
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

  /// Fecha cuando se agregó a favoritos
  final DateTime addedAt;

  /// Tags personalizados del usuario
  final List<String> tags;

  /// Calificación personal del usuario (1-10)
  final double? personalRating;

  /// Notas personales del usuario
  final String? personalNotes;

  @override
  String get entityType => 'favorite';

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
      'added_at': addedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'last_modified_at': lastModifiedAt.toIso8601String(),
      'is_deleted': isDeleted,
      'sync_version': syncVersion,
      'device_id': deviceId,
      'tags': tags,
      'personal_rating': personalRating,
      'personal_notes': personalNotes,
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
      'addedAt': addedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'lastModifiedAt': lastModifiedAt.toIso8601String(),
      'isDeleted': isDeleted,
      'syncVersion': syncVersion,
      'deviceId': deviceId,
      'tags': tags,
      'personalRating': personalRating,
      'personalNotes': personalNotes,
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
      'addedAt': addedAt.toIso8601String(),
      'tags': tags,
      'personalRating': personalRating,
      'personalNotes': personalNotes,
    };
    return SyncUtilities.generateChecksum(contentData);
  }

  @override
  bool hasSameContentAs(SyncableEntity other) {
    if (other is! SyncableFavorite) return false;
    return movieId == other.movieId &&
        movieTitle == other.movieTitle &&
        moviePosterPath == other.moviePosterPath &&
        movieBackdropPath == other.movieBackdropPath &&
        movieOverview == other.movieOverview &&
        movieReleaseDate == other.movieReleaseDate &&
        movieVoteAverage == other.movieVoteAverage &&
        addedAt == other.addedAt &&
        _listEquals(tags, other.tags) &&
        personalRating == other.personalRating &&
        personalNotes == other.personalNotes;
  }

  @override
  SyncableEntity mergeWith(SyncableEntity other) {
    if (other is! SyncableFavorite) {
      throw ArgumentError(
          'Cannot merge SyncableFavorite with ${other.runtimeType}');
    }

    // Usar la versión más reciente como base
    final newer = lastModifiedAt.isAfter(other.lastModifiedAt) ? this : other;
    final older = lastModifiedAt.isAfter(other.lastModifiedAt) ? other : this;

    return SyncableFavorite(
      id: id,
      userId: userId,
      movieId: movieId,
      movieTitle: newer.movieTitle,
      moviePosterPath: newer.moviePosterPath ?? older.moviePosterPath,
      movieBackdropPath: newer.movieBackdropPath ?? older.movieBackdropPath,
      movieOverview: newer.movieOverview ?? older.movieOverview,
      movieReleaseDate: newer.movieReleaseDate ?? older.movieReleaseDate,
      movieVoteAverage: newer.movieVoteAverage ?? older.movieVoteAverage,
      addedAt: older.addedAt, // Mantener la fecha original
      createdAt: createdAt,
      lastModifiedAt: SyncUtilities.utcNow(),
      isDeleted: newer.isDeleted,
      syncVersion: syncVersion + 1,
      deviceId: deviceId,
      // Combinar tags únicos
      tags: {...older.tags, ...newer.tags}.toList(),
      personalRating: newer.personalRating ?? older.personalRating,
      personalNotes: newer.personalNotes ?? older.personalNotes,
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

    if (tags.any((tag) => tag.trim().isEmpty)) {
      errors.add('tags cannot contain empty strings');
    }

    return errors;
  }

  @override
  int get syncPriority => 5; // Prioridad media para favoritos

  /// Crea una copia con campos modificados (implementación de SyncableEntity)
  @override
  SyncableFavorite copyWith({
    DateTime? lastModifiedAt,
    int? syncVersion,
    String? deviceId,
    bool? isDeleted,
  }) {
    return SyncableFavorite(
      id: id,
      userId: userId,
      movieId: movieId,
      movieTitle: movieTitle,
      moviePosterPath: moviePosterPath,
      movieBackdropPath: movieBackdropPath,
      movieOverview: movieOverview,
      movieReleaseDate: movieReleaseDate,
      movieVoteAverage: movieVoteAverage,
      addedAt: addedAt,
      createdAt: createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncVersion: syncVersion ?? this.syncVersion,
      deviceId: deviceId ?? this.deviceId,
      tags: tags,
      personalRating: personalRating,
      personalNotes: personalNotes,
    );
  }

  /// Método copyWith extendido para uso interno
  SyncableFavorite copyWithData({
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
    DateTime? lastModifiedAt,
    bool? isDeleted,
    int? syncVersion,
    String? deviceId,
    List<String>? tags,
    double? personalRating,
    String? personalNotes,
  }) {
    return SyncableFavorite(
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
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncVersion: syncVersion ?? this.syncVersion,
      deviceId: deviceId ?? this.deviceId,
      tags: tags ?? this.tags,
      personalRating: personalRating ?? this.personalRating,
      personalNotes: personalNotes ?? this.personalNotes,
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
      genreIds: [], // No disponible en favoritos
      adult: false, // Valor por defecto
      originalLanguage: '', // No disponible
      originalTitle: movieTitle, // Usar el título como fallback
      popularity: 0.0, // No disponible
      video: false, // Valor por defecto
      voteCount: 0, // No disponible
    );
  }

  /// Utilidad para comparar listas
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncableFavorite &&
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
        other.lastModifiedAt == lastModifiedAt &&
        other.isDeleted == isDeleted &&
        other.syncVersion == syncVersion &&
        other.deviceId == deviceId &&
        _listEquals(other.tags, tags) &&
        other.personalRating == personalRating &&
        other.personalNotes == personalNotes;
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
      lastModifiedAt,
      isDeleted,
      syncVersion,
      deviceId,
      Object.hashAll(tags),
      personalRating,
      personalNotes,
    );
  }

  @override
  String toString() {
    return 'SyncableFavorite(id: $id, userId: $userId, movieId: $movieId, '
        'movieTitle: $movieTitle, isDeleted: $isDeleted, '
        'syncVersion: $syncVersion, lastModifiedAt: $lastModifiedAt)';
  }
}
