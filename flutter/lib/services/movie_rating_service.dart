import 'dart:async';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logging/logger_factory.dart';
import '../domain/entities/movie.dart';
import '../domain/entities/movie_rating.dart';
import '../domain/repositories/movie_ratings_repository.dart';
import '../models/rating_helpfulness.dart';
import '../infrastructure/repositories/supabase_rating_helpfulness_repository.dart';

/// Servicio integral para manejo de calificaciones y reseñas de películas
class MovieRatingService {
  MovieRatingService._();

  static final MovieRatingService _instance = MovieRatingService._();
  static MovieRatingService get instance => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;
  final SupabaseRatingHelpfulnessRepository _helpfulnessRepo =
      SupabaseRatingHelpfulnessRepository();

  /// Califica una película con reseña opcional
  Future<MovieRating> submitRating({
    required String userId,
    required int movieId,
    required double rating,
    String? review,
    bool containsSpoilers = false,
    required MovieRatingsRepository repository,
  }) async {
    try {
      LoggerFactory.info(
          '🌟 Submitting rating for movie $movieId: $rating stars');

      // Validaciones
      if (!_isValidRating(rating)) {
        throw Exception('La calificación debe estar entre 1.0 y 5.0');
      }

      if (review != null && !_isValidReview(review)) {
        throw Exception('La reseña contiene contenido no válido');
      }

      // Crear la calificación
      final movieRating = MovieRating.create(
        userId: userId,
        movieId: movieId,
        rating: rating,
        review: review,
        containsSpoilers: containsSpoilers,
      );

      // Guardar usando el repositorio existente (adaptación)
      await repository.rateMovie(
        movie: Movie(
          id: movieId,
          title: '', // Se obtendrá después si es necesario
          overview: '',
          posterPath: '',
          backdropPath: '',
          releaseDate: DateTime.now(),
          genreIds: [],
          originalTitle: '',
          originalLanguage: '',
          popularity: 0,
          voteCount: 0,
          video: false,
          voteAverage: 0,
          adult: false,
        ),
        rating: rating,
        review: review,
        isPublic: true, // Las reseñas son públicas por defecto
      );

      LoggerFactory.info('✅ Rating submitted successfully');
      return movieRating;
    } catch (e) {
      LoggerFactory.error('❌ Failed to submit rating: $e');
      rethrow;
    }
  }

  /// Actualiza una calificación existente
  Future<MovieRating> updateRating({
    required String ratingId,
    required String userId,
    required int movieId,
    double? newRating,
    String? newReview,
    bool? containsSpoilers,
    required MovieRatingsRepository repository,
  }) async {
    try {
      LoggerFactory.info('📝 Updating rating $ratingId for movie $movieId');

      // Obtener la calificación existente
      final existingRating = await repository.getUserRating(movieId);
      if (existingRating == null) {
        throw Exception('No se encontró la calificación a actualizar');
      }

      // Validaciones
      if (newRating != null && !_isValidRating(newRating)) {
        throw Exception('La calificación debe estar entre 1.0 y 5.0');
      }

      if (newReview != null && !_isValidReview(newReview)) {
        throw Exception('La reseña contiene contenido no válido');
      }

      // Actualizar usando el repositorio
      await repository.updateRating(
        movieId: movieId,
        rating: newRating ?? existingRating.rating,
        review: newReview ?? existingRating.review,
      );

      // Crear la entidad actualizada (simulada)
      final updatedRating = MovieRating(
        id: ratingId,
        userId: userId,
        movieId: movieId,
        rating: newRating ?? existingRating.rating,
        review: newReview ?? existingRating.review,
        createdAt: existingRating.createdAt,
        updatedAt: DateTime.now(),
        containsSpoilers: containsSpoilers ?? false,
      );

      LoggerFactory.info('✅ Rating updated successfully');
      return updatedRating;
    } catch (e) {
      LoggerFactory.error('❌ Failed to update rating: $e');
      rethrow;
    }
  }

  /// Elimina una calificación
  Future<void> deleteRating({
    required int movieId,
    required MovieRatingsRepository repository,
  }) async {
    try {
      LoggerFactory.info('🗑️ Deleting rating for movie $movieId');

      await repository.removeRating(movieId);

      LoggerFactory.info('✅ Rating deleted successfully');
    } catch (e) {
      LoggerFactory.error('❌ Failed to delete rating: $e');
      rethrow;
    }
  }

