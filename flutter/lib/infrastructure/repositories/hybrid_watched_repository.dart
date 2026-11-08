import 'dart:async';

import '../../core/logging/logger_factory.dart';
import '../../core/sync/entity_sync_manager.dart';
import '../../core/sync/unified_watched_sync.dart';
import '../../core/sync/watched_sync_manager.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/syncable_watched_movie.dart';
import '../../domain/entities/watched_movie.dart';
import '../../domain/repositories/watched_movies_repository.dart';
import '../datasources/watched_movies_hive_datasource.dart';
import 'base_hybrid_repository.dart';

/// Repositorio híbrido para películas vistas que combina almacenamiento local y remoto
/// con sincronización automática usando el sistema unificado
class HybridWatchedRepository extends BaseHybridRepository<SyncableWatchedMovie>
    implements WatchedMoviesRepository {
  HybridWatchedRepository({
    required super.userId,
    EntitySyncManager<SyncableWatchedMovie>? syncManager,
    super.syncCoordinator,
  })  : _localDatasource = WatchedMoviesHiveDatasource(),
        _unifiedSync = UnifiedWatchedSync.instance,
        super(
          entityType: 'watched_movie',
          syncManager: syncManager ?? WatchedSyncManager(userId: userId),
        );

  final WatchedMoviesHiveDatasource _localDatasource;
  final UnifiedWatchedSync _unifiedSync;

  // =============================================
  // IMPLEMENTACIÓN DE MÉTODOS ABSTRACTOS
  // =============================================

  @override
  String get tableName => 'user_watched';

  @override
  SyncableWatchedMovie deserializeFromRemote(Map<String, dynamic> data) {
    return SyncableWatchedMovie.fromJson(data);
  }

  @override
  Future<void> initializeLocal() async {
    // La inicialización de Hive es manejada por el datasource
    LoggerFactory.info('✅ HybridWatchedRepository local storage initialized');
  }

  @override
  Future<List<SyncableWatchedMovie>> getLocalData() async {
    try {
      final watchedMovies =
          await _localDatasource.loadWatchedMovies(limit: 10000);
      return watchedMovies
          .map((watched) => SyncableWatchedMovie.fromWatchedMovie(
                userId: userId,
                watchedMovie: watched,
              ))
          .toList();
    } catch (e) {
      LoggerFactory.error('❌ Failed to get local watched movies: $e');
      return [];
    }
  }

  @override
  Future<void> saveToLocal(SyncableWatchedMovie entity) async {
    try {
      final watchedMovie = entity.toWatchedMovie();
      await _localDatasource.markAsWatched(watchedMovie.movie);
      LoggerFactory.debug('💾 Saved watched movie locally: ${entity.movieId}');
    } catch (e) {
      LoggerFactory.error('❌ Failed to save watched movie locally: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeFromLocal(String id) async {
    try {
      // El ID de la entidad syncable no es el movie_id, necesitamos encontrarlo
      final localMovies = await getLocalData();

      // Try to find by syncable ID first
      SyncableWatchedMovie? movieToRemove;
      try {
        movieToRemove = localMovies.firstWhere((e) => e.id == id);
      } catch (e) {
        // If not found by syncable ID, try to parse as movie ID
        final movieId = int.tryParse(id);
        if (movieId != null) {
          movieToRemove =
              localMovies.where((e) => e.movieId == movieId).firstOrNull;
        }
      }

      if (movieToRemove != null) {
        await _localDatasource.removeFromWatched(movieToRemove.movieId);
        LoggerFactory.debug(
            '🗑️ Removed watched movie from local storage: $id (movieId: ${movieToRemove.movieId})');
      } else {
        LoggerFactory.warning('⚠️ Movie not found locally for removal: $id');
        // Don't throw error - movie might already be removed
      }
    } catch (e) {
      LoggerFactory.error('❌ Failed to remove watched movie locally: $e');
      // Don't rethrow - we want to be resilient to local data inconsistencies
    }
  }

  @override
  Future<void> updateLocal(SyncableWatchedMovie entity) async {
    // Hive no tiene un `update` directo, re-guardar funciona
    await saveToLocal(entity);
  }

  @override
  SyncableWatchedMovie convertToModel(SyncableWatchedMovie entity) {
    return entity;
  }

  @override
  SyncableWatchedMovie convertFromModel(dynamic model, String userId) {
    if (model is SyncableWatchedMovie) {
      return model;
    } else if (model is WatchedMovie) {
      return SyncableWatchedMovie.fromWatchedMovie(
          userId: userId, watchedMovie: model);
    } else {
      throw ArgumentError(
          'Model must be a SyncableWatchedMovie or WatchedMovie, got ${model.runtimeType}');
    }
  }

  // =============================================
  // MÉTODOS ESPECÍFICOS PARA PELÍCULAS VISTAS
  // =============================================

  @override
  Future<bool> isMovieWatched(int movieId) async {
    try {
      return await _localDatasource.isMovieWatched(movieId);
    } catch (e) {
      LoggerFactory.error('❌ Failed to check if movie is watched: $e');
      return false;
    }
  }

  Future<SyncableWatchedMovie?> getWatchedMovieByMovieId(int movieId) async {
    try {
      final watchedMovies = await getLocalData();
      final matches = watchedMovies.where((movie) => movie.movieId == movieId);
      return matches.isNotEmpty ? matches.first : null;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get watched movie by movie ID: $e');
      return null;
    }
  }

  @override
  Future<void> markAsWatched(Movie movie) async {
    try {
      // ✅ USAR EL SISTEMA UNIFICADO
      final isCurrentlyWatched = await isMovieWatched(movie.id);

      if (isCurrentlyWatched) {
        LoggerFactory.info('ℹ️ Movie ${movie.id} is already marked as watched');
        return;
      }

      LoggerFactory.info(
          '🔄 HybridWatched: Marcando ${movie.title} como vista');

      // Actualizar local primero (optimistic update)
      await _localDatasource.markAsWatched(movie);

      // Sincronizar con Supabase usando el sistema unificado
      await _unifiedSync.addOrUpdateItem(userId, movie, {
        'watched_at': DateTime.now().toUtc().toIso8601String(),
      });

      LoggerFactory.info(
          '✅ HybridWatched: Marcado exitosamente ${movie.title}');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ HybridWatched: Error marcando como vista: $e');
      LoggerFactory.error('Stack trace: $stackTrace');

      // Revertir cambio local en caso de error
      await _localDatasource.removeFromWatched(movie.id);
      rethrow;
    }
  }

  @override
  Future<void> removeFromWatched(int movieId) async {
    try {
      // ✅ USAR EL SISTEMA UNIFICADO
      final watchedMovie = await getWatchedMovieByMovieId(movieId);
      if (watchedMovie == null) {
        LoggerFactory.info('ℹ️ Movie $movieId was not marked as watched');
        return;
      }

      LoggerFactory.info('� HybridWatched: Removiendo película $movieId');

      // Actualizar local primero (optimistic update)
      await _localDatasource.removeFromWatched(movieId);

      // Sincronizar con Supabase usando el sistema unificado
      await _unifiedSync.removeItem(userId, movieId);

      LoggerFactory.info(
          '✅ HybridWatched: Película $movieId removida exitosamente');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ HybridWatched: Error removiendo película: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<List<WatchedMovie>> loadWatchedMovies(
      {int limit = 10, int offset = 0}) async {
    return await _localDatasource.loadWatchedMovies(
        limit: limit, offset: offset);
  }

  Future<void> updateWatchedMovie({
    required int movieId,
    double? rating,
    String? review,
  }) async {
    try {
      final watchedMovie = await getWatchedMovieByMovieId(movieId);
      if (watchedMovie == null) {
        throw Exception('Movie $movieId is not marked as watched');
      }

      LoggerFactory.info('📝 HybridWatched: Actualizando película $movieId');

      final movie = watchedMovie.toMovie();

      // Sincronizar con Supabase usando el sistema unificado
      await _unifiedSync.addOrUpdateItem(userId, movie, {
        'personal_rating': rating,
        'personal_notes': review,
        'watched_at': watchedMovie.watchedDate.toIso8601String(),
      });

      LoggerFactory.info('✅ HybridWatched: Película $movieId actualizada');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ HybridWatched: Error actualizando película: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Sincronización completa con Supabase
  Future<void> syncWithRemote() async {
    try {
      LoggerFactory.info('🔄 HybridWatched: Iniciando sync con Supabase...');

      // ✅ USAR EL SISTEMA UNIFICADO PARA SINCRONIZAR
      final remoteData = await _unifiedSync.getUserItems(userId);
      final localWatchedMovies =
          await _localDatasource.loadWatchedMovies(limit: 1000, offset: 0);

      // Crear mapas para comparación rápida
      final remoteIds = remoteData.map((d) => d['movie_id'] as int).toSet();
      final localIds = localWatchedMovies.map((w) => w.movie.id).toSet();

      LoggerFactory.info(
          '� HybridWatched: Local=${localIds.length}, Remote=${remoteIds.length}');

      // Agregar películas remotas que no están localmente
      int addedCount = 0;
      for (final data in remoteData) {
        final movieId = data['movie_id'] as int;
        if (!localIds.contains(movieId)) {
          final watched = _unifiedSync.supabaseDataToEntity(data);
          await _localDatasource.markAsWatched(watched.toMovie());
          addedCount++;
        }
      }

      // Subir películas locales que no están en remoto
      final toUpload = localWatchedMovies
          .where((w) => !remoteIds.contains(w.movie.id))
          .map((w) => w.movie)
          .toList();
      if (toUpload.isNotEmpty) {
        LoggerFactory.info(
            '📤 HybridWatched: Subiendo ${toUpload.length} películas locales');
        await _unifiedSync.batchSync(userId, toUpload);
      }

      // Eliminar locales que no están en remoto
      int removedCount = 0;
      for (final movieId in localIds) {
        if (!remoteIds.contains(movieId)) {
          await _localDatasource.removeFromWatched(movieId);
          removedCount++;
        }
      }

      LoggerFactory.info(
          '✅ HybridWatched: Sync completado (agregados: $addedCount, eliminados: $removedCount, subidos: ${toUpload.length})');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ HybridWatched: Error en sync: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<SyncableWatchedMovie>> getWatchedMoviesSorted(
      {bool ascending = false}) async {
    try {
      final watchedMovies = await getLocalData();
      final sortedMovies = watchedMovies.toList();

      sortedMovies.sort((a, b) {
        final comparison = a.watchedDate.compareTo(b.watchedDate);
        return ascending ? comparison : -comparison;
      });

      return sortedMovies;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get sorted watched movies: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getWatchedStats() async {
    try {
      final watchedMovies = await getLocalData();

      final totalWatched = watchedMovies.length;
      final moviesWithRating =
          watchedMovies.where((m) => m.personalRating != null).toList();
      final averageRating = moviesWithRating.isNotEmpty
          ? moviesWithRating
                  .map((m) => m.personalRating!)
                  .reduce((a, b) => a + b) /
              moviesWithRating.length
          : 0.0;

      final moviesWithReview = watchedMovies
          .where((m) => m.personalNotes != null && m.personalNotes!.isNotEmpty)
          .length;

      return {
        'totalWatched': totalWatched,
        'averageRating': averageRating,
        'moviesWithRating': moviesWithRating.length,
        'moviesWithReview': moviesWithReview,
      };
    } catch (e) {
      LoggerFactory.error('❌ Failed to get watched stats: $e');
      return {
        'totalWatched': 0,
        'averageRating': 0.0,
        'moviesWithRating': 0,
        'moviesWithReview': 0,
      };
    }
  }
}
