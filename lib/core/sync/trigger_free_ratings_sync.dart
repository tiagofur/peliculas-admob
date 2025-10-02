import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/user_movie_rating.dart';
import '../logging/logger_factory.dart';

/// Servicio de sincronización que evita completamente los triggers de PostgreSQL
/// usando operaciones directas INSERT/DELETE/UPDATE para ratings y comentarios
class TriggerFreeRatingsSync {
  TriggerFreeRatingsSync._internal();

  static final TriggerFreeRatingsSync _instance =
      TriggerFreeRatingsSync._internal();
  static TriggerFreeRatingsSync get instance => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obtiene todas las calificaciones del usuario
  Future<List<UserMovieRating>> getUserRatings(String userId) async {
    try {
      LoggerFactory.info('📥 [TriggerFreeRatings] Obteniendo ratings: $userId');

      final response = await _supabase
          .from('user_movie_ratings')
          .select('*')
          .eq('user_id', userId);

      final List<dynamic> data = response as List<dynamic>;
      final ratingsData = data.cast<Map<String, dynamic>>();

      final ratings =
          ratingsData.map((data) => UserMovieRating.fromJson(data)).toList();

      LoggerFactory.info(
          '✅ [TriggerFreeRatings] Encontradas ${ratings.length} calificaciones');

      return ratings;
    } catch (e) {
      LoggerFactory.error(
          '❌ [TriggerFreeRatings] Error obteniendo ratings: $e');
      return [];
    }
  }

  /// Obtiene una calificación específica por movie_id
  Future<UserMovieRating?> getUserRating(String userId, int movieId) async {
    try {
      LoggerFactory.debug(
          '🔍 [TriggerFreeRatings] Buscando rating para movie: $movieId');

      final response = await _supabase
          .from('user_movie_ratings')
          .select('*')
          .eq('user_id', userId)
          .eq('movie_id', movieId)
          .maybeSingle();

      if (response != null) {
        final rating = UserMovieRating.fromJson(response);
        LoggerFactory.debug(
            '✅ [TriggerFreeRatings] Rating encontrado: ${rating.rating}/10');
        return rating;
      }

      LoggerFactory.debug(
          '📭 [TriggerFreeRatings] No hay rating para movie: $movieId');
      return null;
    } catch (e) {
      LoggerFactory.error('❌ [TriggerFreeRatings] Error obteniendo rating: $e');
      return null;
    }
  }

  /// Crea o actualiza una calificación usando INSERT/UPDATE directo
  Future<UserMovieRating?> saveRating(
    String userId,
    int movieId,
    String movieTitle,
    double rating, {
    String? review,
    String? moviePosterPath,
  }) async {
    try {
      LoggerFactory.info(
          '💾 [TriggerFreeRatings] Guardando rating: $movieTitle ($rating/10)');

      final now = DateTime.now().toUtc().toIso8601String();

      // Verificar si ya existe un rating
      final existingRating = await getUserRating(userId, movieId);

      Map<String, dynamic> ratingData = {
        'user_id': userId,
        'movie_id': movieId,
        'movie_title': movieTitle,
        'movie_poster_path': moviePosterPath,
        'rating': rating,
        'review': review,
        'last_modified_at': now,
        'sync_version': 1,
      };

      if (existingRating != null) {
        // 🔧 FIXED: Actualizar rating existente con filtros específicos
        final response = await _supabase
            .from('user_movie_ratings')
            .update(ratingData)
            .eq('user_id', userId)
            .eq('movie_id', movieId)
            .select()
            .single();

        final updatedRating = UserMovieRating.fromJson(response);
        LoggerFactory.info(
            '✅ [TriggerFreeRatings] Rating actualizado: $movieTitle');
        return updatedRating;
      } else {
        // 🔧 FIXED: Crear nuevo rating
        ratingData['created_at'] = now;

        final response = await _supabase
            .from('user_movie_ratings')
            .insert(ratingData)
            .select()
            .single();

        final newRating = UserMovieRating.fromJson(response);
        LoggerFactory.info('✅ [TriggerFreeRatings] Rating creado: $movieTitle');
        return newRating;
      }
    } catch (e) {
      LoggerFactory.error('❌ [TriggerFreeRatings] Error guardando rating: $e');

      // 🔧 FIXED: Fallback para casos de error
      try {
        LoggerFactory.info('🔄 [TriggerFreeRatings] Intentando fallback...');
        return await _saveRatingFallback(userId, movieId, movieTitle, rating,
            review: review, moviePosterPath: moviePosterPath);
      } catch (e2) {
        LoggerFactory.error(
            '❌ [TriggerFreeRatings] Fallback también falló: $e2');
        return null;
      }
    }
  }

