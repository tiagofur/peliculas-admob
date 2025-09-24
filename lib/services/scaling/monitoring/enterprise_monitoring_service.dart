/// Enterprise Monitoring Service
///
/// Servicio avanzado de monitoreo empresarial que proporciona:
/// - Monitoreo de infraestructura en tiempo real
/// - Sistema de alertas multinivel
/// - Métricas de rendimiento avanzadas
/// - Análisis de tendencias y predicciones
/// - Reportes automatizados
/// - Dashboard de salud del sistema
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Estados del sistema
enum SystemHealth { excellent, good, warning, critical, emergency }

/// Tipos de alertas
enum AlertType { info, warning, error, critical }

/// Tipos de métricas
enum MetricType {
  performance,
  infrastructure,
  business,
  security,
  userExperience
}

/// Modelo de alerta
class Alert {
  const Alert({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.source,
    this.metadata,
    this.acknowledged = false,
  });
  final String id;
  final AlertType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final String? source;
  final Map<String, dynamic>? metadata;
  final bool acknowledged;

  Alert copyWith({
    String? id,
    AlertType? type,
    String? title,
    String? message,
    DateTime? timestamp,
    String? source,
    Map<String, dynamic>? metadata,
    bool? acknowledged,
  }) {
    return Alert(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
      metadata: metadata ?? this.metadata,
      acknowledged: acknowledged ?? this.acknowledged,
    );
  }
}

/// Modelo de métrica
class Metric {
  const Metric({
    required this.name,
    required this.type,
    required this.value,
    required this.unit,
    required this.timestamp,
    this.tags,
    this.threshold,
  });
  final String name;
  final MetricType type;
  final double value;
  final String unit;
  final DateTime timestamp;
  final Map<String, dynamic>? tags;
  final double? threshold;

  bool get isAboveThreshold => threshold != null && value > threshold!;
}

/// Modelo de estado de infraestructura
class InfrastructureStatus {
  const InfrastructureStatus({
    required this.component,
    required this.health,
    required this.uptime,
    required this.metrics,
    required this.lastCheck,
    required this.issues,
  });
  final String component;
  final SystemHealth health;
  final double uptime;
  final Map<String, dynamic> metrics;
  final DateTime lastCheck;
  final List<String> issues;
}

/// Modelo de reporte
class SystemReport {
  const SystemReport({
    required this.id,
    required this.generatedAt,
    required this.overallHealth,
    required this.components,
    required this.activeAlerts,
    required this.metrics,
    required this.summary,
  });
  final String id;
  final DateTime generatedAt;
  final SystemHealth overallHealth;
  final Map<String, InfrastructureStatus> components;
  final List<Alert> activeAlerts;
  final Map<String, List<Metric>> metrics;
  final Map<String, dynamic> summary;
}

/// Servicio de Monitoreo Empresarial
class EnterpriseMonitoringService {
  factory EnterpriseMonitoringService() => _instance;
  EnterpriseMonitoringService._internal();
  static final EnterpriseMonitoringService _instance =
      EnterpriseMonitoringService._internal();

  // Control del servicio
  bool _isRunning = false;
  Timer? _monitoringTimer;
  Timer? _alertsTimer;
  Timer? _reportTimer;

  // Almacenamiento de datos
  final List<Alert> _alerts = [];
  final Map<String, List<Metric>> _metrics = {};
  final Map<String, InfrastructureStatus> _infrastructure = {};
  final List<SystemReport> _reports = [];

  // Configuración
  Duration _monitoringInterval = const Duration(seconds: 30);
  Duration _alertsInterval = const Duration(seconds: 10);
  Duration _reportInterval = const Duration(hours: 1);
  final int _maxAlerts = 1000;
  final int _maxMetrics = 10000;
  final int _maxReports = 100;

  // Callbacks
  Function(Alert)? _onAlert;
  Function(SystemHealth, SystemHealth)? _onHealthChange;
  Function(SystemReport)? _onReportGenerated;

  // Estado actual
  SystemHealth _currentHealth = SystemHealth.good;
  DateTime _serviceStartTime = DateTime.now();

