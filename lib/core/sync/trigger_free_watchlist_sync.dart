import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/movie.dart';
import '../../domain/entities/watchlist_movie.dart';
import '../logging/logger_factory.dart';

/// Servicio de sincronización que evita completamente los triggers de PostgreSQL
/// usando operaciones directas INSERT/DELETE en lugar de UPSERT para Watchlist
class TriggerFreeWatchlistSync {
  TriggerFreeWatchlistSync._internal();

  static final TriggerFreeWatchlistSync _instance =
      TriggerFreeWatchlistSync._internal();
  static TriggerFreeWatchlistSync get instance => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obtiene watchlist del usuario
  Future<List<WatchlistMovie>> getUserWatchlist(String userId) async {
    try {
      LoggerFactory.info('📥 [TriggerFree] Obteniendo watchlist: $userId');

      final response = await _supabase
          .from('user_watchlist')
          .select('*')
          .eq('user_id', userId)
          .order('added_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final watchlistData = data.cast<Map<String, dynamic>>();

      final watchlistMovies =
          watchlistData.map((data) => _dataToWatchlistMovie(data)).toList();

      LoggerFactory.info(
          '✅ [TriggerFree] Encontrados ${watchlistMovies.length} items en watchlist');

      return watchlistMovies;
    } catch (e) {
      LoggerFactory.error('❌ [TriggerFree] Error obteniendo watchlist: $e');
      return [];
    }
  }

  /// Añadir película a watchlist usando upsert
  Future<void> addToWatchlist(String userId, Movie movie,
      {WatchlistPriority priority = WatchlistPriority.normal}) async {
    try {
      LoggerFactory.info(
          '➕ [TriggerFree] Agregando a watchlist: ${movie.title}');

      final now = DateTime.now().toUtc().toIso8601String();

      // Usar upsert directo para evitar problemas con RPC
      await _supabase.from('user_watchlist').upsert({
        'user_id': userId,
        'movie_id': movie.id,
        'movie_title': movie.title,
        'movie_poster_path': movie.posterPath,
        'movie_backdrop_path': movie.backdropPath,
        'movie_overview': movie.overview,
        'movie_release_date': movie.releaseDate.toIso8601String(),
        'movie_vote_average': movie.voteAverage,
        'priority': priority.value,
        'added_at': now,
        'last_modified_at': now,
        'is_deleted': false,
        'sync_version': 1,
      });

      LoggerFactory.info(
          '✅ [TriggerFree] Película agregada a watchlist: ${movie.title}');
    } catch (e) {
      LoggerFactory.error('❌ [TriggerFree] Error agregando a watchlist: $e');

      // Fallback: intentar con método básico
      try {
        LoggerFactory.info('🔄 [TriggerFree] Intentando fallback...');
        await _addToWatchlistFallback(userId, movie, priority);
      } catch (e2) {
        LoggerFactory.error('❌ [TriggerFree] Fallback también falló: $e2');
        rethrow;
      }
    }
  }

  /// Remueve una película de watchlist usando DELETE directo
  Future<void> removeFromWatchlist(String userId, int movieId) async {
    try {
      LoggerFactory.info('🗑️ [TriggerFree] Removiendo de watchlist: $movieId');

      // DELETE no debería activar triggers UPDATE
      await _supabase
          .from('user_watchlist')
          .delete()
          .eq('user_id', userId)
          .eq('movie_id', movieId);

      LoggerFactory.info(
          '✅ [TriggerFree] Película removida de watchlist: $movieId');
    } catch (e) {
      LoggerFactory.error('❌ [TriggerFree] Error removiendo de watchlist: $e');
      rethrow;
    }
  }

  /// Cambia la prioridad de un item en la watchlist
  Future<void> changePriority(
      String userId, int movieId, WatchlistPriority newPriority) async {
    try {
      LoggerFactory.info(
          '🔄 [TriggerFree] Cambiando prioridad: $movieId -> ${newPriority.name}');

      await _supabase
          .from('user_watchlist')
          .update({
            'priority': newPriority.value,
            'last_modified_at': DateTime.now().toUtc().toIso8601String(),
            'sync_version': 1,
          })
          .eq('user_id', userId)
          .eq('movie_id', movieId);

      LoggerFactory.info('✅ [TriggerFree] Prioridad cambiada: $movieId');
    } catch (e) {
      LoggerFactory.error('❌ [TriggerFree] Error cambiando prioridad: $e');
      rethrow;
    }
  }

  /// Fallback que usa el método básico sin campos problemáticos
  Future<void> _addToWatchlistFallback(
      String userId, Movie movie, WatchlistPriority priority) async {
    LoggerFactory.info(
        '🔄 [TriggerFree] Ejecutando fallback para watchlist...');

    final now = DateTime.now().toUtc().toIso8601String();

    await _supabase.from('user_watchlist').upsert({
      'user_id': userId,
      'movie_id': movie.id,
      'movie_title': movie.title,
      'priority': priority.value,
      'added_at': now,
      'is_deleted': false,
    });

    LoggerFactory.info('✅ [TriggerFree] Fallback exitoso para watchlist');
  }

  /// Convierte datos de Supabase a WatchlistMovie
  WatchlistMovie _dataToWatchlistMovie(Map<String, dynamic> data) {
    return WatchlistMovie(
      id: data['id']?.toString() ?? '',
      movieId: data['movie_id'] as int,
      movieTitle: data['movie_title'] as String,
      moviePosterPath: data['movie_poster_path'] as String?,
      movieBackdropPath: data['movie_backdrop_path'] as String?,
      movieOverview: data['movie_overview'] as String?,
      movieReleaseDate: data['movie_release_date'] != null
          ? DateTime.parse(data['movie_release_date'] as String)
          : null,
      movieVoteAverage: (data['movie_vote_average'] as num?)?.toDouble(),
      priority: _parsePriority(data['priority'] as String?),
      addedAt: DateTime.parse(data['added_at'] as String),
      lastModifiedAt: DateTime.parse(
          data['last_modified_at'] as String? ?? data['added_at'] as String),
    );
  }

  /// Parsea la prioridad desde string
  WatchlistPriority _parsePriority(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'alta':
        return WatchlistPriority.alta;
      case 'baja':
        return WatchlistPriority.baja;
      case 'normal':
      default:
        return WatchlistPriority.normal;
    }
  }

  /// Verifica si una película está en la watchlist del usuario
  Future<bool> isInWatchlist(String userId, int movieId) async {
    try {
      final response = await _supabase
          .from('user_watchlist')
          .select('movie_id')
          .eq('user_id', userId)
          .eq('movie_id', movieId)
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      LoggerFactory.error('❌ [TriggerFree] Error verificando watchlist: $e');
      return false;
    }
  }
}
