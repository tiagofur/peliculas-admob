import 'dart:async';
import 'dart:collection';
import 'dart:math';


/// Métricas de rendimiento para el sistema de sincronización
class SyncPerformanceMetrics {
  factory SyncPerformanceMetrics() => _instance;
  SyncPerformanceMetrics._internal();

  static final SyncPerformanceMetrics _instance = SyncPerformanceMetrics._internal();
  static SyncPerformanceMetrics get instance => _instance;

  // Contadores de eventos
  int _totalSyncOperations = 0;
  int _successfulSyncs = 0;
  int _failedSyncs = 0;
  int _conflictsDetected = 0;
  int _conflictsResolved = 0;
  int _realtimeEventsReceived = 0;
  int _realtimeEventsProcessed = 0;
  int _throttledEvents = 0;
  int _networkReconnections = 0;

  // Métricas de tiempo
  final Queue<Duration> _syncDurations = Queue<Duration>();
  final Queue<Duration> _conflictResolutionTimes = Queue<Duration>();
  final Queue<Duration> _realtimeProcessingTimes = Queue<Duration>();
  final Map<String, DateTime> _operationStartTimes = <String, DateTime>{};

  // Métricas de red
  final Queue<DateTime> _networkEvents = Queue<DateTime>();
  Duration _totalOfflineTime = Duration.zero;
  DateTime? _lastDisconnectionTime;
  bool _isOnline = true;

  // Métricas por entidad
  final Map<String, EntityMetrics> _entityMetrics = <String, EntityMetrics>{};

  // Configuración
  static const int _maxHistorySize = 1000;
  static const Duration _metricsWindow = Duration(hours: 1);

  // Streams para notificaciones en tiempo real
  final StreamController<MetricsSnapshot> _metricsController = 
      StreamController<MetricsSnapshot>.broadcast();
  
  Stream<MetricsSnapshot> get metricsStream => _metricsController.stream;

  // Timer para limpiar métricas antiguas
  Timer? _cleanupTimer;

