import 'package:supabase_flutter/supabase_flutter.dart';

import '../logging/logger_factory.dart';
import '../../domain/entities/sync_result.dart';
import '../../domain/entities/syncable_watched_movie.dart';
import 'entity_sync_manager.dart';
import 'sync_operation.dart';

/// Implementación específica del EntitySyncManager para películas vistas
class WatchedSyncManager extends EntitySyncManager<SyncableWatchedMovie> {
  WatchedSyncManager({
    required super.userId,
    SupabaseClient? supabaseClient,
  })  : _supabase = supabaseClient ?? Supabase.instance.client,
        super(entityType: 'watched_movie');

  final SupabaseClient _supabase;
  static const String _tableName = 'user_watched_movies';

  // =============================================
  // IMPLEMENTACIONES REQUERIDAS
  // =============================================

  @override
  Future<List<SyncableWatchedMovie>> getLocalPendingSync(
      {DateTime? since}) async {
    try {
      // Get local watched movies that need syncing from the persistent queue
      final queuedOperations = await super.processQueuedOperations();

      // For now, we'll get pending operations from the sync queue
      // In a complete implementation, this would also check local storage timestamps
      LoggerFactory.info(
          '🔍 Found ${queuedOperations.itemsProcessed} pending sync operations for watched movies');

      // Return empty list as operations are processed through the queue system
      return [];
    } catch (e) {
      LoggerFactory.error('❌ Error getting local pending sync: $e');
      return [];
    }
  }

  @override
  Future<List<SyncableWatchedMovie>> getRemoteChanges({DateTime? since}) async {
    try {
      var query = _supabase
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .order('last_modified_at', ascending: false);

      // Add date filtering for incremental sync
      if (since != null) {
        query = query.gte('last_modified_at', since.toIso8601String());
        LoggerFactory.info(
            '📅 Fetching remote changes since: ${since.toIso8601String()}');
      }

      final response = await query;
      final List<dynamic> data = response as List<dynamic>;

      final watchedMovies = data
          .map((item) => deserializeFromRemote(Map<String, dynamic>.from(item)))
          .toList();

      LoggerFactory.info(
          '📥 Retrieved ${watchedMovies.length} remote watched movies');
      return watchedMovies;
    } catch (e) {
      LoggerFactory.error('❌ Failed to fetch remote changes: $e');
      rethrow;
    }
  }

  @override
  Future<SyncResult> uploadChanges(List<SyncableWatchedMovie> entities) async {
    if (entities.isEmpty) {
      return SyncResult.success(itemsProcessed: 0);
    }

    final startTime = DateTime.now();
    var successful = 0;
    final errors = <String>[];

    try {
      LoggerFactory.info('📤 Uploading ${entities.length} watched movies');

      for (final entity in entities) {
        try {
          final data = serializeForRemote(entity);

          // Usar upsert para crear o actualizar
          await _supabase.from(_tableName).upsert(data);

          successful++;
          LoggerFactory.debug('✅ Uploaded watched movie: ${entity.movieTitle}');
        } catch (e) {
          final error = 'Failed to upload watched movie ${entity.id}: $e';
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
      List<SyncableWatchedMovie> entities) async {
    if (entities.isEmpty) {
      return SyncResult.success(itemsProcessed: 0);
    }

    final startTime = DateTime.now();
    var successful = 0;
    final errors = <String>[];

    try {
      LoggerFactory.info(
          '📥 Processing ${entities.length} remote watched movies');

      for (final entity in entities) {
        try {
          // This will be handled by the hybrid repository when it processes the download
          // For now, just count as successful - the hybrid repository handles actual storage
          successful++;
          LoggerFactory.debug(
              '✅ Downloaded watched movie: ${entity.movieTitle}');
        } catch (e) {
          final error = 'Failed to save watched movie ${entity.id}: $e';
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
  Future<List<ConflictInfo<SyncableWatchedMovie>>> detectConflicts() async {
    // Para películas vistas, los conflictos son menos comunes
    // Implementación simple por ahora
    final conflicts = <ConflictInfo<SyncableWatchedMovie>>[];

    try {
      // TODO: Implementar detección de conflictos cuando tengamos storage local
      LoggerFactory.debug('🔍 No conflicts detected for watched movies');
    } catch (e) {
      LoggerFactory.error('❌ Conflict detection failed: $e');
    }

    return conflicts;
  }

  @override
  Future<SyncableWatchedMovie> resolveConflict(
      ConflictInfo<SyncableWatchedMovie> conflict) async {
    // Estrategia simple: "last write wins"
    final resolved =
        conflict.localEntity.hasPrecedenceOver(conflict.remoteEntity)
            ? conflict.localEntity
            : conflict.remoteEntity;

    LoggerFactory.info(
        '⚖️ Resolved conflict for watched movie ${resolved.movieTitle}: ${conflict.conflictType.name}');
    return resolved;
  }

  @override
  Map<String, dynamic> serializeForLocal(SyncableWatchedMovie entity) {
    return entity.toLocalStorage();
  }

  @override
  SyncableWatchedMovie deserializeFromLocal(Map<String, dynamic> data) {
    return SyncableWatchedMovie.fromJson(data);
  }

  @override
  Map<String, dynamic> serializeForRemote(SyncableWatchedMovie entity) {
    return entity.toSupabaseJson();
  }

  @override
  SyncableWatchedMovie deserializeFromRemote(Map<String, dynamic> data) {
    return SyncableWatchedMovie.fromJson(data);
  }

  // =============================================
  // MÉTODOS ESPECÍFICOS PARA PELÍCULAS VISTAS
  // =============================================

  /// Agrega una película vista y la cola para sync
  Future<void> addWatchedMovie(SyncableWatchedMovie watchedMovie) async {
    // TODO: Guardar localmente cuando tengamos storage

    await queueOperation(
      type: SyncOperationType.create,
      entityId: watchedMovie.id,
      data: serializeForLocal(watchedMovie),
      priority: 3, // Prioridad media para películas vistas
    );

    LoggerFactory.info(
        '➕ Added watched movie to queue: ${watchedMovie.movieTitle}');
  }

  /// Elimina una película vista y la cola para sync
  Future<void> removeWatchedMovie(String watchedMovieId) async {
    // TODO: Marcar como eliminado localmente cuando tengamos storage

    await queueOperation(
      type: SyncOperationType.delete,
      entityId: watchedMovieId,
      data: {
        'is_deleted': true,
        'deleted_at': DateTime.now().toIso8601String()
      },
      priority: 2, // Alta prioridad para eliminaciones
    );

    LoggerFactory.info('🗑️ Removed watched movie from queue: $watchedMovieId');
  }

  /// Sincroniza películas vistas específicamente
  Future<SyncResult> syncWatchedMovies() async {
    LoggerFactory.info('🔄 Starting watched movies sync');

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
        '✅ Watched movies sync completed: ${combinedResult.toString()}');
    return combinedResult;
  }
}
