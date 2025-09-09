import 'dart:async';
import 'dart:convert';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logging/logger_factory.dart';
import 'entity_sync_manager.dart';
import 'sync_coordinator.dart';
import 'sync_operation.dart';
import 'realtime_channel_pool.dart';
import 'realtime_performance_monitor.dart';
import 'realtime_data_validator.dart';
import '../../domain/entities/sync_result.dart';
import '../../domain/entities/syncable_entity.dart';
import '../../domain/repositories/syncable_repository.dart';

/// Versión optimizada del BaseHybridRepository con mejoras en rendimiento,
/// cache inteligente, gestión de subscripciones y serialización optimizada
abstract class OptimizedHybridRepository<T extends SyncableEntity>
    implements SyncableRepository<T> {
  OptimizedHybridRepository({
    required this.userId,
    required this.entityType,
    EntitySyncManager<T>? syncManager,
    SyncCoordinator? syncCoordinator,
    RealtimeChannelPool? channelPool,
    RealtimePerformanceMonitor? performanceMonitor,
    RealtimeDataValidator? dataValidator,
    int cacheMaxSize = 1000,
    Duration cacheExpiry = const Duration(minutes: 30),
  })  : _syncManager = syncManager,
        _syncCoordinator = syncCoordinator,
        _channelPool = channelPool ?? RealtimeChannelPool.instance,
        _performanceMonitor = performanceMonitor ?? RealtimePerformanceMonitor.instance,
        _dataValidator = dataValidator ?? RealtimeDataValidator.instance,
        _cacheMaxSize = cacheMaxSize,
        _cacheExpiry = cacheExpiry {
    _initialize();
  }

  final String userId;
  final String entityType;
  final EntitySyncManager<T>? _syncManager;
  final SyncCoordinator? _syncCoordinator;
  final RealtimeChannelPool _channelPool;
  final RealtimePerformanceMonitor _performanceMonitor;
  final RealtimeDataValidator _dataValidator;
  final int _cacheMaxSize;
  final Duration _cacheExpiry;

  // Cache inteligente con LRU y expiración
  final LinkedHashMap<String, CacheEntry<T>> _entityCache = LinkedHashMap();
  final LinkedHashMap<String, CacheEntry<List<T>>> _queryCache = LinkedHashMap();
  
  // Pool de subscripciones real-time optimizado
  String? _channelId;
  
  // Serialización optimizada con pool de objetos
  final Queue<Map<String, dynamic>> _serializationPool = Queue();
  
  // Gestión de eventos optimizada
  final StreamController<RepositoryEvent<T>> _eventController =
      StreamController<RepositoryEvent<T>>.broadcast();
  
  // Throttling para operaciones batch
  Timer? _batchTimer;
  final List<BatchOperation<T>> _pendingBatchOperations = [];
  
  // Estado del repositorio
  bool _isInitialized = false;
  bool _isDisposed = false;
  
  // Métricas de rendimiento
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _serializationCount = 0;
  int _deserializationCount = 0;

  /// Stream de eventos del repositorio
  Stream<RepositoryEvent<T>> get events => _eventController.stream;

  /// Indica si el repositorio está inicializado
  bool get isInitialized => _isInitialized;

  /// Estadísticas de cache
  Map<String, dynamic> get cacheStatistics => {
    'entity_cache_size': _entityCache.length,
    'query_cache_size': _queryCache.length,
    'cache_hits': _cacheHits,
    'cache_misses': _cacheMisses,
    'hit_ratio': _cacheHits + _cacheMisses > 0 
        ? _cacheHits / (_cacheHits + _cacheMisses) 
        : 0.0,
    'serialization_count': _serializationCount,
    'deserialization_count': _deserializationCount,
  };

  // =============================================
  // MÉTODOS ABSTRACTOS - IMPLEMENTAR EN SUBCLASES
  // =============================================

  /// Devuelve el nombre de la tabla de Supabase para la entidad
  String get tableName;

  /// Deserializa los datos de Supabase a una entidad (optimizado)
  T deserializeFromRemote(Map<String, dynamic> data);

  /// Serializa entidad a JSON para Supabase (optimizado)
  Map<String, dynamic> serializeForRemote(T entity);

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
  // INICIALIZACIÓN OPTIMIZADA
  // =============================================

  /// Inicialización del repositorio con optimizaciones
  Future<void> _initialize() async {
    if (_isInitialized || _isDisposed) return;

    try {
      // Inicializar almacenamiento local
      await initializeLocal();
      
      // Configurar subscripción real-time optimizada
      await _setupOptimizedRealtimeSubscription();
      
      // Inicializar cache con datos existentes
      await _warmupCache();
      
      _isInitialized = true;
      
      _emitEvent(RepositoryEventType.initialized, 'Repository initialized with optimizations');
      LoggerFactory.info('✅ OptimizedHybridRepository<$entityType> initialized');
      
    } catch (e) {
      LoggerFactory.error('❌ Failed to initialize optimized repository: $e');
      _isInitialized = true; // Continue even if initialization fails
    }
  }

  /// Configura subscripción real-time optimizada usando el pool de canales
  Future<void> _setupOptimizedRealtimeSubscription() async {
    if (userId == 'anonymous_user') return;

    try {
      final channelConfig = ChannelConfig(
        tableName: tableName,
        userId: userId,
        filters: _buildOptimizedFilters(),
        heartbeatInterval: _calculateOptimalHeartbeat(),
      );

      _channelId = await _channelPool.getOrCreateChannel(
        config: channelConfig,
        onEvent: _handleOptimizedRealtimePayload,
      );

      LoggerFactory.info('⚡️ Optimized realtime subscription setup for $tableName');
      
    } catch (e) {
      LoggerFactory.error('❌ Failed to setup optimized realtime subscription: $e');
    }
  }

  /// Construye filtros PostgreSQL optimizados
  Map<String, String> _buildOptimizedFilters() {
    return {
      'user_id': 'eq.$userId',
      'is_deleted': 'eq.false', // Filtrar eliminados a nivel de DB
    };
  }

  /// Calcula intervalo de heartbeat óptimo basado en la actividad
  Duration _calculateOptimalHeartbeat() {
    // Ajustar según la frecuencia de cambios esperada
    final baseInterval = const Duration(seconds: 30);
    
    // Reducir intervalo si hay mucha actividad reciente
    final recentActivity = _performanceMonitor.getRecentActivity(tableName);
    if (recentActivity > 10) {
      return Duration(seconds: baseInterval.inSeconds ~/ 2);
    }
    
    return baseInterval;
  }

  /// Precarga cache con datos frecuentemente accedidos
  Future<void> _warmupCache() async {
    try {
      final localData = await getLocalData();
      
      // Cachear entidades más recientes
      final recentEntities = localData
          .where((e) => e.updatedAt.isAfter(
              DateTime.now().subtract(const Duration(hours: 24))))
          .take(_cacheMaxSize ~/ 2)
          .toList();
      
      for (final entity in recentEntities) {
        _cacheEntity(entity);
      }
      
      // Cachear consulta completa si es pequeña
      if (localData.length <= 100) {
        _cacheQuery('all', localData);
      }
      
      LoggerFactory.info('🔥 Cache warmed up with ${recentEntities.length} entities');
      
    } catch (e) {
      LoggerFactory.warning('⚠️ Cache warmup failed: $e');
    }
  }

  // =============================================
  // CACHE INTELIGENTE
  // =============================================

  /// Obtiene entidad del cache o la carga
  Future<T?> _getCachedEntity(String id) async {
    final cacheEntry = _entityCache[id];
    
    if (cacheEntry != null && !cacheEntry.isExpired) {
      _cacheHits++;
      // Mover al final (LRU)
      _entityCache.remove(id);
      _entityCache[id] = cacheEntry;
      return cacheEntry.data;
    }
    
    _cacheMisses++;
    return null;
  }

  /// Cachea una entidad
  void _cacheEntity(T entity) {
    if (_entityCache.length >= _cacheMaxSize) {
      // Remover el más antiguo (LRU)
      _entityCache.remove(_entityCache.keys.first);
    }
    
    _entityCache[entity.id] = CacheEntry(
      data: entity,
      timestamp: DateTime.now(),
      expiry: _cacheExpiry,
    );
  }

  /// Obtiene resultado de consulta del cache
  List<T>? _getCachedQuery(String queryKey) {
    final cacheEntry = _queryCache[queryKey];
    
    if (cacheEntry != null && !cacheEntry.isExpired) {
      _cacheHits++;
      // Mover al final (LRU)
      _queryCache.remove(queryKey);
      _queryCache[queryKey] = cacheEntry;
      return cacheEntry.data;
    }
    
    _cacheMisses++;
    return null;
  }

  /// Cachea resultado de consulta
  void _cacheQuery(String queryKey, List<T> results) {
    if (_queryCache.length >= _cacheMaxSize ~/ 4) {
      // Remover el más antiguo (LRU)
      _queryCache.remove(_queryCache.keys.first);
    }
    
    _queryCache[queryKey] = CacheEntry(
      data: List.from(results),
      timestamp: DateTime.now(),n      expiry: _cacheExpiry,
    );
  }

  /// Invalida cache para una entidad
  void _invalidateEntityCache(String id) {
    _entityCache.remove(id);
    
    // Invalidar consultas que puedan contener esta entidad
    _queryCache.clear();
  }

  /// Limpia cache expirado
  void _cleanExpiredCache() {
    final now = DateTime.now();
    
    _entityCache.removeWhere((key, entry) => entry.isExpired);
    _queryCache.removeWhere((key, entry) => entry.isExpired);
  }

  // =============================================
  // SERIALIZACIÓN OPTIMIZADA
  // =============================================

  /// Serializa entidad usando pool de objetos
  Map<String, dynamic> _optimizedSerialize(T entity) {
    _serializationCount++;
    
    // Reutilizar mapa del pool si está disponible
    Map<String, dynamic> map;
    if (_serializationPool.isNotEmpty) {
      map = _serializationPool.removeFirst();
      map.clear();
    } else {
      map = <String, dynamic>{};
    }
    
    // Usar método optimizado de la subclase
    final result = serializeForRemote(entity);
    
    // Devolver mapa al pool
    if (_serializationPool.length < 10) {
      _serializationPool.add(map);
    }
    
    return result;
  }

  /// Deserializa con validación y cache
  T _optimizedDeserialize(Map<String, dynamic> data) {
    _deserializationCount++;
    
    // Validar datos antes de deserializar
    final validationResult = _dataValidator.validateRealtimeEvent(
      tableName: tableName,
      eventData: {'table': tableName, 'schema': 'public'},
      eventType: 'INSERT',
      newRecord: data,
    );
    
    if (!validationResult.isValid) {
      throw Exception('Data validation failed: ${validationResult.message}');
    }
    
    return deserializeFromRemote(data);
  }

  // =============================================
  // OPERACIONES BATCH OPTIMIZADAS
  // =============================================

  /// Procesa operaciones en batch para mejor rendimiento
  void _queueBatchOperation(BatchOperation<T> operation) {
    _pendingBatchOperations.add(operation);
    
    // Configurar timer para procesar batch
    _batchTimer?.cancel();
    _batchTimer = Timer(const Duration(milliseconds: 100), _processBatchOperations);
  }

  /// Procesa todas las operaciones batch pendientes
  Future<void> _processBatchOperations() async {
    if (_pendingBatchOperations.isEmpty) return;
    
    final operations = List<BatchOperation<T>>.from(_pendingBatchOperations);
    _pendingBatchOperations.clear();
    
    try {
      // Agrupar operaciones por tipo
      final creates = operations.where((op) => op.type == BatchOperationType.create).toList();
      final updates = operations.where((op) => op.type == BatchOperationType.update).toList();
      final deletes = operations.where((op) => op.type == BatchOperationType.delete).toList();
      
      // Procesar cada tipo en batch
      if (creates.isNotEmpty) {
        await _processBatchCreates(creates);
      }
      
      if (updates.isNotEmpty) {
        await _processBatchUpdates(updates);
      }
      
      if (deletes.isNotEmpty) {
        await _processBatchDeletes(deletes);
      }
      
      LoggerFactory.info('📦 Processed batch: ${creates.length} creates, ${updates.length} updates, ${deletes.length} deletes');
      
    } catch (e) {
      LoggerFactory.error('❌ Batch processing failed: $e');
    }
  }

  Future<void> _processBatchCreates(List<BatchOperation<T>> operations) async {
    for (final op in operations) {
      if (op.entity != null) {
        await saveToLocal(op.entity!);
        _cacheEntity(op.entity!);
      }
    }
  }

  Future<void> _processBatchUpdates(List<BatchOperation<T>> operations) async {
    for (final op in operations) {
      if (op.entity != null) {
        await updateLocal(op.entity!);
        _cacheEntity(op.entity!);
        _invalidateEntityCache(op.entity!.id);
      }
    }
  }

  Future<void> _processBatchDeletes(List<BatchOperation<T>> operations) async {
    for (final op in operations) {
      if (op.entityId != null) {
        await removeFromLocal(op.entityId!);
        _invalidateEntityCache(op.entityId!);
      }
    }
  }

  // =============================================
  // MANEJO DE EVENTOS REAL-TIME OPTIMIZADO
  // =============================================

  /// Maneja eventos real-time con validación y optimizaciones
  Future<void> _handleOptimizedRealtimePayload(PostgresChangePayload payload) async {
    final startTime = DateTime.now();
    
    try {
      // Registrar métricas
      _performanceMonitor.recordRealtimeEvent(
        tableName: tableName,
        eventType: payload.eventType.name,
        processingStartTime: startTime,
      );
      
      // Validar evento
      final validationResult = _dataValidator.validateRealtimeEvent(
        tableName: tableName,
        eventData: {
          'table': payload.table,
          'schema': payload.schema,
        },
        eventType: payload.eventType.name,
        oldRecord: payload.oldRecord,
        newRecord: payload.newRecord,
      );
      
      if (!validationResult.isValid) {
        LoggerFactory.warning('⚠️ Invalid realtime event: ${validationResult.message}');
        return;
      }
      
      // Procesar evento según tipo
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          if (payload.newRecord != null) {
            final entity = _optimizedDeserialize(payload.newRecord!);
            
            _queueBatchOperation(BatchOperation(
              type: payload.eventType == PostgresChangeEvent.insert 
                  ? BatchOperationType.create 
                  : BatchOperationType.update,
              entity: entity,
            ));
            
            _emitEvent(
              RepositoryEventType.itemUpdated,
              'Realtime ${payload.eventType.name}',
              entity: entity,
            );
          }
          break;
          
        case PostgresChangeEvent.delete:
          if (payload.oldRecord != null) {
            final entityId = payload.oldRecord!['id']?.toString();
            if (entityId != null) {
              _queueBatchOperation(BatchOperation(
                type: BatchOperationType.delete,
                entityId: entityId,
              ));
              
              _emitEvent(
                RepositoryEventType.itemRemoved,
                'Realtime delete',
                entityId: entityId,
              );
            }
          }
          break;
          
        case PostgresChangeEvent.all:
          LoggerFactory.debug('Unhandled realtime event type: ${payload.eventType}');
          break;
      }
      
      // Registrar métricas de finalización
      final processingTime = DateTime.now().difference(startTime);
      _performanceMonitor.recordRealtimeEvent(
        tableName: tableName,
        eventType: payload.eventType.name,
        processingStartTime: startTime,
        processingEndTime: DateTime.now(),
      );
      
    } catch (e) {
      LoggerFactory.error('❌ Error processing realtime event: $e');
      
      _performanceMonitor.recordRealtimeError(
        tableName: tableName,
        error: e.toString(),
      );
    }
  }

  // =============================================
  // OPERACIONES CRUD OPTIMIZADAS
  // =============================================

  /// Obtiene entidad por ID con cache
  Future<dynamic> getById(String id) async {
    if (!_isInitialized) await _initialize();
    
    // Intentar desde cache primero
    final cachedEntity = await _getCachedEntity(id);
    if (cachedEntity != null) {
      return convertToModel(cachedEntity);
    }
    
    // Buscar en almacenamiento local
    final localData = await getLocalData();
    final entity = localData.where((e) => e.id == id).firstOrNull;
    
    if (entity != null) {
      _cacheEntity(entity);
      return convertToModel(entity);
    }
    
    return null;
  }

  /// Obtiene todos los elementos con cache inteligente
  Future<List<dynamic>> getAll() async {
    if (!_isInitialized) await _initialize();
    
    // Intentar desde cache de consulta
    final cachedResults = _getCachedQuery('all');
    if (cachedResults != null) {
      return cachedResults.map(convertToModel).toList();
    }
    
    // Obtener desde almacenamiento local
    final entities = await getLocalData();
    
    // Cachear resultado
    _cacheQuery('all', entities);
    
    // Cachear entidades individuales también
    for (final entity in entities.take(50)) { // Limitar para evitar sobrecarga
      _cacheEntity(entity);
    }
    
    return entities.map(convertToModel).toList();
  }

  /// Agrega elemento con optimizaciones
  Future<void> add(dynamic model) async {
    if (!_isInitialized) await _initialize();
    
    try {
      final entity = convertFromModel(model, userId);
      
      // Operación batch para mejor rendimiento
      _queueBatchOperation(BatchOperation(
        type: BatchOperationType.create,
        entity: entity,
      ));
      
      // Cola para sincronización
      await _queueForSync(entity, SyncOperationType.create);
      
      _emitEvent(RepositoryEventType.itemAdded, 'Item added with optimizations', entity: entity);
      LoggerFactory.info('➕ Added $entityType with optimizations: ${entity.id}');
      
    } catch (e) {
      LoggerFactory.error('❌ Failed to add $entityType: $e');
      _emitEvent(RepositoryEventType.error, 'Failed to add item: $e');
      rethrow;
    }
  }

  // =============================================
  // IMPLEMENTACIÓN DE SyncableRepository
  // =============================================

  @override
  Future<void> syncWithSupabase() async {
    if (!_isInitialized) await _initialize();
    
    if (_syncManager != null) {
      try {
        _emitEvent(RepositoryEventType.syncStarted, 'Optimized sync started');
        
        final result = await _syncManager!.performFullSync();
        
        // Limpiar cache después de sync exitoso
        if (result.success) {
          _queryCache.clear();
          _cleanExpiredCache();
        }
        
        _emitEvent(
          result.success ? RepositoryEventType.syncCompleted : RepositoryEventType.syncError,
          'Optimized sync ${result.success ? 'completed' : 'failed'}: ${result.toString()}',
          result: result,
        );
        
      } catch (e) {
        LoggerFactory.error('❌ Optimized sync failed: $e');
        _emitEvent(RepositoryEventType.syncError, 'Optimized sync failed: $e');
        rethrow;
      }
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
      final result = await _syncManager!.uploadChanges(items);
      if (!result.success) {
        throw Exception('Upload failed: ${result.errors.join(', ')}');
      }
    }
  }

  @override
  Future<void> download(List<T> items) async {
    if (_syncManager != null && items.isNotEmpty) {
      final result = await _syncManager!.downloadChanges(items);
      if (!result.success) {
        throw Exception('Download failed: ${result.errors.join(', ')}');
      }
    }
  }

  @override
  Future<void> resolveConflicts(List<T> local, List<T> remote) async {
    if (_syncManager != null) {
      final conflicts = await _syncManager!.detectConflicts();
      for (final conflict in conflicts) {
        final resolved = await _syncManager!.resolveConflict(conflict);
        await updateLocal(resolved);
        _invalidateEntityCache(resolved.id);
      }
    }
  }

  @override
  Future<bool> hasPendingSync() async {
    if (_syncCoordinator != null) {
      final stats = await _syncCoordinator!.getSyncStatistics();
      final queueStats = stats['queue'] as Map<String, dynamic>? ?? {};
      return (queueStats['ready_to_execute'] as int? ?? 0) > 0;
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
  // MÉTODOS DE UTILIDAD
  // =============================================

  /// Cola una entidad para sincronización
  Future<void> _queueForSync(T? entity, SyncOperationType operationType, {String? entityId}) async {
    if (_syncCoordinator != null) {
      Map<String, dynamic> data;
      
      if (entity != null) {
        data = _optimizedSerialize(entity);
      } else if (operationType == SyncOperationType.delete && entityId != null) {
        data = {'id': entityId, 'is_deleted': true};
      } else {
        return;
      }
      
      await _syncCoordinator!.queueSyncOperation(
        entityType: entityType,
        entityId: entity?.id ?? entityId!,
        type: operationType,
        data: data,
        priority: _getOperationPriority(operationType),
      );
    }
  }

  /// Obtiene prioridad para diferentes tipos de operación
  int _getOperationPriority(SyncOperationType operationType) {
    switch (operationType) {
      case SyncOperationType.delete:
        return 2;
      case SyncOperationType.create:
        return 3;
      case SyncOperationType.update:
        return 4;
      case SyncOperationType.merge:
        return 1;
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
    if (_isDisposed) return;
    
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

  /// Obtiene estadísticas completas del repositorio
  Future<Map<String, dynamic>> getStatistics() async {
    final localData = await getLocalData();
    
    return {
      'entity_type': entityType,
      'local_count': localData.length,
      'is_initialized': _isInitialized,
      'cache_stats': cacheStatistics,
      'performance_stats': _performanceMonitor.getTableMetrics(tableName)?.toMap() ?? {},
      'sync_manager_available': _syncManager != null,
      'coordinator_available': _syncCoordinator != null,
      'channel_pool_stats': _channelPool.getStatistics(),
    };
  }

  /// Libera recursos optimizadamente
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    _isDisposed = true;
    
    // Cancelar timers
    _batchTimer?.cancel();
    
    // Procesar operaciones batch pendientes
    if (_pendingBatchOperations.isNotEmpty) {
      await _processBatchOperations();
    }
    
    // Liberar canal del pool
    if (_channelId != null) {
      await _channelPool.releaseChannel(_channelId!);
    }
    
    // Limpiar caches
    _entityCache.clear();
    _queryCache.clear();
    _serializationPool.clear();
    
    // Cerrar stream
    await _eventController.close();
    
    LoggerFactory.info('🔒 OptimizedHybridRepository<$entityType> disposed');
  }
}

// =============================================
// CLASES DE SOPORTE
// =============================================

/// Entrada de cache con expiración
class CacheEntry<T> {
  CacheEntry({
    required this.data,
    required this.timestamp,
    required this.expiry,
  });
  
  final T data;
  final DateTime timestamp;
  final Duration expiry;
  
  bool get isExpired => DateTime.now().difference(timestamp) > expiry;
}

/// Operación batch para procesamiento optimizado
class BatchOperation<T> {
  BatchOperation({
    required this.type,
    this.entity,
    this.entityId,
  });
  
  final BatchOperationType type;
  final T? entity;
  final String? entityId;
}

/// Tipos de operaciones batch
enum BatchOperationType {
  create,
  update,
  delete,
}

/// Evento del repositorio optimizado
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