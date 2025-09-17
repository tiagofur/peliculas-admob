import 'dart:async';
import 'dart:collection';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../logging/logger_factory.dart';

/// Pool optimizado de canales real-time para mejorar rendimiento
/// y gestión de recursos en sincronización
class RealtimeChannelPool {
  RealtimeChannelPool._internal();
  static final RealtimeChannelPool _instance = RealtimeChannelPool._internal();
  static RealtimeChannelPool get instance => _instance;

  // Configuración del pool
  static const int _maxPoolSize = 10;
  static const int _minPoolSize = 2;
  static const Duration _channelTimeout = Duration(seconds: 30);
  static const Duration _heartbeatInterval = Duration(seconds: 15);
  static const Duration _reconnectDelay = Duration(seconds: 5);

  // Pool de canales disponibles
  final Queue<PooledChannel> _availableChannels = Queue<PooledChannel>();

  // Canales activos por tabla
  final Map<String, PooledChannel> _activeChannels = {};

  // Métricas del pool
  final Map<String, ChannelMetrics> _channelMetrics = {};

  // Configuración dinámica de heartbeat
  final Map<String, Duration> _dynamicHeartbeats = {};

  // Timer para limpieza y mantenimiento
  Timer? _maintenanceTimer;
  Timer? _heartbeatTimer;

  bool _isInitialized = false;

  /// Inicializa el pool de canales
  Future<void> initialize() async {
    if (_isInitialized) return;

    LoggerFactory.info('🏊 Inicializando RealtimeChannelPool...');

    // Crear canales mínimos en el pool
    await _createMinimumChannels();

    // Iniciar timers de mantenimiento
    _startMaintenanceTimer();
    _startHeartbeatTimer();

    _isInitialized = true;
    LoggerFactory.info('✅ RealtimeChannelPool inicializado');
  }

  /// Obtiene un canal optimizado para una tabla específica
  Future<PooledChannel> getChannelForTable(
      String tableName, String userId) async {
    if (!_isInitialized) await initialize();

    // Verificar si ya existe un canal activo para esta tabla
    if (_activeChannels.containsKey(tableName)) {
      final existingChannel = _activeChannels[tableName]!;
      if (existingChannel.isHealthy) {
        LoggerFactory.debug('♻️ Reutilizando canal existente para $tableName');
        return existingChannel;
      } else {
        // Canal no saludable, remover y crear uno nuevo
        await _removeUnhealthyChannel(tableName);
      }
    }

    // Obtener canal del pool o crear uno nuevo
    PooledChannel channel;
    if (_availableChannels.isNotEmpty) {
      channel = _availableChannels.removeFirst();
      await channel.reconfigure(tableName, userId);
      LoggerFactory.debug('🔄 Canal reconfigurado del pool para $tableName');
    } else {
      channel = await _createNewChannel(tableName, userId);
      LoggerFactory.debug('🆕 Nuevo canal creado para $tableName');
    }

    // Registrar canal como activo
    _activeChannels[tableName] = channel;
    _initializeChannelMetrics(tableName);

    return channel;
  }

  /// Libera un canal de vuelta al pool
  Future<void> releaseChannel(String tableName) async {
    final channel = _activeChannels.remove(tableName);
    if (channel == null) return;

    LoggerFactory.debug('🔓 Liberando canal para $tableName');

    // Verificar si el canal está saludable
    if (channel.isHealthy && _availableChannels.length < _maxPoolSize) {
      await channel.reset();
      _availableChannels.add(channel);
      LoggerFactory.debug('♻️ Canal devuelto al pool');
    } else {
      await channel.dispose();
      LoggerFactory.debug('🗑️ Canal desechado (no saludable o pool lleno)');
    }

    _channelMetrics.remove(tableName);
  }

  /// Obtiene métricas del pool
  Map<String, dynamic> getPoolMetrics() {
    return {
      'pool_size': _availableChannels.length,
      'active_channels': _activeChannels.length,
      'max_pool_size': _maxPoolSize,
      'min_pool_size': _minPoolSize,
      'channel_metrics': _channelMetrics.map(
        (table, metrics) => MapEntry(table, metrics.toMap()),
      ),
      'is_initialized': _isInitialized,
    };
  }

