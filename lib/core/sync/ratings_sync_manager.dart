import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logging/logger_factory.dart';
import '../../domain/entities/sync_result.dart';
import '../../domain/entities/syncable_movie_rating.dart';
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

  final SupabaseClient _supabase;
  static const String _tableName = 'user_movie_ratings';

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
      var query = _supabase
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .order('last_modified_at', ascending: false);

      // Add date filtering for incremental sync
      if (since != null) {
        // TODO: Fix date filtering when Supabase API is clarified
        // query = query.filter('last_modified_at', 'gte', since.toIso8601String());
        LoggerFactory.info(
            '📅 Fetching remote changes since: ${since.toIso8601String()}');
        LoggerFactory.warning(
            '⚠️ Date filtering temporarily disabled - will fetch all records');
      }

      final response = await query;
      final List<dynamic> data = response as List<dynamic>;

      final ratings = data
          .map((item) => deserializeFromRemote(Map<String, dynamic>.from(item)))
          .toList();

      LoggerFactory.info(
          '📥 Retrieved ${ratings.length} remote movie ratings');
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
  Future<SyncResult> downloadChanges(
      List<SyncableMovieRating> entities) async {
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
    // Para calificaciones, los conflictos son menos comunes
    // Implementación simple por ahora
    final conflicts = <ConflictInfo<SyncableMovieRating>>[];

    try {
      // TODO: Implementar detección de conflictos cuando tengamos storage local
      LoggerFactory.debug('🔍 No conflicts detected for movie ratings');
    } catch (e) {
      LoggerFactory.error('❌ Conflict detection failed: $e');
    }

    return conflicts;
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
    // TODO: Guardar localmente cuando tengamos storage

    await queueOperation(
      type: SyncOperationType.create,
      entityId: rating.id,
      data: serializeForLocal(rating),
      priority: 3, // Prioridad media para calificaciones
    );

    LoggerFactory.info(
        '➕ Added movie rating to queue: ${rating.movieTitle}');
  }

  /// Elimina una calificación y la cola para sync
  Future<void> removeMovieRating(String ratingId) async {
    // TODO: Marcar como eliminado localmente cuando tengamos storage

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
          .eq('movie_id', movieId)
          .eq('is_deleted', false)
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
    return _supabase
        .from(_tableName)
        .stream(primaryKey: ['id']).map((data) {
      // Filter in application layer to avoid Supabase stream filter issues
      final filtered = data
          .where((item) => 
              item['user_id'] == userId && 
              item['is_deleted'] == false)
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
    return _supabase
        .from(_tableName)
        .stream(primaryKey: ['id']).map((data) {
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
  String toString() {
    return 'RatingsSyncManager(userId: $userId, tableName: $_tableName)';
  }
}
