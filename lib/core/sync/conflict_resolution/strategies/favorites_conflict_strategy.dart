import 'dart:developer' as developer;

import '../../../../domain/entities/syncable_favorite_movie.dart';
import '../multiplatform_conflict_resolver.dart';

/// Estrategia de resolución de conflictos para películas favoritas
class FavoritesConflictStrategy
    extends ConflictResolutionStrategy<SyncableFavoriteMovie> {
  static const String _logTag = 'FavoritesConflictStrategy';

  @override
  ConflictResolutionResult<SyncableFavoriteMovie> resolveConflict(
    SyncableFavoriteMovie localItem,
    SyncableFavoriteMovie remoteItem,
    ConflictType conflictType,
  ) {
    developer.log(
      'Resolving favorites conflict: ${conflictType.name} for movie ${localItem.movieId}',
      name: _logTag,
    );

    switch (conflictType) {
      case ConflictType.modificationVsDeletion:
        // La eliminación remota gana sobre modificación local
        return ConflictResolutionResult(
          resolvedItem: remoteItem.copyWith(isDeleted: true),
          conflictType: conflictType,
          severity: ConflictSeverity.medium,
          resolution: 'Remote deletion wins over local modification',
          description:
              'La eliminación remota prevalece sobre la modificación local. Se pierde la modificación local.',
          requiresManualIntervention:
              requiresManualIntervention(localItem, remoteItem, conflictType),
          dataLoss: true,
          resolvedAt: DateTime.now(),
        );

      case ConflictType.deletionVsModification:
        // La eliminación local gana sobre modificación remota
        return ConflictResolutionResult(
          resolvedItem: localItem.copyWith(isDeleted: true),
          conflictType: conflictType,
          severity: ConflictSeverity.medium,
          resolution: 'Local deletion wins over remote modification',
          description:
              'La eliminación local prevalece sobre la modificación remota. Se pierde la modificación remota.',
          requiresManualIntervention:
              requiresManualIntervention(localItem, remoteItem, conflictType),
          dataLoss: true,
          resolvedAt: DateTime.now(),
        );

      case ConflictType.simultaneousAddition:
        // Ambos dispositivos agregaron el mismo favorito - merge timestamps
        final resolvedItem = _mergeSimultaneousAdditions(localItem, remoteItem);
        return ConflictResolutionResult(
          resolvedItem: resolvedItem,
          conflictType: conflictType,
          severity: ConflictSeverity.low,
          resolution: 'Merged simultaneous additions with earliest timestamp',
          description:
              'Ambos dispositivos agregaron el mismo favorito. Se fusiona y se conserva el timestamp más temprano.',
          requiresManualIntervention:
              requiresManualIntervention(localItem, remoteItem, conflictType),
          dataLoss: false,
          resolvedAt: DateTime.now(),
        );

      case ConflictType.simultaneousModification:
        // Modificaciones simultáneas - usar timestamp más reciente
        final resolvedItem =
            _resolveSimultaneousModifications(localItem, remoteItem);
        return ConflictResolutionResult(
          resolvedItem: resolvedItem,
          conflictType: conflictType,
          severity: ConflictSeverity.low,
          resolution:
              'Used most recent timestamp for simultaneous modifications',
          description:
              'Modificaciones simultáneas fusionadas, se conserva el timestamp más reciente.',
          requiresManualIntervention:
              requiresManualIntervention(localItem, remoteItem, conflictType),
          dataLoss: false,
          resolvedAt: DateTime.now(),
        );

      case ConflictType.listConflict:
        // No aplica para favoritos individuales
        throw ArgumentError(
            'List conflicts do not apply to individual favorites');
    }
  }

  /// Merge de adiciones simultáneas - preserva el timestamp más temprano
  SyncableFavoriteMovie _mergeSimultaneousAdditions(
    SyncableFavoriteMovie localItem,
    SyncableFavoriteMovie remoteItem,
  ) {
    // Usar el timestamp más temprano (primera vez que se agregó)
    final earliestTimestamp = localItem.createdAt.isBefore(remoteItem.createdAt)
        ? localItem.createdAt
        : remoteItem.createdAt;

    // Usar el timestamp de actualización más reciente
    final latestUpdateTimestamp =
        localItem.updatedAt.isAfter(remoteItem.updatedAt)
            ? localItem.updatedAt
            : remoteItem.updatedAt;

    developer.log(
      'Merging simultaneous additions: earliest=${earliestTimestamp.toIso8601String()}, latest=${latestUpdateTimestamp.toIso8601String()}',
      name: _logTag,
    );

    return localItem.copyWith(
      createdAt: earliestTimestamp,
      updatedAt: latestUpdateTimestamp,
      isDeleted: false, // Asegurar que no esté marcado como eliminado
    );
  }

  /// Resolución de modificaciones simultáneas - usar timestamp más reciente
  SyncableFavoriteMovie _resolveSimultaneousModifications(
    SyncableFavoriteMovie localItem,
    SyncableFavoriteMovie remoteItem,
  ) {
    // El item con timestamp más reciente gana
    final useLocal = localItem.updatedAt.isAfter(remoteItem.updatedAt);
    final winningItem = useLocal ? localItem : remoteItem;
    final losingItem = useLocal ? remoteItem : localItem;

    developer.log(
      'Resolving simultaneous modifications: ${useLocal ? 'local' : 'remote'} wins with timestamp ${winningItem.updatedAt.toIso8601String()}',
      name: _logTag,
    );

    // Preservar algunos campos del item perdedor si son más recientes
    return winningItem.copyWith(
      // Si el item perdedor tiene un createdAt más temprano, usarlo
      createdAt: winningItem.createdAt.isBefore(losingItem.createdAt)
          ? winningItem.createdAt
          : losingItem.createdAt,
    );
  }

  /// Verifica si dos favoritos son equivalentes (mismo estado final)
  bool areEquivalent(SyncableFavoriteMovie item1, SyncableFavoriteMovie item2) {
    return item1.movieId == item2.movieId && item1.isDeleted == item2.isDeleted;
  }

  /// Determina si un conflicto requiere intervención manual
  bool requiresManualIntervention(
    SyncableFavoriteMovie localItem,
    SyncableFavoriteMovie remoteItem,
    ConflictType conflictType,
  ) {
    // Los favoritos generalmente no requieren intervención manual
    // ya que son operaciones simples (agregar/eliminar)
    return false;
  }
}
