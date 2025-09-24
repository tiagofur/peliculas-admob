import 'dart:async';

import '../logging/logger_factory.dart';
import '../../domain/entities/sync_result.dart';
import '../../infrastructure/services/connectivity_manager.dart';
import '../../infrastructure/services/realtime_sync_manager.dart';
import 'conflict_resolver.dart';
import 'entity_sync_manager.dart';
import 'favorites_sync_manager.dart';
import 'persistent_sync_queue.dart';
import 'sync_operation.dart';

/// Coordinador central para todas las operaciones de sincronización
class SyncCoordinator {
  SyncCoordinator({
    required this.userId,
  })  : _syncQueue = PersistentSyncQueue(userId: userId),
        _conflictResolver = ConflictResolver(),
        _connectivityManager = ConnectivityManager() {
    _initialize();
  }

  final String userId;
  final PersistentSyncQueue _syncQueue;
  final ConflictResolver _conflictResolver;
  final ConnectivityManager _connectivityManager;

  final Map<String, EntitySyncManager> _syncManagers = {};
  final StreamController<SyncCoordinatorEvent> _eventController =
      StreamController<SyncCoordinatorEvent>.broadcast();

  RealtimeSyncManager? _realtimeSyncManager;
  StreamSubscription<ConnectionStatus>? _connectionSubscription;
  StreamSubscription<BackgroundSyncEvent>? _backgroundSyncSubscription;

  bool _isInitialized = false;
  bool _isSyncing = false;

  /// Stream de eventos del coordinador
  Stream<SyncCoordinatorEvent> get events => _eventController.stream;

  /// Indica si está sincronizando actualmente
  bool get isSyncing => _isSyncing;

  /// Indica si está inicializado
  bool get isInitialized => _isInitialized;

  /// Inicialización del coordinador
  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      // Registrar managers de entidades
      await _registerSyncManagers();

      // Inicializar RealtimeSyncManager
      await _initializeRealtimeSync();

      // Configurar listeners de conectividad
      await _setupConnectivityListeners();

      _isInitialized = true;
      _emitEvent(
          SyncCoordinatorEventType.initialized, 'SyncCoordinator initialized');

