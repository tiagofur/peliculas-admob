import 'dart:developer' as developer;

import '../../../infrastructure/sync/conflict_severity_classifier.dart';
import '../../../infrastructure/sync/conflict_statistics_service.dart';
import 'multiplatform_conflict_resolver.dart';
import 'soft_delete_manager.dart';

/// Información detallada sobre un conflicto detectado
class ConflictInfo<T> {
  const ConflictInfo({
    required this.localItem,
    required this.remoteItem,
    required this.type,
    required this.severity,
    required this.description,
    this.metadata = const {},
    required this.detectedAt,
  });
  final T localItem;
  final T remoteItem;
  final ConflictType type;
  final ConflictSeverity severity;
  final String description;
  final Map<String, dynamic> metadata;
  final DateTime detectedAt;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'severity': severity.name,
        'description': description,
        'metadata': metadata,
        'detectedAt': detectedAt.toIso8601String(),
      };
}

/// Estadísticas de detección de conflictos
class ConflictDetectionStats {
  const ConflictDetectionStats({
    required this.totalConflictsDetected,
    required this.conflictsByType,
    required this.conflictsBySeverity,
    required this.autoResolvableConflicts,
    required this.manualInterventionRequired,
    required this.lastDetection,
  });
  final int totalConflictsDetected;
  final Map<ConflictType, int> conflictsByType;
  final Map<ConflictSeverity, int> conflictsBySeverity;
  final int autoResolvableConflicts;
  final int manualInterventionRequired;
  final DateTime lastDetection;

  Map<String, dynamic> toJson() => {
        'totalConflictsDetected': totalConflictsDetected,
        'conflictsByType': conflictsByType.map((k, v) => MapEntry(k.name, v)),
        'conflictsBySeverity':
            conflictsBySeverity.map((k, v) => MapEntry(k.name, v)),
        'autoResolvableConflicts': autoResolvableConflicts,
        'manualInterventionRequired': manualInterventionRequired,
        'lastDetection': lastDetection.toIso8601String(),
      };
}

/// Detector de conflictos entre items locales y remotos
class ConflictDetector {
  ConflictDetector(
    this._softDeleteManager,
    this._statisticsService,
  );
  static const String _logTag = 'ConflictDetector';

  final SoftDeleteManager _softDeleteManager;
  final ConflictStatisticsService _statisticsService;
  final List<ConflictInfo> _detectionHistory = [];

  /// Detecta conflictos entre un item local y remoto
  ConflictInfo<T>? detectConflict<T extends SoftDeletable>(
    T localItem,
    T remoteItem,
  ) {
    if (localItem.id != remoteItem.id) {
      throw ArgumentError('Items must have the same ID for conflict detection');
    }

    final now = DateTime.now();

    // Verificar si hay conflicto real
    final conflictType = _determineConflictType(localItem, remoteItem);
    if (conflictType == null) {
      return null; // No hay conflicto
    }

    // Usar el clasificador de severidad avanzado
    final classifiedConflict = ConflictSeverityClassifier.classify(
      ConflictInfo<T>(
        localItem: localItem,
        remoteItem: remoteItem,
        type: conflictType,
        severity:
            ConflictSeverity.medium, // Placeholder, will be set by classifier
        description: '', // Placeholder, will be set by classifier
        detectedAt: now,
      ),
    );

    final conflictInfo = ConflictInfo<T>(
      localItem: localItem,
      remoteItem: remoteItem,
      type: conflictType,
      severity: classifiedConflict.severity,
      description: classifiedConflict.description,
      metadata: classifiedConflict.metadata,
      detectedAt: now,
    );

    _detectionHistory.add(conflictInfo);

    // Registrar en el servicio de estadísticas
    _statisticsService.recordConflictDetected<T>(conflictInfo);

    developer.log(
      'Conflict detected: ${conflictType.name} (${classifiedConflict.severity.name}) for item ${localItem.id}',
      name: _logTag,
    );

    return conflictInfo;
  }

  /// Detecta conflictos entre listas de items locales y remotos
  List<ConflictInfo<T>> detectConflicts<T extends SoftDeletable>(
    List<T> localItems,
    List<T> remoteItems,
  ) {
    return detectBatchConflicts(localItems, remoteItems);
  }

