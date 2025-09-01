import '../../core/sync/conflict_resolution/conflict_detector.dart';
import '../../core/sync/conflict_resolution/soft_delete_manager.dart';
import '../../core/sync/conflict_resolution/multiplatform_conflict_resolver.dart';

// ConflictSeverity is imported from multiplatform_conflict_resolver.dart

/// Información extendida sobre un conflicto con clasificación de severidad
class ClassifiedConflictInfo<T extends SoftDeletable> extends ConflictInfo<T> {
  // 0.0 - 1.0

  ClassifiedConflictInfo({
    required super.localItem,
    required super.remoteItem,
    required super.type,
    required super.severity,
    required super.description,
    super.metadata = const {},
    required super.detectedAt,
    required this.severityReason,
    required this.riskFactors,
    required this.requiresUserIntervention,
    required this.dataLossRisk,
  });
  final String severityReason;
  final List<String> riskFactors;
  final bool requiresUserIntervention;
  final double dataLossRisk;

  @override
  String toString() {
    return 'ClassifiedConflictInfo('
        'type: $type, '
        'severity: $severity, '
        'dataLossRisk: ${(dataLossRisk * 100).toStringAsFixed(1)}%, '
        'reason: $severityReason'
        ')';
  }
}

/// Clasificador de severidad de conflictos
class ConflictSeverityClassifier {
  /// Clasifica un conflicto según su severidad y riesgo
  static ClassifiedConflictInfo<T> classify<T extends SoftDeletable>(
    ConflictInfo<T> conflict,
  ) {
    final analysis = _analyzeConflict(conflict);

    return ClassifiedConflictInfo<T>(
      localItem: conflict.localItem,
      remoteItem: conflict.remoteItem,
      type: conflict.type,
      severity: analysis.severity,
      description: analysis.reason,
      metadata: conflict.metadata,
      detectedAt: conflict.detectedAt,
      severityReason: analysis.reason,
      riskFactors: analysis.riskFactors,
      requiresUserIntervention: analysis.requiresUserIntervention,
      dataLossRisk: analysis.dataLossRisk,
    );
  }

  /// Analiza un conflicto para determinar su severidad
  static _ConflictAnalysis _analyzeConflict<T extends SoftDeletable>(
    ConflictInfo<T> conflict,
  ) {
    final riskFactors = <String>[];
    double dataLossRisk = 0.0;
    ConflictSeverity severity = ConflictSeverity.low;
    String reason = 'Conflicto estándar';
    bool requiresUserIntervention = false;

    // Análisis por tipo de conflicto
    switch (conflict.type) {
      case ConflictType.modificationVsDeletion:
        severity = ConflictSeverity.high;
        reason = 'Modificación vs eliminación - riesgo de pérdida de datos';
        dataLossRisk = 0.8;
        riskFactors.addAll([
          'Posible pérdida de modificaciones recientes',
          'Conflicto entre intención de preservar vs eliminar',
        ]);
        requiresUserIntervention = _isComplexModification(conflict);
        break;

      case ConflictType.deletionVsModification:
        severity = ConflictSeverity.high;
        reason = 'Eliminación vs modificación - decisión crítica';
        dataLossRisk = 0.7;
        riskFactors.addAll([
          'Eliminación puede ser intencional',
          'Modificación puede contener datos valiosos',
        ]);
        requiresUserIntervention = _hasSignificantChanges(conflict);
        break;

      case ConflictType.simultaneousModification:
        final timeDiff = _getTimeDifference(conflict);
        if (timeDiff.inMinutes < 5) {
          severity = ConflictSeverity.high;
          reason = 'Modificaciones concurrentes muy cercanas en tiempo';
          dataLossRisk = 0.9;
          riskFactors.add('Modificaciones casi simultáneas');
          requiresUserIntervention = true;
        } else if (timeDiff.inHours < 1) {
          severity = ConflictSeverity.high;
          reason = 'Modificaciones concurrentes en la misma hora';
          dataLossRisk = 0.6;
        } else {
          severity = ConflictSeverity.medium;
          reason = 'Modificaciones concurrentes con diferencia temporal';
          dataLossRisk = 0.3;
        }
        break;

      case ConflictType.simultaneousAddition:
        severity = ConflictSeverity.medium;
        reason = 'Creación duplicada - merge posible';
        dataLossRisk = 0.2;
        riskFactors.add('Posible duplicación de esfuerzo');
        break;

      case ConflictType.listConflict:
        severity = ConflictSeverity.medium;
        reason = 'Conflicto en lista - requiere merge';
        dataLossRisk = 0.4;
        break;
    }

    // Factores adicionales de riesgo
    _analyzeAdditionalRiskFactors(conflict, riskFactors, severity);

    // Ajustar severidad basada en factores de riesgo
    if (riskFactors.length > 3) {
      severity = _escalateSeverity(severity);
      dataLossRisk = (dataLossRisk * 1.2).clamp(0.0, 1.0);
    }

    return _ConflictAnalysis(
      severity: severity,
      reason: reason,
      riskFactors: riskFactors,
      requiresUserIntervention: requiresUserIntervention,
      dataLossRisk: dataLossRisk,
    );
  }

