import 'dart:async';
import 'dart:developer' as developer;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../domain/entities/sync_operation.dart';
import 'logger_factory.dart';

/// Estadísticas de la cola de sincronización
class SyncQueueStats {
  const SyncQueueStats({
    required this.pendingOperations,
    required this.failedOperations,
    required this.completedOperations,
    required this.totalOperations,
    this.lastProcessedAt,
    this.isProcessing = false,
  });
  final int pendingOperations;
  final int failedOperations;
  final int completedOperations;
  final int totalOperations;
  final DateTime? lastProcessedAt;
  final bool isProcessing;

  double get successRate {
    if (totalOperations == 0) return 0.0;
    return completedOperations / totalOperations;
  }

  @override
  String toString() {
    return 'SyncQueueStats(pending: $pendingOperations, failed: $failedOperations, completed: $completedOperations, total: $totalOperations, successRate: ${(successRate * 100).toStringAsFixed(1)}%)';
  }
}

/// Cola persistente para operaciones de sincronización offline
class PersistentSyncQueue {
  static const String _boxName = 'sync_operations_queue';
  static const String _statsBoxName = 'sync_queue_stats';
  static const int _maxBatchSize = 10;
  static const Duration _processingInterval = Duration(seconds: 30);
  static const Duration _maxProcessingTime = Duration(minutes: 5);

  late Box<SyncOperation> _operationsBox;
  late Box<dynamic> _statsBox;

  Timer? _processingTimer;
  Timer? _connectivityTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _hasConnectivity = false;

  final Connectivity _connectivity = Connectivity();

  // Callbacks para procesamiento de operaciones
  Future<bool> Function(SyncOperation operation)? _operationProcessor;
  Future<bool> Function(List<SyncOperation> operations)? _batchProcessor;

  // Stream controllers para notificaciones
  final StreamController<SyncQueueStats> _statsController =
      StreamController<SyncQueueStats>.broadcast();
  final StreamController<SyncOperation> _operationCompletedController =
      StreamController<SyncOperation>.broadcast();
  final StreamController<SyncOperation> _operationFailedController =
      StreamController<SyncOperation>.broadcast();

  /// Stream de estadísticas de la cola
  Stream<SyncQueueStats> get statsStream => _statsController.stream;

  /// Stream de operaciones completadas
  Stream<SyncOperation> get operationCompletedStream =>
      _operationCompletedController.stream;

  /// Stream de operaciones fallidas
  Stream<SyncOperation> get operationFailedStream =>
      _operationFailedController.stream;

  /// Indica si la cola está inicializada
  bool get isInitialized => _isInitialized;

