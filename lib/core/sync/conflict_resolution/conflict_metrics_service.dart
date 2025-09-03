import 'dart:convert';
import 'dart:developer' as developer;

import 'conflict_detector.dart';
import 'multiplatform_conflict_resolver.dart';

/// Métricas detalladas de conflictos por sesión
class ConflictSessionMetrics {
  const ConflictSessionMetrics({
    required this.sessionId,
    required this.startTime,
    required this.endTime,
    required this.totalConflictsDetected,
    required this.totalConflictsResolved,
    required this.autoResolvedConflicts,
    required this.manualInterventionRequired,
    required this.conflictsByType,
    required this.conflictsBySeverity,
    required this.conflictsByEntity,
    required this.resolutionLogs,
    required this.averageResolutionTime,
    required this.totalResolutionTime,
  });
  final String sessionId;
  final DateTime startTime;
  final DateTime endTime;
  final int totalConflictsDetected;
  final int totalConflictsResolved;
  final int autoResolvedConflicts;
  final int manualInterventionRequired;
  final Map<ConflictType, int> conflictsByType;
  final Map<ConflictSeverity, int> conflictsBySeverity;
  final Map<String, int> conflictsByEntity;
  final List<ConflictResolutionLog> resolutionLogs;
  final Duration averageResolutionTime;
  final Duration totalResolutionTime;

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'totalConflictsDetected': totalConflictsDetected,
        'totalConflictsResolved': totalConflictsResolved,
        'autoResolvedConflicts': autoResolvedConflicts,
        'manualInterventionRequired': manualInterventionRequired,
        'conflictsByType': conflictsByType.map((k, v) => MapEntry(k.name, v)),
        'conflictsBySeverity':
            conflictsBySeverity.map((k, v) => MapEntry(k.name, v)),
        'conflictsByEntity': conflictsByEntity,
        'resolutionLogs': resolutionLogs.map((log) => log.toJson()).toList(),
        'averageResolutionTimeMs': averageResolutionTime.inMilliseconds,
        'totalResolutionTimeMs': totalResolutionTime.inMilliseconds,
      };
}

/// Log detallado de una resolución de conflicto
class ConflictResolutionLog {
  const ConflictResolutionLog({
    required this.conflictId,
    required this.entityType,
    required this.entityId,
    required this.conflictType,
    required this.severity,
    required this.detectedAt,
    required this.resolvedAt,
    required this.resolutionTime,
    required this.resolutionStrategy,
    required this.resolutionDescription,
    required this.requiresManualIntervention,
    required this.beforeState,
    required this.afterState,
    this.metadata = const {},
  });
  final String conflictId;
  final String entityType;
  final String entityId;
  final ConflictType conflictType;
  final ConflictSeverity severity;
  final DateTime detectedAt;
  final DateTime resolvedAt;
  final Duration resolutionTime;
  final String resolutionStrategy;
  final String resolutionDescription;
  final bool requiresManualIntervention;
  final Map<String, dynamic> beforeState;
  final Map<String, dynamic> afterState;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
        'conflictId': conflictId,
        'entityType': entityType,
        'entityId': entityId,
        'conflictType': conflictType.name,
        'severity': severity.name,
        'detectedAt': detectedAt.toIso8601String(),
        'resolvedAt': resolvedAt.toIso8601String(),
        'resolutionTimeMs': resolutionTime.inMilliseconds,
        'resolutionStrategy': resolutionStrategy,
        'resolutionDescription': resolutionDescription,
        'requiresManualIntervention': requiresManualIntervention,
        'beforeState': beforeState,
        'afterState': afterState,
        'metadata': metadata,
      };
}

/// Servicio para métricas y logging detallado de conflictos
class ConflictMetricsService {
  static const String _logTag = 'ConflictMetrics';

  final List<ConflictResolutionLog> _resolutionHistory = [];
  final Map<String, DateTime> _activeConflicts = {};
  String? _currentSessionId;
  DateTime? _sessionStartTime;

  /// Inicia una nueva sesión de métricas
  void startSession([String? sessionId]) {
    _currentSessionId = sessionId ?? _generateSessionId();
    _sessionStartTime = DateTime.now();

    developer.log(
      'Started conflict metrics session: $_currentSessionId',
      name: _logTag,
    );
  }

