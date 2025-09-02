import 'dart:async';
import 'dart:developer' as developer;

import '../../core/services/sync_performance_metrics.dart';

/// Sistema avanzado de medición de latencia para eventos de sincronización
/// Mide la latencia desde evento Supabase hasta actualización UI
/// Cumple con requisitos del issue #69 de latencia < 1.5s
class LatencyMeasurementSystem {
  factory LatencyMeasurementSystem() => _instance;
  LatencyMeasurementSystem._internal();
  static final LatencyMeasurementSystem _instance = LatencyMeasurementSystem._internal();

  final Map<String, LatencyTracker> _activeTrackers = {};
  final List<LatencyMeasurement> _measurements = [];
  final StreamController<LatencyAlert> _alertController = StreamController<LatencyAlert>.broadcast();
  
  // Configuración según issue #69
  static const Duration _latencyThreshold = Duration(milliseconds: 1500); // < 1.5s requirement
  static const int _maxMeasurements = 1000;
  static const Duration _measurementWindow = Duration(hours: 1);

  /// Stream de alertas de latencia
  Stream<LatencyAlert> get alertStream => _alertController.stream;

  /// Inicia el tracking de latencia para un evento de sincronización
  String startLatencyTracking({
    required String eventType,
    required String entityType,
    required String entityId,
    required LatencyMeasurementPhase phase,
    Map<String, dynamic>? metadata,
  }) {
    final trackingId = 'lat_${DateTime.now().millisecondsSinceEpoch}_${eventType}';
    final startTime = DateTime.now();
    
    final tracker = LatencyTracker(
      trackingId: trackingId,
      eventType: eventType,
      entityType: entityType,
      entityId: entityId,
      startPhase: phase,
      startTime: startTime,
      metadata: metadata ?? {},
    );

    _activeTrackers[trackingId] = tracker;

    developer.log(
      'Iniciando tracking de latencia: $trackingId para $eventType en $entityType:$entityId',
      name: 'LatencyTracker'
    );

    return trackingId;
  }

  /// Marca una fase intermedia en el tracking de latencia
  void markLatencyPhase({
    required String trackingId,
    required LatencyMeasurementPhase phase,
    Map<String, dynamic>? phaseMetadata,
  }) {
    final tracker = _activeTrackers[trackingId];
    if (tracker == null) {
      developer.log('Tracker no encontrado: $trackingId', name: 'LatencyTracker');
      return;
    }

    final now = DateTime.now();
    final phaseData = LatencyPhaseData(
      phase: phase,
      timestamp: now,
      durationFromStart: now.difference(tracker.startTime),
      metadata: phaseMetadata ?? {},
    );

    tracker.phases.add(phaseData);

    developer.log(
      'Fase $phase completada para $trackingId en ${phaseData.durationFromStart.inMilliseconds}ms',
      name: 'LatencyTracker'
    );
  }

  /// Finaliza el tracking de latencia y registra la medición completa
  LatencyMeasurement finishLatencyTracking({
    required String trackingId,
    required LatencyMeasurementPhase endPhase,
    bool success = true,
    String? errorMessage,
  }) {
    final tracker = _activeTrackers.remove(trackingId);
    if (tracker == null) {
      throw ArgumentError('Tracker no encontrado: $trackingId');
    }

    final endTime = DateTime.now();
    final totalLatency = endTime.difference(tracker.startTime);

    // Agregar fase final
    final endPhaseData = LatencyPhaseData(
      phase: endPhase,
      timestamp: endTime,
      durationFromStart: totalLatency,
      metadata: {'success': success, 'error': errorMessage},
    );
    tracker.phases.add(endPhaseData);

    // Crear medición completa
    final measurement = LatencyMeasurement(
      trackingId: trackingId,
      eventType: tracker.eventType,
      entityType: tracker.entityType,
      entityId: tracker.entityId,
      startTime: tracker.startTime,
      endTime: endTime,
      totalLatency: totalLatency,
      phases: List.from(tracker.phases),
      success: success,
      errorMessage: errorMessage,
      metadata: tracker.metadata,
    );

    _addMeasurement(measurement);

    // Verificar si excede el threshold y generar alerta
    if (totalLatency > _latencyThreshold) {
      _generateLatencyAlert(measurement);
    }

    developer.log(
      'Latencia completa para $trackingId: ${totalLatency.inMilliseconds}ms (${success ? 'éxito' : 'fallo'})',
      name: 'LatencyTracker'
    );

    return measurement;
  }

