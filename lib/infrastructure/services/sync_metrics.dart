import 'dart:async';

import 'package:flutter/foundation.dart';

/// Métricas de una operación de sincronización
class SyncOperationMetrics {
  SyncOperationMetrics({
    required this.repository,
    required this.operation,
    required this.startTime,
    required this.endTime,
    required this.success,
    this.itemsProcessed = 0,
    this.conflictsResolved = 0,
    this.errorType,
  }) : duration = endTime.difference(startTime);
  final String repository;
  final String operation;
  final DateTime startTime;
  final DateTime endTime;
  final bool success;
  final int itemsProcessed;
  final int conflictsResolved;
  final String? errorType;
  final Duration duration;

  Map<String, dynamic> toJson() => {
        'repository': repository,
        'operation': operation,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'success': success,
        'items_processed': itemsProcessed,
        'conflicts_resolved': conflictsResolved,
        'error_type': errorType,
        'duration_ms': duration.inMilliseconds,
      };
}

/// KPIs agregados de sincronización
class SyncKPIs {
  const SyncKPIs({
    required this.averageSyncTime,
    required this.successRate,
    required this.totalOperations,
    required this.totalErrors,
    required this.totalConflicts,
    required this.totalItemsSynced,
    required this.periodStart,
    required this.periodEnd,
    required this.repositorySuccessRates,
    required this.repositoryAvgTimes,
    required this.errorTypesCounts,
  });
  final double averageSyncTime;
  final double successRate;
  final int totalOperations;
  final int totalErrors;
  final int totalConflicts;
  final int totalItemsSynced;
  final DateTime periodStart;
  final DateTime periodEnd;
  final Map<String, double> repositorySuccessRates;
  final Map<String, double> repositoryAvgTimes;
  final Map<String, int> errorTypesCounts;

  Map<String, dynamic> toJson() => {
        'average_sync_time_ms': averageSyncTime,
        'success_rate': successRate,
        'total_operations': totalOperations,
        'total_errors': totalErrors,
        'total_conflicts': totalConflicts,
        'total_items_synced': totalItemsSynced,
        'period_start': periodStart.toIso8601String(),
        'period_end': periodEnd.toIso8601String(),
        'repository_success_rates': repositorySuccessRates,
        'repository_avg_times': repositoryAvgTimes,
        'error_types_counts': errorTypesCounts,
      };
}

/// Alerta de sincronización
class SyncAlert {
  SyncAlert({
    required this.id,
    required this.type,
    required this.message,
    required this.severity,
    required this.timestamp,
    this.metadata = const {},
    this.acknowledged = false,
  });
  final String id;
  final String type;
  final String message;
  final String severity; // 'low', 'medium', 'high', 'critical'
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final bool acknowledged;

  SyncAlert copyWith({
    String? id,
    String? type,
    String? message,
    String? severity,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    bool? acknowledged,
  }) {
    return SyncAlert(
      id: id ?? this.id,
      type: type ?? this.type,
      message: message ?? this.message,
      severity: severity ?? this.severity,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
      acknowledged: acknowledged ?? this.acknowledged,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'message': message,
        'severity': severity,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
        'acknowledged': acknowledged,
      };
}

/// Servicio de métricas de sincronización
class SyncMetricsService {
  factory SyncMetricsService() => _instance;
  SyncMetricsService._internal();
  static final SyncMetricsService _instance = SyncMetricsService._internal();

  final List<SyncOperationMetrics> _metrics = [];
  final List<SyncAlert> _alerts = [];
  final int _maxMetrics = 5000; // Mantener últimas 5000 métricas
  final int _maxAlerts = 1000; // Mantener últimas 1000 alertas

  Timer? _alertCheckTimer;
  final Duration _alertCheckInterval = const Duration(minutes: 1);

  // Umbrales para alertas
  static const double _successRateThreshold = 0.95; // 95%
  static const int _maxSyncTimeMs = 30000; // 30 segundos
  static const int _maxErrorsPerHour = 10;
  static const int _maxConflictsPerHour = 5;

  /// Inicializar el servicio de métricas
  void initialize() {
    _startAlertMonitoring();
  }

