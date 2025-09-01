import 'dart:collection';

import '../../core/sync/conflict_resolution/multiplatform_conflict_resolver.dart';
import '../../core/sync/conflict_resolution/conflict_detector.dart';
import '../../core/sync/conflict_resolution/soft_delete_manager.dart';

/// Estadísticas agregadas de conflictos
class ConflictStatistics {
  ConflictStatistics({
    required this.totalConflicts,
    required this.conflictsByType,
    required this.conflictsBySeverity,
    required this.conflictsByEntity,
    required this.averageResolutionTime,
    required this.averageDataLossRisk,
    required this.conflictsRequiringIntervention,
    required this.periodStart,
    required this.periodEnd,
    required this.detectedPatterns,
  });
  final int totalConflicts;
  final Map<ConflictType, int> conflictsByType;
  final Map<ConflictSeverity, int> conflictsBySeverity;
  final Map<String, int> conflictsByEntity;
  final double averageResolutionTime;
  final double averageDataLossRisk;
  final int conflictsRequiringIntervention;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<ConflictPattern> detectedPatterns;

  /// Obtiene el porcentaje de conflictos por severidad
  Map<ConflictSeverity, double> get severityPercentages {
    if (totalConflicts == 0) return {};

    return conflictsBySeverity.map(
      (severity, count) => MapEntry(severity, (count / totalConflicts) * 100),
    );
  }

  /// Obtiene la entidad más conflictiva
  String? get mostConflictedEntity {
    if (conflictsByEntity.isEmpty) return null;

    return conflictsByEntity.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  @override
  String toString() {
    return 'ConflictStatistics('
        'total: $totalConflicts, '
        'avgRisk: ${(averageDataLossRisk * 100).toStringAsFixed(1)}%, '
        'needIntervention: $conflictsRequiringIntervention, '
        'patterns: ${detectedPatterns.length}'
        ')';
  }
}

/// Patrón de conflictos detectado
class ConflictPattern {
  ConflictPattern({
    required this.patternId,
    required this.description,
    required this.primaryType,
    required this.affectedEntity,
    required this.occurrences,
    required this.confidence,
    required this.suggestedActions,
    required this.firstDetected,
    required this.lastDetected,
  });
  final String patternId;
  final String description;
  final ConflictType primaryType;
  final String affectedEntity;
  final int occurrences;
  final double confidence; // 0.0 - 1.0
  final List<String> suggestedActions;
  final DateTime firstDetected;
  final DateTime lastDetected;

  @override
  String toString() {
    return 'ConflictPattern('
        'id: $patternId, '
        'type: $primaryType, '
        'entity: $affectedEntity, '
        'occurrences: $occurrences, '
        'confidence: ${(confidence * 100).toStringAsFixed(1)}%'
        ')';
  }
}

/// Entrada de historial de conflictos
class ConflictHistoryEntry {
  ConflictHistoryEntry({
    required this.conflictId,
    required this.type,
    required this.severity,
    required this.entityType,
    required this.entityId,
    required this.detectedAt,
    this.resolvedAt,
    this.resolutionStrategy,
    required this.wasAutoResolved,
    required this.dataLossRisk,
    this.resolutionTime,
  });
  final String conflictId;
  final ConflictType type;
  final ConflictSeverity severity;
  final String entityType;
  final String entityId;
  final DateTime detectedAt;
  final DateTime? resolvedAt;
  final String? resolutionStrategy;
  final bool wasAutoResolved;
  final double dataLossRisk;
  final Duration? resolutionTime;

  bool get isResolved => resolvedAt != null;

  @override
  String toString() {
    return 'ConflictHistoryEntry('
        'id: $conflictId, '
        'type: $type, '
        'severity: $severity, '
        'resolved: $isResolved'
        ')';
  }
}

/// Servicio de estadísticas y análisis de conflictos
class ConflictStatisticsService {
  ConflictStatisticsService({int maxHistorySize = 1000})
      : _maxHistorySize = maxHistorySize;
  final Queue<ConflictHistoryEntry> _history = Queue<ConflictHistoryEntry>();
  final Map<String, ConflictPattern> _detectedPatterns = {};
  final int _maxHistorySize;

