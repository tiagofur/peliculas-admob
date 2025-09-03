import 'dart:developer' as developer;

import '../../../../domain/entities/syncable_custom_list.dart';
import '../multiplatform_conflict_resolver.dart';

/// Estrategia de resolución de conflictos para listas personalizadas
class CustomListsConflictStrategy
    extends ConflictResolutionStrategy<SyncableCustomList> {
  static const String _logTag = 'CustomListsConflictStrategy';

  @override
  ConflictResolutionResult<SyncableCustomList> resolveConflict(
    SyncableCustomList localItem,
    SyncableCustomList remoteItem,
    ConflictType conflictType,
  ) {
    developer.log(
      'Resolving custom lists conflict: ${conflictType.name} for list ${localItem.id}',
      name: _logTag,
    );

    switch (conflictType) {
      case ConflictType.modificationVsDeletion:
        // La eliminación remota gana sobre modificación local
        return ConflictResolutionResult(
          resolvedItem: remoteItem.copyWith(isDeleted: true),
          conflictType: conflictType,
          severity: ConflictSeverity.high,
          resolution: 'Remote deletion wins over local modification',
          description:
              'La eliminación remota prevalece sobre la modificación local. Se pierden las modificaciones locales.',
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
          severity: ConflictSeverity.high,
          resolution: 'Local deletion wins over remote modification',
          description:
              'La eliminación local prevalece sobre la modificación remota. Se pierden las modificaciones remotas.',
          requiresManualIntervention:
              requiresManualIntervention(localItem, remoteItem, conflictType),
          dataLoss: true,
          resolvedAt: DateTime.now(),
        );

      case ConflictType.simultaneousAddition:
        // Ambos dispositivos crearon listas similares - merge
        final resolvedItem =
            _mergeSimultaneousListCreations(localItem, remoteItem);
        return ConflictResolutionResult(
          resolvedItem: resolvedItem,
          conflictType: conflictType,
          severity: ConflictSeverity.medium,
          resolution: 'Merged simultaneous list creations',
          description:
              'Ambos dispositivos crearon listas similares. Se fusionan las listas.',
          requiresManualIntervention:
              requiresManualIntervention(localItem, remoteItem, conflictType),
          dataLoss: false,
          resolvedAt: DateTime.now(),
        );

      case ConflictType.simultaneousModification:
        // Modificaciones simultáneas - merge inteligente
        final resolvedItem =
            _resolveSimultaneousListModifications(localItem, remoteItem);
        return ConflictResolutionResult(
          resolvedItem: resolvedItem,
          conflictType: conflictType,
          severity: ConflictSeverity.medium,
          resolution: 'Merged simultaneous list modifications',
          description:
              'Modificaciones simultáneas fusionadas, se preserva la mejor información de la lista.',
          requiresManualIntervention:
              requiresManualIntervention(localItem, remoteItem, conflictType),
          dataLoss: false,
          resolvedAt: DateTime.now(),
        );

      case ConflictType.listConflict:
        // Conflictos específicos de listas (orden, items)
        final resolvedItem =
            _resolveListSpecificConflicts(localItem, remoteItem);
        return ConflictResolutionResult(
          resolvedItem: resolvedItem,
          conflictType: conflictType,
          severity: ConflictSeverity.medium,
          resolution: 'Resolved list-specific conflicts (items and order)',
          description:
              'Conflictos específicos de listas resueltos (orden e items).',
          requiresManualIntervention:
              requiresManualIntervention(localItem, remoteItem, conflictType),
          dataLoss: false,
          resolvedAt: DateTime.now(),
        );
    }
  }

  /// Merge de creaciones simultáneas de listas
  SyncableCustomList _mergeSimultaneousListCreations(
    SyncableCustomList localItem,
    SyncableCustomList remoteItem,
  ) {
    // Usar el timestamp de creación más temprano
    final earliestCreatedAt = localItem.createdAt.isBefore(remoteItem.createdAt)
        ? localItem.createdAt
        : remoteItem.createdAt;

    // Usar el timestamp de actualización más reciente
    final latestUpdatedAt = localItem.updatedAt.isAfter(remoteItem.updatedAt)
        ? localItem.updatedAt
        : remoteItem.updatedAt;

    // Merge de metadatos - usar los más completos
    final name = localItem.name.isNotEmpty ? localItem.name : remoteItem.name;
    final description = localItem.description.isNotEmpty == true
        ? localItem.description
        : remoteItem.description;

    // Merge de películas - unión sin duplicados
    final mergedMovieIds = <int>{};
    mergedMovieIds.addAll(localItem.movieIds);
    mergedMovieIds.addAll(remoteItem.movieIds);

    developer.log(
      'Merging simultaneous list creations: local_movies=${localItem.movieIds.length}, remote_movies=${remoteItem.movieIds.length}, merged=${mergedMovieIds.length}',
      name: _logTag,
    );

    return localItem.copyWith(
      name: name,
      description: description,
      movieIds: mergedMovieIds.toList(),
      createdAt: earliestCreatedAt,
      updatedAt: latestUpdatedAt,
      isDeleted: false,
    );
  }

  /// Resolución de modificaciones simultáneas de listas
  SyncableCustomList _resolveSimultaneousListModifications(
    SyncableCustomList localItem,
    SyncableCustomList remoteItem,
  ) {
    // Determinar cuál tiene el timestamp más reciente como base
    final useLocalAsBase = localItem.updatedAt.isAfter(remoteItem.updatedAt);
    final baseItem = useLocalAsBase ? localItem : remoteItem;
    final otherItem = useLocalAsBase ? remoteItem : localItem;

    // Merge inteligente de metadatos
    final name = _mergeStringField(baseItem.name, otherItem.name);
    final description =
        _mergeStringField(baseItem.description, otherItem.description);

    // Merge de películas preservando adiciones de ambos lados
    final mergedMovieIds =
        _mergeMovieIds(baseItem.movieIds, otherItem.movieIds);

    // Preservar el createdAt más temprano
    final earliestCreatedAt = baseItem.createdAt.isBefore(otherItem.createdAt)
        ? baseItem.createdAt
        : otherItem.createdAt;

    developer.log(
      'Resolving simultaneous list modifications: base=${useLocalAsBase ? 'local' : 'remote'}, final_movies=${mergedMovieIds.length}',
      name: _logTag,
    );

    return baseItem.copyWith(
      name: name,
      description: description,
      movieIds: mergedMovieIds,
      createdAt: earliestCreatedAt,
    );
  }

  /// Resolución de conflictos específicos de listas
  SyncableCustomList _resolveListSpecificConflicts(
    SyncableCustomList localItem,
    SyncableCustomList remoteItem,
  ) {
    // Para conflictos específicos de listas, hacer merge completo
    final mergedMovieIds =
        _mergeMovieIds(localItem.movieIds, remoteItem.movieIds);

    // Usar el item con timestamp más reciente como base
    final baseItem = localItem.updatedAt.isAfter(remoteItem.updatedAt)
        ? localItem
        : remoteItem;

    final otherItem = localItem.updatedAt.isAfter(remoteItem.updatedAt)
        ? remoteItem
        : localItem;

    // Merge de metadatos
    final name = _mergeStringField(baseItem.name, otherItem.name);
    final description =
        _mergeStringField(baseItem.description, otherItem.description);

    developer.log(
      'Resolving list-specific conflicts: merged ${mergedMovieIds.length} movies',
      name: _logTag,
    );

    return baseItem.copyWith(
      name: name,
      description: description,
      movieIds: mergedMovieIds,
      createdAt: baseItem.createdAt.isBefore(otherItem.createdAt)
          ? baseItem.createdAt
          : otherItem.createdAt,
    );
  }

  /// Merge inteligente de IDs de películas
  List<int> _mergeMovieIds(List<int> localIds, List<int> remoteIds) {
    final mergedIds = <int>{};

    // Agregar todas las películas locales
    mergedIds.addAll(localIds);

    // Agregar películas remotas que no estén en local
    for (final remoteId in remoteIds) {
      mergedIds.add(remoteId);
    }

    // Mantener el orden basado en la lista más larga
    final longerList =
        localIds.length >= remoteIds.length ? localIds : remoteIds;
    final result = <int>[];

    // Primero agregar en el orden de la lista más larga
    for (final id in longerList) {
      if (mergedIds.contains(id)) {
        result.add(id);
        mergedIds.remove(id);
      }
    }

    // Agregar los IDs restantes al final
    result.addAll(mergedIds);

    return result;
  }

  /// Merge inteligente de campos de texto
  String? _mergeStringField(String? field1, String? field2) {
    if (field1?.isNotEmpty == true && field2?.isNotEmpty == true) {
      // Si ambos tienen contenido, usar el más largo
      return (field1?.length ?? 0) >= (field2?.length ?? 0) ? field1 : field2;
    }

    // Usar el que no esté vacío
    return field1?.isNotEmpty == true ? field1 : field2;
  }

  /// Verifica si dos listas son equivalentes
  bool areEquivalent(SyncableCustomList item1, SyncableCustomList item2) {
    return item1.id == item2.id &&
        item1.name == item2.name &&
        item1.isDeleted == item2.isDeleted &&
        _listsEqual(item1.movieIds, item2.movieIds);
  }

  /// Compara si dos listas de IDs son equivalentes (mismo contenido, orden puede diferir)
  bool _listsEqual(List<int> list1, List<int> list2) {
    if (list1.length != list2.length) return false;

    final set1 = Set<int>.from(list1);
    final set2 = Set<int>.from(list2);

    return set1.length == set2.length && set1.containsAll(set2);
  }

  /// Determina si un conflicto requiere intervención manual
  bool requiresManualIntervention(
    SyncableCustomList localItem,
    SyncableCustomList remoteItem,
    ConflictType conflictType,
  ) {
    // Requiere intervención manual si:
    // 1. Los nombres son muy diferentes
    // 2. Las listas tienen contenido muy diferente
    // 3. Una lista se vació mientras la otra se llenó

    // Nombres muy diferentes
    if (localItem.name.isNotEmpty && remoteItem.name.isNotEmpty) {
      final similarity =
          _calculateStringSimilarity(localItem.name, remoteItem.name);
      if (similarity < 0.5) {
        // Menos del 50% de similitud
        return true;
      }
    }

    // Cambios drásticos en el contenido
    final localCount = localItem.movieIds.length;
    final remoteCount = remoteItem.movieIds.length;

    if (localCount > 0 && remoteCount == 0) return true; // Una se vació
    if (localCount == 0 && remoteCount > 0) {
      return true; // Una se llenó desde vacía
    }

    // Cambio drástico en tamaño (más del 50%)
    if (localCount > 0 && remoteCount > 0) {
      final ratio =
          (localCount - remoteCount).abs() / (localCount + remoteCount) * 2;
      if (ratio > 0.5) return true;
    }

    return false;
  }

  /// Calcula similitud básica entre dos strings
  double _calculateStringSimilarity(String str1, String str2) {
    if (str1 == str2) return 1.0;
    if (str1.isEmpty || str2.isEmpty) return 0.0;

    final longer = str1.length > str2.length ? str1 : str2;
    final shorter = str1.length > str2.length ? str2 : str1;

    if (longer.isEmpty) return 1.0;

    final editDistance = _calculateEditDistance(longer, shorter);
    return (longer.length - editDistance) / longer.length;
  }

  /// Calcula distancia de edición básica entre dos strings
  int _calculateEditDistance(String str1, String str2) {
    final matrix = List.generate(
      str1.length + 1,
      (i) => List.filled(str2.length + 1, 0),
    );

    for (int i = 0; i <= str1.length; i++) {
      matrix[i][0] = i;
    }

    for (int j = 0; j <= str2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= str1.length; i++) {
      for (int j = 1; j <= str2.length; j++) {
        final cost = str1[i - 1] == str2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[str1.length][str2.length];
  }
}