  /// Detecta conflictos en lotes para múltiples items
  List<ConflictInfo<T>> detectBatchConflicts<T extends SoftDeletable>(
    List<T> localItems,
    List<T> remoteItems,
  ) {
    final conflicts = <ConflictInfo<T>>[];
    final remoteMap = {for (final item in remoteItems) item.id: item};

    // Detectar conflictos en items que existen en ambos lados
    for (final localItem in localItems) {
      final remoteItem = remoteMap[localItem.id];
      if (remoteItem != null) {
        final conflict = detectConflict(localItem, remoteItem);
        if (conflict != null) {
          conflicts.add(conflict);
        }
      }
    }

    developer.log(
      'Batch conflict detection: ${conflicts.length} conflicts found in ${localItems.length} local and ${remoteItems.length} remote items',
      name: _logTag,
    );

    return conflicts;
  }

  /// Determina el tipo de conflicto entre dos items
  ConflictType? _determineConflictType<T extends SoftDeletable>(
    T localItem,
    T remoteItem,
  ) {
    final localDeleted = localItem.isDeleted;
    final remoteDeleted = remoteItem.isDeleted;

    // Caso 1: Eliminación vs Modificación
    if (localDeleted && !remoteDeleted) {
      // Verificar si la eliminación local es posterior a la modificación remota
      final localDeletedAt = _softDeleteManager.getDeletionDate(localItem.id) ??
          localItem.updatedAt;
      if (localDeletedAt.isAfter(remoteItem.updatedAt)) {
        return ConflictType.deletionVsModification;
      }
    }

    if (!localDeleted && remoteDeleted) {
      // Verificar si la eliminación remota es posterior a la modificación local
      if (remoteItem.updatedAt.isAfter(localItem.updatedAt)) {
        return ConflictType.modificationVsDeletion;
      }
    }

    // Caso 2: Ambos eliminados - no hay conflicto real
    if (localDeleted && remoteDeleted) {
      return null;
    }

    // Caso 3: Modificaciones simultáneas
    if (!localDeleted && !remoteDeleted) {
      final timeDiff =
          localItem.updatedAt.difference(remoteItem.updatedAt).abs();

      // Si las modificaciones son muy cercanas en tiempo (menos de 5 minutos)
      if (timeDiff.inMinutes < 5) {
        return ConflictType.simultaneousModification;
      }

      // Si los timestamps son diferentes pero no hay cambios reales
      if (_areItemsEquivalent(localItem, remoteItem)) {
        return null; // No hay conflicto real
      }

      // Modificaciones en diferentes momentos
      return ConflictType.simultaneousModification;
    }

    return null;
  }

  /// Método auxiliar para obtener estadísticas del servicio de estadísticas
  ConflictStatistics getConflictStatistics({DateTime? since}) {
    return _statisticsService.getStatistics(startDate: since);
  }

  /// Obtiene patrones de conflictos detectados
  List<ConflictPattern> getConflictPatterns() {
    return _statisticsService.analyzePatterns();
  }

  /// Obtiene conflictos no resueltos
  List<ConflictHistoryEntry> getUnresolvedConflicts() {
    return _statisticsService.getUnresolvedConflicts();
  }

  /// Verifica si dos items son equivalentes (mismo estado final)
  bool _areItemsEquivalent<T extends SoftDeletable>(T item1, T item2) {
    // Implementación básica - puede ser sobrescrita por tipos específicos
    return item1.isDeleted == item2.isDeleted;
  }

  /// Obtiene estadísticas de detección de conflictos
  ConflictDetectionStats getDetectionStats() {
    final stats = _statisticsService.getStatistics();

    return ConflictDetectionStats(
      totalConflictsDetected: stats.totalConflicts,
      conflictsByType: stats.conflictsByType,
      conflictsBySeverity: stats.conflictsBySeverity,
      autoResolvableConflicts: 0, // Not tracked
      manualInterventionRequired: stats.conflictsRequiringIntervention,
      lastDetection: stats.periodEnd,
    );
  }

  /// Obtiene conflictos recientes
  List<ConflictInfo> getRecentConflicts({int limit = 50}) {
    return _detectionHistory.reversed.take(limit).toList();
  }

  /// Limpia el historial de detección (para testing)
  void clearHistory() {
    _detectionHistory.clear();
  }
}