      LoggerFactory.info('✅ SyncCoordinator initialized for user: $userId');
    } catch (e) {
      LoggerFactory.error('❌ Failed to initialize SyncCoordinator: $e');
      _isInitialized = true; // Continue even if some parts fail
    }
  }

  /// Registra los managers de sincronización por entidad
  Future<void> _registerSyncManagers() async {
    // Registrar manager de favoritos
    _syncManagers['favorite'] = FavoritesSyncManager(userId: userId);

    // _syncManagers['watchlist'] = WatchlistSyncManager(userId: userId);
    // _syncManagers['custom_list'] = CustomListSyncManager(userId: userId);

    LoggerFactory.info('📋 Registered ${_syncManagers.length} sync managers');
  }

  /// Inicializa el RealtimeSyncManager
  Future<void> _initializeRealtimeSync() async {
    try {
      _realtimeSyncManager = RealtimeSyncManager(
        userId: userId,
        syncCoordinator: this,
        connectivityManager: _connectivityManager,
      );

      await _realtimeSyncManager!.initialize();
      LoggerFactory.info('🔄 RealtimeSyncManager initialized');
    } catch (e) {
      LoggerFactory.error('❌ Failed to initialize RealtimeSyncManager: $e');
      // Continue without realtime sync if it fails
    }
  }

  /// Configura listeners de conectividad
  Future<void> _setupConnectivityListeners() async {
    try {
      // Listener de estado de conexión
      _connectionSubscription = _connectivityManager.connectionStatus.listen(
        _handleConnectionStatusChange,
        onError: (error) {
          LoggerFactory.error('❌ Connection status listener error: $error');
        },
      );

      // Listener de eventos de sincronización en background
      _backgroundSyncSubscription =
          _connectivityManager.backgroundSyncEvents.listen(
        _handleBackgroundSyncEvent,
        onError: (error) {
          LoggerFactory.error('❌ Background sync listener error: $error');
        },
      );

      LoggerFactory.info('📡 Connectivity listeners configured');
    } catch (e) {
      LoggerFactory.error('❌ Failed to setup connectivity listeners: $e');
    }
  }

  /// Maneja cambios en el estado de conexión
  void _handleConnectionStatusChange(ConnectionStatus status) {
    LoggerFactory.info('🌐 Connection status changed: ${status.name}');

    _emitEvent(
      SyncCoordinatorEventType.connectionStatusChanged,
      'Connection status: ${status.name}',
      metadata: {'status': status.name},
    );

    // Reactivar sincronización en tiempo real si se restaura la conexión
    if (status == ConnectionStatus.online && _realtimeSyncManager != null) {
      _realtimeSyncManager!.resumeListeners();
    }
  }

  /// Maneja eventos de sincronización en background
  void _handleBackgroundSyncEvent(BackgroundSyncEvent event) {
    LoggerFactory.info('📱 Background sync event: ${event.type}');

    switch (event.type) {
      case 'backgroundSyncTriggered':
        _triggerBackgroundSync();
        break;
      case 'connectionRestored':
        _onConnectionRestored();
        break;
      case 'connectionLost':
        _onConnectionLost();
        break;
      default:
        // Otros eventos se manejan automáticamente
        break;
    }

    _emitEvent(
      SyncCoordinatorEventType.backgroundSyncEvent,
      'Background sync event: ${event.type}',
      metadata: {
        'event_type': event.type,
        'timestamp': event.timestamp.toIso8601String(),
        'data': event.data,
      },
    );
  }

  /// Dispara sincronización en background
  void _triggerBackgroundSync() {
    if (_isSyncing) {
      LoggerFactory.info(
          '⚠️ Sync already in progress, skipping background sync');
      return;
    }

    // Ejecutar sincronización en background sin bloquear
    performFullSync().then((result) {
      LoggerFactory.info('📱 Background sync completed: ${result.toString()}');
    }).catchError((error) {
      LoggerFactory.error('❌ Background sync failed: $error');
    });
  }

  /// Maneja restauración de conexión
  void _onConnectionRestored() {
    LoggerFactory.info('🟢 Connection restored, resuming realtime sync');
    _realtimeSyncManager?.resumeListeners();
  }

  /// Maneja pérdida de conexión
  void _onConnectionLost() {
    LoggerFactory.info('🔴 Connection lost, pausing realtime sync');
    _realtimeSyncManager?.pauseListeners();
  }

  /// Ejecuta sincronización completa de todas las entidades
  Future<SyncResult> performFullSync() async {
    if (!_isInitialized) await _initialize();

    if (_isSyncing) {
      LoggerFactory.warning('⚠️ Sync already in progress, skipping');
      return SyncResult.failure(
        itemsProcessed: 0,
        errors: ['Sync already in progress'],
      );
    }

    _isSyncing = true;
    _emitEvent(SyncCoordinatorEventType.syncStarted, 'Full sync started');

    final startTime = DateTime.now();
    var totalProcessed = 0;
    var totalSuccessful = 0;
    final allErrors = <String>[];

    try {
      LoggerFactory.info(
          '🔄 Starting full sync for ${_syncManagers.length} entity types');

      // Fase 1: Procesar cola de operaciones pendientes
      _emitEvent(SyncCoordinatorEventType.processingQueue,
          'Processing pending operations');
      final queueStats = await _syncQueue.getQueueStatistics();
      final readyOperations = queueStats['ready_to_execute'] ?? 0;

      if (readyOperations > 0) {
        LoggerFactory.info('📋 Processing $readyOperations queued operations');

        for (final manager in _syncManagers.values) {
          final queueResult = await manager.processQueuedOperations();
          totalProcessed += queueResult.itemsProcessed;
          totalSuccessful += queueResult.itemsSuccessful;
          allErrors.addAll(queueResult.errors);
        }
      }

      // Fase 2: Sincronización por entidad
      _emitEvent(SyncCoordinatorEventType.syncingEntities, 'Syncing entities');

      for (final entry in _syncManagers.entries) {
        final entityType = entry.key;
        final manager = entry.value;

        try {
          LoggerFactory.info('🔄 Syncing $entityType');
          _emitEvent(
              SyncCoordinatorEventType.syncingEntity, 'Syncing $entityType');

          final syncResult = await manager.performFullSync();
          totalProcessed += syncResult.itemsProcessed;
          totalSuccessful += syncResult.itemsSuccessful;
          allErrors.addAll(syncResult.errors);

          LoggerFactory.info('✅ $entityType sync: ${syncResult.toString()}');
        } catch (e) {
          final error = 'Failed to sync $entityType: $e';
          allErrors.add(error);
          LoggerFactory.error(error);
        }
      }

      // Resultado final
      final finalResult = SyncResult(
        success: allErrors.isEmpty,
        itemsProcessed: totalProcessed,
        itemsSuccessful: totalSuccessful,
        itemsFailed: totalProcessed - totalSuccessful,
        errors: allErrors,
        duration: DateTime.now().difference(startTime),
      );

      _emitEvent(
        allErrors.isEmpty
            ? SyncCoordinatorEventType.syncCompleted
            : SyncCoordinatorEventType.syncError,
        'Full sync completed: ${finalResult.toString()}',
        result: finalResult,
      );

      LoggerFactory.info('🎉 Full sync completed: ${finalResult.toString()}');
      return finalResult;
    } catch (e) {
      final error = 'Full sync failed: $e';
      LoggerFactory.error(error);

      final failureResult = SyncResult.failure(
        itemsProcessed: totalProcessed,
        itemsSuccessful: totalSuccessful,
        errors: [error],
        duration: DateTime.now().difference(startTime),
      );

      _emitEvent(SyncCoordinatorEventType.syncError, error,
          result: failureResult);
      return failureResult;
    } finally {
      _isSyncing = false;
    }
  }

  /// Sincroniza una entidad específica
  Future<SyncResult> syncEntity(String entityType) async {
    if (!_isInitialized) await _initialize();

    final manager = _syncManagers[entityType];
    if (manager == null) {
      final error = 'No sync manager found for entity type: $entityType';
      LoggerFactory.error(error);
      return SyncResult.failure(itemsProcessed: 0, errors: [error]);
    }

    _emitEvent(SyncCoordinatorEventType.syncingEntity, 'Syncing $entityType');

    try {
      final result = await manager.performFullSync();

      _emitEvent(
        result.success
            ? SyncCoordinatorEventType.entitySynced
            : SyncCoordinatorEventType.syncError,
        'Entity $entityType sync: ${result.toString()}',
        result: result,
      );

      return result;
    } catch (e) {
      final error = 'Failed to sync $entityType: $e';
      LoggerFactory.error(error);

      final failureResult =
          SyncResult.failure(itemsProcessed: 0, errors: [error]);
      _emitEvent(SyncCoordinatorEventType.syncError, error,
          result: failureResult);

      return failureResult;
    }
  }

  /// Cola una operación para sincronización posterior
  Future<void> queueSyncOperation({
    required String entityType,
    required String entityId,
    required SyncOperationType type,
    required Map<String, dynamic> data,
    int priority = 5,
  }) async {
    if (!_isInitialized) await _initialize();

    final manager = _syncManagers[entityType];
    if (manager != null) {
      await manager.queueOperation(
        type: type,
        entityId: entityId,
        data: data,
        priority: priority,
      );

      _emitEvent(
        SyncCoordinatorEventType.operationQueued,
        'Queued $type operation for $entityType($entityId)',
      );
    } else {
      LoggerFactory.warning('⚠️ No manager found for entity type: $entityType');
    }
  }

  /// Obtiene estadísticas de sincronización
  Future<Map<String, dynamic>> getSyncStatistics() async {
    if (!_isInitialized) await _initialize();

    final stats = <String, dynamic>{
      'coordinator': {
        'user_id': userId,
        'is_syncing': _isSyncing,
        'registered_managers': _syncManagers.keys.toList(),
      },
      'queue': await _syncQueue.getQueueStatistics(),
      'conflict_resolver': _conflictResolver.getResolutionStats(),
      'managers': {},
    };

    // Estadísticas por manager
    for (final entry in _syncManagers.entries) {
      try {
        final managerStats = await entry.value.getSyncStatistics();
        stats['managers'][entry.key] = {
          'entity_type': managerStats.entityType,
          'total_entities': managerStats.totalEntities,
          'synced_entities': managerStats.syncedEntities,
          'failed_entities': managerStats.failedEntities,
          'last_sync_at': managerStats.lastSyncAt.toIso8601String(),
          'success_rate': managerStats.successRate,
          'conflicts_detected': managerStats.conflictsDetected,
          'conflicts_resolved': managerStats.conflictsResolved,
        };
      } catch (e) {
        LoggerFactory.warning('Failed to get stats for ${entry.key}: $e');
      }
    }

    return stats;
  }

  /// Configura estrategia de conflictos para un tipo de entidad
  void setConflictStrategy(String entityType, ConflictStrategy strategy) {
    _conflictResolver.setDefaultStrategy(entityType, strategy);
    _emitEvent(
      SyncCoordinatorEventType.configurationChanged,
      'Set conflict strategy for $entityType: ${strategy.name}',
    );
  }

  /// Obtiene el estado actual de conexión
  ConnectionStatus get connectionStatus => _connectivityManager.currentStatus;

  /// Stream de estado de conexión
  Stream<ConnectionStatus> get connectionStatusStream =>
      _connectivityManager.connectionStatus;

  /// Habilita modo offline manual
  Future<void> enableOfflineMode() async {
    await _connectivityManager.enableOfflineMode();
    LoggerFactory.info('📱 Offline mode enabled via SyncCoordinator');
  }

  /// Deshabilita modo offline manual
  Future<void> disableOfflineMode() async {
    await _connectivityManager.disableOfflineMode();
    LoggerFactory.info('🌐 Offline mode disabled via SyncCoordinator');
  }

  /// Fuerza verificación de conexión
  Future<void> forceConnectionCheck() async {
    await _connectivityManager.forceConnectionCheck();
    LoggerFactory.info('🔍 Connection check forced via SyncCoordinator');
  }

  /// Pausa sincronización en tiempo real
  void pauseRealtimeSync() {
    _realtimeSyncManager?.pauseListeners();
    _emitEvent(
      SyncCoordinatorEventType.realtimeSyncEvent,
      'Realtime sync paused',
    );
  }

  /// Reanuda sincronización en tiempo real
  void resumeRealtimeSync() {
    _realtimeSyncManager?.resumeListeners();
    _emitEvent(
      SyncCoordinatorEventType.realtimeSyncEvent,
      'Realtime sync resumed',
    );
  }

  /// Indica si la sincronización en tiempo real está activa
  bool get isRealtimeSyncActive => _realtimeSyncManager?.isListening ?? false;

  /// Propaga un cambio local a través del RealtimeSyncManager
  Future<void> propagateLocalChange({
    required String entityType,
    required String entityId,
    required SyncOperationType operationType,
    required Map<String, dynamic> data,
  }) async {
    await _realtimeSyncManager?.propagateLocalChange(
      entityType: entityType,
      entityId: entityId,
      operationType: operationType,
      data: data,
    );
  }

  /// Limpia datos de sincronización (para testing o reset)
  Future<void> reset() async {
    _isSyncing = false;
    await _syncQueue.clear();
    _conflictResolver.clearStats();

    _emitEvent(SyncCoordinatorEventType.reset, 'SyncCoordinator reset');
    LoggerFactory.info('🧹 SyncCoordinator reset completed');
  }

  /// Emite un evento del coordinador
  void _emitEvent(
    SyncCoordinatorEventType type,
    String message, {
    SyncResult? result,
    Map<String, dynamic>? metadata,
  }) {
    final event = SyncCoordinatorEvent(
      type: type,
      message: message,
      timestamp: DateTime.now(),
      result: result,
      metadata: metadata,
    );

    _eventController.add(event);
  }

  /// Libera recursos
  Future<void> dispose() async {
    try {
      LoggerFactory.info('🔒 Starting SyncCoordinator disposal...');

      // Marcar como no sincronizando para prevenir nuevas operaciones
      _isSyncing = false;
      _isInitialized = false;

      // Cerrar subscripciones con manejo de errores
      try {
        await _connectionSubscription?.cancel();
        LoggerFactory.info('✅ Connection subscription cancelled');
      } catch (e) {
        LoggerFactory.warning(
            '⚠️ Failed to cancel connection subscription: $e');
      }

      try {
        await _backgroundSyncSubscription?.cancel();
        LoggerFactory.info('✅ Background sync subscription cancelled');
      } catch (e) {
        LoggerFactory.warning(
            '⚠️ Failed to cancel background sync subscription: $e');
      }

      // Cerrar RealtimeSyncManager con timeout
      try {
        await _realtimeSyncManager?.dispose().timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            LoggerFactory.warning('⚠️ RealtimeSyncManager disposal timed out');
          },
        );
        LoggerFactory.info('✅ RealtimeSyncManager disposed');
      } catch (e) {
        LoggerFactory.warning('⚠️ Failed to dispose RealtimeSyncManager: $e');
      }

      // Cerrar ConnectivityManager
      try {
        await _connectivityManager.dispose();
        LoggerFactory.info('✅ ConnectivityManager disposed');
      } catch (e) {
        LoggerFactory.warning('⚠️ Failed to dispose ConnectivityManager: $e');
      }

      // Cerrar managers con manejo de errores individual
      final managerDisposalFutures = _syncManagers.entries.map((entry) async {
        final entityType = entry.key;
        final manager = entry.value;

        try {
          await manager.dispose().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              LoggerFactory.warning(
                  '⚠️ Manager disposal timed out for $entityType');
            },
          );
          LoggerFactory.info('✅ Manager disposed: $entityType');
        } catch (e) {
          LoggerFactory.warning('⚠️ Failed to dispose manager $entityType: $e');
        }
      });

      await Future.wait(managerDisposalFutures, eagerError: false);
      _syncManagers.clear();

      // Cerrar streams de forma segura
      try {
        if (!_eventController.isClosed) {
          await _eventController.close();
        }
        LoggerFactory.info('✅ Event controller closed');
      } catch (e) {
        LoggerFactory.warning('⚠️ Failed to close event controller: $e');
      }

      LoggerFactory.info('✅ SyncCoordinator disposed successfully');
    } catch (e) {
      LoggerFactory.error('❌ Error during SyncCoordinator disposal: $e');

      // Forzar limpieza en caso de error
      _isSyncing = false;
      _isInitialized = false;
      _syncManagers.clear();

      if (!_eventController.isClosed) {
        _eventController.close();
      }
    }
  }
}

/// Evento del coordinador de sincronización
class SyncCoordinatorEvent {
  const SyncCoordinatorEvent({
    required this.type,
    required this.message,
    required this.timestamp,
    this.result,
    this.metadata,
  });

  final SyncCoordinatorEventType type;
  final String message;
  final DateTime timestamp;
  final SyncResult? result;
  final Map<String, dynamic>? metadata;

  @override
  String toString() {
    return 'SyncCoordinatorEvent(${type.name}: $message)';
  }
}

/// Tipos de eventos del coordinador
enum SyncCoordinatorEventType {
  initialized,
  syncStarted,
  processingQueue,
  syncingEntities,
  syncingEntity,
  entitySynced,
  syncCompleted,
  syncError,
  operationQueued,
  configurationChanged,
  reset,
  connectionStatusChanged,
  backgroundSyncEvent,
  realtimeSyncEvent,
}
