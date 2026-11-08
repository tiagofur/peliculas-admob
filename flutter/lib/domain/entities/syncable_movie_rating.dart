import '../../core/logging/logger_factory.dart';
import '../../core/sync/sync_utilities.dart';
import 'movie.dart';
import 'syncable_entity.dart';

/// Entidad de calificación de película que implementa SyncableEntity
/// para el sistema de sincronización offline-first
class SyncableMovieRating extends SyncableEntity {
  SyncableMovieRating({
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
    required this.rating,
    this.review,
    required this.ratedAt,
    this.isPublic = false,
    this.tags = const [],
  });

  /// Factory constructor desde Movie
  factory SyncableMovieRating.fromMovie({
    required String userId,
    required Movie movie,
    required double rating,
    String? review,
    String? customId,
    DateTime? ratedAt,
    bool isPublic = false,
    List<String> tags = const [],
    String? deviceId,
  }) {
    final now = SyncUtilities.utcNow();
    return SyncableMovieRating(
      id: customId ?? SyncUtilities.generateUuid(),
      userId: userId,
      movieId: movie.id,
      movieTitle: movie.title,
      moviePosterPath: movie.posterPath,
      movieBackdropPath: movie.backdropPath,
      movieOverview: movie.overview,
      movieReleaseDate: movie.releaseDate,
      movieVoteAverage: movie.voteAverage,
      rating: rating,
      review: review,
      ratedAt: ratedAt ?? now,
      createdAt: now,
      lastModifiedAt: now,
      isPublic: isPublic,
      tags: tags,
      deviceId: deviceId,
    );
  }

  /// Factory constructor desde JSON
  factory SyncableMovieRating.fromJson(Map<String, dynamic> json) {
    T? read<T>(List<String> keys) {
      for (final key in keys) {
        if (json.containsKey(key) && json[key] != null) {
          return json[key] as T;
        }
      }
      return null;
    }

    DateTime? parseDate(List<String> keys) {
      final value = read<dynamic>(keys);
      if (value == null) return null;
      if (value is DateTime) return value.toUtc();
      if (value is String && value.isNotEmpty) {
        return DateTime.parse(value);
      }
      return null;
    }

    double? parseDouble(List<String> keys) {
      final value = read<dynamic>(keys);
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) {
        return double.tryParse(value);
      }
      return null;
    }

