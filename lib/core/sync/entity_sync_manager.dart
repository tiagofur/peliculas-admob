import 'dart:async';

import '../logging/logger_factory.dart';
import '../../domain/entities/sync_result.dart';
import '../../domain/entities/syncable_entity.dart';
import 'persistent_sync_queue.dart';
import 'sync_operation.dart';
import 'sync_utilities.dart';

/// Eventos de progreso de sincronización
class SyncProgressEvent {
  const SyncProgressEvent({
    required this.entityType,
    required this.phase,
    required this.currentItem,
    required this.totalItems,
    this.message,
    this.error,
  });

  final String entityType;
  final SyncPhase phase;
  final int currentItem;
  final int totalItems;
  final String? message;
  final String? error;

  double get progress => totalItems > 0 ? currentItem / totalItems : 0.0;

  bool get isCompleted => currentItem >= totalItems;
}

/// Fases de sincronización
enum SyncPhase {
  detecting('detecting_changes'),
  uploading('uploading'),
  downloading('downloading'),
  resolving('resolving_conflicts'),
  completed('completed');

  const SyncPhase(this.value);
  final String value;
}

/// Estadísticas de sincronización por entidad
class SyncStats {
  const SyncStats({
    required this.entityType,
    required this.totalEntities,
    required this.syncedEntities,
    required this.failedEntities,
    required this.lastSyncAt,
    this.averageSyncTime,
    this.conflictsDetected = 0,
    this.conflictsResolved = 0,
  });

  final String entityType;
  final int totalEntities;
  final int syncedEntities;
  final int failedEntities;
  final DateTime lastSyncAt;
  final Duration? averageSyncTime;
  final int conflictsDetected;
  final int conflictsResolved;

  double get successRate =>
      totalEntities > 0 ? syncedEntities / totalEntities : 0.0;

  bool get hasFailures => failedEntities > 0;
  bool get hasConflicts => conflictsDetected > 0;
}

/// Información de conflicto detectado
class ConflictInfo<T extends SyncableEntity> {
  const ConflictInfo({
    required this.localEntity,
    required this.remoteEntity,
    required this.conflictType,
    required this.detectedAt,
    this.resolution,
    this.metadata,
  });

  final T localEntity;
  final T remoteEntity;
  final ConflictType conflictType;
  final DateTime detectedAt;
  final ConflictResolution? resolution;
  final Map<String, dynamic>? metadata;

  bool get isResolved => resolution != null;

  String get conflictDescription {
    switch (conflictType) {
      case ConflictType.concurrentModification:
        return 'Both local and remote entities were modified';
      case ConflictType.deleteVsModify:
        return 'One version deleted while other was modified';
      case ConflictType.duplicateCreation:
        return 'Same entity created on multiple devices';
    }
  }
}

/// Tipos de conflicto
enum ConflictType {
  concurrentModification,
  deleteVsModify,
  duplicateCreation,
}

/// Resolución de conflicto
class ConflictResolution {
  const ConflictResolution({
    required this.strategy,
    required this.resolvedAt,
    required this.resolvedEntity,
    this.reason,
  });

  final ConflictStrategy strategy;
  final DateTime resolvedAt;
  final SyncableEntity resolvedEntity;
  final String? reason;
}

/// Estrategias de resolución de conflictos
enum ConflictStrategy {
  localWins,
  remoteWins,
  merge,
  userChoice,
}

/// Gestor abstracto base para sincronización de entidades
abstract class EntitySyncManager<T extends SyncableEntity> {
  EntitySyncManager({
    required this.entityType,
    required this.userId,
    PersistentSyncQueue? syncQueue,
  }) : _syncQueue = syncQueue ?? PersistentSyncQueue(userId: userId) {
    _initialize();
  }

  final String entityType;
  final String userId;
  final PersistentSyncQueue _syncQueue;

  final StreamController<SyncProgressEvent> _progressController =
      StreamController<SyncProgressEvent>.broadcast();

  bool _isInitialized = false;
  DateTime? _lastSyncAt;
  SyncStats? _lastStats;

  /// Stream de eventos de progreso
  Stream<SyncProgressEvent> get syncProgress => _progressController.stream;

  /// Indica si el manager está inicializado
  bool get isInitialized => _isInitialized;

  /// Fecha de la última sincronización
  DateTime? get lastSyncAt => _lastSyncAt;