  /// Registra la detección de un conflicto
  void logConflictDetected<T>(
    ConflictInfo<T> conflict, {
    Map<String, dynamic>? additionalMetadata,
  }) {
    final conflictId = _generateConflictId(conflict);
    _activeConflicts[conflictId] = conflict.detectedAt;

    final logData = {
      'sessionId': _currentSessionId,
      'conflictId': conflictId,
      'entityType': T.toString(),
      'entityId': _getEntityId(conflict.localItem),
      'conflictType': conflict.type.name,
      'severity': conflict.severity.name,
      'description': conflict.description,
      'detectedAt': conflict.detectedAt.toIso8601String(),
      'metadata': {
        ...conflict.metadata,
        if (additionalMetadata != null) ...additionalMetadata,
      },
    };

    developer.log(
      'Conflict detected: ${jsonEncode(logData)}',
      name: _logTag,
    );
  }

  /// Registra la resolución de un conflicto
  void logConflictResolved<T>(
    ConflictInfo<T> conflict,
    ConflictResolutionResult<T> resolution, {
    Map<String, dynamic>? beforeState,
    Map<String, dynamic>? afterState,
    Map<String, dynamic>? additionalMetadata,
  }) {
    final conflictId = _generateConflictId(conflict);
    final detectedAt = _activeConflicts[conflictId] ?? conflict.detectedAt;
    final resolvedAt = DateTime.now();
    final resolutionTime = resolvedAt.difference(detectedAt);

    final resolutionLog = ConflictResolutionLog(
      conflictId: conflictId,
      entityType: T.toString(),
      entityId: _getEntityId(conflict.localItem),
      conflictType: conflict.type,
      severity: conflict.severity,
      detectedAt: detectedAt,
      resolvedAt: resolvedAt,
      resolutionTime: resolutionTime,
      resolutionStrategy: resolution.resolution,
      resolutionDescription: resolution.description,
      requiresManualIntervention: resolution.requiresManualIntervention,
      beforeState: beforeState ?? {},
      afterState: afterState ?? {},
      metadata: {
        ...conflict.metadata,
        if (additionalMetadata != null) ...additionalMetadata,
      },
    );

    _resolutionHistory.add(resolutionLog);
    _activeConflicts.remove(conflictId);

    developer.log(
      'Conflict resolved: ${jsonEncode(resolutionLog.toJson())}',
      name: _logTag,
    );
  }

