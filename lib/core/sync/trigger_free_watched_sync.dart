import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/movie.dart';
import '../logging/logger_factory.dart';

/// Servicio de sincronización que evita completamente los triggers de PostgreSQL
/// usando operaciones directas INSERT/DELETE en lugar de UPSERT
class TriggerFreeWatchedSync {
  TriggerFreeWatchedSync._internal();
  
  static final TriggerFreeWatchedSync _instance = TriggerFreeWatchedSync._internal();
  static TriggerFreeWatchedSync get instance => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obtener todas las películas vistas del usuario
  Future<List<Movie>> getUserWatchedMovies(String userId) async {
    try {
      LoggerFactory.info('🎬 [WatchedSync] Obteniendo películas vistas para usuario: $userId');

      final response = await _supabase
          .from('user_watched_movies')
          .select('*')
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false);

      LoggerFactory.info('🎬 [WatchedSync] Respuesta Supabase: ${response.length} películas vistas');

      final movies = <Movie>[];
      for (final item in response) {
        try {
          final movie = Movie(
            id: item['movie_id'] as int,
            title: item['movie_title'] as String,
            posterPath: item['movie_poster_path'] as String? ?? '',
            backdropPath: item['movie_backdrop_path'] as String? ?? '',
            overview: item['movie_overview'] as String? ?? '',
            releaseDate: item['movie_release_date'] != null
                ? (DateTime.tryParse(item['movie_release_date'] as String) ?? DateTime.now())
                : DateTime.now(),
            voteAverage: (item['movie_vote_average'] as num?)?.toDouble() ?? 0.0,
            genreIds: [],
            adult: false,
            originalLanguage: 'en',
            originalTitle: item['movie_title'] as String,
            popularity: 0.0,
            video: false,
            voteCount: 0,
          );
          movies.add(movie);
        } catch (e) {
          LoggerFactory.error('❌ [WatchedSync] Error procesando película vista: $e');
        }
      }

      LoggerFactory.info('✅ [WatchedSync] ${movies.length} películas vistas procesadas');
      return movies;
    } catch (e) {
      LoggerFactory.error('❌ [WatchedSync] Error obteniendo películas vistas: $e');
      return [];
    }
  }

  /// Añadir película vista usando INSERT directo (evita triggers)
  Future<void> addWatchedMovie(String userId, Movie movie) async {
    try {
      LoggerFactory.info('➕ [WatchedSync] Añadiendo película vista: ${movie.title}');

      // Usar INSERT directo para evitar triggers
      await _supabase.from('user_watched_movies').insert({
        'user_id': userId,
        'movie_id': movie.id,
        'movie_title': movie.title,
        'movie_poster_path': movie.posterPath,
        'movie_backdrop_path': movie.backdropPath,
        'movie_overview': movie.overview,
        'movie_release_date': movie.releaseDate.toIso8601String(),
        'movie_vote_average': movie.voteAverage,
        'is_deleted': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'last_modified_at': DateTime.now().toUtc().toIso8601String(),
      });

      LoggerFactory.info('✅ [WatchedSync] Película vista añadida correctamente: ${movie.title}');
    } catch (e) {
      LoggerFactory.error('❌ [WatchedSync] Error añadiendo película vista: $e');
      rethrow;
    }
  }

  /// Remover película vista usando DELETE directo (evita triggers)
  Future<void> removeWatchedMovie(String userId, int movieId) async {
    try {
      LoggerFactory.info('🗑️ [WatchedSync] Removiendo película vista: $movieId');

      // Usar DELETE directo para evitar triggers
      await _supabase
          .from('user_watched_movies')
          .delete()
          .eq('user_id', userId)
          .eq('movie_id', movieId);

      LoggerFactory.info('✅ [WatchedSync] Película vista removida correctamente: $movieId');
    } catch (e) {
      LoggerFactory.error('❌ [WatchedSync] Error removiendo película vista: $e');
      rethrow;
    }
  }

  /// Verificar si una película está marcada como vista
  Future<bool> isMovieWatched(String userId, int movieId) async {
    try {
      final response = await _supabase
          .from('user_watched_movies')
          .select('id')
          .eq('user_id', userId)
          .eq('movie_id', movieId)
          .eq('is_deleted', false)
          .maybeSingle();

      return response != null;
    } catch (e) {
      LoggerFactory.error('❌ [WatchedSync] Error verificando película vista: $e');
      return false;
    }
  }

  /// Sincronización manual de películas vistas
  Future<void> syncWatchedMovies(String userId) async {
    try {
      LoggerFactory.info('🔄 [WatchedSync] Iniciando sincronización manual...');
      
      final movies = await getUserWatchedMovies(userId);
      
      LoggerFactory.info('✅ [WatchedSync] Sincronización completada: ${movies.length} películas vistas');
    } catch (e) {
      LoggerFactory.error('❌ [WatchedSync] Error en sincronización: $e');
      rethrow;
    }
  }
}