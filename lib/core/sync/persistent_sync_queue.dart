import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../logging/logger_factory.dart';
import 'sync_operation.dart';
import 'sync_utilities.dart';

/// Cola persistente para operaciones de sincronización
/// Utiliza SharedPreferences para persistencia simple y rápida
class PersistentSyncQueue {
  PersistentSyncQueue({String? userId}) : _userId = userId {
    _queueKey = 'sync_queue_${_userId ?? 'default'}';
    _init();
  }

  final String? _userId;
  late final String _queueKey;
  final List<SyncOperation> _operations = [];
  bool _initialized = false;
  SharedPreferences? _prefs;

  /// Inicializa la cola cargando operaciones persistentes
  Future<void> _init() async {
    if (_initialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadOperations();
      _initialized = true;

      LoggerFactory.info(
          '✅ PersistentSyncQueue initialized with ${_operations.length} operations');
    } catch (e) {
      LoggerFactory.error('❌ Failed to initialize PersistentSyncQueue: $e');
      _initialized = true; // Continue even if loading fails
    }
  }

  /// Asegura que la cola esté inicializada
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await _init();
    }
  }

  /// Carga operaciones desde SharedPreferences
  Future<void> _loadOperations() async {
    try {
      final jsonString = _prefs?.getString(_queueKey);
      if (jsonString == null || jsonString.isEmpty) {
        LoggerFactory.info('No persisted operations found');
        return;
      }

      final List<dynamic> jsonList = json.decode(jsonString);
      _operations.clear();

      for (final item in jsonList) {
        try {
          final operation =
              SyncOperation.fromJson(Map<String, dynamic>.from(item));
          _operations.add(operation);
        } catch (e) {
          LoggerFactory.error('Failed to parse operation: $e');
        }
      }

      // Ordenar por prioridad y fecha de creación
      _sortOperations();

      LoggerFactory.info(
          'Loaded ${_operations.length} operations from storage');
    } catch (e) {
      LoggerFactory.error('Failed to load operations: $e');
    }
  }

  /// Guarda operaciones en SharedPreferences
  Future<void> _saveOperations() async {
    if (_prefs == null) return;

    try {
      final jsonList = _operations.map((op) => op.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await _prefs!.setString(_queueKey, jsonString);

      LoggerFactory.debug('Saved ${_operations.length} operations to storage');
    } catch (e) {
      LoggerFactory.error('Failed to save operations: $e');
    }
  }

  /// Ordena operaciones por prioridad y fecha de creación
  void _sortOperations() {
    _operations.sort((a, b) {
      // Primero por prioridad (menor número = mayor prioridad)
      final priorityComparison = a.priority.compareTo(b.priority);
      if (priorityComparison != 0) return priorityComparison;

      // Luego por fecha de creación (más antiguas primero)
      return a.createdAt.compareTo(b.createdAt);
    });
  }

  /// Agrega una operación a la cola
  Future<void> enqueue(SyncOperation operation) async {
    await _ensureInitialized();

    // Verificar si ya existe una operación similar
    final existingIndex = _operations.indexWhere((op) =>
        op.entityType == operation.entityType &&
        op.entityId == operation.entityId &&
        op.type == operation.type &&
        op.userId == operation.userId &&
        !op.isCompleted);

    if (existingIndex != -1) {
      // Actualizar operación existente
      _operations[existingIndex] = operation;
      LoggerFactory.info('Updated existing operation: ${operation.toString()}');
    } else {
      // Agregar nueva operación
      _operations.add(operation);
      LoggerFactory.info('Enqueued new operation: ${operation.toString()}');
    }

    _sortOperations();
    await _saveOperations();
  }

  /// Obtiene la próxima operación lista para ejecutar
  Future<SyncOperation?> dequeue() async {
    await _ensureInitialized();

    for (final operation in _operations) {
      if (operation.isReadyToExecute) {
        LoggerFactory.debug('Dequeued operation: ${operation.toString()}');
        return operation;
      }
    }

    return null;
  }

  /// Obtiene múltiples operaciones listas para ejecutar
  Future<List<SyncOperation>> dequeueBatch({int maxCount = 10}) async {
    await _ensureInitialized();

    final readyOperations = <SyncOperation>[];

    for (final operation in _operations) {
      if (operation.isReadyToExecute && readyOperations.length < maxCount) {
        readyOperations.add(operation);
      }
    }

    LoggerFactory.debug(
        'Dequeued batch of ${readyOperations.length} operations');
    return readyOperations;
  }

  /// Actualiza el estado de una operación
  Future<void> updateOperation(SyncOperation updatedOperation) async {
    await _ensureInitialized();

    final index = _operations.indexWhere((op) => op.id == updatedOperation.id);
    if (index != -1) {
      _operations[index] = updatedOperation;
      await _saveOperations();

      LoggerFactory.debug('Updated operation: ${updatedOperation.toString()}');
    } else {
      LoggerFactory.warning(
          'Operation not found for update: ${updatedOperation.id}');
    }
  }

  /// Marca una operación como completada y la elimina de la cola
  Future<void> markCompleted(String operationId) async {
    await _ensureInitialized();

    final index = _operations.indexWhere((op) => op.id == operationId);
    if (index != -1) {
      final operation = _operations[index];
      _operations[index] = operation.markAsCompleted();

      // Opcional: eliminar operaciones completadas después de un tiempo
      _scheduleCleanup();
      await _saveOperations();

      LoggerFactory.info('Marked operation as completed: $operationId');
    }
  }

  /// Marca una operación como fallida
  Future<void> markFailed(String operationId, String errorMessage) async {
    await _ensureInitialized();

    final index = _operations.indexWhere((op) => op.id == operationId);
    if (index != -1) {
      final operation = _operations[index];
      final updatedOperation = operation.markAsFailed(errorMessage);

      if (updatedOperation.canRetry) {
        // Programar reintento
        _operations[index] = updatedOperation.scheduleRetry();
        LoggerFactory.info(
            'Scheduled retry for operation: $operationId (attempt ${updatedOperation.retryCount + 1}/${updatedOperation.maxRetries})');
      } else {
        // Máximo de reintentos alcanzado
        _operations[index] = updatedOperation;
        LoggerFactory.error(
            'Operation failed permanently: $operationId - $errorMessage');
      }

      await _saveOperations();
    }
  }

  /// Obtiene todas las operaciones de un tipo específico
  Future<List<SyncOperation>> getOperationsByType(String entityType) async {
    await _ensureInitialized();

    return _operations.where((op) => op.entityType == entityType).toList();
  }

  /// Obtiene operaciones por estado
  Future<List<SyncOperation>> getOperationsByStatus(
      SyncOperationStatus status) async {
    await _ensureInitialized();

    return _operations.where((op) => op.status == status).toList();
  }

  /// Obtiene estadísticas de la cola
  Future<Map<String, int>> getQueueStatistics() async {
    await _ensureInitialized();

    final stats = <String, int>{
      'total': _operations.length,
      'pending': 0,
      'processing': 0,
      'completed': 0,
      'failed': 0,
      'cancelled': 0,
      'ready_to_execute': 0,
    };

    for (final operation in _operations) {
      stats[operation.status.value.toLowerCase()] =
          (stats[operation.status.value.toLowerCase()] ?? 0) + 1;

      if (operation.isReadyToExecute) {
        stats['ready_to_execute'] = (stats['ready_to_execute'] ?? 0) + 1;
      }
    }

    return stats;
  }

  /// Cancela una operación específica
  Future<void> cancelOperation(String operationId) async {
    await _ensureInitialized();

    final index = _operations.indexWhere((op) => op.id == operationId);
    if (index != -1) {
      _operations[index] = _operations[index].copyWith(
        status: SyncOperationStatus.cancelled,
        lastAttemptAt: SyncUtilities.utcNow(),
      );

      await _saveOperations();
      LoggerFactory.info('Cancelled operation: $operationId');
    }
  }

  /// Cancela todas las operaciones de un tipo específico
  Future<void> cancelOperationsByType(String entityType) async {
    await _ensureInitialized();

    int cancelledCount = 0;
    for (int i = 0; i < _operations.length; i++) {
      if (_operations[i].entityType == entityType &&
          !_operations[i].isCompleted) {
        _operations[i] = _operations[i].copyWith(
          status: SyncOperationStatus.cancelled,
          lastAttemptAt: SyncUtilities.utcNow(),
        );
        cancelledCount++;
      }
    }

    if (cancelledCount > 0) {
      await _saveOperations();
      LoggerFactory.info(
          'Cancelled $cancelledCount operations of type: $entityType');
    }
  }

  /// Limpia operaciones completadas y canceladas antiguas
  Future<void> cleanup({Duration? olderThan}) async {
    await _ensureInitialized();

    final cutoffTime =
        DateTime.now().subtract(olderThan ?? const Duration(days: 7));
    final initialCount = _operations.length;

    _operations.removeWhere((operation) {
      return (operation.isCompleted || operation.isCancelled) &&
          operation.createdAt.isBefore(cutoffTime);
    });

    final removedCount = initialCount - _operations.length;
    if (removedCount > 0) {
      await _saveOperations();
      LoggerFactory.info('Cleaned up $removedCount old operations');
    }
  }

  /// Programa limpieza automática
  void _scheduleCleanup() {
    // Limpieza cada 24 horas
    Timer(const Duration(hours: 24), () {
      cleanup();
    });
  }

  /// Limpia completamente la cola (para testing o reset)
  Future<void> clear() async {
    await _ensureInitialized();

    _operations.clear();
    await _saveOperations();

    LoggerFactory.info('Cleared all operations from queue');
  }

  /// Obtiene el tamaño actual de la cola
  Future<int> get size async {
    await _ensureInitialized();
    return _operations.length;
  }

  /// Indica si la cola está vacía
  Future<bool> get isEmpty async {
    await _ensureInitialized();
    return _operations.isEmpty;
  }

  /// Indica si hay operaciones listas para ejecutar
  Future<bool> get hasReadyOperations async {
    await _ensureInitialized();
    return _operations.any((op) => op.isReadyToExecute);
  }
}