  /// Actualiza solo el comentario de un rating existente
  Future<UserMovieRating?> updateReview(
    String userId,
    int movieId,
    String? review,
  ) async {
    try {
      LoggerFactory.info(
          '📝 [TriggerFreeRatings] Actualizando comentario para movie: $movieId');

      final now = DateTime.now().toUtc().toIso8601String();

      final response = await _supabase
          .from('user_movie_ratings')
          .update({
            'review': review,
            'last_modified_at': now,
            'sync_version': 1,
          })
          .eq('user_id', userId)
          .eq('movie_id', movieId)
          .select()
          .single();

      final updatedRating = UserMovieRating.fromJson(response);
      LoggerFactory.info('✅ [TriggerFreeRatings] Comentario actualizado');
      return updatedRating;
    } catch (e) {
      LoggerFactory.error(
          '❌ [TriggerFreeRatings] Error actualizando comentario: $e');
      return null;
    }
  }

  /// Elimina un rating usando DELETE directo
  Future<void> deleteRating(String userId, int movieId) async {
    try {
      LoggerFactory.info(
          '🗑️ [TriggerFreeRatings] Eliminando rating para movie: $movieId');

      // 🔧 FIXED: DELETE específico por user_id y movie_id
      await _supabase
          .from('user_movie_ratings')
          .delete()
          .eq('user_id', userId)
          .eq('movie_id', movieId);

      LoggerFactory.info('✅ [TriggerFreeRatings] Rating eliminado');
    } catch (e) {
      LoggerFactory.error('❌ [TriggerFreeRatings] Error eliminando rating: $e');
      rethrow;
    }
  }

  /// Verifica si el usuario ha calificado una película
  Future<bool> hasUserRated(String userId, int movieId) async {
    try {
      final response = await _supabase
          .from('user_movie_ratings')
          .select('id')
          .eq('user_id', userId)
          .eq('movie_id', movieId)
          .limit(1);

      final List<dynamic> data = response as List<dynamic>;
      return data.isNotEmpty;
    } catch (e) {
      LoggerFactory.error(
          '❌ [TriggerFreeRatings] Error verificando rating: $e');
      return false;
    }
  }

  /// Obtiene estadísticas de ratings del usuario
  Future<Map<String, dynamic>> getUserRatingStats(String userId) async {
    try {
      LoggerFactory.info(
          '📊 [TriggerFreeRatings] Obteniendo estadísticas para: $userId');

      final ratings = await getUserRatings(userId);

      if (ratings.isEmpty) {
        return {
          'totalRatings': 0,
          'averageRating': 0.0,
          'highestRating': 0.0,
          'lowestRating': 0.0,
          'ratingsWithReview': 0,
          'recentRatingsCount': 0,
        };
      }

      final totalRatings = ratings.length;
      final averageRating =
          ratings.map((r) => r.rating).reduce((a, b) => a + b) / totalRatings;
      final highestRating =
          ratings.map((r) => r.rating).reduce((a, b) => a > b ? a : b);
      final lowestRating =
          ratings.map((r) => r.rating).reduce((a, b) => a < b ? a : b);
      final ratingsWithReview =
          ratings.where((r) => r.review != null && r.review!.isNotEmpty).length;

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentRatingsCount =
          ratings.where((r) => r.createdAt.isAfter(thirtyDaysAgo)).length;

      final stats = {
        'totalRatings': totalRatings,
        'averageRating': double.parse(averageRating.toStringAsFixed(1)),
        'highestRating': highestRating,
        'lowestRating': lowestRating,
        'ratingsWithReview': ratingsWithReview,
        'recentRatingsCount': recentRatingsCount,
      };

      LoggerFactory.info(
          '✅ [TriggerFreeRatings] Estadísticas calculadas: $stats');
      return stats;
    } catch (e) {
      LoggerFactory.error(
          '❌ [TriggerFreeRatings] Error obteniendo estadísticas: $e');
      return {
        'totalRatings': 0,
        'averageRating': 0.0,
        'highestRating': 0.0,
        'lowestRating': 0.0,
        'ratingsWithReview': 0,
        'recentRatingsCount': 0,
      };
    }
  }

  /// Busca ratings por título de película
  Future<List<UserMovieRating>> searchRatingsByTitle(
      String userId, String query) async {
    try {
      LoggerFactory.info(
          '🔍 [TriggerFreeRatings] Buscando ratings con query: "$query"');

      final response = await _supabase
          .from('user_movie_ratings')
          .select('*')
          .eq('user_id', userId)
          .ilike('movie_title', '%$query%');

      final List<dynamic> data = response as List<dynamic>;
      final ratingsData = data.cast<Map<String, dynamic>>();

      final ratings =
          ratingsData.map((data) => UserMovieRating.fromJson(data)).toList();

      LoggerFactory.info(
          '✅ [TriggerFreeRatings] Encontrados ${ratings.length} ratings con "$query"');
      return ratings;
    } catch (e) {
      LoggerFactory.error('❌ [TriggerFreeRatings] Error buscando ratings: $e');
      return [];
    }
  }

  /// Obtiene los ratings más recientes
  Future<List<UserMovieRating>> getRecentRatings(String userId,
      {int limit = 20}) async {
    try {
      final response = await _supabase
          .from('user_movie_ratings')
          .select('*')
          .eq('user_id', userId)
          .limit(limit);

      final List<dynamic> data = response as List<dynamic>;
      final ratingsData = data.cast<Map<String, dynamic>>();

      final ratings =
          ratingsData.map((data) => UserMovieRating.fromJson(data)).toList();

      LoggerFactory.info(
          '✅ [TriggerFreeRatings] ${ratings.length} ratings recientes obtenidos');
      return ratings;
    } catch (e) {
      LoggerFactory.error(
          '❌ [TriggerFreeRatings] Error obteniendo ratings recientes: $e');
      return [];
    }
  }