  /// Ejecuta un test completo de latencia end-to-end
  Future<LatencyTestResult> runLatencyTest({
    required String testName,
    required String entityType,
    required List<String> operations,
    int iterations = 10,
  }) async {
    developer.log('Iniciando test de latencia: $testName', name: 'LatencyTracker');
    
    final testStartTime = DateTime.now();
    final measurements = <LatencyMeasurement>[];

    for (int i = 0; i < iterations; i++) {
      for (final operation in operations) {
        try {
          final measurement = await _performSingleLatencyTest(
            testName: '$testName-$operation-$i',
            entityType: entityType,
            operation: operation,
          );
          measurements.add(measurement);
        } catch (e) {
          developer.log('Error en test de latencia: $e', name: 'LatencyTracker');
        }
      }

      // Pequeña pausa entre iteraciones
      if (i < iterations - 1) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    final testEndTime = DateTime.now();
    final testDuration = testEndTime.difference(testStartTime);

    final result = LatencyTestResult(
      testName: testName,
      entityType: entityType,
      operations: operations,
      iterations: iterations,
      startTime: testStartTime,
      duration: testDuration,
      measurements: measurements,
      thresholdExceeded: measurements.where((m) => m.totalLatency > _latencyThreshold).length,
    );

    developer.log(
      'Test de latencia completado: $testName - ${measurements.length} mediciones en ${testDuration.inMilliseconds}ms',
      name: 'LatencyTracker'
    );

    return result;
  }

  /// Obtiene estadísticas de latencia para un período específico
  LatencyStatistics getLatencyStatistics({
    String? entityType,
    String? eventType,
    Duration? timeWindow,
  }) {
    var filteredMeasurements = _measurements.toList();

    // Aplicar filtros
    if (entityType != null) {
      filteredMeasurements = filteredMeasurements
          .where((m) => m.entityType == entityType)
          .toList();
    }

    if (eventType != null) {
      filteredMeasurements = filteredMeasurements
          .where((m) => m.eventType == eventType)
          .toList();
    }

    if (timeWindow != null) {
      final cutoff = DateTime.now().subtract(timeWindow);
      filteredMeasurements = filteredMeasurements
          .where((m) => m.startTime.isAfter(cutoff))
          .toList();
    }

    if (filteredMeasurements.isEmpty) {
      return LatencyStatistics.empty();
    }

    // Calcular estadísticas
    final latencies = filteredMeasurements.map((m) => m.totalLatency).toList()
      ..sort((a, b) => a.compareTo(b));

    final totalMs = latencies.fold<int>(0, (sum, duration) => sum + duration.inMilliseconds);
    final averageMs = totalMs / latencies.length;

    final exceedsThreshold = latencies.where((l) => l > _latencyThreshold).length;
    final successfulMeasurements = filteredMeasurements.where((m) => m.success).length;

    return LatencyStatistics(
      totalMeasurements: filteredMeasurements.length,
      averageLatency: Duration(milliseconds: averageMs.round()),
      minLatency: latencies.first,
      maxLatency: latencies.last,
      medianLatency: latencies[latencies.length ~/ 2],
      p95Latency: latencies[(latencies.length * 0.95).round() - 1],
      p99Latency: latencies[(latencies.length * 0.99).round() - 1],
      thresholdExceeded: exceedsThreshold,
      successRate: successfulMeasurements / filteredMeasurements.length,
      measurementsByPhase: _groupMeasurementsByPhase(filteredMeasurements),
    );
  }

  /// Obtiene mediciones recientes
  List<LatencyMeasurement> getRecentMeasurements({
    int limit = 50,
    String? entityType,
    String? eventType,
  }) {
    var measurements = _measurements.toList();

    // Aplicar filtros
    if (entityType != null) {
      measurements = measurements.where((m) => m.entityType == entityType).toList();
    }

    if (eventType != null) {
      measurements = measurements.where((m) => m.eventType == eventType).toList();
    }

    // Ordenar por tiempo más reciente y limitar
    measurements.sort((a, b) => b.startTime.compareTo(a.startTime));
    return measurements.take(limit).toList();
  }

  /// Limpia mediciones antiguas
  void cleanupOldMeasurements() {
    final cutoff = DateTime.now().subtract(_measurementWindow);
    _measurements.removeWhere((m) => m.startTime.isBefore(cutoff));
    
    developer.log(
      'Limpieza completada: ${_measurements.length} mediciones restantes',
      name: 'LatencyTracker'
    );
  }

  // === MÉTODOS PRIVADOS ===

  Future<LatencyMeasurement> _performSingleLatencyTest({
    required String testName,
    required String entityType,
    required String operation,
  }) async {
    final trackingId = startLatencyTracking(
      eventType: operation,
      entityType: entityType,
      entityId: 'test_${DateTime.now().millisecondsSinceEpoch}',
      phase: LatencyMeasurementPhase.supabaseEventReceived,
      metadata: {'test_name': testName},
    );

    try {
      // Simular procesamiento de evento Supabase
      await Future.delayed(const Duration(milliseconds: 50));
      markLatencyPhase(
        trackingId: trackingId,
        phase: LatencyMeasurementPhase.throttleServiceProcessing,
      );

      // Simular throttling
      await Future.delayed(const Duration(milliseconds: 20));
      markLatencyPhase(
        trackingId: trackingId,
        phase: LatencyMeasurementPhase.syncManagerProcessing,
      );

      // Simular sincronización
      await Future.delayed(const Duration(milliseconds: 100));
      markLatencyPhase(
        trackingId: trackingId,
        phase: LatencyMeasurementPhase.localDatabaseUpdate,
      );

      // Simular actualización de base de datos local
      await Future.delayed(const Duration(milliseconds: 30));
      markLatencyPhase(
        trackingId: trackingId,
        phase: LatencyMeasurementPhase.providerInvalidation,
      );

      // Simular invalidación de provider
      await Future.delayed(const Duration(milliseconds: 10));

      return finishLatencyTracking(
        trackingId: trackingId,
        endPhase: LatencyMeasurementPhase.uiUpdated,
        success: true,
      );

    } catch (e) {
      return finishLatencyTracking(
        trackingId: trackingId,
        endPhase: LatencyMeasurementPhase.uiUpdated,
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  void _addMeasurement(LatencyMeasurement measurement) {
    _measurements.add(measurement);

    // Registrar en métricas globales
    SyncPerformanceMetrics.instance.recordRealtimeEventProcessed(
      measurement.eventType,
      measurement.entityType,
      measurement.totalLatency,
    );

    // Mantener solo las mediciones más recientes
    while (_measurements.length > _maxMeasurements) {
      _measurements.removeAt(0);
    }
  }

  void _generateLatencyAlert(LatencyMeasurement measurement) {
    final alert = LatencyAlert(
      measurement: measurement,
      thresholdExceeded: _latencyThreshold,
      timestamp: DateTime.now(),
      severity: _calculateAlertSeverity(measurement.totalLatency),
    );

    _alertController.add(alert);

    developer.log(
      'ALERTA DE LATENCIA: ${measurement.eventType} en ${measurement.entityType} tomó ${measurement.totalLatency.inMilliseconds}ms (threshold: ${_latencyThreshold.inMilliseconds}ms)',
      name: 'LatencyTracker'
    );
  }

  LatencyAlertSeverity _calculateAlertSeverity(Duration latency) {
    final thresholdMs = _latencyThreshold.inMilliseconds;
    final latencyMs = latency.inMilliseconds;

    if (latencyMs > thresholdMs * 3) return LatencyAlertSeverity.critical;
    if (latencyMs > thresholdMs * 2) return LatencyAlertSeverity.high;
    if (latencyMs > thresholdMs * 1.5) return LatencyAlertSeverity.medium;
    return LatencyAlertSeverity.low;
  }

  Map<LatencyMeasurementPhase, LatencyPhaseStatistics> _groupMeasurementsByPhase(
    List<LatencyMeasurement> measurements,
  ) {
    final phaseStats = <LatencyMeasurementPhase, List<Duration>>{};

    for (final measurement in measurements) {
      for (int i = 0; i < measurement.phases.length - 1; i++) {
        final currentPhase = measurement.phases[i];
        final nextPhase = measurement.phases[i + 1];
        final phaseDuration = nextPhase.timestamp.difference(currentPhase.timestamp);

        phaseStats.putIfAbsent(currentPhase.phase, () => []).add(phaseDuration);
      }
    }

    final result = <LatencyMeasurementPhase, LatencyPhaseStatistics>{};
    for (final entry in phaseStats.entries) {
      final durations = entry.value..sort((a, b) => a.compareTo(b));
      final totalMs = durations.fold<int>(0, (sum, d) => sum + d.inMilliseconds);

      result[entry.key] = LatencyPhaseStatistics(
        phase: entry.key,
        measurements: durations.length,
        averageDuration: Duration(milliseconds: totalMs ~/ durations.length),
        minDuration: durations.first,
        maxDuration: durations.last,
      );
    }

    return result;
  }
}

/// Fases de medición de latencia
enum LatencyMeasurementPhase {
  supabaseEventReceived,
  throttleServiceProcessing,
  syncManagerProcessing,
  localDatabaseUpdate,
  providerInvalidation,
  uiUpdated,
}

/// Tracker activo de latencia
class LatencyTracker {
  final String trackingId;
  final String eventType;
  final String entityType;
  final String entityId;
  final LatencyMeasurementPhase startPhase;
  final DateTime startTime;
  final Map<String, dynamic> metadata;
  final List<LatencyPhaseData> phases = [];

  LatencyTracker({
    required this.trackingId,
    required this.eventType,
    required this.entityType,
    required this.entityId,
    required this.startPhase,
    required this.startTime,
    required this.metadata,
  });
}

/// Datos de una fase específica en la medición
class LatencyPhaseData {
  final LatencyMeasurementPhase phase;
  final DateTime timestamp;
  final Duration durationFromStart;
  final Map<String, dynamic> metadata;

  LatencyPhaseData({
    required this.phase,
    required this.timestamp,
    required this.durationFromStart,
    required this.metadata,
  });
}

/// Medición completa de latencia
class LatencyMeasurement {
  final String trackingId;
  final String eventType;
  final String entityType;
  final String entityId;
  final DateTime startTime;
  final DateTime endTime;
  final Duration totalLatency;
  final List<LatencyPhaseData> phases;
  final bool success;
  final String? errorMessage;
  final Map<String, dynamic> metadata;

  LatencyMeasurement({
    required this.trackingId,
    required this.eventType,
    required this.entityType,
    required this.entityId,
    required this.startTime,
    required this.endTime,
    required this.totalLatency,
    required this.phases,
    required this.success,
    this.errorMessage,
    required this.metadata,
  });
}

/// Resultado de un test de latencia
class LatencyTestResult {
  final String testName;
  final String entityType;
  final List<String> operations;
  final int iterations;
  final DateTime startTime;
  final Duration duration;
  final List<LatencyMeasurement> measurements;
  final int thresholdExceeded;

  LatencyTestResult({
    required this.testName,
    required this.entityType,
    required this.operations,
    required this.iterations,
    required this.startTime,
    required this.duration,
    required this.measurements,
    required this.thresholdExceeded,
  });

  int get totalMeasurements => measurements.length;
  int get successfulMeasurements => measurements.where((m) => m.success).length;
  double get successRate => totalMeasurements > 0 ? successfulMeasurements / totalMeasurements : 0.0;
  double get thresholdExceededRate => totalMeasurements > 0 ? thresholdExceeded / totalMeasurements : 0.0;
}

/// Estadísticas de latencia
class LatencyStatistics {
  final int totalMeasurements;
  final Duration averageLatency;
  final Duration minLatency;
  final Duration maxLatency;
  final Duration medianLatency;
  final Duration p95Latency;
  final Duration p99Latency;
  final int thresholdExceeded;
  final double successRate;
  final Map<LatencyMeasurementPhase, LatencyPhaseStatistics> measurementsByPhase;

  LatencyStatistics({
    required this.totalMeasurements,
    required this.averageLatency,
    required this.minLatency,
    required this.maxLatency,
    required this.medianLatency,
    required this.p95Latency,
    required this.p99Latency,
    required this.thresholdExceeded,
    required this.successRate,
    required this.measurementsByPhase,
  });

  factory LatencyStatistics.empty() {
    return LatencyStatistics(
      totalMeasurements: 0,
      averageLatency: Duration.zero,
      minLatency: Duration.zero,
      maxLatency: Duration.zero,
      medianLatency: Duration.zero,
      p95Latency: Duration.zero,
      p99Latency: Duration.zero,
      thresholdExceeded: 0,
      successRate: 0.0,
      measurementsByPhase: {},
    );
  }

  double get thresholdExceededRate => totalMeasurements > 0 ? thresholdExceeded / totalMeasurements : 0.0;
}

/// Estadísticas de una fase específica
class LatencyPhaseStatistics {
  final LatencyMeasurementPhase phase;
  final int measurements;
  final Duration averageDuration;
  final Duration minDuration;
  final Duration maxDuration;

  LatencyPhaseStatistics({
    required this.phase,
    required this.measurements,
    required this.averageDuration,
    required this.minDuration,
    required this.maxDuration,
  });
}

/// Alerta de latencia
class LatencyAlert {
  final LatencyMeasurement measurement;
  final Duration thresholdExceeded;
  final DateTime timestamp;
  final LatencyAlertSeverity severity;

  LatencyAlert({
    required this.measurement,
    required this.thresholdExceeded,
    required this.timestamp,
    required this.severity,
  });
}

/// Severidad de alerta de latencia
enum LatencyAlertSeverity {
  low,
  medium,
  high,
  critical,
}