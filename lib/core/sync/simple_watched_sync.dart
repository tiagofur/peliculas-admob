import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/movie.dart';
import '../logging/logger_factory.dart';

/// Servicio de sincronización SIMPLE para películas vistas
/// Funciona igual que SimpleFavoritesSync pero para user_watched_movies
class SimpleWatchedSync {
  SimpleWatchedSync._internal();

  static final SimpleWatchedSync _instance = SimpleWatchedSync._internal();
  static SimpleWatchedSync get instance => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isSyncing = false;

  /// Verifica la estructura de la tabla user_watched_movies
  Future<void> checkDatabaseStructure() async {
    try {
      LoggerFactory.info('🔍 Verificando estructura de user_watched_movies...');

      // Verificar si la tabla existe y obtener algunas filas
      final response =
          await _supabase.from('user_watched_movies').select('*').limit(1);

      LoggerFactory.info('✅ Tabla user_watched_movies existe');
      LoggerFactory.info('📊 Estructura ejemplo: $response');
    } catch (e) {
      LoggerFactory.error(
          '❌ Error verificando estructura de BD para watched: $e');
      rethrow;
    }
  }

  /// Obtiene películas vistas del usuario
  Future<List<Map<String, dynamic>>> getUserWatchedMovies(String userId) async {
    try {
      LoggerFactory.info(
          '📥 Obteniendo películas vistas para usuario: $userId');

      final response = await _supabase
          .from('user_watched_movies')
          .select('*')
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .order('last_modified_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final watchedMovies = data.cast<Map<String, dynamic>>();

      LoggerFactory.info(
          '✅ Obtenidas ${watchedMovies.length} películas vistas');
      return watchedMovies;
    } catch (e) {
      LoggerFactory.error('❌ Error obteniendo películas vistas: $e');
      rethrow;
    }
  }

  /// Añade una película como vista
  Future<void> addWatchedMovie(String userId, Movie movie) async {
    try {
      LoggerFactory.info('➕ Añadiendo película vista: ${movie.title}');

      final watchedData = {
        'user_id': userId,
        'movie_id': movie.id,
        'movie_title': movie.title,
        'movie_poster_path': movie.posterPath,
        'movie_backdrop_path': movie.backdropPath,
        'movie_overview': movie.overview,
        'movie_release_date': movie.releaseDate.toIso8601String(),
        'movie_vote_average': movie.voteAverage,
        'watched_at': DateTime.now().toIso8601String(),
        'last_modified_at': DateTime.now().toIso8601String(),
        'is_deleted': false,
        'sync_version': 1,
      };

      await _supabase
          .from('user_watched_movies')
          .upsert(watchedData, onConflict: 'user_id,movie_id');

      LoggerFactory.info(
          '✅ Película vista añadida exitosamente: ${movie.title}');
    } catch (e) {
      LoggerFactory.error('❌ Error añadiendo película vista: $e');
      rethrow;
    }
  }

  /// Remueve una película vista (soft delete)
  Future<void> removeWatchedMovie(String userId, int movieId) async {
    try {
      LoggerFactory.info('🗑️ Removiendo película vista con movieId: $movieId');

      await _supabase
          .from('user_watched_movies')
          .update({
            'is_deleted': true,
            'last_modified_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('movie_id', movieId);

      LoggerFactory.info('✅ Película vista removida exitosamente: $movieId');
    } catch (e) {
      LoggerFactory.error('❌ Error removiendo película vista: $e');
      rethrow;
    }
  }

  /// Verifica si una película está vista
  Future<bool> isWatched(String userId, int movieId) async {
    try {
      final response = await _supabase
          .from('user_watched_movies')
          .select('id')
          .eq('user_id', userId)
          .eq('movie_id', movieId)
          .eq('is_deleted', false)
          .limit(1);

      final List<dynamic> data = response as List<dynamic>;
      return data.isNotEmpty;
    } catch (e) {
      LoggerFactory.error('❌ Error verificando película vista: $e');
      return false;
    }
  }

  /// Sincronización simple de películas vistas
  Future<List<Movie>> performSimpleSync(String userId) async {
    if (_isSyncing) {
      LoggerFactory.info('🔄 Ya hay una sincronización de watched en curso');
      return [];
    }

    _isSyncing = true;

    try {
      LoggerFactory.info(
          '🔄 Iniciando sincronización de watched para: $userId');

      // 1. Verificar estructura de BD
      await checkDatabaseStructure();

      // 2. Obtener películas vistas
      final watchedData = await getUserWatchedMovies(userId);

      // 3. Convertir a objetos Movie
      final movies = watchedData.map((data) => _dataToMovie(data)).toList();

      LoggerFactory.info(
          '✅ Sync de watched completado: ${movies.length} películas');

      return movies;
    } catch (e) {
      LoggerFactory.error('❌ Error en sync de watched: $e');
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
      genreIds: [], // No disponible en watched
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
}