  /// Inicializa la cola persistente
  Future<void> initialize({
    Future<bool> Function(SyncOperation operation)? operationProcessor,
    Future<bool> Function(List<SyncOperation> operations)? batchProcessor,
  }) async {
    if (_isInitialized) return;

    try {
      LoggerFactory.info('Inicializando PersistentSyncQueue...');

      // Registrar adaptadores de Hive si no están registrados
      if (!Hive.isAdapterRegistered(10)) {
        Hive.registerAdapter(SyncOperationAdapter());
      }
      if (!Hive.isAdapterRegistered(11)) {
        Hive.registerAdapter(SyncOperationTypeAdapter());
      }
      if (!Hive.isAdapterRegistered(12)) {
        Hive.registerAdapter(SyncOperationStatusAdapter());
      }

      // Abrir cajas de Hive
      _operationsBox = await Hive.openBox<SyncOperation>(_boxName);
      _statsBox = await Hive.openBox<dynamic>(_statsBoxName);

      // Configurar procesadores
      _operationProcessor = operationProcessor;
      _batchProcessor = batchProcessor;

      // Verificar conectividad inicial
      await _checkConnectivity();

      // Configurar listeners de conectividad
      _setupConnectivityListener();

      // Limpiar operaciones completadas antiguas
      await _cleanupCompletedOperations();

      // Iniciar procesamiento automático
      _startPeriodicProcessing();

      _isInitialized = true;
      LoggerFactory.info('PersistentSyncQueue inicializada correctamente');

      // Emitir estadísticas iniciales
      _emitStats();
    } catch (e, stackTrace) {
      LoggerFactory.error('Error inicializando PersistentSyncQueue',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Agrega una operación a la cola
  Future<void> enqueue(SyncOperation operation) async {
    if (!_isInitialized) {
      throw StateError('PersistentSyncQueue no está inicializada');
    }

    try {
      await _operationsBox.put(operation.id, operation);
      LoggerFactory.debug(
          'Operación agregada a la cola: ${operation.type} (${operation.id})');

      // Emitir estadísticas actualizadas
      _emitStats();

      // Procesar inmediatamente si hay conectividad
      if (_hasConnectivity && !_isProcessing) {
        unawaited(_processQueue());
      }
    } catch (e, stackTrace) {
      LoggerFactory.error('Error agregando operación a la cola',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Agrega múltiples operaciones a la cola
  Future<void> enqueueAll(List<SyncOperation> operations) async {
    if (!_isInitialized) {
      throw StateError('PersistentSyncQueue no está inicializada');
    }

    try {
      final Map<String, SyncOperation> operationsMap = {
        for (final operation in operations) operation.id: operation
      };

      await _operationsBox.putAll(operationsMap);
      LoggerFactory.debug(
          '${operations.length} operaciones agregadas a la cola');

      // Emitir estadísticas actualizadas
      _emitStats();

      // Procesar inmediatamente si hay conectividad
      if (_hasConnectivity && !_isProcessing) {
        unawaited(_processQueue());
      }
    } catch (e, stackTrace) {
      LoggerFactory.error('Error agregando operaciones a la cola',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Procesa la cola de operaciones
  Future<void> processQueue() async {
    if (!_isInitialized) {
      LoggerFactory.warning('Intentando procesar cola no inicializada');
      return;
    }

    await _processQueue();
  }

  /// Obtiene las estadísticas actuales de la cola
  SyncQueueStats getStats() {
    if (!_isInitialized) {
      return const SyncQueueStats(
        pendingOperations: 0,
        failedOperations: 0,
        completedOperations: 0,
        totalOperations: 0,
      );
    }

    final operations = _operationsBox.values.toList();
    final pending = operations.where((op) => op.isPending).length;
    final failed = operations.where((op) => op.isDefinitelyFailed).length;
    final completed = operations.where((op) => op.isCompleted).length;
    final lastProcessed = _statsBox.get('lastProcessedAt') as DateTime?;

    return SyncQueueStats(
      pendingOperations: pending,
      failedOperations: failed,
      completedOperations: completed,
      totalOperations: operations.length,
      lastProcessedAt: lastProcessed,
      isProcessing: _isProcessing,
    );
  }

  /// Obtiene operaciones por estado
  List<SyncOperation> getOperationsByStatus(SyncOperationStatus status) {
    if (!_isInitialized) return [];

    return _operationsBox.values
        .where((operation) => operation.status == status)
        .toList();
  }

  /// Obtiene operaciones pendientes ordenadas por prioridad y fecha
  List<SyncOperation> getPendingOperations() {
    if (!_isInitialized) return [];

    final pending = _operationsBox.values
        .where((operation) => operation.isPending)
        .toList();

    // Ordenar por prioridad (mayor primero) y luego por fecha de creación
    pending.sort((a, b) {
      final priorityComparison = b.priority.compareTo(a.priority);
      if (priorityComparison != 0) return priorityComparison;
      return a.createdAt.compareTo(b.createdAt);
    });

    return pending;
  }

  /// Reintenta operaciones fallidas que están listas para reintento
  Future<void> retryFailedOperations() async {
    if (!_isInitialized || !_hasConnectivity) return;

    try {
      final failedOperations = _operationsBox.values
          .where((operation) => operation.canRetry && operation.isReadyForRetry)
          .toList();

      if (failedOperations.isEmpty) return;

      LoggerFactory.info(
          'Reintentando ${failedOperations.length} operaciones fallidas');

      for (final operation in failedOperations) {
        final updatedOperation = operation.copyWith(
          status: SyncOperationStatus.pending,
          errorMessage: null,
        );
        await _operationsBox.put(operation.id, updatedOperation);
      }

      _emitStats();

      // Procesar las operaciones reintentadas
      if (!_isProcessing) {
        unawaited(_processQueue());
      }
    } catch (e, stackTrace) {
      LoggerFactory.error('Error reintentando operaciones fallidas',
          error: e, stackTrace: stackTrace);
    }
  }

  /// Limpia operaciones completadas antiguas
  Future<void> cleanupCompletedOperations({Duration? olderThan}) async {
    if (!_isInitialized) return;

    await _cleanupCompletedOperations(olderThan: olderThan);
  }

  /// Limpia todas las operaciones completadas
  Future<void> clearCompleted() async {
    if (!_isInitialized) return;

    try {
      final completedOperations = _operationsBox.values
          .where((operation) => operation.isCompleted)
          .toList();

      for (final operation in completedOperations) {
        await _operationsBox.delete(operation.id);
      }

      if (completedOperations.isNotEmpty) {
        LoggerFactory.info(
            'Limpiadas ${completedOperations.length} operaciones completadas');
        _emitStats();
      }
    } catch (e, stackTrace) {
      LoggerFactory.error('Error limpiando operaciones completadas',
          error: e, stackTrace: stackTrace);
    }
  }

  /// Limpia todas las operaciones de la cola
  Future<void> clearAll() async {
    if (!_isInitialized) return;

    try {
      await _operationsBox.clear();
      LoggerFactory.info('Cola de sincronización limpiada');
      _emitStats();
    } catch (e, stackTrace) {
      LoggerFactory.error('Error limpiando la cola',
          error: e, stackTrace: stackTrace);
    }
  }

  /// Alias para clearAll() - mantiene compatibilidad
  Future<void> clear() async {
    await clearAll();
  }

  /// Cierra la cola y libera recursos
  Future<void> dispose() async {
    LoggerFactory.info('Cerrando PersistentSyncQueue...');

    _processingTimer?.cancel();
    _connectivityTimer?.cancel();
    await _connectivitySubscription?.cancel();

    await _statsController.close();
    await _operationCompletedController.close();
    await _operationFailedController.close();

    if (_isInitialized) {
      await _operationsBox.close();
      await _statsBox.close();
    }

    _isInitialized = false;
    LoggerFactory.info('PersistentSyncQueue cerrada');
  }

  // Métodos privados

  Future<void> _processQueue() async {
    if (_isProcessing || !_hasConnectivity) return;

    _isProcessing = true;
    _emitStats();

    try {
      LoggerFactory.debug('Iniciando procesamiento de cola');
      final startTime = DateTime.now();

      final pendingOperations = getPendingOperations();
      if (pendingOperations.isEmpty) {
        LoggerFactory.debug('No hay operaciones pendientes para procesar');
        return;
      }

      LoggerFactory.info(
          'Procesando ${pendingOperations.length} operaciones pendientes');

      // Procesar en lotes
      for (int i = 0; i < pendingOperations.length; i += _maxBatchSize) {
        // Verificar tiempo máximo de procesamiento
        if (DateTime.now().difference(startTime) > _maxProcessingTime) {
          LoggerFactory.warning(
              'Tiempo máximo de procesamiento alcanzado, pausando');
          break;
        }

        // Verificar conectividad
        if (!_hasConnectivity) {
          LoggerFactory.info('Conectividad perdida durante procesamiento');
          break;
        }

        final batch = pendingOperations.skip(i).take(_maxBatchSize).toList();
        await _processBatch(batch);
      }

      // Actualizar estadísticas
      await _statsBox.put('lastProcessedAt', DateTime.now());
    } catch (e, stackTrace) {
      LoggerFactory.error('Error procesando cola',
          error: e, stackTrace: stackTrace);
    } finally {
      _isProcessing = false;
      _emitStats();
    }
  }

  Future<void> _processBatch(List<SyncOperation> batch) async {
    if (batch.isEmpty) return;

    try {
      // Intentar procesamiento en lote si está disponible
      if (_batchProcessor != null && batch.length > 1) {
        LoggerFactory.debug('Procesando lote de ${batch.length} operaciones');

        // Marcar operaciones como en procesamiento
        for (final operation in batch) {
          final processingOperation = operation.markAsProcessing();
          await _operationsBox.put(operation.id, processingOperation);
        }

        final success = await _batchProcessor!(batch);

        if (success) {
          // Marcar todas como completadas
          for (final operation in batch) {
            final completedOperation = operation.markAsCompleted();
            await _operationsBox.put(operation.id, completedOperation);
            _operationCompletedController.add(completedOperation);
          }
          LoggerFactory.debug('Lote procesado exitosamente');
        } else {
          // Procesar individualmente en caso de fallo del lote
          LoggerFactory.warning(
              'Fallo en procesamiento de lote, procesando individualmente');
          for (final operation in batch) {
            await _processSingleOperation(operation);
          }
        }
      } else {
        // Procesamiento individual
        for (final operation in batch) {
          await _processSingleOperation(operation);
        }
      }
    } catch (e, stackTrace) {
      LoggerFactory.error('Error procesando lote',
          error: e, stackTrace: stackTrace);

      // Procesar individualmente en caso de error
      for (final operation in batch) {
        await _processSingleOperation(operation);
      }
    }
  }

  Future<void> _processSingleOperation(SyncOperation operation) async {
    if (_operationProcessor == null) {
      LoggerFactory.warning('No hay procesador de operaciones configurado');
      return;
    }

    try {
      LoggerFactory.debug(
          'Procesando operación: ${operation.type} (${operation.id})');

      // Marcar como en procesamiento
      final processingOperation = operation.markAsProcessing();
      await _operationsBox.put(operation.id, processingOperation);

      // Procesar operación
      final success = await _operationProcessor!(operation);

      if (success) {
        // Marcar como completada
        final completedOperation = operation.markAsCompleted();
        await _operationsBox.put(operation.id, completedOperation);
        _operationCompletedController.add(completedOperation);
        LoggerFactory.debug('Operación completada: ${operation.id}');
      } else {
        // Marcar como fallida e incrementar contador de reintentos
        final failedOperation =
            operation.incrementRetry().markAsFailed('Procesamiento falló');
        await _operationsBox.put(operation.id, failedOperation);
        _operationFailedController.add(failedOperation);
        LoggerFactory.warning(
            'Operación fallida: ${operation.id} (intento ${failedOperation.retryCount}/${failedOperation.maxRetries})');
      }
    } catch (e, stackTrace) {
      LoggerFactory.error('Error procesando operación ${operation.id}',
          error: e, stackTrace: stackTrace);

      // Marcar como fallida con el error específico
      final failedOperation =
          operation.incrementRetry().markAsFailed(e.toString());
      await _operationsBox.put(operation.id, failedOperation);
      _operationFailedController.add(failedOperation);
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _hasConnectivity =
          results.isNotEmpty && !results.contains(ConnectivityResult.none);
      LoggerFactory.debug('Estado de conectividad: $_hasConnectivity');
    } catch (e) {
      LoggerFactory.warning('Error verificando conectividad: $e');
      _hasConnectivity = false;
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final wasConnected = _hasConnectivity;
        _hasConnectivity =
            results.isNotEmpty && !results.contains(ConnectivityResult.none);

        LoggerFactory.debug(
            'Cambio de conectividad: $wasConnected -> $_hasConnectivity');

        // Si recuperamos conectividad, procesar cola
        if (!wasConnected && _hasConnectivity && !_isProcessing) {
          LoggerFactory.info('Conectividad recuperada, procesando cola');
          unawaited(_processQueue());
        }
      },
      onError: (error) {
        LoggerFactory.error('Error en listener de conectividad', error: error);
      },
    );
  }

  void _startPeriodicProcessing() {
    _processingTimer = Timer.periodic(_processingInterval, (timer) {
      if (_hasConnectivity && !_isProcessing) {
        unawaited(_processQueue());
      }
    });
  }

  Future<void> _cleanupCompletedOperations({Duration? olderThan}) async {
    try {
      final cutoffTime =
          DateTime.now().subtract(olderThan ?? const Duration(days: 7));

      final completedOperations = _operationsBox.values
          .where((operation) =>
              operation.isCompleted &&
              operation.lastAttemptAt != null &&
              operation.lastAttemptAt!.isBefore(cutoffTime))
          .toList();

      if (completedOperations.isNotEmpty) {
        for (final operation in completedOperations) {
          await _operationsBox.delete(operation.id);
        }
        LoggerFactory.info(
            'Limpiadas ${completedOperations.length} operaciones completadas antiguas');
        _emitStats();
      }
    } catch (e, stackTrace) {
      LoggerFactory.error('Error limpiando operaciones completadas',
          error: e, stackTrace: stackTrace);
    }
  }

  void _emitStats() {
    if (!_statsController.isClosed) {
      _statsController.add(getStats());
    }
  }

  /// Agrega un elemento individual a la cola de sincronización
  Future<void> addItem(String type, Map<String, dynamic> data,
      {int priority = 0}) async {
    SyncOperationType opType;
    try {
      opType = SyncOperationType.values.byName(type);
    } catch (e) {
      LoggerFactory.error('Tipo de operación inválido: $type', error: e);
      return;
    }
    final operation = SyncOperation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: opType,
      data: data,
      priority: priority,
      createdAt: DateTime.now(),
    );
    await enqueue(operation);
  }

  /// Limpia todas las operaciones de la cola
  // Duplicate clear() removed

  /// Detecta conflictos entre operaciones
  List<SyncOperation> detectConflicts() {
    final operations = _operationsBox.values.toList();
    final conflicts = <SyncOperation>[];

    // Agrupar operaciones por tipo y datos similares
    final operationGroups = <String, List<SyncOperation>>{};

    for (final operation in operations) {
      final key = '${operation.type}_${operation.data['id'] ?? ''}';
      operationGroups.putIfAbsent(key, () => []).add(operation);
    }

    // Identificar grupos con múltiples operaciones como conflictos potenciales
    for (final group in operationGroups.values) {
      if (group.length > 1) {
        conflicts.addAll(group);
      }
    }

    return conflicts;
  }
}

/// Provider para PersistentSyncQueue
final persistentSyncQueueProvider = Provider<PersistentSyncQueue>((ref) {
  final queue = PersistentSyncQueue();

  // Dispose cuando el provider se destruye
  ref.onDispose(() {
    queue.dispose();
  });

  return queue;
});

/// Provider para las estadísticas de la cola
final syncQueueStatsProvider = StreamProvider<SyncQueueStats>((ref) {
  final queue = ref.watch(persistentSyncQueueProvider);
  return queue.statsStream;
});

/// Función auxiliar para evitar warnings de unawaited
void unawaited(Future<void> future) {
  future.catchError((error, stackTrace) {
    developer.log(
      'Unawaited future error',
      error: error,
      stackTrace: stackTrace,
    );
  });
}
