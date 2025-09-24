import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'logger_factory.dart';
import 'safe_developer_log.dart';

/// Servicio de logging avanzado con métricas, alertas y dashboard
class AdvancedLoggingService {
  AdvancedLoggingService._() {
    _initialize();
  }

  static AdvancedLoggingService? _instance;

  static AdvancedLoggingService get instance {
    _instance ??= AdvancedLoggingService._();
    return _instance!;
  }

  // Configuración del servicio
  static const int _maxLogEntries = 10000;
  static const int _maxMetricEntries = 5000;
  static const Duration _metricsAggregationInterval = Duration(minutes: 1);
  static const Duration _alertCheckInterval = Duration(seconds: 30);
  static const Duration _logRotationInterval = Duration(hours: 24);

  // Almacenamiento de logs y métricas
  final Queue<LogEntry> _logEntries = Queue<LogEntry>();
  final Queue<MetricEntry> _metricEntries = Queue<MetricEntry>();
  final Map<String, PerformanceMetrics> _performanceMetrics = {};
  final Map<String, AlertRule> _alertRules = {};
  final Queue<Alert> _activeAlerts = Queue<Alert>();

  // Agregaciones de métricas
  final Map<String, AggregatedMetrics> _aggregatedMetrics = {};

  // Timers para procesamiento
  Timer? _metricsAggregationTimer;
  Timer? _alertCheckTimer;
  Timer? _logRotationTimer;

  // Streams para eventos
  final StreamController<LogEntry> _logStreamController =
      StreamController<LogEntry>.broadcast();
  final StreamController<Alert> _alertStreamController =
      StreamController<Alert>.broadcast();
  final StreamController<DashboardUpdate> _dashboardStreamController =
      StreamController<DashboardUpdate>.broadcast();

  // Estado del servicio
  bool _isInitialized = false;
  bool _isDisposed = false;
  String? _logDirectory;

  // Contadores de rendimiento
  int _totalLogs = 0;
  int _totalMetrics = 0;
  int _totalAlerts = 0;
  DateTime _serviceStartTime = DateTime.now();

  /// Stream de logs en tiempo real
  Stream<LogEntry> get logStream => _logStreamController.stream;

  /// Stream de alertas
  Stream<Alert> get alertStream => _alertStreamController.stream;

  /// Stream de actualizaciones del dashboard
  Stream<DashboardUpdate> get dashboardStream =>
      _dashboardStreamController.stream;

  /// Indica si el servicio está inicializado
  bool get isInitialized => _isInitialized;

  /// Tiempo de funcionamiento del servicio
  Duration get uptime => DateTime.now().difference(_serviceStartTime);

  // =============================================
  // INICIALIZACIÓN
  // =============================================

  /// Inicializa el servicio de logging avanzado
  Future<void> _initialize() async {
    if (_isInitialized || _isDisposed) return;

    try {
      // Configurar directorio de logs
      await _setupLogDirectory();

      // Configurar reglas de alerta por defecto
      _setupDefaultAlertRules();

      // Iniciar timers de procesamiento
      _startTimers();

      // Cargar logs existentes si los hay
      await _loadExistingLogs();

      _isInitialized = true;
      _serviceStartTime = DateTime.now();

      await logInfo(
          'AdvancedLoggingService', 'Service initialized successfully');
    } catch (e) {
      SafeDeveloperLog.log('❌ Failed to initialize AdvancedLoggingService: $e',
          error: e);
      _isInitialized = true; // Continue even if initialization fails
    }
  }

  /// Configura el directorio de logs
  Future<void> _setupLogDirectory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _logDirectory = '${appDir.path}/logs';

