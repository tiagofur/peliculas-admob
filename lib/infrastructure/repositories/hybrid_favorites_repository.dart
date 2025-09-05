import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/logger_factory.dart';
import '../../core/sync/entity_sync_manager.dart';
import '../../core/sync/favorites_sync_manager.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/syncable_favorite.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../models/favorite_model.dart';
import 'base_hybrid_repository.dart';

/// Repositorio híbrido para favoritos que combina almacenamiento local y remoto
/// con sincronización automática usando el sistema de sync de Fase 3
class HybridFavoritesRepository extends BaseHybridRepository<SyncableFavorite> 
    implements FavoritesRepository {
  HybridFavoritesRepository({
    required super.userId,
    SharedPreferences? prefs,
    EntitySyncManager<SyncableFavorite>? syncManager,
    super.syncCoordinator,
  })  : _prefs = prefs,
        super(
          entityType: 'favorite',
          syncManager: syncManager ?? FavoritesSyncManager(userId: userId),
        );

  SharedPreferences? _prefs;
  static const String _storageKey = 'local_favorites';

  // =============================================
  // IMPLEMENTACIÓN DE MÉTODOS ABSTRACTOS
  // =============================================

  @override
  Future<void> initializeLocal() async {
    _prefs ??= await SharedPreferences.getInstance();
    LoggerFactory.info('✅ HybridFavoritesRepository local storage initialized');
  }

  @override
  Future<List<SyncableFavorite>> getLocalData() async {
    if (_prefs == null) await initializeLocal();

    try {
      final jsonList = _prefs!.getStringList(_storageKey) ?? [];
      final favorites = jsonList
          .map((jsonStr) => SyncableFavorite.fromJsonString(jsonStr))
          .where((fav) => fav.userId == userId && !fav.isDeleted)
          .toList();

      LoggerFactory.debug(
          '📋 Retrieved ${favorites.length} local favorites for user $userId');
      return favorites;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get local favorites: $e');
      return [];
    }
  }

  @override
  Future<void> saveToLocal(SyncableFavorite entity) async {
    if (_prefs == null) await initializeLocal();

    try {
      final existing = await getLocalData();
      final updated = <SyncableFavorite>[];

      // Remover favorito existente con el mismo ID
      for (final fav in existing) {
        if (fav.id != entity.id) {
          updated.add(fav);
        }
      }

      // Agregar nueva entidad
      updated.add(entity);

      // Guardar lista actualizada
      final jsonList = updated.map((fav) => fav.toJsonString()).toList();
      await _prefs!.setStringList(_storageKey, jsonList);

      LoggerFactory.debug('💾 Saved favorite locally: ${entity.movieTitle}');
    } catch (e) {
      LoggerFactory.error('❌ Failed to save favorite locally: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeFromLocal(String id) async {
    if (_prefs == null) await initializeLocal();

    try {
      final existing = await getLocalData();
      final filtered = existing.where((fav) => fav.id != id).toList();

      final jsonList = filtered.map((fav) => fav.toJsonString()).toList();
      await _prefs!.setStringList(_storageKey, jsonList);

      LoggerFactory.debug('🗑️ Removed favorite from local storage: $id');
    } catch (e) {
      LoggerFactory.error('❌ Failed to remove favorite locally: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateLocal(SyncableFavorite entity) async {
    // Reutilizar saveToLocal ya que maneja actualizaciones
    await saveToLocal(entity);
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

  // =============================================
  // MÉTODOS ESPECÍFICOS PARA FAVORITOS
  // =============================================

  /// Verifica si una película es favorita
  Future<bool> isFavorite(int movieId) async {
    try {
      final favorites = await getAll();
      return favorites.any((fav) => fav.movieId == movieId);
    } catch (e) {
      LoggerFactory.error('❌ Failed to check if movie is favorite: $e');
      return false;
    }
  }

  /// Obtiene favorito por ID de película
  Future<FavoriteModel?> getFavoriteByMovieId(int movieId) async {
    try {
      final favorites = await getAll();
      final matches = favorites
          .cast<FavoriteModel>()
          .where((fav) => fav.movieId == movieId);
      return matches.isNotEmpty ? matches.first : null;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get favorite by movie ID: $e');
      return null;
    }
  }

  /// Agrega una película a favoritos
  Future<void> addFavorite(
    int movieId, {
    String? movieTitle,
    String? posterPath,
    double? rating,
    String? overview,
    DateTime? releaseDate,
  }) async {
    try {
      final favoriteModel = FavoriteModel(
        id: 'fav_${userId}_${movieId}_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        movieId: movieId,
        movieTitle: movieTitle ?? 'Unknown Movie',
        posterPath: posterPath,
        rating: rating,
        overview: overview,
        releaseDate: releaseDate,
        addedAt: DateTime.now(),
      );

      await add(favoriteModel);
      LoggerFactory.info('➕ Added movie to favorites: $movieTitle ($movieId)');
    } catch (e) {
      LoggerFactory.error('❌ Failed to add favorite: $e');
      rethrow;
    }
  }

  /// Elimina una película de favoritos
  Future<void> removeFavorite(int movieId) async {
    try {
      final existing = await getFavoriteByMovieId(movieId);
      if (existing != null) {
        await remove(existing.id);
        LoggerFactory.info(
            '🗑️ Removed movie from favorites: ${existing.movieTitle} ($movieId)');
      } else {
        LoggerFactory.warning(
            '⚠️ Tried to remove non-existent favorite: $movieId');
      }
    } catch (e) {
      LoggerFactory.error('❌ Failed to remove favorite: $e');
      rethrow;
    }
  }

  /// Alterna el estado de favorito de una película (método específico con parámetros opcionales)
  Future<bool> toggleFavoriteById(
    int movieId, {
    String? movieTitle,
    String? posterPath,
    double? rating,
    String? overview,
    DateTime? releaseDate,
  }) async {
    try {
      final isCurrentlyFavorite = await isFavorite(movieId);

      if (isCurrentlyFavorite) {
        await removeFavorite(movieId);
        LoggerFactory.info('🔄 Toggled favorite OFF: $movieTitle ($movieId)');
        return false;
      } else {
        await addFavorite(
          movieId,
          movieTitle: movieTitle,
          posterPath: posterPath,
          rating: rating,
          overview: overview,
          releaseDate: releaseDate,
        );
        LoggerFactory.info('🔄 Toggled favorite ON: $movieTitle ($movieId)');
        return true;
      }
    } catch (e) {
      LoggerFactory.error('❌ Failed to toggle favorite: $e');
      rethrow;
    }
  }

  /// Obtiene favoritos ordenados por fecha de agregado (más recientes primero)
  Future<List<FavoriteModel>> getFavoritesSorted({
    int? limit,
    int? offset,
  }) async {
    try {
      final allFavorites = await getAll();
      final sortedFavorites = allFavorites.cast<FavoriteModel>().toList()
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

      if (offset != null) {
        final startIndex = offset.clamp(0, sortedFavorites.length);
        final endIndex = limit != null
            ? (startIndex + limit).clamp(startIndex, sortedFavorites.length)
            : sortedFavorites.length;

        return sortedFavorites.sublist(startIndex, endIndex);
      }

      if (limit != null) {
        return sortedFavorites.take(limit).toList();
      }

      return sortedFavorites;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get sorted favorites: $e');
      return [];
    }
  }

  /// Busca favoritos por título
  Future<List<FavoriteModel>> searchFavorites(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final allFavorites = await getAll();
      final queryLower = query.toLowerCase().trim();

      final matches = allFavorites
          .cast<FavoriteModel>()
          .where((fav) => fav.movieTitle.toLowerCase().contains(queryLower))
          .toList()
        ..sort((a, b) => a.movieTitle.compareTo(b.movieTitle));

      LoggerFactory.debug(
          '🔍 Found ${matches.length} favorite matches for "$query"');
      return matches;
    } catch (e) {
      LoggerFactory.error('❌ Failed to search favorites: $e');
      return [];
    }
  }

  /// Obtiene estadísticas de favoritos
  Future<Map<String, dynamic>> getFavoritesStatistics() async {
    try {
      final baseStats = await getStatistics();
      final favorites = await getAll();
      final favoritesTyped = favorites.cast<FavoriteModel>();

      final totalCount = favoritesTyped.length;
      final yearCounts = <int, int>{};
      var totalRating = 0.0;
      var ratedCount = 0;

      for (final favorite in favoritesTyped) {
        // Contar por año
        if (favorite.releaseDate != null) {
          final year = favorite.releaseDate!.year;
          yearCounts[year] = (yearCounts[year] ?? 0) + 1;
        }

        // Sumar ratings
        if (favorite.rating != null && favorite.rating! > 0) {
          totalRating += favorite.rating!;
          ratedCount++;
        }
      }

      final averageRating = ratedCount > 0 ? totalRating / ratedCount : 0.0;
      final topYear = yearCounts.isNotEmpty
          ? yearCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key
          : null;

      return {
        ...baseStats,
        'favorites_stats': {
          'total_favorites': totalCount,
          'average_rating': averageRating.toStringAsFixed(1),
          'top_year': topYear,
          'year_distribution': yearCounts,
          'oldest_favorite': favoritesTyped.isNotEmpty
              ? favoritesTyped
                  .map((f) => f.addedAt)
                  .reduce((a, b) => a.isBefore(b) ? a : b)
                  .toIso8601String()
              : null,
          'newest_favorite': favoritesTyped.isNotEmpty
              ? favoritesTyped
                  .map((f) => f.addedAt)
                  .reduce((a, b) => a.isAfter(b) ? a : b)
                  .toIso8601String()
              : null,
        },
      };
    } catch (e) {
      LoggerFactory.error('❌ Failed to get favorites statistics: $e');
      return await getStatistics(); // Fallback to base stats
    }
  }

  /// Limpia favoritos locales (para testing o reset)
  Future<void> clearLocalFavorites() async {
    try {
      if (_prefs == null) await initializeLocal();
      await _prefs!.remove(_storageKey);
      LoggerFactory.info('🧹 Cleared all local favorites for user $userId');
    } catch (e) {
      LoggerFactory.error('❌ Failed to clear local favorites: $e');
      rethrow;
    }
  }

  // =============================================
  // IMPLEMENTACIÓN DE FavoritesRepository
  // =============================================

  @override
  Future<Map<int, Movie>> getFavoriteMovies() async {
    try {
      final favorites = await getAll();
      final favoriteMovies = <int, Movie>{};
      
      for (final fav in favorites.cast<FavoriteModel>()) {
        favoriteMovies[fav.movieId] = Movie(
          id: fav.movieId,
          title: fav.movieTitle,
          adult: false,
          backdropPath: '',
          genreIds: [],
          originalLanguage: 'en',
          originalTitle: fav.movieTitle,
          overview: fav.overview ?? '',
          popularity: 0.0,
          posterPath: fav.posterPath ?? '',
          releaseDate: fav.releaseDate ?? DateTime.now(),
          video: false,
          voteAverage: fav.rating ?? 0.0,
          voteCount: 0,
        );
      }
      
      LoggerFactory.debug('📋 Retrieved ${favoriteMovies.length} favorite movies');
      return favoriteMovies;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get favorite movies: $e');
      return {};
    }
  }

  @override
  Future<void> toggleFavorite(Movie movie) async {
    try {
      final isCurrentlyFavorite = await isFavorite(movie.id);
      
      if (isCurrentlyFavorite) {
        await removeFavorite(movie.id);
      } else {
        await addFavorite(
          movie.id,
          movieTitle: movie.title,
          posterPath: movie.posterPath,
          rating: movie.voteAverage,
          overview: movie.overview,
          releaseDate: movie.releaseDate,
        );
      }
      
      LoggerFactory.info('🔄 Toggled favorite for movie: ${movie.title}');
    } catch (e) {
      LoggerFactory.error('❌ Failed to toggle favorite: $e');
      rethrow;
    }
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
    await clearLocalFavorites();
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
