import 'dart:developer' as developer;

import '../../../../domain/entities/syncable_user_movie_rating.dart';
import '../multiplatform_conflict_resolver.dart';

/// Estrategia de resolución de conflictos para valoraciones de películas
class RatingsConflictStrategy
    extends ConflictResolutionStrategy<SyncableUserMovieRating> {
  static const String _logTag = 'RatingsConflictStrategy';

  @override
  ConflictResolutionResult<SyncableUserMovieRating> resolveConflict(
    SyncableUserMovieRating localItem,
    SyncableUserMovieRating remoteItem,
    ConflictType conflictType,
  ) {
    developer.log(
      'Resolving ratings conflict: ${conflictType.name} for movie ${localItem.movieId}',
      name: _logTag,
    );

    switch (conflictType) {
      case ConflictType.modificationVsDeletion:
      case ConflictType.deletionVsModification:
        // Las valoraciones normalmente no se eliminan, solo se actualizan
        // Si ocurre, tratarlo como modificación simultánea con el más reciente
        final resolvedItem = _resolveSimultaneousRatingModifications(localItem, remoteItem);
        return ConflictResolutionResult(
          resolvedItem: resolvedItem,
          conflictType: conflictType,
          severity: ConflictSeverity.medium,
          resolution: 'Treated deletion as modification, used most recent rating',
          description:
              'Conflicto de eliminación vs modificación tratado como actualización usando last-write-wins.',
          requiresManualIntervention:
              requiresManualIntervention(localItem, remoteItem, conflictType),
          dataLoss: false,
          resolvedAt: DateTime.now(),
        );

      case ConflictType.simultaneousAddition:
        // Ambos dispositivos crearon valoración - merge inteligente
        final resolvedItem = _mergeSimultaneousRatingAdditions(localItem, remoteItem);
        return ConflictResolutionResult(
          resolvedItem: resolvedItem,
          conflictType: conflictType,
          severity: ConflictSeverity.low,
          resolution: 'Merged simultaneous rating additions with most recent data',
          description:
              'Ambos dispositivos crearon valoración. Se fusiona conservando la información más reciente.',
          requiresManualIntervention:
              requiresManualIntervention(localItem, remoteItem, conflictType),
          dataLoss: false,
          resolvedAt: DateTime.now(),
        );

      case ConflictType.simultaneousModification:
        // Modificaciones simultáneas - usar timestamp más reciente (last-write-wins)
        final resolvedItem = _resolveSimultaneousRatingModifications(localItem, remoteItem);
        return ConflictResolutionResult(
          resolvedItem: resolvedItem,
          conflictType: conflictType,
          severity: ConflictSeverity.medium,
          resolution: 'Used most recent timestamp for simultaneous rating modifications',
          description:
              'Modificaciones simultáneas en valoración fusionadas usando last-write-wins.',
          requiresManualIntervention:
              requiresManualIntervention(localItem, remoteItem, conflictType),
          dataLoss: _wouldResultInDataLoss(localItem, remoteItem),
          resolvedAt: DateTime.now(),
        );

      case ConflictType.listConflict:
        // No aplica para valoraciones individuales
        throw ArgumentError('List conflicts do not apply to individual ratings');
    }
  }

  /// Merge de adiciones simultáneas de valoraciones
  SyncableUserMovieRating _mergeSimultaneousRatingAdditions(
    SyncableUserMovieRating localItem,
    SyncableUserMovieRating remoteItem,
  ) {
    // Usar el timestamp de creación más temprano
    final earliestCreatedAt = localItem.createdAt.isBefore(remoteItem.createdAt)
        ? localItem.createdAt
        : remoteItem.createdAt;

    // Usar el timestamp de actualización más reciente
    final latestUpdatedAt = localItem.updatedAt.isAfter(remoteItem.updatedAt)
        ? localItem.updatedAt
        : remoteItem.updatedAt;

    // Usar la valoración y nota más reciente (last-write-wins)
    final useLocal = localItem.updatedAt.isAfter(remoteItem.updatedAt);
    final rating = useLocal ? localItem.rating : remoteItem.rating;
    final personalNote = useLocal ? localItem.personalNote : remoteItem.personalNote;

    developer.log(
      'Merging simultaneous rating additions: earliest_created=${earliestCreatedAt.toIso8601String()}, latest_updated=${latestUpdatedAt.toIso8601String()}, rating=$rating',
      name: _logTag,
    );

    return localItem.copyWith(
      createdAt: earliestCreatedAt,
      updatedAt: latestUpdatedAt,
      rating: rating,
      personalNote: personalNote,
    );
  }

  /// Resolución de modificaciones simultáneas - last-write-wins con merge inteligente
  SyncableUserMovieRating _resolveSimultaneousRatingModifications(
    SyncableUserMovieRating localItem,
    SyncableUserMovieRating remoteItem,
  ) {
    // El item con timestamp más reciente gana (last-write-wins)
    final useLocal = localItem.updatedAt.isAfter(remoteItem.updatedAt);
    final winningItem = useLocal ? localItem : remoteItem;
    final losingItem = useLocal ? remoteItem : localItem;

    developer.log(
      'Resolving simultaneous rating modifications: ${useLocal ? 'local' : 'remote'} wins with timestamp ${winningItem.updatedAt.toIso8601String()}',
      name: _logTag,
    );

    // Preservar el createdAt más temprano
    final earliestCreatedAt = winningItem.createdAt.isBefore(losingItem.createdAt)
        ? winningItem.createdAt
        : losingItem.createdAt;

    // Merge inteligente de notas si ambas tienen contenido valioso
    String? mergedNote;
    if (winningItem.personalNote?.isNotEmpty == true && 
        losingItem.personalNote?.isNotEmpty == true) {
      mergedNote = _mergePersonalNotes(winningItem.personalNote!, losingItem.personalNote!);
    } else {
      mergedNote = winningItem.personalNote?.isNotEmpty == true 
          ? winningItem.personalNote 
          : losingItem.personalNote;
    }

    return winningItem.copyWith(
      createdAt: earliestCreatedAt,
      personalNote: mergedNote,
    );
  }

  /// Merge inteligente de notas personales
  String _mergePersonalNotes(String note1, String note2) {
    // Si las notas son muy similares, usar la más larga
    if (_areNotesSimilar(note1, note2)) {
      return note1.length >= note2.length ? note1 : note2;
    }

    // Si son diferentes, combinar si no son muy largas
    final combined = '$note1\n\n[Merged] $note2';
    if (combined.length <= 500) {
      return combined;
    }

    // Si serían muy largas combinadas, usar la más reciente (note1)
    return note1;
  }

  /// Verifica si dos notas son similares
  bool _areNotesSimilar(String note1, String note2) {
    final clean1 = note1.toLowerCase().trim();
    final clean2 = note2.toLowerCase().trim();
    
    // Si una contiene a la otra en más del 70%
    if (clean1.contains(clean2) || clean2.contains(clean1)) {
      return true;
    }

    // Verificar similaridad por palabras comunes
    final words1 = clean1.split(RegExp(r'\s+'));
    final words2 = clean2.split(RegExp(r'\s+'));
    final commonWords = words1.where((word) => words2.contains(word)).length;
    final totalWords = (words1.length + words2.length) / 2;
    
    return commonWords / totalWords > 0.7;
  }

  /// Verifica si la resolución resultaría en pérdida de datos
  bool _wouldResultInDataLoss(
    SyncableUserMovieRating localItem,
    SyncableUserMovieRating remoteItem,
  ) {
    // Hay pérdida de datos si:
    // 1. Los ratings son muy diferentes
    // 2. Las notas son diferentes y no se pueden mergear sin pérdida
    
    final ratingDiff = (localItem.rating - remoteItem.rating).abs();
    if (ratingDiff >= 2) {
      return true;
    }

    // Si ambas tienen notas no vacías y son muy diferentes
    if (localItem.personalNote?.isNotEmpty == true &&
        remoteItem.personalNote?.isNotEmpty == true &&
        !_areNotesSimilar(localItem.personalNote!, remoteItem.personalNote!)) {
      return true;
    }

    return false;
  }

  /// Verifica si dos valoraciones son equivalentes
  bool areEquivalent(SyncableUserMovieRating item1, SyncableUserMovieRating item2) {
    return item1.movieId == item2.movieId &&
        item1.rating == item2.rating &&
        item1.personalNote == item2.personalNote;
  }

  /// Determina si un conflicto requiere intervención manual
  bool requiresManualIntervention(
    SyncableUserMovieRating localItem,
    SyncableUserMovieRating remoteItem,
    ConflictType conflictType,
  ) {
    // Requiere intervención manual si:
    // 1. Hay diferencias significativas en ratings (3+ estrellas)
    // 2. Las notas personales son muy diferentes y largas
    // 3. Las fechas de actualización sugieren ediciones conscientes

    final ratingDiff = (localItem.rating - remoteItem.rating).abs();
    if (ratingDiff >= 3) {
      return true;
    }

    // Si ambas tienen notas largas y diferentes
    if (localItem.personalNote?.isNotEmpty == true &&
        remoteItem.personalNote?.isNotEmpty == true) {
      final note1 = localItem.personalNote!;
      final note2 = remoteItem.personalNote!;
      
      if (note1.length > 50 && note2.length > 50 && !_areNotesSimilar(note1, note2)) {
        return true;
      }
    }

    // Si las actualizaciones fueron muy recientes (menos de 5 minutos)
    // sugiere ediciones activas que el usuario debería revisar
    final updateDiff = localItem.updatedAt.difference(remoteItem.updatedAt).abs();
    if (updateDiff.inMinutes < 5 && ratingDiff >= 2) {
      return true;
    }

    return false;
  }
}