      final logDir = Directory(_logDirectory!);
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
    } catch (e) {
      SafeDeveloperLog.log('⚠️ Failed to setup log directory: $e', error: e);
    }
  }

  /// Configura reglas de alerta por defecto
  void _setupDefaultAlertRules() {
    // Alerta por errores frecuentes
    addAlertRule(AlertRule(
      id: 'frequent_errors',
      name: 'Errores Frecuentes',
      description: 'Se detectaron muchos errores en poco tiempo',
      condition: AlertCondition.errorRate,
      threshold: 10, // 10 errores por minuto
      timeWindow: const Duration(minutes: 1),
      severity: AlertSeverity.high,
      enabled: true,
    ));

    // Alerta por latencia alta
    addAlertRule(AlertRule(
      id: 'high_latency',
      name: 'Latencia Alta',
      description: 'La latencia de sincronización es muy alta',
      condition: AlertCondition.averageLatency,
      threshold: 5000, // 5 segundos
      timeWindow: const Duration(minutes: 5),
      severity: AlertSeverity.medium,
      enabled: true,
    ));

    // Alerta por fallos de conexión
    addAlertRule(AlertRule(
      id: 'connection_failures',
      name: 'Fallos de Conexión',
      description: 'Múltiples fallos de conexión detectados',
      condition: AlertCondition.connectionFailures,
      threshold: 5, // 5 fallos por minuto
      timeWindow: const Duration(minutes: 1),
      severity: AlertSeverity.high,
      enabled: true,
    ));

    // Alerta por uso excesivo de memoria
    addAlertRule(AlertRule(
      id: 'memory_usage',
      name: 'Uso Excesivo de Memoria',
      description: 'El uso de memoria está por encima del límite',
      condition: AlertCondition.memoryUsage,
      threshold: 100, // 100 MB
      timeWindow: const Duration(minutes: 5),
      severity: AlertSeverity.medium,
      enabled: true,
    ));
  }

  /// Inicia los timers de procesamiento
  void _startTimers() {
    // Timer para agregación de métricas
    _metricsAggregationTimer = Timer.periodic(_metricsAggregationInterval, (_) {
      if (!_isDisposed) {
        _aggregateMetrics();
      }
    });

    // Timer para verificación de alertas
    _alertCheckTimer = Timer.periodic(_alertCheckInterval, (_) {
      if (!_isDisposed) {
        _checkAlerts();
      }
    });

    // Timer para rotación de logs
    _logRotationTimer = Timer.periodic(_logRotationInterval, (_) {
      if (!_isDisposed) {
        _rotateLogs();
      }
    });
  }

  /// Carga logs existentes del almacenamiento
  Future<void> _loadExistingLogs() async {
    if (_logDirectory == null) return;

    try {
      final logFile = File('$_logDirectory/current.log');
      if (await logFile.exists()) {
        final lines = await logFile.readAsLines();

        for (final line in lines.take(1000)) {
          // Cargar solo los últimos 1000
          try {
            final json = jsonDecode(line);
            final entry = LogEntry.fromJson(json);
            _logEntries.add(entry);
          } catch (e) {
            // Ignorar líneas malformadas
          }
        }

        SafeDeveloperLog.log(
            '📄 Loaded ${_logEntries.length} existing log entries');
      }
    } catch (e) {
      SafeDeveloperLog.log('⚠️ Failed to load existing logs: $e', error: e);
    }
  }

  // =============================================
  // LOGGING PÚBLICO
  // =============================================

  /// Registra un log de información
  Future<void> logInfo(String component, String message,
      {Map<String, dynamic>? metadata}) async {
    await _addLogEntry(LogLevel.info, component, message, metadata: metadata);
  }

  /// Registra un log de advertencia
  Future<void> logWarning(String component, String message,
      {Map<String, dynamic>? metadata}) async {
    await _addLogEntry(LogLevel.warning, component, message,
        metadata: metadata);
  }

  /// Registra un log de error
  Future<void> logError(String component, String message,
      {Map<String, dynamic>? metadata, StackTrace? stackTrace}) async {
    final errorMetadata = Map<String, dynamic>.from(metadata ?? {});
    if (stackTrace != null) {
      errorMetadata['stack_trace'] = stackTrace.toString();
    }
    await _addLogEntry(LogLevel.error, component, message,
        metadata: errorMetadata);
  }

  /// Registra un log de debug
  Future<void> logDebug(String component, String message,
      {Map<String, dynamic>? metadata}) async {
    if (kDebugMode) {
      await _addLogEntry(LogLevel.debug, component, message,
          metadata: metadata);
    }
  }

  /// Registra una métrica de rendimiento
  Future<void> recordMetric(String name, double value,
      {String? unit, Map<String, dynamic>? tags}) async {
    final entry = MetricEntry(
      name: name,
      value: value,
      unit: unit ?? 'count',
      tags: tags ?? {},
      timestamp: DateTime.now(),
    );

    _metricEntries.add(entry);
    _totalMetrics++;

    // Mantener límite de métricas
    while (_metricEntries.length > _maxMetricEntries) {
      _metricEntries.removeFirst();
    }

    // Actualizar métricas de rendimiento
    _updatePerformanceMetrics(name, value);
  }

  /// Registra el tiempo de ejecución de una operación
  Future<void> recordExecutionTime(String operation, Duration duration,
      {Map<String, dynamic>? metadata}) async {
    await recordMetric(
      'execution_time_$operation',
      duration.inMilliseconds.toDouble(),
      unit: 'ms',
      tags: {
        'operation': operation,
        ...?metadata,
      },
    );
  }

  /// Registra un evento de sincronización
  Future<void> recordSyncEvent(String eventType, String tableName,
      {bool success = true, String? error}) async {
    await recordMetric(
      'sync_event',
      success ? 1.0 : 0.0,
      tags: {
        'event_type': eventType,
        'table_name': tableName,
        'success': success.toString(),
        if (error != null) 'error': error,
      },
    );

    if (!success && error != null) {
      await logError(
          'SyncService', 'Sync event failed: $eventType for $tableName',
          metadata: {'error': error, 'table': tableName});
    }
  }

  /// Registra métricas de conexión
  Future<void> recordConnectionMetrics({
    required bool connected,
    Duration? latency,
    String? networkType,
    double? bandwidth,
  }) async {
    await recordMetric(
      'connection_status',
      connected ? 1.0 : 0.0,
      tags: {
        'connected': connected.toString(),
        if (networkType != null) 'network_type': networkType,
      },
    );

    if (latency != null) {
      await recordMetric(
        'connection_latency',
        latency.inMilliseconds.toDouble(),
        unit: 'ms',
        tags: {'network_type': networkType ?? 'unknown'},
      );
    }

    if (bandwidth != null) {
      await recordMetric(
        'connection_bandwidth',
        bandwidth,
        unit: 'mbps',
        tags: {'network_type': networkType ?? 'unknown'},
      );
    }
  }

  // =============================================
  // GESTIÓN DE LOGS INTERNA
  // =============================================

  /// Agrega una entrada de log
  Future<void> _addLogEntry(LogLevel level, String component, String message,
      {Map<String, dynamic>? metadata}) async {
    final entry = LogEntry(
      level: level,
      component: component,
      message: message,
      timestamp: DateTime.now(),
      metadata: metadata ?? {},
    );

    _logEntries.add(entry);
    _totalLogs++;

    // Mantener límite de logs en memoria
    while (_logEntries.length > _maxLogEntries) {
      _logEntries.removeFirst();
    }

    // Emitir al stream
    _logStreamController.add(entry);

    // Escribir a archivo si es posible
    await _writeLogToFile(entry);

    // Log también al sistema estándar
    _logToStandardOutput(entry);
  }

  /// Escribe log a archivo
  Future<void> _writeLogToFile(LogEntry entry) async {
    if (_logDirectory == null) return;

    try {
      final logFile = File('$_logDirectory/current.log');
      final json = jsonEncode(entry.toJson());
      await logFile.writeAsString('$json\n', mode: FileMode.append);
    } catch (e) {
      // Fallar silenciosamente para evitar loops
    }
  }

  /// Log al output estándar
  void _logToStandardOutput(LogEntry entry) {
    final timestamp = entry.timestamp.toIso8601String();
    final level = entry.level.name.toUpperCase();
    final component = entry.component;
    final message = entry.message;

    final logLine = '[$timestamp] $level [$component] $message';

    switch (entry.level) {
      case LogLevel.error:
        LoggerFactory.error(logLine);
        break;
      case LogLevel.warning:
        LoggerFactory.warning(logLine);
        break;
      case LogLevel.info:
        LoggerFactory.info(logLine);
        break;
      case LogLevel.debug:
        LoggerFactory.debug(logLine);
        break;
    }
  }

  // =============================================
  // MÉTRICAS Y AGREGACIONES
  // =============================================

  /// Actualiza métricas de rendimiento
  void _updatePerformanceMetrics(String name, double value) {
    final metrics = _performanceMetrics[name] ?? PerformanceMetrics(name: name);

    metrics.addValue(value);
    _performanceMetrics[name] = metrics;
  }

  /// Agrega métricas periódicamente
  void _aggregateMetrics() {
    final now = DateTime.now();
    final windowStart = now.subtract(_metricsAggregationInterval);

    // Agrupar métricas por nombre en la ventana de tiempo
    final Map<String, List<MetricEntry>> groupedMetrics = {};

    for (final metric in _metricEntries) {
      if (metric.timestamp.isAfter(windowStart)) {
        groupedMetrics.putIfAbsent(metric.name, () => []).add(metric);
      }
    }

    // Crear agregaciones
    for (final entry in groupedMetrics.entries) {
      final metricName = entry.key;
      final metrics = entry.value;

      if (metrics.isNotEmpty) {
        final values = metrics.map((m) => m.value).toList();
        values.sort();

        final aggregated = AggregatedMetrics(
          name: metricName,
          count: metrics.length,
          sum: values.fold(0.0, (a, b) => a + b),
          average: values.fold(0.0, (a, b) => a + b) / values.length,
          min: values.first,
          max: values.last,
          median: values[values.length ~/ 2],
          p95: values[(values.length * 0.95).floor()],
          timestamp: now,
          timeWindow: _metricsAggregationInterval,
        );

        _aggregatedMetrics[metricName] = aggregated;
      }
    }

    // Emitir actualización del dashboard
    _emitDashboardUpdate();
  }

  // =============================================
  // SISTEMA DE ALERTAS
  // =============================================

  /// Agrega una regla de alerta
  void addAlertRule(AlertRule rule) {
    _alertRules[rule.id] = rule;
  }

  /// Elimina una regla de alerta
  void removeAlertRule(String ruleId) {
    _alertRules.remove(ruleId);
  }

  /// Verifica alertas según las reglas configuradas
  void _checkAlerts() {
    final now = DateTime.now();

    for (final rule in _alertRules.values) {
      if (!rule.enabled) continue;

      final shouldAlert = _evaluateAlertCondition(rule, now);

      if (shouldAlert) {
        final existingAlert = _activeAlerts
            .where((a) => a.ruleId == rule.id && !a.isResolved)
            .firstOrNull;

        if (existingAlert == null) {
          // Crear nueva alerta
          final alert = Alert(
            id: 'alert_${rule.id}_${now.millisecondsSinceEpoch}',
            ruleId: rule.id,
            ruleName: rule.name,
            message: rule.description,
            severity: rule.severity,
            timestamp: now,
            isResolved: false,
            metadata: _getAlertMetadata(rule, now),
          );

          _activeAlerts.add(alert);
          _totalAlerts++;

          // Emitir alerta
          _alertStreamController.add(alert);

          // Log de la alerta
          logWarning('AlertSystem', 'Alert triggered: ${rule.name}',
              metadata: alert.metadata);
        }
      }
    }

    // Limpiar alertas antiguas
    _cleanupOldAlerts();
  }

  /// Evalúa si se debe disparar una alerta
  bool _evaluateAlertCondition(AlertRule rule, DateTime now) {
    final windowStart = now.subtract(rule.timeWindow);

    switch (rule.condition) {
      case AlertCondition.errorRate:
        final errorCount = _logEntries
            .where((log) =>
                log.level == LogLevel.error &&
                log.timestamp.isAfter(windowStart))
            .length;
        return errorCount >= rule.threshold;

      case AlertCondition.averageLatency:
        final latencyMetrics = _metricEntries
            .where((m) =>
                m.name.contains('latency') && m.timestamp.isAfter(windowStart))
            .toList();
        if (latencyMetrics.isEmpty) return false;

        final avgLatency =
            latencyMetrics.map((m) => m.value).fold(0.0, (a, b) => a + b) /
                latencyMetrics.length;
        return avgLatency >= rule.threshold;

      case AlertCondition.connectionFailures:
        final failureCount = _logEntries
            .where((log) =>
                log.message.toLowerCase().contains('connection') &&
                log.message.toLowerCase().contains('fail') &&
                log.timestamp.isAfter(windowStart))
            .length;
        return failureCount >= rule.threshold;

      case AlertCondition.memoryUsage:
        final memoryMetrics = _metricEntries
            .where((m) =>
                m.name.contains('memory') && m.timestamp.isAfter(windowStart))
            .toList();
        if (memoryMetrics.isEmpty) return false;

        final maxMemory = memoryMetrics
            .map((m) => m.value)
            .fold(0.0, (a, b) => a > b ? a : b);
        return maxMemory >= rule.threshold;

      case AlertCondition.custom:
        // Para condiciones personalizadas, siempre retornar false por ahora
        return false;
    }
  }

  /// Obtiene metadatos para una alerta
  Map<String, dynamic> _getAlertMetadata(AlertRule rule, DateTime timestamp) {
    final windowStart = timestamp.subtract(rule.timeWindow);

    return {
      'rule_id': rule.id,
      'condition': rule.condition.name,
      'threshold': rule.threshold,
      'time_window_minutes': rule.timeWindow.inMinutes,
      'evaluation_time': timestamp.toIso8601String(),
      'window_start': windowStart.toIso8601String(),
    };
  }

  /// Limpia alertas antiguas
  void _cleanupOldAlerts() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));

    while (_activeAlerts.isNotEmpty &&
        _activeAlerts.first.timestamp.isBefore(cutoff)) {
      _activeAlerts.removeFirst();
    }
  }

  /// Resuelve una alerta
  void resolveAlert(String alertId) {
    for (final alert in _activeAlerts) {
      if (alert.id == alertId && !alert.isResolved) {
        alert.resolve();
        logInfo('AlertSystem', 'Alert resolved: ${alert.ruleName}');
        break;
      }
    }
  }

  // =============================================
  // DASHBOARD Y REPORTES
  // =============================================

  /// Emite actualización del dashboard
  void _emitDashboardUpdate() {
    final update = DashboardUpdate(
      timestamp: DateTime.now(),
      totalLogs: _totalLogs,
      totalMetrics: _totalMetrics,
      totalAlerts: _totalAlerts,
      activeAlerts: _activeAlerts.where((a) => !a.isResolved).length,
      uptime: uptime,
      recentLogs: _logEntries.take(100).toList(),
      aggregatedMetrics: Map.from(_aggregatedMetrics),
      performanceMetrics: Map.from(_performanceMetrics),
    );

    _dashboardStreamController.add(update);
  }

  /// Obtiene estadísticas del dashboard
  DashboardStatistics getDashboardStatistics() {
    final now = DateTime.now();
    final last24h = now.subtract(const Duration(hours: 24));
    final lastHour = now.subtract(const Duration(hours: 1));

    final logsLast24h =
        _logEntries.where((log) => log.timestamp.isAfter(last24h)).length;
    final logsLastHour =
        _logEntries.where((log) => log.timestamp.isAfter(lastHour)).length;

    final errorsLast24h = _logEntries
        .where((log) =>
            log.level == LogLevel.error && log.timestamp.isAfter(last24h))
        .length;

    final activeAlertCount = _activeAlerts.where((a) => !a.isResolved).length;

    return DashboardStatistics(
      totalLogs: _totalLogs,
      totalMetrics: _totalMetrics,
      totalAlerts: _totalAlerts,
      activeAlerts: activeAlertCount,
      logsLast24h: logsLast24h,
      logsLastHour: logsLastHour,
      errorsLast24h: errorsLast24h,
      uptime: uptime,
      memoryUsage: _logEntries.length + _metricEntries.length,
      performanceMetrics: Map.from(_performanceMetrics),
      aggregatedMetrics: Map.from(_aggregatedMetrics),
    );
  }

  /// Obtiene logs filtrados
  List<LogEntry> getFilteredLogs({
    LogLevel? level,
    String? component,
    DateTime? startTime,
    DateTime? endTime,
    int limit = 1000,
  }) {
    var filtered = _logEntries.where((log) {
      if (level != null && log.level != level) return false;
      if (component != null &&
          !log.component.toLowerCase().contains(component.toLowerCase())) {
        return false;
      }
      if (startTime != null && log.timestamp.isBefore(startTime)) return false;
      if (endTime != null && log.timestamp.isAfter(endTime)) return false;
      return true;
    });

    return filtered.take(limit).toList();
  }

  /// Obtiene métricas filtradas
  List<MetricEntry> getFilteredMetrics({
    String? name,
    DateTime? startTime,
    DateTime? endTime,
    int limit = 1000,
  }) {
    var filtered = _metricEntries.where((metric) {
      if (name != null &&
          !metric.name.toLowerCase().contains(name.toLowerCase())) {
        return false;
      }
      if (startTime != null && metric.timestamp.isBefore(startTime)) {
        return false;
      }
      if (endTime != null && metric.timestamp.isAfter(endTime)) return false;
      return true;
    });

    return filtered.take(limit).toList();
  }

  /// Exporta logs a JSON
  Future<String> exportLogsToJson({
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final logs = getFilteredLogs(
      startTime: startTime,
      endTime: endTime,
      limit: 10000,
    );

    final export = {
      'export_timestamp': DateTime.now().toIso8601String(),
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'total_logs': logs.length,
      'logs': logs.map((log) => log.toJson()).toList(),
    };

    return jsonEncode(export);
  }

  // =============================================
  // ROTACIÓN DE LOGS
  // =============================================

  /// Rota los archivos de log
  Future<void> _rotateLogs() async {
    if (_logDirectory == null) return;

    try {
      final currentLogFile = File('$_logDirectory/current.log');

      if (await currentLogFile.exists()) {
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
        final rotatedLogFile = File('$_logDirectory/log_$timestamp.log');

        await currentLogFile.rename(rotatedLogFile.path);

        logInfo('LogRotation', 'Log file rotated to: ${rotatedLogFile.path}');

        // Limpiar logs antiguos (mantener solo los últimos 7 días)
        await _cleanupOldLogFiles();
      }
    } catch (e) {
      logError('LogRotation', 'Failed to rotate logs: $e');
    }
  }

  /// Limpia archivos de log antiguos
  Future<void> _cleanupOldLogFiles() async {
    if (_logDirectory == null) return;

    try {
      final logDir = Directory(_logDirectory!);
      final files = await logDir.list().toList();

      final cutoff = DateTime.now().subtract(const Duration(days: 7));

      for (final file in files) {
        if (file is File && file.path.contains('log_')) {
          final stat = await file.stat();
          if (stat.modified.isBefore(cutoff)) {
            await file.delete();
            logInfo('LogRotation', 'Deleted old log file: ${file.path}');
          }
        }
      }
    } catch (e) {
      logError('LogRotation', 'Failed to cleanup old log files: $e');
    }
  }

  // =============================================
  // LIMPIEZA Y DISPOSICIÓN
  // =============================================

  /// Libera recursos del servicio
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    // Cancelar timers
    _metricsAggregationTimer?.cancel();
    _alertCheckTimer?.cancel();
    _logRotationTimer?.cancel();

    // Cerrar streams
    await _logStreamController.close();
    await _alertStreamController.close();
    await _dashboardStreamController.close();

    // Limpiar datos
    _logEntries.clear();
    _metricEntries.clear();
    _performanceMetrics.clear();
    _alertRules.clear();
    _activeAlerts.clear();
    _aggregatedMetrics.clear();

    SafeDeveloperLog.log('🔒 AdvancedLoggingService disposed');
  }
}

