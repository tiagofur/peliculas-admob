import 'dart:async';

import '../../core/logging/logger_factory.dart';
import '../../core/sync/entity_sync_manager.dart';
import '../../core/sync/favorites_sync_manager.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/syncable_favorite.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../datasources/favorite_movies_hive_datasource.dart';
import '../models/favorite_model.dart';
import 'base_hybrid_repository.dart';

class HybridFavoritesRepository extends BaseHybridRepository<SyncableFavorite> 
    implements FavoritesRepository {
  final FavoriteMoviesHiveDatasource _localDatasource;

  HybridFavoritesRepository({
    required super.userId,
    EntitySyncManager<SyncableFavorite>? syncManager,
    super.syncCoordinator,
  })  : _localDatasource = FavoriteMoviesHiveDatasource(),
        super(
          entityType: 'favorite',
          syncManager: syncManager ?? FavoritesSyncManager(userId: userId),
        );

  @override
  Future<void> initializeLocal() async {
    // Hive initialization is handled by the datasource
    LoggerFactory.info('✅ HybridFavoritesRepository local storage initialized');
  }

  @override
  Future<List<SyncableFavorite>> getLocalData() async {
    // This method is not used anymore, local data is handled by the datasource
    return [];
  }

  @override
  Future<void> saveToLocal(SyncableFavorite entity) async {
    // This method is not used anymore, local data is handled by the datasource
  }

  @override
  Future<void> removeFromLocal(String id) async {
    // This method is not used anymore, local data is handled by the datasource
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

  Future<bool> isFavorite(int movieId) async {
    return await _localDatasource.isMovieFavorite(movieId);
  }

  Future<void> addFavorite(Movie movie) async {
    await _localDatasource.toggleFavorite(movie);
  }

  Future<void> removeFavorite(Movie movie) async {
    await _localDatasource.toggleFavorite(movie);
  }

  @override
  Future<Map<int, Movie>> getFavoriteMovies() async {
    final movies = await _localDatasource.loadMovies();
    return {for (var movie in movies) movie.id: movie};
  }

  @override
  Future<void> toggleFavorite(Movie movie) async {
    await _localDatasource.toggleFavorite(movie);
  }

  @override
  Future<bool> isMovieFavorite(int movieId) async {
    return await isFavorite(movieId);
  }

  @override
  Future<void> syncWithRemote() async {
    try {
      await forceSync();
      LoggerFactory.info('🔄 Manual sync completed for favorites');
    } catch (e) {
      LoggerFactory.error('❌ Error in manual favorites sync: $e');
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