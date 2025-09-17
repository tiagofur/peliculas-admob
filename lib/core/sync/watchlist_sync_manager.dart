import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/sync_result.dart';
import '../../domain/entities/syncable_watchlist_item.dart';
import '../../domain/entities/watchlist_movie.dart';
import '../../infrastructure/datasources/watchlist_hive_datasource.dart';
import '../logging/logger_factory.dart';
import 'entity_sync_manager.dart';
import 'sync_operation.dart';

/// Implementación específica del EntitySyncManager para watchlist
class WatchlistSyncManager extends EntitySyncManager<SyncableWatchlistItem> {
  WatchlistSyncManager({
    required super.userId,
    SupabaseClient? supabaseClient,
  })  : _supabase = supabaseClient ?? Supabase.instance.client,
        super(entityType: 'watchlist');
  final WatchlistHiveDatasource _localDatasource = WatchlistHiveDatasource();

  final SupabaseClient _supabase;
  static const String _tableName = 'user_watchlist';

  // =============================================
  // IMPLEMENTACIONES REQUERIDAS
  // =============================================

  @override
  Future<List<SyncableWatchlistItem>> getLocalPendingSync(
      {DateTime? since}) async {
    try {
      // Get local watchlist items that need syncing from the persistent queue
      final queuedOperations = await super.processQueuedOperations();

      // For now, we'll get pending operations from the sync queue
      // In a complete implementation, this would also check local storage timestamps
      LoggerFactory.info(
          '🔍 Found ${queuedOperations.itemsProcessed} pending sync operations for watchlist');

      // Return empty list as operations are processed through the queue system
      return [];
    } catch (e) {
      LoggerFactory.error('❌ Error getting local pending sync: $e');
      return [];
    }
  }

  @override
  Future<List<SyncableWatchlistItem>> getRemoteChanges(
      {DateTime? since}) async {
    try {
      final response = since != null
          ? await _supabase
              .from(_tableName)
              .select()
              .eq('user_id', userId)
              .filter('last_modified_at', 'gte', since.toIso8601String())
              .order('last_modified_at', ascending: false)
          : await _supabase
              .from(_tableName)
              .select()
              .eq('user_id', userId)
              .order('last_modified_at', ascending: false);

      if (since != null) {
        LoggerFactory.info(
            '📅 Fetching remote changes since: ${since.toIso8601String()}');
      } else {
        LoggerFactory.info('📅 Fetching all remote changes (no date filter)');
      }
      final List<dynamic> data = response as List<dynamic>;

      final watchlistItems = data
          .map((item) => deserializeFromRemote(Map<String, dynamic>.from(item)))
          .toList();

      LoggerFactory.info(
          '📥 Retrieved ${watchlistItems.length} remote watchlist items');
      return watchlistItems;
    } catch (e) {
      LoggerFactory.error('❌ Failed to fetch remote watchlist changes: $e');
      rethrow;
    }
  }