  void initialize() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) => _cleanupOldMetrics());
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _metricsController.close();
  }

  // === REGISTRO DE EVENTOS ===

  /// Inicia el seguimiento de una operación de sincronización
  String startSyncOperation(String operationType, [String? entityId]) {
    final operationId = '${operationType}_${DateTime.now().millisecondsSinceEpoch}';
    _operationStartTimes[operationId] = DateTime.now();
    _totalSyncOperations++;
    
    if (entityId != null) {
      _getEntityMetrics(entityId).operationsStarted++;
    }
    
    _notifyMetricsUpdate();
    return operationId;
  }

  /// Finaliza el seguimiento de una operación de sincronización
  void endSyncOperation(String operationId, bool success, [String? entityId]) {
    final startTime = _operationStartTimes.remove(operationId);
    if (startTime == null) return;

    final duration = DateTime.now().difference(startTime);
    _syncDurations.add(duration);
    
    if (_syncDurations.length > _maxHistorySize) {
      _syncDurations.removeFirst();
    }

    if (success) {
      _successfulSyncs++;
      if (entityId != null) {
        _getEntityMetrics(entityId).successfulOperations++;
      }
    } else {
      _failedSyncs++;
      if (entityId != null) {
        _getEntityMetrics(entityId).failedOperations++;
      }
    }

    _notifyMetricsUpdate();
  }

  /// Registra la detección de un conflicto
  String recordConflictDetected(String entityType, String entityId) {
    final conflictId = 'conflict_${DateTime.now().millisecondsSinceEpoch}';
    _conflictsDetected++;
    _operationStartTimes[conflictId] = DateTime.now();
    
    _getEntityMetrics(entityId).conflictsDetected++;
    _notifyMetricsUpdate();
    
    return conflictId;
  }

  /// Registra la resolución de un conflicto
  void recordConflictResolved(String conflictId, bool success, [String? entityId]) {
    final startTime = _operationStartTimes.remove(conflictId);
    if (startTime == null) return;

    final duration = DateTime.now().difference(startTime);
    _conflictResolutionTimes.add(duration);
    
    if (_conflictResolutionTimes.length > _maxHistorySize) {
      _conflictResolutionTimes.removeFirst();
    }

    if (success) {
      _conflictsResolved++;
      if (entityId != null) {
        _getEntityMetrics(entityId).conflictsResolved++;
      }
    }

    _notifyMetricsUpdate();
  }

  /// Registra un evento de tiempo real recibido
  void recordRealtimeEventReceived(String eventType, String table) {
    _realtimeEventsReceived++;
    _getEntityMetrics(table).realtimeEventsReceived++;
    _notifyMetricsUpdate();
  }

  /// Registra un evento de tiempo real procesado
  void recordRealtimeEventProcessed(String eventType, String table, Duration processingTime) {
    _realtimeEventsProcessed++;
    _realtimeProcessingTimes.add(processingTime);
    
    if (_realtimeProcessingTimes.length > _maxHistorySize) {
      _realtimeProcessingTimes.removeFirst();
    }

    final entityMetrics = _getEntityMetrics(table);
    entityMetrics.realtimeEventsProcessed++;
    entityMetrics.totalProcessingTime += processingTime;
    
    _notifyMetricsUpdate();
  }

  /// Registra un evento throttled
  void recordThrottledEvent(String eventType, String table) {
    _throttledEvents++;
    _getEntityMetrics(table).throttledEvents++;
    _notifyMetricsUpdate();
  }

  /// Registra un evento de red
  void recordNetworkEvent(bool isOnline) {
    final now = DateTime.now();
    _networkEvents.add(now);
    
    if (_networkEvents.length > _maxHistorySize) {
      _networkEvents.removeFirst();
    }

    if (_isOnline != isOnline) {
      if (isOnline) {
        // Reconexión
        _networkReconnections++;
        if (_lastDisconnectionTime != null) {
          _totalOfflineTime += now.difference(_lastDisconnectionTime!);
          _lastDisconnectionTime = null;
        }
      } else {
        // Desconexión
        _lastDisconnectionTime = now;
      }
      _isOnline = isOnline;
    }

    _notifyMetricsUpdate();
  }

  // === CÁLCULO DE MÉTRICAS ===

  /// Obtiene un snapshot completo de las métricas actuales
  MetricsSnapshot getSnapshot() {
    return MetricsSnapshot(
      timestamp: DateTime.now(),
      totalSyncOperations: _totalSyncOperations,
      successfulSyncs: _successfulSyncs,
      failedSyncs: _failedSyncs,
      successRate: _totalSyncOperations > 0 ? _successfulSyncs / _totalSyncOperations : 0.0,
      conflictsDetected: _conflictsDetected,
      conflictsResolved: _conflictsResolved,
      conflictResolutionRate: _conflictsDetected > 0 ? _conflictsResolved / _conflictsDetected : 0.0,
      realtimeEventsReceived: _realtimeEventsReceived,
      realtimeEventsProcessed: _realtimeEventsProcessed,
      realtimeProcessingRate: _realtimeEventsReceived > 0 ? _realtimeEventsProcessed / _realtimeEventsReceived : 0.0,
      throttledEvents: _throttledEvents,
      networkReconnections: _networkReconnections,
      totalOfflineTime: _getTotalOfflineTime(),
      isOnline: _isOnline,
      averageSyncDuration: _calculateAverageDuration(_syncDurations),
      averageConflictResolutionTime: _calculateAverageDuration(_conflictResolutionTimes),
      averageRealtimeProcessingTime: _calculateAverageDuration(_realtimeProcessingTimes),
      syncDurationPercentiles: _calculatePercentiles(_syncDurations),
      entityMetrics: Map.from(_entityMetrics),
      networkStability: _calculateNetworkStability(),
      performanceScore: _calculatePerformanceScore(),
    );
  }

  /// Calcula la duración promedio de una lista de duraciones
  Duration _calculateAverageDuration(Queue<Duration> durations) {
    if (durations.isEmpty) return Duration.zero;
    
    final totalMs = durations.fold<int>(0, (sum, duration) => sum + duration.inMilliseconds);
    return Duration(milliseconds: totalMs ~/ durations.length);
  }

  /// Calcula percentiles para una lista de duraciones
  Map<int, Duration> _calculatePercentiles(Queue<Duration> durations) {
    if (durations.isEmpty) return {};
    
    final sortedDurations = durations.toList()..sort((a, b) => a.compareTo(b));
    final percentiles = <int, Duration>{};
    
    for (final p in [50, 75, 90, 95, 99]) {
      final index = ((p / 100) * (sortedDurations.length - 1)).round();
      percentiles[p] = sortedDurations[index];
    }
    
    return percentiles;
  }

  /// Calcula la estabilidad de la red
  double _calculateNetworkStability() {
    if (_networkEvents.isEmpty) return 1.0;
    
    final recentEvents = _networkEvents.where(
      (event) => DateTime.now().difference(event) <= _metricsWindow
    ).length;
    
    // Menos eventos de red = más estabilidad
    return max(0.0, 1.0 - (recentEvents / 100.0));
  }

  /// Calcula un score general de rendimiento
  double _calculatePerformanceScore() {
    double score = 0.0;
    int factors = 0;

    // Factor de éxito de sincronización (40%)
    if (_totalSyncOperations > 0) {
      score += (_successfulSyncs / _totalSyncOperations) * 0.4;
      factors++;
    }

    // Factor de resolución de conflictos (20%)
    if (_conflictsDetected > 0) {
      score += (_conflictsResolved / _conflictsDetected) * 0.2;
      factors++;
    }

    // Factor de procesamiento en tiempo real (20%)
    if (_realtimeEventsReceived > 0) {
      score += (_realtimeEventsProcessed / _realtimeEventsReceived) * 0.2;
      factors++;
    }

    // Factor de estabilidad de red (20%)
    score += _calculateNetworkStability() * 0.2;
    factors++;

    return factors > 0 ? score : 0.0;
  }

  /// Obtiene el tiempo total offline incluyendo el tiempo actual si está offline
  Duration _getTotalOfflineTime() {
    var total = _totalOfflineTime;
    if (!_isOnline && _lastDisconnectionTime != null) {
      total += DateTime.now().difference(_lastDisconnectionTime!);
    }
    return total;
  }

  /// Obtiene o crea métricas para una entidad específica
  EntityMetrics _getEntityMetrics(String entityId) {
    return _entityMetrics.putIfAbsent(entityId, () => EntityMetrics(entityId));
  }

  /// Limpia métricas antiguas para evitar uso excesivo de memoria
  void _cleanupOldMetrics() {
    final cutoff = DateTime.now().subtract(_metricsWindow);
    
    // Limpiar eventos de red antiguos
    _networkEvents.removeWhere((event) => event.isBefore(cutoff));
    
    // Limpiar operaciones que no han terminado (posibles memory leaks)
    _operationStartTimes.removeWhere((key, startTime) => startTime.isBefore(cutoff));
  }

  /// Notifica a los listeners sobre actualizaciones de métricas
  void _notifyMetricsUpdate() {
    if (!_metricsController.isClosed) {
      _metricsController.add(getSnapshot());
    }
  }

  /// Resetea todas las métricas
  void reset() {
    _totalSyncOperations = 0;
    _successfulSyncs = 0;
    _failedSyncs = 0;
    _conflictsDetected = 0;
    _conflictsResolved = 0;
    _realtimeEventsReceived = 0;
    _realtimeEventsProcessed = 0;
    _throttledEvents = 0;
    _networkReconnections = 0;
    
    _syncDurations.clear();
    _conflictResolutionTimes.clear();
    _realtimeProcessingTimes.clear();
    _operationStartTimes.clear();
    _networkEvents.clear();
    _entityMetrics.clear();
    
    _totalOfflineTime = Duration.zero;
    _lastDisconnectionTime = null;
    _isOnline = true;
    
    _notifyMetricsUpdate();
  }

  // === MÉTODOS DE UTILIDAD ===

  /// Exporta métricas en formato JSON para análisis
  Map<String, dynamic> exportToJson() {
    final snapshot = getSnapshot();
    return snapshot.toJson();
  }

  /// Genera un reporte de rendimiento en texto
  String generatePerformanceReport() {
    final snapshot = getSnapshot();
    final buffer = StringBuffer();
    
    buffer.writeln('=== REPORTE DE RENDIMIENTO DE SINCRONIZACIÓN ===');
    buffer.writeln('Timestamp: ${snapshot.timestamp}');
    buffer.writeln();
    
    buffer.writeln('OPERACIONES DE SINCRONIZACIÓN:');
    buffer.writeln('  Total: ${snapshot.totalSyncOperations}');
    buffer.writeln('  Exitosas: ${snapshot.successfulSyncs}');
    buffer.writeln('  Fallidas: ${snapshot.failedSyncs}');
    buffer.writeln('  Tasa de éxito: ${(snapshot.successRate * 100).toStringAsFixed(1)}%');
    buffer.writeln();
    
    buffer.writeln('RESOLUCIÓN DE CONFLICTOS:');
    buffer.writeln('  Detectados: ${snapshot.conflictsDetected}');
    buffer.writeln('  Resueltos: ${snapshot.conflictsResolved}');
    buffer.writeln('  Tasa de resolución: ${(snapshot.conflictResolutionRate * 100).toStringAsFixed(1)}%');
    buffer.writeln();
    
    buffer.writeln('EVENTOS EN TIEMPO REAL:');
    buffer.writeln('  Recibidos: ${snapshot.realtimeEventsReceived}');
    buffer.writeln('  Procesados: ${snapshot.realtimeEventsProcessed}');
    buffer.writeln('  Throttled: ${snapshot.throttledEvents}');
    buffer.writeln('  Tasa de procesamiento: ${(snapshot.realtimeProcessingRate * 100).toStringAsFixed(1)}%');
    buffer.writeln();
    
    buffer.writeln('RED:');
    buffer.writeln('  Estado: ${snapshot.isOnline ? "Online" : "Offline"}');
    buffer.writeln('  Reconexiones: ${snapshot.networkReconnections}');
    buffer.writeln('  Tiempo offline total: ${snapshot.totalOfflineTime.inMinutes} minutos');
    buffer.writeln('  Estabilidad: ${(snapshot.networkStability * 100).toStringAsFixed(1)}%');
    buffer.writeln();
    
    buffer.writeln('RENDIMIENTO:');
    buffer.writeln('  Score general: ${(snapshot.performanceScore * 100).toStringAsFixed(1)}%');
    buffer.writeln('  Duración promedio sync: ${snapshot.averageSyncDuration.inMilliseconds}ms');
    buffer.writeln('  Tiempo promedio resolución conflictos: ${snapshot.averageConflictResolutionTime.inMilliseconds}ms');
    buffer.writeln('  Tiempo promedio procesamiento realtime: ${snapshot.averageRealtimeProcessingTime.inMilliseconds}ms');
    
    return buffer.toString();
  }
}

