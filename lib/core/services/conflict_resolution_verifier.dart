import 'dart:async';
import 'dart:developer' as developer;

import '../../core/services/sync_performance_metrics.dart';

/// Sistema avanzado de verificación de resolución de conflictos
/// Implementa validación explícita de last-write-wins usando updated_at
/// según los requisitos del issue #69
class ConflictResolutionVerifier {
  factory ConflictResolutionVerifier() => _instance;
  ConflictResolutionVerifier._internal();

  static final ConflictResolutionVerifier _instance =
      ConflictResolutionVerifier._internal();

  final List<ConflictLog> _conflictHistory = [];
  final Map<String, ConflictResolutionStrategy> _strategies = {};

  // Configuración para tests de conflictos
  static const int _maxConflictHistory = 1000;

  /// Inicializa el verificador con estrategias de resolución
  void initialize() {
    _strategies['user_watchlist'] = ConflictResolutionStrategy.lastWriteWins;
    _strategies['user_movie_ratings'] =
        ConflictResolutionStrategy.lastWriteWins;
    developer.log('ConflictResolutionVerifier initialized',
        name: 'ConflictVerifier');
  }

  /// Simula un conflicto concurrente entre múltiples dispositivos
  /// para validar la resolución last-write-wins
  Future<ConflictSimulationResult> simulateConflict({
    required String entityType,
    required String entityId,
    required int numberOfDevices,
    required Duration delayBetweenWrites,
  }) async {
    assert(numberOfDevices >= 2,
        'Se requieren al menos 2 dispositivos para simular conflicto');

    final conflictId = 'sim_${DateTime.now().millisecondsSinceEpoch}';
    final startTime = DateTime.now();

    developer.log(
        'Iniciando simulación de conflicto: $conflictId para $entityType:$entityId con $numberOfDevices dispositivos',
        name: 'ConflictVerifier');

    // Registrar inicio del conflicto
    final metricsConflictId = SyncPerformanceMetrics.instance
        .recordConflictDetected(entityType, entityId);

    final deviceWrites = <ConflictingWrite>[];

    try {
      // Simular escrituras concurrentes desde múltiples dispositivos
      for (int device = 0; device < numberOfDevices; device++) {
        final writeTime = startTime.add(
            Duration(milliseconds: device * delayBetweenWrites.inMilliseconds));

        final write = ConflictingWrite(
          deviceId: 'device_$device',
          entityType: entityType,
          entityId: entityId,
          timestamp: writeTime,
          data: await _generateTestData(entityType, entityId, device),
        );

        deviceWrites.add(write);

        // Simular el delay entre escrituras
        if (device < numberOfDevices - 1) {
          await Future.delayed(delayBetweenWrites);
        }
      }

      // Determinar el ganador usando last-write-wins
      final winner = _resolveConflictLastWriteWins(deviceWrites);
      final resolutionTime = DateTime.now().difference(startTime);

      // Validar que la resolución es correcta
      final isResolutionCorrect =
          _validateLastWriteWinsResolution(deviceWrites, winner);

      // Registrar resolución del conflicto
      SyncPerformanceMetrics.instance.recordConflictResolved(
          metricsConflictId, isResolutionCorrect, entityId);

      // Crear log del conflicto
      final conflictLog = ConflictLog(
        conflictId: conflictId,
        entityType: entityType,
        entityId: entityId,
        startTime: startTime,
        resolutionTime: resolutionTime,
        deviceWrites: deviceWrites,
        winnerWrite: winner,
        strategy: ConflictResolutionStrategy.lastWriteWins,
        isResolutionCorrect: isResolutionCorrect,
      );

      _addConflictLog(conflictLog);

      developer.log(
          'Conflicto $conflictId resuelto en ${resolutionTime.inMilliseconds}ms. Ganador: ${winner.deviceId}',
          name: 'ConflictVerifier');

      return ConflictSimulationResult(
        conflictId: conflictId,
        success: isResolutionCorrect,
        resolutionTime: resolutionTime,
        totalWrites: deviceWrites.length,
        winnerDeviceId: winner.deviceId,
        conflictLog: conflictLog,
      );
    } catch (e) {
      developer.log('Error en simulación de conflicto $conflictId: $e',
          name: 'ConflictVerifier');

      SyncPerformanceMetrics.instance
          .recordConflictResolved(metricsConflictId, false, entityId);

      return ConflictSimulationResult(
        conflictId: conflictId,
        success: false,
        resolutionTime: DateTime.now().difference(startTime),
        totalWrites: deviceWrites.length,
        winnerDeviceId: null,
        error: e.toString(),
      );
    }
  }

