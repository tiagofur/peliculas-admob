import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/logger_factory.dart';
import '../../core/sync/entity_sync_manager.dart';
import '../../core/sync/watched_sync_manager.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/syncable_watched_movie.dart';
import 'base_hybrid_repository.dart';

/// Repositorio híbrido para películas vistas que combina almacenamiento local y remoto
/// con sincronización automática usando el sistema de sync de Fase 3
class HybridWatchedRepository
    extends BaseHybridRepository<SyncableWatchedMovie> {
  HybridWatchedRepository({
    required super.userId,
    SharedPreferences? prefs,
    EntitySyncManager<SyncableWatchedMovie>? syncManager,
    super.syncCoordinator,
  })  : _prefs = prefs,
        super(
          entityType: 'watched_movie',
          syncManager: syncManager ?? WatchedSyncManager(userId: userId),
        );

  SharedPreferences? _prefs;
  static const String _storageKey = 'local_watched_movies';

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
    _prefs ??= await SharedPreferences.getInstance();
    LoggerFactory.info('✅ HybridWatchedRepository local storage initialized');
  }

  @override
  Future<List<SyncableWatchedMovie>> getLocalData() async {
    if (_prefs == null) await initializeLocal();

    try {
      final jsonList = _prefs!.getStringList(_storageKey) ?? [];
      final watchedMovies = jsonList
          .map((jsonStr) => SyncableWatchedMovie.fromJsonString(jsonStr))
          .where((movie) => movie.userId == userId && !movie.isDeleted)
          .toList();

      LoggerFactory.debug(
          '📋 Retrieved ${watchedMovies.length} local watched movies for user $userId');
      return watchedMovies;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get local watched movies: $e');
      return [];
    }
  }

  @override
  Future<void> saveToLocal(SyncableWatchedMovie entity) async {
    if (_prefs == null) await initializeLocal();

    try {
      final existing = await getLocalData();
      final updated = <SyncableWatchedMovie>[];

      // Remover película existente con el mismo ID
      for (final movie in existing) {
        if (movie.id != entity.id) {
          updated.add(movie);
        }
      }

      // Agregar nueva entidad
      updated.add(entity);

      // Guardar lista actualizada
      final jsonList = updated.map((movie) => movie.toJsonString()).toList();
      await _prefs!.setStringList(_storageKey, jsonList);

      LoggerFactory.debug('💾 Saved watched movie locally: ${entity.movieId}');
    } catch (e) {
      LoggerFactory.error('❌ Failed to save watched movie locally: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeFromLocal(String id) async {
    if (_prefs == null) await initializeLocal();

    try {
      final existing = await getLocalData();
      final filtered = existing.where((movie) => movie.id != id).toList();

      final jsonList = filtered.map((movie) => movie.toJsonString()).toList();
      await _prefs!.setStringList(_storageKey, jsonList);

      LoggerFactory.debug('🗑️ Removed watched movie from local storage: $id');
    } catch (e) {
      LoggerFactory.error('❌ Failed to remove watched movie locally: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateLocal(SyncableWatchedMovie entity) async {
    // Reutilizar saveToLocal ya que maneja actualizaciones
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
    } else {
      throw ArgumentError(
          'Model must be a SyncableWatchedMovie, got ${model.runtimeType}');
    }
  }

  // =============================================
  // MÉTODOS ESPECÍFICOS PARA PELÍCULAS VISTAS
  // =============================================

  /// Verifica si una película está marcada como vista
  Future<bool> isMovieWatched(int movieId) async {
    try {
      final watchedMovies = await getAll();
      return watchedMovies.any((movie) => movie.movieId == movieId);
    } catch (e) {
      LoggerFactory.error('❌ Failed to check if movie is watched: $e');
      return false;
    }
  }

  /// Obtiene película vista por ID de película
  Future<SyncableWatchedMovie?> getWatchedMovieByMovieId(int movieId) async {
    try {
      final watchedMovies = await getAll();
      final matches = watchedMovies.where((movie) => movie.movieId == movieId);
      return matches.isNotEmpty ? matches.first : null;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get watched movie by movie ID: $e');
      return null;
    }
  }

  /// Marca una película como vista
  Future<void> markAsWatched({
    required int movieId,
    DateTime? watchedAt,
    double? rating,
    String? review,
  }) async {
    try {
      // Verificar si ya está marcada como vista
      final existing = await getWatchedMovieByMovieId(movieId);
      if (existing != null) {
        LoggerFactory.info('ℹ️ Movie $movieId is already marked as watched');
        return;
      }

      final watchedMovie = SyncableWatchedMovie.fromMovie(
        userId: userId,
        movie: Movie(
          id: movieId,
          title: 'Movie $movieId',
          adult: false,
          backdropPath: '',
          genreIds: [],
          originalLanguage: 'en',
          originalTitle: 'Movie $movieId',
          overview: '',
          popularity: 0.0,
          posterPath: '',
          releaseDate: DateTime.now(),
          video: false,
          voteAverage: 0.0,
          voteCount: 0,
        ),
        watchedDate: watchedAt ?? DateTime.now(),
        personalRating: rating,
        personalNotes: review,
      );

      await add(watchedMovie);
      LoggerFactory.info('✅ Marked movie as watched: $movieId');
    } catch (e) {
      LoggerFactory.error('❌ Failed to mark movie as watched: $e');
      rethrow;
    }
  }

  /// Desmarca una película como vista
  Future<void> unmarkAsWatched(int movieId) async {
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

  /// Actualiza la calificación y reseña de una película vista
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

  /// Obtiene todas las películas vistas ordenadas por fecha
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

  /// Obtiene estadísticas de películas vistas
  Future<Map<String, dynamic>> getWatchedStats() async {
    try {
      final watchedMovies = await getAll();

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