  /// Registrar métricas de una operación
  void recordOperation(SyncOperationMetrics metrics) {
    _metrics.add(metrics);

    // Mantener solo las últimas N métricas
    if (_metrics.length > _maxMetrics) {
      _metrics.removeAt(0);
    }

    // Verificar si se deben generar alertas
    _checkForAlerts(metrics);

    if (kDebugMode) {
      print('SyncMetrics: ${metrics.repository} ${metrics.operation} '
          '${metrics.success ? "SUCCESS" : "FAILED"} '
          '(${metrics.duration.inMilliseconds}ms)');
    }
  }

  /// Obtener KPIs para un período específico
  SyncKPIs getKPIs({
    DateTime? since,
    DateTime? until,
    String? repository,
  }) {
    final now = DateTime.now();
    since ??= now.subtract(const Duration(hours: 24));
    until ??= now;

    final filteredMetrics = _metrics.where((m) {
      if (m.startTime.isBefore(since!) || m.startTime.isAfter(until!)) {
        return false;
      }
      if (repository != null && m.repository != repository) {
        return false;
      }
      return true;
    }).toList();

    if (filteredMetrics.isEmpty) {
      return SyncKPIs(
        averageSyncTime: 0.0,
        successRate: 0.0,
        totalOperations: 0,
        totalErrors: 0,
        totalConflicts: 0,
        totalItemsSynced: 0,
        periodStart: since,
        periodEnd: until,
        repositorySuccessRates: {},
        repositoryAvgTimes: {},
        errorTypesCounts: {},
      );
    }

    // Calcular métricas agregadas
    final totalOps = filteredMetrics.length;
    final successfulOps = filteredMetrics.where((m) => m.success).length;
    final totalErrors = filteredMetrics.where((m) => !m.success).length;
    final totalConflicts =
        filteredMetrics.map((m) => m.conflictsResolved).reduce((a, b) => a + b);
    final totalItems =
        filteredMetrics.map((m) => m.itemsProcessed).reduce((a, b) => a + b);

    final avgTime = filteredMetrics
            .map((m) => m.duration.inMilliseconds)
            .reduce((a, b) => a + b) /
        totalOps;

    final successRate = totalOps > 0 ? successfulOps / totalOps : 0.0;

    // Métricas por repositorio
    final repositories = filteredMetrics.map((m) => m.repository).toSet();
    final repoSuccessRates = <String, double>{};
    final repoAvgTimes = <String, double>{};

    for (final repo in repositories) {
      final repoMetrics = filteredMetrics.where((m) => m.repository == repo);
      final repoTotal = repoMetrics.length;
      final repoSuccessful = repoMetrics.where((m) => m.success).length;
      final repoAvgTime = repoMetrics
              .map((m) => m.duration.inMilliseconds)
              .reduce((a, b) => a + b) /
          repoTotal;

      repoSuccessRates[repo] = repoTotal > 0 ? repoSuccessful / repoTotal : 0.0;
      repoAvgTimes[repo] = repoAvgTime;
    }

    // Contar tipos de errores
    final errorTypes = <String, int>{};
    for (final metric in filteredMetrics.where((m) => !m.success)) {
      final errorType = metric.errorType ?? 'unknown';
      errorTypes[errorType] = (errorTypes[errorType] ?? 0) + 1;
    }

    return SyncKPIs(
      averageSyncTime: avgTime,
      successRate: successRate,
      totalOperations: totalOps,
      totalErrors: totalErrors,
      totalConflicts: totalConflicts,
      totalItemsSynced: totalItems,
      periodStart: since,
      periodEnd: until,
      repositorySuccessRates: repoSuccessRates,
      repositoryAvgTimes: repoAvgTimes,
      errorTypesCounts: errorTypes,
    );
  }

  /// Obtener métricas de rendimiento en tiempo real
  Map<String, dynamic> getRealTimeMetrics() {
    final lastHour = DateTime.now().subtract(const Duration(hours: 1));
    final recentMetrics = _metrics.where((m) => m.startTime.isAfter(lastHour));

    if (recentMetrics.isEmpty) {
      return {
        'operations_last_hour': 0,
        'success_rate_last_hour': 0.0,
        'avg_sync_time_ms': 0.0,
        'active_alerts': _alerts.where((a) => !a.acknowledged).length,
        'last_sync': null,
      };
    }

    final successful = recentMetrics.where((m) => m.success).length;
    final total = recentMetrics.length;
    final avgTime = recentMetrics
            .map((m) => m.duration.inMilliseconds)
            .reduce((a, b) => a + b) /
        total;

    final lastSync =
        _metrics.isNotEmpty ? _metrics.last.endTime.toIso8601String() : null;

    return {
      'operations_last_hour': total,
      'success_rate_last_hour': total > 0 ? successful / total : 0.0,
      'avg_sync_time_ms': avgTime,
      'active_alerts': _alerts.where((a) => !a.acknowledged).length,
      'last_sync': lastSync,
    };
  }