/// Métricas específicas por entidad
class EntityMetrics {
  EntityMetrics(this.entityId);

  final String entityId;
  int operationsStarted = 0;
  int successfulOperations = 0;
  int failedOperations = 0;
  int conflictsDetected = 0;
  int conflictsResolved = 0;
  int realtimeEventsReceived = 0;
  int realtimeEventsProcessed = 0;
  int throttledEvents = 0;
  Duration totalProcessingTime = Duration.zero;

  double get successRate => operationsStarted > 0 ? successfulOperations / operationsStarted : 0.0;
  double get conflictResolutionRate => conflictsDetected > 0 ? conflictsResolved / conflictsDetected : 0.0;
  double get realtimeProcessingRate => realtimeEventsReceived > 0 ? realtimeEventsProcessed / realtimeEventsReceived : 0.0;
  Duration get averageProcessingTime => realtimeEventsProcessed > 0 
      ? Duration(milliseconds: totalProcessingTime.inMilliseconds ~/ realtimeEventsProcessed)
      : Duration.zero;

  Map<String, dynamic> toJson() {
    return {
      'entityId': entityId,
      'operationsStarted': operationsStarted,
      'successfulOperations': successfulOperations,
      'failedOperations': failedOperations,
      'successRate': successRate,
      'conflictsDetected': conflictsDetected,
      'conflictsResolved': conflictsResolved,
      'conflictResolutionRate': conflictResolutionRate,
      'realtimeEventsReceived': realtimeEventsReceived,
      'realtimeEventsProcessed': realtimeEventsProcessed,
      'realtimeProcessingRate': realtimeProcessingRate,
      'throttledEvents': throttledEvents,
      'totalProcessingTimeMs': totalProcessingTime.inMilliseconds,
      'averageProcessingTimeMs': averageProcessingTime.inMilliseconds,
    };
  }
}

