import 'dart:async';

import '../../core/logging/logger_factory.dart';
import '../../core/sync/entity_sync_manager.dart';
import '../../core/sync/ratings_sync_manager.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/syncable_movie_rating.dart';
import '../../domain/repositories/movie_ratings_repository.dart';
import '../datasources/movie_ratings_hive_datasource.dart';
import 'base_hybrid_repository.dart';

/// Repositorio híbrido para calificaciones de películas que combina almacenamiento local y remoto
/// con sincronización automática usando el sistema de sync
class HybridMovieRatingsRepository
    extends BaseHybridRepository<SyncableMovieRating>
    implements MovieRatingsRepository {
  HybridMovieRatingsRepository({
    required super.userId,
    EntitySyncManager<SyncableMovieRating>? syncManager,
    super.syncCoordinator,
  })  : _localDatasource = MovieRatingsHiveDatasource(),
        super(
          entityType: 'movie_rating',
          syncManager: syncManager ?? RatingsSyncManager(userId: userId),
        );

  final MovieRatingsHiveDatasource _localDatasource;

  /// Accessor para el sync manager específico
  RatingsSyncManager get _ratingsSync => syncManager! as RatingsSyncManager;

  // =============================================
  // IMPLEMENTACIÓN DE MÉTODOS ABSTRACTOS
  // =============================================

  @override
  String get tableName => 'user_movie_ratings';

  @override
  SyncableMovieRating deserializeFromRemote(Map<String, dynamic> data) {
    return SyncableMovieRating.fromJson(data);
  }

  @override
  Future<void> initializeLocal() async {
    // La inicialización de Hive es manejada por el datasource
    LoggerFactory.info(
      '✅ HybridMovieRatingsRepository local storage initialized',
    );
  }

  @override
  Future<List<SyncableMovieRating>> getLocalData() async {
    try {
      return await _localDatasource.loadUserRatings(userId: userId);
    } catch (e) {
      LoggerFactory.error('❌ Failed to get local movie ratings: $e');
      return [];
    }
  }

  @override
  Future<void> saveToLocal(SyncableMovieRating entity) async {
    try {
      await _localDatasource.saveRating(entity);
      LoggerFactory.debug('💾 Saved movie rating locally: ${entity.movieId}');
    } catch (e) {
      LoggerFactory.error('❌ Failed to save movie rating locally: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeFromLocal(String id) async {
    try {
      // Buscar la calificación por ID
      final ratings = await getLocalData();
      final ratingToRemove = ratings.where((r) => r.id == id).firstOrNull;

      if (ratingToRemove != null) {
        await _localDatasource.removeRating(ratingToRemove.movieId, userId);
        LoggerFactory.debug('🗑️ Removed movie rating from local storage: $id');
      } else {
        LoggerFactory.warning(
          '⚠️ Movie rating not found locally for removal: $id',
        );
      }
    } catch (e) {
      LoggerFactory.error('❌ Failed to remove movie rating locally: $e');
      // No relanzar - ser resiliente a inconsistencias locales
    }
  }

  @override
  Future<void> updateLocal(SyncableMovieRating entity) async {
    await saveToLocal(entity);
  }

  @override
  SyncableMovieRating convertToModel(SyncableMovieRating entity) {
    return entity;
  }

  @override
  SyncableMovieRating convertFromModel(dynamic model, String userId) {
    if (model is SyncableMovieRating) {
      return model;
    } else {
      throw ArgumentError(
        'Model must be a SyncableMovieRating, got ${model.runtimeType}',
      );
    }
  }

  // =============================================
  // IMPLEMENTACIÓN DEL REPOSITORIO DE CALIFICACIONES
  // =============================================

  @override
  Future<void> rateMovie({
    required Movie movie,
    required double rating,
    String? review,
    bool isPublic = false,
    List<String> tags = const [],
  }) async {
    try {
      // ✅ CRITICAL: Validar rating ANTES de crear la entidad
      // Escala 1.0-10.0 directa (sin conversión de estrellas)
      final validatedRating = rating.clamp(1.0, 10.0);

      if (rating != validatedRating) {
        LoggerFactory.warning(
          '⚠️ Rating clamped from $rating to $validatedRating for movie ${movie.id}',
        );
      }

      // Verificar si ya existe una calificación para esta película
      final existingRating = await getUserRating(movie.id);
      if (existingRating != null) {
        // Actualizar calificación existente
        await updateRating(
          movieId: movie.id,
          rating: validatedRating, // ✅ Usar rating validado
          review: review,
          isPublic: isPublic,
          tags: tags,
        );
        return;
      }

      final movieRating = SyncableMovieRating.fromMovie(
        userId: userId,
        movie: movie,
        rating: validatedRating, // ✅ Usar rating validado
        review: review,
        isPublic: isPublic,
        tags: tags,
      );

      await add(movieRating);
      LoggerFactory.info('⭐ Rated movie: ${movie.id} ($validatedRating/10)');
    } catch (e) {
      LoggerFactory.error('❌ Failed to rate movie: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateRating({
    required int movieId,
    required double rating,
    String? review,
    bool? isPublic,
    List<String>? tags,
  }) async {
    try {
      // ✅ CRITICAL: Validar rating antes de actualizar
      final validatedRating = rating.clamp(1.0, 10.0);

      if (rating != validatedRating) {
        LoggerFactory.warning(
          '⚠️ Rating clamped from $rating to $validatedRating for movie $movieId',
        );
      }

      final existingRating = await getUserRating(movieId);
      if (existingRating == null) {
        throw Exception('Movie $movieId is not rated yet');
      }

      final updatedRating = existingRating.copyWithData(
        rating: validatedRating, // ✅ Usar rating validado
        review: review,
        isPublic: isPublic ?? existingRating.isPublic,
        tags: tags ?? existingRating.tags,
        lastModifiedAt: DateTime.now(),
        syncVersion: existingRating.syncVersion + 1,
      );

      await update(updatedRating);
      LoggerFactory.info(
        '📝 Updated movie rating: $movieId ($validatedRating/10)',
      );
    } catch (e) {
      LoggerFactory.error('❌ Failed to update movie rating: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeRating(int movieId) async {
    try {
      final rating = await getUserRating(movieId);
      if (rating != null) {
        await remove(rating.id);
        LoggerFactory.info('🗑️ Removed rating for movie: $movieId');
      } else {
        LoggerFactory.info('ℹ️ Movie $movieId was not rated');
      }
    } catch (e) {
      LoggerFactory.error('❌ Failed to remove movie rating: $e');
      rethrow;
    }
  }

  @override
  Future<SyncableMovieRating?> getUserRating(int movieId) async {
    try {
      return await _localDatasource.getUserRating(movieId, userId);
    } catch (e) {
      LoggerFactory.error('❌ Failed to get user rating: $e');
      return null;
    }
  }

  @override
  Future<bool> hasUserRatedMovie(int movieId) async {
    try {
      final rating = await getUserRating(movieId);
      return rating != null;
    } catch (e) {
      LoggerFactory.error('❌ Failed to check if user rated movie: $e');
      return false;
    }
  }

  @override
  Future<List<SyncableMovieRating>> getUserRatings({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      return await _localDatasource.loadUserRatings(
        userId: userId,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      LoggerFactory.error('❌ Failed to get user ratings: $e');
      return [];
    }
  }

  @override
  Future<List<SyncableMovieRating>> getUserRatingsSorted({
    bool ascending = false,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      return await _localDatasource.getUserRatingsSorted(
        userId: userId,
        ascending: ascending,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      LoggerFactory.error('❌ Failed to get sorted user ratings: $e');
      return [];
    }
  }

  @override
  Future<List<SyncableMovieRating>> getUserRatingsByRating({
    double? minRating,
    double? maxRating,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      return await _localDatasource.getUserRatingsByRating(
        userId: userId,
        minRating: minRating,
        maxRating: maxRating,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      LoggerFactory.error('❌ Failed to get ratings by rating: $e');
      return [];
    }
  }

  @override
  Future<List<SyncableMovieRating>> getUserRatingsWithReviews({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      return await _localDatasource.getUserRatingsWithReviews(
        userId: userId,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      LoggerFactory.error('❌ Failed to get ratings with reviews: $e');
      return [];
    }
  }

  @override
  Future<List<SyncableMovieRating>> getUserPublicRatings({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final ratings = await getUserRatings(
        limit: 1000,
      ); // Obtener más para filtrar
      final publicRatings = ratings.where((r) => r.isPublic).toList();

      final startIndex = offset;
      final endIndex = (startIndex + limit < publicRatings.length)
          ? startIndex + limit
          : publicRatings.length;

      if (startIndex >= publicRatings.length) return [];

      return publicRatings.sublist(startIndex, endIndex);
    } catch (e) {
      LoggerFactory.error('❌ Failed to get public ratings: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> getUserRatingStats() async {
    try {
      return await _localDatasource.getUserRatingStats(userId);
    } catch (e) {
      LoggerFactory.error('❌ Failed to get user rating stats: $e');
      return {
        'totalRatings': 0,
        'averageRating': 0.0,
        'highestRating': 0.0,
        'lowestRating': 0.0,
        'ratingsWithReview': 0,
        'publicRatings': 0,
        'recentRatingsCount': 0,
      };
    }
  }

  @override
  Future<List<SyncableMovieRating>> searchRatingsByTags({
    required List<String> tags,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      return await _localDatasource.searchRatingsByTags(
        userId: userId,
        tags: tags,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      LoggerFactory.error('❌ Failed to search ratings by tags: $e');
      return [];
    }
  }

  @override
  Future<List<SyncableMovieRating>> searchRatingsByReviewText({
    required String query,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      return await _localDatasource.searchRatingsByReviewText(
        userId: userId,
        query: query,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      LoggerFactory.error('❌ Failed to search ratings by review text: $e');
      return [];
    }
  }

  @override
  Future<List<SyncableMovieRating>> getRecentRatings({
    int days = 30,
    int limit = 20,
  }) async {
    try {
      final allRatings = await getUserRatings(limit: 1000);
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      final recentRatings =
          allRatings.where((r) => r.ratedAt.isAfter(cutoffDate)).toList();

      // Ordenar por fecha más reciente primero
      recentRatings.sort((a, b) => b.ratedAt.compareTo(a.ratedAt));

      return recentRatings.take(limit).toList();
    } catch (e) {
      LoggerFactory.error('❌ Failed to get recent ratings: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> exportUserRatings() async {
    try {
      final ratings = await getUserRatings(limit: 10000);
      return ratings.map((rating) => rating.toLocalStorage()).toList();
    } catch (e) {
      LoggerFactory.error('❌ Failed to export user ratings: $e');
      return [];
    }
  }

  @override
  Future<void> importUserRatings(List<Map<String, dynamic>> ratingsData) async {
    try {
      for (final ratingData in ratingsData) {
        try {
          final rating = SyncableMovieRating.fromJson(ratingData);
          await saveToLocal(rating);
        } catch (e) {
          LoggerFactory.warning('⚠️ Failed to import rating: $e');
        }
      }
      LoggerFactory.info('📥 Imported ${ratingsData.length} ratings');
    } catch (e) {
      LoggerFactory.error('❌ Failed to import user ratings: $e');
      rethrow;
    }
  }

  @override
  Stream<List<SyncableMovieRating>> watchUserRatings() {
    try {
      return _ratingsSync.watchUserRatings();
    } catch (e) {
      LoggerFactory.error('❌ Failed to watch user ratings: $e');
      return Stream.value([]);
    }
  }

  @override
  Stream<SyncableMovieRating?> watchUserRating(int movieId) {
    try {
      return _ratingsSync.watchMovieRating(movieId);
    } catch (e) {
      LoggerFactory.error('❌ Failed to watch user rating: $e');
      return Stream.value(null);
    }
  }

  @override
  Future<Map<String, dynamic>?> getMovieRatingSummary(int movieId) async {
    try {
      return await _ratingsSync.getMovieRatingSummary(movieId);
    } catch (e) {
      LoggerFactory.error('❌ Failed to get movie rating summary: $e');
      return null;
    }
  }

  /// Método auxiliar para obtener estadísticas desde el servidor
  Future<Map<String, dynamic>?> getRemoteUserRatingStats() async {
    try {
      return await _ratingsSync.getUserRatingStats();
    } catch (e) {
      LoggerFactory.error('❌ Failed to get remote user rating stats: $e');
      return null;
    }
  }
}