  /// Obtiene la calificación del usuario para una película
  Future<MovieRating?> getUserRating({
    required int movieId,
    required MovieRatingsRepository repository,
  }) async {
    try {
      final syncableRating = await repository.getUserRating(movieId);
      if (syncableRating == null) return null;

      // Convertir de SyncableMovieRating a MovieRating
      return MovieRating(
        id: syncableRating.id,
        userId: syncableRating.userId,
        movieId: syncableRating.movieId,
        rating: syncableRating.rating,
        review: syncableRating.review,
        createdAt: syncableRating.createdAt,
        updatedAt: syncableRating.lastModifiedAt,
      );
    } catch (e) {
      LoggerFactory.error('❌ Failed to get user rating: $e');
      return null;
    }
  }

  /// Obtiene estadísticas de calificación de una película
  Future<MovieRatingStats> getMovieRatingStats({
    required int movieId,
    required MovieRatingsRepository repository,
  }) async {
    try {
      LoggerFactory.info('📊 Getting rating stats for movie $movieId');

      final summary = await repository.getMovieRatingSummary(movieId);
      if (summary == null) {
        return MovieRatingStats.empty();
      }

      return MovieRatingStats(
        averageRating: (summary['average_rating'] as num?)?.toDouble() ?? 0.0,
        totalRatings: (summary['total_ratings'] as int?) ?? 0,
        ratingDistribution: Map<int, int>.from(summary['distribution'] ?? {}),
        reviewsCount: (summary['reviews_count'] as int?) ?? 0,
      );
    } catch (e) {
      LoggerFactory.error('❌ Failed to get movie rating stats: $e');
      return MovieRatingStats.empty();
    }
  }

  /// Busca reseñas por texto
  Future<List<MovieRating>> searchReviews({
    required String query,
    required MovieRatingsRepository repository,
    int limit = 20,
  }) async {
    try {
      LoggerFactory.info('🔍 Searching reviews for: "$query"');

      final syncableRatings = await repository.searchRatingsByReviewText(
        query: query,
        limit: limit,
      );

      return syncableRatings
          .map((syncableRating) => MovieRating(
                id: syncableRating.id,
                userId: syncableRating.userId,
                movieId: syncableRating.movieId,
                rating: syncableRating.rating,
                review: syncableRating.review,
                createdAt: syncableRating.createdAt,
                updatedAt: syncableRating.lastModifiedAt,
              ))
          .toList();
    } catch (e) {
      LoggerFactory.error('❌ Failed to search reviews: $e');
      return [];
    }
  }

  /// Marca una reseña como útil o no útil
  Future<RatingHelpfulnessVote> markReviewHelpfulness({
    required String ratingId,
    required bool isHelpful,
    required String currentUserId,
  }) async {
    try {
      LoggerFactory.info(
          '👍 Marking review $ratingId as ${isHelpful ? 'helpful' : 'not helpful'}');

      // Enviar voto usando el repositorio de helpfulness
      final vote = await _helpfulnessRepo.submitVote(
        reviewId: ratingId,
        userId: currentUserId,
        isHelpful: isHelpful,
      );

      LoggerFactory.info('✅ Review helpfulness updated: ${vote.id}');
      return vote;
    } catch (e) {
      LoggerFactory.error('❌ Failed to update review helpfulness: $e');
      rethrow;
    }
  }

  /// Obtiene el voto de utilidad de un usuario para una reseña
  Future<RatingHelpfulnessVote?> getUserHelpfulnessVote({
    required String ratingId,
    required String userId,
  }) async {
    try {
      LoggerFactory.info(
          '🗳️ Getting user helpfulness vote for review $ratingId');

      final vote = await _helpfulnessRepo.getUserVote(
        reviewId: ratingId,
        userId: userId,
      );

      if (vote != null) {
        LoggerFactory.info(
            '✅ User vote found: ${vote.isHelpful ? 'helpful' : 'not helpful'}');
      } else {
        LoggerFactory.info('ℹ️ No user vote found');
      }

      return vote;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get user helpfulness vote: $e');
      rethrow;
    }
  }

  /// Obtiene estadísticas de utilidad para una reseña
  Future<RatingHelpfulnessStats?> getReviewHelpfulnessStats({
    required String ratingId,
  }) async {
    try {
      LoggerFactory.info('📊 Getting helpfulness stats for review $ratingId');

      final stats = await _helpfulnessRepo.getStatsForReview(ratingId);

      if (stats != null) {
        LoggerFactory.info(
            '✅ Helpfulness stats found: ${stats.totalVotes} votes, score=${stats.helpfulnessScore}');
      } else {
        LoggerFactory.info('ℹ️ No helpfulness stats found');
      }

      return stats;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get helpfulness stats: $e');
      rethrow;
    }
  }

