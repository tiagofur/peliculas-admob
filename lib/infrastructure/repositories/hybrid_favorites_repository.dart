import 'dart:async';

import '../../core/logging/logger_factory.dart';
import '../../core/sync/entity_sync_manager.dart';
import '../../core/sync/favorites_sync_manager.dart';
import '../../core/sync/unified_favorites_sync.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/syncable_favorite.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../datasources/favorite_movies_hive_datasource.dart';
import '../models/favorite_model.dart';
import 'base_hybrid_repository.dart';

class HybridFavoritesRepository extends BaseHybridRepository<SyncableFavorite>
    implements FavoritesRepository {
  HybridFavoritesRepository({
    required super.userId,
    EntitySyncManager<SyncableFavorite>? syncManager,
    super.syncCoordinator,
  })  : _localDatasource = FavoriteMoviesHiveDatasource(),
        _unifiedSync = UnifiedFavoritesSync.instance,
        super(
          entityType: 'favorite',
          syncManager: syncManager ?? FavoritesSyncManager(userId: userId),
        );
  final FavoriteMoviesHiveDatasource _localDatasource;
  final UnifiedFavoritesSync _unifiedSync;

  @override
  Future<void> initializeLocal() async {
    // Hive initialization is handled by the datasource
    LoggerFactory.info('✅ HybridFavoritesRepository local storage initialized');
  }

  @override
  Future<List<SyncableFavorite>> getLocalData() async {
    final movies = await _localDatasource.loadMovies(limit: 10000, offset: 0);
    return movies
        .map((movie) =>
            convertFromModel(FavoriteModel.fromMovie(movie, userId), userId))
        .toList();
  }

  @override
  String get tableName => 'user_favorites';

  @override
  SyncableFavorite deserializeFromRemote(Map<String, dynamic> data) {
    return SyncableFavorite.fromJson(data);
  }

  @override
  Future<void> saveToLocal(SyncableFavorite entity) async {
    try {
      final favoriteModel = convertToModel(entity);
      final movie = favoriteModel.toMovie();
      await _localDatasource.saveFavorite(movie);
      LoggerFactory.debug(
          '💾 Saved favorite locally: ${entity.movieTitle} (movieId: ${entity.movieId})');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ Failed to save favorite locally: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> removeFromLocal(String id) async {
    try {
      // El ID puede ser:
      // 1. Un movie_id directo (número como string)
      // 2. Un UUID de la entidad syncable

      LoggerFactory.debug('🔍 Attempting to remove favorite with ID: $id');

      // Primero intentar como movie_id directo
      final movieId = int.tryParse(id);
      if (movieId != null) {
        LoggerFactory.debug('🗑️ Removing favorite by movie_id: $movieId');
        await _localDatasource.removeFavoriteById(movieId);
        LoggerFactory.info(
            '✅ Favorite removed successfully (movie_id: $movieId)');
      } else {
        // Si no es un número, intentar buscar por UUID en datos locales
        LoggerFactory.debug('🔍 ID is not a movie_id, searching by UUID: $id');
        final localFavorites = await getLocalData();
        final favorite = localFavorites.cast<SyncableFavorite?>().firstWhere(
              (fav) => fav?.id == id,
              orElse: () => null,
            );

        if (favorite != null) {
          LoggerFactory.debug(
              '🗑️ Removing favorite by UUID->movie_id: ${favorite.movieId}');
          await _localDatasource.removeFavoriteById(favorite.movieId);
          LoggerFactory.info(
              '✅ Favorite removed successfully (UUID: $id, movie_id: ${favorite.movieId})');
        } else {
          LoggerFactory.warning(
              '⚠️ Favorite not found locally for removal (ID: $id)');
          // Don't throw - might be already removed
        }
      }
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ Failed to remove favorite locally (ID: $id): $e');
      LoggerFactory.error('Stack trace: $stackTrace');
      // Don't rethrow - be resilient to inconsistencies
    }
  }

  @override
  Future<void> updateLocal(SyncableFavorite entity) async {
    // This method is not used anymore, local data is handled by the datasource
  }

  @override
  FavoriteModel convertToModel(SyncableFavorite entity) {
    return FavoriteModel.fromSyncableEntity(entity);
  }

  @override
  SyncableFavorite convertFromModel(dynamic model, String userId) {
    if (model is FavoriteModel) {
      return SyncableFavorite.fromFavoriteModel(model, userId);
    } else {
      throw ArgumentError(
          'Model must be a FavoriteModel, got ${model.runtimeType}');
    }
  }

  Future<SyncableFavorite?> getFavoriteByMovieId(int movieId) async {
    final favorites = await getLocalData();
    try {
      return favorites.firstWhere((fav) => fav.movieId == movieId);
    } catch (e) {
      return null;
    }
  }

  Future<void> addFavorite(Movie movie) async {
    final favorite = FavoriteModel.fromMovie(movie, userId);
    final syncableFavorite = convertFromModel(favorite, userId);
    await super.add(syncableFavorite);
  }

  Future<void> removeFavorite(Movie movie) async {
    final favoriteToRemove = await getFavoriteByMovieId(movie.id);
    if (favoriteToRemove != null) {
      await super.remove(favoriteToRemove.id);
    } else {
      LoggerFactory.warning(
          'Attempted to remove a favorite that was not found locally: ${movie.title}');
    }
  }

  @override
  Future<Map<int, Movie>> getFavoriteMovies() async {
    // 🐛 FIX: Cargar TODAS las películas, no solo las primeras 10
    final movies = await _localDatasource.loadMovies(limit: 1000, offset: 0);
    final result = {for (var movie in movies) movie.id: movie};

    return result;
  }

  @override
  Future<void> toggleFavorite(Movie movie) async {
    try {
      // ✅ USAR EL SISTEMA UNIFICADO
      final isCurrentlyFavorite = await isMovieFavorite(movie.id);

      LoggerFactory.info(
          '🔄 HybridFavorites: Toggle ${movie.title} (actual: $isCurrentlyFavorite)');

      // Actualizar local primero (optimistic update)
      await _localDatasource.toggleFavorite(movie);

      // Sincronizar con Supabase usando el sistema unificado
      if (isCurrentlyFavorite) {
        await _unifiedSync.removeItem(userId, movie.id);
      } else {
        await _unifiedSync.addOrUpdateItem(userId, movie);
      }

      LoggerFactory.info(
          '✅ HybridFavorites: Toggle exitoso para ${movie.title}');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ HybridFavorites: Error en toggle: $e');
      LoggerFactory.error('Stack trace: $stackTrace');

      // Revertir cambio local en caso de error
      await _localDatasource.toggleFavorite(movie);
      rethrow;
    }
  }

  @override
  Future<bool> isMovieFavorite(int movieId) async {
    return await _localDatasource.isMovieFavorite(movieId);
  }

  @override
  Future<void> syncWithRemote() async {
    try {
      LoggerFactory.info('🔄 HybridFavorites: Iniciando sync con Supabase...');

      // ✅ USAR EL SISTEMA UNIFICADO PARA SINCRONIZAR
      final remoteData = await _unifiedSync.getUserItems(userId);
      final localMovies =
          await _localDatasource.loadMovies(limit: 1000, offset: 0);

      // Crear mapas para comparación rápida
      final remoteIds = remoteData.map((d) => d['movie_id'] as int).toSet();
      final localIds = localMovies.map((m) => m.id).toSet();

      LoggerFactory.info(
          '� HybridFavorites: Local=${localIds.length}, Remote=${remoteIds.length}');

      // Agregar favoritos remotos que no están localmente
      int addedCount = 0;
      for (final data in remoteData) {
        final movieId = data['movie_id'] as int;
        if (!localIds.contains(movieId)) {
          final favorite = _unifiedSync.supabaseDataToEntity(data);
          await _localDatasource.saveFavorite(favorite.toMovie());
          addedCount++;
        }
      }

      // Subir favoritos locales que no están en remoto
      final toUpload =
          localMovies.where((m) => !remoteIds.contains(m.id)).toList();
      if (toUpload.isNotEmpty) {
        LoggerFactory.info(
            '📤 HybridFavorites: Subiendo ${toUpload.length} favoritos locales');
        await _unifiedSync.batchSync(userId, toUpload);
      }

      // Eliminar locales que no están en remoto (ya no son favoritos)
      int removedCount = 0;
      for (final movieId in localIds) {
        if (!remoteIds.contains(movieId)) {
          await _localDatasource.removeFavoriteById(movieId);
          removedCount++;
        }
      }

      LoggerFactory.info(
          '✅ HybridFavorites: Sync completado (agregados: $addedCount, eliminados: $removedCount, subidos: ${toUpload.length})');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ HybridFavorites: Error en sync: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> clearLocalData() async {
    // This method should be implemented in the datasource
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
}
