import 'dart:developer' as developer;

import '../../../../domain/entities/syncable_watchlist_movie.dart';
import '../../../../domain/entities/watchlist_movie.dart';
import '../multiplatform_conflict_resolver.dart';

/// Estrategia de resolución de conflictos para películas en watchlist
class WatchlistConflictStrategy
    extends ConflictResolutionStrategy<SyncableWatchlistMovie> {
  static const String _logTag = 'WatchlistConflictStrategy';

  @override
  ConflictResolutionResult<SyncableWatchlistMovie> resolveConflict(
    SyncableWatchlistMovie localItem,
    SyncableWatchlistMovie remoteItem,
    ConflictType conflictType,
  ) {
    developer.log(
      'Resolving watchlist conflict: ${conflictType.name} for movie ${localItem.movieId}',
      name: _logTag,
    );

    switch (conflictType) {
      case ConflictType.modificationVsDeletion:
        // La eliminación remota gana sobre modificación local
        return ConflictResolutionResult(
          resolvedItem: remoteItem.copyWith(deletedAt: remoteItem.deletedAt),
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
          resolvedItem: localItem.copyWith(deletedAt: localItem.deletedAt),
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
        // Ambos dispositivos agregaron a watchlist - merge inteligente
        final resolvedItem = _mergeSimultaneousWatchlistAdditions(localItem, remoteItem);
        return ConflictResolutionResult(
          resolvedItem: resolvedItem,
          conflictType: conflictType,
          severity: ConflictSeverity.low,
          resolution: 'Merged simultaneous watchlist additions with earliest timestamp',
          description:
              'Ambos dispositivos agregaron la misma película a watchlist. Se fusiona con el timestamp más temprano.',
          requiresManualIntervention:
              requiresManualIntervention(localItem, remoteItem, conflictType),
          dataLoss: false,
          resolvedAt: DateTime.now(),
        );

      case ConflictType.simultaneousModification:
        // Modificaciones simultáneas - usar timestamp más reciente (last-write-wins)
        final resolvedItem =
            _resolveSimultaneousWatchlistModifications(localItem, remoteItem);
        return ConflictResolutionResult(
          resolvedItem: resolvedItem,
          conflictType: conflictType,
          severity: ConflictSeverity.low,
          resolution:
              'Used most recent timestamp for simultaneous watchlist modifications',
          description:
              'Modificaciones simultáneas en watchlist fusionadas usando last-write-wins.',
          requiresManualIntervention:
              requiresManualIntervention(localItem, remoteItem, conflictType),
          dataLoss: false,
          resolvedAt: DateTime.now(),
        );

      case ConflictType.listConflict:
        // No aplica para elementos individuales de watchlist
        throw ArgumentError(
            'List conflicts do not apply to individual watchlist items');
    }
  }

  /// Merge de adiciones simultáneas a watchlist - preserva el timestamp más temprano
  SyncableWatchlistMovie _mergeSimultaneousWatchlistAdditions(
    SyncableWatchlistMovie localItem,
    SyncableWatchlistMovie remoteItem,
  ) {
    // Usar el timestamp de addedAt más temprano (primera vez que se agregó)
    final earliestAddedAt = localItem.addedAt.isBefore(remoteItem.addedAt)
        ? localItem.addedAt
        : remoteItem.addedAt;

    // Usar el timestamp de actualización más reciente para la última modificación
    final latestUpdatedAt = localItem.updatedAt.isAfter(remoteItem.updatedAt)
        ? localItem.updatedAt
        : remoteItem.updatedAt;

    // Preservar la prioridad más alta si difieren
    final priority = _selectHigherPriority(localItem.priority, remoteItem.priority);

    developer.log(
      'Merging simultaneous watchlist additions: earliest_added=${earliestAddedAt.toIso8601String()}, latest_updated=${latestUpdatedAt.toIso8601String()}, priority=$priority',
      name: _logTag,
    );

    return localItem.copyWith(
      addedAt: earliestAddedAt,
      updatedAt: latestUpdatedAt,
      priority: priority,
      deletedAt: null, // Asegurar que no esté marcado como eliminado
    );
  }

  /// Resolución de modificaciones simultáneas - last-write-wins con merge inteligente
  SyncableWatchlistMovie _resolveSimultaneousWatchlistModifications(
    SyncableWatchlistMovie localItem,
    SyncableWatchlistMovie remoteItem,
  ) {
    // El item con timestamp más reciente gana (last-write-wins)
    final useLocal = localItem.updatedAt.isAfter(remoteItem.updatedAt);
    final winningItem = useLocal ? localItem : remoteItem;
    final losingItem = useLocal ? remoteItem : localItem;

    developer.log(
      'Resolving simultaneous watchlist modifications: ${useLocal ? 'local' : 'remote'} wins with timestamp ${winningItem.updatedAt.toIso8601String()}',
      name: _logTag,
    );

    // Preservar el addedAt más temprano
    final earliestAddedAt = winningItem.addedAt.isBefore(losingItem.addedAt)
        ? winningItem.addedAt
        : losingItem.addedAt;

    return winningItem.copyWith(
      addedAt: earliestAddedAt,
    );
  }

  /// Selecciona la prioridad más alta entre dos prioridades de watchlist
  WatchlistPriority _selectHigherPriority(
    WatchlistPriority priority1,
    WatchlistPriority priority2,
  ) {
    // Orden de prioridad: alta > normal > baja
    const priorityOrder = {
      WatchlistPriority.alta: 3,
      WatchlistPriority.normal: 2,
      WatchlistPriority.baja: 1,
    };

    final value1 = priorityOrder[priority1] ?? 2;
    final value2 = priorityOrder[priority2] ?? 2;

    return value1 >= value2 ? priority1 : priority2;
  }

  /// Verifica si dos elementos de watchlist son equivalentes
  bool areEquivalent(SyncableWatchlistMovie item1, SyncableWatchlistMovie item2) {
    return item1.movieId == item2.movieId &&
        item1.isDeleted == item2.isDeleted &&
        item1.priority == item2.priority;
  }

  /// Determina si un conflicto requiere intervención manual
  bool requiresManualIntervention(
    SyncableWatchlistMovie localItem,
    SyncableWatchlistMovie remoteItem,
    ConflictType conflictType,
  ) {
    // Los elementos de watchlist generalmente no requieren intervención manual
    // ya que son operaciones simples (agregar/eliminar/cambiar prioridad)
    // Solo requerirían intervención en casos muy específicos:
    
    // Si hay una diferencia significativa en los timestamps de addedAt
    // que podría indicar un conflicto de sincronización más complejo
    final addedAtDiff = localItem.addedAt.difference(remoteItem.addedAt).abs();
    if (addedAtDiff.inDays > 7) {
      return true;
    }

    return false;
  }
}