  /// Iniciar el servicio de monitoreo
  Future<void> startMonitoring({
    Duration? monitoringInterval,
    Duration? alertsInterval,
    Duration? reportInterval,
    Function(Alert)? onAlert,
    Function(SystemHealth, SystemHealth)? onHealthChange,
    Function(SystemReport)? onReportGenerated,
  }) async {
    if (_isRunning) {
      if (kDebugMode) {
        debugPrint('⚠️ Enterprise Monitoring ya está ejecutándose');
      }
      return;
    }

    if (kDebugMode) debugPrint('🚀 Iniciando Enterprise Monitoring Service...');

    // Configurar callbacks
    _onAlert = onAlert;
    _onHealthChange = onHealthChange;
    _onReportGenerated = onReportGenerated;

    // Configurar intervalos
    if (monitoringInterval != null) _monitoringInterval = monitoringInterval;
    if (alertsInterval != null) _alertsInterval = alertsInterval;
    if (reportInterval != null) _reportInterval = reportInterval;

    _isRunning = true;
    _serviceStartTime = DateTime.now();

    // Inicializar infraestructura
    await _initializeInfrastructure();

    // Iniciar timers
    _startMonitoringTimer();
    _startAlertsTimer();
    _startReportTimer();

    if (kDebugMode) debugPrint('✅ Enterprise Monitoring Service iniciado');
  }

  /// Detener el servicio
  void stopMonitoring() {
    if (!_isRunning) return;

    if (kDebugMode) {
      debugPrint('🛑 Deteniendo Enterprise Monitoring Service...');
    }

    _monitoringTimer?.cancel();
    _alertsTimer?.cancel();
    _reportTimer?.cancel();

    _isRunning = false;

    if (kDebugMode) debugPrint('✅ Enterprise Monitoring Service detenido');
  }

  /// Registrar métrica personalizada
  void recordMetric(
    String name,
    double value, {
    MetricType type = MetricType.business,
    String unit = 'count',
    Map<String, dynamic>? tags,
    double? threshold,
  }) {
    final metric = Metric(
      name: name,
      type: type,
      value: value,
      unit: unit,
      timestamp: DateTime.now(),
      tags: tags,
      threshold: threshold,
    );

    _addMetric(metric);

    // Verificar threshold
    if (metric.isAboveThreshold) {
      _createAlert(
        type: AlertType.warning,
        title: 'Threshold Exceeded',
        message:
            'Metric $name exceeded threshold: ${metric.value} > ${metric.threshold}',
        source: 'metric_monitor',
        metadata: {'metric': metric.name, 'value': metric.value},
      );
    }

    if (kDebugMode) debugPrint('📊 Métrica registrada: $name = $value $unit');
  }

  /// Crear alerta manual
  void createAlert({
    required AlertType type,
    required String title,
    required String message,
    String? source,
    Map<String, dynamic>? metadata,
  }) {
    _createAlert(
      type: type,
      title: title,
      message: message,
      source: source ?? 'manual',
      metadata: metadata,
    );
  }

  /// Reconocer alerta
  void acknowledgeAlert(String alertId) {
    final alertIndex = _alerts.indexWhere((alert) => alert.id == alertId);
    if (alertIndex != -1) {
      _alerts[alertIndex] = _alerts[alertIndex].copyWith(acknowledged: true);
      if (kDebugMode) debugPrint('✅ Alerta reconocida: $alertId');
    }
  }

