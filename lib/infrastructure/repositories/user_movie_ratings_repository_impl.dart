import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/services/logger_factory.dart';
import '../../domain/entities/user_movie_rating.dart';
import '../../domain/repositories/user_movie_ratings_repository.dart';

class UserMovieRatingsRepositoryImpl implements UserMovieRatingsRepository {
  final SupabaseClient _supabase = SupabaseConfig.client;
  static const String _tableName = 'user_movie_ratings';

  @override
  Future<UserMovieRating?> getUserRating(int movieId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return null; // Return null instead of throwing when not authenticated
    }

    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('user_id', user.id)
          .eq('movie_id', movieId)
          .maybeSingle();

      return response != null ? UserMovieRating.fromJson(response) : null;
    } catch (e) {
      // Log error but don't throw to prevent UI crashes
      LoggerFactory.error('Error getting user rating: $e', tag: 'UserMovieRatingsRepository');
      return null;
    }
  }

  @override
  Future<List<UserMovieRating>> getUserRatings({
    int? limit,
    int? offset,
    String? orderBy,
    bool ascending = false,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return []; // Return empty list instead of throwing

    try {
      PostgrestTransformBuilder<PostgrestList> query =
          _supabase.from(_tableName).select().eq('user_id', user.id);

      // Aplicar ordenamiento
      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      } else {
        query = query.order('created_at', ascending: false);
      }

      // Aplicar límite y offset
      if (limit != null) {
        query = query.limit(limit);
      }
      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 50) - 1);
      }

      final response = await query;

      return response
          .map<UserMovieRating>((json) => UserMovieRating.fromJson(json))
          .toList();
    } catch (e) {
      LoggerFactory.error('Error getting user ratings: $e', tag: 'UserMovieRatingsRepository');
      return [];
    }
  }

  @override
  Future<UserMovieRating> saveRating(UserMovieRating rating) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Verificar si ya existe una valoración para esta película
      final existingRating = await getUserRating(rating.movieId);

      if (existingRating != null) {
        // Actualizar valoración existente
        final response = await _supabase
            .from(_tableName)
            .update(rating.toSupabaseUpdate())
            .eq('user_id', user.id)
            .eq('movie_id', rating.movieId)
            .select()
            .single();

        return UserMovieRating.fromJson(response);
      } else {
        // Crear nueva valoración
        final response = await _supabase
            .from(_tableName)
            .insert({
              ...rating.toSupabaseInsert(),
              'user_id': user.id,
            })
            .select()
            .single();

        return UserMovieRating.fromJson(response);
      }
    } catch (e) {
      LoggerFactory.error('Error saving rating: $e', tag: 'UserMovieRatingsRepository');
      rethrow; // Re-throw so UI can handle the error
    }
  }

  @override
  Future<void> deleteRating(int movieId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _supabase
        .from(_tableName)
        .delete()
        .eq('user_id', user.id)
        .eq('movie_id', movieId);
  }

  @override
  Future<Map<String, dynamic>> getRatingStats() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Calcular estadísticas localmente
    final ratings = await getUserRatings();

    if (ratings.isEmpty) {
      return {
        'total_ratings': 0,
        'average_rating': 0.0,
        'rating_distribution': <int, int>{},
        'most_rated_rating': null,
      };
    }

    final totalRatings = ratings.length;
    final averageRating =
        ratings.map((r) => r.rating).reduce((a, b) => a + b) / totalRatings;

    // Calcular distribución de ratings
    final distribution = <int, int>{};
    for (int i = 1; i <= 5; i++) {
      distribution[i] = ratings.where((r) => r.rating == i).length;
    }

    // Rating más frecuente
    final mostRatedRating =
        distribution.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    return {
      'total_ratings': totalRatings,
      'average_rating': averageRating,
      'rating_distribution': distribution,
      'most_rated_rating': mostRatedRating,
    };
  }

  @override
  Future<List<UserMovieRating>> getTopRatedMovies({int limit = 10}) async {
    return getUserRatings(
      limit: limit,
      orderBy: 'rating',
      ascending: false,
    );
  }

  @override
  Future<List<UserMovieRating>> getRecentRatings({int limit = 10}) async {
    return getUserRatings(
      limit: limit,
      orderBy: 'created_at',
      ascending: false,
    );
  }

  @override
  Future<List<UserMovieRating>> searchRatingsByTitle(String query) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from(_tableName)
        .select()
        .eq('user_id', user.id)
        .ilike('movie_title', '%$query%')
        .order('created_at', ascending: false);

    return response
        .map<UserMovieRating>((json) => UserMovieRating.fromJson(json))
        .toList();
  }
}
