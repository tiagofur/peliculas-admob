import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logging/logger_factory.dart';
import '../../core/sync/entity_sync_manager.dart';
import '../../core/sync/sync_coordinator.dart';
import '../../core/sync/sync_operation.dart';
import '../../domain/entities/sync_result.dart';
import '../../domain/entities/syncable_entity.dart';
import '../../domain/repositories/syncable_repository.dart';

/// Clase base para repositorios híbridos que combinan almacenamiento local y remoto
/// con sincronización automática usando el sistema de sync de Fase 3
abstract class BaseHybridRepository<T extends SyncableEntity>
    implements SyncableRepository<T> {
  BaseHybridRepository({
    required this.userId,
    required this.entityType,
    EntitySyncManager<T>? syncManager,
    SyncCoordinator? syncCoordinator,
  })  : _syncManager = syncManager,
        _syncCoordinator = syncCoordinator {
    _initialize();
  }

  final String userId;
  final String entityType;
  final EntitySyncManager<T>? _syncManager;
  final SyncCoordinator? _syncCoordinator;
  RealtimeChannel? _realtimeChannel;

  final StreamController<RepositoryEvent<T>> _eventController =
      StreamController<RepositoryEvent<T>>.broadcast();

  bool _isInitialized = false;

  /// Stream de eventos del repositorio
  Stream<RepositoryEvent<T>> get events => _eventController.stream;

  /// Indica si el repositorio está inicializado
  bool get isInitialized => _isInitialized;

  /// Accessor protegido para el sync manager
  @protected
  EntitySyncManager<T>? get syncManager => _syncManager;

  /// Inicialización del repositorio
  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      await initializeLocal();
      _isInitialized = true;
      _setupRealtimeSubscription();

      _emitEvent(RepositoryEventType.initialized, 'Repository initialized');
      LoggerFactory.info('✅ BaseHybridRepository<$entityType> initialized');
    } catch (e) {
      LoggerFactory.error('❌ Failed to initialize repository: $e');
      _isInitialized = true; // Continue even if initialization fails
    }
  }

  // =============================================
  // MÉTODOS ABSTRACTOS - IMPLEMENTAR EN SUBCLASES
  // =============================================

  /// Devuelve el nombre de la tabla de Supabase para la entidad
  String get tableName;

  /// Deserializa los datos de Supabase a una entidad
  T deserializeFromRemote(Map<String, dynamic> data);

  /// Inicializa el almacenamiento local
  Future<void> initializeLocal();

  /// Obtiene todos los elementos desde almacenamiento local
  @override
  Future<List<T>> getLocalData();

  /// Guarda un elemento en almacenamiento local
  Future<void> saveToLocal(T entity);

  /// Elimina un elemento del almacenamiento local
  Future<void> removeFromLocal(String id);

  /// Actualiza un elemento en almacenamiento local
  Future<void> updateLocal(T entity);

  /// Convierte entidad a modelo de dominio para la UI
  dynamic convertToModel(T entity);

  /// Convierte modelo de dominio a entidad sincronizable
  T convertFromModel(dynamic model, String userId);

  // =============================================
  // IMPLEMENTACIÓN DE SyncableRepository
  // =============================================

  @override
  Future<void> syncWithSupabase() async {
    if (!_isInitialized) await _initialize();

    if (_syncManager != null) {
      LoggerFactory.info(
          '🔄 Starting sync for $entityType via EntitySyncManager');

      try {
        _emitEvent(RepositoryEventType.syncStarted, 'Sync started');

        final result = await _syncManager!.performFullSync();

        _emitEvent(
          result.success
              ? RepositoryEventType.syncCompleted
              : RepositoryEventType.syncError,
          'Sync ${result.success ? 'completed' : 'failed'}: ${result.toString()}',
          result: result,
        );

        LoggerFactory.info(
            '✅ Sync completed for $entityType: ${result.toString()}');
      } catch (e) {
        final error = 'Sync failed for $entityType: $e';
        LoggerFactory.error('❌ $error');
        _emitEvent(RepositoryEventType.syncError, error);
        rethrow;
      }
    } else {
      LoggerFactory.warning('⚠️ No sync manager available for $entityType');
    }
  }

  @override
  Future<List<T>> getRemoteData() async {
    if (_syncManager != null) {
      return await _syncManager!.getRemoteChanges();
    }
    return [];
  }

  @override
  Future<void> upload(List<T> items) async {
    if (_syncManager != null && items.isNotEmpty) {
      LoggerFactory.info('📤 Uploading ${items.length} $entityType items');

      final result = await _syncManager!.uploadChanges(items);

      LoggerFactory.info('📤 Upload result: ${result.toString()}');

      if (!result.success) {
        throw Exception('Upload failed: ${result.errors.join(', ')}');
      }
    }
  }

  @override
  Future<void> download(List<T> items) async {
    if (_syncManager != null && items.isNotEmpty) {
      LoggerFactory.info('📥 Downloading ${items.length} $entityType items');

      final result = await _syncManager!.downloadChanges(items);

      LoggerFactory.info('📥 Download result: ${result.toString()}');

      if (!result.success) {
        throw Exception('Download failed: ${result.errors.join(', ')}');
      }
    }
  }

  @override
  Future<void> resolveConflicts(List<T> local, List<T> remote) async {
    if (_syncManager != null) {
      LoggerFactory.info(
          '⚖️ Resolving conflicts between ${local.length} local and ${remote.length} remote $entityType items');

      final conflicts = await _syncManager!.detectConflicts();

      if (conflicts.isNotEmpty) {
        LoggerFactory.info('🔍 Found ${conflicts.length} conflicts to resolve');

        for (final conflict in conflicts) {
          try {
            final resolved = await _syncManager!.resolveConflict(conflict);
            await updateLocal(resolved);
            LoggerFactory.debug(
                '✅ Resolved conflict for $entityType: ${resolved.id}');
          } catch (e) {
            LoggerFactory.error('❌ Failed to resolve conflict: $e');
          }
        }
      }
    }
  }

  @override
  Future<bool> hasPendingSync() async {
    if (_syncCoordinator != null) {
      final stats = await _syncCoordinator!.getSyncStatistics();
      final queueStats = stats['queue'] as Map<String, dynamic>? ?? {};
      final readyCount = queueStats['ready_to_execute'] as int? ?? 0;
      return readyCount > 0;
    }
    return false;
  }

  @override
  Future<List<String>> getPendingSyncItems() async {
    if (_syncCoordinator != null) {
      final stats = await _syncCoordinator!.getSyncStatistics();
      final queueStats = stats['queue'] as Map<String, dynamic>? ?? {};
      final pendingItems = queueStats['pending_items'] as List<dynamic>? ?? [];
      return pendingItems.cast<String>();
    }
    return [];
  }

  // =============================================
  // OPERACIONES CRUD HÍBRIDAS
  // =============================================

  /// Agrega un elemento (local + queue para sync)
  Future<void> add(dynamic model) async {
    if (!_isInitialized) await _initialize();

    try {
      final entity = convertFromModel(model, userId);

      // Guardar localmente primero
      await saveToLocal(entity);

      // Cola para sincronización
      await _queueForSync(entity, SyncOperationType.create);

      _emitEvent(RepositoryEventType.itemAdded, 'Item added locally',
          entity: entity);
      LoggerFactory.info('➕ Added $entityType locally: ${entity.id}');

      // Intentar sincronizar inmediatamente si es posible
      await _tryImmediateSync();
    } catch (e) {
      LoggerFactory.error('❌ Failed to add $entityType: $e');
      _emitEvent(RepositoryEventType.error, 'Failed to add item: $e');
      rethrow;
    }
  }

  /// Actualiza un elemento (local + queue para sync)
  Future<void> update(dynamic model) async {
    if (!_isInitialized) await _initialize();

    try {
      final entity = convertFromModel(model, userId);

      // Actualizar localmente
      await updateLocal(entity);

      // Cola para sincronización
      await _queueForSync(entity, SyncOperationType.update);

      _emitEvent(RepositoryEventType.itemUpdated, 'Item updated locally',
          entity: entity);
      LoggerFactory.info('📝 Updated $entityType locally: ${entity.id}');

      // Intentar sincronizar inmediatamente si es posible
      await _tryImmediateSync();
    } catch (e) {
      LoggerFactory.error('❌ Failed to update $entityType: $e');
      _emitEvent(RepositoryEventType.error, 'Failed to update item: $e');
      rethrow;
    }
  }

  /// Elimina un elemento (soft delete local + queue para sync)
  Future<void> remove(String id) async {
    if (!_isInitialized) await _initialize();

    try {
      // Marcar como eliminado localmente
      await removeFromLocal(id);

      // Cola para sincronización de eliminación
      await _queueForSync(null, SyncOperationType.delete, entityId: id);

      _emitEvent(RepositoryEventType.itemRemoved, 'Item removed locally',
          entityId: id);
      LoggerFactory.info('🗑️ Removed $entityType locally: $id');

      // Intentar sincronizar inmediatamente si es posible
      await _tryImmediateSync();
    } catch (e) {
      LoggerFactory.error('❌ Failed to remove $entityType: $e');
      _emitEvent(RepositoryEventType.error, 'Failed to remove item: $e');
      rethrow;
    }
  }

  /// Obtiene todos los elementos priorizando datos de Supabase
  Future<List<dynamic>> getAll() async {
    if (!_isInitialized) await _initialize();

    try {
      // Intentar obtener datos remotos primero si hay conexión
      List<T> entities;
      
      try {
        if (_syncManager != null && userId != 'anonymous_user') {
          LoggerFactory.debug('🌐 Attempting to get remote data for $entityType');
          final remoteEntities = await _syncManager!.getRemoteChanges();
          
          if (remoteEntities.isNotEmpty) {
            // Actualizar datos locales con los remotos
            for (final entity in remoteEntities) {
              await saveToLocal(entity);
            }
            entities = remoteEntities;
            LoggerFactory.debug('✅ Using ${entities.length} remote $entityType items');
          } else {
            // Si no hay datos remotos, usar locales
            entities = await getLocalData();
            LoggerFactory.debug('📱 Using ${entities.length} local $entityType items (no remote data)');
          }
        } else {
          // Sin sync manager o usuario anónimo, usar solo datos locales
          entities = await getLocalData();
          LoggerFactory.debug('📱 Using ${entities.length} local $entityType items (no sync manager)');
        }
      } catch (remoteError) {
        // Si falla la obtención remota, usar datos locales como fallback
        LoggerFactory.warning('⚠️ Remote data fetch failed, using local fallback: $remoteError');
        entities = await getLocalData();
        LoggerFactory.debug('📱 Using ${entities.length} local $entityType items (remote fallback)');
      }

      final models = entities.map(convertToModel).toList();
      LoggerFactory.debug('📋 Retrieved ${models.length} $entityType items total');
      return models;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get $entityType items: $e');
      rethrow;
    }
  }

  /// Busca un elemento por ID
  Future<dynamic> getById(String id) async {
    final all = await getAll();
    try {
      // Asumiendo que el modelo tiene un campo 'id'
      return all.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Obtiene todos los elementos con sincronización forzada desde Supabase
  Future<List<dynamic>> getAllWithForcedSync() async {
    if (!_isInitialized) await _initialize();

    try {
      // Forzar sincronización completa primero
      if (_syncManager != null && userId != 'anonymous_user') {
        LoggerFactory.info('🔄 Forcing full sync before data retrieval for $entityType');
        await _syncManager!.performFullSync();
      }

      // Obtener datos actualizados
      final entities = await getLocalData();
      final models = entities.map(convertToModel).toList();

      LoggerFactory.debug('📋 Retrieved ${models.length} $entityType items after forced sync');
      return models;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get $entityType items with forced sync: $e');
      // Fallback a datos locales sin sync
      final entities = await getLocalData();
      return entities.map(convertToModel).toList();
    }
  }

  /// Fuerza sincronización inmediata
  Future<SyncResult> forceSync() async {
    if (!_isInitialized) await _initialize();

    if (_syncManager != null) {
      LoggerFactory.info('🔄 Force sync requested for $entityType');
      return await _syncManager!.performFullSync();
    } else {
      LoggerFactory.warning('⚠️ No sync manager available for forced sync');
      return SyncResult.success(
          itemsProcessed: 0, message: 'No sync manager available');
    }
  }

  // =============================================
  // MÉTODOS PRIVADOS
  // =============================================

  void _setupRealtimeSubscription() {
    if (userId == 'anonymous_user') return;

    _realtimeChannel = Supabase.instance.client
        .channel('public:$tableName:user_id=eq.$userId');
    _realtimeChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: tableName,
          callback: (payload) {
            _handleRealtimePayload(payload);
          },
        )
        .subscribe();
    LoggerFactory.info('⚡️ Realtime subscription setup for $tableName');
  }

  void _handleRealtimePayload(PostgresChangePayload payload) {
    final eventType = payload.eventType;
    LoggerFactory.info(
        'Realtime event: $eventType, data: ${payload.oldRecord}');

    switch (eventType) {
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        final entity = deserializeFromRemote(payload.newRecord);
        saveToLocal(entity);
        _emitEvent(RepositoryEventType.itemUpdated, 'Realtime item updated',
            entity: entity);
        break;
      case PostgresChangeEvent.delete:
        final movieId = payload.oldRecord['movie_id']?.toString();
        if (movieId != null) {
          removeFromLocal(movieId);
          _emitEvent(RepositoryEventType.itemRemoved, 'Realtime item removed',
              entityId: movieId);
        }
        break;
      case PostgresChangeEvent.all:
        // Handle other event types or ignore
        LoggerFactory.debug('Unhandled realtime event type: $eventType');
        break;
    }
  }

  /// Cola una entidad para sincronización
  Future<void> _queueForSync(T? entity, SyncOperationType operationType,
      {String? entityId}) async {
    if (_syncCoordinator != null) {
      Map<String, dynamic> data;

      if (entity != null) {
        data = entity.toSupabaseJson();
      } else if (operationType == SyncOperationType.delete &&
          entityId != null) {
        data = {'id': entityId, 'is_deleted': true};
      } else {
        LoggerFactory.warning(
            '⚠️ Cannot queue operation - missing entity or entityId');
        return;
      }

      await _syncCoordinator!.queueSyncOperation(
        entityType: entityType,
        entityId: entity?.id ?? entityId!,
        type: operationType,
        data: data,
        priority: _getOperationPriority(operationType),
      );

      LoggerFactory.debug(
          '📋 Queued $operationType for $entityType: ${entity?.id ?? entityId}');
    }
  }

  /// Intenta sincronización inmediata si las condiciones son favorables
  Future<void> _tryImmediateSync() async {
    if (_syncCoordinator != null && !_syncCoordinator!.isSyncing) {
      try {
        // Solo intentar si no estamos ya sincronizando
        await _syncCoordinator!.syncEntity(entityType);
      } catch (e) {
        // No es crítico si falla - la operación queda en cola
        LoggerFactory.debug('ℹ️ Immediate sync failed (not critical): $e');
      }
    }
  }

  /// Obtiene prioridad para diferentes tipos de operación
  int _getOperationPriority(SyncOperationType operationType) {
    switch (operationType) {
      case SyncOperationType.delete:
        return 2; // Alta prioridad para eliminaciones
      case SyncOperationType.create:
        return 3; // Media-alta para creaciones
      case SyncOperationType.update:
        return 4; // Media para actualizaciones
      case SyncOperationType.merge:
        return 1; // Máxima prioridad para resoluciones de conflicto
    }
  }

  /// Emite un evento del repositorio
  void _emitEvent(
    RepositoryEventType type,
    String message, {
    T? entity,
    String? entityId,
    SyncResult? result,
  }) {
    final event = RepositoryEvent<T>(
      type: type,
      message: message,
      timestamp: DateTime.now(),
      entity: entity,
      entityId: entityId,
      result: result,
    );

    _eventController.add(event);
  }

  /// Obtiene estadísticas del repositorio
  Future<Map<String, dynamic>> getStatistics() async {
    final localData = await getLocalData();

    Map<String, dynamic> syncStats = {};
    if (_syncManager != null) {
      try {
        final stats = await _syncManager!.getSyncStatistics();
        syncStats = {
          'total_entities': stats.totalEntities,
          'synced_entities': stats.syncedEntities,
          'failed_entities': stats.failedEntities,
          'success_rate': stats.successRate,
          'last_sync_at': stats.lastSyncAt.toIso8601String(),
          'conflicts_detected': stats.conflictsDetected,
          'conflicts_resolved': stats.conflictsResolved,
        };
      } catch (e) {
        LoggerFactory.warning('Failed to get sync stats: $e');
      }
    }

    return {
      'entity_type': entityType,
      'local_count': localData.length,
      'is_initialized': _isInitialized,
      'sync_manager_available': _syncManager != null,
      'coordinator_available': _syncCoordinator != null,
      'sync_stats': syncStats,
    };
  }

  /// Libera recursos
  Future<void> dispose() async {
    await _eventController.close();
    _realtimeChannel?.unsubscribe();
    LoggerFactory.info('🔒 BaseHybridRepository<$entityType> disposed');
  }
}

/// Evento del repositorio
class RepositoryEvent<T extends SyncableEntity> {
  const RepositoryEvent({
    required this.type,
    required this.message,
    required this.timestamp,
    this.entity,
    this.entityId,
    this.result,
  });

  final RepositoryEventType type;
  final String message;
  final DateTime timestamp;
  final T? entity;
  final String? entityId;
  final SyncResult? result;

  @override
  String toString() {
    return 'RepositoryEvent(${type.name}: $message)';
  }
}

/// Tipos de eventos del repositorio
enum RepositoryEventType {
  initialized,
  itemAdded,
  itemUpdated,
  itemRemoved,
  syncStarted,
  syncCompleted,
  syncError,
  error,
}