  /// Verificar y generar alertas basadas en métricas
  void _checkForAlerts(SyncOperationMetrics metrics) {
    final now = DateTime.now();

    // Alerta por tiempo de sincronización excesivo
    if (metrics.duration.inMilliseconds > _maxSyncTimeMs) {
      _createAlert(
        type: 'slow_sync',
        message: 'Sincronización lenta detectada en ${metrics.repository}: '
            '${metrics.duration.inMilliseconds}ms',
        severity: 'medium',
        metadata: {
          'repository': metrics.repository,
          'operation': metrics.operation,
          'duration_ms': metrics.duration.inMilliseconds,
        },
      );
    }

    // Alerta por fallo de sincronización
    if (!metrics.success) {
      _createAlert(
        type: 'sync_failure',
        message: 'Fallo en sincronización de ${metrics.repository}: '
            '${metrics.errorType ?? "Error desconocido"}',
        severity: 'high',
        metadata: {
          'repository': metrics.repository,
          'operation': metrics.operation,
          'error_type': metrics.errorType,
        },
      );
    }

    // Verificar tasa de éxito por hora
    final lastHour = now.subtract(const Duration(hours: 1));
    final hourlyMetrics = _metrics.where((m) => m.startTime.isAfter(lastHour));

    if (hourlyMetrics.length >= 10) {
      // Solo verificar si hay suficientes datos
      final successful = hourlyMetrics.where((m) => m.success).length;
      final successRate = successful / hourlyMetrics.length;

      if (successRate < _successRateThreshold) {
        _createAlert(
          type: 'low_success_rate',
          message:
              'Tasa de éxito baja detectada: ${(successRate * 100).toStringAsFixed(1)}%',
          severity: 'critical',
          metadata: {
            'success_rate': successRate,
            'total_operations': hourlyMetrics.length,
            'successful_operations': successful,
          },
        );
      }
    }

    // Verificar errores por hora
    final hourlyErrors = hourlyMetrics.where((m) => !m.success).length;
    if (hourlyErrors > _maxErrorsPerHour) {
      _createAlert(
        type: 'high_error_rate',
        message:
            'Alto número de errores detectado: $hourlyErrors errores en la última hora',
        severity: 'high',
        metadata: {
          'errors_count': hourlyErrors,
          'threshold': _maxErrorsPerHour,
        },
      );
    }

    // Verificar conflictos por hora
    final hourlyConflicts =
        hourlyMetrics.map((m) => m.conflictsResolved).reduce((a, b) => a + b);
    if (hourlyConflicts > _maxConflictsPerHour) {
      _createAlert(
        type: 'high_conflict_rate',
        message:
            'Alto número de conflictos detectado: $hourlyConflicts conflictos en la última hora',
        severity: 'medium',
        metadata: {
          'conflicts_count': hourlyConflicts,
          'threshold': _maxConflictsPerHour,
        },
      );
    }
  }