  /// Ejecuta una suite completa de tests de conflictos
  Future<ConflictTestSuiteResult> runConflictTestSuite() async {
    developer.log('Iniciando suite de tests de conflictos',
        name: 'ConflictVerifier');

    final startTime = DateTime.now();
    final results = <ConflictSimulationResult>[];

    // Test 1: Conflicto simple en watchlist (2 dispositivos)
    results.add(await simulateConflict(
      entityType: 'user_watchlist',
      entityId: 'movie_550',
      numberOfDevices: 2,
      delayBetweenWrites: const Duration(milliseconds: 100),
    ));

    // Test 2: Conflicto complejo en watchlist (5 dispositivos)
    results.add(await simulateConflict(
      entityType: 'user_watchlist',
      entityId: 'movie_551',
      numberOfDevices: 5,
      delayBetweenWrites: const Duration(milliseconds: 50),
    ));

    // Test 3: Conflicto simple en ratings (2 dispositivos)
    results.add(await simulateConflict(
      entityType: 'user_movie_ratings',
      entityId: 'rating_550',
      numberOfDevices: 2,
      delayBetweenWrites: const Duration(milliseconds: 200),
    ));

    // Test 4: Conflicto complejo en ratings (3 dispositivos)
    results.add(await simulateConflict(
      entityType: 'user_movie_ratings',
      entityId: 'rating_551',
      numberOfDevices: 3,
      delayBetweenWrites: const Duration(milliseconds: 75),
    ));

    // Test 5: Conflicto con timestamps muy cercanos
    results.add(await simulateConflict(
      entityType: 'user_watchlist',
      entityId: 'movie_552',
      numberOfDevices: 3,
      delayBetweenWrites: const Duration(milliseconds: 1), // Muy cercanos
    ));

    final totalTime = DateTime.now().difference(startTime);
    final successfulTests = results.where((r) => r.success).length;

    developer.log(
        'Suite de tests completada: $successfulTests/${results.length} exitosos en ${totalTime.inMilliseconds}ms',
        name: 'ConflictVerifier');

    return ConflictTestSuiteResult(
      startTime: startTime,
      totalTime: totalTime,
      totalTests: results.length,
      successfulTests: successfulTests,
      failedTests: results.length - successfulTests,
      testResults: results,
    );
  }

  /// Valida que un objeto tiene el timestamp updated_at correcto
  bool validateUpdatedAtTimestamp(Map<String, dynamic> data) {
    if (!data.containsKey('updated_at')) {
      developer.log('Objeto sin campo updated_at: $data',
          name: 'ConflictVerifier');
      return false;
    }

    try {
      final updatedAt = DateTime.parse(data['updated_at']);
      final now = DateTime.now();

      // El timestamp no puede ser del futuro ni muy antiguo (más de 1 hora)
      if (updatedAt.isAfter(now.add(const Duration(minutes: 5))) ||
          updatedAt.isBefore(now.subtract(const Duration(hours: 1)))) {
        developer.log(
            'Timestamp updated_at inválido: $updatedAt (actual: $now)',
            name: 'ConflictVerifier');
        return false;
      }

      return true;
    } catch (e) {
      developer.log('Error parseando updated_at: $e', name: 'ConflictVerifier');
      return false;
    }
  }

