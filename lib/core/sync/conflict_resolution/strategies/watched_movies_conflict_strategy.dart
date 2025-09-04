import 'dart:developer' as developer;

import '../../../../domain/entities/sync_models.dart';
import '../multiplatform_conflict_resolver.dart';

/// Estrategia de resolución de conflictos para películas vistas
class WatchedMoviesConflictStrategy
    extends ConflictResolutionStrategy<SyncableWatchedMovie> {
  static const String _logTag = 'WatchedMoviesConflictStrategy';

  @override
  ConflictResolutionResult<SyncableWatchedMovie> resolveConflict(
    SyncableWatchedMovie localItem,
    SyncableWatchedMovie remoteItem,
    ConflictType conflictType,
  ) {
    developer.log(
      'Resolving watched movies conflict: ${conflictType.name} for movie ${localItem.movieId}',
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
              'La eliminación remota prevalece sobre la modificación local. Se pierde la información local.',
          requiresManualIntervention:
              requiresManualIntervention(localItem, remoteItem, conflictType),
          dataLoss: true, // Se pierde la información de visualización local
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
              'La eliminación local prevalece sobre la modificación remota. Se pierde la información remota.',
          requiresManualIntervention:
              requiresManualIntervention(localItem, remoteItem, conflictType),
          dataLoss: true, // Se pierde la información de visualización remota
          resolvedAt: DateTime.now(),
        );

      case ConflictType.simultaneousAddition:
        // Ambos dispositivos marcaron como vista - merge inteligente
        final resolvedItem =
            _mergeSimultaneousWatchedEntries(localItem, remoteItem);
        return ConflictResolutionResult(
          resolvedItem: resolvedItem,
          conflictType: conflictType,
          severity: ConflictSeverity.low,
          resolution:
              'Merged simultaneous watched entries with earliest watch date',
          description:
              'Entradas simultáneas fusionadas, se conserva la fecha de visualización más temprana.',
          requiresManualIntervention:
              requiresManualIntervention(localItem, remoteItem, conflictType),
          dataLoss: false,
          resolvedAt: DateTime.now(),
        );

      case ConflictType.simultaneousModification:
        // Modificaciones simultáneas - merge preservando la mejor información
        final resolvedItem =
            _resolveSimultaneousWatchedModifications(localItem, remoteItem);
        return ConflictResolutionResult(
          resolvedItem: resolvedItem,
          conflictType: conflictType,
          severity: ConflictSeverity.medium,
          resolution: 'Merged simultaneous modifications preserving best data',
          description:
              'Modificaciones simultáneas fusionadas, se preserva la mejor información.',
          requiresManualIntervention:
              requiresManualIntervention(localItem, remoteItem, conflictType),
          dataLoss: false,
          resolvedAt: DateTime.now(),
        );

      case ConflictType.listConflict:
        // No aplica para películas vistas individuales
        throw ArgumentError(
            'List conflicts do not apply to individual watched movies');
    }
  }

  /// Merge de entradas simultáneas de películas vistas
  SyncableWatchedMovie _mergeSimultaneousWatchedEntries(
    SyncableWatchedMovie localItem,
    SyncableWatchedMovie remoteItem,
  ) {
    // Usar la fecha de visualización más temprana (primera vez que se vio)
    final earliestWatchedAt = localItem.watchedAt.isBefore(remoteItem.watchedAt)
        ? localItem.watchedAt
        : remoteItem.watchedAt;

    // Usar el timestamp de creación más temprano
    final earliestCreatedAt = localItem.createdAt.isBefore(remoteItem.createdAt)
        ? localItem.createdAt
        : remoteItem.createdAt;

    // Usar el timestamp de actualización más reciente
    final latestUpdatedAt = localItem.updatedAt.isAfter(remoteItem.updatedAt)
        ? localItem.updatedAt
        : remoteItem.updatedAt;

    // Preservar rating si existe en alguno de los items
    final rating = localItem.rating ?? remoteItem.rating;
    final review = localItem.review?.isNotEmpty == true
        ? localItem.review
        : remoteItem.review;

    developer.log(
      'Merging simultaneous watched entries: earliest_watched=${earliestWatchedAt.toIso8601String()}, rating=$rating',
      name: _logTag,
    );

    return localItem.copyWith(
      watchedAt: earliestWatchedAt,
      createdAt: earliestCreatedAt,
      updatedAt: latestUpdatedAt,
      rating: rating,
      review: review,
      isDeleted: false,
    );
  }

  /// Resolución de modificaciones simultáneas preservando la mejor información
  SyncableWatchedMovie _resolveSimultaneousWatchedModifications(
    SyncableWatchedMovie localItem,
    SyncableWatchedMovie remoteItem,
  ) {
    // Determinar cuál tiene el timestamp de actualización más reciente
    final useLocalAsBase = localItem.updatedAt.isAfter(remoteItem.updatedAt);
    final baseItem = useLocalAsBase ? localItem : remoteItem;
    final otherItem = useLocalAsBase ? remoteItem : localItem;

    // Preservar la fecha de visualización más temprana
    final earliestWatchedAt = baseItem.watchedAt.isBefore(otherItem.watchedAt)
        ? baseItem.watchedAt
        : otherItem.watchedAt;

    // Preservar el rating más reciente (si existe)
    final rating = baseItem.rating ?? otherItem.rating;

    // Preservar la review más larga/completa
    String? review;
    if (baseItem.review?.isNotEmpty == true &&
        otherItem.review?.isNotEmpty == true) {
      // Si ambos tienen review, usar la más larga
      review = (baseItem.review?.length ?? 0) >= (otherItem.review?.length ?? 0)
          ? baseItem.review
          : otherItem.review;
    } else {
      // Usar la que no esté vacía
      review = baseItem.review?.isNotEmpty == true
          ? baseItem.review
          : otherItem.review;
    }

    // Preservar el createdAt más temprano
    final earliestCreatedAt = baseItem.createdAt.isBefore(otherItem.createdAt)
        ? baseItem.createdAt
        : otherItem.createdAt;

    developer.log(
      'Resolving simultaneous watched modifications: base=${useLocalAsBase ? 'local' : 'remote'}, merged_rating=$rating',
      name: _logTag,
    );

    return baseItem.copyWith(
      watchedAt: earliestWatchedAt,
      createdAt: earliestCreatedAt,
      rating: rating,
      review: review,
    );
  }

  /// Verifica si dos películas vistas son equivalentes
  bool areEquivalent(SyncableWatchedMovie item1, SyncableWatchedMovie item2) {
    return item1.movieId == item2.movieId &&
        item1.isDeleted == item2.isDeleted &&
        item1.watchedAt.difference(item2.watchedAt).abs().inMinutes < 1 &&
        item1.rating == item2.rating;
  }

  /// Determina si un conflicto requiere intervención manual
  bool requiresManualIntervention(
    SyncableWatchedMovie localItem,
    SyncableWatchedMovie remoteItem,
    ConflictType conflictType,
  ) {
    // Requiere intervención manual si:
    // 1. Hay ratings muy diferentes
    // 2. Hay reviews muy diferentes
    // 3. Las fechas de visualización difieren significativamente

    if (localItem.rating != null && remoteItem.rating != null) {
      final ratingDiff = (localItem.rating! - remoteItem.rating!).abs();
      if (ratingDiff >= 3.0) {
        // Diferencia de 3+ estrellas
        return true;
      }
    }

    if (localItem.review?.isNotEmpty == true &&
        remoteItem.review?.isNotEmpty == true) {
      final localReview = localItem.review?.toLowerCase() ?? '';
      final remoteReview = remoteItem.review?.toLowerCase() ?? '';

      // Si las reviews son muy diferentes en longitud o contenido
      if ((localReview.length - remoteReview.length).abs() > 100 ||
          !localReview
              .contains(remoteReview.substring(0, remoteReview.length ~/ 2))) {
        return true;
      }
    }

    // Fechas de visualización muy diferentes (más de 7 días)
    final watchedAtDiff =
        localItem.watchedAt.difference(remoteItem.watchedAt).abs();
    if (watchedAtDiff.inDays > 7) {
      return true;
    }

    return false;
  }
}
