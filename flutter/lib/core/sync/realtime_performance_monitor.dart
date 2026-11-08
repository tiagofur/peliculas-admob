import 'dart:async';
import 'dart:collection';
import 'dart:math';
import '../logging/logger_factory.dart';

/// Monitor de rendimiento para el sistema de sincronización real-time
/// Proporciona métricas detalladas, alertas y dashboard de estado
class RealtimePerformanceMonitor {
  RealtimePerformanceMonitor._internal();

  static final RealtimePerformanceMonitor _instance =
      RealtimePerformanceMonitor._internal();
  static RealtimePerformanceMonitor get instance => _instance;

  // Métricas de rendimiento
  final Map<String, TableMetrics> _tableMetrics = {};
  final Map<String, ConnectionMetrics> _connectionMetrics = {};
  final Queue<PerformanceSnapshot> _performanceHistory =
      Queue<PerformanceSnapshot>();

  // Configuración de alertas
  final Map<AlertType, AlertConfig> _alertConfigs = {
    AlertType.highLatency: AlertConfig(threshold: 2000, enabled: true), // 2s
    AlertType.connectionFailure:
        AlertConfig(threshold: 3, enabled: true), // 3 fallos
    AlertType.lowThroughput:
        AlertConfig(threshold: 0.5, enabled: true), // 50% throughput
    AlertType.memoryUsage: AlertConfig(threshold: 100, enabled: true), // 100MB
    AlertType.batchOverflow:
        AlertConfig(threshold: 50, enabled: true), // 50 eventos
  };

  // Callbacks de alertas
  final Map<AlertType, List<AlertCallback>> _alertCallbacks = {};

  // Timers
  Timer? _metricsTimer;
  Timer? _alertTimer;
  Timer? _cleanupTimer;

  bool _isMonitoring = false;

  /// Inicia el monitoreo de rendimiento
  void startMonitoring() {
    if (_isMonitoring) return;

    LoggerFactory.info('📊 Iniciando RealtimePerformanceMonitor...');

    _startMetricsCollection();
    _startAlertSystem();
    _startCleanupTimer();

    _isMonitoring = true;
    LoggerFactory.info('✅ Monitor de rendimiento iniciado');
  }

  /// Detiene el monitoreo
  void stopMonitoring() {
    if (!_isMonitoring) return;

    _metricsTimer?.cancel();
    _alertTimer?.cancel();
    _cleanupTimer?.cancel();

    _isMonitoring = false;
    LoggerFactory.info('🛑 Monitor de rendimiento detenido');
  }

  /// Registra métricas de una tabla específica
  void recordTableMetrics(
    String tableName, {
    int? eventsProcessed,
    int? batchSize,
    Duration? processingTime,
    int? errorsCount,
    double? throughput,
  }) {
    final metrics = _tableMetrics.putIfAbsent(
      tableName,
      () => TableMetrics(tableName: tableName),
    );

    if (eventsProcessed != null) {
      metrics.recordEventsProcessed(eventsProcessed);
    }

    if (batchSize != null) {
      metrics.recordBatchSize(batchSize);
    }

    if (processingTime != null) {
      metrics.recordProcessingTime(processingTime);
    }

    if (errorsCount != null) {
      metrics.recordErrors(errorsCount);
    }

    if (throughput != null) {
      metrics.recordThroughput(throughput);
    }

    _checkTableAlerts(tableName, metrics);
  }

  /// Registra métricas de conexión
  void recordConnectionMetrics(
    String connectionId, {
    bool? isConnected,
    Duration? latency,
    int? reconnectAttempts,
    DateTime? lastActivity,
  }) {
    final metrics = _connectionMetrics.putIfAbsent(
      connectionId,
      () => ConnectionMetrics(connectionId: connectionId),
    );

    if (isConnected != null) {
      metrics.recordConnectionStatus(isConnected);
    }

    if (latency != null) {
      metrics.recordLatency(latency);
    }

    if (reconnectAttempts != null) {
      metrics.recordReconnectAttempts(reconnectAttempts);
    }

    if (lastActivity != null) {
      metrics.recordActivity(lastActivity);
    }

    _checkConnectionAlerts(connectionId, metrics);
  }

  /// Registra el tamaño de batch para una tabla
  void recordBatchSize(String tableName, int size) {
    recordTableMetrics(tableName, batchSize: size);
  }

  /// Registra la eficiencia del throttling
  void recordThrottlingEfficiency(String tableName, double efficiency) {
    recordTableMetrics(tableName, throughput: efficiency);
  }

