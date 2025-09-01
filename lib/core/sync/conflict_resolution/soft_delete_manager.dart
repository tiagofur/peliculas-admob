import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Interfaz para entidades que soportan soft delete
abstract class SoftDeletable {
  bool get isDeleted;
  DateTime get updatedAt;
  DateTime get createdAt;
  String get id;

  /// Crea una copia de la entidad marcada como eliminada
  SoftDeletable copyWithDeleted(bool isDeleted, DateTime updatedAt);
}

/// Resultado de una operación de soft delete
class SoftDeleteResult<T extends SoftDeletable> {
  const SoftDeleteResult({
    required this.item,
    required this.wasAlreadyDeleted,
    required this.deletedAt,
    required this.reason,
  });
  final T item;
  final bool wasAlreadyDeleted;
  final DateTime deletedAt;
  final String reason;

  Map<String, dynamic> toJson() => {
        'wasAlreadyDeleted': wasAlreadyDeleted,
        'deletedAt': deletedAt.toIso8601String(),
        'reason': reason,
      };
}

/// Configuración para limpieza automática de items eliminados
class CleanupConfig {
  const CleanupConfig({
    this.retentionPeriod = const Duration(days: 30),
    this.maxDeletedItems = 1000,
    this.enableAutoCleanup = true,
  });
  final Duration retentionPeriod;
  final int maxDeletedItems;
  final bool enableAutoCleanup;
}

/// Manager para manejo consistente de eliminaciones lógicas
class SoftDeleteManager {
  SoftDeleteManager({CleanupConfig? config})
      : _config = config ?? const CleanupConfig();
  static const String _logTag = 'SoftDeleteManager';

  final CleanupConfig _config;
  final Map<String, DateTime> _deletionHistory = {};
  final Map<String, String> _deletionReasons = {};

  /// Marca un item como eliminado (soft delete)
  SoftDeleteResult<T> markAsDeleted<T extends SoftDeletable>(
    T item, {
    String reason = 'User deletion',
  }) {
    final now = DateTime.now();
    final wasAlreadyDeleted = item.isDeleted;

    if (wasAlreadyDeleted) {
      developer.log(
        'Item ${item.id} was already deleted',
        name: _logTag,
      );

      return SoftDeleteResult(
        item: item,
        wasAlreadyDeleted: true,
        deletedAt: item.updatedAt,
        reason: _deletionReasons[item.id] ?? 'Unknown',
      );
    }

    // Marcar como eliminado
    final deletedItem = item.copyWithDeleted(true, now) as T;

    // Registrar en historial
    _deletionHistory[item.id] = now;
    _deletionReasons[item.id] = reason;

    developer.log(
      'Marked item ${item.id} as deleted: $reason',
      name: _logTag,
    );

    return SoftDeleteResult(
      item: deletedItem,
      wasAlreadyDeleted: false,
      deletedAt: now,
      reason: reason,
    );
  }

  /// Restaura un item eliminado (undelete)
  T restoreDeleted<T extends SoftDeletable>(
    T item, {
    String reason = 'User restoration',
  }) {
    if (!item.isDeleted) {
      developer.log(
        'Item ${item.id} is not deleted, no restoration needed',
        name: _logTag,
      );
      return item;
    }

    final now = DateTime.now();
    final restoredItem = item.copyWithDeleted(false, now) as T;

    // Remover del historial de eliminación
    _deletionHistory.remove(item.id);
    _deletionReasons.remove(item.id);

    developer.log(
      'Restored item ${item.id}: $reason',
      name: _logTag,
    );

    return restoredItem;
  }

  /// Verifica si un item debe ser eliminado permanentemente
  bool shouldPermanentlyDelete<T extends SoftDeletable>(T item) {
    if (!item.isDeleted) return false;

    final deletedAt = _deletionHistory[item.id] ?? item.updatedAt;
    final age = DateTime.now().difference(deletedAt);

    return age > _config.retentionPeriod;
  }

  /// Obtiene items que deben ser limpiados
  List<T> getItemsForCleanup<T extends SoftDeletable>(List<T> items) {
    if (!_config.enableAutoCleanup) return [];

    final itemsToCleanup = <T>[];
    final deletedItems = items.where((item) => item.isDeleted).toList();

    // Limpiar por antigüedad
    for (final item in deletedItems) {
      if (shouldPermanentlyDelete(item)) {
        itemsToCleanup.add(item);
      }
    }

    // Limpiar por cantidad máxima
    if (deletedItems.length > _config.maxDeletedItems) {
      // Ordenar por fecha de eliminación (más antiguos primero)
      deletedItems.sort((a, b) {
        final aDeletedAt = _deletionHistory[a.id] ?? a.updatedAt;
        final bDeletedAt = _deletionHistory[b.id] ?? b.updatedAt;
        return aDeletedAt.compareTo(bDeletedAt);
      });

      final excess = deletedItems.length - _config.maxDeletedItems;
      itemsToCleanup.addAll(deletedItems.take(excess));
    }

    if (itemsToCleanup.isNotEmpty) {
      developer.log(
        'Found ${itemsToCleanup.length} items for cleanup',
        name: _logTag,
      );
    }

    return itemsToCleanup;
  }