  /// Obtiene los ratings mejor calificados
  Future<List<UserMovieRating>> getTopRatedMovies(String userId,
      {int limit = 20}) async {
    try {
      final response = await _supabase
          .from('user_movie_ratings')
          .select('*')
          .eq('user_id', userId)
          .limit(limit);

      final List<dynamic> data = response as List<dynamic>;
      final ratingsData = data.cast<Map<String, dynamic>>();

      final ratings =
          ratingsData.map((data) => UserMovieRating.fromJson(data)).toList();

      LoggerFactory.info(
          '✅ [TriggerFreeRatings] ${ratings.length} top ratings obtenidos');
      return ratings;
    } catch (e) {
      LoggerFactory.error(
          '❌ [TriggerFreeRatings] Error obteniendo top ratings: $e');
      return [];
    }
  }

  /// Método fallback para casos de error
  Future<UserMovieRating?> _saveRatingFallback(
    String userId,
    int movieId,
    String movieTitle,
    double rating, {
    String? review,
    String? moviePosterPath,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final ratingData = {
      'user_id': userId,
      'movie_id': movieId,
      'movie_title': movieTitle,
      'movie_poster_path': moviePosterPath,
      'rating': rating,
      'review': review,
      'created_at': now,
      'last_modified_at': now,
      'sync_version': 1,
    };

    try {
      // Intentar INSERT primero
      final response = await _supabase
          .from('user_movie_ratings')
          .insert(ratingData)
          .select()
          .single();

      return UserMovieRating.fromJson(response);
    } catch (e) {
      if (e.toString().contains('duplicate') ||
          e.toString().contains('unique')) {
        // Si ya existe, hacer DELETE + INSERT
        await deleteRating(userId, movieId);

        final response = await _supabase
            .from('user_movie_ratings')
            .insert(ratingData)
            .select()
            .single();

        return UserMovieRating.fromJson(response);
      } else {
        rethrow;
      }
    }
  }

  /// Stream de cambios en tiempo real para todas las calificaciones del usuario
  Stream<List<UserMovieRating>> watchUserRatings(String userId) {
    try {
      LoggerFactory.info(
          '👀 [TriggerFreeRatings] Configurando stream en tiempo real para usuario: $userId');

      return _supabase
          .from('user_movie_ratings')
          .stream(primaryKey: ['id']).map((data) {
        // Filtrar en el lado de la aplicación ya que stream no soporta .eq()
        final filtered =
            data.where((item) => item['user_id'] == userId).toList();

        LoggerFactory.debug(
            '🔄 [TriggerFreeRatings] Real-time update recibido: ${filtered.length} ratings');
        return filtered.map((item) => UserMovieRating.fromJson(item)).toList();
      });
    } catch (e) {
      LoggerFactory.error(
          '❌ [TriggerFreeRatings] Error configurando stream: $e');
      return Stream.value([]);
    }
  }

  /// Stream de cambios en tiempo real para una calificación específica
  Stream<UserMovieRating?> watchMovieRating(String userId, int movieId) {
    try {
      LoggerFactory.debug(
          '👀 [TriggerFreeRatings] Configurando stream para movie: $movieId');

      return _supabase
          .from('user_movie_ratings')
          .stream(primaryKey: ['id']).map((data) {
        // Filtrar en el lado de la aplicación
        final filtered = data
            .where((item) =>
                item['user_id'] == userId && item['movie_id'] == movieId)
            .toList();

        if (filtered.isEmpty) {
          LoggerFactory.debug(
              '📭 [TriggerFreeRatings] No rating para movie $movieId');
          return null;
        }
        LoggerFactory.debug(
            '🔄 [TriggerFreeRatings] Rating actualizado para movie $movieId');
        return UserMovieRating.fromJson(filtered.first);
      });
    } catch (e) {
      LoggerFactory.error(
          '❌ [TriggerFreeRatings] Error configurando stream para movie: $e');
      return Stream.value(null);
    }
  }

  /// Test básico de conectividad y datos
  Future<bool> testConnection() async {
    try {
      LoggerFactory.info('🔗 [TriggerFreeRatings] Probando conexión...');

      // Query super simple sin filtros
      final response = await _supabase
          .from('user_movie_ratings')
          .select('id, user_id, movie_title, rating')
          .limit(5);

      final List<dynamic> data = response as List<dynamic>;

      LoggerFactory.info('✅ [TriggerFreeRatings] Conexión exitosa');
      LoggerFactory.info(
          '📊 [TriggerFreeRatings] Total ratings en tabla: ${data.length}');

      for (final item in data) {
        LoggerFactory.info(
            '  📌 Rating: ${item['movie_title']} - ${item['rating']}/10 (user: ${item['user_id']})');
      }

      return true;
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ [TriggerFreeRatings] Error de conexión: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
      return false;
    }
  }
}
