import '../entities/movie.dart';
import '../entities/syncable_movie_rating.dart';

/// Repositorio abstracto para manejo de calificaciones de películas
abstract class MovieRatingsRepository {
  /// Califica una película
  Future<void> rateMovie({
    required Movie movie,
    required double rating,
    String? review,
    bool isPublic = false,
    List<String> tags = const [],
  });

  /// Actualiza una calificación existente
  Future<void> updateRating({
    required int movieId,
    required double rating,
    String? review,
    bool? isPublic,
    List<String>? tags,
  });

  /// Elimina una calificación
  Future<void> removeRating(int movieId);

  /// Obtiene la calificación del usuario para una película específica
  Future<SyncableMovieRating?> getUserRating(int movieId);

  /// Verifica si el usuario ya calificó una película
  Future<bool> hasUserRatedMovie(int movieId);

  /// Obtiene todas las calificaciones del usuario
  Future<List<SyncableMovieRating>> getUserRatings({
    int limit = 50,
    int offset = 0,
  });

  /// Obtiene calificaciones ordenadas por fecha
  Future<List<SyncableMovieRating>> getUserRatingsSorted({
    bool ascending = false,
    int limit = 50,
    int offset = 0,
  });

  /// Obtiene calificaciones filtradas por rating
  Future<List<SyncableMovieRating>> getUserRatingsByRating({
    double? minRating,
    double? maxRating,
    int limit = 50,
    int offset = 0,
  });

  /// Obtiene calificaciones que tienen reseña
  Future<List<SyncableMovieRating>> getUserRatingsWithReviews({
    int limit = 50,
    int offset = 0,
  });

  /// Obtiene calificaciones públicas
  Future<List<SyncableMovieRating>> getUserPublicRatings({
    int limit = 50,
    int offset = 0,
  });

  /// Obtiene estadísticas de calificaciones del usuario
  Future<Map<String, dynamic>> getUserRatingStats();

  /// Busca calificaciones por tags
  Future<List<SyncableMovieRating>> searchRatingsByTags({
    required List<String> tags,
    int limit = 50,
    int offset = 0,
  });

  /// Busca calificaciones por texto en reseña
  Future<List<SyncableMovieRating>> searchRatingsByReviewText({
    required String query,
    int limit = 50,
    int offset = 0,
  });

  /// Obtiene calificaciones recientes (último mes)
  Future<List<SyncableMovieRating>> getRecentRatings({
    int days = 30,
    int limit = 20,
  });

  /// Exporta todas las calificaciones del usuario
  Future<List<Map<String, dynamic>>> exportUserRatings();

  /// Importa calificaciones desde datos exportados
  Future<void> importUserRatings(List<Map<String, dynamic>> ratingsData);

  /// Stream de cambios en calificaciones (para real-time updates)
  Stream<List<SyncableMovieRating>> watchUserRatings();

  /// Stream de cambios en una calificación específica
  Stream<SyncableMovieRating?> watchUserRating(int movieId);

  /// Obtiene resumen de calificación de una película (todas las calificaciones públicas)
  Future<Map<String, dynamic>?> getMovieRatingSummary(int movieId);
}
