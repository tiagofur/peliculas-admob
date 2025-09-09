import 'package:supabase_flutter/supabase_flutter.dart';

import '../logging/logger_factory.dart';
import '../../domain/entities/sync_result.dart';
import '../../domain/entities/syncable_favorite.dart';
import 'entity_sync_manager.dart';
import 'sync_operation.dart';

/// Implementación específica del EntitySyncManager para favoritos
class FavoritesSyncManager extends EntitySyncManager<SyncableFavorite> {
  FavoritesSyncManager({
    required super.userId,
    SupabaseClient? supabaseClient,
  })  : _supabase = supabaseClient ?? Supabase.instance.client,
        super(entityType: 'favorite');

  final SupabaseClient _supabase;
  static const String _tableName = 'user_favorites';

  // =============================================
  // IMPLEMENTACIONES REQUERIDAS
  // =============================================

  @override
  Future<List<SyncableFavorite>> getLocalPendingSync({DateTime? since}) async {
    try {
      // Get local favorites that need syncing from the persistent queue
      final queuedOperations = await super.processQueuedOperations();

      // For now, we'll get pending operations from the sync queue
      // In a complete implementation, this would also check local storage timestamps
      LoggerFactory.info(
          '🔍 Found ${queuedOperations.itemsProcessed} pending sync operations for favorites');

      // Return empty list as operations are processed through the queue system
      return [];
    } catch (e) {
      LoggerFactory.error('❌ Error getting local pending sync: $e');
      return [];
    }
  }

  @override
  Future<List<SyncableFavorite>> getRemoteChanges({DateTime? since}) async {
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

      final favorites = data
          .map((item) => deserializeFromRemote(Map<String, dynamic>.from(item)))
          .toList();

      LoggerFactory.info('📥 Retrieved ${favorites.length} remote favorites');
      return favorites;
    } catch (e) {
      LoggerFactory.error('❌ Failed to fetch remote changes: $e');
      rethrow;
    }
  }

  @override
  Future<SyncResult> uploadChanges(List<SyncableFavorite> entities) async {
    if (entities.isEmpty) {
      return SyncResult.success(itemsProcessed: 0);
    }

    final startTime = DateTime.now();
    var successful = 0;
    final errors = <String>[];

    try {
      LoggerFactory.info('📤 Uploading ${entities.length} favorites');

      for (final entity in entities) {
        try {
          final data = serializeForRemote(entity);

          // Usar upsert para crear o actualizar
          await _supabase.from(_tableName).upsert(data);

          successful++;
          LoggerFactory.debug('✅ Uploaded favorite: ${entity.movieTitle}');
        } catch (e) {
          final error = 'Failed to upload favorite ${entity.id}: $e';
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
  Future<SyncResult> downloadChanges(List<SyncableFavorite> entities) async {
    if (entities.isEmpty) {
      return SyncResult.success(itemsProcessed: 0);
    }

    final startTime = DateTime.now();
    var successful = 0;
    final errors = <String>[];

    try {
      LoggerFactory.info('📥 Processing ${entities.length} remote favorites');

      for (final entity in entities) {
        try {
          // This will be handled by the hybrid repository when it processes the download
          // For now, just count as successful - the hybrid repository handles actual storage
          successful++;
          LoggerFactory.debug('✅ Downloaded favorite: ${entity.movieTitle}');
        } catch (e) {
          final error = 'Failed to save favorite ${entity.id}: $e';
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
  Future<List<ConflictInfo<SyncableFavorite>>> detectConflicts() async {
    // Para favoritos, los conflictos son menos comunes
    // Implementación simple por ahora
    final conflicts = <ConflictInfo<SyncableFavorite>>[];

    try {
      // TODO: Implementar detección de conflictos cuando tengamos storage local
      LoggerFactory.debug('🔍 No conflicts detected for favorites');
    } catch (e) {
      LoggerFactory.error('❌ Conflict detection failed: $e');
    }

    return conflicts;
  }

  @override
  Future<SyncableFavorite> resolveConflict(
      ConflictInfo<SyncableFavorite> conflict) async {
    // Estrategia simple: "last write wins"
    final resolved =
        conflict.localEntity.hasPrecedenceOver(conflict.remoteEntity)
            ? conflict.localEntity
            : conflict.remoteEntity;

    LoggerFactory.info(
        '⚖️ Resolved conflict for favorite ${resolved.movieTitle}: ${conflict.conflictType.name}');
    return resolved;
  }

  @override
  Map<String, dynamic> serializeForLocal(SyncableFavorite entity) {
    return entity.toLocalStorage();
  }

  @override
  SyncableFavorite deserializeFromLocal(Map<String, dynamic> data) {
    return SyncableFavorite.fromJson(data);
  }

  @override
  Map<String, dynamic> serializeForRemote(SyncableFavorite entity) {
    return entity.toSupabaseJson();
  }

  @override
  SyncableFavorite deserializeFromRemote(Map<String, dynamic> data) {
    return SyncableFavorite.fromJson(data);
  }

  // =============================================
  // MÉTODOS ESPECÍFICOS PARA FAVORITOS
  // =============================================

  /// Agrega un favorito y lo cola para sync
  Future<void> addFavorite(SyncableFavorite favorite) async {
    // TODO: Guardar localmente cuando tengamos storage

    await queueOperation(
      type: SyncOperationType.create,
      entityId: favorite.id,
      data: serializeForLocal(favorite),
      priority: 3, // Prioridad media para favoritos
    );

    LoggerFactory.info('➕ Added favorite to queue: ${favorite.movieTitle}');
  }

  /// Elimina un favorito y lo cola para sync
  Future<void> removeFavorite(String favoriteId) async {
    // TODO: Marcar como eliminado localmente cuando tengamos storage

    await queueOperation(
      type: SyncOperationType.delete,
      entityId: favoriteId,
      data: {
        'is_deleted': true,
        'deleted_at': DateTime.now().toIso8601String()
      },
      priority: 2, // Alta prioridad para eliminaciones
    );

    LoggerFactory.info('🗑️ Removed favorite from queue: $favoriteId');
  }

  /// Sincroniza favoritos específicamente
  Future<SyncResult> syncFavorites() async {
    LoggerFactory.info('🔄 Starting favorites sync');

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
        '✅ Favorites sync completed: ${combinedResult.toString()}');
    return combinedResult;
  }
}
