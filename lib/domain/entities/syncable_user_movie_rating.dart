import 'user_movie_rating.dart';

/// Entidad sincronizable para valoraciones de usuario que incluye metadatos de sincronización
class SyncableUserMovieRating {
  const SyncableUserMovieRating({
    required this.id,
    required this.userId,
    required this.movieId,
    required this.movieTitle,
    this.moviePosterPath,
    required this.rating,
    this.personalNote,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.needsSync = true,
  });

  /// Convierte de UserMovieRating local a SyncableUserMovieRating
  factory SyncableUserMovieRating.fromUserMovieRating(
    UserMovieRating rating, {
    bool isSynced = false,
    bool needsSync = true,
  }) {
    return SyncableUserMovieRating(
      id: rating.id,
      userId: rating.userId,
      movieId: rating.movieId,
      movieTitle: rating.movieTitle,
      moviePosterPath: rating.moviePosterPath,
      rating: rating.rating,
      personalNote: rating.personalNote,
      createdAt: rating.createdAt,
      updatedAt: rating.updatedAt,
      isSynced: isSynced,
      needsSync: needsSync,
    );
  }

  /// Convierte de datos de Supabase a SyncableUserMovieRating
  factory SyncableUserMovieRating.fromSupabase(Map<String, dynamic> data) {
    return SyncableUserMovieRating(
      id: data['id'] as String,
      userId: data['user_id'] as String,
      movieId: data['movie_id'] as int,
      movieTitle: data['movie_title'] as String,
      moviePosterPath: data['movie_poster_path'] as String?,
      rating: data['rating'] as int,
      personalNote: data['personal_note'] as String?,
      createdAt: DateTime.parse(data['created_at'] as String),
      updatedAt: DateTime.parse(data['updated_at'] as String),
      isSynced: true,
      needsSync: false,
    );
  }

  /// Convierte desde JSON (compatible con payload de realtime)
  factory SyncableUserMovieRating.fromJson(Map<String, dynamic> json) {
    return SyncableUserMovieRating.fromSupabase(json);
  }
  final String id;
  final String userId;
  final int movieId;
  final String movieTitle;
  final String? moviePosterPath;
  final int rating;
  final String? personalNote;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final bool needsSync;

  /// Convierte a UserMovieRating local
  UserMovieRating toUserMovieRating() {
    return UserMovieRating(
      id: id,
      userId: userId,
      movieId: movieId,
      movieTitle: movieTitle,
      moviePosterPath: moviePosterPath,
      rating: rating,
      personalNote: personalNote,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Convierte a formato para Supabase
  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'user_id': userId,
      'movie_id': movieId,
      'movie_title': movieTitle,
      'movie_poster_path': moviePosterPath,
      'rating': rating,
      'personal_note': personalNote,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convierte a JSON (compatible con sync manager)
  Map<String, dynamic> toJson() {
    return toSupabase();
  }

  SyncableUserMovieRating copyWith({
    String? id,
    String? userId,
    int? movieId,
    String? movieTitle,
    String? moviePosterPath,
    int? rating,
    String? personalNote,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    bool? needsSync,
  }) {
    return SyncableUserMovieRating(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      moviePosterPath: moviePosterPath ?? this.moviePosterPath,
      rating: rating ?? this.rating,
      personalNote: personalNote ?? this.personalNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      needsSync: needsSync ?? this.needsSync,
    );
  }

  /// Valida que el rating esté en el rango correcto
  bool get isValidRating => rating >= 1 && rating <= 5;

  /// Valida que la nota personal no exceda el límite
  bool get isValidNote => personalNote == null || (personalNote?.length ?? 0) <= 500;

  /// Valida que la entidad sea válida
  bool get isValid => isValidRating && isValidNote;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncableUserMovieRating &&
        other.id == id &&
        other.userId == userId &&
        other.movieId == movieId &&
        other.rating == rating;
  }

  @override
  int get hashCode {
    return id.hashCode ^ userId.hashCode ^ movieId.hashCode ^ rating.hashCode;
  }

  @override
  String toString() {
    return 'SyncableUserMovieRating(id: $id, userId: $userId, movieId: $movieId, title: $movieTitle, rating: $rating, synced: $isSynced)';
  }
}