  /// Optimiza la configuración de heartbeat basada en la calidad de red
  void optimizeHeartbeat(String tableName, NetworkQuality quality) {
    Duration newHeartbeat;

    switch (quality) {
      case NetworkQuality.excellent:
        newHeartbeat = const Duration(seconds: 30);
        break;
      case NetworkQuality.good:
        newHeartbeat = const Duration(seconds: 20);
        break;
      case NetworkQuality.fair:
        newHeartbeat = const Duration(seconds: 15);
        break;
      case NetworkQuality.poor:
        newHeartbeat = const Duration(seconds: 10);
        break;
    }

    _dynamicHeartbeats[tableName] = newHeartbeat;

    final channel = _activeChannels[tableName];
    if (channel != null) {
      channel.updateHeartbeat(newHeartbeat);
      LoggerFactory.info(
          '💓 Heartbeat optimizado para $tableName: ${newHeartbeat.inSeconds}s (calidad: ${quality.name})');
    }
  }

  // Métodos privados

  Future<void> _createMinimumChannels() async {
    for (int i = 0; i < _minPoolSize; i++) {
      final channel = await _createNewChannel('pool_channel_$i', 'pool_user');
      await channel.reset();
      _availableChannels.add(channel);
    }
    LoggerFactory.info('🏊 Creados $_minPoolSize canales en el pool');
  }

  Future<PooledChannel> _createNewChannel(
      String tableName, String userId) async {
    final channelId =
        'optimized_${tableName}_${DateTime.now().millisecondsSinceEpoch}';
    final supabaseChannel = Supabase.instance.client.channel(channelId);

    final pooledChannel = PooledChannel(
      channel: supabaseChannel,
      tableName: tableName,
      userId: userId,
      heartbeatInterval: _dynamicHeartbeats[tableName] ?? _heartbeatInterval,
    );

    await pooledChannel.initialize();
    return pooledChannel;
  }

  void _initializeChannelMetrics(String tableName) {
    _channelMetrics[tableName] = ChannelMetrics(
      tableName: tableName,
      createdAt: DateTime.now(),
    );
  }

  Future<void> _removeUnhealthyChannel(String tableName) async {
    final channel = _activeChannels.remove(tableName);
    if (channel != null) {
      await channel.dispose();
      LoggerFactory.warning('⚠️ Canal no saludable removido para $tableName');
    }
  }

  void _startMaintenanceTimer() {
    _maintenanceTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _performMaintenance();
    });
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _performHeartbeatCheck();
    });
  }

  void _performMaintenance() {
    LoggerFactory.debug('🔧 Realizando mantenimiento del pool...');

    // Limpiar canales no saludables del pool
    _availableChannels.removeWhere((channel) {
      if (!channel.isHealthy) {
        channel.dispose();
        return true;
      }
      return false;
    });

    // Actualizar métricas
    for (final metrics in _channelMetrics.values) {
      metrics.updateHealth();
    }

    LoggerFactory.debug(
        '🔧 Mantenimiento completado. Pool: ${_availableChannels.length}, Activos: ${_activeChannels.length}');
  }

  void _performHeartbeatCheck() {
    for (final entry in _activeChannels.entries) {
      final tableName = entry.key;
      final channel = entry.value;

      if (!channel.isHealthy) {
        LoggerFactory.warning('💔 Canal no saludable detectado: $tableName');
        _channelMetrics[tableName]?.recordUnhealthyEvent();
      } else {
        _channelMetrics[tableName]?.recordHealthyEvent();
      }
    }
  }

  /// Libera todos los recursos del pool
  Future<void> dispose() async {
    LoggerFactory.info('🔒 Liberando RealtimeChannelPool...');

    _maintenanceTimer?.cancel();
    _heartbeatTimer?.cancel();

    // Liberar canales activos
    for (final channel in _activeChannels.values) {
      await channel.dispose();
    }
    _activeChannels.clear();

    // Liberar canales del pool
    for (final channel in _availableChannels) {
      await channel.dispose();
    }
    _availableChannels.clear();

    _channelMetrics.clear();
    _dynamicHeartbeats.clear();

    _isInitialized = false;
    LoggerFactory.info('✅ RealtimeChannelPool liberado');
  }
}

