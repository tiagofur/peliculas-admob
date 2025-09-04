import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/exceptions/sync_exceptions.dart';
import '../../core/logging/logger_factory.dart';
import '../../domain/datasources/local_storage_datasource.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/sync_models.dart';
import '../../domain/repositories/favorites_repository.dart';
import 'base_hybrid_repository.dart';

// Repositorio híbrido que maneja favoritos localmente y sincroniza con Supabase
class HybridFavoritesRepository extends BaseHybridRepository<SyncableFavorite>
    implements FavoritesRepository {
  HybridFavoritesRepository({
    required LocalStorageDatasource datasource,
    required super.ref,
  }) : _datasource = datasource;

  final LocalStorageDatasource _datasource;

  // Implements BaseHybridRepository abstract methods
  @override
  String get tableName => 'user_favorites';

  @override
  SyncableFavorite mapFromSupabase(Map<String, dynamic> data) {
    return SyncableFavorite(
      id: data['id'] ??
          '${data['user_id']}_${data['movie_id']}', // Usar UUID o generar ID
      userId: data['user_id'],
      movieId: data['movie_id'],
      traktId: null, // No usar Trakt ID
      movieTitle: data['movie_title'],
      moviePosterPath: data['movie_poster_path'],
      movieBackdropPath: data['movie_backdrop_path'],
      movieOverview: data['movie_overview'],
      movieReleaseDate: data['movie_release_date'] != null
          ? DateTime.parse(data['movie_release_date'])
          : null,
      movieVoteAverage: data['movie_vote_average']?.toDouble(),
      addedAt: DateTime.parse(data['added_at']),
      createdAt: DateTime.parse(data['added_at']),
      updatedAt: DateTime.parse(data['last_modified_at'] ?? data['updated_at'] ?? data['added_at']),
    );
  }

  @override
  Map<String, dynamic> mapToSupabase(SyncableFavorite favorite) {
    return {
      'user_id': favorite.userId,
      'movie_id': favorite.movieId,
      'movie_title': favorite.movieTitle,
      'movie_poster_path': favorite.moviePosterPath,
      'movie_backdrop_path': favorite.movieBackdropPath,
      'movie_overview': favorite.movieOverview,
      'movie_release_date':
          favorite.movieReleaseDate?.toIso8601String().split('T')[0],
      'movie_vote_average': favorite.movieVoteAverage,
      'added_at': favorite.addedAt.toIso8601String(),
      'is_deleted': false,
      'last_modified_at': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<void> clearRepositoryData() async {
    // Limpiar todas las películas favoritas una por una
    final allFavorites = await _datasource.loadMovies();
    for (final favorite in allFavorites) {
      await _datasource.toggleFavorite(favorite);
    }
  }

  // Implements FavoritesRepository interface
  @override
  Future<Map<int, Movie>> getFavoriteMovies() async {
    try {
      // Obtener datos locales
      final moviesList = await _datasource.loadMovies();
      return {for (var movie in moviesList) movie.id: movie};
    } catch (e) {
      throw LocalStorageException(
          'Error al cargar las películas favoritas: $e');
    }
  }

  @override
  Future<void> clearLocalData() async {
    await super.clearLocalData();
  }

  // Agregar/quitar película de favoritos
  @override
  Future<void> toggleFavorite(Movie movie) async {
    LoggerFactory.info('🎬 TOGGLE FAVORITE llamado para: ${movie.title}');

    try {
      // 1. Actualizar localmente primero (Local First)
      LoggerFactory.info('💾 Actualizando favorito localmente: ${movie.title}');
      await _datasource.toggleFavorite(movie);
      LoggerFactory.info('✅ Favorito actualizado localmente: ${movie.title}');
    } catch (e) {
      LoggerFactory.error('❌ Error al actualizar favorito localmente: $e');
      throw LocalStorageException('Error al cambiar el estado de favorito: $e');
    }

    // 2. Sincronización inmediata si el usuario está autenticado
    if (isAuthenticated()) {
      try {
        LoggerFactory.info('🔄 Iniciando sincronización inmediata...');
        await syncWithSupabase();
        LoggerFactory.info('✅ Sincronización inmediata completada');
      } catch (e) {
        LoggerFactory.warning('⚠️ Error en sincronización inmediata (continuará en background): $e');
        // No lanzamos error para no afectar UX, se reintentará después
      }
    } else {
      LoggerFactory.info('📝 Usuario no autenticado, cambio guardado localmente');
    }

    LoggerFactory.info('🏁 TOGGLE FAVORITE completado para: ${movie.title}');
  }

  // Verificar si una película es favorita
  @override
  Future<bool> isMovieFavorite(int movieId) async {
    // Siempre usar datos locales para respuesta inmediata
    try {
      return await _datasource.isMovieFavorite(movieId);
    } catch (e) {
      throw LocalStorageException(
          'Error al verificar si la película es favorita: $e');
    }
  }

  // Implementación de SyncableRepository
  @override
  Future<List<SyncableFavorite>> getLocalData() async {
    try {
      LoggerFactory.info('🔍 Obteniendo datos locales...');
      // Obtener TODAS las películas, no solo las primeras 10
      final moviesList = await _datasource.loadMovies(limit: 10000, offset: 0);
      LoggerFactory.info(
          '🔍 HiveDatasource retornó: ${moviesList.length} películas');

      final userId = getCurrentUserId();
      if (userId == null) {
        LoggerFactory.warning(
            '❌ No hay usuario para obtener datos locales de favoritos');
        return [];
      }
      LoggerFactory.info('🔍 Usuario actual: $userId');

      final localFavorites = moviesList
          .map((movie) => SyncableFavorite.fromMovie(
                userId: userId,
                movie: movie,
              ))
          .toList();

      LoggerFactory.info(
          '📱 Favoritos locales encontrados: ${localFavorites.length}');
      if (localFavorites.isNotEmpty) {
        LoggerFactory.info('📱 Primeros favoritos locales:');
        for (int i = 0; i < localFavorites.length.clamp(0, 3); i++) {
          final fav = localFavorites[i];
          LoggerFactory.info('   - ${fav.movieTitle} (ID: ${fav.movieId})');
        }
      }
      return localFavorites;
    } catch (e) {
      LoggerFactory.error('❌ Error obteniendo favoritos locales: $e');
      throw LocalStorageException(
          'Error al obtener los datos locales de favoritos: $e');
    }
  }

  @override
  Future<List<SyncableFavorite>> getRemoteData() async {
    final userId = getCurrentUserId();
    if (userId == null) {
      LoggerFactory.warning(
          '❌ No hay usuario para obtener datos remotos de favoritos');
      return [];
    }

    try {
      await checkOnline();
      LoggerFactory.info(
          '☁️ Obteniendo favoritos remotos para usuario: $userId');

      final response = await supabase
          .from('user_favorites')
          .select()
          .eq('user_id', userId)
          .eq('is_deleted', false) // ✅ Solo obtener favoritos activos (no eliminados)
          .order('added_at', ascending: false);

      final remoteFavorites =
          (response as List).map((data) => mapFromSupabase(data)).toList();
      LoggerFactory.info(
          '☁️ Favoritos remotos encontrados: ${remoteFavorites.length}');

      return remoteFavorites;
    } on PostgrestException catch (e) {
      LoggerFactory.error(
          '❌ Error PostgreSQL obteniendo favoritos remotos: ${e.message} (${e.code})');
      throw SupabaseSyncException(e.message, code: e.code);
    } catch (e) {
      LoggerFactory.error('❌ Error obteniendo favoritos remotos: $e');
      throw SupabaseSyncException('Error obteniendo favoritos remotos: $e');
    }
  }

  @override
  Future<void> upload(List<SyncableFavorite> favorites) async {
    LoggerFactory.info('⬆️ UPLOAD iniciado para ${favorites.length} favoritos');

    if (favorites.isEmpty) {
      LoggerFactory.info('⬆️ No hay favoritos para subir');
      return;
    }

    for (final favorite in favorites) {
      try {
        LoggerFactory.info(
            '⬆️ Subiendo ${favorite.movieTitle} (ID: ${favorite.movieId})...');

        await supabase
            .from('user_favorites')
            .upsert(mapToSupabase(favorite), onConflict: 'user_id,movie_id');

        LoggerFactory.info('✅ ${favorite.movieTitle} subido exitosamente');
      } on PostgrestException catch (e) {
        LoggerFactory.error(
            '❌ Error PostgreSQL subiendo ${favorite.movieTitle}: ${e.message}');
        throw SupabaseSyncException(
            'Error subiendo favorito ${favorite.movieTitle}: ${e.message}',
            code: e.code);
      } catch (e) {
        LoggerFactory.error(
            '❌ Error general subiendo ${favorite.movieTitle}: $e');
        throw SupabaseSyncException(
            'Error subiendo favorito ${favorite.movieTitle}: $e');
      }
    }

    LoggerFactory.info('🎉 Upload de ${favorites.length} favoritos completado');
  }

  @override
  Future<void> download(List<SyncableFavorite> favorites) async {
    for (final favorite in favorites) {
      try {
        final movie = favorite.toMovie();
        await _datasource.toggleFavorite(movie);
      } catch (e) {
        throw LocalStorageException(
            'Error descargando favorito ${favorite.id}: $e');
      }
    }
  }




  @override
  Future<void> syncWithRemote() async {
    try {
      await syncWithSupabase();
    } catch (e) {
      LoggerFactory.error('Error sincronizando favoritos: $e');
      rethrow;
    }
  }

  @override
  Future<List<SyncableFavorite>> resolveConflicts(
    List<SyncableFavorite> localItems,
    List<SyncableFavorite> remoteItems,
  ) async {
    // Usar estrategia de resolución de conflictos para favoritos
    // Por ahora, priorizar datos remotos más recientes
    final Map<String, SyncableFavorite> resolved = {};
    
    // Agregar todos los elementos locales
    for (final item in localItems) {
      resolved[item.id] = item;
    }
    
    // Sobrescribir con elementos remotos más recientes
    for (final item in remoteItems) {
      final existing = resolved[item.id];
      if (existing == null || item.updatedAt.isAfter(existing.updatedAt)) {
        resolved[item.id] = item;
      }
    }
    
    return resolved.values.toList();
  }
}