/// Snapshot de métricas en un momento específico
class MetricsSnapshot {
  const MetricsSnapshot({
    required this.timestamp,
    required this.totalSyncOperations,
    required this.successfulSyncs,
    required this.failedSyncs,
    required this.successRate,
    required this.conflictsDetected,
    required this.conflictsResolved,
    required this.conflictResolutionRate,
    required this.realtimeEventsReceived,
    required this.realtimeEventsProcessed,
    required this.realtimeProcessingRate,
    required this.throttledEvents,
    required this.networkReconnections,
    required this.totalOfflineTime,
    required this.isOnline,
    required this.averageSyncDuration,
    required this.averageConflictResolutionTime,
    required this.averageRealtimeProcessingTime,
    required this.syncDurationPercentiles,
    required this.entityMetrics,
    required this.networkStability,
    required this.performanceScore,
  });

  final DateTime timestamp;
  final int totalSyncOperations;
  final int successfulSyncs;
  final int failedSyncs;
  final double successRate;
  final int conflictsDetected;
  final int conflictsResolved;
  final double conflictResolutionRate;
  final int realtimeEventsReceived;
  final int realtimeEventsProcessed;
  final double realtimeProcessingRate;
  final int throttledEvents;
  final int networkReconnections;
  final Duration totalOfflineTime;
  final bool isOnline;
  final Duration averageSyncDuration;
  final Duration averageConflictResolutionTime;
  final Duration averageRealtimeProcessingTime;
  final Map<int, Duration> syncDurationPercentiles;
  final Map<String, EntityMetrics> entityMetrics;
  final double networkStability;
  final double performanceScore;

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'totalSyncOperations': totalSyncOperations,
      'successfulSyncs': successfulSyncs,
      'failedSyncs': failedSyncs,
      'successRate': successRate,
      'conflictsDetected': conflictsDetected,
      'conflictsResolved': conflictsResolved,
      'conflictResolutionRate': conflictResolutionRate,
      'realtimeEventsReceived': realtimeEventsReceived,
      'realtimeEventsProcessed': realtimeEventsProcessed,
      'realtimeProcessingRate': realtimeProcessingRate,
      'throttledEvents': throttledEvents,
      'networkReconnections': networkReconnections,
      'totalOfflineTimeMs': totalOfflineTime.inMilliseconds,
      'isOnline': isOnline,
      'averageSyncDurationMs': averageSyncDuration.inMilliseconds,
      'averageConflictResolutionTimeMs': averageConflictResolutionTime.inMilliseconds,
      'averageRealtimeProcessingTimeMs': averageRealtimeProcessingTime.inMilliseconds,
      'syncDurationPercentiles': syncDurationPercentiles.map(
        (key, value) => MapEntry(key.toString(), value.inMilliseconds)
      ),
      'entityMetrics': entityMetrics.map(
        (key, value) => MapEntry(key, value.toJson())
      ),
      'networkStability': networkStability,
      'performanceScore': performanceScore,
    };
  }
}