  /// Registra un conflicto detectado
  void recordConflictDetected<T extends SoftDeletable>(
    ConflictInfo<T> conflict,
  ) {
    final entry = ConflictHistoryEntry(
      conflictId: conflict.localItem.id,
      type: conflict.type,
      severity: conflict.severity,
      entityType: T.toString(),
      entityId: conflict.localItem.id,
      detectedAt: conflict.detectedAt,
      wasAutoResolved: false,
      dataLossRisk: 0.5, // Valor por defecto
    );

    _addToHistory(entry);
    _analyzePatterns();
  }

  /// Registra la resolución de un conflicto
  void recordConflictResolved(
    String conflictId,
    String resolutionStrategy,
    bool wasAutoResolved,
  ) {
    // Buscar la entrada en el historial y actualizarla
    for (int i = _history.length - 1; i >= 0; i--) {
      final entry = _history.elementAt(i);
      if (entry.conflictId == conflictId && !entry.isResolved) {
        final resolvedAt = DateTime.now();
        final resolutionTime = resolvedAt.difference(entry.detectedAt);

        final updatedEntry = ConflictHistoryEntry(
          conflictId: entry.conflictId,
          type: entry.type,
          severity: entry.severity,
          entityType: entry.entityType,
          entityId: entry.entityId,
          detectedAt: entry.detectedAt,
          resolvedAt: resolvedAt,
          resolutionStrategy: resolutionStrategy,
          wasAutoResolved: wasAutoResolved,
          dataLossRisk: entry.dataLossRisk,
          resolutionTime: resolutionTime,
        );

        // Reemplazar la entrada en el historial
        _history.removeWhere((e) => e.conflictId == conflictId);
        _addToHistory(updatedEntry);
        break;
      }
    }
  }