// =============================================
// CLASES DE SOPORTE
// =============================================

/// Niveles de log
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Entrada de log
class LogEntry {
  LogEntry({
    required this.level,
    required this.component,
    required this.message,
    required this.timestamp,
    required this.metadata,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      level: LogLevel.values.firstWhere((l) => l.name == json['level']),
      component: json['component'],
      message: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  final LogLevel level;
  final String component;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() {
    return {
      'level': level.name,
      'component': component,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }
}

/// Entrada de métrica
class MetricEntry {
  MetricEntry({
    required this.name,
    required this.value,
    required this.unit,
    required this.tags,
    required this.timestamp,
  });

  final String name;
  final double value;
  final String unit;
  final Map<String, dynamic> tags;
  final DateTime timestamp;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'unit': unit,
      'tags': tags,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Métricas de rendimiento
class PerformanceMetrics {
  PerformanceMetrics({required this.name});

  final String name;
  final List<double> _values = [];
  double _sum = 0.0;
  double _min = double.infinity;
  double _max = double.negativeInfinity;
  DateTime _lastUpdate = DateTime.now();

  int get count => _values.length;
  double get sum => _sum;
  double get average => count > 0 ? _sum / count : 0.0;
  double get min => _min == double.infinity ? 0.0 : _min;
  double get max => _max == double.negativeInfinity ? 0.0 : _max;
  DateTime get lastUpdate => _lastUpdate;

  void addValue(double value) {
    _values.add(value);
    _sum += value;
    if (value < _min) _min = value;
    if (value > _max) _max = value;
    _lastUpdate = DateTime.now();

    // Mantener solo los últimos 1000 valores
    if (_values.length > 1000) {
      final removed = _values.removeAt(0);
      _sum -= removed;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'count': count,
      'sum': sum,
      'average': average,
      'min': min,
      'max': max,
      'last_update': lastUpdate.toIso8601String(),
    };
  }
}

/// Métricas agregadas
class AggregatedMetrics {
  const AggregatedMetrics({
    required this.name,
    required this.count,
    required this.sum,
    required this.average,
    required this.min,
    required this.max,
    required this.median,
    required this.p95,
    required this.timestamp,
    required this.timeWindow,
  });

  final String name;
  final int count;
  final double sum;
  final double average;
  final double min;
  final double max;
  final double median;
  final double p95;
  final DateTime timestamp;
  final Duration timeWindow;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'count': count,
      'sum': sum,
      'average': average,
      'min': min,
      'max': max,
      'median': median,
      'p95': p95,
      'timestamp': timestamp.toIso8601String(),
      'time_window_minutes': timeWindow.inMinutes,
    };
  }
}

/// Condiciones de alerta
enum AlertCondition {
  errorRate,
  averageLatency,
  connectionFailures,
  memoryUsage,
  custom,
}

/// Severidad de alerta
enum AlertSeverity {
  low,
  medium,
  high,
  critical,
}

/// Regla de alerta
class AlertRule {
  AlertRule({
    required this.id,
    required this.name,
    required this.description,
    required this.condition,
    required this.threshold,
    required this.timeWindow,
    required this.severity,
    required this.enabled,
  });

  final String id;
  final String name;
  final String description;
  final AlertCondition condition;
  final double threshold;
  final Duration timeWindow;
  final AlertSeverity severity;
  final bool enabled;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'condition': condition.name,
      'threshold': threshold,
      'time_window_minutes': timeWindow.inMinutes,
      'severity': severity.name,
      'enabled': enabled,
    };
  }
}

