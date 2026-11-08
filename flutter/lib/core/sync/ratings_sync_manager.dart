import 'dart:async';

import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/sync_result.dart';
import '../../domain/entities/syncable_movie_rating.dart';
import '../../infrastructure/datasources/movie_ratings_hive_datasource.dart';
import '../logging/logger_factory.dart';
import 'entity_sync_manager.dart';
import 'sync_operation.dart';

/// Manager de sincronización específico para calificaciones de películas
/// Extiende EntitySyncManager para obtener funcionalidad base de sincronización
class RatingsSyncManager extends EntitySyncManager<SyncableMovieRating> {
  RatingsSyncManager({
    required super.userId,
    SupabaseClient? supabaseClient,
  })  : _supabase = supabaseClient ?? Supabase.instance.client,
        super(entityType: 'movie_rating');
  final MovieRatingsHiveDatasource _localDatasource =
      MovieRatingsHiveDatasource();

  final SupabaseClient _supabase;
  static const String _tableName = 'user_movie_ratings';

  /// Getter para acceder al almacenamiento local de Hive
  Box get _localStorage => Hive.box('movie_ratings');

  // =============================================
  // IMPLEMENTACIONES REQUERIDAS
  // =============================================

  @override
  Future<List<SyncableMovieRating>> getLocalPendingSync(
      {DateTime? since}) async {
    try {
      // Get local ratings that need syncing from the persistent queue
      final queuedOperations = await super.processQueuedOperations();

      // For now, we'll get pending operations from the sync queue
      // In a complete implementation, this would also check local storage timestamps
      LoggerFactory.info(
          '🔍 Found ${queuedOperations.itemsProcessed} pending sync operations for movie ratings');

      // Return empty list as operations are processed through the queue system
      return [];
    } catch (e) {
      LoggerFactory.error('❌ Error getting local pending sync: $e');
      return [];
    }
  }

  @override
  Future<List<SyncableMovieRating>> getRemoteChanges({DateTime? since}) async {
    try {
      // Add date filtering for incremental sync
      if (since != null) {
        LoggerFactory.info(
            '📅 Fetching remote changes since: ${since.toIso8601String()}');
      } else {
        LoggerFactory.info('📅 Fetching all remote changes (no date filter)');
      }

      final response = since != null
          ? await _supabase
              .from(_tableName)
              .select()
              .eq('user_id', userId)
              .eq('is_deleted', false)
              .filter('last_modified_at', 'gte', since.toIso8601String())
              .order('last_modified_at', ascending: false)
          : await _supabase
              .from(_tableName)
              .select()
              .eq('user_id', userId)
              .eq('is_deleted', false)
              .order('last_modified_at', ascending: false);
      final List<dynamic> data = response as List<dynamic>;

      final ratings = data
          .map((item) => SyncableMovieRating(
                id: item['id'],
                userId: item['user_id'],
                movieId: item['movie_id'],
                movieTitle: item['movie_title'],
                rating: item['rating']?.toDouble() ?? 0.0,
                review: item['review'],
                ratedAt: DateTime.parse(item['rated_at'] ?? item['created_at']),
                createdAt: DateTime.parse(item['created_at']),
                lastModifiedAt: DateTime.parse(item['last_modified_at']),
                isDeleted: item['is_deleted'] ?? false,
                syncVersion: item['sync_version'] ?? 0,
                deviceId: item['device_id'],
              ))
          .toList();

      LoggerFactory.info('📥 Retrieved ${ratings.length} remote movie ratings');
      return ratings;
    } catch (e) {
      LoggerFactory.error('❌ Failed to fetch remote changes: $e');
      rethrow;
    }
  }