  @override
  Future<SyncResult> uploadChanges(List<SyncableWatchlistItem> entities) async {
    if (entities.isEmpty) {
      return SyncResult.success(itemsProcessed: 0);
    }

    final startTime = DateTime.now();
    var successful = 0;
    final errors = <String>[];

    try {
      LoggerFactory.info('📤 Uploading ${entities.length} watchlist items');

      for (final entity in entities) {
        try {
          final data = serializeForRemote(entity);

          // Usar upsert para crear o actualizar
          await _supabase.from(_tableName).upsert(data);

          successful++;
          LoggerFactory.debug(
              '✅ Uploaded watchlist item: ${entity.movieTitle}');
        } catch (e) {
          final error = 'Failed to upload watchlist item ${entity.id}: $e';
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

      LoggerFactory.info('📤 Watchlist upload completed: ${result.toString()}');
      return result;
    } catch (e) {
      LoggerFactory.error('❌ Watchlist upload batch failed: $e');
      return SyncResult.failure(
        itemsProcessed: entities.length,
        errors: ['Batch upload failed: $e'],
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  @override
  Future<SyncResult> downloadChanges(
      List<SyncableWatchlistItem> entities) async {
    if (entities.isEmpty) {
      return SyncResult.success(itemsProcessed: 0);
    }

    final startTime = DateTime.now();
    var successful = 0;
    final errors = <String>[];

    try {
      LoggerFactory.info(
          '📥 Processing ${entities.length} remote watchlist items');

      for (final entity in entities) {
        try {
          // This will be handled by the hybrid repository when it processes the download
          // For now, just count as successful - the hybrid repository handles actual storage
          successful++;
          LoggerFactory.debug(
              '✅ Downloaded watchlist item: ${entity.movieTitle}');
        } catch (e) {
          final error = 'Failed to save watchlist item ${entity.id}: $e';
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

      LoggerFactory.info(
          '📥 Watchlist download completed: ${result.toString()}');
      return result;
    } catch (e) {
      LoggerFactory.error('❌ Watchlist download batch failed: $e');
      return SyncResult.failure(
        itemsProcessed: entities.length,
        errors: ['Batch download failed: $e'],
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  @override
  Future<List<ConflictInfo<SyncableWatchlistItem>>> detectConflicts() async {
    try {
      final conflicts = <ConflictInfo<SyncableWatchlistItem>>[];

      // Obtener elementos locales de la watchlist
      final localMovies = await _localDatasource.loadWatchlistMovies();

      // Obtener cambios remotos para comparar
      final remoteItems = await getRemoteChanges();

      for (final remoteItem in remoteItems) {
        // Buscar si existe localmente
        final localMovie = localMovies.cast<dynamic>().firstWhere(
              (movie) => movie?.movie?.id == remoteItem.movieId,
              orElse: () => null,
            );

        // Detectar conflicto si ambos existen pero tienen diferentes timestamps
        final localTimestamp = localMovie?.addedDate ?? DateTime.now();
        final remoteTimestamp = remoteItem.lastModifiedAt;

        // Si las fechas difieren significativamente (más de 1 segundo), hay conflicto
        if (localMovie != null &&
            (localTimestamp.difference(remoteTimestamp).abs().inSeconds > 1)) {
          conflicts.add(ConflictInfo<SyncableWatchlistItem>(
            localEntity: SyncableWatchlistItem.fromWatchlistMovie(
              userId: userId,
              watchlistMovie: localMovie,
            ),
            remoteEntity: remoteItem,
            conflictType: ConflictType.concurrentModification,
            detectedAt: DateTime.now(),
          ));
        }
      }

      LoggerFactory.debug(
          '🔍 Detected ${conflicts.length} watchlist conflicts');
      return conflicts;
    } catch (e) {
      LoggerFactory.error('❌ Watchlist conflict detection failed: $e');
      return [];
    }
  }

  @override
  Future<SyncableWatchlistItem> resolveConflict(
      ConflictInfo<SyncableWatchlistItem> conflict) async {
    // Estrategia simple: "last write wins" pero mantiene la fecha de adición original
    final resolved =
        conflict.localEntity.hasPrecedenceOver(conflict.remoteEntity)
            ? conflict.localEntity
            : conflict.remoteEntity.copyWithData(
                addedAt: conflict
                    .localEntity.addedAt, // Mantener fecha original de adición
              );

    LoggerFactory.info(
        '⚖️ Resolved watchlist conflict for ${resolved.movieTitle}: ${conflict.conflictType.name}');
    return resolved;
  }

  @override
  Map<String, dynamic> serializeForLocal(SyncableWatchlistItem entity) {
    return entity.toLocalStorage();
  }

  @override
  SyncableWatchlistItem deserializeFromLocal(Map<String, dynamic> data) {
    return SyncableWatchlistItem.fromJson(data);
  }

  @override
  Map<String, dynamic> serializeForRemote(SyncableWatchlistItem entity) {
    return entity.toSupabaseJson();
  }

  @override
  SyncableWatchlistItem deserializeFromRemote(Map<String, dynamic> data) {
    return SyncableWatchlistItem.fromJson(data);
  }

  // =============================================
  // MÉTODOS ESPECÍFICOS PARA WATCHLIST
  // =============================================

  /// Agrega un item a la watchlist y lo cola para sync
  Future<void> addWatchlistItem(SyncableWatchlistItem item) async {
    await queueOperation(
      type: SyncOperationType.create,
      entityId: item.id,
      data: serializeForLocal(item),
      priority: item.syncPriority,
    );

    LoggerFactory.info(
        '➕ Added watchlist item to queue: ${item.movieTitle} (${item.priority.name})');
  }

  /// Actualiza un item de la watchlist y lo cola para sync
  Future<void> updateWatchlistItem(SyncableWatchlistItem item) async {
    await queueOperation(
      type: SyncOperationType.update,
      entityId: item.id,
      data: serializeForLocal(item),
      priority: item.syncPriority,
    );

    LoggerFactory.info(
        '🔄 Updated watchlist item in queue: ${item.movieTitle} (${item.priority.name})');
  }

  /// Elimina un item de la watchlist y lo cola para sync
  Future<void> removeWatchlistItem(String itemId) async {
    await queueOperation(
      type: SyncOperationType.delete,
      entityId: itemId,
      data: {}, // No necesitamos datos adicionales para hard delete
      priority: 2, // Alta prioridad para eliminaciones
    );

    LoggerFactory.info('🗑️ Removed watchlist item from queue: $itemId');
  }

  /// Sincroniza watchlist específicamente
  Future<SyncResult> syncWatchlist() async {
    LoggerFactory.info('🔄 Starting watchlist sync');

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
        '✅ Watchlist sync completed: ${combinedResult.toString()}');
    return combinedResult;
  }

  /// Cambia la prioridad de un item específico
  Future<void> changePriority(int movieId, int newPriority) async {
    try {
      // Obtener el elemento actual del almacenamiento local
      final localMovies = await _localDatasource.loadWatchlistMovies();
      final currentMovie = localMovies.firstWhere(
        (movie) => movie.movieId == movieId,
        orElse: () => throw Exception('Movie $movieId not found in watchlist'),
      );

      // Actualizar la prioridad localmente (convertir int a WatchlistPriority)
      final priorityEnum = _convertIntToPriority(newPriority);
      await _localDatasource.updateWatchlistPriority(movieId, priorityEnum);

      // Crear el item sincronizable con los datos actuales
      final now = DateTime.now();
      final currentItem = SyncableWatchlistItem(
        id: 'watchlist_${movieId}_$userId',
        movieId: movieId,
        movieTitle: currentMovie.movieTitle,
        userId: userId,
        priority: priorityEnum,
        addedAt: currentMovie.addedAt,
        createdAt: now,
        lastModifiedAt: now,
      );

      await queueOperation(
        type: SyncOperationType.update,
        entityId: currentItem.id,
        data: serializeForLocal(currentItem),
        priority: 5, // Prioridad media para cambios de prioridad
      );

      LoggerFactory.info(
          '🔄 Changed watchlist item priority: $movieId -> $newPriority');
    } catch (e) {
      LoggerFactory.error('❌ Failed to change watchlist priority: $e');
      rethrow;
    }
  }

  // =============================================
  // MÉTODOS ABSTRACTOS REQUERIDOS
  // =============================================

  @override
  Future<void> deleteEntity(String entityId) async {
    try {
      await _supabase.from(_tableName).delete().eq('id', entityId);

      LoggerFactory.info('🗑️ Deleted watchlist entity: $entityId');
    } catch (e) {
      LoggerFactory.error('❌ Failed to delete watchlist entity $entityId: $e');
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
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      LoggerFactory.error(
          '❌ Failed to get remote watchlist entity $entityId: $e');
      return null;
    }
  }

  @override
  Future<SyncableWatchlistItem> mergeEntities(SyncableWatchlistItem localEntity,
      SyncableWatchlistItem remoteEntity) async {
    // Estrategia simple: usar la entidad con timestamp más reciente
    final localTimestamp = localEntity.lastModifiedAt;
    final remoteTimestamp = remoteEntity.lastModifiedAt;

    if (localTimestamp.isAfter(remoteTimestamp)) {
      LoggerFactory.info(
          '🔀 Merged watchlist: keeping local version for ${localEntity.movieTitle}');
      return localEntity;
    } else {
      LoggerFactory.info(
          '🔀 Merged watchlist: keeping remote version for ${remoteEntity.movieTitle}');
      return remoteEntity;
    }
  }

  /// Convierte un int a WatchlistPriority
  WatchlistPriority _convertIntToPriority(int priority) {
    switch (priority) {
      case 0:
      case 1:
        return WatchlistPriority.alta;
      case 2:
        return WatchlistPriority.normal;
      case 3:
      default:
        return WatchlistPriority.baja;
    }
  }
}