/// Alerta activa
class Alert {
  Alert({
    required this.id,
    required this.ruleId,
    required this.ruleName,
    required this.message,
    required this.severity,
    required this.timestamp,
    required this.isResolved,
    required this.metadata,
  });

  final String id;
  final String ruleId;
  final String ruleName;
  final String message;
  final AlertSeverity severity;
  final DateTime timestamp;
  bool isResolved;
  DateTime? resolvedAt;
  final Map<String, dynamic> metadata;

  void resolve() {
    isResolved = true;
    resolvedAt = DateTime.now();
  }

  Duration? get duration {
    final end = resolvedAt ?? DateTime.now();
    return end.difference(timestamp);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rule_id': ruleId,
      'rule_name': ruleName,
      'message': message,
      'severity': severity.name,
      'timestamp': timestamp.toIso8601String(),
      'is_resolved': isResolved,
      'resolved_at': resolvedAt?.toIso8601String(),
      'duration_seconds': duration?.inSeconds,
      'metadata': metadata,
    };
  }
}

/// Actualización del dashboard
class DashboardUpdate {
  const DashboardUpdate({
    required this.timestamp,
    required this.totalLogs,
    required this.totalMetrics,
    required this.totalAlerts,
    required this.activeAlerts,
    required this.uptime,
    required this.recentLogs,
    required this.aggregatedMetrics,
    required this.performanceMetrics,
  });

