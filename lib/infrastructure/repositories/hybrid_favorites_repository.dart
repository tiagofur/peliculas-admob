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
  HybridFavoritesRepository({
    required super.userId,
    EntitySyncManager<SyncableFavorite>? syncManager,
    super.syncCoordinator,
  })  : _localDatasource = FavoriteMoviesHiveDatasource(),
        super(
          entityType: 'favorite',
          syncManager: syncManager ?? FavoritesSyncManager(userId: userId),
        );
  final FavoriteMoviesHiveDatasource _localDatasource;

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
    final favoriteModel = convertToModel(entity);
    final movie = favoriteModel.toMovie();
    await _localDatasource.saveFavorite(movie);
  }

  @override
  Future<void> removeFromLocal(String id) async {
    // The ID from supabase is the movie ID, so we can use it directly.
    final movieId = int.tryParse(id);
    if (movieId != null) {
      await _localDatasource.removeFavoriteById(movieId);
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
    final isCurrentlyFavorite = await isMovieFavorite(movie.id);
    if (isCurrentlyFavorite) {
      await removeFavorite(movie);
    } else {
      await addFavorite(movie);
    }
  }

  @override
  Future<bool> isMovieFavorite(int movieId) async {
    return await _localDatasource.isMovieFavorite(movieId);
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