    int? parseInt(List<String> keys) {
      final value = read<dynamic>(keys);
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        return int.tryParse(value);
      }
      return null;
    }

    List<String> parseStringList(List<String> keys) {
      final value = read<dynamic>(keys);
      if (value == null) return [];

      if (value is List) {
        return value
            .where((element) => element != null)
            .map((element) => element.toString())
            .toList();
      }

      if (value is String && value.isNotEmpty) {
        return value.split(',').map((tag) => tag.trim()).toList();
      }

      return [];
    }

    String? readString(List<String> keys) {
      final value = read<dynamic>(keys);
      if (value == null) return null;
      return value.toString();
    }

    bool? readBool(List<String> keys) {
      final value = read<dynamic>(keys);
      if (value == null) return null;
      if (value is bool) return value;
      if (value is String) {
        final normalized = value.toLowerCase();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
      if (value is num) {
        return value != 0;
      }
      return null;
    }

    return SyncableMovieRating(
      id: readString(['id']) ??
          'unknown_${DateTime.now().millisecondsSinceEpoch}',
      userId: readString(['user_id', 'userId']) ?? 'unknown_user',
      movieId: parseInt(['movie_id', 'movieId']) ?? 0,
      movieTitle: readString(['movie_title', 'movieTitle']) ?? 'Unknown Movie',
      moviePosterPath: readString(['movie_poster_path', 'moviePosterPath']),
      movieBackdropPath:
          readString(['movie_backdrop_path', 'movieBackdropPath']),
      movieOverview: readString(['movie_overview', 'movieOverview']),
      movieReleaseDate: parseDate(['movie_release_date', 'movieReleaseDate']),
      movieVoteAverage: parseDouble(['movie_vote_average', 'movieVoteAverage']),
      rating: parseDouble(['rating']) ?? 0.0,
      review: readString(['review']),
      ratedAt: parseDate(['rated_at', 'ratedAt']) ?? DateTime.now(),
      createdAt: parseDate(['created_at', 'createdAt']) ?? DateTime.now(),
      lastModifiedAt:
          parseDate(['last_modified_at', 'lastModifiedAt']) ?? DateTime.now(),
      isDeleted: readBool(['is_deleted', 'isDeleted']) ?? false,
      syncVersion: parseInt(['sync_version', 'syncVersion']) ?? 0,
      deviceId: readString(['device_id', 'deviceId']),
      isPublic: readBool(['is_public', 'isPublic']) ?? false,
      tags: parseStringList(['tags']),
    );
  }

  /// Factory constructor desde string JSON
  factory SyncableMovieRating.fromJsonString(String jsonString) {
    final json = SyncUtilities.decodeJson(jsonString);
    return SyncableMovieRating.fromJson(json);
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

  /// Calificación del usuario (1.0-10.0)
  final double rating;

  /// Review/reseña del usuario
  final String? review;

  /// Fecha cuando se calificó la película
  final DateTime ratedAt;

  /// Si la calificación es pública
  final bool isPublic;

  /// Tags asociados a la reseña
  final List<String> tags;

  @override
  String get entityType => 'movie_rating';

  @override
  Map<String, dynamic> toSupabaseJson() {
    // ✅ CRITICAL: Validar rating para prevenir numeric field overflow
    // Database: DECIMAL(3,1) solo acepta 1.0-10.0
    final validatedRating = rating.clamp(1.0, 10.0);

    if (rating != validatedRating) {
      // Log warning si el valor fue ajustado
      LoggerFactory.warning(
        '⚠️ Rating clamped from $rating to $validatedRating for movie $movieId',
      );
    }

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
      'rating': validatedRating, // ✅ Usar rating validado
      'review': review,
      'rated_at': ratedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'last_modified_at': lastModifiedAt.toIso8601String(),
      'is_deleted': isDeleted,
      'sync_version': syncVersion,
      'device_id': deviceId,
      'is_public': isPublic,
      'tags': tags,
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
      'rating': rating,
      'review': review,
      'ratedAt': ratedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'lastModifiedAt': lastModifiedAt.toIso8601String(),
      'isDeleted': isDeleted,
      'syncVersion': syncVersion,
      'deviceId': deviceId,
      'isPublic': isPublic,
      'tags': tags,
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
      'rating': rating,
      'review': review,
      'ratedAt': ratedAt.toIso8601String(),
      'isPublic': isPublic,
      'tags': tags,
    };
    return SyncUtilities.generateChecksum(contentData);
  }

  @override
  bool hasSameContentAs(SyncableEntity other) {
    if (other is! SyncableMovieRating) return false;
    return movieId == other.movieId &&
        movieTitle == other.movieTitle &&
        moviePosterPath == other.moviePosterPath &&
        movieBackdropPath == other.movieBackdropPath &&
        movieOverview == other.movieOverview &&
        movieReleaseDate == other.movieReleaseDate &&
        movieVoteAverage == other.movieVoteAverage &&
        rating == other.rating &&
        review == other.review &&
        ratedAt == other.ratedAt &&
        isPublic == other.isPublic &&
        tags.toString() == other.tags.toString();
  }

  @override
  SyncableEntity mergeWith(SyncableEntity other) {
    if (other is! SyncableMovieRating) {
      throw ArgumentError(
        'Cannot merge SyncableMovieRating with ${other.runtimeType}',
      );
    }

    // Usar la versión más reciente como base
    final newer = lastModifiedAt.isAfter(other.lastModifiedAt) ? this : other;
    final older = lastModifiedAt.isAfter(other.lastModifiedAt) ? other : this;

    return SyncableMovieRating(
      id: id,
      userId: userId,
      movieId: movieId,
      movieTitle: newer.movieTitle,
      moviePosterPath: newer.moviePosterPath ?? older.moviePosterPath,
      movieBackdropPath: newer.movieBackdropPath ?? older.movieBackdropPath,
      movieOverview: newer.movieOverview ?? older.movieOverview,
      movieReleaseDate: newer.movieReleaseDate ?? older.movieReleaseDate,
      movieVoteAverage: newer.movieVoteAverage ?? older.movieVoteAverage,
      rating: newer.rating, // Usar el rating más reciente
      review: newer.review ?? older.review,
      ratedAt: newer.ratedAt, // Usar la fecha más reciente
      createdAt: createdAt,
      lastModifiedAt: SyncUtilities.utcNow(),
      isDeleted: newer.isDeleted,
      syncVersion: syncVersion + 1,
      deviceId: deviceId,
      isPublic: newer.isPublic,
      tags: newer.tags.isNotEmpty ? newer.tags : older.tags,
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

    if (rating < 1.0 || rating > 10.0) {
      errors.add('rating must be between 1.0 and 10.0');
    }

    if (review != null && review!.trim().isEmpty) {
      errors.add('review cannot be empty if provided');
    }

    return errors;
  }

  @override
  int get syncPriority => 3; // Prioridad media para ratings

  /// Crea una copia con campos modificados (implementación de SyncableEntity)
  @override
  SyncableMovieRating copyWith({
    DateTime? lastModifiedAt,
    int? syncVersion,
    String? deviceId,
    bool? isDeleted,
  }) {
    return SyncableMovieRating(
      id: id,
      userId: userId,
      movieId: movieId,
      movieTitle: movieTitle,
      moviePosterPath: moviePosterPath,
      movieBackdropPath: movieBackdropPath,
      movieOverview: movieOverview,
      movieReleaseDate: movieReleaseDate,
      movieVoteAverage: movieVoteAverage,
      rating: rating,
      review: review,
      ratedAt: ratedAt,
      createdAt: createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncVersion: syncVersion ?? this.syncVersion,
      deviceId: deviceId ?? this.deviceId,
      isPublic: isPublic,
      tags: tags,
    );
  }

  /// Método copyWith extendido para uso interno
  SyncableMovieRating copyWithData({
    String? id,
    String? userId,
    int? movieId,
    String? movieTitle,
    String? moviePosterPath,
    String? movieBackdropPath,
    String? movieOverview,
    DateTime? movieReleaseDate,
    double? movieVoteAverage,
    double? rating,
    String? review,
    DateTime? ratedAt,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    bool? isDeleted,
    int? syncVersion,
    String? deviceId,
    bool? isPublic,
    List<String>? tags,
  }) {
    return SyncableMovieRating(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      moviePosterPath: moviePosterPath ?? this.moviePosterPath,
      movieBackdropPath: movieBackdropPath ?? this.movieBackdropPath,
      movieOverview: movieOverview ?? this.movieOverview,
      movieReleaseDate: movieReleaseDate ?? this.movieReleaseDate,
      movieVoteAverage: movieVoteAverage ?? this.movieVoteAverage,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      ratedAt: ratedAt ?? this.ratedAt,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncVersion: syncVersion ?? this.syncVersion,
      deviceId: deviceId ?? this.deviceId,
      isPublic: isPublic ?? this.isPublic,
      tags: tags ?? this.tags,
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
      genreIds: [], // No disponible en ratings
      adult: false, // Valor por defecto
      originalLanguage: '', // No disponible
      originalTitle: movieTitle, // Usar el título como fallback
      popularity: 0.0, // No disponible
      video: false, // Valor por defecto
      voteCount: 0, // No disponible
    );
  }

  /// Obtiene un resumen de la calificación como string
  String get ratingSummary {
    final buffer = StringBuffer();
    buffer.write('★ ${rating.toStringAsFixed(1)}/10.0');

    if (review != null && review!.isNotEmpty) {
      final previewLength = review!.length > 50 ? 50 : review!.length;
      buffer.write(' - ${review!.substring(0, previewLength)}');
      if (review!.length > 50) buffer.write('...');
    }

    return buffer.toString();
  }

  /// Verifica si tiene una reseña válida
  bool get hasReview => review != null && review!.trim().isNotEmpty;

  /// Obtiene los tags como string
  String get tagsString => tags.join(', ');

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncableMovieRating &&
        other.id == id &&
        other.userId == userId &&
        other.movieId == movieId &&
        other.movieTitle == movieTitle &&
        other.moviePosterPath == moviePosterPath &&
        other.movieBackdropPath == movieBackdropPath &&
        other.movieOverview == movieOverview &&
        other.movieReleaseDate == movieReleaseDate &&
        other.movieVoteAverage == movieVoteAverage &&
        other.rating == rating &&
        other.review == review &&
        other.ratedAt == ratedAt &&
        other.createdAt == createdAt &&
        other.lastModifiedAt == lastModifiedAt &&
        other.isDeleted == isDeleted &&
        other.syncVersion == syncVersion &&
        other.deviceId == deviceId &&
        other.isPublic == isPublic &&
        other.tags.toString() == tags.toString();
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
      rating,
      review,
      ratedAt,
      createdAt,
      lastModifiedAt,
      isDeleted,
      syncVersion,
      deviceId,
      isPublic,
      tags.toString(),
    );
  }

  @override
  String toString() {
    return 'SyncableMovieRating(id: $id, userId: $userId, movieId: $movieId, '
        'movieTitle: $movieTitle, rating: $rating, ratedAt: $ratedAt, '
        'isDeleted: $isDeleted, syncVersion: $syncVersion, '
        'lastModifiedAt: $lastModifiedAt)';
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
  double? get movieRating => movieVoteAverage;
}
