class UserMovieRating {
  const UserMovieRating({
    required this.id,
    required this.userId,
    required this.movieId,
    required this.movieTitle,
    this.moviePosterPath,
    required this.rating,
    this.review,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory constructor para crear desde JSON
  factory UserMovieRating.fromJson(Map<String, dynamic> json) {
    return UserMovieRating(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      movieId: json['movie_id'] as int? ?? 0,
      movieTitle: json['movie_title']?.toString() ?? '',
      moviePosterPath: json['movie_poster_path']?.toString(),
      rating: (json['rating'] as num?)?.toDouble() ?? 1.0,
      review: json['review']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['last_modified_at'] != null
          ? DateTime.parse(json['last_modified_at'].toString())
          : DateTime.now(),
    );
  }
  final String id;
  final String userId;
  final int movieId;
  final String movieTitle;
  final String? moviePosterPath;
  final double rating; // 1.0-10.0 stars
  final String? review;
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
      'review': review,
      'created_at': createdAt.toIso8601String(),
      'last_modified_at': updatedAt.toIso8601String(),
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
      'review': review,
    };
  }

  /// Convierte a Map para actualizar en Supabase (sin created_at)
  Map<String, dynamic> toSupabaseUpdate() {
    return {
      'movie_title': movieTitle,
      'movie_poster_path': moviePosterPath,
      'rating': rating,
      'review': review,
    };
  }

  /// Crea una copia con campos modificados
  UserMovieRating copyWith({
    String? id,
    String? userId,
    int? movieId,
    String? movieTitle,
    String? moviePosterPath,
    double? rating,
    String? review,
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
      review: review ?? this.review,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Valida que el rating esté en el rango correcto
  bool get isValidRating => rating >= 1.0 && rating <= 10.0;

  /// Valida que la reseña no exceda el límite
  bool get isValidReview => review == null || (review?.length ?? 0) <= 500;

  /// Valida que la entidad sea válida
  bool get isValid => isValidRating && isValidReview;

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
        other.review == review &&
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
        (review?.hashCode ?? 0) ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }

  @override
  String toString() {
    return 'UserMovieRating(id: $id, userId: $userId, movieId: $movieId, '
        'movieTitle: $movieTitle, rating: $rating, review: $review, '
        'createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