  /// Obtiene estadísticas para un período específico
  ConflictStatistics getStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 30));
    final end = endDate ?? now;

    final filteredHistory = _history.where((entry) =>
        entry.detectedAt.isAfter(start) && entry.detectedAt.isBefore(end));

    if (filteredHistory.isEmpty) {
      return ConflictStatistics(
        totalConflicts: 0,
        conflictsByType: {},
        conflictsBySeverity: {},
        conflictsByEntity: {},
        averageResolutionTime: 0.0,
        averageDataLossRisk: 0.0,
        conflictsRequiringIntervention: 0,
        periodStart: start,
        periodEnd: end,
        detectedPatterns: [],
      );
    }

    final conflictsByType = <ConflictType, int>{};
    final conflictsBySeverity = <ConflictSeverity, int>{};
    final conflictsByEntity = <String, int>{};
    final resolutionTimes = <Duration>[];
    final dataLossRisks = <double>[];
    int conflictsRequiringIntervention = 0;

    for (final entry in filteredHistory) {
      // Contar por tipo
      conflictsByType[entry.type] = (conflictsByType[entry.type] ?? 0) + 1;

      // Contar por severidad
      conflictsBySeverity[entry.severity] =
          (conflictsBySeverity[entry.severity] ?? 0) + 1;

      // Contar por entidad
      conflictsByEntity[entry.entityType] =
          (conflictsByEntity[entry.entityType] ?? 0) + 1;

      // Recopilar tiempos de resolución
      if (entry.resolutionTime != null) {
        resolutionTimes.add(entry.resolutionTime!);
      }

      // Recopilar riesgos de pérdida de datos
      dataLossRisks.add(entry.dataLossRisk);

      // Contar conflictos que requieren intervención
      if (entry.severity == ConflictSeverity.high) {
        conflictsRequiringIntervention++;
      }
    }

    final averageResolutionTime = resolutionTimes.isEmpty
        ? 0.0
        : resolutionTimes.map((d) => d.inMilliseconds).reduce((a, b) => a + b) /
            resolutionTimes.length;

    final averageDataLossRisk = dataLossRisks.isEmpty
        ? 0.0
        : dataLossRisks.reduce((a, b) => a + b) / dataLossRisks.length;

    return ConflictStatistics(
      totalConflicts: filteredHistory.length,
      conflictsByType: conflictsByType,
      conflictsBySeverity: conflictsBySeverity,
      conflictsByEntity: conflictsByEntity,
      averageResolutionTime: averageResolutionTime,
      averageDataLossRisk: averageDataLossRisk,
      conflictsRequiringIntervention: conflictsRequiringIntervention,
      periodStart: start,
      periodEnd: end,
      detectedPatterns: _detectedPatterns.values.toList(),
    );
  }

  /// Obtiene conflictos no resueltos
  List<ConflictHistoryEntry> getUnresolvedConflicts() {
    return _history.where((entry) => !entry.isResolved).toList();
  }

  /// Obtiene el historial completo de conflictos
  List<ConflictHistoryEntry> getHistory({
    int? limit,
    ConflictType? filterByType,
    ConflictSeverity? filterBySeverity,
  }) {
    var filtered = _history.toList();

    if (filterByType != null) {
      filtered = filtered.where((e) => e.type == filterByType).toList();
    }

    if (filterBySeverity != null) {
      filtered = filtered.where((e) => e.severity == filterBySeverity).toList();
    }

    // Ordenar por fecha de detección (más reciente primero)
    filtered.sort((a, b) => b.detectedAt.compareTo(a.detectedAt));

    if (limit != null && limit < filtered.length) {
      filtered = filtered.take(limit).toList();
    }

    return filtered;
  }

  /// Limpia el historial antiguo
  void cleanupOldHistory({Duration? olderThan}) {
    final cutoff =
        DateTime.now().subtract(olderThan ?? const Duration(days: 90));
    _history.removeWhere((entry) => entry.detectedAt.isBefore(cutoff));
  }

  /// Agrega una entrada al historial
  void _addToHistory(ConflictHistoryEntry entry) {
    _history.add(entry);

    // Mantener el tamaño máximo del historial
    while (_history.length > _maxHistorySize) {
      _history.removeFirst();
    }
  }

  /// Analiza patrones en el historial de conflictos
  void _analyzePatterns() {
    // Análisis simplificado de patrones
    final recentHistory = _history
        .where((e) => e.detectedAt
            .isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .toList();

    if (recentHistory.length < 3) return;

    // Detectar patrones por entidad y tipo
    final entityTypePatterns = <String, List<ConflictHistoryEntry>>{};

    for (final entry in recentHistory) {
      final key = '${entry.entityType}_${entry.type.toString()}';
      entityTypePatterns.putIfAbsent(key, () => []).add(entry);
    }

    // Identificar patrones significativos
    for (final entry in entityTypePatterns.entries) {
      final key = entry.key;
      final conflicts = entry.value;

      if (conflicts.length >= 3) {
        final pattern = ConflictPattern(
          patternId: 'pattern_$key',
          description:
              'Conflictos recurrentes en ${conflicts.first.entityType}',
          primaryType: conflicts.first.type,
          affectedEntity: conflicts.first.entityType,
          occurrences: conflicts.length,
          confidence: (conflicts.length / recentHistory.length).clamp(0.0, 1.0),
          suggestedActions: _generateSuggestions(conflicts),
          firstDetected: conflicts
              .map((c) => c.detectedAt)
              .reduce((a, b) => a.isBefore(b) ? a : b),
          lastDetected: conflicts
              .map((c) => c.detectedAt)
              .reduce((a, b) => a.isAfter(b) ? a : b),
        );

        _detectedPatterns[pattern.patternId] = pattern;
      }
    }
  }

  /// Analiza y retorna patrones detectados en los conflictos
  List<ConflictPattern> analyzePatterns() {
    _analyzePatterns();
    return _detectedPatterns.values.toList();
  }

  /// Genera sugerencias basadas en patrones de conflictos
  List<String> _generateSuggestions(List<ConflictHistoryEntry> conflicts) {
    final suggestions = <String>[];

    final primaryType = conflicts.first.type;
    final entityType = conflicts.first.entityType;

    switch (primaryType) {
      case ConflictType.simultaneousModification:
        suggestions.addAll([
          'Considerar implementar bloqueo optimista',
          'Mejorar la sincronización en tiempo real',
          'Educar usuarios sobre colaboración simultánea',
        ]);
        break;

      case ConflictType.modificationVsDeletion:
        suggestions.addAll([
          'Implementar confirmación antes de eliminar',
          'Mejorar la visibilidad de elementos modificados',
          'Considerar papelera de reciclaje temporal',
        ]);
        break;

      case ConflictType.simultaneousAddition:
        suggestions.addAll([
          'Mejorar detección de duplicados',
          'Implementar sugerencias de elementos existentes',
          'Optimizar sincronización de creación',
        ]);
        break;

      default:
        suggestions.add('Revisar lógica de sincronización para $entityType');
    }

    return suggestions;
  }
}
