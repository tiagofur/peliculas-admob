import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logging/logger_factory.dart';
import '../../models/rating_helpfulness.dart';

/// Repositorio para manejar votos de utilidad de reseñas en Supabase
class SupabaseRatingHelpfulnessRepository {
  SupabaseRatingHelpfulnessRepository({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? Supabase.instance.client;
  final SupabaseClient _supabaseClient;

  /// Envía un voto de utilidad sobre una reseña
  /// Si el usuario ya votó, actualiza su voto existente
  Future<RatingHelpfulnessVote> submitVote({
    required String reviewId,
    required String userId,
    required bool isHelpful,
  }) async {
    try {
      LoggerFactory.info(
          'Enviando voto de utilidad: reviewId=$reviewId, userId=$userId, isHelpful=$isHelpful');

      // Intentar insertar nuevo voto o actualizar existente usando upsert
      final response = await _supabaseClient
          .from('rating_helpfulness_votes')
          .upsert({
            'review_id': reviewId,
            'voter_user_id': userId,
            'is_helpful': isHelpful,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'review_id,voter_user_id')
          .select()
          .single();

      final vote = RatingHelpfulnessVote.fromJson(response);
      LoggerFactory.info('Voto de utilidad enviado exitosamente: ${vote.id}');
      return vote;
    } catch (e, stackTrace) {
      LoggerFactory.error('Error al enviar voto de utilidad: $e',
          stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Obtiene el voto de un usuario específico para una reseña
  Future<RatingHelpfulnessVote?> getUserVote({
    required String reviewId,
    required String userId,
  }) async {
    try {
      LoggerFactory.info(
          'Obteniendo voto del usuario: reviewId=$reviewId, userId=$userId');

      final response = await _supabaseClient
          .from('rating_helpfulness_votes')
          .select()
          .eq('review_id', reviewId)
          .eq('voter_user_id', userId)
          .maybeSingle();

      if (response == null) {
        LoggerFactory.info('No se encontró voto del usuario');
        return null;
      }

      final vote = RatingHelpfulnessVote.fromJson(response);
      LoggerFactory.info('Voto del usuario encontrado: ${vote.id}');
      return vote;
    } catch (e, stackTrace) {
      LoggerFactory.error('Error al obtener voto del usuario: $e',
          stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Obtiene todos los votos de utilidad para una reseña
  Future<List<RatingHelpfulnessVote>> getVotesForReview(String reviewId) async {
    try {
      LoggerFactory.info('Obteniendo votos para reseña: reviewId=$reviewId');

      final response = await _supabaseClient
          .from('rating_helpfulness_votes')
          .select()
          .eq('review_id', reviewId)
          .order('created_at', ascending: true);

      final votes = (response as List)
          .map((json) => RatingHelpfulnessVote.fromJson(json))
          .toList();

      LoggerFactory.info('Encontrados ${votes.length} votos para la reseña');
      return votes;
    } catch (e, stackTrace) {
      LoggerFactory.error('Error al obtener votos para reseña: $e',
          stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Obtiene estadísticas de utilidad para una reseña
  Future<RatingHelpfulnessStats?> getStatsForReview(String reviewId) async {
    try {
      LoggerFactory.info(
          'Obteniendo estadísticas de utilidad: reviewId=$reviewId');

      final response = await _supabaseClient
          .from('rating_helpfulness_stats')
          .select()
          .eq('review_id', reviewId)
          .maybeSingle();

      if (response == null) {
        LoggerFactory.info('No se encontraron estadísticas para la reseña');
        return null;
      }

      final stats = RatingHelpfulnessStats.fromJson(response);
      LoggerFactory.info(
          'Estadísticas encontradas: ${stats.totalVotes} votos, score=${stats.helpfulnessScore}');
      return stats;
    } catch (e, stackTrace) {
      LoggerFactory.error('Error al obtener estadísticas de utilidad: $e',
          stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Obtiene estadísticas de utilidad para múltiples reseñas
  Future<Map<String, RatingHelpfulnessStats>> getStatsForMultipleReviews(
    List<String> reviewIds,
  ) async {
    try {
      LoggerFactory.info(
          'Obteniendo estadísticas para ${reviewIds.length} reseñas');

      if (reviewIds.isEmpty) {
        return {};
      }

      final response = await _supabaseClient
          .from('rating_helpfulness_stats')
          .select()
          .inFilter('review_id', reviewIds);

      final statsMap = <String, RatingHelpfulnessStats>{};
      for (final json in response as List) {
        final stats = RatingHelpfulnessStats.fromJson(json);
        statsMap[stats.reviewId] = stats;
      }

      LoggerFactory.info(
          'Encontradas estadísticas para ${statsMap.length} reseñas');
      return statsMap;
    } catch (e, stackTrace) {
      LoggerFactory.error('Error al obtener estadísticas múltiples: $e',
          stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Elimina un voto de utilidad
  Future<void> removeVote({
    required String reviewId,
    required String userId,
  }) async {
    try {
      LoggerFactory.info(
          'Eliminando voto de utilidad: reviewId=$reviewId, userId=$userId');

      await _supabaseClient
          .from('rating_helpfulness_votes')
          .delete()
          .eq('review_id', reviewId)
          .eq('voter_user_id', userId);

      LoggerFactory.info('Voto de utilidad eliminado exitosamente');
    } catch (e, stackTrace) {
      LoggerFactory.error('Error al eliminar voto de utilidad: $e',
          stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Obtiene las reseñas más útiles basadas en el score de utilidad
  Future<List<RatingHelpfulnessStats>> getMostHelpfulReviews({
    int limit = 50,
    double minScore = 0.6,
    int minVotes = 3,
  }) async {
    try {
      LoggerFactory.info(
          'Obteniendo reseñas más útiles: limit=$limit, minScore=$minScore, minVotes=$minVotes');

      final response = await _supabaseClient
          .from('rating_helpfulness_stats')
          .select()
          .gte('helpfulness_score', minScore)
          .gte('total_votes', minVotes)
          .order('helpfulness_score', ascending: false)
          .limit(limit);

      final stats = (response as List)
          .map((json) => RatingHelpfulnessStats.fromJson(json))
          .toList();

      LoggerFactory.info('Encontradas ${stats.length} reseñas útiles');
      return stats;
    } catch (e, stackTrace) {
      LoggerFactory.error('Error al obtener reseñas más útiles: $e',
          stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Obtiene estadísticas agregadas del sistema de utilidad
  Future<Map<String, dynamic>> getSystemStats() async {
    try {
      LoggerFactory.info('Obteniendo estadísticas del sistema de utilidad');

      // Obtener conteos básicos
      final votesCountResponse =
          await _supabaseClient.rpc('count_helpfulness_votes');
      final reviewsWithStatsResponse =
          await _supabaseClient.rpc('count_reviews_with_helpfulness_stats');

      // Obtener estadísticas de distribución
      final avgScoreResponse = await _supabaseClient
          .from('rating_helpfulness_stats')
          .select('helpfulness_score')
          .neq('total_votes', 0);

      final scores = (avgScoreResponse as List)
          .map((json) => json['helpfulness_score'] as double)
          .toList();

      final avgScore =
          scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;

      final stats = {
        'total_votes': votesCountResponse ?? 0,
        'reviews_with_stats': reviewsWithStatsResponse ?? 0,
        'average_helpfulness_score': avgScore,
        'score_distribution': _calculateScoreDistribution(scores),
      };

      LoggerFactory.info(
          'Estadísticas del sistema obtenidas: ${stats.keys.join(", ")}');
      return stats;
    } catch (e, stackTrace) {
      LoggerFactory.error('Error al obtener estadísticas del sistema: $e',
          stackTrace: stackTrace);
      // Retornar estadísticas vacías en caso de error
      return {
        'total_votes': 0,
        'reviews_with_stats': 0,
        'average_helpfulness_score': 0.0,
        'score_distribution': {},
      };
    }
  }

  /// Calcula la distribución de scores de utilidad
  Map<String, int> _calculateScoreDistribution(List<double> scores) {
    final distribution = <String, int>{
      '0.0-0.2': 0,
      '0.2-0.4': 0,
      '0.4-0.6': 0,
      '0.6-0.8': 0,
      '0.8-1.0': 0,
    };

    for (final score in scores) {
      if (score < 0.2) {
        distribution['0.0-0.2'] = (distribution['0.0-0.2'] ?? 0) + 1;
      } else if (score < 0.4) {
        distribution['0.2-0.4'] = (distribution['0.2-0.4'] ?? 0) + 1;
      } else if (score < 0.6) {
        distribution['0.4-0.6'] = (distribution['0.4-0.6'] ?? 0) + 1;
      } else if (score < 0.8) {
        distribution['0.6-0.8'] = (distribution['0.6-0.8'] ?? 0) + 1;
      } else {
        distribution['0.8-1.0'] = (distribution['0.8-1.0'] ?? 0) + 1;
      }
    }

    return distribution;
  }
}