  @override
  Future<SyncResult> uploadChanges(List<SyncableMovieRating> entities) async {
    if (entities.isEmpty) {
      return SyncResult.success(itemsProcessed: 0);
    }

    final startTime = DateTime.now();
    var successful = 0;
    final errors = <String>[];

    try {
      LoggerFactory.info('📤 Uploading ${entities.length} movie ratings');

      for (final entity in entities) {
        try {
          final data = serializeForRemote(entity);

          // Usar upsert para crear o actualizar
          await _supabase.from(_tableName).upsert(data);

          successful++;
          LoggerFactory.debug('✅ Uploaded movie rating: ${entity.movieTitle}');
        } catch (e) {
          final error = 'Failed to upload movie rating ${entity.id}: $e';
          errors.add(error);
          LoggerFactory.error(error);
        }
      }

      final result = SyncResult(
        success: errors.isEmpty,
        itemsProcessed: entities.length,
        itemsSuccessful: successful,
        itemsFailed: entities.length - successful,
        errors: errors,
        duration: DateTime.now().difference(startTime),
      );

      LoggerFactory.info('📤 Upload completed: ${result.toString()}');
      return result;
    } catch (e) {
      LoggerFactory.error('❌ Upload batch failed: $e');
      return SyncResult.failure(
        itemsProcessed: entities.length,
        errors: ['Batch upload failed: $e'],
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  @override
  Future<SyncResult> downloadChanges(List<SyncableMovieRating> entities) async {
    if (entities.isEmpty) {
      return SyncResult.success(itemsProcessed: 0);
    }

    final startTime = DateTime.now();
    var successful = 0;
    final errors = <String>[];

    try {
      LoggerFactory.info(
          '📥 Processing ${entities.length} remote movie ratings');

      for (final entity in entities) {
        try {
          // This will be handled by the hybrid repository when it processes the download
          // For now, just count as successful - the hybrid repository handles actual storage
          successful++;
          LoggerFactory.debug(
              '✅ Downloaded movie rating: ${entity.movieTitle}');
        } catch (e) {
          final error = 'Failed to save movie rating ${entity.id}: $e';
          errors.add(error);
          LoggerFactory.error(error);
        }
      }

      final result = SyncResult(
        success: errors.isEmpty,
        itemsProcessed: entities.length,
        itemsSuccessful: successful,
        itemsFailed: entities.length - successful,
        errors: errors,
        duration: DateTime.now().difference(startTime),
      );

      LoggerFactory.info('📥 Download completed: ${result.toString()}');
      return result;
    } catch (e) {
      LoggerFactory.error('❌ Download batch failed: $e');
      return SyncResult.failure(
        itemsProcessed: entities.length,
        errors: ['Batch download failed: $e'],
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  @override
  Future<List<ConflictInfo<SyncableMovieRating>>> detectConflicts() async {
    try {
      final conflicts = <ConflictInfo<SyncableMovieRating>>[];

      // Obtener ratings locales
      final localRatings =
          await _localDatasource.loadUserRatings(userId: userId);

      // Obtener cambios remotos para comparar
      final remoteRatings = await getRemoteChanges();

      for (final remoteRating in remoteRatings) {
        // Buscar si existe localmente
        final localRating =
            localRatings.cast<SyncableMovieRating?>().firstWhere(
                  (rating) => rating?.movieId == remoteRating.movieId,
                  orElse: () => null,
                );

        // Detectar conflicto si ambos existen pero tienen diferentes valores o timestamps
        if (localRating != null) {
          final localTimestamp = localRating.ratedAt;
          final remoteTimestamp = remoteRating.lastModifiedAt;

          // Conflicto si las fechas difieren o los ratings son diferentes
          final hasTimestampConflict =
              (localTimestamp.difference(remoteTimestamp).abs().inSeconds > 1);
          final hasValueConflict = localRating.rating != remoteRating.rating;

          if (hasTimestampConflict || hasValueConflict) {
            conflicts.add(ConflictInfo<SyncableMovieRating>(
              localEntity: SyncableMovieRating(
                id: 'rating_${localRating.movieId}_$userId',
                movieId: localRating.movieId,
                userId: userId,
                rating: localRating.rating,
                movieTitle: localRating.movieTitle,
                ratedAt: localRating.ratedAt,
                createdAt: localRating.ratedAt,
                lastModifiedAt: localRating.ratedAt,
              ),
              remoteEntity: remoteRating,
              conflictType: ConflictType.concurrentModification,
              detectedAt: DateTime.now(),
            ));
          }
        }
      }

      LoggerFactory.debug('🔍 Detected ${conflicts.length} rating conflicts');
      return conflicts;
    } catch (e) {
      LoggerFactory.error('❌ Rating conflict detection failed: $e');
      return [];
    }
  }

  @override
  Future<SyncableMovieRating> resolveConflict(
      ConflictInfo<SyncableMovieRating> conflict) async {
    // Estrategia simple: "last write wins"
    final resolved =
        conflict.localEntity.hasPrecedenceOver(conflict.remoteEntity)
            ? conflict.localEntity
            : conflict.remoteEntity;

    LoggerFactory.info(
        '⚖️ Resolved conflict for movie rating ${resolved.movieTitle}: ${conflict.conflictType.name}');
    return resolved;
  }

  @override
  Map<String, dynamic> serializeForLocal(SyncableMovieRating entity) {
    return entity.toLocalStorage();
  }

  @override
  SyncableMovieRating deserializeFromLocal(Map<String, dynamic> data) {
    return SyncableMovieRating.fromJson(data);
  }

  @override
  Map<String, dynamic> serializeForRemote(SyncableMovieRating entity) {
    return entity.toSupabaseJson();
  }

  @override
  SyncableMovieRating deserializeFromRemote(Map<String, dynamic> data) {
    return SyncableMovieRating.fromJson(data);
  }

  // =============================================
  // MÉTODOS ESPECÍFICOS PARA CALIFICACIONES DE PELÍCULAS
  // =============================================

  /// Agrega una calificación y la cola para sync
  Future<void> addMovieRating(SyncableMovieRating rating) async {
    try {
      // Guardar localmente primero
      final localData = serializeForLocal(rating);
      await _localStorage.put('rating_${rating.id}', localData);
      LoggerFactory.info('💾 Saved movie rating locally: ${rating.movieTitle}');

      await queueOperation(
        type: SyncOperationType.create,
        entityId: rating.id,
        data: localData,
        priority: 3, // Prioridad media para calificaciones
      );

      LoggerFactory.info('➕ Added movie rating to queue: ${rating.movieTitle}');
    } catch (e) {
      LoggerFactory.error(
          '❌ Error adding movie rating ${rating.movieTitle}: $e');
      rethrow;
    }
  }

  /// Elimina una calificación y la cola para sync
  Future<void> removeMovieRating(String ratingId) async {
    try {
      // Marcar como eliminado localmente
      await _localStorage.delete('rating_$ratingId');
      LoggerFactory.info(
          '🗑️ Removed movie rating from local storage: $ratingId');

      await queueOperation(
        type: SyncOperationType.delete,
        entityId: ratingId,
        data: {
          'is_deleted': true,
          'deleted_at': DateTime.now().toIso8601String()
        },
        priority: 2, // Alta prioridad para eliminaciones
      );

      LoggerFactory.info('🗑️ Removed movie rating from queue: $ratingId');
    } catch (e) {
      LoggerFactory.error('❌ Error removing movie rating $ratingId: $e');
      rethrow;
    }
  }

  /// Actualiza una calificación existente o crea una nueva
  Future<void> updateRating(int movieId, double newRating) async {
    try {
      // Obtener el rating actual del almacenamiento local
      final localRatings =
          await _localDatasource.loadUserRatings(userId: userId);
      final existingRating =
          localRatings.cast<SyncableMovieRating?>().firstWhere(
                (rating) => rating?.movieId == movieId,
                orElse: () => null,
              );

      // Actualizar o crear el rating localmente
      if (existingRating != null) {
        await _localDatasource.updateRating(existingRating.copyWithData(
          rating: newRating,
          ratedAt: DateTime.now(),
        ));
      } else {
        // Crear nuevo rating local
        final newUserRating = SyncableMovieRating(
          id: 'rating_${movieId}_$userId',
          movieId: movieId,
          userId: userId,
          rating: newRating,
          movieTitle: 'Unknown Movie', // Se actualizará con datos reales
          ratedAt: DateTime.now(),
          createdAt: DateTime.now(),
          lastModifiedAt: DateTime.now(),
        );
        await _localDatasource.saveRating(newUserRating);
      }

      // Crear el item sincronizable
      final now = DateTime.now();
      final currentRating = SyncableMovieRating(
        id: 'rating_${movieId}_$userId',
        movieId: movieId,
        userId: userId,
        rating: newRating,
        movieTitle: 'Unknown Movie', // Se actualizará con datos reales
        ratedAt: now,
        createdAt: now,
        lastModifiedAt: now,
      );

      await queueOperation(
        type: existingRating != null
            ? SyncOperationType.update
            : SyncOperationType.create,
        entityId: currentRating.id,
        data: serializeForLocal(currentRating),
        priority: 3, // Prioridad media para calificaciones
      );

      LoggerFactory.debug(
          '📝 Rating ${existingRating != null ? "updated" : "created"} for movie $movieId: $newRating');
    } catch (e) {
      LoggerFactory.error('❌ Failed to update rating: $e');
      rethrow;
    }
  }

  /// Sincroniza calificaciones específicamente
  Future<SyncResult> syncMovieRatings() async {
    LoggerFactory.info('🔄 Starting movie ratings sync');

    // Primero procesar operaciones en cola
    final queueResult = await processQueuedOperations();

    // Luego realizar sync completo
    final syncResult = await performFullSync();

    // Combinar resultados
    final totalProcessed =
        queueResult.itemsProcessed + syncResult.itemsProcessed;
    final totalSuccessful =
        queueResult.itemsSuccessful + syncResult.itemsSuccessful;
    final allErrors = [...queueResult.errors, ...syncResult.errors];

    final combinedResult = SyncResult(
      success: allErrors.isEmpty,
      itemsProcessed: totalProcessed,
      itemsSuccessful: totalSuccessful,
      itemsFailed: totalProcessed - totalSuccessful,
      errors: allErrors,
      duration: (queueResult.duration ?? Duration.zero) +
          (syncResult.duration ?? Duration.zero),
    );

    LoggerFactory.info(
        '✅ Movie ratings sync completed: ${combinedResult.toString()}');
    return combinedResult;
  }

  /// Obtiene una calificación específica por movie ID
  Future<SyncableMovieRating?> getRatingByMovieId(int movieId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        return SyncableMovieRating.fromJson(response);
      }
      return null;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get rating by movie ID: $e');
      return null;
    }
  }

  /// Obtiene estadísticas de calificaciones del usuario
  Future<Map<String, dynamic>?> getUserRatingStats() async {
    try {
      final response = await _supabase
          .rpc('get_user_rating_stats', params: {'target_user_id': userId});

      if (response != null) {
        return Map<String, dynamic>.from(response);
      }
      return null;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get user rating stats: $e');
      return null;
    }
  }

  /// Obtiene resumen de calificaciones para una película específica
  Future<Map<String, dynamic>?> getMovieRatingSummary(int movieId) async {
    try {
      final response = await _supabase.rpc('get_movie_rating_summary',
          params: {'target_movie_id': movieId});

      if (response != null) {
        return Map<String, dynamic>.from(response);
      }
      return null;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get movie rating summary: $e');
      return null;
    }
  }

  /// Stream de cambios en tiempo real para calificaciones del usuario
  Stream<List<SyncableMovieRating>> watchUserRatings() {
    return _supabase.from(_tableName).stream(primaryKey: ['id']).map((data) {
      // Filter in application layer to avoid Supabase stream filter issues
      final filtered = data
          .where((item) =>
              item['user_id'] == userId && item['is_deleted'] == false)
          .toList();

      // Sort by rated_at descending
      filtered.sort((a, b) =>
          (b['rated_at'] as String).compareTo(a['rated_at'] as String));

      return filtered
          .map((item) => SyncableMovieRating.fromJson(item))
          .toList();
    });
  }

  /// Stream para una calificación específica
  Stream<SyncableMovieRating?> watchMovieRating(int movieId) {
    return _supabase.from(_tableName).stream(primaryKey: ['id']).map((data) {
      // Filter in application layer
      final filtered = data
          .where((item) =>
              item['user_id'] == userId &&
              item['movie_id'] == movieId &&
              item['is_deleted'] == false)
          .toList();

      return filtered.isNotEmpty
          ? SyncableMovieRating.fromJson(filtered.first)
          : null;
    });
  }

  @override
  Future<void> deleteEntity(String entityId) async {
    try {
      // Eliminar de Supabase
      await _supabase.from(_tableName).delete().eq('id', entityId);

      LoggerFactory.info('🗑️ Deleted rating entity: $entityId');
    } catch (e) {
      LoggerFactory.error('❌ Failed to delete rating entity $entityId: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> getRemoteEntity(String entityId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('id', entityId)
          .maybeSingle();

      LoggerFactory.debug('📥 Retrieved remote rating entity: $entityId');
      return response;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get remote rating entity $entityId: $e');
      return null;
    }
  }

  @override
  Future<SyncableMovieRating> mergeEntities(
      SyncableMovieRating localEntity, SyncableMovieRating remoteEntity) async {
    // Estrategia: usar la entidad con timestamp más reciente
    final localTimestamp = localEntity.lastModifiedAt;
    final remoteTimestamp = remoteEntity.lastModifiedAt;

    final merged =
        localTimestamp.isAfter(remoteTimestamp) ? localEntity : remoteEntity;

    LoggerFactory.info('🔀 Merged rating entities for movie ${merged.movieId}');
    return merged;
  }

  @override
  String toString() {
    return 'RatingsSyncManager(userId: $userId, tableName: $_tableName)';
  }
}
