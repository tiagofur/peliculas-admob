import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/movie.dart';
import '../../presentation/providers/storage/direct_sync_provider.dart';
import '../logging/logger_factory.dart';

/// Servicio de sincronización que evita completamente los triggers de PostgreSQL
/// usando operaciones directas INSERT/DELETE en lugar de UPSERT
class TriggerFreeWatchedSync implements BaseSync {
  TriggerFreeWatchedSync._internal();

  static final TriggerFreeWatchedSync _instance =
      TriggerFreeWatchedSync._internal();
  static TriggerFreeWatchedSync get instance => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obtiene películas vistas del usuario (igual que favoritos)
  @override
  Future<List<Map<String, dynamic>>> getUserMovies(String userId) async {
    try {
      LoggerFactory.info(
          '📥 [TriggerFree] Obteniendo películas vistas: $userId');

      final response = await _supabase
          .from('user_watched')
          .select('*')
          .eq('user_id', userId)
          .order('watched_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final watchedMovies = data.cast<Map<String, dynamic>>();

      LoggerFactory.info(
          '✅ [TriggerFree] Encontradas ${watchedMovies.length} películas vistas');

      return watchedMovies;
    } catch (e) {
      LoggerFactory.error(
          '❌ [TriggerFree] Error obteniendo películas vistas: $e');
      return [];
    }
  }

  /// Añadir película vista usando upsert y fallback (igual que favoritos)
  @override
  Future<void> addMovie(String userId, Movie movie) async {
    try {
      LoggerFactory.info(
          '➕ [TriggerFree] Agregando película vista: ${movie.title}');

      final now = DateTime.now().toUtc().toIso8601String();

      // Usar upsert directo para evitar problemas con RPC (igual que favoritos)
      await _supabase.from('user_watched').upsert({
        'user_id': userId,
        'movie_id': movie.id,
        'movie_title': movie.title,
        'movie_poster_path': movie.posterPath,
        'movie_backdrop_path': movie.backdropPath,
        'movie_overview': movie.overview,
        'movie_release_date': movie.releaseDate.toIso8601String(),
        'movie_vote_average': movie.voteAverage,
        'watched_at': now,
        'last_modified_at': now,
        'is_deleted': false,
        'sync_version': 1,
      });

      LoggerFactory.info(
          '✅ [TriggerFree] Película vista agregada: ${movie.title}');
    } catch (e) {
      LoggerFactory.error('❌ [TriggerFree] Error agregando película vista: $e');

      // Fallback: intentar con método original (igual que favoritos)
      try {
        LoggerFactory.info('🔄 [TriggerFree] Intentando fallback...');
        await _addWatchedFallback(userId, movie);
      } catch (e2) {
        LoggerFactory.error('❌ [TriggerFree] Fallback también falló: $e2');
        rethrow;
      }
    }
  }

  /// Remueve una película vista usando DELETE directo (igual que favoritos)
  @override
  Future<void> removeMovie(String userId, int movieId) async {
    try {
      LoggerFactory.info(
          '🗑️ [TriggerFree] Removiendo película vista: $movieId para el usuario $userId');

      // DELETE no debería activar triggers UPDATE (igual que favoritos)
      await _supabase
          .from('user_watched')
          .delete()
          .eq('user_id', userId)
          .eq('movie_id', movieId);

      LoggerFactory.info('✅ [TriggerFree] Película vista removida: $movieId');
    } catch (e) {
      LoggerFactory.error(
          '❌ [TriggerFree] Error removiendo película vista: $e');
      rethrow;
    }
  }

  /// Fallback que usa el método básico sin campos problemáticos (igual que favoritos)
  Future<void> _addWatchedFallback(String userId, Movie movie) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final watchedData = {
      'user_id': userId,
      'movie_id': movie.id,
      'movie_title': movie.title,
      'movie_poster_path': movie.posterPath,
      'movie_backdrop_path': movie.backdropPath,
      'movie_overview': movie.overview,
      'movie_release_date': movie.releaseDate.toIso8601String(),
      'movie_vote_average': movie.voteAverage,
      'watched_at': now,
      'last_modified_at': now,
      'is_deleted': false,
      'sync_version': 1,
    };

    try {
      // Intentar INSERT primero
      await _supabase.from('user_watched').insert(watchedData);
    } catch (e) {
      if (e.toString().contains('duplicate') ||
          e.toString().contains('unique')) {
        // Si ya existe, hacer DELETE + INSERT
        await removeMovie(userId, movie.id);
        await _supabase.from('user_watched').insert(watchedData);
      } else {
        rethrow;
      }
    }
  }

  /// Verificar si una película está marcada como vista
  Future<bool> isMovieWatched(String userId, int movieId) async {
    try {
      final response = await _supabase
          .from('user_watched')
          .select('id')
          .eq('user_id', userId)
          .eq('movie_id', movieId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      LoggerFactory.error(
          '❌ [WatchedSync] Error verificando película vista: $e');
      return false;
    }
  }

  /// Test básico de conectividad (igual que favoritos)
  Future<bool> testConnection() async {
    try {
      LoggerFactory.info('🔗 [TriggerFree] Probando conexión...');

      await _supabase.from('user_watched').select('count').limit(1);

      LoggerFactory.info('✅ [TriggerFree] Conexión exitosa');
      return true;
    } catch (e) {
      LoggerFactory.error('❌ [TriggerFree] Error de conexión: $e');
      return false;
    }
  }
}
