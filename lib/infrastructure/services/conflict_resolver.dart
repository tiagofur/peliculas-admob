import '../../domain/entities/sync_models.dart';
import '../../domain/repositories/syncable_repository.dart';

// Clase para resolver conflictos en sincronización bidireccional
class ConflictResolver {
  /// Resuelve conflicto usando timestamp (último cambio gana)
  static T resolveByTimestamp<T extends Timestamped>(T local, T remote) {
    return local.updatedAt.isAfter(remote.updatedAt) ? local : remote;
  }

  /// Combina colecciones locales y remotas resolviendo conflictos por timestamp
  /// ✅ Maneja soft delete correctamente
  static List<T> mergeCollections<T extends SyncableEntity>(
      List<T> local, List<T> remote) {
    final Map<String, T> merged = {};

    // Agregar elementos remotos (incluye los soft-deleted)
    for (final item in remote) {
      merged[item.id] = item;
    }

    // Sobrescribir con elementos locales más recientes
    for (final item in local) {
      final existing = merged[item.id];
      if (existing == null || item.updatedAt.isAfter(existing.updatedAt)) {
        merged[item.id] = item;
      }
    }

    // ✅ Filtrar elementos soft-deleted del resultado final
    // Solo devolver elementos activos para mostrar en la UI
    return merged.values.where((item) => item.isActive).toList();
  }

  /// ✅ Combina colecciones incluyendo soft-deleted (para sincronización interna)
  static List<T> mergeCollectionsWithDeleted<T extends SyncableEntity>(
      List<T> local, List<T> remote) {
    final Map<String, T> merged = {};

    // Agregar elementos remotos
    for (final item in remote) {
      merged[item.id] = item;
    }

    // Sobrescribir con elementos locales más recientes
    for (final item in local) {
      final existing = merged[item.id];
      if (existing == null || item.updatedAt.isAfter(existing.updatedAt)) {
        merged[item.id] = item;
      }
    }

    return merged.values.toList();
  }

  /// Identifica elementos que existen solo localmente
  static List<T> findLocalOnlyItems<T extends Identifiable>(
      List<T> local, List<T> remote) {
    final remoteIds = remote.map((item) => item.id).toSet();
    return local.where((item) => !remoteIds.contains(item.id)).toList();
  }

  /// Identifica elementos que existen solo remotamente
  static List<T> findRemoteOnlyItems<T extends Identifiable>(
      List<T> local, List<T> remote) {
    final localIds = local.map((item) => item.id).toSet();
    return remote.where((item) => !localIds.contains(item.id)).toList();
  }

  /// Identifica elementos que han cambiado localmente
  static List<T> findLocalChanges<T extends SyncableEntity>(
      List<T> local, List<T> remote) {
    final remoteMap = {for (var item in remote) item.id: item};

    return local.where((localItem) {
      final remoteItem = remoteMap[localItem.id];
      return remoteItem == null ||
          localItem.updatedAt.isAfter(remoteItem.updatedAt);
    }).toList();
  }

  /// Identifica elementos que han cambiado remotamente
  static List<T> findRemoteChanges<T extends SyncableEntity>(
      List<T> local, List<T> remote) {
    final localMap = {for (var item in local) item.id: item};

    return remote.where((remoteItem) {
      final localItem = localMap[remoteItem.id];
      return localItem == null ||
          remoteItem.updatedAt.isAfter(localItem.updatedAt);
    }).toList();
  }

  /// Detecta conflictos reales (cambios simultáneos)
  /// ✅ Considera soft delete en la detección de conflictos
  static List<ConflictPair<T>> detectConflicts<T extends SyncableEntity>(
      List<T> local, List<T> remote,
      {Duration conflictWindow = const Duration(seconds: 30)}) {
    final conflicts = <ConflictPair<T>>[];
    final remoteMap = {for (var item in remote) item.id: item};

    for (final localItem in local) {
      final remoteItem = remoteMap[localItem.id];
      if (remoteItem != null) {
        final timeDiff =
            (localItem.updatedAt.difference(remoteItem.updatedAt)).abs();
        if (timeDiff <= conflictWindow &&
            localItem.updatedAt != remoteItem.updatedAt) {
          conflicts.add(ConflictPair(localItem, remoteItem));
        }
      }
    }

    return conflicts;
  }

  /// ✅ Detecta conflictos de eliminación (uno activo, otro eliminado)
  static List<DeletionConflictPair<T>>
      detectDeletionConflicts<T extends SyncableEntity>(
          List<T> local, List<T> remote) {
    final conflicts = <DeletionConflictPair<T>>[];
    final remoteMap = {for (var item in remote) item.id: item};

    for (final localItem in local) {
      final remoteItem = remoteMap[localItem.id];
      if (remoteItem != null) {
        // Conflicto si uno está activo y otro eliminado
        if (localItem.isActive != remoteItem.isActive) {
          conflicts.add(DeletionConflictPair(localItem, remoteItem));
        }
      }
    }

    return conflicts;
  }

  /// ✅ Resuelve conflictos de eliminación (la eliminación más reciente gana)
  static T resolveDeletionConflict<T extends SyncableEntity>(
      T local, T remote) {
    return local.updatedAt.isAfter(remote.updatedAt) ? local : remote;
  }
}

// Representa un par de elementos en conflicto
class ConflictPair<T> {
  ConflictPair(this.local, this.remote);
  final T local;
  final T remote;

  @override
  String toString() => 'ConflictPair(local: $local, remote: $remote)';
}

// ✅ Representa un conflicto de eliminación (uno activo, otro eliminado)
class DeletionConflictPair<T extends SyncableEntity> {
  DeletionConflictPair(this.local, this.remote);
  final T local;
  final T remote;

  bool get localIsDeleted => local.isDeleted;
  bool get remoteIsDeleted => remote.isDeleted;

  @override
  String toString() =>
      'DeletionConflictPair(local: ${local.isDeleted ? "DELETED" : "ACTIVE"}, remote: ${remote.isDeleted ? "DELETED" : "ACTIVE"})';
}

// Estrategias de resolución de conflictos
enum ConflictResolutionStrategy {
  localWins, // Los cambios locales tienen prioridad
  remoteWins, // Los cambios remotos tienen prioridad
  newestWins, // El timestamp más reciente gana
  manual, // Requiere intervención manual
}

// Configuración para resolución de conflictos
class ConflictResolutionConfig {
  const ConflictResolutionConfig({
    this.strategy = ConflictResolutionStrategy.newestWins,
    this.conflictWindow = const Duration(seconds: 30),
    this.autoResolve = true,
  });
  final ConflictResolutionStrategy strategy;
  final Duration conflictWindow;
  final bool autoResolve;
}
