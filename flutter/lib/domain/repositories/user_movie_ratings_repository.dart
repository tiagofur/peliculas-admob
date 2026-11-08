import '../entities/user_movie_rating.dart';

abstract class UserMovieRatingsRepository {
  /// Obtiene la valoración de una película por el usuario actual
  Future<UserMovieRating?> getUserRating(int movieId);

  /// Obtiene todas las valoraciones del usuario actual
  Future<List<UserMovieRating>> getUserRatings({
    int? limit,
    int? offset,
    String? orderBy, // 'rating', 'created_at', 'movie_title'
    bool ascending = false,
  });

  /// Guarda o actualiza una valoración de película
  Future<UserMovieRating> saveRating(UserMovieRating rating);

  /// Elimina una valoración de película
  Future<void> deleteRating(int movieId);

  /// Obtiene estadísticas de valoraciones del usuario
  Future<Map<String, dynamic>> getRatingStats();

  /// Obtiene las mejores películas valoradas por el usuario
  Future<List<UserMovieRating>> getTopRatedMovies({int limit = 10});

  /// Obtiene las valoraciones más recientes del usuario
  Future<List<UserMovieRating>> getRecentRatings({int limit = 10});

  /// Busca valoraciones por título de película
  Future<List<UserMovieRating>> searchRatingsByTitle(String query);
}