  /// Crear una nueva alerta
  void _createAlert({
    required String type,
    required String message,
    required String severity,
    Map<String, dynamic> metadata = const {},
  }) {
    // Evitar alertas duplicadas recientes (últimos 5 minutos)
    final recentAlerts = _alerts.where((a) =>
        a.type == type &&
        a.timestamp
            .isAfter(DateTime.now().subtract(const Duration(minutes: 5))));

    if (recentAlerts.isNotEmpty) return;

    final alert = SyncAlert(
      id: '${type}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      message: message,
      severity: severity,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    _alerts.add(alert);

    // Mantener solo las últimas N alertas
    if (_alerts.length > _maxAlerts) {
      _alerts.removeAt(0);
    }

    if (kDebugMode) {
      print('SyncAlert [${severity.toUpperCase()}]: $message');
    }
  }

  /// Iniciar monitoreo automático de alertas
  void _startAlertMonitoring() {
    _alertCheckTimer?.cancel();
    _alertCheckTimer = Timer.periodic(_alertCheckInterval, (_) {
      _performPeriodicChecks();
    });
  }

  /// Verificaciones periódicas de alertas
  void _performPeriodicChecks() {
    final now = DateTime.now();
    final last5Minutes = now.subtract(const Duration(minutes: 5));

    // Verificar si no ha habido sincronizaciones recientes
    final recentSyncs =
        _metrics.where((m) => m.startTime.isAfter(last5Minutes));
    if (recentSyncs.isEmpty && _metrics.isNotEmpty) {
      final lastSync = _metrics.last;
      final timeSinceLastSync = now.difference(lastSync.endTime);

      if (timeSinceLastSync.inMinutes > 10) {
        _createAlert(
          type: 'no_recent_sync',
          message: 'No se han detectado sincronizaciones en los últimos '
              '${timeSinceLastSync.inMinutes} minutos',
          severity: 'medium',
          metadata: {
            'minutes_since_last_sync': timeSinceLastSync.inMinutes,
            'last_sync': lastSync.endTime.toIso8601String(),
          },
        );
      }
    }
  }

  /// Obtener alertas activas
  List<SyncAlert> getActiveAlerts() {
    return _alerts.where((a) => !a.acknowledged).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Obtener todas las alertas
  List<SyncAlert> getAllAlerts({int? limit}) {
    final sorted = _alerts.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (limit != null && sorted.length > limit) {
      return sorted.take(limit).toList();
    }

    return sorted;
  }

  /// Marcar alerta como reconocida
  void acknowledgeAlert(String alertId) {
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index != -1) {
      _alerts[index] = _alerts[index].copyWith(acknowledged: true);
    }
  }

  /// Limpiar alertas antiguas
  void clearOldAlerts({DateTime? before}) {
    before ??= DateTime.now().subtract(const Duration(days: 7));
    _alerts.removeWhere((alert) => alert.timestamp.isBefore(before!));
  }

  /// Limpiar métricas antiguas
  void clearOldMetrics({DateTime? before}) {
    before ??= DateTime.now().subtract(const Duration(days: 30));
    _metrics.removeWhere((metric) => metric.startTime.isBefore(before!));
  }

  /// Exportar métricas como JSON
  List<Map<String, dynamic>> exportMetrics({
    DateTime? since,
    String? repository,
    int? limit,
  }) {
    var filtered = _metrics.where((m) {
      if (since != null && m.startTime.isBefore(since)) return false;
      if (repository != null && m.repository != repository) return false;
      return true;
    }).toList();

    filtered.sort((a, b) => b.startTime.compareTo(a.startTime));

    if (limit != null && filtered.length > limit) {
      filtered = filtered.take(limit).toList();
    }

    return filtered.map((m) => m.toJson()).toList();
  }

  /// Detener el servicio
  void dispose() {
    _alertCheckTimer?.cancel();
  }
}

/// Extension para facilitar el registro de métricas
extension SyncMetricsExtension on Object {
  SyncMetricsService get syncMetrics => SyncMetricsService();

  String get _repositoryName => runtimeType.toString();

  /// Registrar inicio de operación de sincronización
  DateTime startSyncOperation() {
    return DateTime.now();
  }

  /// Registrar finalización exitosa de operación
  void recordSyncSuccess({
    required DateTime startTime,
    required String operation,
    int itemsProcessed = 0,
    int conflictsResolved = 0,
  }) {
    final endTime = DateTime.now();
    syncMetrics.recordOperation(SyncOperationMetrics(
      repository: _repositoryName,
      operation: operation,
      startTime: startTime,
      endTime: endTime,
      success: true,
      itemsProcessed: itemsProcessed,
      conflictsResolved: conflictsResolved,
    ));
  }

  /// Registrar fallo de operación
  void recordSyncFailure({
    required DateTime startTime,
    required String operation,
    String? errorType,
    int itemsProcessed = 0,
  }) {
    final endTime = DateTime.now();
    syncMetrics.recordOperation(SyncOperationMetrics(
      repository: _repositoryName,
      operation: operation,
      startTime: startTime,
      endTime: endTime,
      success: false,
      itemsProcessed: itemsProcessed,
      errorType: errorType,
    ));
  }
}