  /// Obtiene estadísticas de utilidad para múltiples reseñas
  Future<Map<String, RatingHelpfulnessStats>>
      getMultipleReviewsHelpfulnessStats({
    required List<String> ratingIds,
  }) async {
    try {
      LoggerFactory.info(
          '📊 Getting helpfulness stats for ${ratingIds.length} reviews');

      final statsMap =
          await _helpfulnessRepo.getStatsForMultipleReviews(ratingIds);

      LoggerFactory.info(
          '✅ Helpfulness stats retrieved for ${statsMap.length} reviews');
      return statsMap;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get multiple helpfulness stats: $e');
      rethrow;
    }
  }

  /// Reporta una reseña por contenido inapropiado
  Future<void> reportReview({
    required String ratingId,
    required String reason,
    required String reporterUserId,
  }) async {
    try {
      LoggerFactory.info('🚨 Reporting review $ratingId for: $reason');

      // Validar parámetros
      if (ratingId.isEmpty || reason.isEmpty || reporterUserId.isEmpty) {
        throw Exception(
            'Todos los parámetros son requeridos para reportar una reseña');
      }

      // Llamar a la función de Supabase para enviar el reporte
      final response = await _supabase.rpc(
        'submit_rating_report',
        params: {
          'p_rating_id': ratingId,
          'p_reporter_user_id': reporterUserId,
          'p_reason': reason,
        },
      );

      // La función devuelve un JSON con status y message
      if (response is Map<String, dynamic>) {
        final status = response['status'] as String?;
        final message = response['message'] as String?;

        if (status == 'success') {
          LoggerFactory.info('✅ Review reported successfully: $message');
        } else {
          LoggerFactory.warning('⚠️ Report not submitted: $message');
          throw Exception(message ?? 'Error al procesar el reporte');
        }
      } else {
        LoggerFactory.error(
            '❌ Unexpected response format from report function');
        throw Exception('Error en el formato de respuesta del servidor');
      }
    } catch (e) {
      LoggerFactory.error('❌ Failed to report review: $e');
      rethrow;
    }
  }

  /// Obtiene reseñas destacadas (mejor calificadas y más útiles)
  Future<List<MovieRating>> getFeaturedReviews({
    required int movieId,
    required MovieRatingsRepository repository,
    int limit = 5,
  }) async {
    try {
      LoggerFactory.info('⭐ Getting featured reviews for movie $movieId');

      // Obtener calificaciones con reseñas
      final syncableRatings = await repository.searchRatingsByReviewText(
        query: '', // Query vacío para obtener todas las reseñas
        limit: limit * 2, // Obtener más para poder filtrar
      );

      // Filtrar solo las que tienen reseñas y ordenar por criterios
      final ratingsWithReviews = syncableRatings
          .where((rating) =>
              rating.movieId == movieId &&
              rating.review != null &&
              rating.review!.trim().isNotEmpty)
          .map((syncableRating) => MovieRating(
                id: syncableRating.id,
                userId: syncableRating.userId,
                movieId: syncableRating.movieId,
                rating: syncableRating.rating,
                review: syncableRating.review,
                createdAt: syncableRating.createdAt,
                updatedAt: syncableRating.lastModifiedAt,
              ))
          .toList();

      // Ordenar por calidad (rating alto + reseña larga = mejor)
      ratingsWithReviews.sort((a, b) {
        final scoreA = _calculateReviewQualityScore(a);
        final scoreB = _calculateReviewQualityScore(b);
        return scoreB.compareTo(scoreA);
      });

      return ratingsWithReviews.take(limit).toList();
    } catch (e) {
      LoggerFactory.error('❌ Failed to get featured reviews: $e');
      return [];
    }
  }

  /// Calcula un score de calidad para una reseña
  double _calculateReviewQualityScore(MovieRating rating) {
    double score = 0.0;

    // Factor de rating (ratings altos son mejores)
    score += rating.rating * 20;

    // Factor de longitud de reseña (reseñas más largas suelen ser mejores)
    if (rating.hasReview) {
      final reviewLength = rating.review!.length;
      score += min(reviewLength / 50, 20); // Máximo 20 puntos por longitud
    }

    // Factor de utilidad (si está disponible)
    score += rating.helpfulnessScore * 30;

    // Penalización por spoilers (opcional)
    if (rating.containsSpoilers) {
      score *= 0.8;
    }

    return score;
  }