/// Canal pooled con optimizaciones
class PooledChannel {
  PooledChannel({
    required this.channel,
    required this.tableName,
    required this.userId,
    required this.heartbeatInterval,
  });

  final RealtimeChannel channel;
  String tableName;
  String userId;
  Duration heartbeatInterval;

  DateTime _lastActivity = DateTime.now();
  bool _isSubscribed = false;
  Timer? _heartbeatTimer;

  bool get isHealthy {
    final timeSinceActivity = DateTime.now().difference(_lastActivity);
    return _isSubscribed &&
        timeSinceActivity < RealtimeChannelPool._channelTimeout;
  }

  Future<void> initialize() async {
    await _subscribe();
    _startHeartbeat();
  }

  Future<void> reconfigure(String newTableName, String newUserId) async {
    if (_isSubscribed) {
      await channel.unsubscribe();
    }

    tableName = newTableName;
    userId = newUserId;

    await _subscribe();
    _updateActivity();
  }

  Future<void> reset() async {
    if (_isSubscribed) {
      await channel.unsubscribe();
    }
    _stopHeartbeat();
    _isSubscribed = false;
  }

  void updateHeartbeat(Duration newInterval) {
    heartbeatInterval = newInterval;
    _stopHeartbeat();
    _startHeartbeat();
  }

  void _updateActivity() {
    _lastActivity = DateTime.now();
  }

  Future<void> _subscribe() async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        channel.subscribe();
        _isSubscribed = true;
        _updateActivity();
        LoggerFactory.debug('✅ Canal suscrito para $tableName');
        return;
      } catch (e) {
        retryCount++;
        LoggerFactory.error('❌ Error suscribiendo canal para $tableName (intento $retryCount): $e');
        
        if (retryCount < maxRetries) {
          LoggerFactory.info('🔄 Reintentando suscripción en ${RealtimeChannelPool._reconnectDelay.inSeconds}s...');
          await Future.delayed(RealtimeChannelPool._reconnectDelay);
        } else {
          _isSubscribed = false;
          LoggerFactory.error('💥 Falló suscripción después de $maxRetries intentos para $tableName');
        }
      }
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      if (_isSubscribed) {
        _updateActivity();
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> dispose() async {
    _stopHeartbeat();
    if (_isSubscribed) {
      await channel.unsubscribe();
    }
    _isSubscribed = false;
  }
}

/// Métricas de canal
class ChannelMetrics {
  ChannelMetrics({
    required this.tableName,
    required this.createdAt,
  });

  final String tableName;
  final DateTime createdAt;

  int _healthyEvents = 0;
  int _unhealthyEvents = 0;
  DateTime _lastHealthCheck = DateTime.now();

  void recordHealthyEvent() {
    _healthyEvents++;
    _lastHealthCheck = DateTime.now();
  }

  void recordUnhealthyEvent() {
    _unhealthyEvents++;
    _lastHealthCheck = DateTime.now();
  }

  void updateHealth() {
    _lastHealthCheck = DateTime.now();
  }

  double get healthRatio {
    final total = _healthyEvents + _unhealthyEvents;
    return total > 0 ? _healthyEvents / total : 1.0;
  }

  Map<String, dynamic> toMap() {
    return {
      'table_name': tableName,
      'created_at': createdAt.toIso8601String(),
      'healthy_events': _healthyEvents,
      'unhealthy_events': _unhealthyEvents,
      'health_ratio': healthRatio,
      'last_health_check': _lastHealthCheck.toIso8601String(),
      'uptime_minutes': DateTime.now().difference(createdAt).inMinutes,
    };
  }
}

/// Calidad de red para optimización de heartbeat
enum NetworkQuality {
  excellent,
  good,
  fair,
  poor,
}
