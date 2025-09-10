import 'dart:async';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logging/logger_factory.dart';
import '../../core/sync/sync_coordinator.dart';
import '../../core/sync/sync_operation.dart';
import 'connectivity_manager.dart';

/// Configuración para retry logic
class RetryConfig {
  const RetryConfig({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
    this.timeout = const Duration(seconds: 10),
  });

  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  final Duration timeout;
}

/// Gestor de sincronización en tiempo real usando Supabase Realtime
/// Maneja listeners, eventos y propagación de cambios locales
class RealtimeSyncManager {
  RealtimeSyncManager({
    required this.userId,
    required this.syncCoordinator,
    required this.connectivityManager,
  }) : _supabase = Supabase.instance.client {
    _initialize();
  }

  final String userId;
  final SyncCoordinator syncCoordinator;
  final ConnectivityManager connectivityManager;
  final SupabaseClient _supabase;

  // Cache de configuraciones adaptativas
  final Map<String, DateTime> _lastConfigUpdate = {};

  // Estado interno
  bool _isInitialized = false;
  bool _isListening = false;
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, StreamSubscription> _subscriptions = {};

  // Throttling y batching optimizado
  final Map<String, Timer> _throttleTimers = {};
  final Map<String, List<RealtimeEvent>> _batchedEvents = {};
  static const Duration _throttleDelay = Duration(milliseconds: 300);
  static const int _maxBatchSize = 15;
  static const int _criticalBatchSize = 25; // Para eventos críticos

  // Configuraciones adaptativas por tabla
  static const Map<String, int> _tableBatchSizes = {
    'user_watchlist': 20,
    'user_favorites': 15,
    'user_watched_movies': 25,
    'user_lists': 10,
    'user_list_items': 30,
  };

  static const Map<String, Duration> _tableThrottleDelays = {
    'user_watchlist': Duration(milliseconds: 250),
    'user_favorites': Duration(milliseconds: 200),
    'user_watched_movies': Duration(milliseconds: 400),
    'user_lists': Duration(milliseconds: 300),
    'user_list_items': Duration(milliseconds: 150),
  };

  // Eventos
  final StreamController<RealtimeSyncEvent> _eventController =
      StreamController<RealtimeSyncEvent>.broadcast();

  // Configuración de retry
  static const RetryConfig _defaultRetryConfig = RetryConfig();
  static const RetryConfig _criticalRetryConfig = RetryConfig(
    maxRetries: 5,
    initialDelay: Duration(milliseconds: 500),
    timeout: Duration(seconds: 15),
  );

  /// Stream de eventos de sincronización en tiempo real
  Stream<RealtimeSyncEvent> get events => _eventController.stream;

  /// Ejecuta una operación con retry y backoff exponencial
  Future<T> _executeWithRetry<T>(
    Future<T> Function() operation, {
    RetryConfig config = _defaultRetryConfig,
    String? operationName,
  }) async {
    int attempt = 0;
    Duration delay = config.initialDelay;

    while (attempt < config.maxRetries) {
      try {
        return await operation().timeout(config.timeout);
      } catch (e) {
        attempt++;

        if (attempt >= config.maxRetries) {
          LoggerFactory.error(
              '❌ ${operationName ?? "Operation"} failed after $attempt attempts: $e');
          rethrow;
        }

        LoggerFactory.warning(
            '⚠️ ${operationName ?? "Operation"} failed (attempt $attempt/${config.maxRetries}), retrying in ${delay.inMilliseconds}ms: $e');

        await Future.delayed(delay);
        delay = Duration(
          milliseconds: min(
            (delay.inMilliseconds * config.backoffMultiplier).round(),
            config.maxDelay.inMilliseconds,
          ),
        );
      }
    }

    throw StateError('Retry logic should not reach this point');
  }

  /// Indica si está escuchando cambios en tiempo real
  bool get isListening => _isListening;

  /// Indica si está inicializado
  bool get isInitialized => _isInitialized;

  /// Inicialización del manager
  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      // Escuchar cambios de conectividad
      _subscriptions['connectivity'] = connectivityManager.connectionStatus
          .listen(_handleConnectivityChange);

      _isInitialized = true;
      _emitEvent(
          RealtimeSyncEventType.initialized, 'RealtimeSyncManager initialized');