  /// Obtiene el historial de conflictos
  List<ConflictLog> getConflictHistory({
    String? entityType,
    Duration? timeWindow,
  }) {
    var filtered = _conflictHistory.toList();

    if (entityType != null) {
      filtered = filtered.where((log) => log.entityType == entityType).toList();
    }

    if (timeWindow != null) {
      final cutoff = DateTime.now().subtract(timeWindow);
      filtered =
          filtered.where((log) => log.startTime.isAfter(cutoff)).toList();
    }

    return filtered..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  /// Obtiene estadísticas de resolución de conflictos
  ConflictResolutionStats getResolutionStats({Duration? timeWindow}) {
    final logs = getConflictHistory(timeWindow: timeWindow);

    if (logs.isEmpty) {
      return ConflictResolutionStats(
        totalConflicts: 0,
        resolvedConflicts: 0,
        averageResolutionTime: Duration.zero,
        successRate: 0.0,
        conflictsByEntity: {},
      );
    }

    final resolvedCount = logs.where((log) => log.isResolutionCorrect).length;
    final totalResolutionTime = logs.fold<Duration>(
      Duration.zero,
      (sum, log) => sum + log.resolutionTime,
    );

    final conflictsByEntity = <String, int>{};
    for (final log in logs) {
      conflictsByEntity[log.entityType] =
          (conflictsByEntity[log.entityType] ?? 0) + 1;
    }

    return ConflictResolutionStats(
      totalConflicts: logs.length,
      resolvedConflicts: resolvedCount,
      averageResolutionTime: Duration(
          milliseconds: totalResolutionTime.inMilliseconds ~/ logs.length),
      successRate: resolvedCount / logs.length,
      conflictsByEntity: conflictsByEntity,
    );
  }

  // === MÉTODOS PRIVADOS ===

  ConflictingWrite _resolveConflictLastWriteWins(
      List<ConflictingWrite> writes) {
    // Ordenar por timestamp y devolver el más reciente
    writes.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return writes.first;
  }

  bool _validateLastWriteWinsResolution(
      List<ConflictingWrite> writes, ConflictingWrite winner) {
    // Verificar que el ganador tiene el timestamp más reciente
    for (final write in writes) {
      if (write != winner && write.timestamp.isAfter(winner.timestamp)) {
        developer.log(
            'Resolución incorrecta: ${write.deviceId} tiene timestamp más reciente que el ganador ${winner.deviceId}',
            name: 'ConflictVerifier');
        return false;
      }
    }
    return true;
  }

  Future<Map<String, dynamic>> _generateTestData(
      String entityType, String entityId, int deviceIndex) async {
    final baseTime = DateTime.now();

    switch (entityType) {
      case 'user_watchlist':
        return {
          'id': entityId,
          'user_id': 'test_user',
          'movie_id': 550 + deviceIndex,
          'movie_title': 'Test Movie $deviceIndex',
          'priority': ['alta', 'media', 'baja'][deviceIndex % 3],
          'added_at': baseTime
              .subtract(Duration(minutes: deviceIndex))
              .toIso8601String(),
          'updated_at': baseTime
              .add(Duration(milliseconds: deviceIndex * 10))
              .toIso8601String(),
          'device_origin': 'device_$deviceIndex',
        };

      case 'user_movie_ratings':
        return {
          'id': entityId,
          'user_id': 'test_user',
          'movie_id': 550 + deviceIndex,
          'rating': (3.0 + deviceIndex * 0.5).clamp(1.0, 5.0),
          'review': 'Test review from device $deviceIndex',
          'created_at': baseTime
              .subtract(Duration(minutes: deviceIndex))
              .toIso8601String(),
          'updated_at': baseTime
              .add(Duration(milliseconds: deviceIndex * 10))
              .toIso8601String(),
          'device_origin': 'device_$deviceIndex',
        };

      default:
        throw ArgumentError('Tipo de entidad no soportado: $entityType');
    }
  }

  void _addConflictLog(ConflictLog log) {
    _conflictHistory.add(log);

    // Mantener solo los logs más recientes
    while (_conflictHistory.length > _maxConflictHistory) {
      _conflictHistory.removeAt(0);
    }
  }
}

/// Enumeración de estrategias de resolución de conflictos
enum ConflictResolutionStrategy {
  lastWriteWins,
  mergeChanges,
  userResolution,
}

/// Registro de un conflicto detectado y resuelto
class ConflictLog {
  ConflictLog({
    required this.conflictId,
    required this.entityType,
    required this.entityId,
    required this.startTime,
    required this.resolutionTime,
    required this.deviceWrites,
    required this.winnerWrite,
    required this.strategy,
    required this.isResolutionCorrect,
  });
  final String conflictId;
  final String entityType;
  final String entityId;
  final DateTime startTime;
  final Duration resolutionTime;
  final List<ConflictingWrite> deviceWrites;
  final ConflictingWrite winnerWrite;
  final ConflictResolutionStrategy strategy;
  final bool isResolutionCorrect;

  DateTime get endTime => startTime.add(resolutionTime);
}

/// Representa una escritura conflictiva desde un dispositivo
class ConflictingWrite {
  ConflictingWrite({
    required this.deviceId,
    required this.entityType,
    required this.entityId,
    required this.timestamp,
    required this.data,
  });
  final String deviceId;
  final String entityType;
  final String entityId;
  final DateTime timestamp;
  final Map<String, dynamic> data;
}

/// Resultado de una simulación de conflicto
class ConflictSimulationResult {
  ConflictSimulationResult({
    required this.conflictId,
    required this.success,
    required this.resolutionTime,
    required this.totalWrites,
    this.winnerDeviceId,
    this.conflictLog,
    this.error,
  });
  final String conflictId;
  final bool success;
  final Duration resolutionTime;
  final int totalWrites;
  final String? winnerDeviceId;
  final ConflictLog? conflictLog;
  final String? error;
}

/// Resultado de una suite completa de tests de conflictos
class ConflictTestSuiteResult {
  ConflictTestSuiteResult({
    required this.startTime,
    required this.totalTime,
    required this.totalTests,
    required this.successfulTests,
    required this.failedTests,
    required this.testResults,
  });
  final DateTime startTime;
  final Duration totalTime;
  final int totalTests;
  final int successfulTests;
  final int failedTests;
  final List<ConflictSimulationResult> testResults;

  double get successRate => totalTests > 0 ? successfulTests / totalTests : 0.0;
}

/// Estadísticas de resolución de conflictos
class ConflictResolutionStats {
  ConflictResolutionStats({
    required this.totalConflicts,
    required this.resolvedConflicts,
    required this.averageResolutionTime,
    required this.successRate,
    required this.conflictsByEntity,
  });
  final int totalConflicts;
  final int resolvedConflicts;
  final Duration averageResolutionTime;
  final double successRate;
  final Map<String, int> conflictsByEntity;
}
