import 'package:flutter/foundation.dart';

/// Servicio de métricas en tiempo real
///
/// Recolecta y analiza métricas de performance, uso y errores
/// de la aplicación en tiempo real.
class RealTimeMetricsService {
  RealTimeMetricsService._();
  static RealTimeMetricsService? _instance;

  static RealTimeMetricsService get instance {
    _instance ??= RealTimeMetricsService._();
    return _instance!;
  }

  bool _isInitialized = false;
  final Map<String, List<double>> _metrics = {};
  final Map<String, int> _eventCounts = {};
  final List<MetricEvent> _recentEvents = [];
  DateTime? _sessionStartTime;

  /// Inicializa el servicio de métricas
  Future<void> initialize() async {
    if (_isInitialized) return;

    _sessionStartTime = DateTime.now();
    _isInitialized = true;

    debugPrint('📊 RealTimeMetrics service inicializado');

    // Iniciar métricas de sesión
    startSessionMetrics();
  }

  /// Inicia la recolección de métricas de sesión
  void startSessionMetrics() {
    recordEvent('session_started', data: {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'platform': kIsWeb ? 'web' : 'mobile',
    });
  }

  /// Registra una métrica numérica
  void recordMetric(String name, double value,
      {Map<String, dynamic>? context}) {
    if (!_isInitialized) return;

    _metrics.putIfAbsent(name, () => []);
    _metrics[name]!.add(value);

    // Mantener solo los últimos 100 valores
    if (_metrics[name]!.length > 100) {
      _metrics[name]!.removeAt(0);
    }

    if (kDebugMode) {
      debugPrint('📈 Metric [$name]: $value');
    }

    recordEvent('metric_recorded', data: {
      'metric_name': name,
      'value': value,
      ...?context,
    });
  }

  /// Registra un evento
  void recordEvent(String eventType, {Map<String, dynamic>? data}) {
    if (!_isInitialized) return;

    _eventCounts[eventType] = (_eventCounts[eventType] ?? 0) + 1;

    final event = MetricEvent(
      type: eventType,
      timestamp: DateTime.now(),
      data: data,
    );

    _recentEvents.add(event);

    // Mantener solo los últimos 500 eventos
    if (_recentEvents.length > 500) {
      _recentEvents.removeAt(0);
    }

    if (kDebugMode && eventType != 'metric_recorded') {
      debugPrint('📅 Event [$eventType]: $data');
    }
  }

  /// Obtiene estadísticas de una métrica
  MetricStats? getMetricStats(String name) {
    final values = _metrics[name];
    if (values == null || values.isEmpty) return null;

    values.sort();
    final length = values.length;
    final sum = values.reduce((a, b) => a + b);

    return MetricStats(
      name: name,
      count: length,
      sum: sum,
      average: sum / length,
      min: values.first,
      max: values.last,
      median: length % 2 == 0
          ? (values[length ~/ 2 - 1] + values[length ~/ 2]) / 2
          : values[length ~/ 2],
      p95: values[(length * 0.95).floor().clamp(0, length - 1)],
    );
  }

  /// Obtiene todas las métricas actuales
  Map<String, MetricStats> getAllMetrics() {
    final result = <String, MetricStats>{};

    for (final name in _metrics.keys) {
      final stats = getMetricStats(name);
      if (stats != null) {
        result[name] = stats;
      }
    }

    return result;
  }

  /// Obtiene contadores de eventos
  Map<String, int> getEventCounts() => Map.from(_eventCounts);

  /// Obtiene eventos recientes
  List<MetricEvent> getRecentEvents([int? limit]) {
    final events = List<MetricEvent>.from(_recentEvents);
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (limit != null && limit < events.length) {
      return events.take(limit).toList();
    }

    return events;
  }

  /// Obtiene duración de la sesión actual
  Duration getSessionDuration() {
    if (_sessionStartTime == null) return Duration.zero;
    return DateTime.now().difference(_sessionStartTime!);
  }

  /// Obtiene un resumen completo de métricas
  MetricsSummary getMetricsSummary() {
    return MetricsSummary(
      sessionDuration: getSessionDuration(),
      totalEvents: _recentEvents.length,
      uniqueEventTypes: _eventCounts.length,
      metricsCollected: _metrics.length,
      topEvents: _getTopEvents(),
      performanceMetrics: _getPerformanceMetrics(),
      errorRate: _calculateErrorRate(),
    );
  }

  /// Exporta métricas en formato JSON
  Map<String, dynamic> exportMetrics() {
    return {
      'session_info': {
        'start_time': _sessionStartTime?.toIso8601String(),
        'duration_seconds': getSessionDuration().inSeconds,
        'platform': kIsWeb ? 'web' : 'mobile',
      },
      'metrics': getAllMetrics().map((k, v) => MapEntry(k, v.toJson())),
      'event_counts': getEventCounts(),
      'recent_events': getRecentEvents(50).map((e) => e.toJson()).toList(),
      'summary': getMetricsSummary().toJson(),
    };
  }

