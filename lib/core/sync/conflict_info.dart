import '../../domain/entities/syncable_entity.dart';

/// Información de conflicto detectado
class ConflictInfo<T extends SyncableEntity> {
  const ConflictInfo({
    required this.localEntity,
    required this.remoteEntity,
    required this.conflictType,
    required this.detectedAt,
    this.resolution,
    this.metadata,
  });

  final T localEntity;
  final T remoteEntity;
  final ConflictType conflictType;
  final DateTime detectedAt;
  final ConflictResolution? resolution;
  final Map<String, dynamic>? metadata;

  bool get isResolved => resolution != null;

  String get conflictDescription {
    switch (conflictType) {
      case ConflictType.concurrentModification:
        return 'Both local and remote entities were modified';
      case ConflictType.deleteVsModify:
        return 'One version deleted while other was modified';
      case ConflictType.duplicateCreation:
        return 'Same entity created on multiple devices';
    }
  }
}

/// Tipos de conflicto
enum ConflictType {
  concurrentModification,
  deleteVsModify,
  duplicateCreation,
}

/// Resolución de conflicto
class ConflictResolution {
  const ConflictResolution({
    required this.type,
    this.userChoice,
    this.mergedData,
    required this.resolvedAt,
    required this.resolvedBy,
  });
  final ConflictType type;
  final String? userChoice;
  final Map<String, dynamic>? mergedData;
  final DateTime resolvedAt;
  final String resolvedBy;
}

enum ConflictStrategy {
  serverWins,
  clientWins,
  userChoice,
}