  /// Valida si una calificación está en el rango válido
  bool _isValidRating(double rating) {
    return rating >= 1.0 && rating <= 5.0;
  }

  /// Valida si una reseña es válida (no vacía, no spam, etc.)
  bool _isValidReview(String review) {
    final cleanReview = review.trim();

    // Revisar longitud mínima
    if (cleanReview.length < 10) {
      return false;
    }

    // Revisar longitud máxima
    if (cleanReview.length > 5000) {
      return false;
    }

    // Revisar por patrones de spam (básico)
    final spamPatterns = [
      RegExp(r'(.)\1{4,}'), // Caracteres repetidos
      RegExp(r'http[s]?://'), // URLs
      RegExp(r'www\.'), // URLs
      RegExp(r'[A-Z]{10,}'), // Mayúsculas excesivas
    ];

    for (final pattern in spamPatterns) {
      if (pattern.hasMatch(cleanReview)) {
        return false;
      }
    }

    return true;
  }

  /// Genera estadísticas del usuario sobre sus calificaciones
  Future<UserRatingStats> getUserRatingStatistics({
    required String userId,
    required MovieRatingsRepository repository,
  }) async {
    try {
      LoggerFactory.info('📈 Getting user rating statistics for $userId');

      final stats = await repository.getUserRatingStats();

      return UserRatingStats(
        totalRatings: stats['total_ratings'] ?? 0,
        averageRating: (stats['average_rating'] as num?)?.toDouble() ?? 0.0,
        reviewsCount: stats['reviews_count'] ?? 0,
        favoriteGenres: List<String>.from(stats['favorite_genres'] ?? []),
        ratingDistribution:
            Map<int, int>.from(stats['rating_distribution'] ?? {}),
        mostActiveMonth: stats['most_active_month'] as String?,
        totalWatchTime: stats['total_watch_time'] ?? 0,
      );
    } catch (e) {
      LoggerFactory.error('❌ Failed to get user rating statistics: $e');
      return UserRatingStats.empty();
    }
  }
}

/// Estadísticas de calificación de una película específica
class MovieRatingStats {
  const MovieRatingStats({
    required this.averageRating,
    required this.totalRatings,
    required this.ratingDistribution,
    required this.reviewsCount,
  });

  factory MovieRatingStats.empty() {
    return const MovieRatingStats(
      averageRating: 0.0,
      totalRatings: 0,
      ratingDistribution: {},
      reviewsCount: 0,
    );
  }
  final double averageRating;
  final int totalRatings;
  final Map<int, int> ratingDistribution;
  final int reviewsCount;

  /// Obtiene el porcentaje de cada rating
  Map<int, double> get ratingPercentages {
    if (totalRatings == 0) return {};

    return ratingDistribution
        .map((rating, count) => MapEntry(rating, (count / totalRatings) * 100));
  }

  /// Indica si hay suficientes calificaciones para mostrar estadísticas confiables
  bool get hasReliableStats => totalRatings >= 5;
}

/// Estadísticas del usuario sobre sus calificaciones
class UserRatingStats {
  // En minutos

  const UserRatingStats({
    required this.totalRatings,
    required this.averageRating,
    required this.reviewsCount,
    required this.favoriteGenres,
    required this.ratingDistribution,
    this.mostActiveMonth,
    required this.totalWatchTime,
  });

  factory UserRatingStats.empty() {
    return const UserRatingStats(
      totalRatings: 0,
      averageRating: 0.0,
      reviewsCount: 0,
      favoriteGenres: [],
      ratingDistribution: {},
      totalWatchTime: 0,
    );
  }
  final int totalRatings;
  final double averageRating;
  final int reviewsCount;
  final List<String> favoriteGenres;
  final Map<int, int> ratingDistribution;
  final String? mostActiveMonth;
  final int totalWatchTime;

  /// Porcentaje de películas que el usuario ha reseñado
  double get reviewPercentage {
    if (totalRatings == 0) return 0.0;
    return (reviewsCount / totalRatings) * 100;
  }

  /// Total de horas vistas
  double get totalWatchHours => totalWatchTime / 60.0;

  /// Indica si el usuario es activo (ha calificado al menos 10 películas)
  bool get isActiveUser => totalRatings >= 10;
}