  /// Obtiene el dashboard completo de métricas
  Map<String, dynamic> getDashboard() {
    final now = DateTime.now();

    return {
      'timestamp': now.toIso8601String(),
      'monitoring_status': _isMonitoring,
      'system_overview': _getSystemOverview(),
      'table_metrics': _getTableMetricsSummary(),
      'connection_metrics': _getConnectionMetricsSummary(),
      'performance_trends': _getPerformanceTrends(),
      'active_alerts': _getActiveAlerts(),
      'recommendations': _getRecommendations(),
    };
  }

  /// Obtiene métricas específicas de una tabla
  Map<String, dynamic>? getTableMetrics(String tableName) {
    final metrics = _tableMetrics[tableName];
    return metrics?.toMap();
  }

  /// Registra callback para alertas
  void registerAlertCallback(AlertType type, AlertCallback callback) {
    _alertCallbacks.putIfAbsent(type, () => []).add(callback);
  }

  /// Configura umbral de alerta
  void configureAlert(AlertType type, {double? threshold, bool? enabled}) {
    final config = _alertConfigs[type];
    if (config != null) {
      if (threshold != null) config.threshold = threshold;
      if (enabled != null) config.enabled = enabled;

      LoggerFactory.info(
          '⚙️ Alerta ${type.name} configurada: umbral=${config.threshold}, habilitada=${config.enabled}');
    }
  }

  // Métodos privados

