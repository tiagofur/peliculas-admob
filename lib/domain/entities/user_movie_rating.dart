class UserMovieRating {
  const UserMovieRating({
    required this.id,
    required this.userId,
    required this.movieId,
    required this.movieTitle,
    this.moviePosterPath,
    required this.rating,
    this.personalNote,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory constructor para crear desde JSON
  factory UserMovieRating.fromJson(Map<String, dynamic> json) {
    return UserMovieRating(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      movieId: json['movie_id'] as int,
      movieTitle: json['movie_title'] as String,
      moviePosterPath: json['movie_poster_path'] as String?,
      rating: json['rating'] as int,
      personalNote: json['personal_note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
  final String id;
  final String userId;
  final int movieId;
  final String movieTitle;
  final String? moviePosterPath;
  final int rating; // 1-5 stars
  final String? personalNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Convierte la valoración a JSON
  Map<String, dynamic> toJson() {
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

  /// Convierte a Map para insertar en Supabase (sin timestamps generados)
  Map<String, dynamic> toSupabaseInsert() {
    return {
      'user_id': userId,
      'movie_id': movieId,
      'movie_title': movieTitle,
      'movie_poster_path': moviePosterPath,
      'rating': rating,
      'personal_note': personalNote,
    };
  }

  /// Convierte a Map para actualizar en Supabase (sin created_at)
  Map<String, dynamic> toSupabaseUpdate() {
    return {
      'movie_title': movieTitle,
      'movie_poster_path': moviePosterPath,
      'rating': rating,
      'personal_note': personalNote,
    };
  }

  /// Crea una copia con campos modificados
  UserMovieRating copyWith({
    String? id,
    String? userId,
    int? movieId,
    String? movieTitle,
    String? moviePosterPath,
    int? rating,
    String? personalNote,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserMovieRating(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      moviePosterPath: moviePosterPath ?? this.moviePosterPath,
      rating: rating ?? this.rating,
      personalNote: personalNote ?? this.personalNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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

    return other is UserMovieRating &&
        other.id == id &&
        other.userId == userId &&
        other.movieId == movieId &&
        other.movieTitle == movieTitle &&
        other.moviePosterPath == moviePosterPath &&
        other.rating == rating &&
        other.personalNote == personalNote &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        movieId.hashCode ^
        movieTitle.hashCode ^
        (moviePosterPath?.hashCode ?? 0) ^
        rating.hashCode ^
        (personalNote?.hashCode ?? 0) ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }

  @override
  String toString() {
    return 'UserMovieRating(id: $id, userId: $userId, movieId: $movieId, '
        'movieTitle: $movieTitle, rating: $rating, personalNote: $personalNote, '
        'createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
