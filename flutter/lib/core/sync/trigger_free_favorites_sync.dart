import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/movie.dart';
import '../../presentation/providers/storage/direct_sync_provider.dart';
import '../logging/logger_factory.dart';

/// Servicio que evita completamente los triggers de PostgreSQL
/// usando operaciones SQL manuales que no activan triggers
class TriggerFreeFavoritesSync implements BaseSync {
  TriggerFreeFavoritesSync._internal();

  static final TriggerFreeFavoritesSync _instance =
      TriggerFreeFavoritesSync._internal();
  static TriggerFreeFavoritesSync get instance => _instance;

  SupabaseClient? _debugClient;

  SupabaseClient get _supabase => _debugClient ?? Supabase.instance.client;

  /// Testing seam: inject a fake client in unit tests.
  @visibleForTesting
  set debugClient(SupabaseClient client) => _debugClient = client;

  /// Agrega un favorito usando SQL manual para evitar triggers
  @override
  Future<void> addMovie(String userId, Movie movie) async {
    try {
      LoggerFactory.info('➕ [TriggerFree] Agregando favorito: ${movie.title}');

      final now = DateTime.now().toUtc().toIso8601String();

      // Usar upsert directo para evitar problemas con RPC.
      // onConflict es obligatorio: sin objetivo de conflicto el upsert
      // inserta duplicados en lugar de conciliar.
      await _supabase.from('user_favorites').upsert(
        {
          'user_id': userId,
          'movie_id': movie.id,
          'movie_title': movie.title,
          'movie_poster_path': movie.posterPath,
          'movie_backdrop_path': movie.backdropPath,
          'movie_overview': movie.overview,
          'movie_release_date': movie.releaseDate.toIso8601String(),
          'movie_vote_average': movie.voteAverage,
          'added_at': now,
          'last_modified_at': now,
          'is_deleted': false,
          'sync_version': 1,
        },
        onConflict: 'user_id,movie_id',
        ignoreDuplicates: false,
      );

      LoggerFactory.info('✅ [TriggerFree] Favorito agregado: ${movie.title}');
    } catch (e) {
      LoggerFactory.error('❌ [TriggerFree] Error agregando favorito: $e');

      // Fallback: intentar con método original pero sin sync_version
      try {
        LoggerFactory.info('🔄 [TriggerFree] Intentando fallback...');
        await _addFavoriteFallback(userId, movie);
      } catch (e2) {
        LoggerFactory.error('❌ [TriggerFree] Fallback también falló: $e2');
        rethrow;
      }
    }
  }

  /// Remueve un favorito usando DELETE directo
  @override
  Future<void> removeMovie(String userId, int movieId) async {
    try {
      LoggerFactory.info('🗑️ [TriggerFree] Removiendo favorito: $movieId');

      // DELETE no debería activar triggers UPDATE
      await _supabase
          .from('user_favorites')
          .delete()
          .eq('user_id', userId)
          .eq('movie_id', movieId);

      LoggerFactory.info('✅ [TriggerFree] Favorito removido: $movieId');
    } catch (e) {
      LoggerFactory.error('❌ [TriggerFree] Error removiendo favorito: $e');
      rethrow;
    }
  }

  /// Fallback que usa el método básico sin campos problemáticos
  Future<void> _addFavoriteFallback(String userId, Movie movie) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final favoriteData = {
      'user_id': userId,
      'movie_id': movie.id,
      'movie_title': movie.title,
      'movie_poster_path': movie.posterPath,
      'movie_backdrop_path': movie.backdropPath,
      'movie_overview': movie.overview,
      'movie_release_date': movie.releaseDate.toIso8601String(),
      'movie_vote_average': movie.voteAverage,
      'added_at': now,
      'last_modified_at': now,
      'is_deleted': false,
      'sync_version': 1,
    };

    try {
      // Intentar INSERT primero
      await _supabase.from('user_favorites').insert(favoriteData);
    } catch (e) {
      if (e.toString().contains('duplicate') ||
          e.toString().contains('unique')) {
        // Si ya existe, hacer DELETE + INSERT
        await removeMovie(userId, movie.id);
        await _supabase.from('user_favorites').insert(favoriteData);
      } else {
        rethrow;
      }
    }
  }

  /// Obtiene favoritos del usuario
  @override
  Future<List<Map<String, dynamic>>> getUserMovies(String userId) async {
    try {
      LoggerFactory.info('📥 [TriggerFree] Obteniendo favoritos: $userId');

      final response = await _supabase
          .from('user_favorites')
          .select('*')
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .order('added_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final favorites = data.cast<Map<String, dynamic>>();

      LoggerFactory.info(
          '✅ [TriggerFree] Encontrados ${favorites.length} favoritos');

      return favorites;
    } catch (e) {
      LoggerFactory.error('❌ [TriggerFree] Error obteniendo favoritos: $e');
      return [];
    }
  }

  /// Verifica si una película es favorita
  Future<bool> isFavorite(String userId, int movieId) async {
    try {
      final response = await _supabase
          .from('user_favorites')
          .select('id')
          .eq('user_id', userId)
          .eq('movie_id', movieId)
          .limit(1);

      final List<dynamic> data = response as List<dynamic>;
      return data.isNotEmpty;
    } catch (e) {
      LoggerFactory.error('❌ [TriggerFree] Error verificando favorito: $e');
      return false;
    }
  }

  /// Test básico de conectividad
  Future<bool> testConnection() async {
    try {
      LoggerFactory.info('🔗 [TriggerFree] Probando conexión...');

      await _supabase.from('user_favorites').select('count').limit(1);

      LoggerFactory.info('✅ [TriggerFree] Conexión exitosa');
      return true;
    } catch (e) {
      LoggerFactory.error('❌ [TriggerFree] Error de conexión: $e');
      return false;
    }
  }
}
