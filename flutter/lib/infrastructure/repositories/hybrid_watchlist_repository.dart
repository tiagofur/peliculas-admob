import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/logger_factory.dart';
import '../../core/sync/generic_entity_sync_manager.dart';
import '../../core/sync/sync_utilities.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/syncable_watchlist_item.dart';
import '../../domain/entities/watchlist_movie.dart';
import '../../domain/repositories/watchlist_repository.dart';
import 'base_hybrid_repository.dart';

import '../datasources/watchlist_hive_datasource.dart';

/// Repositorio híbrido para watchlist que combina almacenamiento local y remoto
/// con sincronización automática usando el sistema de sync de Fase 3
class HybridWatchlistRepository
    extends BaseHybridRepository<SyncableWatchlistItem>
    implements WatchlistRepository {
  HybridWatchlistRepository({
    required super.userId,
    required this.hiveDatasource,
    SharedPreferences? prefs,
    GenericEntitySyncManager<SyncableWatchlistItem>? syncManager,
    super.syncCoordinator,
  })  : _prefs = prefs,
        super(
          entityType: 'watchlist_item',
          syncManager: syncManager ??
              GenericEntitySyncManager<SyncableWatchlistItem>(
                  userId: userId, entityType: 'watchlist_item'),
        );

  final WatchlistHiveDatasource hiveDatasource;
  SharedPreferences? _prefs;
  static const String _storageKey = 'local_watchlist';

  // =============================================
  // IMPLEMENTACIÓN DE MÉTODOS ABSTRACTOS
  // =============================================

  @override
  String get tableName => 'user_watchlist';

  @override
  SyncableWatchlistItem deserializeFromRemote(Map<String, dynamic> data) {
    return SyncableWatchlistItem.fromJson(data);
  }

  @override
  Future<void> initializeLocal() async {
    _prefs ??= await SharedPreferences.getInstance();
    LoggerFactory.info('✅ HybridWatchlistRepository local storage initialized');
  }

  @override
  Future<List<SyncableWatchlistItem>> getLocalData() async {
    try {
      final movies = await hiveDatasource.getAllWatchlistMovies();
      final watchlistItems = movies
          .map((movie) => SyncableWatchlistItem.fromWatchlistMovie(
                watchlistMovie: movie,
                userId: userId,
                deviceId: 'local',
              ))
          .toList();

      LoggerFactory.debug(
          '📋 Retrieved ${watchlistItems.length} watchlist items from Hive');
      return watchlistItems;
    } catch (e) {
      LoggerFactory.error(
          '❌ Failed to get local watchlist items from Hive: $e');
      return [];
    }
  }

  @override
  Future<void> saveToLocal(SyncableWatchlistItem entity) async {
    try {
      final movie = entity.toWatchlistMovie();
      await hiveDatasource.addToWatchlist(movie);

      LoggerFactory.debug(
          '💾 Saved watchlist item to Hive: ${entity.movieTitle}');
    } catch (e) {
      LoggerFactory.error('❌ Failed to save watchlist item to Hive: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeFromLocal(String id) async {
    try {
      // Note: The ID of the syncable item is not the movie ID.
      // We need to find the movie ID from the local data.
      final localData = await getLocalData();
      final itemToRemove = localData.firstWhere((item) => item.id == id);
      await hiveDatasource.removeFromWatchlist(itemToRemove.movieId);

      LoggerFactory.debug('🗑️ Removed watchlist item from Hive: $id');
    } catch (e) {
      LoggerFactory.error('❌ Failed to remove watchlist item from Hive: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateLocal(SyncableWatchlistItem entity) async {
    await saveToLocal(entity);
  }

  @override
  WatchlistMovie convertToModel(SyncableWatchlistItem entity) {
    return entity.toWatchlistMovie();
  }

  @override
  SyncableWatchlistItem convertFromModel(dynamic model, String userId) {
    if (model is WatchlistMovie) {
      return SyncableWatchlistItem.fromWatchlistMovie(
        userId: userId,
        watchlistMovie: model,
        deviceId: 'device_${DateTime.now().millisecondsSinceEpoch}',
      );
    } else {
      throw ArgumentError(
          'Model must be a WatchlistMovie, got ${model.runtimeType}');
    }
  }

  // =============================================
  // IMPLEMENTACIÓN DE WatchlistRepository
  // =============================================

  @override
  Future<List<Movie>> getWatchlistMovies() async {
    try {
      final syncableEntities = await getLocalData();
      return syncableEntities
          .where((entity) => !entity.isDeleted)
          .map((entity) =>
              _convertWatchlistMovieToMovie(entity.toWatchlistMovie()))
          .toList();
    } catch (e) {
      LoggerFactory.error('❌ Error getting watchlist movies: $e');
      return [];
    }
  }

  @override
  Future<void> addToWatchlist(Movie movie) async {
    await addToWatchlistWithPriority(movie, WatchlistPriority.normal);
  }

  /// Agregar película a watchlist con prioridad específica
  Future<void> addToWatchlistWithPriority(
      Movie movie, WatchlistPriority priority) async {
    try {
      final watchlistMovie = _convertMovieToWatchlistMovie(movie).copyWith(
        priority: priority,
      );

      await add(watchlistMovie);
      LoggerFactory.debug(
          '➕ Added to watchlist: ${movie.title} with priority: ${priority.value}');
    } catch (e) {
      LoggerFactory.error('❌ Error adding to watchlist: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeFromWatchlist(int movieId) async {
    try {
      final localEntities = await getLocalData();
      final entity = localEntities
          .where((e) => e.movieId == movieId && !e.isDeleted)
          .firstOrNull;

      if (entity != null) {
        await remove(entity.id);
        LoggerFactory.debug('🗑️ Removed from watchlist: $movieId');
      }
    } catch (e) {
      LoggerFactory.error('❌ Error removing from watchlist: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isInWatchlist(int movieId) async {
    try {
      final watchlistMovies = await getWatchlistMovies();
      return watchlistMovies.any((movie) => movie.id == movieId);
    } catch (e) {
      LoggerFactory.error('❌ Error checking if movie is in watchlist: $e');
      return false;
    }
  }

  @override
  Future<List<Movie>> getWatchlistMoviesPaginated({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final allMovies = await getWatchlistMovies();
      return allMovies.skip(offset).take(limit).toList();
    } catch (e) {
      LoggerFactory.error('❌ Error getting paginated watchlist movies: $e');
      return [];
    }
  }

  @override
  Future<void> syncWithRemote() async {
    try {
      await forceSync();
      LoggerFactory.info('🔄 Manual sync requested');
    } catch (e) {
      LoggerFactory.error('❌ Error in manual sync: $e');
    }
  }

  @override
  Future<void> clearLocalData() async {
    try {
      if (_prefs == null) await initializeLocal();
      await _prefs!.remove(_storageKey);
      LoggerFactory.info('🧹 Local watchlist data cleared');
    } catch (e) {
      LoggerFactory.error('❌ Error clearing local data: $e');
    }
  }

  @override
  Future<bool> hasPendingSync() async {
    try {
      return await super.hasPendingSync();
    } catch (e) {
      LoggerFactory.error('❌ Error checking pending sync: $e');
      return false;
    }
  }

  // =============================================
  // MÉTODOS AUXILIARES DE CONVERSIÓN
  // =============================================

  /// Convierte WatchlistMovie a Movie
  Movie _convertWatchlistMovieToMovie(WatchlistMovie watchlistMovie) {
    return Movie(
      adult: false, // valor por defecto
      backdropPath: watchlistMovie.movieBackdropPath ?? '',
      genreIds: [], // valor por defecto
      id: watchlistMovie.movieId,
      originalLanguage: 'en', // valor por defecto
      originalTitle: watchlistMovie.movieTitle,
      overview: watchlistMovie.movieOverview ?? '',
      popularity: 0.0, // valor por defecto
      posterPath: watchlistMovie.moviePosterPath ?? '',
      releaseDate: watchlistMovie.movieReleaseDate ?? DateTime.now(),
      title: watchlistMovie.movieTitle,
      video: false, // valor por defecto
      voteAverage: watchlistMovie.movieVoteAverage ?? 0.0,
      voteCount: 0, // valor por defecto
    );
  }

  /// Convierte Movie a WatchlistMovie
  WatchlistMovie _convertMovieToWatchlistMovie(Movie movie) {
    return WatchlistMovie(
      id: SyncUtilities.generateUuid(),
      movieId: movie.id,
      movieTitle: movie.title,
      moviePosterPath: movie.posterPath,
      movieBackdropPath: movie.backdropPath,
      movieOverview: movie.overview,
      movieReleaseDate: movie.releaseDate,
      movieVoteAverage: movie.voteAverage,
      priority: WatchlistPriority.normal,
      addedAt: SyncUtilities.utcNow(),
      lastModifiedAt: SyncUtilities.utcNow(),
    );
  }

  /// Obtiene watchlist movies como WatchlistMovie entities
  Future<List<WatchlistMovie>> getWatchlistMoviesAsWatchlistMovie() async {
    try {
      final syncableEntities = await getLocalData();
      return syncableEntities
          .where((entity) => !entity.isDeleted)
          .map((entity) => entity.toWatchlistMovie())
          .toList();
    } catch (e) {
      LoggerFactory.error(
          '❌ Error getting watchlist movies as WatchlistMovie: $e');
      return [];
    }
  }

  // =============================================
  // MÉTODOS ADICIONALES DE UTILIDAD
  // =============================================

  /// Obtiene estadísticas de la watchlist
  Future<Map<String, int>> getWatchlistStats() async {
    try {
      final watchlistMovies = await getWatchlistMoviesAsWatchlistMovie();

      return {
        'total': watchlistMovies.length,
        'high_priority': watchlistMovies
            .where((movie) => movie.priority == WatchlistPriority.alta)
            .length,
        'medium_priority': watchlistMovies
            .where((movie) => movie.priority == WatchlistPriority.normal)
            .length,
        'low_priority': watchlistMovies
            .where((movie) => movie.priority == WatchlistPriority.baja)
            .length,
        'this_month': watchlistMovies.where((movie) {
          final now = DateTime.now();
          return movie.addedAt.year == now.year &&
              movie.addedAt.month == now.month;
        }).length,
      };
    } catch (e) {
      LoggerFactory.error('❌ Error getting watchlist stats: $e');
      return {
        'total': 0,
        'high_priority': 0,
        'medium_priority': 0,
        'low_priority': 0,
        'this_month': 0,
      };
    }
  }

  /// Exporta la watchlist a formato JSON
  Future<String> exportWatchlistToJson() async {
    try {
      final watchlistMovies = await getWatchlistMoviesAsWatchlistMovie();
      final exportData = {
        'exported_at': DateTime.now().toIso8601String(),
        'total_items': watchlistMovies.length,
        'watchlist': watchlistMovies
            .map((movie) => {
                  'movie_id': movie.movieId,
                  'movie_title': movie.movieTitle,
                  'priority': movie.priority.value,
                  'added_at': movie.addedAt.toIso8601String(),
                })
            .toList(),
      };

      return jsonEncode(exportData);
    } catch (e) {
      LoggerFactory.error('❌ Error exporting watchlist to JSON: $e');
      return '{"error": "Failed to export watchlist"}';
    }
  }

  // =============================================
  // MÉTODOS ADICIONALES DESDE DATA REPOSITORY
  // =============================================

  /// Obtiene una película específica de la watchlist
  Future<WatchlistMovie?> getWatchlistMovie(int movieId) async {
    try {
      final watchlistMovies = await getWatchlistMoviesAsWatchlistMovie();
      return watchlistMovies
          .where((movie) => movie.movieId == movieId)
          .firstOrNull;
    } catch (e) {
      LoggerFactory.error('❌ Error getting watchlist movie: $e');
      return null;
    }
  }

  /// Actualiza una película en la watchlist
  Future<void> updateWatchlistMovie(WatchlistMovie watchlistMovie) async {
    try {
      final localEntities = await getLocalData();
      final existingEntity = localEntities
          .where((e) => e.movieId == watchlistMovie.movieId && !e.isDeleted)
          .firstOrNull;

      if (existingEntity != null) {
        final updatedEntity = SyncableWatchlistItem.fromWatchlistMovie(
          userId: userId,
          watchlistMovie: watchlistMovie,
          deviceId: 'device_${DateTime.now().millisecondsSinceEpoch}',
        ).copyWith(
          syncVersion: existingEntity.syncVersion + 1,
        );

        await update(updatedEntity);
        LoggerFactory.debug(
            '📝 Updated watchlist movie: ${watchlistMovie.movieTitle}');
      } else {
        await addToWatchlist(_convertWatchlistMovieToMovie(watchlistMovie));
      }
    } catch (e) {
      LoggerFactory.error('❌ Error updating watchlist movie: $e');
      rethrow;
    }
  }

  /// Obtiene películas por prioridad
  Future<List<WatchlistMovie>> getWatchlistMoviesByPriority(
    WatchlistPriority priority,
  ) async {
    try {
      final watchlistMovies = await getWatchlistMoviesAsWatchlistMovie();
      return watchlistMovies
          .where((movie) => movie.priority == priority)
          .toList();
    } catch (e) {
      LoggerFactory.error('❌ Error getting watchlist movies by priority: $e');
      return [];
    }
  }

  /// Obtiene películas ordenadas por prioridad
  Future<List<WatchlistMovie>> getWatchlistMoviesSortedByPriority() async {
    try {
      final watchlistMovies = await getWatchlistMoviesAsWatchlistMovie();
      watchlistMovies
          .sort((a, b) => a.priority.index.compareTo(b.priority.index));
      return watchlistMovies;
    } catch (e) {
      LoggerFactory.error(
          '❌ Error getting watchlist movies sorted by priority: $e');
      return [];
    }
  }

  /// Obtiene películas agregadas recientemente
  Future<List<WatchlistMovie>> getRecentlyAddedToWatchlist(
      {int limit = 10}) async {
    try {
      final watchlistMovies = await getWatchlistMoviesAsWatchlistMovie();
      watchlistMovies.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      return watchlistMovies.take(limit).toList();
    } catch (e) {
      LoggerFactory.error('❌ Error getting recently added to watchlist: $e');
      return [];
    }
  }

  /// Actualiza la prioridad de una película
  Future<void> updateWatchlistPriority(
      int movieId, WatchlistPriority priority) async {
    try {
      final watchlistMovie = await getWatchlistMovie(movieId);
      if (watchlistMovie != null) {
        final updatedMovie = watchlistMovie.copyWith(
          priority: priority,
          lastModifiedAt: SyncUtilities.utcNow(),
        );
        await updateWatchlistMovie(updatedMovie);
        LoggerFactory.debug(
            '📝 Updated watchlist priority for movie $movieId to $priority');
      }
    } catch (e) {
      LoggerFactory.error('❌ Error updating watchlist priority: $e');
      rethrow;
    }
  }

  /// Reordena la watchlist
  Future<void> reorderWatchlist(List<int> movieIds) async {
    try {
      final watchlistMovies = await getWatchlistMoviesAsWatchlistMovie();

      for (int i = 0; i < movieIds.length; i++) {
        final movieId = movieIds[i];
        final movie =
            watchlistMovies.where((m) => m.movieId == movieId).firstOrNull;

        if (movie != null) {
          final updatedMovie = movie.copyWith(
            lastModifiedAt:
                SyncUtilities.utcNow().add(Duration(milliseconds: i)),
          );
          await updateWatchlistMovie(updatedMovie);
        }
      }

      LoggerFactory.debug(
          '🔄 Reordered watchlist with ${movieIds.length} items');
    } catch (e) {
      LoggerFactory.error('❌ Error reordering watchlist: $e');
      rethrow;
    }
  }

  /// Sincroniza un elemento específico de la watchlist
  Future<void> syncWatchlistItem(int movieId) async {
    try {
      final localEntities = await getLocalData();
      final entity =
          localEntities.where((e) => e.movieId == movieId).firstOrNull;

      if (entity != null) {
        await forceSync();
        LoggerFactory.debug('🔄 Queued sync for watchlist item: $movieId');
      }
    } catch (e) {
      LoggerFactory.error('❌ Error syncing watchlist item: $e');
    }
  }

  /// Limpia los elementos eliminados de la watchlist
  Future<void> cleanupDeletedItems() async {
    try {
      final localEntities = await getLocalData();
      final deletedEntities = localEntities.where((e) => e.isDeleted).toList();

      for (final entity in deletedEntities) {
        final daysSinceDeleted =
            DateTime.now().difference(entity.lastModifiedAt).inDays;

        if (daysSinceDeleted > 30) {
          await removeFromLocal(entity.id);
          LoggerFactory.debug(
              '🧼 Cleaned up deleted watchlist item: ${entity.movieTitle}');
        }
      }
    } catch (e) {
      LoggerFactory.error('❌ Error cleaning up deleted items: $e');
    }
  }

  /// Obtiene recomendaciones basadas en la watchlist
  Future<List<int>> getWatchlistRecommendations() async {
    try {
      final watchlistMovies = await getWatchlistMovies();

      LoggerFactory.debug(
          '📊 Analyzing ${watchlistMovies.length} movies for recommendations');

      return [];
    } catch (e) {
      LoggerFactory.error('❌ Error getting watchlist recommendations: $e');
      return [];
    }
  }

  /// Carga películas de watchlist con filtros opcionales
  Future<List<WatchlistMovie>> loadWatchlistMovies({
    int limit = 20,
    int offset = 0,
    WatchlistPriority? priority,
  }) async {
    try {
      final allMovies = await getWatchlistMoviesAsWatchlistMovie();

      // Filtrar por prioridad si se especifica
      List<WatchlistMovie> filteredMovies = priority != null
          ? allMovies.where((movie) => movie.priority == priority).toList()
          : allMovies;

      // Ordenar por prioridad y fecha
      filteredMovies.sort((a, b) {
        final priorityComparison = a.priority.index.compareTo(b.priority.index);
        if (priorityComparison != 0) return priorityComparison;
        return b.addedAt.compareTo(a.addedAt);
      });

      // Aplicar paginación
      return filteredMovies.skip(offset).take(limit).toList();
    } catch (e) {
      LoggerFactory.error('❌ Error loading watchlist movies: $e');
      return [];
    }
  }

  /// Obtiene el conteo total de películas en watchlist
  Future<int> getWatchlistCount() async {
    try {
      final watchlistMovies = await getWatchlistMoviesAsWatchlistMovie();
      return watchlistMovies.length;
    } catch (e) {
      LoggerFactory.error('❌ Error getting watchlist count: $e');
      return 0;
    }
  }

  /// Verifica si una película está en la watchlist
  Future<bool> isMovieInWatchlist(int movieId) async {
    try {
      final watchlistMovie = await getWatchlistMovie(movieId);
      return watchlistMovie != null;
    } catch (e) {
      LoggerFactory.error('❌ Error checking if movie is in watchlist: $e');
      return false;
    }
  }
}

/// Extensión para facilitar el trabajo con listas de watchlist
extension WatchlistMovieListExtensions on List<WatchlistMovie> {
  /// Filtra por prioridad
  List<WatchlistMovie> filterByPriority(WatchlistPriority priority) {
    return where((movie) => movie.priority == priority).toList();
  }

  /// Filtra por rango de fechas de adición
  List<WatchlistMovie> filterByDateRange(DateTime startDate, DateTime endDate) {
    return where((movie) =>
        movie.addedAt.isAfter(startDate.subtract(const Duration(days: 1))) &&
        movie.addedAt.isBefore(endDate.add(const Duration(days: 1)))).toList();
  }

  /// Ordena por fecha de adición
  List<WatchlistMovie> sortByAddedDate({bool ascending = false}) {
    final sorted = List<WatchlistMovie>.from(this);
    sorted.sort((a, b) => ascending
        ? a.addedAt.compareTo(b.addedAt)
        : b.addedAt.compareTo(a.addedAt));
    return sorted;
  }

  /// Ordena por prioridad
  List<WatchlistMovie> sortByPriority({bool ascending = true}) {
    final sorted = List<WatchlistMovie>.from(this);
    sorted.sort((a, b) => ascending
        ? a.priority.index.compareTo(b.priority.index)
        : b.priority.index.compareTo(a.priority.index));
    return sorted;
  }

  /// Agrupa por prioridad
  Map<WatchlistPriority, List<WatchlistMovie>> groupByPriority() {
    final grouped = <WatchlistPriority, List<WatchlistMovie>>{};

    for (final priority in WatchlistPriority.values) {
      grouped[priority] = filterByPriority(priority);
    }

    return grouped;
  }
}