  /// Obtener alertas activas
  List<Alert> getActiveAlerts(
      {AlertType? type, bool includeAcknowledged = false}) {
    return _alerts.where((alert) {
      if (type != null && alert.type != type) return false;
      if (!includeAcknowledged && alert.acknowledged) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Obtener métricas recientes
  List<Metric> getRecentMetrics({
    String? name,
    MetricType? type,
    Duration? period,
  }) {
    final cutoff = DateTime.now().subtract(period ?? const Duration(hours: 1));
    final List<Metric> allMetrics = [];

    for (final metricsList in _metrics.values) {
      allMetrics.addAll(metricsList.where((metric) {
        if (metric.timestamp.isBefore(cutoff)) return false;
        if (name != null && metric.name != name) return false;
        if (type != null && metric.type != type) return false;
        return true;
      }));
    }

    return allMetrics..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Obtener estado actual del sistema
  SystemHealth get currentHealth => _currentHealth;

  /// Obtener tiempo de actividad del servicio
  Duration get uptime => DateTime.now().difference(_serviceStartTime);

  /// Obtener estado de infraestructura
  Map<String, InfrastructureStatus> get infrastructureStatus =>
      Map.unmodifiable(_infrastructure);

  /// Generar reporte del sistema
  SystemReport generateSystemReport() {
    final report = SystemReport(
      id: _generateId(),
      generatedAt: DateTime.now(),
      overallHealth: _currentHealth,
      components: Map.from(_infrastructure),
      activeAlerts: getActiveAlerts(),
      metrics: Map.from(_metrics),
      summary: _generateSummary(),
    );

    _reports.add(report);
    _trimReports();

    _onReportGenerated?.call(report);

    if (kDebugMode) debugPrint('📋 Reporte generado: ${report.id}');
    return report;
  }

  /// Obtener reportes históricos
  List<SystemReport> getReports({int limit = 10}) {
    final sorted = List<SystemReport>.from(_reports)
      ..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    return sorted.take(limit).toList();
  }

  // Métodos privados

  /// Inicializar infraestructura simulada
  Future<void> _initializeInfrastructure() async {
    final components = [
      'database',
      'cdn',
      'load_balancer',
      'cache',
      'api_gateway',
      'auth_service',
      'notification_service',
      'analytics_service',
    ];

    for (final component in components) {
      _infrastructure[component] = InfrastructureStatus(
        component: component,
        health: SystemHealth.good,
        uptime: 99.9,
        metrics: {
          'cpu_usage': 25.0 + Random().nextDouble() * 30,
          'memory_usage': 40.0 + Random().nextDouble() * 40,
          'response_time': 50.0 + Random().nextDouble() * 100,
        },
        lastCheck: DateTime.now(),
        issues: [],
      );
    }
  }

  /// Iniciar timer de monitoreo principal
  void _startMonitoringTimer() {
    _monitoringTimer = Timer.periodic(_monitoringInterval, (_) async {
      await _performMonitoringCycle();
    });
  }

  /// Iniciar timer de procesamiento de alertas
  void _startAlertsTimer() {
    _alertsTimer = Timer.periodic(_alertsInterval, (_) {
      _processAlerts();
    });
  }

  /// Iniciar timer de reportes
  void _startReportTimer() {
    _reportTimer = Timer.periodic(_reportInterval, (_) {
      generateSystemReport();
    });
  }

  /// Realizar ciclo de monitoreo
  Future<void> _performMonitoringCycle() async {
    if (kDebugMode) debugPrint('🔄 Ejecutando ciclo de monitoreo...');

    // Actualizar métricas de infraestructura
    await _updateInfrastructureMetrics();

    // Evaluar salud del sistema
    _evaluateSystemHealth();

    // Generar métricas automáticas
    _generateAutomaticMetrics();
  }

  /// Actualizar métricas de infraestructura
  Future<void> _updateInfrastructureMetrics() async {
    for (final component in _infrastructure.keys.toList()) {
      final currentStatus = _infrastructure[component]!;
      final random = Random();

      // Simular variaciones en las métricas
      final newMetrics = Map<String, dynamic>.from(currentStatus.metrics);
      newMetrics['cpu_usage'] =
          _simulateMetric(newMetrics['cpu_usage'], 0, 100);
      newMetrics['memory_usage'] =
          _simulateMetric(newMetrics['memory_usage'], 0, 100);
      newMetrics['response_time'] =
          _simulateMetric(newMetrics['response_time'], 10, 1000);

      // Determinar salud del componente
      SystemHealth health = SystemHealth.good;
      List<String> issues = [];

      if (newMetrics['cpu_usage'] > 80) {
        health = SystemHealth.warning;
        issues.add('High CPU usage');
      }
      if (newMetrics['memory_usage'] > 85) {
        health = SystemHealth.warning;
        issues.add('High memory usage');
      }
      if (newMetrics['response_time'] > 500) {
        health = SystemHealth.warning;
        issues.add('High response time');
      }

      // Simular problemas ocasionales
      if (random.nextDouble() < 0.05) {
        health = SystemHealth.critical;
        issues.add('Random critical issue detected');
      }

      _infrastructure[component] = InfrastructureStatus(
        component: component,
        health: health,
        uptime: currentStatus.uptime * (0.999 + random.nextDouble() * 0.001),
        metrics: newMetrics,
        lastCheck: DateTime.now(),
        issues: issues,
      );

      // Crear alertas para problemas
      for (final issue in issues) {
        if (health == SystemHealth.critical) {
          _createAlert(
            type: AlertType.critical,
            title: 'Critical Issue in $component',
            message: issue,
            source: component,
          );
        } else if (health == SystemHealth.warning) {
          _createAlert(
            type: AlertType.warning,
            title: 'Warning in $component',
            message: issue,
            source: component,
          );
        }
      }
    }
  }

  /// Simular métrica con variaciones naturales
  double _simulateMetric(double current, double min, double max) {
    final random = Random();
    final variation = (random.nextDouble() - 0.5) * 10; // ±5%
    final newValue = current + variation;
    return newValue.clamp(min, max);
  }

  /// Evaluar salud general del sistema
  void _evaluateSystemHealth() {
    final healthCounts = <SystemHealth, int>{};

    for (final status in _infrastructure.values) {
      healthCounts[status.health] = (healthCounts[status.health] ?? 0) + 1;
    }

    final previousHealth = _currentHealth;

    // Determinar salud general
    if (healthCounts[SystemHealth.critical] != null &&
        healthCounts[SystemHealth.critical]! > 0) {
      _currentHealth = SystemHealth.critical;
    } else if (healthCounts[SystemHealth.warning] != null &&
        healthCounts[SystemHealth.warning]! > 2) {
      _currentHealth = SystemHealth.warning;
    } else if (healthCounts[SystemHealth.warning] != null &&
        healthCounts[SystemHealth.warning]! > 0) {
      _currentHealth = SystemHealth.good;
    } else {
      _currentHealth = SystemHealth.excellent;
    }

    // Notificar cambios de salud
    if (previousHealth != _currentHealth) {
      _onHealthChange?.call(previousHealth, _currentHealth);

      _createAlert(
        type: _currentHealth == SystemHealth.critical
            ? AlertType.critical
            : AlertType.info,
        title: 'System Health Changed',
        message:
            'System health changed from $previousHealth to $_currentHealth',
        source: 'health_monitor',
      );
    }
  }

  /// Generar métricas automáticas
  void _generateAutomaticMetrics() {
    // Métrica de alertas activas
    recordMetric(
      'active_alerts',
      getActiveAlerts(includeAcknowledged: false).length.toDouble(),
      type: MetricType.infrastructure,
      unit: 'count',
    );

    // Métrica de componentes saludables
    final healthyComponents = _infrastructure.values
        .where((status) =>
            status.health == SystemHealth.excellent ||
            status.health == SystemHealth.good)
        .length;

    recordMetric(
      'healthy_components',
      healthyComponents.toDouble(),
      type: MetricType.infrastructure,
      unit: 'count',
    );

    // Métricas de rendimiento promedio
    double avgCpuUsage = 0;
    double avgMemoryUsage = 0;
    double avgResponseTime = 0;

    for (final status in _infrastructure.values) {
      avgCpuUsage += status.metrics['cpu_usage'] ?? 0;
      avgMemoryUsage += status.metrics['memory_usage'] ?? 0;
      avgResponseTime += status.metrics['response_time'] ?? 0;
    }

    final componentCount = _infrastructure.length;
    if (componentCount > 0) {
      recordMetric('avg_cpu_usage', avgCpuUsage / componentCount,
          type: MetricType.performance, unit: '%');
      recordMetric('avg_memory_usage', avgMemoryUsage / componentCount,
          type: MetricType.performance, unit: '%');
      recordMetric('avg_response_time', avgResponseTime / componentCount,
          type: MetricType.performance, unit: 'ms');
    }
  }

  /// Procesar alertas
  void _processAlerts() {
    // Limpiar alertas muy antiguas
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    _alerts.removeWhere((alert) => alert.timestamp.isBefore(cutoff));

    // Agrupar alertas similares
    _consolidateAlerts();
  }

  /// Consolidar alertas similares
  void _consolidateAlerts() {
    final Map<String, List<Alert>> grouped = {};

    for (final alert in _alerts) {
      final key = '${alert.type}_${alert.title}_${alert.source}';
      grouped.putIfAbsent(key, () => []).add(alert);
    }

    // Si hay muchas alertas del mismo tipo, crear una consolidada
    for (final entry in grouped.entries) {
      if (entry.value.length > 5) {
        final alerts = entry.value;
        final latest =
            alerts.reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);

        // Crear alerta consolidada
        _createAlert(
          type: latest.type,
          title: '${latest.title} (${alerts.length} occurrences)',
          message:
              '${latest.message}\n\nThis alert occurred ${alerts.length} times in the last period.',
          source: latest.source,
          metadata: {
            'consolidated': true,
            'count': alerts.length,
            'first_occurrence': alerts.first.timestamp.toIso8601String(),
            'last_occurrence': latest.timestamp.toIso8601String(),
          },
        );

        // Remover alertas individuales
        for (final alert in alerts) {
          _alerts.removeWhere((a) => a.id == alert.id);
        }
      }
    }
  }

  /// Crear alerta
  void _createAlert({
    required AlertType type,
    required String title,
    required String message,
    String? source,
    Map<String, dynamic>? metadata,
  }) {
    final alert = Alert(
      id: _generateId(),
      type: type,
      title: title,
      message: message,
      timestamp: DateTime.now(),
      source: source,
      metadata: metadata,
    );

    _alerts.add(alert);
    _trimAlerts();

    _onAlert?.call(alert);

    if (kDebugMode) {
      debugPrint('🚨 Alerta creada: ${alert.type} - ${alert.title}');
    }
  }

  /// Añadir métrica
  void _addMetric(Metric metric) {
    _metrics.putIfAbsent(metric.name, () => []).add(metric);
    _trimMetrics();
  }

  /// Generar resumen del sistema
  Map<String, dynamic> _generateSummary() {
    final alerts = getActiveAlerts(includeAcknowledged: false);
    final metrics = getRecentMetrics();

    return {
      'uptime_seconds': uptime.inSeconds,
      'total_components': _infrastructure.length,
      'healthy_components': _infrastructure.values
          .where((s) =>
              s.health == SystemHealth.excellent ||
              s.health == SystemHealth.good)
          .length,
      'active_alerts': alerts.length,
      'critical_alerts':
          alerts.where((a) => a.type == AlertType.critical).length,
      'recent_metrics': metrics.length,
      'avg_response_time': metrics
              .where((m) => m.name == 'avg_response_time')
              .map((m) => m.value)
              .fold<double>(0, (a, b) => a + b) /
          (metrics
              .where((m) => m.name == 'avg_response_time')
              .length
              .clamp(1, double.infinity)),
    };
  }

  /// Limpiar alertas antiguas
  void _trimAlerts() {
    if (_alerts.length > _maxAlerts) {
      _alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _alerts.removeRange(_maxAlerts, _alerts.length);
    }
  }

  /// Limpiar métricas antiguas
  void _trimMetrics() {
    for (final name in _metrics.keys.toList()) {
      final metrics = _metrics[name]!;
      if (metrics.length > _maxMetrics ~/ _metrics.length) {
        metrics.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _metrics[name] = metrics.take(_maxMetrics ~/ _metrics.length).toList();
      }
    }
  }

  /// Limpiar reportes antiguos
  void _trimReports() {
    if (_reports.length > _maxReports) {
      _reports.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
      _reports.removeRange(_maxReports, _reports.length);
    }
  }

  /// Generar ID único
  String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'ems_${timestamp}_$random';
  }

  /// Limpiar recursos
  void dispose() {
    stopMonitoring();
    _alerts.clear();
    _metrics.clear();
    _infrastructure.clear();
    _reports.clear();
  }
}
