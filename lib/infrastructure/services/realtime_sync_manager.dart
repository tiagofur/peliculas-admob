import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logging/logger_factory.dart';
import '../../core/sync/sync_operation.dart';
import '../../core/sync/sync_coordinator.dart';
import 'connectivity_manager.dart';

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

  // Estado interno
  bool _isInitialized = false;
  bool _isListening = false;
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, StreamSubscription> _subscriptions = {};
  
  // Throttling y batching
  final Map<String, Timer> _throttleTimers = {};
  final Map<String, List<RealtimeEvent>> _batchedEvents = {};
  static const Duration _throttleDelay = Duration(milliseconds: 500);
  static const int _maxBatchSize = 10;
  
  // Eventos
  final StreamController<RealtimeSyncEvent> _eventController = 
      StreamController<RealtimeSyncEvent>.broadcast();
  
  /// Stream de eventos de sincronización en tiempo real
  Stream<RealtimeSyncEvent> get events => _eventController.stream;
  
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
      _emitEvent(RealtimeSyncEventType.initialized, 'RealtimeSyncManager initialized');
      
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

    try {
      await startListeners();
      LoggerFactory.info('🚀 RealtimeSyncManager initialized successfully');
    } catch (e) {
      LoggerFactory.error('❌ Failed to initialize RealtimeSyncManager: $e');
      rethrow;
    }
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
        LoggerFactory.info('⏸️ Skipping realtime listening - not online: $connectionStatus');
        return;
      }

      await _setupRealtimeChannels();
      _isListening = true;
      
      _emitEvent(RealtimeSyncEventType.listeningStarted, 'Started realtime listening');
      LoggerFactory.info('🎧 Started realtime listening');
    } catch (e) {
      LoggerFactory.error('❌ Failed to start realtime listening: $e');
      _emitEvent(RealtimeSyncEventType.error, 'Failed to start listening: $e');
    }
  }

  /// Detiene la escucha de cambios en tiempo real
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _cleanupChannels();
      _isListening = false;
      
      _emitEvent(RealtimeSyncEventType.listeningStopped, 'Stopped realtime listening');
      LoggerFactory.info('🔇 Stopped realtime listening');
    } catch (e) {
      LoggerFactory.error('❌ Failed to stop realtime listening: $e');
    }
  }

  /// Configura los canales de Supabase Realtime
  Future<void> _setupRealtimeChannels() async {
    final tables = ['user_favorites', 'user_watchlist', 'user_watched_movies', 'user_custom_lists'];
    
    for (final table in tables) {
      await _setupTableChannel(table);
    }
  }

  /// Configura un canal para una tabla específica
  Future<void> _setupTableChannel(String tableName) async {
    try {
      // Crear canal con filtro por usuario
      final channel = _supabase.channel('realtime:$tableName:$userId')
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
    } catch (e) {
      LoggerFactory.error('❌ Failed to setup channel for $tableName: $e');
    }
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
      
      LoggerFactory.info('📨 Received realtime event: ${event.eventType} on $tableName');
    } catch (e) {
      LoggerFactory.error('❌ Failed to handle realtime event: $e');
    }
  }

  /// Aplica throttling y batching a los eventos
  void _throttleAndBatchEvent(String tableName, RealtimeEvent event) {
    // Agregar evento al batch
    _batchedEvents.putIfAbsent(tableName, () => []).add(event);
    
    // Cancelar timer anterior si existe
    _throttleTimers[tableName]?.cancel();
    
    // Crear nuevo timer para procesar batch
    _throttleTimers[tableName] = Timer(_throttleDelay, () {
      _processBatchedEvents(tableName);
    });
    
    // Procesar inmediatamente si el batch está lleno
    if (_batchedEvents[tableName]!.length >= _maxBatchSize) {
      _throttleTimers[tableName]?.cancel();
      _processBatchedEvents(tableName);
    }
  }

  /// Procesa eventos en batch
  Future<void> _processBatchedEvents(String tableName) async {
    final events = _batchedEvents[tableName];
    if (events == null || events.isEmpty) return;
    
    try {
      LoggerFactory.info('⚡ Processing ${events.length} batched events for $tableName');
      
      // Agrupar eventos por tipo para optimizar
      final groupedEvents = <RealtimeEventType, List<RealtimeEvent>>{};
      for (final event in events) {
        groupedEvents.putIfAbsent(event.eventType, () => []).add(event);
      }
      
      // Procesar cada grupo
      for (final entry in groupedEvents.entries) {
        await _processEventGroup(tableName, entry.key, entry.value);
      }
      
      _emitEvent(
        RealtimeSyncEventType.batchProcessed,
        'Processed ${events.length} events for $tableName',
        metadata: {'table': tableName, 'event_count': events.length},
      );
      
    } catch (e) {
      LoggerFactory.error('❌ Failed to process batched events for $tableName: $e');
      _emitEvent(RealtimeSyncEventType.error, 'Failed to process batch: $e');
    } finally {
      // Limpiar batch
      _batchedEvents[tableName]?.clear();
    }
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
      LoggerFactory.error('❌ Failed to process $eventType events for $tableName: $e');
    }
  }

  /// Maneja eventos de inserción
  Future<void> _handleInsertEvents(String tableName, List<RealtimeEvent> events) async {
    for (final event in events) {
      if (event.newRecord != null) {
        await _syncEntityFromRemote(tableName, event.newRecord!);
      }
    }
  }

  /// Maneja eventos de actualización
  Future<void> _handleUpdateEvents(String tableName, List<RealtimeEvent> events) async {
    for (final event in events) {
      if (event.newRecord != null) {
        await _syncEntityFromRemote(tableName, event.newRecord!);
      }
    }
  }

  /// Maneja eventos de eliminación
  Future<void> _handleDeleteEvents(String tableName, List<RealtimeEvent> events) async {
    for (final event in events) {
      if (event.oldRecord != null) {
        await _handleEntityDeletion(tableName, event.oldRecord!);
      }
    }
  }

  /// Sincroniza una entidad desde el servidor
  Future<void> _syncEntityFromRemote(String tableName, Map<String, dynamic> record) async {
    try {
      final entityType = _mapTableToEntityType(tableName);
      if (entityType == null) return;
      
      // Delegar al SyncCoordinator para manejar la sincronización
      await syncCoordinator.queueSyncOperation(
        entityType: entityType,
        entityId: record['id']?.toString() ?? '',
        type: SyncOperationType.update,
        data: record,
        priority: 1, // Alta prioridad para cambios en tiempo real
      );
      
      LoggerFactory.info('🔄 Queued sync for $entityType from realtime');
    } catch (e) {
      LoggerFactory.error('❌ Failed to sync entity from remote: $e');
    }
  }

  /// Maneja eliminación de entidad
  Future<void> _handleEntityDeletion(String tableName, Map<String, dynamic> record) async {
    try {
      final entityType = _mapTableToEntityType(tableName);
      if (entityType == null) return;
      
      await syncCoordinator.queueSyncOperation(
        entityType: entityType,
        entityId: record['id']?.toString() ?? '',
        type: SyncOperationType.delete,
        data: record,
        priority: 1,
      );
      
      LoggerFactory.info('🗑️ Queued deletion for $entityType from realtime');
    } catch (e) {
      LoggerFactory.error('❌ Failed to handle entity deletion: $e');
    }
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
      
      LoggerFactory.info('📤 Propagated local change: $operationType $entityType($entityId)');
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
    LoggerFactory.info('🔄 Connection restored, attempting to restart realtime sync');
    
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
      // Verificar si Supabase está respondiendo
      final response = await Supabase.instance.client
          .from('user_favorites')
          .select('version')
          .limit(1)
          .timeout(const Duration(seconds: 5));
      
      return response.isNotEmpty;
    } catch (e) {
      LoggerFactory.warning('⚠️ Connection health check failed: $e');
      return false;
    }
  }

  /// Limpia todos los canales
  Future<void> _cleanupChannels() async {
    for (final channel in _channels.values) {
      try {
        await channel.unsubscribe();
      } catch (e) {
        LoggerFactory.warning('⚠️ Failed to unsubscribe channel: $e');
      }
    }
    _channels.clear();
    
    // Cancelar timers
    for (final timer in _throttleTimers.values) {
      timer.cancel();
    }
    _throttleTimers.clear();
    _batchedEvents.clear();
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
      'batched_events': _batchedEvents.values.fold<int>(0, (sum, events) => sum + events.length),
      'active_timers': _throttleTimers.length,
    };
  }

  /// Libera recursos
  Future<void> dispose() async {
    await stopListening();
    
    // Cancelar suscripciones
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    
    // Cerrar stream
    await _eventController.close();
    
    LoggerFactory.info('🔒 RealtimeSyncManager disposed');
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