import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Tipos de conflictos que pueden ocurrir entre dispositivos
enum ConflictType {
  /// Modificación vs Eliminación - La eliminación siempre gana
  modificationVsDeletion,

  /// Adición simultánea del mismo elemento
  simultaneousAddition,

  /// Modificación simultánea con diferentes timestamps
  simultaneousModification,

  /// Eliminación vs Modificación - La eliminación siempre gana
  deletionVsModification,

  /// Conflicto en listas personalizadas (orden, items)
  listConflict,
}

/// Severidad del conflicto para logging y métricas
enum ConflictSeverity {
  low, // Conflictos automáticamente resolubles
  medium, // Requieren lógica específica pero no pierden datos
  high, // Pueden resultar en pérdida de datos si no se manejan correctamente
}

/// Resultado de la resolución de conflictos
class ConflictResolutionResult<T> {
  const ConflictResolutionResult({
    required this.resolvedItem,
    required this.conflictType,
    required this.severity,
    required this.resolution,
    required this.description,
    required this.requiresManualIntervention,
    this.dataLoss = false,
    required this.resolvedAt,
  });
  final T resolvedItem;
  final ConflictType conflictType;
  final ConflictSeverity severity;
  final String resolution;
  final String description;
  final bool requiresManualIntervention;
  final bool dataLoss;
  final DateTime resolvedAt;

  Map<String, dynamic> toJson() => {
        'conflictType': conflictType.name,
        'severity': severity.name,
        'resolution': resolution,
        'description': description,
        'requiresManualIntervention': requiresManualIntervention,
        'dataLoss': dataLoss,
        'resolvedAt': resolvedAt.toIso8601String(),
      };
}

/// Interfaz para estrategias de resolución específicas por entidad
abstract class ConflictResolutionStrategy<T> {
  ConflictResolutionResult<T> resolveConflict(
    T localItem,
    T remoteItem,
    ConflictType conflictType,
  );
}

/// Clase principal para resolución de conflictos multiplataforma
class MultiplataformConflictResolver {
  static const String _logTag = 'ConflictResolver';

  final Map<Type, dynamic> _strategies = {};
  final List<ConflictResolutionResult> _resolutionHistory = [];

  /// Registra una estrategia de resolución para un tipo específico
  void registerStrategy<T>(ConflictResolutionStrategy<T> strategy) {
    _strategies[T] = strategy;
    developer.log(
      'Registered conflict resolution strategy for type: $T',
      name: _logTag,
    );
  }

  /// Resuelve un conflicto entre un item local y remoto
  ConflictResolutionResult<T> resolveConflict<T>(
    T localItem,
    T remoteItem,
    ConflictType conflictType,
  ) {
    final strategy = _strategies[T] as ConflictResolutionStrategy<T>?;

    if (strategy == null) {
      throw ArgumentError(
          'No conflict resolution strategy registered for type: $T');
    }

    final result =
        strategy.resolveConflict(localItem, remoteItem, conflictType);

    // Registrar la resolución para métricas
    _resolutionHistory.add(result);

    developer.log(
      'Conflict resolved: ${conflictType.name} -> ${result.resolution}',
      name: _logTag,
    );

    return result;
  }

  /// Detecta el tipo de conflicto basado en los estados de los items
  ConflictType detectConflictType<T>(
    T localItem,
    T remoteItem,
    bool localDeleted,
    bool remoteDeleted,
    DateTime? localTimestamp,
    DateTime? remoteTimestamp,
  ) {
    // Regla 1: Eliminación siempre gana sobre modificación
    if (localDeleted && !remoteDeleted) {
      return ConflictType.deletionVsModification;
    }
    if (!localDeleted && remoteDeleted) {
      return ConflictType.modificationVsDeletion;
    }

    // Si ambos están eliminados, no hay conflicto real
    if (localDeleted && remoteDeleted) {
      return ConflictType
          .simultaneousAddition; // Será manejado como no-conflicto
    }

    // Detectar modificaciones simultáneas
    if (localTimestamp != null && remoteTimestamp != null) {
      final timeDiff = localTimestamp.difference(remoteTimestamp).abs();
      if (timeDiff.inMinutes < 5) {
        // Modificaciones dentro de 5 minutos
        return ConflictType.simultaneousModification;
      }
    }

    return ConflictType.simultaneousAddition;
  }

  /// Obtiene estadísticas de resolución de conflictos
  Map<String, dynamic> getConflictStats() {
    final stats = <String, int>{};
    final severityStats = <String, int>{};
    int dataLossCount = 0;

    for (final resolution in _resolutionHistory) {
      final type = resolution.conflictType.name;
      final severity = resolution.severity.name;

      stats[type] = (stats[type] ?? 0) + 1;
      severityStats[severity] = (severityStats[severity] ?? 0) + 1;

      if (resolution.dataLoss) {
        dataLossCount++;
      }
    }

    return {
      'totalConflicts': _resolutionHistory.length,
      'conflictsByType': stats,
      'conflictsBySeverity': severityStats,
      'dataLossIncidents': dataLossCount,
      'lastResolution': _resolutionHistory.isNotEmpty
          ? _resolutionHistory.last.resolvedAt.toIso8601String()
          : null,
    };
  }

  /// Limpia el historial de resoluciones (para testing)
  @visibleForTesting
  void clearHistory() {
    _resolutionHistory.clear();
  }

  /// Obtiene el historial de resoluciones recientes
  List<ConflictResolutionResult> getRecentResolutions({int limit = 50}) {
    return _resolutionHistory.reversed.take(limit).toList();
  }
}