  void _startMetricsCollection() {
    _metricsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _collectPerformanceSnapshot();
    });
  }

  void _startAlertSystem() {
    _alertTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkAllAlerts();
    });
  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _cleanupOldData();
    });
  }

  void _collectPerformanceSnapshot() {
    final snapshot = PerformanceSnapshot(
      timestamp: DateTime.now(),
      tableCount: _tableMetrics.length,
      connectionCount: _connectionMetrics.length,
      totalEventsProcessed: _getTotalEventsProcessed(),
      averageLatency: _getAverageLatency(),
      errorRate: _getErrorRate(),
      memoryUsage: _estimateMemoryUsage(),
    );

    _performanceHistory.add(snapshot);

    // Mantener solo las últimas 24 horas de snapshots
    while (_performanceHistory.length > 2880) {
      // 24h * 60min / 0.5min
      _performanceHistory.removeFirst();
    }
  }

  void _checkAllAlerts() {
    for (final entry in _tableMetrics.entries) {
      _checkTableAlerts(entry.key, entry.value);
    }

    for (final entry in _connectionMetrics.entries) {
      _checkConnectionAlerts(entry.key, entry.value);
    }

    _checkSystemAlerts();
  }

  void _checkTableAlerts(String tableName, TableMetrics metrics) {
    // Alerta de baja throughput
    if (_alertConfigs[AlertType.lowThroughput]!.enabled) {
      final avgThroughput = metrics.getAverageThroughput();
      if (avgThroughput < _alertConfigs[AlertType.lowThroughput]!.threshold) {
        _triggerAlert(AlertType.lowThroughput,
            'Baja throughput en $tableName: ${avgThroughput.toStringAsFixed(2)}');
      }
    }

    // Alerta de batch overflow
    if (_alertConfigs[AlertType.batchOverflow]!.enabled) {
      final maxBatchSize = metrics.getMaxBatchSize();
      if (maxBatchSize > _alertConfigs[AlertType.batchOverflow]!.threshold) {
        _triggerAlert(AlertType.batchOverflow,
            'Batch overflow en $tableName: $maxBatchSize eventos');
      }
    }
  }

  void _checkConnectionAlerts(String connectionId, ConnectionMetrics metrics) {
    // Alerta de alta latencia
    if (_alertConfigs[AlertType.highLatency]!.enabled) {
      final avgLatency = metrics.getAverageLatency();
      if (avgLatency.inMilliseconds >
          _alertConfigs[AlertType.highLatency]!.threshold) {
        _triggerAlert(AlertType.highLatency,
            'Alta latencia en $connectionId: ${avgLatency.inMilliseconds}ms');
      }
    }

    // Alerta de fallos de conexión
    if (_alertConfigs[AlertType.connectionFailure]!.enabled) {
      final reconnectAttempts = metrics.getReconnectAttempts();
      if (reconnectAttempts >
          _alertConfigs[AlertType.connectionFailure]!.threshold) {
        _triggerAlert(AlertType.connectionFailure,
            'Múltiples fallos de conexión en $connectionId: $reconnectAttempts intentos');
      }
    }
  }

  void _checkSystemAlerts() {
    // Alerta de uso de memoria
    if (_alertConfigs[AlertType.memoryUsage]!.enabled) {
      final memoryUsage = _estimateMemoryUsage();
      if (memoryUsage > _alertConfigs[AlertType.memoryUsage]!.threshold) {
        _triggerAlert(AlertType.memoryUsage,
            'Alto uso de memoria: ${memoryUsage.toStringAsFixed(1)}MB');
      }
    }
  }

  void _triggerAlert(AlertType type, String message) {
    final alert = Alert(
      type: type,
      message: message,
      timestamp: DateTime.now(),
      severity: _getAlertSeverity(type),
    );

    LoggerFactory.warning('🚨 ALERTA ${type.name}: $message');

    // Ejecutar callbacks registrados
    final callbacks = _alertCallbacks[type] ?? [];
    for (final callback in callbacks) {
      try {
        callback(alert);
      } catch (e) {
        LoggerFactory.error('Error ejecutando callback de alerta: $e');
      }
    }
  }

  AlertSeverity _getAlertSeverity(AlertType type) {
    switch (type) {
      case AlertType.connectionFailure:
      case AlertType.memoryUsage:
        return AlertSeverity.critical;
      case AlertType.highLatency:
      case AlertType.batchOverflow:
        return AlertSeverity.warning;
      case AlertType.lowThroughput:
        return AlertSeverity.info;
    }
  }

  Map<String, dynamic> _getSystemOverview() {
    return {
      'total_tables': _tableMetrics.length,
      'total_connections': _connectionMetrics.length,
      'total_events_processed': _getTotalEventsProcessed(),
      'average_latency_ms': _getAverageLatency().inMilliseconds,
      'error_rate': _getErrorRate(),
      'memory_usage_mb': _estimateMemoryUsage(),
      'uptime_minutes': _isMonitoring
          ? DateTime.now().difference(DateTime.now()).inMinutes
          : 0,
    };
  }

  Map<String, dynamic> _getTableMetricsSummary() {
    return _tableMetrics.map((table, metrics) => MapEntry(table, {
          'events_processed': metrics.getTotalEventsProcessed(),
          'average_batch_size': metrics.getAverageBatchSize(),
          'average_processing_time_ms':
              metrics.getAverageProcessingTime().inMilliseconds,
          'error_count': metrics.getTotalErrors(),
          'throughput': metrics.getAverageThroughput(),
        }));
  }

  Map<String, dynamic> _getConnectionMetricsSummary() {
    return _connectionMetrics.map((conn, metrics) => MapEntry(conn, {
          'is_connected': metrics.isConnected(),
          'average_latency_ms': metrics.getAverageLatency().inMilliseconds,
          'reconnect_attempts': metrics.getReconnectAttempts(),
          'last_activity': metrics.getLastActivity()?.toIso8601String(),
        }));
  }

  List<Map<String, dynamic>> _getPerformanceTrends() {
    return _performanceHistory.map((snapshot) => snapshot.toMap()).toList();
  }

  List<Map<String, dynamic>> _getActiveAlerts() {
    // En una implementación real, mantendríamos un registro de alertas activas
    return [];
  }

  List<String> _getRecommendations() {
    final recommendations = <String>[];

    // Analizar métricas y generar recomendaciones
    final avgLatency = _getAverageLatency();
    if (avgLatency.inMilliseconds > 1000) {
      recommendations.add(
          'Considerar optimizar la configuración de heartbeat para reducir latencia');
    }

    final errorRate = _getErrorRate();
    if (errorRate > 0.05) {
      recommendations
          .add('Alta tasa de errores detectada, revisar configuración de red');
    }

    final memoryUsage = _estimateMemoryUsage();
    if (memoryUsage > 50) {
      recommendations
          .add('Alto uso de memoria, considerar optimizar el tamaño de batch');
    }

    return recommendations;
  }

  int _getTotalEventsProcessed() {
    return _tableMetrics.values
        .map((m) => m.getTotalEventsProcessed())
        .fold(0, (a, b) => a + b);
  }

  Duration _getAverageLatency() {
    if (_connectionMetrics.isEmpty) return Duration.zero;

    final totalLatency = _connectionMetrics.values
        .map((m) => m.getAverageLatency().inMilliseconds)
        .fold(0, (a, b) => a + b);

    return Duration(milliseconds: totalLatency ~/ _connectionMetrics.length);
  }

  double _getErrorRate() {
    final totalEvents = _getTotalEventsProcessed();
    if (totalEvents == 0) return 0.0;

    final totalErrors = _tableMetrics.values
        .map((m) => m.getTotalErrors())
        .fold(0, (a, b) => a + b);

    return totalErrors / totalEvents;
  }

  double _estimateMemoryUsage() {
    // Estimación simple basada en el número de métricas y snapshots
    final baseUsage = (_tableMetrics.length + _connectionMetrics.length) * 0.1;
    final historyUsage = _performanceHistory.length * 0.01;
    return baseUsage + historyUsage;
  }

  void _cleanupOldData() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));

    // Limpiar métricas antiguas
    for (final metrics in _tableMetrics.values) {
      metrics.cleanupOldData(cutoff);
    }

    for (final metrics in _connectionMetrics.values) {
      metrics.cleanupOldData(cutoff);
    }

    LoggerFactory.debug('🧹 Limpieza de datos antiguos completada');
  }
}

