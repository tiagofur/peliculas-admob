import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/entity_sync_manager.dart';
import '../../../domain/entities/syncable_custom_list.dart';
import '../../../domain/entities/syncable_entity.dart';
import '../../../domain/entities/syncable_watched_movie.dart';
import '../../../domain/entities/syncable_watchlist_item.dart';

/// Widget que muestra una vista previa de los cambios en conflicto
class ConflictPreviewWidget<T extends SyncableEntity> extends ConsumerWidget {
  const ConflictPreviewWidget({
    super.key,
    required this.conflict,
    required this.selectedStrategy,
    this.compact = false,
    this.showDifferences = true,
  });

  final ConflictInfo<T> conflict;
  final ConflictStrategy selectedStrategy;
  final bool compact;
  final bool showDifferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.preview,
                  size: compact ? 18 : 20,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Vista Previa',
                  style: (compact
                          ? theme.textTheme.titleSmall
                          : theme.textTheme.titleMedium)
                      ?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const Spacer(),
                _buildStrategyChip(context),
              ],
            ),
            SizedBox(height: compact ? 8 : 12),
            _buildPreviewContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategyChip(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    Color chipColor;
    IconData chipIcon;
    String chipLabel;

    switch (selectedStrategy) {
      case ConflictStrategy.localWins:
        chipColor = colors.tertiary;
        chipIcon = Icons.phone_android;
        chipLabel = 'Local';
        break;
      case ConflictStrategy.remoteWins:
        chipColor = colors.secondary;
        chipIcon = Icons.cloud;
        chipLabel = 'Remoto';
        break;
      case ConflictStrategy.merge:
        chipColor = colors.primary;
        chipIcon = Icons.merge;
        chipLabel = 'Fusión';
        break;
      case ConflictStrategy.userChoice:
        chipColor = colors.error;
        chipIcon = Icons.person;
        chipLabel = 'Manual';
        break;
    }

    return Chip(
      avatar: Icon(
        chipIcon,
        size: 16,
        color: chipColor,
      ),
      label: Text(
        chipLabel,
        style: theme.textTheme.labelSmall?.copyWith(
          color: chipColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: chipColor.withValues(alpha: 0.1),
      side: BorderSide(color: chipColor.withValues(alpha: 0.3)),
    );
  }

  Widget _buildPreviewContent(BuildContext context) {
    switch (selectedStrategy) {
      case ConflictStrategy.localWins:
        return _buildSingleVersionPreview(
            context, conflict.localEntity, 'Versión Local', true);
      case ConflictStrategy.remoteWins:
        return _buildSingleVersionPreview(
            context, conflict.remoteEntity, 'Versión Remota', false);
      case ConflictStrategy.merge:
        return _buildMergePreview(context);
      case ConflictStrategy.userChoice:
        return _buildComparisonPreview(context);
    }
  }

  Widget _buildSingleVersionPreview(
      BuildContext context, T entity, String title, bool isLocal) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isLocal ? Icons.phone_android : Icons.cloud,
              size: 16,
              color: isLocal ? colors.tertiary : colors.secondary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: colors.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (isLocal ? colors.tertiary : colors.secondary)
                  .withValues(alpha: 0.3),
            ),
          ),
          child: _buildEntityDetails(context, entity),
        ),
      ],
    );
  }

  Widget _buildMergePreview(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.merge,
              size: 16,
              color: colors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Resultado de Fusión',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: colors.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vista previa de fusión automática:',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              _buildMergedEntityPreview(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonPreview(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comparación de Versiones',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        if (compact)
          _buildCompactComparison(context)
        else
          _buildDetailedComparison(context),
      ],
    );
  }

  Widget _buildCompactComparison(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.tertiaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.tertiary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.phone_android, size: 14, color: colors.tertiary),
                    const SizedBox(width: 4),
                    Text(
                      'Local',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colors.tertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _buildEntitySummary(context, conflict.localEntity),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.compare_arrows,
          color: colors.onSurface.withValues(alpha: 0.5),
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.secondaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: colors.secondary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud, size: 14, color: colors.secondary),
                    const SizedBox(width: 4),
                    Text(
                      'Remoto',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _buildEntitySummary(context, conflict.remoteEntity),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedComparison(BuildContext context) {
    return Column(
      children: [
        _buildSingleVersionPreview(
            context, conflict.localEntity, 'Versión Local', true),
        const SizedBox(height: 12),
        _buildSingleVersionPreview(
            context, conflict.remoteEntity, 'Versión Remota', false),
        if (showDifferences) ...[
          const SizedBox(height: 12),
          _buildDifferencesSection(context),
        ],
      ],
    );
  }

  Widget _buildDifferencesSection(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final differences = _calculateDifferences();

    if (differences.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: colors.primary,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'No se encontraron diferencias significativas',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Diferencias Detectadas',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.errorContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: differences.entries
                .map((diff) => _buildDifferenceItem(context, diff))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDifferenceItem(
      BuildContext context, MapEntry<String, Map<String, dynamic>> diff) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber,
            size: 14,
            color: colors.error,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onErrorContainer,
                ),
                children: [
                  TextSpan(
                    text: '${diff.key}: ',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(
                    text:
                        '"${diff.value['local']}" → "${diff.value['remote']}"',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntityDetails(BuildContext context, T entity) {
    // Implementación específica por tipo de entidad
    if (entity is SyncableWatchedMovie) {
      return _buildWatchedMovieDetails(context, entity);
    } else if (entity is SyncableWatchlistItem) {
      return _buildWatchlistItemDetails(context, entity);
    } else if (entity is SyncableCustomList) {
      return _buildCustomListDetails(context, entity);
    }

    return _buildGenericEntityDetails(context, entity);
  }

  Widget _buildEntitySummary(BuildContext context, T entity) {
    final theme = Theme.of(context);

    if (entity is SyncableWatchedMovie) {
      return Text(
        entity.movieTitle,
        style: theme.textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else if (entity is SyncableWatchlistItem) {
      return Text(
        entity.movieTitle,
        style: theme.textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else if (entity is SyncableCustomList) {
      return Text(
        entity.name,
        style: theme.textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text(
      entity.id,
      style: theme.textTheme.bodySmall,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildWatchedMovieDetails(
      BuildContext context, SyncableWatchedMovie movie) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow(context, 'Película', movie.movieTitle),
        _buildDetailRow(context, 'Calificación',
            movie.rating?.toString() ?? 'Sin calificar'),
        _buildDetailRow(context, 'Visto el', _formatDate(movie.watchedDate)),
        if (movie.personalNotes != null && movie.personalNotes!.isNotEmpty)
          _buildDetailRow(context, 'Reseña', movie.personalNotes!, maxLines: 2),
        _buildDetailRow(
            context, 'Modificado', _formatDate(movie.lastModifiedAt)),
      ],
    );
  }

  Widget _buildWatchlistItemDetails(
      BuildContext context, SyncableWatchlistItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow(context, 'Película', item.movieTitle),
        _buildDetailRow(context, 'Agregado', _formatDate(item.addedAt)),
        _buildDetailRow(
            context, 'Prioridad', item.priority.toString()),
        if (item.personalNotes != null && item.personalNotes!.isNotEmpty)
          _buildDetailRow(context, 'Notas', item.personalNotes!, maxLines: 2),
        _buildDetailRow(
            context, 'Modificado', _formatDate(item.lastModifiedAt)),
      ],
    );
  }

  Widget _buildCustomListDetails(
      BuildContext context, SyncableCustomList list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow(context, 'Nombre', list.name),
        if (list.description != null && list.description!.isNotEmpty)
          _buildDetailRow(context, 'Descripción', list.description!,
              maxLines: 2),
        _buildDetailRow(
            context, 'Películas', '${list.movieIds.length} elementos'),
        _buildDetailRow(context, 'Creado', _formatDate(list.createdAt)),
        _buildDetailRow(
            context, 'Modificado', _formatDate(list.lastModifiedAt)),
      ],
    );
  }

  Widget _buildGenericEntityDetails(BuildContext context, T entity) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow(context, 'ID', entity.id),
        _buildDetailRow(context, 'Tipo', entity.entityType),
        _buildDetailRow(context, 'Usuario', entity.userId),
        _buildDetailRow(context, 'Creado', _formatDate(entity.createdAt)),
        _buildDetailRow(
            context, 'Modificado', _formatDate(entity.lastModifiedAt)),
      ],
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value,
      {int maxLines = 1}) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMergedEntityPreview(BuildContext context) {
    // Simulación de fusión - en implementación real usaría el ConflictResolver
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Los siguientes campos serán fusionados automáticamente:',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        ..._getMergeableFields().map((field) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                children: [
                  Icon(
                    Icons.merge,
                    size: 12,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    field,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            )),
      ],
    );
  }

  List<String> _getMergeableFields() {
    // Lógica simplificada para determinar campos fusionables
    if (conflict.localEntity is SyncableWatchedMovie) {
      return [
        'Título de película',
        'Fecha de visualización',
        'Calificación más reciente'
      ];
    } else if (conflict.localEntity is SyncableWatchlistItem) {
      return ['Título de película', 'Fecha de agregado', 'Notas combinadas'];
    } else if (conflict.localEntity is SyncableCustomList) {
      return ['Nombre de lista', 'Descripción', 'Películas combinadas'];
    }
    return ['Campos básicos', 'Metadatos'];
  }

  Map<String, Map<String, dynamic>> _calculateDifferences() {
    final differences = <String, Map<String, dynamic>>{};

    // Implementación simplificada - en la práctica usaría reflexión o mapas
    if (conflict.localEntity is SyncableWatchedMovie &&
        conflict.remoteEntity is SyncableWatchedMovie) {
      final local = conflict.localEntity as SyncableWatchedMovie;
      final remote = conflict.remoteEntity as SyncableWatchedMovie;

      if (local.rating != remote.rating) {
        differences['Calificación'] = {
          'local': local.rating,
          'remote': remote.rating
        };
      }
      if (local.personalNotes != remote.personalNotes) {
        differences['Reseña'] = {
          'local': local.personalNotes ?? '',
          'remote': remote.personalNotes ?? ''
        };
      }
    }

    return differences;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