  /// Limpia todas las métricas
  void clearMetrics() {
    _metrics.clear();
    _eventCounts.clear();
    _recentEvents.clear();

    recordEvent('metrics_cleared');

    if (kDebugMode) {
      debugPrint('🗑️ Métricas limpiadas');
    }
  }

  // Métodos privados de análisis

  List<MapEntry<String, int>> _getTopEvents() {
    final entries = _eventCounts.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(10).toList();
  }

  Map<String, double> _getPerformanceMetrics() {
    final result = <String, double>{};

    // Métricas clave de performance
    final loadTimeStats = getMetricStats('screen_load_time');
    if (loadTimeStats != null) {
      result['avg_load_time'] = loadTimeStats.average;
    }

    final memoryStats = getMetricStats('memory_usage');
    if (memoryStats != null) {
      result['avg_memory_mb'] = memoryStats.average;
    }

    final fpsStats = getMetricStats('frame_rate');
    if (fpsStats != null) {
      result['avg_fps'] = fpsStats.average;
    }

    return result;
  }

  double _calculateErrorRate() {
    final totalEvents = _recentEvents.length;
    if (totalEvents == 0) return 0.0;

    final errorEvents = _recentEvents
        .where((e) => e.type.contains('error') || e.type.contains('exception'))
        .length;

    return (errorEvents / totalEvents) * 100;
  }
}

/// Clase para representar un evento métrico
class MetricEvent {
  MetricEvent({
    required this.type,
    required this.timestamp,
    this.data,
  });
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  Map<String, dynamic> toJson() => {
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        if (data != null) 'data': data,
      };
}

/// Clase para estadísticas de métrica
class MetricStats {
  MetricStats({
    required this.name,
    required this.count,
    required this.sum,
    required this.average,
    required this.min,
    required this.max,
    required this.median,
    required this.p95,
  });
  final String name;
  final int count;
  final double sum;
  final double average;
  final double min;
  final double max;
  final double median;
  final double p95;

  Map<String, dynamic> toJson() => {
        'name': name,
        'count': count,
        'sum': sum,
        'average': average,
        'min': min,
        'max': max,
        'median': median,
        'p95': p95,
      };
}

/// Resumen completo de métricas
class MetricsSummary {
  MetricsSummary({
    required this.sessionDuration,
    required this.totalEvents,
    required this.uniqueEventTypes,
    required this.metricsCollected,
    required this.topEvents,
    required this.performanceMetrics,
    required this.errorRate,
  });
  final Duration sessionDuration;
  final int totalEvents;
  final int uniqueEventTypes;
  final int metricsCollected;
  final List<MapEntry<String, int>> topEvents;
  final Map<String, double> performanceMetrics;
  final double errorRate;

  Map<String, dynamic> toJson() => {
        'session_duration_seconds': sessionDuration.inSeconds,
        'total_events': totalEvents,
        'unique_event_types': uniqueEventTypes,
        'metrics_collected': metricsCollected,
        'top_events': Map.fromEntries(topEvents),
        'performance_metrics': performanceMetrics,
        'error_rate_percentage': errorRate,
      };
}

/// Helpers para métricas específicas
class MetricsHelpers {
  static final _metrics = RealTimeMetricsService.instance;

  /// Mide el tiempo de ejecución de una función
  static Future<T> measureExecutionTime<T>(
    String metricName,
    Future<T> Function() function,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await function();
      _metrics.recordMetric(
          metricName, stopwatch.elapsedMilliseconds.toDouble());
      return result;
    } catch (e) {
      _metrics.recordEvent('execution_error', data: {
        'metric': metricName,
        'error': e.toString(),
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Registra uso de memoria actual
  static void recordCurrentMemoryUsage([String? context]) {
    // En una implementación real, aquí se obtendría el uso real de memoria
    // Por ahora usamos un valor simulado
    const estimatedMemoryMB = 50.0; // Placeholder

    _metrics.recordMetric('memory_usage', estimatedMemoryMB,
        context: context != null ? {'context': context} : null);
  }

  /// Registra FPS (frames por segundo)
  static void recordFrameRate(double fps) {
    _metrics.recordMetric('frame_rate', fps);
  }

  /// Registra tiempo de carga de pantalla
  static void recordScreenLoadTime(String screenName, Duration loadTime) {
    _metrics.recordMetric(
        'screen_load_time', loadTime.inMilliseconds.toDouble(),
        context: {'screen': screenName});

    _metrics.recordEvent('screen_loaded', data: {
      'screen': screenName,
      'load_time_ms': loadTime.inMilliseconds,
    });
  }

  /// Registra error de red
  static void recordNetworkError(String endpoint, String error) {
    _metrics.recordEvent('network_error', data: {
      'endpoint': endpoint,
      'error': error,
    });
  }

  /// Registra respuesta exitosa de API
  static void recordApiSuccess(String endpoint, Duration responseTime) {
    _metrics.recordMetric(
        'api_response_time', responseTime.inMilliseconds.toDouble(),
        context: {'endpoint': endpoint});

    _metrics.recordEvent('api_success', data: {
      'endpoint': endpoint,
      'response_time_ms': responseTime.inMilliseconds,
    });
  }
}