  /// Registra un error en la resolución de conflictos
  void logConflictResolutionError<T>(
    ConflictInfo<T> conflict,
    Object error,
    StackTrace stackTrace, {
    Map<String, dynamic>? additionalMetadata,
  }) {
    final conflictId = _generateConflictId(conflict);

    final errorData = {
      'sessionId': _currentSessionId,
      'conflictId': conflictId,
      'entityType': T.toString(),
      'entityId': _getEntityId(conflict.localItem),
      'conflictType': conflict.type.name,
      'severity': conflict.severity.name,
      'error': error.toString(),
      'stackTrace': stackTrace.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'metadata': {
        ...conflict.metadata,
        if (additionalMetadata != null) ...additionalMetadata,
      },
    };

    developer.log(
      'Conflict resolution error: ${jsonEncode(errorData)}',
      name: _logTag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Finaliza la sesión actual y genera métricas
  ConflictSessionMetrics? endSession() {
    if (_currentSessionId == null || _sessionStartTime == null) {
      return null;
    }

    final endTime = DateTime.now();

    // Calcular métricas de la sesión
    final conflictsByType = <ConflictType, int>{};
    final conflictsBySeverity = <ConflictSeverity, int>{};
    final conflictsByEntity = <String, int>{};

    int autoResolved = 0;
    int manualIntervention = 0;
    Duration totalResolutionTime = Duration.zero;

    for (final log in _resolutionHistory) {
      conflictsByType[log.conflictType] =
          (conflictsByType[log.conflictType] ?? 0) + 1;
      conflictsBySeverity[log.severity] =
          (conflictsBySeverity[log.severity] ?? 0) + 1;
      conflictsByEntity[log.entityType] =
          (conflictsByEntity[log.entityType] ?? 0) + 1;

      if (log.requiresManualIntervention) {
        manualIntervention++;
      } else {
        autoResolved++;
      }

      totalResolutionTime += log.resolutionTime;
    }

    final averageResolutionTime = _resolutionHistory.isNotEmpty
        ? Duration(
            milliseconds:
                totalResolutionTime.inMilliseconds ~/ _resolutionHistory.length)
        : Duration.zero;

    final metrics = ConflictSessionMetrics(
      sessionId: _currentSessionId!,
      startTime: _sessionStartTime ?? DateTime.now(),
      endTime: endTime,
      totalConflictsDetected:
          _resolutionHistory.length + _activeConflicts.length,
      totalConflictsResolved: _resolutionHistory.length,
      autoResolvedConflicts: autoResolved,
      manualInterventionRequired: manualIntervention,
      conflictsByType: conflictsByType,
      conflictsBySeverity: conflictsBySeverity,
      conflictsByEntity: conflictsByEntity,
      resolutionLogs: List.from(_resolutionHistory),
      averageResolutionTime: averageResolutionTime,
      totalResolutionTime: totalResolutionTime,
    );

    developer.log(
      'Session ended: ${jsonEncode(metrics.toJson())}',
      name: _logTag,
    );

    // Limpiar estado de la sesión
    _currentSessionId = null;
    _sessionStartTime = null;
    _resolutionHistory.clear();
    _activeConflicts.clear();

    return metrics;
  }

  /// Obtiene métricas de la sesión actual (sin finalizarla)
  ConflictSessionMetrics? getCurrentSessionMetrics() {
    if (_currentSessionId == null || _sessionStartTime == null) {
      return null;
    }

    final now = DateTime.now();

    // Calcular métricas actuales
    final conflictsByType = <ConflictType, int>{};
    final conflictsBySeverity = <ConflictSeverity, int>{};
    final conflictsByEntity = <String, int>{};

    int autoResolved = 0;
    int manualIntervention = 0;
    Duration totalResolutionTime = Duration.zero;

    for (final log in _resolutionHistory) {
      conflictsByType[log.conflictType] =
          (conflictsByType[log.conflictType] ?? 0) + 1;
      conflictsBySeverity[log.severity] =
          (conflictsBySeverity[log.severity] ?? 0) + 1;
      conflictsByEntity[log.entityType] =
          (conflictsByEntity[log.entityType] ?? 0) + 1;

      if (log.requiresManualIntervention) {
        manualIntervention++;
      } else {
        autoResolved++;
      }

      totalResolutionTime += log.resolutionTime;
    }

    final averageResolutionTime = _resolutionHistory.isNotEmpty
        ? Duration(
            milliseconds:
                totalResolutionTime.inMilliseconds ~/ _resolutionHistory.length)
        : Duration.zero;

    return ConflictSessionMetrics(
      sessionId: _currentSessionId!,
      startTime: _sessionStartTime ?? DateTime.now(),
      endTime: now,
      totalConflictsDetected:
          _resolutionHistory.length + _activeConflicts.length,
      totalConflictsResolved: _resolutionHistory.length,
      autoResolvedConflicts: autoResolved,
      manualInterventionRequired: manualIntervention,
      conflictsByType: conflictsByType,
      conflictsBySeverity: conflictsBySeverity,
      conflictsByEntity: conflictsByEntity,
      resolutionLogs: List.from(_resolutionHistory),
      averageResolutionTime: averageResolutionTime,
      totalResolutionTime: totalResolutionTime,
    );
  }

  /// Obtiene logs de resolución recientes
  List<ConflictResolutionLog> getRecentResolutionLogs({int limit = 50}) {
    return _resolutionHistory.reversed.take(limit).toList();
  }

  /// Obtiene conflictos activos (no resueltos)
  Map<String, DateTime> getActiveConflicts() {
    return Map.from(_activeConflicts);
  }

  /// Limpia el historial (para testing)
  void clearHistory() {
    _resolutionHistory.clear();
    _activeConflicts.clear();
  }

  /// Genera un ID único para la sesión
  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'session_$timestamp';
  }

  /// Genera un ID único para el conflicto
  String _generateConflictId<T>(ConflictInfo<T> conflict) {
    final entityId = _getEntityId(conflict.localItem);
    final timestamp = conflict.detectedAt.millisecondsSinceEpoch;
    return 'conflict_${entityId}_$timestamp';
  }

  /// Extrae el ID de la entidad (implementación básica)
  String _getEntityId(dynamic entity) {
    if (entity is Map<String, dynamic> && entity.containsKey('id')) {
      return entity['id'].toString();
    }

    // Intentar usar reflection básica para encontrar un campo 'id'
    try {
      final entityString = entity.toString();
      final idMatch = RegExp(r'id: ([^,)]+)').firstMatch(entityString);
      if (idMatch != null) {
        return idMatch.group(1) ?? 'unknown';
      }
    } catch (e) {
      // Ignorar errores de parsing
    }

    return entity.hashCode.toString();
  }
}
