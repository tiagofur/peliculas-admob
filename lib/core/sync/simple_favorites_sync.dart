import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logging/logger_factory.dart';
import '../../domain/entities/movie.dart';

/// Servicio de sincronización SIMPLE para favoritos
/// Solo para debugging y encontrar el problema de congelamiento
class SimpleFavoritesSync {
  SimpleFavoritesSync._internal();

  static final SimpleFavoritesSync _instance = SimpleFavoritesSync._internal();
  static SimpleFavoritesSync get instance => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isSyncing = false;

  /// Verifica la estructura de la tabla user_favorites
  Future<void> checkDatabaseStructure() async {
    try {
      LoggerFactory.info('🔍 Verificando estructura de la base de datos...');

      // Verificar si la tabla existe y obtener algunas filas
      final response =
          await _supabase.from('user_favorites').select('*').limit(1);

      LoggerFactory.info('✅ Tabla user_favorites existe');
      LoggerFactory.info('📊 Estructura ejemplo: $response');
    } catch (e) {
      LoggerFactory.error('❌ Error verificando estructura de BD: $e');
      rethrow;
    }
  }

  /// Obtiene favoritos del usuario de forma simple
  Future<List<Map<String, dynamic>>> getUserFavorites(String userId) async {
    try {
      LoggerFactory.info('📥 Obteniendo favoritos para usuario: $userId');

      final response = await _supabase
          .from('user_favorites')
          .select('*')
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .order('last_modified_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final favorites = data.cast<Map<String, dynamic>>();

      LoggerFactory.info('✅ Encontrados ${favorites.length} favoritos');

      // Log de los primeros favoritos para debug
      if (favorites.isNotEmpty && kDebugMode) {
        LoggerFactory.info('🎬 Primer favorito: ${favorites.first}');
      }

      return favorites;
    } catch (e) {
      LoggerFactory.error('❌ Error obteniendo favoritos: $e');
      rethrow;
    }
  }

  /// Agrega un favorito de forma simple
  Future<void> addFavorite(String userId, Movie movie) async {
    try {
      LoggerFactory.info('➕ Agregando favorito: ${movie.title}');

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
        'is_deleted': false,
        'sync_version': 1,
        'device_id': 'flutter_web_${DateTime.now().millisecondsSinceEpoch}',
        // Establecer manualmente last_modified_at para evitar que el trigger lo actualice
        'last_modified_at': now,
        'created_at': now,
      };

      // Usar INSERT en lugar de UPSERT para evitar trigger de UPDATE
      try {
        await _supabase.from('user_favorites').insert(favoriteData);
      } catch (e) {
        // Si ya existe, intentar con DELETE + INSERT
        if (e.toString().contains('duplicate key') ||
            e.toString().contains('unique constraint')) {
          await _supabase
              .from('user_favorites')
              .delete()
              .eq('user_id', userId)
              .eq('movie_id', movie.id);

          await _supabase.from('user_favorites').insert(favoriteData);
        } else {
          rethrow;
        }
      }

      LoggerFactory.info('✅ Favorito agregado exitosamente: ${movie.title}');
    } catch (e) {
      LoggerFactory.error('❌ Error agregando favorito: $e');
      rethrow;
    }
  }

  /// Remueve un favorito de forma simple (DELETE directo)
  Future<void> removeFavorite(String userId, int movieId) async {
    try {
      LoggerFactory.info('🗑️ Removiendo favorito con movieId: $movieId');

      // USAR DELETE DIRECTO para evitar problemas de trigger
      await _supabase
          .from('user_favorites')
          .delete()
          .eq('user_id', userId)
          .eq('movie_id', movieId);

      LoggerFactory.info('✅ Favorito removido exitosamente: $movieId');
    } catch (e) {
      LoggerFactory.error('❌ Error removiendo favorito: $e');
      rethrow;
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
          .eq('is_deleted', false)
          .limit(1);

      final List<dynamic> data = response as List<dynamic>;
      return data.isNotEmpty;
    } catch (e) {
      LoggerFactory.error('❌ Error verificando favorito: $e');
      return false;
    }
  }

  /// Sincronización simple sin bloquear UI
  Future<List<Movie>> performSimpleSync(String userId) async {
    if (_isSyncing) {
      LoggerFactory.info('🔄 Ya hay una sincronización en curso');
      return [];
    }

    _isSyncing = true;

    try {
      LoggerFactory.info('🔄 Iniciando sincronización simple para: $userId');

      // 1. Verificar estructura de BD
      await checkDatabaseStructure();

      // 2. Obtener favoritos
      final favoritesData = await getUserFavorites(userId);

      // 3. Convertir a objetos Movie
      final movies = favoritesData.map((data) => _dataToMovie(data)).toList();

      LoggerFactory.info(
          '✅ Sincronización completada: ${movies.length} favoritos');

      return movies;
    } catch (e) {
      LoggerFactory.error('❌ Error en sincronización simple: $e');
      return [];
    } finally {
      _isSyncing = false;
    }
  }

  /// Convierte data de BD a Movie
  Movie _dataToMovie(Map<String, dynamic> data) {
    return Movie(
      id: data['movie_id'] as int,
      title: data['movie_title'] as String,
      posterPath: data['movie_poster_path'] as String? ?? '',
      backdropPath: data['movie_backdrop_path'] as String? ?? '',
      overview: data['movie_overview'] as String? ?? '',
      releaseDate: data['movie_release_date'] != null
          ? (DateTime.tryParse(data['movie_release_date'] as String) ??
              DateTime.now())
          : DateTime.now(),
      voteAverage: (data['movie_vote_average'] as num?)?.toDouble() ?? 0.0,
      genreIds: [], // No disponible en favoritos
      adult: false,
      originalLanguage: 'en',
      originalTitle: data['movie_title'] as String,
      popularity: 0.0,
      video: false,
      voteCount: 0,
    );
  }

  /// Verifica si está sincronizando
  bool get isSyncing => _isSyncing;

  /// Test de conectividad básico
  Future<bool> testConnection() async {
    try {
      LoggerFactory.info('🔗 Probando conexión a Supabase...');

      await _supabase.from('user_favorites').select('count').limit(1);

      LoggerFactory.info('✅ Conexión a Supabase exitosa');
      return true;
    } catch (e) {
      LoggerFactory.error('❌ Error de conexión a Supabase: $e');
      return false;
    }
  }
}