      LoggerFactory.info('✅ RealtimeSyncManager initialized for user: $userId');
    } catch (e) {
      LoggerFactory.error('❌ Failed to initialize RealtimeSyncManager: $e');
      rethrow;
    }
  }

  /// Inicializa el manager de sincronización en tiempo real
  Future<void> initialize() async {
    if (_isListening) {
      LoggerFactory.warning('⚠️ RealtimeSyncManager already initialized');
      return;
    }

    await _executeWithRetry(
      () async {
        await startListeners();
        LoggerFactory.info('🚀 RealtimeSyncManager initialized successfully');
      },
      config: _criticalRetryConfig,
      operationName: 'RealtimeSyncManager initialization',
    );
  }

  /// Inicia los listeners de tiempo real
  Future<void> startListeners() async {
    if (_isListening) {
      LoggerFactory.warning('⚠️ Realtime listeners already active');
      return;
    }

    try {
      await _setupRealtimeListeners();
      _isListening = true;
      LoggerFactory.info('🎧 Realtime listeners started');
    } catch (e) {
      LoggerFactory.error('❌ Failed to start realtime listeners: $e');
      rethrow;
    }
  }

  /// Configura los listeners de tiempo real para las tablas
  Future<void> _setupRealtimeListeners() async {
    try {
      await _setupRealtimeChannels();
      LoggerFactory.info('🎧 Realtime listeners configured successfully');
    } catch (e) {
      LoggerFactory.error('❌ Failed to setup realtime listeners: $e');
      rethrow;
    }
  }

  /// Inicia la escucha de cambios en tiempo real
  Future<void> startListening() async {
    if (!_isInitialized) await _initialize();
    if (_isListening) return;

    try {
      // Solo iniciar si hay conexión
      final connectionStatus = connectivityManager.currentStatus;
      if (connectionStatus != ConnectionStatus.online) {
        LoggerFactory.info(
            '⏸️ Skipping realtime listening - not online: $connectionStatus');
        return;
      }

      await _executeWithRetry(
        () async {
          await _setupRealtimeChannels();
          _isListening = true;
        },
        config: _criticalRetryConfig,
        operationName: 'Setup realtime channels',
      );

      _emitEvent(
          RealtimeSyncEventType.listeningStarted, 'Started realtime listening');
      LoggerFactory.info('🎧 Started realtime listening');
    } catch (e) {
      LoggerFactory.error('❌ Failed to start realtime listening: $e');
      _emitEvent(RealtimeSyncEventType.error, 'Failed to start listening: $e');
      rethrow;
    }
  }

  /// Detiene la escucha de cambios en tiempo real
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _cleanupChannels();
      _isListening = false;

      _emitEvent(
          RealtimeSyncEventType.listeningStopped, 'Stopped realtime listening');
      LoggerFactory.info('🔇 Stopped realtime listening');
    } catch (e) {
      LoggerFactory.error('❌ Failed to stop realtime listening: $e');
    }
  }

  /// Configura los canales de Supabase Realtime
  Future<void> _setupRealtimeChannels() async {
    final tables = [
      'user_favorites',
      'user_watchlist',
      'user_watched_movies',
      'user_custom_lists'
    ];

    for (final table in tables) {
      await _setupTableChannel(table);
    }
  }

  /// Configura un canal para una tabla específica
  Future<void> _setupTableChannel(String tableName) async {
    await _executeWithRetry(
      () async {
        // Crear canal con filtro por usuario
        final channel = _supabase
            .channel('realtime:$tableName:$userId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: tableName,
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: userId,
              ),
              callback: (payload) => _handleRealtimeEvent(tableName, payload),
            );

        // Suscribir al canal
        channel.subscribe();
        _channels[tableName] = channel;

        LoggerFactory.info('📡 Setup realtime channel for $tableName');
      },
      config: _defaultRetryConfig,
      operationName: 'Setup channel for $tableName',
    );
  }

  /// Maneja eventos de Supabase Realtime
  void _handleRealtimeEvent(String tableName, PostgresChangePayload payload) {
    try {
      final event = RealtimeEvent(
        tableName: tableName,
        eventType: _mapEventType(payload.eventType),
        oldRecord: payload.oldRecord,
        newRecord: payload.newRecord,
        timestamp: DateTime.now(),
      );

      // Aplicar throttling y batching
      _throttleAndBatchEvent(tableName, event);

      LoggerFactory.info(
          '📨 Received realtime event: ${event.eventType} on $tableName');
    } catch (e) {
      LoggerFactory.error('❌ Failed to handle realtime event: $e');
    }
  }

  /// Aplica throttling y batching optimizado a los eventos
  void _throttleAndBatchEvent(String tableName, RealtimeEvent event) {
    // Agregar evento al batch
    _batchedEvents.putIfAbsent(tableName, () => []).add(event);

    // Obtener configuraciones adaptativas para la tabla
    final adaptiveBatchSize = _getAdaptiveBatchSize(tableName);
    final adaptiveDelay = _getAdaptiveThrottleDelay(tableName);

    // Usar throttling con Timer existente
    _throttleTimers[tableName]?.cancel();
    _throttleTimers[tableName] = Timer(adaptiveDelay, () {
      _processBatchedEvents(tableName);
    });

    // Procesar inmediatamente si el batch alcanza el tamaño adaptativo
    final currentBatchSize = _batchedEvents[tableName]!.length;
    if (currentBatchSize >= adaptiveBatchSize) {
      _throttleTimers[tableName]?.cancel();
      _processBatchedEvents(tableName);
    }

    // Registrar métricas de throttling
    _recordThrottlingMetrics(tableName, currentBatchSize, adaptiveBatchSize);
  }

  /// Registra métricas de rendimiento del throttling
  void _recordThrottlingMetrics(
      String tableName, int currentSize, int maxSize) {
    // Log periódico para debugging
    if (currentSize % 5 == 0) {
      LoggerFactory.debug(
          '📊 Batch status for $tableName: $currentSize/$maxSize');
    }

    // Alertas de rendimiento
    if (currentSize > maxSize * 0.8) {
      LoggerFactory.warning(
          '⚠️ High batch load for $tableName: $currentSize/$maxSize (${(currentSize / maxSize * 100).toStringAsFixed(1)}%)');
    }

    // Registrar en métricas de rendimiento
    // TODO: Implementar _performanceMetrics si es necesario
    // _performanceMetrics.recordBatchSize(tableName, currentSize);
    // _performanceMetrics.recordThrottlingEfficiency(
    //   tableName,
    //   currentSize / maxSize,
    // );
  }

  /// Obtiene el tamaño de batch adaptativo para una tabla
  int _getAdaptiveBatchSize(String tableName) {
    // Usar configuración específica de tabla si existe
    if (_tableBatchSizes.containsKey(tableName)) {
      return _tableBatchSizes[tableName]!;
    }

    // Adaptación basada en la carga actual
    final currentBatchSize = _batchedEvents[tableName]?.length ?? 0;
    if (currentBatchSize > 50) {
      return _criticalBatchSize; // Procesar en lotes más grandes bajo alta carga
    }

    return _maxBatchSize;
  }

  /// Obtiene el delay de throttle adaptativo para una tabla
  Duration _getAdaptiveThrottleDelay(String tableName) {
    // Actualizar configuraciones adaptativas si es necesario
    _updateAdaptiveConfig(tableName);

    // Usar configuración específica de tabla si existe
    if (_tableThrottleDelays.containsKey(tableName)) {
      return _tableThrottleDelays[tableName]!;
    }

    // Adaptación basada en la carga actual
    final currentBatchSize = _batchedEvents[tableName]?.length ?? 0;
    if (currentBatchSize > 30) {
      return const Duration(
          milliseconds: 100); // Procesar más rápido bajo alta carga
    } else if (currentBatchSize > 15) {
      return const Duration(milliseconds: 200);
    }

    return _throttleDelay;
  }

  /// Actualiza las configuraciones adaptativas para una tabla específica
  void _updateAdaptiveConfig(String tableName) {
    final now = DateTime.now();
    final lastUpdate = _lastConfigUpdate[tableName];

    // Solo actualizar cada 30 segundos para evitar overhead
    if (lastUpdate == null || now.difference(lastUpdate).inSeconds > 30) {
      final currentLoad = _batchedEvents[tableName]?.length ?? 0;

      // Log de configuración adaptativa
      if (currentLoad > 20) {
        LoggerFactory.debug(
            '⚡ High load detected for $tableName: $currentLoad events, adapting configuration');
      }

      _lastConfigUpdate[tableName] = now;
    }
  }

  /// Procesa eventos en batch con optimizaciones avanzadas
  Future<void> _processBatchedEvents(String tableName) async {
    final events = _batchedEvents[tableName];
    if (events == null || events.isEmpty) return;

    final startTime = DateTime.now();

    try {
      LoggerFactory.info(
          '⚡ Processing ${events.length} batched events for $tableName');

      // Optimización: Deduplicar eventos por ID para evitar procesamiento redundante
      final deduplicatedEvents = _deduplicateEvents(events);
      final savedEvents = events.length - deduplicatedEvents.length;

      if (savedEvents > 0) {
        LoggerFactory.info(
            '🔄 Deduplicated $savedEvents redundant events for $tableName');
      }

      // Agrupar eventos por tipo para optimizar procesamiento
      final groupedEvents = <RealtimeEventType, List<RealtimeEvent>>{};
      for (final event in deduplicatedEvents) {
        groupedEvents.putIfAbsent(event.eventType, () => []).add(event);
      }

      // Procesar grupos en orden de prioridad (deletes primero, luego inserts, luego updates)
      final processingOrder = [
        RealtimeEventType.delete,
        RealtimeEventType.insert,
        RealtimeEventType.update,
      ];

      for (final eventType in processingOrder) {
        if (groupedEvents.containsKey(eventType)) {
          await _processEventGroup(
              tableName, eventType, groupedEvents[eventType]!);
        }
      }

      final processingTime = DateTime.now().difference(startTime);

      _emitEvent(
        RealtimeSyncEventType.batchProcessed,
        'Processed ${deduplicatedEvents.length}/${events.length} events for $tableName in ${processingTime.inMilliseconds}ms',
        metadata: {
          'table': tableName,
          'original_event_count': events.length,
          'processed_event_count': deduplicatedEvents.length,
          'deduplicated_count': savedEvents,
          'processing_time_ms': processingTime.inMilliseconds,
        },
      );

      // Registrar métricas de rendimiento
      if (processingTime.inMilliseconds > 1000) {
        LoggerFactory.warning(
            '⚠️ Slow batch processing for $tableName: ${processingTime.inMilliseconds}ms');
      }
    } catch (e) {
      LoggerFactory.error(
          '❌ Failed to process batched events for $tableName: $e');
      _emitEvent(RealtimeSyncEventType.error, 'Failed to process batch: $e');
    } finally {
      // Limpiar batch
      _batchedEvents[tableName]?.clear();
    }
  }

  /// Deduplica eventos basándose en ID y tipo para evitar procesamiento redundante
  List<RealtimeEvent> _deduplicateEvents(List<RealtimeEvent> events) {
    final seen = <String, RealtimeEvent>{};

    // Procesar eventos en orden inverso para mantener los más recientes
    for (int i = events.length - 1; i >= 0; i--) {
      final event = events[i];
      final recordId = _getEventRecordId(event);

      if (recordId != null) {
        final key = '${event.eventType}_$recordId';

        // Solo mantener el evento más reciente para cada combinación tipo+ID
        if (!seen.containsKey(key)) {
          seen[key] = event;
        }
      } else {
        // Si no podemos obtener ID, mantener el evento
        seen['${event.hashCode}'] = event;
      }
    }

    // Devolver eventos en orden original
    final result = <RealtimeEvent>[];
    for (final event in events) {
      final recordId = _getEventRecordId(event);
      final key = recordId != null
          ? '${event.eventType}_$recordId'
          : '${event.hashCode}';

      if (seen.containsKey(key) && seen[key] == event) {
        result.add(event);
        seen.remove(key); // Evitar duplicados
      }
    }

    return result;
  }

  /// Obtiene el ID del registro de un evento
  String? _getEventRecordId(RealtimeEvent event) {
    final record = event.newRecord ?? event.oldRecord;
    return record?['id']?.toString();
  }

  /// Procesa un grupo de eventos del mismo tipo
  Future<void> _processEventGroup(
    String tableName,
    RealtimeEventType eventType,
    List<RealtimeEvent> events,
  ) async {
    try {
      switch (eventType) {
        case RealtimeEventType.insert:
          await _handleInsertEvents(tableName, events);
          break;
        case RealtimeEventType.update:
          await _handleUpdateEvents(tableName, events);
          break;
        case RealtimeEventType.delete:
          await _handleDeleteEvents(tableName, events);
          break;
      }
    } catch (e) {
      LoggerFactory.error(
          '❌ Failed to process $eventType events for $tableName: $e');
    }
  }

  /// Maneja eventos de inserción
  Future<void> _handleInsertEvents(
      String tableName, List<RealtimeEvent> events) async {
    for (final event in events) {
      if (event.newRecord != null) {
        await _syncEntityFromRemote(tableName, event.newRecord!);
      }
    }
  }

  /// Maneja eventos de actualización
  Future<void> _handleUpdateEvents(
      String tableName, List<RealtimeEvent> events) async {
    for (final event in events) {
      if (event.newRecord != null) {
        await _syncEntityFromRemote(tableName, event.newRecord!);
      }
    }
  }

  /// Maneja eventos de eliminación
  Future<void> _handleDeleteEvents(
      String tableName, List<RealtimeEvent> events) async {
    for (final event in events) {
      if (event.oldRecord != null) {
        await _handleEntityDeletion(tableName, event.oldRecord!);
      }
    }
  }

  /// Sincroniza una entidad desde el servidor
  Future<void> _syncEntityFromRemote(
      String tableName, Map<String, dynamic> record) async {
    await _executeWithRetry(
      () async {
        final entityType = _mapTableToEntityType(tableName);
        if (entityType == null) {
          throw ArgumentError('Unknown table name: $tableName');
        }

        // Delegar al SyncCoordinator para manejar la sincronización
        await syncCoordinator.queueSyncOperation(
          entityType: entityType,
          entityId: record['id']?.toString() ?? '',
          type: SyncOperationType.update,
          data: record,
          priority: 1, // Alta prioridad para cambios en tiempo real
        );

        LoggerFactory.info('🔄 Queued sync for $entityType from realtime');
      },
      config: _defaultRetryConfig,
      operationName: 'Sync entity from remote ($tableName)',
    );
  }

  /// Maneja eliminación de entidad
  Future<void> _handleEntityDeletion(
      String tableName, Map<String, dynamic> record) async {
    await _executeWithRetry(
      () async {
        final entityType = _mapTableToEntityType(tableName);
        if (entityType == null) {
          throw ArgumentError('Unknown table name: $tableName');
        }

        await syncCoordinator.queueSyncOperation(
          entityType: entityType,
          entityId: record['id']?.toString() ?? '',
          type: SyncOperationType.delete,
          data: record,
          priority: 1,
        );

        LoggerFactory.info('🗑️ Queued deletion for $entityType from realtime');
      },
      config: _defaultRetryConfig,
      operationName: 'Handle entity deletion ($tableName)',
    );
  }

  /// Propaga cambios locales a otros dispositivos
  Future<void> propagateLocalChange({
    required String entityType,
    required String entityId,
    required SyncOperationType operationType,
    required Map<String, dynamic> data,
  }) async {
    if (!_isListening) return;

    try {
      // Los cambios locales se propagan automáticamente a través de Supabase
      // cuando se actualizan las tablas. Aquí podemos agregar lógica adicional
      // como notificaciones push o webhooks si es necesario.

      _emitEvent(
        RealtimeSyncEventType.localChangePropagated,
        'Propagated $operationType for $entityType($entityId)',
        metadata: {
          'entity_type': entityType,
          'entity_id': entityId,
          'operation': operationType.toString(),
        },
      );

      LoggerFactory.info(
          '📤 Propagated local change: $operationType $entityType($entityId)');
    } catch (e) {
      LoggerFactory.error('❌ Failed to propagate local change: $e');
    }
  }

  /// Maneja cambios de conectividad
  void _handleConnectivityChange(ConnectionStatus status) {
    LoggerFactory.info('🌐 Connectivity changed: $status');

    switch (status) {
      case ConnectionStatus.online:
        _onConnectionRestored();
        break;
      case ConnectionStatus.offline:
      case ConnectionStatus.limited:
        _onConnectionLost();
        break;
      case ConnectionStatus.manual:
        // No hacer nada automáticamente en modo manual
        break;
    }
  }

  /// Maneja restauración de conexión
  void _onConnectionRestored() {
    LoggerFactory.info(
        '🔄 Connection restored, attempting to restart realtime sync');

    if (!_isListening && _isInitialized) {
      // Reiniciar listeners con delay para evitar reconexiones rápidas
      Timer(const Duration(seconds: 2), () {
        if (!_isListening) {
          startListening();
          _emitEvent(
            RealtimeSyncEventType.connectionRestored,
            'Realtime sync restarted after connection recovery',
          );
        }
      });
    }
  }

  /// Maneja pérdida de conexión
  void _onConnectionLost() {
    LoggerFactory.info('📡 Connection lost, stopping realtime sync');

    if (_isListening) {
      stopListening();
      _emitEvent(
        RealtimeSyncEventType.connectionLost,
        'Realtime sync stopped due to connection loss',
      );
    }
  }

  /// Reinicia completamente el RealtimeSyncManager
  Future<void> restart() async {
    LoggerFactory.info('🔄 Restarting RealtimeSyncManager');

    await stopListening();
    await Future.delayed(const Duration(seconds: 1));

    if (_isInitialized) {
      startListening();
      _emitEvent(
        RealtimeSyncEventType.restarted,
        'RealtimeSyncManager restarted successfully',
      );
    }
  }

  /// Verifica el estado de salud de las conexiones
  Future<bool> checkConnectionHealth() async {
    try {
      return await _executeWithRetry(
        () async {
          // Verificar si Supabase está respondiendo
          final response = await Supabase.instance.client
              .from('user_favorites')
              .select('version')
              .limit(1)
              .timeout(const Duration(seconds: 5));

          if (response.isEmpty) {
            throw Exception('Health check response is empty');
          }
          return true;
        },
        config: const RetryConfig(
          maxRetries: 2,
          initialDelay: Duration(milliseconds: 500),
          backoffMultiplier: 1.5,
          maxDelay: Duration(seconds: 2),
          timeout: Duration(seconds: 10),
        ),
        operationName: 'Connection health check',
      );
    } catch (e) {
      LoggerFactory.warning(
          '⚠️ Connection health check failed after retries: $e');
      return false;
    }
  }

  /// Limpia todos los canales
  Future<void> _cleanupChannels() async {
    LoggerFactory.info('🧹 Starting channel cleanup...');

    // Desuscribir canales con timeout individual
    final channelCleanupFutures = _channels.entries.map((entry) async {
      final tableName = entry.key;
      final channel = entry.value;

      try {
        await channel.unsubscribe().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            LoggerFactory.warning(
                '⚠️ Channel unsubscribe timed out for $tableName');
            return 'timeout';
          },
        );
        LoggerFactory.info('✅ Channel unsubscribed: $tableName');
      } catch (e) {
        LoggerFactory.warning(
            '⚠️ Failed to unsubscribe channel $tableName: $e');
      }
    });

    // Esperar a que todos los canales se desuscriban (sin fallar si uno falla)
    await Future.wait(channelCleanupFutures, eagerError: false);
    _channels.clear();

    // Cancelar todos los timers de throttling
    try {
      for (final entry in _throttleTimers.entries) {
        final tableName = entry.key;
        final timer = entry.value;

        if (timer.isActive) {
          timer.cancel();
          LoggerFactory.info('⏹️ Throttle timer cancelled for $tableName');
        }
      }
      _throttleTimers.clear();
    } catch (e) {
      LoggerFactory.warning('⚠️ Error cancelling throttle timers: $e');
      _throttleTimers.clear(); // Forzar limpieza
    }

    // Limpiar eventos batcheados
    _batchedEvents.clear();

    LoggerFactory.info('✅ Channel cleanup completed');
  }

  /// Mapea tipo de evento de Postgres a nuestro enum
  RealtimeEventType _mapEventType(PostgresChangeEvent event) {
    switch (event) {
      case PostgresChangeEvent.insert:
        return RealtimeEventType.insert;
      case PostgresChangeEvent.update:
        return RealtimeEventType.update;
      case PostgresChangeEvent.delete:
        return RealtimeEventType.delete;
      default:
        return RealtimeEventType.update;
    }
  }

  /// Mapea nombre de tabla a tipo de entidad
  String? _mapTableToEntityType(String tableName) {
    switch (tableName) {
      case 'user_favorites':
        return 'favorite';
      case 'user_watchlist':
        return 'watchlist';
      case 'user_watched_movies':
        return 'watched_movie';
      case 'user_custom_lists':
        return 'custom_list';
      default:
        return null;
    }
  }

  /// Pauses all active listeners temporarily
  void pauseListeners() {
    if (!_isListening) return;

    _isListening = false;
    LoggerFactory.info('Realtime listeners paused');

    _emitEvent(
      RealtimeSyncEventType.listenersPaused,
      'Realtime listeners paused',
      metadata: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Resumes paused listeners
  void resumeListeners() {
    if (_isListening || !_isInitialized) return;

    _isListening = true;
    LoggerFactory.info('Realtime listeners resumed');

    _emitEvent(
      RealtimeSyncEventType.listenersResumed,
      'Realtime listeners resumed',
      metadata: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Emite un evento
  void _emitEvent(
    RealtimeSyncEventType type,
    String message, {
    Map<String, dynamic>? metadata,
  }) {
    final event = RealtimeSyncEvent(
      type: type,
      message: message,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    _eventController.add(event);
  }

  /// Obtiene estadísticas del manager
  Map<String, dynamic> getStatistics() {
    return {
      'user_id': userId,
      'is_initialized': _isInitialized,
      'is_listening': _isListening,
      'active_channels': _channels.length,
      'active_subscriptions': _subscriptions.length,
      'batched_events': _batchedEvents.values
          .fold<int>(0, (sum, events) => sum + events.length),
      'active_timers': _throttleTimers.length,
    };
  }

  /// Libera recursos
  Future<void> dispose() async {
    try {
      LoggerFactory.info('🔒 Starting RealtimeSyncManager disposal...');

      // Marcar como no inicializado para prevenir nuevas operaciones
      _isInitialized = false;
      _isListening = false;

      // Detener listeners de forma segura
      await stopListening();

      // Cleanup completo de canales con timeout
      await _cleanupChannels().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          LoggerFactory.warning('⚠️ Channel cleanup timed out');
          return Future.value();
        },
      );

      // Cancelar todas las suscripciones con manejo de errores
      final subscriptionFutures =
          _subscriptions.values.map((subscription) async {
        try {
          await subscription.cancel();
        } catch (e) {
          LoggerFactory.warning('⚠️ Failed to cancel subscription: $e');
        }
      });

      await Future.wait(subscriptionFutures, eagerError: false);
      _subscriptions.clear();

      // Cerrar stream controller de forma segura
      if (!_eventController.isClosed) {
        await _eventController.close();
      }

      LoggerFactory.info('✅ RealtimeSyncManager disposed successfully');
    } catch (e) {
      LoggerFactory.error('❌ Error during RealtimeSyncManager disposal: $e');
      // Asegurar que los recursos se liberen incluso si hay errores
      _subscriptions.clear();
      _channels.clear();
      _throttleTimers.clear();
      _batchedEvents.clear();

      if (!_eventController.isClosed) {
        _eventController.close();
      }
    }
  }
}

/// Evento de sincronización en tiempo real
class RealtimeSyncEvent {
  const RealtimeSyncEvent({
    required this.type,
    required this.message,
    required this.timestamp,
    this.metadata,
  });

  final RealtimeSyncEventType type;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  @override
  String toString() {
    return 'RealtimeSyncEvent(${type.name}: $message)';
  }
}

/// Tipos de eventos de sincronización en tiempo real
enum RealtimeSyncEventType {
  initialized,
  listeningStarted,
  listeningStopped,
  listenersPaused,
  listenersResumed,
  batchProcessed,
  localChangePropagated,
  connectionRestored,
  connectionLost,
  restarted,
  error,
}

/// Evento de Realtime interno
class RealtimeEvent {
  const RealtimeEvent({
    required this.tableName,
    required this.eventType,
    required this.timestamp,
    this.oldRecord,
    this.newRecord,
  });

  final String tableName;
  final RealtimeEventType eventType;
  final Map<String, dynamic>? oldRecord;
  final Map<String, dynamic>? newRecord;
  final DateTime timestamp;
}

/// Tipos de eventos de Realtime
enum RealtimeEventType {
  insert,
  update,
  delete,
}