  /// Verifica si es una modificación compleja
  static bool _isComplexModification<T extends SoftDeletable>(
    ConflictInfo<T> conflict,
  ) {
    // Lógica específica por tipo de entidad
    // Por ahora, consideramos compleja si hay diferencias significativas
    return _hasSignificantChanges(conflict);
  }

  /// Verifica si hay cambios significativos entre versiones
  static bool _hasSignificantChanges<T extends SoftDeletable>(
    ConflictInfo<T> conflict,
  ) {
    final timeDiff = conflict.localItem.updatedAt
        .difference(conflict.remoteItem.updatedAt)
        .abs();

    return timeDiff.inMinutes > 30; // Cambios con más de 30 min de diferencia
  }

  /// Obtiene la diferencia temporal entre modificaciones
  static Duration _getTimeDifference<T extends SoftDeletable>(
    ConflictInfo<T> conflict,
  ) {
    return conflict.localItem.updatedAt
        .difference(conflict.remoteItem.updatedAt)
        .abs();
  }

  /// Analiza factores adicionales de riesgo
  static void _analyzeAdditionalRiskFactors<T extends SoftDeletable>(
    ConflictInfo<T> conflict,
    List<String> riskFactors,
    ConflictSeverity currentSeverity,
  ) {
    // Factor: Elementos eliminados lógicamente
    if (conflict.localItem.isDeleted == true ||
        conflict.remoteItem.isDeleted == true) {
      riskFactors.add('Involucra elementos eliminados lógicamente');
    }

    // Factor: Conflicto en entidad crítica
    if (_isCriticalEntity(T.toString())) {
      riskFactors.add('Entidad crítica para el usuario');
    }

    // Factor: Conflicto recurrente
    if (_isRecurringConflict(conflict)) {
      riskFactors.add('Patrón de conflictos recurrentes detectado');
    }

    // Factor: Datos de usuario únicos
    if (_containsUniqueUserData(conflict)) {
      riskFactors.add('Contiene datos únicos del usuario');
    }
  }

  /// Verifica si es una entidad crítica
  static bool _isCriticalEntity(String entityType) {
    const criticalEntities = {
      'CustomList',
      'UserProfile',
      'Settings',
    };
    return criticalEntities.contains(entityType);
  }

  /// Verifica si es un conflicto recurrente (simplificado)
  static bool _isRecurringConflict<T extends SoftDeletable>(
    ConflictInfo<T> conflict,
  ) {
    // En una implementación real, esto consultaría un historial
    // Por ahora, asumimos false
    return false;
  }

  /// Verifica si contiene datos únicos del usuario
  static bool _containsUniqueUserData<T extends SoftDeletable>(
    ConflictInfo<T> conflict,
  ) {
    // Lógica específica por tipo de entidad
    // Por ahora, asumimos que las listas personalizadas son únicas
    return T.toString().contains('CustomList');
  }

  /// Escala la severidad al siguiente nivel
  static ConflictSeverity _escalateSeverity(ConflictSeverity current) {
    switch (current) {
      case ConflictSeverity.low:
        return ConflictSeverity.medium;
      case ConflictSeverity.medium:
        return ConflictSeverity.high;
      case ConflictSeverity.high:
        return ConflictSeverity.high; // Ya es máximo
    }
  }
}

/// Resultado del análisis de conflicto
class _ConflictAnalysis {
  _ConflictAnalysis({
    required this.severity,
    required this.reason,
    required this.riskFactors,
    required this.requiresUserIntervention,
    required this.dataLossRisk,
  });
  final ConflictSeverity severity;
  final String reason;
  final List<String> riskFactors;
  final bool requiresUserIntervention;
  final double dataLossRisk;
}