  /// Verifica si se debe prevenir la resurrección de un item eliminado
  bool shouldPreventResurrection<T extends SoftDeletable>(
    T deletedItem,
    T newItem,
  ) {
    return preventResurrection(deletedItem, newItem);
  }

  /// Previene la resurrección de items eliminados
  bool preventResurrection<T extends SoftDeletable>(
    T localItem,
    T remoteItem,
  ) {
    // Si el item local está eliminado y el remoto no, verificar timestamps
    if (localItem.isDeleted && !remoteItem.isDeleted) {
      final localDeletedAt =
          _deletionHistory[localItem.id] ?? localItem.updatedAt;

      // Si la eliminación local es más reciente que la modificación remota,
      // prevenir la resurrección
      if (localDeletedAt.isAfter(remoteItem.updatedAt)) {
        developer.log(
          'Preventing resurrection of item ${localItem.id}: local deletion (${localDeletedAt.toIso8601String()}) is newer than remote modification (${remoteItem.updatedAt.toIso8601String()})',
          name: _logTag,
        );
        return true;
      }
    }

    // Si el item remoto está eliminado y el local no, verificar timestamps
    if (remoteItem.isDeleted && !localItem.isDeleted) {
      // Asumir que la eliminación remota es válida si es más reciente
      if (remoteItem.updatedAt.isAfter(localItem.updatedAt)) {
        developer.log(
          'Remote deletion (${remoteItem.updatedAt.toIso8601String()}) is newer than local modification (${localItem.updatedAt.toIso8601String()})',
          name: _logTag,
        );
        return true;
      }
    }

    return false;
  }

  /// Propaga soft deletes entre dispositivos
  List<T> propagateSoftDeletes<T extends SoftDeletable>(
    List<T> localItems,
    List<T> remoteItems,
  ) {
    final propagatedItems = <T>[];
    final localMap = {for (final item in localItems) item.id: item};
    final remoteMap = {for (final item in remoteItems) item.id: item};

    // Propagar eliminaciones locales a items remotos
    for (final localItem in localItems) {
      if (localItem.isDeleted) {
        final remoteItem = remoteMap[localItem.id];
        if (remoteItem != null && !remoteItem.isDeleted) {
          // Verificar si la eliminación local es más reciente
          final localDeletedAt =
              _deletionHistory[localItem.id] ?? localItem.updatedAt;
          if (localDeletedAt.isAfter(remoteItem.updatedAt)) {
            final deletedRemoteItem =
                remoteItem.copyWithDeleted(true, localDeletedAt) as T;
            propagatedItems.add(deletedRemoteItem);

            developer.log(
              'Propagated local deletion of ${localItem.id} to remote',
              name: _logTag,
            );
          }
        }
      }
    }

    // Propagar eliminaciones remotas a items locales
    for (final remoteItem in remoteItems) {
      if (remoteItem.isDeleted) {
        final localItem = localMap[remoteItem.id];
        if (localItem != null && !localItem.isDeleted) {
          // Verificar si la eliminación remota es más reciente
          if (remoteItem.updatedAt.isAfter(localItem.updatedAt)) {
            final deletedLocalItem =
                localItem.copyWithDeleted(true, remoteItem.updatedAt) as T;
            propagatedItems.add(deletedLocalItem);

            // Registrar en historial local
            _deletionHistory[localItem.id] = remoteItem.updatedAt;
            _deletionReasons[localItem.id] = 'Remote deletion propagation';

            developer.log(
              'Propagated remote deletion of ${remoteItem.id} to local',
              name: _logTag,
            );
          }
        }
      }
    }

    return propagatedItems;
  }

  /// Obtiene estadísticas de soft deletes
  Map<String, dynamic> getSoftDeleteStats() {
    final now = DateTime.now();
    final recentDeletions = _deletionHistory.values
        .where((deletedAt) => now.difference(deletedAt).inDays <= 7)
        .length;

    final oldDeletions = _deletionHistory.values
        .where(
            (deletedAt) => now.difference(deletedAt) > _config.retentionPeriod)
        .length;

    final reasonStats = <String, int>{};
    for (final reason in _deletionReasons.values) {
      reasonStats[reason] = (reasonStats[reason] ?? 0) + 1;
    }

    return {
      'totalDeleted': _deletionHistory.length,
      'recentDeletions': recentDeletions,
      'oldDeletions': oldDeletions,
      'deletionReasons': reasonStats,
      'retentionPeriodDays': _config.retentionPeriod.inDays,
      'maxDeletedItems': _config.maxDeletedItems,
      'autoCleanupEnabled': _config.enableAutoCleanup,
    };
  }

  /// Limpia el historial de eliminaciones (para testing)
  @visibleForTesting
  void clearHistory() {
    _deletionHistory.clear();
    _deletionReasons.clear();
  }

  /// Obtiene la fecha de eliminación de un item
  DateTime? getDeletionDate(String itemId) {
    return _deletionHistory[itemId];
  }

  /// Obtiene la razón de eliminación de un item
  String? getDeletionReason(String itemId) {
    return _deletionReasons[itemId];
  }
}