  /// Últimas estadísticas de sincronización
  SyncStats? get lastStats => _lastStats;

  /// Inicialización del manager
  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      await _loadLastSyncInfo();
      _isInitialized = true;

      LoggerFactory.info('✅ EntitySyncManager initialized for $entityType');
    } catch (e) {
      LoggerFactory.error('❌ Failed to initialize EntitySyncManager: $e');
      _isInitialized = true; // Continue even if loading fails
    }
  }

  /// Carga información de la última sincronización
  Future<void> _loadLastSyncInfo() async {
    // Implementación específica en clases derivadas si es necesario
  }

  // =============================================
  // OPERACIONES ABSTRACTAS - IMPLEMENTAR EN SUBCLASES
  // =============================================

  /// Obtiene entidades locales que necesitan sincronización
  Future<List<T>> getLocalPendingSync({DateTime? since});

  /// Obtiene cambios remotos desde el servidor
  Future<List<T>> getRemoteChanges({DateTime? since});

  /// Sube cambios locales al servidor
  Future<SyncResult> uploadChanges(List<T> entities);

  /// Descarga y aplica cambios remotos
  Future<SyncResult> downloadChanges(List<T> entities);

  /// Detecta conflictos entre entidades local y remota
  Future<List<ConflictInfo<T>>> detectConflicts();

  /// Resuelve un conflicto específico
  Future<T> resolveConflict(ConflictInfo<T> conflict);

  /// Serializa entidad para almacenamiento local
  Map<String, dynamic> serializeForLocal(T entity);

  /// Deserializa entidad desde almacenamiento local
  T deserializeFromLocal(Map<String, dynamic> data);

  /// Serializa entidad para envío al servidor
  Map<String, dynamic> serializeForRemote(T entity);

  /// Deserializa entidad desde servidor
  T deserializeFromRemote(Map<String, dynamic> data);

  /// Elimina una entidad por ID
  Future<void> deleteEntity(String entityId);

  /// Obtiene una entidad remota por ID
  Future<Map<String, dynamic>?> getRemoteEntity(String entityId);

  /// Fusiona dos entidades (local y remota)
  Future<T> mergeEntities(T localEntity, T remoteEntity);

  // =============================================
  // OPERACIONES PÚBLICAS
  // =============================================

  /// Ejecuta sincronización completa bidireccional
  Future<SyncResult> performFullSync() async {
    if (!_isInitialized) await _initialize();

    final startTime = DateTime.now();
    var totalProcessed = 0;
    var totalSuccessful = 0;
    final errors = <String>[];

    try {
      LoggerFactory.info('🔄 Starting full sync for $entityType');

      // Fase 1: Detectar cambios locales
      _emitProgress(SyncPhase.detecting, 0, 4, 'Detecting local changes');
      final localChanges = await getLocalPendingSync();
      totalProcessed += localChanges.length;

      // Fase 2: Subir cambios locales
      if (localChanges.isNotEmpty) {
        _emitProgress(SyncPhase.uploading, 1, 4,
            'Uploading ${localChanges.length} local changes');
        final uploadResult = await uploadChanges(localChanges);
        totalSuccessful += uploadResult.itemsSuccessful;
        errors.addAll(uploadResult.errors);
      }

      // Fase 3: Detectar y descargar cambios remotos
      _emitProgress(SyncPhase.downloading, 2, 4, 'Downloading remote changes');
      final remoteChanges = await getRemoteChanges(since: _lastSyncAt);

      if (remoteChanges.isNotEmpty) {
        final downloadResult = await downloadChanges(remoteChanges);
        totalProcessed += remoteChanges.length;
        totalSuccessful += downloadResult.itemsSuccessful;
        errors.addAll(downloadResult.errors);
      }

      // Fase 4: Detectar y resolver conflictos
      _emitProgress(SyncPhase.resolving, 3, 4, 'Resolving conflicts');
      final conflicts = await detectConflicts();

      for (final conflict in conflicts) {
        try {
          await resolveConflict(conflict);
        } catch (e) {
          errors.add('Conflict resolution failed: $e');
        }
      }

      // Completar sincronización
      _emitProgress(SyncPhase.completed, 4, 4, 'Sync completed');
      _lastSyncAt = DateTime.now();

      final result = errors.isEmpty
          ? SyncResult.success(
              itemsProcessed: totalProcessed,
              itemsSuccessful: totalSuccessful,
              duration: DateTime.now().difference(startTime),
              message: 'Full sync completed successfully',
            )
          : SyncResult.failure(
              itemsProcessed: totalProcessed,
              itemsSuccessful: totalSuccessful,
              errors: errors,
              duration: DateTime.now().difference(startTime),
              message: 'Sync completed with errors',
            );

      await _updateSyncStats(result);
      LoggerFactory.info(
          '✅ Full sync completed for $entityType: ${result.toString()}');

      return result;
    } catch (e) {
      final error = 'Full sync failed for $entityType: $e';
      LoggerFactory.error(error);

      return SyncResult.failure(
        itemsProcessed: totalProcessed,
        itemsSuccessful: totalSuccessful,
        errors: [error],
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  /// Ejecuta sincronización incremental
  Future<SyncResult> performIncrementalSync() async {
    if (!_isInitialized) await _initialize();

    final startTime = DateTime.now();
    var totalProcessed = 0;
    var totalSuccessful = 0;
    final errors = <String>[];

    try {
      LoggerFactory.info('🔄 Starting incremental sync for $entityType');

      // Solo sincronizar cambios desde la última sincronización
      final lastSync = _lastSyncAt ?? DateTime.now().subtract(const Duration(hours: 24));
      
      // Fase 1: Subir cambios locales pendientes
      _emitProgress(SyncPhase.uploading, 0, 2, 'Uploading pending changes');
      final localChanges = await getLocalPendingSync();
      
      if (localChanges.isNotEmpty) {
        final uploadResult = await uploadChanges(localChanges);
        totalProcessed += localChanges.length;
        totalSuccessful += uploadResult.itemsSuccessful;
        errors.addAll(uploadResult.errors);
      }

      // Fase 2: Descargar solo cambios remotos recientes
      _emitProgress(SyncPhase.downloading, 1, 2, 'Downloading recent changes');
      final recentChanges = await getRemoteChanges(since: lastSync);
      
      if (recentChanges.isNotEmpty) {
        final downloadResult = await downloadChanges(recentChanges);
        totalProcessed += recentChanges.length;
        totalSuccessful += downloadResult.itemsSuccessful;
        errors.addAll(downloadResult.errors);
      }

      _emitProgress(SyncPhase.completed, 2, 2, 'Incremental sync completed');
      _lastSyncAt = DateTime.now();

      final result = errors.isEmpty
          ? SyncResult.success(
              itemsProcessed: totalProcessed,
              itemsSuccessful: totalSuccessful,
              duration: DateTime.now().difference(startTime),
              message: 'Incremental sync completed successfully',
            )
          : SyncResult.failure(
              itemsProcessed: totalProcessed,
              itemsSuccessful: totalSuccessful,
              errors: errors,
              duration: DateTime.now().difference(startTime),
              message: 'Incremental sync completed with errors',
            );

      await _updateSyncStats(result);
      LoggerFactory.info('✅ Incremental sync completed for $entityType: ${result.toString()}');

      return result;
    } catch (e) {
      final error = 'Incremental sync failed for $entityType: $e';
      LoggerFactory.error(error);

      return SyncResult.failure(
        itemsProcessed: totalProcessed,
        itemsSuccessful: totalSuccessful,
        errors: [error],
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  /// Cola una operación para sincronización posterior
  Future<void> queueOperation({
    required SyncOperationType type,
    required String entityId,
    required Map<String, dynamic> data,
    int priority = 5,
  }) async {
    if (!_isInitialized) await _initialize();

    final operation = SyncOperation.create(
      entityType: entityType,
      entityId: entityId,
      type: type,
      data: data,
      userId: userId,
      priority: priority,
      deviceId: await SyncUtilities.getDeviceId(),
    );

    await _syncQueue.enqueue(operation);
    LoggerFactory.info('📋 Queued $type operation for $entityType($entityId)');
  }

  /// Procesa operaciones en cola para esta entidad
  Future<SyncResult> processQueuedOperations() async {
    if (!_isInitialized) await _initialize();

    final operations = await _syncQueue.getOperationsByType(entityType);
    final readyOperations =
        operations.where((op) => op.isReadyToExecute).toList();

    if (readyOperations.isEmpty) {
      return SyncResult.success(itemsProcessed: 0);
    }

    final startTime = DateTime.now();
    var successful = 0;
    final errors = <String>[];

    LoggerFactory.info(
        '🔄 Processing ${readyOperations.length} queued operations for $entityType');

    for (final operation in readyOperations) {
      try {
        await _syncQueue.updateOperation(operation.markAsProcessing());

        // Procesar según el tipo de operación
        switch (operation.type) {
          case SyncOperationType.create:
          case SyncOperationType.update:
            final entity = deserializeFromLocal(operation.data);
            final result = await uploadChanges([entity]);

            if (result.success) {
              await _syncQueue.markCompleted(operation.id);
              successful++;
            } else {
              await _syncQueue.markFailed(
                  operation.id, result.errors.join(', '));
              errors.addAll(result.errors);
            }
            break;

          case SyncOperationType.delete:
            try {
              // Eliminar entidad localmente y remotamente
              await deleteEntity(operation.entityId);
              await _syncQueue.markCompleted(operation.id);
              successful++;
              LoggerFactory.info('🗑️ Deleted entity ${operation.entityId}');
            } catch (e) {
              await _syncQueue.markFailed(operation.id, 'Delete failed: $e');
              errors.add('Delete operation failed for ${operation.entityId}: $e');
            }
            break;

          case SyncOperationType.merge:
            try {
              // Fusionar datos locales y remotos
              final localEntity = deserializeFromLocal(operation.data);
              final remoteData = await getRemoteEntity(operation.entityId);
              
              if (remoteData != null) {
                final remoteEntity = deserializeFromRemote(remoteData);
                final mergedEntity = await mergeEntities(localEntity, remoteEntity);
                final result = await uploadChanges([mergedEntity]);
                
                if (result.success) {
                  await _syncQueue.markCompleted(operation.id);
                  successful++;
                  LoggerFactory.info('🔀 Merged entity ${operation.entityId}');
                } else {
                  await _syncQueue.markFailed(operation.id, result.errors.join(', '));
                  errors.addAll(result.errors);
                }
              } else {
                // Si no hay datos remotos, subir los locales
                final result = await uploadChanges([localEntity]);
                if (result.success) {
                  await _syncQueue.markCompleted(operation.id);
                  successful++;
                } else {
                  await _syncQueue.markFailed(operation.id, result.errors.join(', '));
                  errors.addAll(result.errors);
                }
              }
            } catch (e) {
              await _syncQueue.markFailed(operation.id, 'Merge failed: $e');
              errors.add('Merge operation failed for ${operation.entityId}: $e');
            }
            break;
        }
      } catch (e) {
        final error = 'Operation ${operation.id} failed: $e';
        await _syncQueue.markFailed(operation.id, error);
        errors.add(error);
      }
    }

    final result = SyncResult(
      success: errors.isEmpty,
      itemsProcessed: readyOperations.length,
      itemsSuccessful: successful,
      itemsFailed: readyOperations.length - successful,
      errors: errors,
      duration: DateTime.now().difference(startTime),
    );

    LoggerFactory.info(
        '✅ Processed queued operations for $entityType: ${result.toString()}');
    return result;
  }

  /// Obtiene estadísticas de sincronización
  Future<SyncStats> getSyncStatistics() async {
    if (_lastStats != null) return _lastStats!;

    // Generar estadísticas básicas
    return SyncStats(
      entityType: entityType,
      totalEntities: 0,
      syncedEntities: 0,
      failedEntities: 0,
      lastSyncAt: _lastSyncAt ?? DateTime.now(),
    );
  }

  // =============================================
  // MÉTODOS PRIVADOS
  // =============================================

  /// Emite evento de progreso
  void _emitProgress(SyncPhase phase, int current, int total, String? message) {
    final event = SyncProgressEvent(
      entityType: entityType,
      phase: phase,
      currentItem: current,
      totalItems: total,
      message: message,
    );

    _progressController.add(event);
  }

  /// Actualiza estadísticas de sincronización
  Future<void> _updateSyncStats(SyncResult result) async {
    _lastStats = SyncStats(
      entityType: entityType,
      totalEntities: result.itemsProcessed,
      syncedEntities: result.itemsSuccessful,
      failedEntities: result.itemsFailed,
      lastSyncAt: DateTime.now(),
      averageSyncTime: result.duration,
    );
  }

  /// Limpia recursos
  Future<void> dispose() async {
    await _progressController.close();
  }
}