  final DateTime timestamp;
  final int totalLogs;
  final int totalMetrics;
  final int totalAlerts;
  final int activeAlerts;
  final Duration uptime;
  final List<LogEntry> recentLogs;
  final Map<String, AggregatedMetrics> aggregatedMetrics;
  final Map<String, PerformanceMetrics> performanceMetrics;
}

/// Estadísticas del dashboard
class DashboardStatistics {
  const DashboardStatistics({
    required this.totalLogs,
    required this.totalMetrics,
    required this.totalAlerts,
    required this.activeAlerts,
    required this.logsLast24h,
    required this.logsLastHour,
    required this.errorsLast24h,
    required this.uptime,
    required this.memoryUsage,
    required this.performanceMetrics,
    required this.aggregatedMetrics,
  });

  final int totalLogs;
  final int totalMetrics;
  final int totalAlerts;
  final int activeAlerts;
  final int logsLast24h;
  final int logsLastHour;
  final int errorsLast24h;
  final Duration uptime;
  final int memoryUsage;
  final Map<String, PerformanceMetrics> performanceMetrics;
  final Map<String, AggregatedMetrics> aggregatedMetrics;

  Map<String, dynamic> toMap() {
    return {
      'total_logs': totalLogs,
      'total_metrics': totalMetrics,
      'total_alerts': totalAlerts,
      'active_alerts': activeAlerts,
      'logs_last_24h': logsLast24h,
      'logs_last_hour': logsLastHour,
      'errors_last_24h': errorsLast24h,
      'uptime_seconds': uptime.inSeconds,
      'memory_usage': memoryUsage,
      'performance_metrics_count': performanceMetrics.length,
      'aggregated_metrics_count': aggregatedMetrics.length,
    };
  }
}
