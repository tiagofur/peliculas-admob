import '../../domain/entities/movie.dart';

/// Modelo de dominio para favoritos - usado en la capa de presentación
/// Se convierte desde/hacia SyncableFavorite para operaciones de sync
class FavoriteModel {
  const FavoriteModel({
    required this.id,
    required this.userId,
    required this.movieId,
    required this.movieTitle,
    required this.addedAt,
    this.posterPath,
    this.rating,
    this.overview,
    this.releaseDate,
  });

  final String id;
  final String userId;
  final int movieId;
  final String movieTitle;
  final String? posterPath;
  final double? rating;
  final String? overview;
  final DateTime? releaseDate;
  final DateTime addedAt;

  /// Crea un FavoriteModel desde una SyncableFavorite
  factory FavoriteModel.fromSyncableEntity(dynamic syncableEntity) {
    // Asumiendo que syncableEntity es SyncableFavorite
    return FavoriteModel(
      id: syncableEntity.id,
      userId: syncableEntity.userId,
      movieId: syncableEntity.movieId,
      movieTitle: syncableEntity.movieTitle,
      posterPath: syncableEntity.posterPath,
      rating: syncableEntity.rating,
      overview: syncableEntity.overview,
      releaseDate: syncableEntity.releaseDate,
      addedAt: syncableEntity.addedAt,
    );
  }

  /// Crea desde Map de serialización local
  factory FavoriteModel.fromJson(Map<String, dynamic> json) {
    return FavoriteModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      movieId: json['movie_id'] as int,
      movieTitle: json['movie_title'] as String,
      posterPath: json['poster_path'] as String?,
      rating: json['rating']?.toDouble(),
      overview: json['overview'] as String?,
      releaseDate: json['release_date'] != null 
          ? DateTime.parse(json['release_date'] as String)
          : null,
      addedAt: DateTime.parse(json['added_at'] as String),
    );
  }

  /// Convierte a Map para serialización local
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'movie_id': movieId,
      'movie_title': movieTitle,
      'poster_path': posterPath,
      'rating': rating,
      'overview': overview,
      'release_date': releaseDate?.toIso8601String(),
      'added_at': addedAt.toIso8601String(),
    };
  }

  /// Crea una copia con cambios opcionales
  FavoriteModel copyWith({
    String? id,
    String? userId,
    int? movieId,
    String? movieTitle,
    String? posterPath,
    double? rating,
    String? overview,
    DateTime? releaseDate,
    DateTime? addedAt,
  }) {
    return FavoriteModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      posterPath: posterPath ?? this.posterPath,
      rating: rating ?? this.rating,
      overview: overview ?? this.overview,
      releaseDate: releaseDate ?? this.releaseDate,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FavoriteModel &&
        other.id == id &&
        other.userId == userId &&
        other.movieId == movieId;
  }

  @override
  int get hashCode => Object.hash(id, userId, movieId);

  /// Convierte a Movie para compatibilidad con datasources
  Movie toMovie() {
    return Movie(
      id: movieId,
      title: movieTitle,
      posterPath: posterPath ?? '',
      backdropPath: '', // No disponible en favoritos
      overview: overview ?? '',
      releaseDate: releaseDate ?? DateTime.now(),
      voteAverage: rating ?? 0.0,
      genreIds: [], // No disponible en favoritos
      adult: false, // Valor por defecto
      video: false, // Valor por defecto
      originalLanguage: 'en', // Valor por defecto
      originalTitle: movieTitle,
      popularity: 0.0, // Valor por defecto
      voteCount: 0, // Valor por defecto
    );
  }

  @override
  String toString() {
    return 'FavoriteModel(id: $id, movieId: $movieId, title: $movieTitle)';
  }
}