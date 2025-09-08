import 'dart:async';

import '../../core/logging/logger_factory.dart';
import '../../core/sync/entity_sync_manager.dart';
import '../../core/sync/watched_sync_manager.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/syncable_watched_movie.dart';
import '../../domain/entities/watched_movie.dart';
import '../../domain/repositories/watched_movies_repository.dart';
import '../datasources/watched_movies_hive_datasource.dart';
import 'base_hybrid_repository.dart';

/// Repositorio híbrido para películas vistas que combina almacenamiento local y remoto
/// con sincronización automática usando el sistema de sync de Fase 3
class HybridWatchedRepository extends BaseHybridRepository<SyncableWatchedMovie>
    implements WatchedMoviesRepository {
  HybridWatchedRepository({
    required super.userId,
    EntitySyncManager<SyncableWatchedMovie>? syncManager,
    super.syncCoordinator,
  })  : _localDatasource = WatchedMoviesHiveDatasource(),
        super(
          entityType: 'watched_movie',
          syncManager: syncManager ?? WatchedSyncManager(userId: userId),
        );

  final WatchedMoviesHiveDatasource _localDatasource;

  // =============================================
  // IMPLEMENTACIÓN DE MÉTODOS ABSTRACTOS
  // =============================================

  @override
  String get tableName => 'user_watched_movies';

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
          movieToRemove = localMovies.where((e) => e.movieId == movieId).firstOrNull;
        }
      }
      
      if (movieToRemove != null) {
        await _localDatasource.removeFromWatched(movieToRemove.movieId);
        LoggerFactory.debug('🗑️ Removed watched movie from local storage: $id (movieId: ${movieToRemove.movieId})');
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
      final existing = await isMovieWatched(movie.id);
      if (existing) {
        LoggerFactory.info('ℹ️ Movie ${movie.id} is already marked as watched');
        return;
      }

      final watchedMovie = SyncableWatchedMovie.fromMovie(
        userId: userId,
        movie: movie,
      );

      await add(watchedMovie);
      LoggerFactory.info('✅ Marked movie as watched: ${movie.id}');
    } catch (e) {
      LoggerFactory.error('❌ Failed to mark movie as watched: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeFromWatched(int movieId) async {
    try {
      final watchedMovie = await getWatchedMovieByMovieId(movieId);
      if (watchedMovie != null) {
        await remove(watchedMovie.id);
        LoggerFactory.info('🗑️ Unmarked movie as watched: $movieId');
      } else {
        LoggerFactory.info('ℹ️ Movie $movieId was not marked as watched');
      }
    } catch (e) {
      LoggerFactory.error('❌ Failed to unmark movie as watched: $e');
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

      final updatedMovie = watchedMovie.copyWithData(
        personalRating: rating,
        personalNotes: review,
        lastModifiedAt: DateTime.now(),
      );

      await update(updatedMovie);
      LoggerFactory.info('📝 Updated watched movie: $movieId');
    } catch (e) {
      LoggerFactory.error('❌ Failed to update watched movie: $e');
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
