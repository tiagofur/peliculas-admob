import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/conflict_resolver.dart';
import '../../../core/sync/entity_sync_manager.dart';
import '../../../domain/entities/syncable_custom_list.dart';
import '../../../domain/entities/syncable_entity.dart';
import '../../../domain/entities/syncable_watched_movie.dart';
import '../../../domain/entities/syncable_watchlist_item.dart';

/// Widget que muestra una vista previa específica para fusión de datos
class MergePreviewWidget<T extends SyncableEntity>
    extends ConsumerStatefulWidget {
  const MergePreviewWidget({
    super.key,
    required this.conflict,
    this.compact = false,
    this.showFieldDetails = true,
    this.onMergeStrategyChanged,
  });

  final ConflictInfo<T> conflict;
  final bool compact;
  final bool showFieldDetails;
  final Function(Map<String, MergeFieldStrategy>)? onMergeStrategyChanged;

  @override
  ConsumerState<MergePreviewWidget<T>> createState() =>
      _MergePreviewWidgetState<T>();
}

class _MergePreviewWidgetState<T extends SyncableEntity>
    extends ConsumerState<MergePreviewWidget<T>> {
  final Map<String, MergeFieldStrategy> _fieldStrategies = {};
  T? _previewEntity;
  bool _isGeneratingPreview = false;
  String? _previewError;

  @override
  void initState() {
    super.initState();
    _initializeFieldStrategies();
    _generateMergePreview();
  }

  void _initializeFieldStrategies() {
    final fields = _getEntityFields();
    for (final field in fields) {
      _fieldStrategies[field.name] = field.recommendedStrategy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            SizedBox(height: widget.compact ? 8 : 12),
            if (_isGeneratingPreview)
              _buildLoadingIndicator(context)
            else if (_previewError != null)
              _buildErrorIndicator(context)
            else
              _buildMergeContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Icon(
          Icons.merge,
          size: widget.compact ? 18 : 20,
          color: colors.primary,
        ),
        const SizedBox(width: 8),
        Text(
          'Vista Previa de Fusión',
          style: (widget.compact
                  ? theme.textTheme.titleSmall
                  : theme.textTheme.titleMedium)
              ?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        const Spacer(),
        _buildMergeStatusChip(context),
      ],
    );
  }

  Widget _buildMergeStatusChip(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final conflictCount = _getConflictingFieldsCount();
    final Color chipColor;
    final IconData chipIcon;
    final String chipLabel;

    if (conflictCount == 0) {
      chipColor = colors.tertiary;
      chipIcon = Icons.check_circle;
      chipLabel = 'Sin conflictos';
    } else {
      chipColor = colors.error;
      chipIcon = Icons.warning;
      chipLabel = '$conflictCount conflictos';
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
      backgroundColor: chipColor.withValues(alpha: 0.1 * 255),
      side: BorderSide(color: chipColor.withValues(alpha: 0.3 * 255)),
    );
  }

  Widget _buildLoadingIndicator(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Generando vista previa...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7 * 255),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: colors.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Error al generar vista previa',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _previewError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _generateMergePreview,
            child: Text(
              'Reintentar',
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMergeContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showFieldDetails) ...[
          _buildFieldStrategiesSection(context),
          const SizedBox(height: 16),
        ],
        _buildMergeResultSection(context),
      ],
    );
  }

  Widget _buildFieldStrategiesSection(BuildContext context) {
    final theme = Theme.of(context);
    final fields = _getEntityFields();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estrategias por Campo',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...fields.map((field) => _buildFieldStrategyItem(context, field)),
      ],
    );
  }

  Widget _buildFieldStrategyItem(BuildContext context, MergeableField field) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final currentStrategy =
        _fieldStrategies[field.name] ?? field.recommendedStrategy;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: field.hasConflict
            ? colors.errorContainer.withValues(alpha: 0.1 * 255)
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: field.hasConflict
              ? colors.error.withValues(alpha: 0.3 * 255)
              : colors.outline.withValues(alpha: 0.2 * 255),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  field.displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (field.hasConflict)
                Icon(
                  Icons.warning_amber,
                  size: 16,
                  color: colors.error,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _buildFieldValues(context, field),
              ),
              const SizedBox(width: 8),
              _buildStrategySelector(context, field, currentStrategy),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldValues(BuildContext context, MergeableField field) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.phone_android, size: 12, color: colors.tertiary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Local: ${field.localValue}',
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(Icons.cloud, size: 12, color: colors.secondary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Remoto: ${field.remoteValue}',
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStrategySelector(BuildContext context, MergeableField field,
      MergeFieldStrategy currentStrategy) {
    final theme = Theme.of(context);

    return PopupMenuButton<MergeFieldStrategy>(
      initialValue: currentStrategy,
      onSelected: (strategy) {
        setState(() {
          _fieldStrategies[field.name] = strategy;
        });
        _generateMergePreview();
        widget.onMergeStrategyChanged?.call(_fieldStrategies);
      },
      itemBuilder: (context) => MergeFieldStrategy.values.map((strategy) {
        return PopupMenuItem(
          value: strategy,
          child: Row(
            children: [
              Icon(
                _getStrategyIcon(strategy),
                size: 16,
                color: _getStrategyColor(context, strategy),
              ),
              const SizedBox(width: 8),
              Text(_getStrategyLabel(strategy)),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getStrategyColor(context, currentStrategy)
              .withValues(alpha: 0.1 * 255),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _getStrategyColor(context, currentStrategy)
                .withValues(alpha: 0.3 * 255),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getStrategyIcon(currentStrategy),
              size: 14,
              color: _getStrategyColor(context, currentStrategy),
            ),
            const SizedBox(width: 4),
            Text(
              _getStrategyLabel(currentStrategy),
              style: theme.textTheme.labelSmall?.copyWith(
                color: _getStrategyColor(context, currentStrategy),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: _getStrategyColor(context, currentStrategy),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMergeResultSection(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resultado de Fusión',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: 0.3 * 255),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: colors.primary.withValues(alpha: 0.3 * 255)),
          ),
          child: _previewEntity != null
              ? _buildEntityPreview(context, _previewEntity!)
              : _buildNoPreviewMessage(context),
        ),
      ],
    );
  }

  Widget _buildEntityPreview(BuildContext context, T entity) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.preview,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Vista previa del resultado fusionado:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8 * 255),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildEntityDetails(context, entity),
      ],
    );
  }

  Widget _buildNoPreviewMessage(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          Icons.info_outline,
          size: 16,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5 * 255),
        ),
        const SizedBox(width: 8),
        Text(
          'Vista previa no disponible',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7 * 255),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
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

  Widget _buildWatchedMovieDetails(
      BuildContext context, SyncableWatchedMovie movie) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Película', movie.movieTitle),
        _buildDetailRow(
            'Calificación', movie.rating?.toString() ?? 'Sin calificar'),
        _buildDetailRow('Visto el', _formatDate(movie.watchedDate)),
        if (movie.personalNotes != null && movie.personalNotes!.isNotEmpty)
          _buildDetailRow('Reseña', movie.personalNotes!, maxLines: 2),
      ],
    );
  }

  Widget _buildWatchlistItemDetails(
      BuildContext context, SyncableWatchlistItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Película', item.movieTitle),
        _buildDetailRow('Agregado', _formatDate(item.addedAt)),
        _buildDetailRow('Prioridad', item.priority.toString() ?? 'Normal'),
        if (item.personalNotes != null && item.personalNotes!.isNotEmpty)
          _buildDetailRow('Notas', item.personalNotes!, maxLines: 2),
      ],
    );
  }

  Widget _buildCustomListDetails(
      BuildContext context, SyncableCustomList list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Nombre', list.name),
        if (list.description != null && list.description!.isNotEmpty)
          _buildDetailRow('Descripción', list.description!, maxLines: 2),
        _buildDetailRow('Películas', '${list.movieIds.length} elementos'),
      ],
    );
  }

  Widget _buildGenericEntityDetails(BuildContext context, T entity) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('ID', entity.id),
        _buildDetailRow('Tipo', entity.entityType),
        _buildDetailRow('Usuario', entity.userId ?? 'N/A'),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {int maxLines = 1}) {
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
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7 * 255),
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

  Future<void> _generateMergePreview() async {
    setState(() {
      _isGeneratingPreview = true;
      _previewError = null;
    });

    try {
      // Simular generación de vista previa usando ConflictResolver
      final resolver = ConflictResolver();
      final resolution = await resolver.resolveConflict(
        widget.conflict,
        overrideStrategy: ConflictStrategy.merge,
      );

      if (mounted) {
        setState(() {
          _previewEntity = resolution.resolvedEntity as T?;
          _isGeneratingPreview = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _previewError = e.toString();
          _isGeneratingPreview = false;
        });
      }
    }
  }

  List<MergeableField> _getEntityFields() {
    // Implementación específica por tipo de entidad
    if (widget.conflict.localEntity is SyncableWatchedMovie) {
      return _getWatchedMovieFields();
    } else if (widget.conflict.localEntity is SyncableWatchlistItem) {
      return _getWatchlistItemFields();
    } else if (widget.conflict.localEntity is SyncableCustomList) {
      return _getCustomListFields();
    }

    return _getGenericEntityFields();
  }

  List<MergeableField> _getWatchedMovieFields() {
    final local = widget.conflict.localEntity as SyncableWatchedMovie;
    final remote = widget.conflict.remoteEntity as SyncableWatchedMovie;

    return [
      MergeableField(
        name: 'rating',
        displayName: 'Calificación',
        localValue: local.rating?.toString() ?? 'Sin calificar',
        remoteValue: remote.rating?.toString() ?? 'Sin calificar',
        hasConflict: local.rating != remote.rating,
        recommendedStrategy: local.rating != remote.rating
            ? MergeFieldStrategy.useNewer
            : MergeFieldStrategy.keepLocal,
      ),
      MergeableField(
        name: 'personalNotes',
        displayName: 'Reseña',
        localValue: local.personalNotes ?? '',
        remoteValue: remote.personalNotes ?? '',
        hasConflict: local.personalNotes != remote.personalNotes,
        recommendedStrategy: (local.personalNotes?.isNotEmpty == true &&
                remote.personalNotes?.isNotEmpty == true)
            ? MergeFieldStrategy.concatenate
            : MergeFieldStrategy.useLonger,
      ),
      MergeableField(
        name: 'watchedDate',
        displayName: 'Fecha de visualización',
        localValue: _formatDate(local.watchedDate),
        remoteValue: _formatDate(remote.watchedDate),
        hasConflict: local.watchedDate != remote.watchedDate,
        recommendedStrategy: MergeFieldStrategy.useNewer,
      ),
    ];
  }

  List<MergeableField> _getWatchlistItemFields() {
    final local = widget.conflict.localEntity as SyncableWatchlistItem;
    final remote = widget.conflict.remoteEntity as SyncableWatchlistItem;

    return [
      MergeableField(
        name: 'priority',
        displayName: 'Prioridad',
        localValue: local.priority.toString() ?? 'Normal',
        remoteValue: remote.priority.toString() ?? 'Normal',
        hasConflict: local.priority != remote.priority,
        recommendedStrategy: MergeFieldStrategy.useHigher,
      ),
      MergeableField(
        name: 'personalNotes',
        displayName: 'Notas',
        localValue: local.personalNotes ?? '',
        remoteValue: remote.personalNotes ?? '',
        hasConflict: local.personalNotes != remote.personalNotes,
        recommendedStrategy: (local.personalNotes?.isNotEmpty == true &&
                remote.personalNotes?.isNotEmpty == true)
            ? MergeFieldStrategy.concatenate
            : MergeFieldStrategy.useLonger,
      ),
    ];
  }

  List<MergeableField> _getCustomListFields() {
    final local = widget.conflict.localEntity as SyncableCustomList;
    final remote = widget.conflict.remoteEntity as SyncableCustomList;

    return [
      MergeableField(
        name: 'name',
        displayName: 'Nombre',
        localValue: local.name,
        remoteValue: remote.name,
        hasConflict: local.name != remote.name,
        recommendedStrategy: MergeFieldStrategy.useNewer,
      ),
      MergeableField(
        name: 'description',
        displayName: 'Descripción',
        localValue: local.description ?? '',
        remoteValue: remote.description ?? '',
        hasConflict: local.description != remote.description,
        recommendedStrategy: MergeFieldStrategy.useLonger,
      ),
      MergeableField(
        name: 'movieIds',
        displayName: 'Películas',
        localValue: '${local.movieIds.length} elementos',
        remoteValue: '${remote.movieIds.length} elementos',
        hasConflict: !_listsEqual(local.movieIds, remote.movieIds),
        recommendedStrategy: MergeFieldStrategy.union,
      ),
    ];
  }

  List<MergeableField> _getGenericEntityFields() {
    final local = widget.conflict.localEntity;
    final remote = widget.conflict.remoteEntity;

    return [
      MergeableField(
        name: 'lastModifiedAt',
        displayName: 'Fecha de modificación',
        localValue: _formatDate(local.lastModifiedAt),
        remoteValue: _formatDate(remote.lastModifiedAt),
        hasConflict: local.lastModifiedAt != remote.lastModifiedAt,
        recommendedStrategy: MergeFieldStrategy.useNewer,
      ),
    ];
  }

  int _getConflictingFieldsCount() {
    return _getEntityFields().where((field) => field.hasConflict).length;
  }

  IconData _getStrategyIcon(MergeFieldStrategy strategy) {
    switch (strategy) {
      case MergeFieldStrategy.keepLocal:
        return Icons.phone_android;
      case MergeFieldStrategy.keepRemote:
        return Icons.cloud;
      case MergeFieldStrategy.useNewer:
        return Icons.schedule;
      case MergeFieldStrategy.useOlder:
        return Icons.history;
      case MergeFieldStrategy.useLonger:
        return Icons.text_fields;
      case MergeFieldStrategy.useShorter:
        return Icons.short_text;
      case MergeFieldStrategy.useHigher:
        return Icons.arrow_upward;
      case MergeFieldStrategy.useLower:
        return Icons.arrow_downward;
      case MergeFieldStrategy.concatenate:
        return Icons.merge;
      case MergeFieldStrategy.union:
        return Icons.join_inner;
      case MergeFieldStrategy.intersection:
        return Icons.join_full;
    }
  }

  Color _getStrategyColor(BuildContext context, MergeFieldStrategy strategy) {
    final colors = Theme.of(context).colorScheme;

    switch (strategy) {
      case MergeFieldStrategy.keepLocal:
        return colors.tertiary;
      case MergeFieldStrategy.keepRemote:
        return colors.secondary;
      case MergeFieldStrategy.useNewer:
      case MergeFieldStrategy.useOlder:
        return colors.primary;
      case MergeFieldStrategy.useLonger:
      case MergeFieldStrategy.useShorter:
        return colors.outline;
      case MergeFieldStrategy.useHigher:
      case MergeFieldStrategy.useLower:
        return colors.error;
      case MergeFieldStrategy.concatenate:
      case MergeFieldStrategy.union:
      case MergeFieldStrategy.intersection:
        return colors.primary;
    }
  }

  String _getStrategyLabel(MergeFieldStrategy strategy) {
    switch (strategy) {
      case MergeFieldStrategy.keepLocal:
        return 'Local';
      case MergeFieldStrategy.keepRemote:
        return 'Remoto';
      case MergeFieldStrategy.useNewer:
        return 'Más nuevo';
      case MergeFieldStrategy.useOlder:
        return 'Más antiguo';
      case MergeFieldStrategy.useLonger:
        return 'Más largo';
      case MergeFieldStrategy.useShorter:
        return 'Más corto';
      case MergeFieldStrategy.useHigher:
        return 'Mayor';
      case MergeFieldStrategy.useLower:
        return 'Menor';
      case MergeFieldStrategy.concatenate:
        return 'Concatenar';
      case MergeFieldStrategy.union:
        return 'Unión';
      case MergeFieldStrategy.intersection:
        return 'Intersección';
    }
  }

  bool _listsEqual<E>(List<E> list1, List<E> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Clase para representar un campo fusionable
class MergeableField {
  const MergeableField({
    required this.name,
    required this.displayName,
    required this.localValue,
    required this.remoteValue,
    required this.hasConflict,
    required this.recommendedStrategy,
  });

  final String name;
  final String displayName;
  final String localValue;
  final String remoteValue;
  final bool hasConflict;
  final MergeFieldStrategy recommendedStrategy;
}

/// Estrategias de fusión por campo
enum MergeFieldStrategy {
  keepLocal,
  keepRemote,
  useNewer,
  useOlder,
  useLonger,
  useShorter,
  useHigher,
  useLower,
  concatenate,
  union,
  intersection,
}