// Clases de soporte

class TableMetrics {
  TableMetrics({required this.tableName});

  final String tableName;
  final Queue<int> _eventsProcessed = Queue<int>();
  final Queue<int> _batchSizes = Queue<int>();
  final Queue<Duration> _processingTimes = Queue<Duration>();
  final Queue<int> _errors = Queue<int>();
  final Queue<double> _throughputs = Queue<double>();

  void recordEventsProcessed(int count) => _eventsProcessed.add(count);
  void recordBatchSize(int size) => _batchSizes.add(size);
  void recordProcessingTime(Duration time) => _processingTimes.add(time);
  void recordErrors(int count) => _errors.add(count);
  void recordThroughput(double throughput) => _throughputs.add(throughput);

  int getTotalEventsProcessed() => _eventsProcessed.fold(0, (a, b) => a + b);
  double getAverageBatchSize() => _batchSizes.isEmpty
      ? 0
      : _batchSizes.reduce((a, b) => a + b) / _batchSizes.length;
  int getMaxBatchSize() => _batchSizes.isEmpty ? 0 : _batchSizes.reduce(max);
  Duration getAverageProcessingTime() {
    if (_processingTimes.isEmpty) return Duration.zero;
    final totalMs =
        _processingTimes.map((d) => d.inMilliseconds).reduce((a, b) => a + b);
    return Duration(milliseconds: totalMs ~/ _processingTimes.length);
  }

  int getTotalErrors() => _errors.fold(0, (a, b) => a + b);
  double getAverageThroughput() => _throughputs.isEmpty
      ? 0
      : _throughputs.reduce((a, b) => a + b) / _throughputs.length;

  void cleanupOldData(DateTime cutoff) {
    // En una implementación real, mantendríamos timestamps para limpiar datos antiguos
  }

  Map<String, dynamic> toMap() {
    return {
      'table_name': tableName,
      'total_events_processed': getTotalEventsProcessed(),
      'average_batch_size': getAverageBatchSize(),
      'max_batch_size': getMaxBatchSize(),
      'average_processing_time_ms': getAverageProcessingTime().inMilliseconds,
      'total_errors': getTotalErrors(),
      'average_throughput': getAverageThroughput(),
    };
  }
}

class ConnectionMetrics {
  ConnectionMetrics({required this.connectionId});

  final String connectionId;
  final Queue<Duration> _latencies = Queue<Duration>();
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  DateTime? _lastActivity;

  void recordLatency(Duration latency) => _latencies.add(latency);
  void recordConnectionStatus(bool connected) => _isConnected = connected;
  void recordReconnectAttempts(int attempts) => _reconnectAttempts = attempts;
  void recordActivity(DateTime activity) => _lastActivity = activity;

  bool isConnected() => _isConnected;
  Duration getAverageLatency() {
    if (_latencies.isEmpty) return Duration.zero;
    final totalMs =
        _latencies.map((d) => d.inMilliseconds).reduce((a, b) => a + b);
    return Duration(milliseconds: totalMs ~/ _latencies.length);
  }

  int getReconnectAttempts() => _reconnectAttempts;
  DateTime? getLastActivity() => _lastActivity;

  void cleanupOldData(DateTime cutoff) {
    // Implementar limpieza de datos antiguos
  }
}

class PerformanceSnapshot {
  PerformanceSnapshot({
    required this.timestamp,
    required this.tableCount,
    required this.connectionCount,
    required this.totalEventsProcessed,
    required this.averageLatency,
    required this.errorRate,
    required this.memoryUsage,
  });

  final DateTime timestamp;
  final int tableCount;
  final int connectionCount;
  final int totalEventsProcessed;
  final Duration averageLatency;
  final double errorRate;
  final double memoryUsage;

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'table_count': tableCount,
      'connection_count': connectionCount,
      'total_events_processed': totalEventsProcessed,
      'average_latency_ms': averageLatency.inMilliseconds,
      'error_rate': errorRate,
      'memory_usage_mb': memoryUsage,
    };
  }
}

class Alert {
  Alert({
    required this.type,
    required this.message,
    required this.timestamp,
    required this.severity,
  });

  final AlertType type;
  final String message;
  final DateTime timestamp;
  final AlertSeverity severity;
}

class AlertConfig {
  AlertConfig({required this.threshold, required this.enabled});

  double threshold;
  bool enabled;
}

enum AlertType {
  highLatency,
  connectionFailure,
  lowThroughput,
  memoryUsage,
  batchOverflow,
}

enum AlertSeverity {
  info,
  warning,
  critical,
}

typedef AlertCallback = void Function(Alert alert);
