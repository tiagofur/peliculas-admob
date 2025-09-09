import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/conflict_resolution/strategies/conflict_strategy.dart'
    as strategy;
import '../../../core/sync/conflict_resolver.dart';
import '../../../core/sync/entity_sync_manager.dart';
import '../../../domain/entities/syncable_entity.dart';
import '../../providers/sync_integration_provider.dart' as integration;
import 'conflict_preview_widget.dart';
import 'merge_preview_widget.dart';

/// Modal principal para resolver conflictos de sincronización
class ConflictResolutionDialog<T extends SyncableEntity>
    extends ConsumerStatefulWidget {
  const ConflictResolutionDialog({
    super.key,
    required this.conflict,
    required this.onResolved,
    this.allowMerge = true,
    this.showPreview = true,
  });

  final ConflictInfo<T> conflict;
  final Function(ConflictResolution) onResolved;
  final bool allowMerge;
  final bool showPreview;

  @override
  ConsumerState<ConflictResolutionDialog<T>> createState() =>
      _ConflictResolutionDialogState<T>();
}

class _ConflictResolutionDialogState<T extends SyncableEntity>
    extends ConsumerState<ConflictResolutionDialog<T>> {
  ConflictStrategy? _selectedStrategy;
  bool _isResolving = false;
  String? _errorMessage;
  bool _showAdvancedOptions = false;

  @override
  void initState() {
    super.initState();
    _selectedStrategy = _getRecommendedStrategy();
  }

  ConflictStrategy _getRecommendedStrategy() {
    // Lógica para recomendar estrategia basada en el tipo de conflicto
    switch (widget.conflict.conflictType) {
      case ConflictType.deleteVsModify:
        return ConflictStrategy.userChoice;
      case ConflictType.concurrentModification:
        return widget.allowMerge
            ? ConflictStrategy.merge
            : ConflictStrategy.localWins;
      case ConflictType.duplicateCreation:
        return ConflictStrategy.remoteWins;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: colors.error,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _getDialogTitle(),
              style: theme.textTheme.titleLarge?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConflictDescription(),
              const SizedBox(height: 16),
              _buildStrategySelection(),
              if (widget.showPreview && _selectedStrategy != null) ...[
                const SizedBox(height: 16),
                _buildPreviewSection(),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                _buildErrorMessage(),
              ],
              const SizedBox(height: 8),
              _buildAdvancedOptionsToggle(),
              if (_showAdvancedOptions) ...[
                const SizedBox(height: 12),
                _buildAdvancedOptions(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isResolving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isResolving || _selectedStrategy == null
              ? null
              : _resolveConflict,
          child: _isResolving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Resolver'),
        ),
      ],
    );
  }

  Widget _buildConflictDescription() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detalles del Conflicto',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          _buildConflictDetail('Tipo', _getConflictTypeDescription()),
          _buildConflictDetail(
              'Entidad', widget.conflict.localEntity.entityType),
          _buildConflictDetail(
              'Detectado', _formatDateTime(widget.conflict.detectedAt)),
          if (widget.conflict.metadata != null) ..._buildMetadataDetails(),
        ],
      ),
    );
  }

  Widget _buildConflictDetail(String label, String value) {
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
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMetadataDetails() {
    final metadata = widget.conflict.metadata!;
    return [
      _buildConflictDetail(
          'Versión Local', metadata['local_version']?.toString() ?? 'N/A'),
      _buildConflictDetail(
          'Versión Remota', metadata['remote_version']?.toString() ?? 'N/A'),
      _buildConflictDetail(
          'Modificado Local',
          _formatDateTime(DateTime.tryParse(metadata['local_modified'] ?? '') ??
              DateTime.now())),
      _buildConflictDetail(
          'Modificado Remoto',
          _formatDateTime(
              DateTime.tryParse(metadata['remote_modified'] ?? '') ??
                  DateTime.now())),
    ];
  }

  Widget _buildStrategySelection() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estrategia de Resolución',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Column(
          children: ConflictStrategy.values.where((strategy) {
            return widget.allowMerge || strategy != ConflictStrategy.merge;
          }).map((strategy) {
            return ListTile(
              title: Text(_getStrategyTitle(strategy)),
              subtitle: Text(
                _getStrategyDescription(strategy),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              leading: Radio<ConflictStrategy>(
                value: strategy,
                groupValue: _selectedStrategy,
                onChanged: _isResolving
                    ? null
                    : (value) {
                        setState(() {
                          _selectedStrategy = value;
                          _errorMessage = null;
                        });
                      },
              ),
              onTap: _isResolving
                  ? null
                  : () {
                      setState(() {
                        _selectedStrategy = strategy;
                        _errorMessage = null;
                      });
                    },
              dense: true,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPreviewSection() {
    if (_selectedStrategy == null) return const SizedBox.shrink();

    switch (_selectedStrategy!) {
      case ConflictStrategy.merge:
        return MergePreviewWidget<T>(
          conflict: widget.conflict,
          compact: true,
        );
      case ConflictStrategy.localWins:
      case ConflictStrategy.remoteWins:
      case ConflictStrategy.userChoice:
        return ConflictPreviewWidget<T>(
          conflict: widget.conflict,
          selectedStrategy: _selectedStrategy!,
          compact: true,
        );
    }
  }

  Widget _buildErrorMessage() {
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
            child: Text(
              _errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedOptionsToggle() {
    return TextButton.icon(
      onPressed: () {
        setState(() {
          _showAdvancedOptions = !_showAdvancedOptions;
        });
      },
      icon: Icon(
        _showAdvancedOptions ? Icons.expand_less : Icons.expand_more,
        size: 20,
      ),
      label: Text(
        _showAdvancedOptions
            ? 'Ocultar opciones avanzadas'
            : 'Mostrar opciones avanzadas',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildAdvancedOptions() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información Técnica',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (widget.conflict.metadata != null) ...[
            _buildConflictDetail(
                'Checksum Local',
                widget.conflict.metadata!['local_checksum']?.toString() ??
                    'N/A'),
            _buildConflictDetail(
                'Checksum Remoto',
                widget.conflict.metadata!['remote_checksum']?.toString() ??
                    'N/A'),
          ],
          _buildConflictDetail('ID Entidad', widget.conflict.localEntity.id),
          _buildConflictDetail(
              'Usuario ID', widget.conflict.localEntity.userId),
        ],
      ),
    );
  }

  Future<void> _resolveConflict() async {
    if (_selectedStrategy == null) return;

    setState(() {
      _isResolving = true;
      _errorMessage = null;
    });

    try {
      final resolver = ConflictResolver();
      final resolution = await resolver.resolveConflict(
        widget.conflict,
        overrideStrategy: _selectedStrategy,
      );

      // Notificar al provider de integración sobre la resolución
      if (mounted) {
        // Convertir ConflictStrategy a ConflictResolutionStrategy local
        final localStrategy = _convertToLocalStrategy(_selectedStrategy!);
        ref
            .read(integration.syncIntegrationProvider.notifier)
            .onConflictResolved(
              widget.conflict.localEntity.id,
              localStrategy,
            );

        widget.onResolved(resolution);
        Navigator.of(context).pop(resolution);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al resolver conflicto: ${e.toString()}';
          _isResolving = false;
        });
      }
    }
  }

  String _getDialogTitle() {
    switch (widget.conflict.conflictType) {
      case ConflictType.concurrentModification:
        return 'Modificación Concurrente';
      case ConflictType.deleteVsModify:
        return 'Eliminación vs Modificación';
      case ConflictType.duplicateCreation:
        return 'Creación Duplicada';
    }
  }

  String _getConflictTypeDescription() {
    switch (widget.conflict.conflictType) {
      case ConflictType.concurrentModification:
        return 'La misma entidad fue modificada en múltiples dispositivos';
      case ConflictType.deleteVsModify:
        return 'Una entidad fue eliminada en un dispositivo y modificada en otro';
      case ConflictType.duplicateCreation:
        return 'La misma entidad fue creada en múltiples dispositivos';
    }
  }

  String _getStrategyTitle(ConflictStrategy strategy) {
    switch (strategy) {
      case ConflictStrategy.localWins:
        return 'Mantener Versión Local';
      case ConflictStrategy.remoteWins:
        return 'Usar Versión Remota';
      case ConflictStrategy.merge:
        return 'Fusionar Cambios';
      case ConflictStrategy.userChoice:
        return 'Resolución Manual';
    }
  }

  String _getStrategyDescription(ConflictStrategy strategy) {
    switch (strategy) {
      case ConflictStrategy.localWins:
        return 'Conservar los cambios realizados en este dispositivo';
      case ConflictStrategy.remoteWins:
        return 'Adoptar los cambios del servidor/otros dispositivos';
      case ConflictStrategy.merge:
        return 'Combinar automáticamente los cambios de ambas versiones';
      case ConflictStrategy.userChoice:
        return 'Permitir selección manual de campos específicos';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Hace unos segundos';
    } else if (difference.inHours < 1) {
      return 'Hace ${difference.inMinutes} minutos';
    } else if (difference.inDays < 1) {
      return 'Hace ${difference.inHours} horas';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Convierte ConflictStrategy a ConflictResolutionStrategy local
  strategy.ConflictResolutionStrategy _convertToLocalStrategy(
      ConflictStrategy conflictStrategy) {
    switch (conflictStrategy) {
      case ConflictStrategy.localWins:
        return strategy.ConflictResolutionStrategy.clientWins;
      case ConflictStrategy.remoteWins:
        return strategy.ConflictResolutionStrategy.serverWins;
      case ConflictStrategy.merge:
        return strategy.ConflictResolutionStrategy.merge;
      case ConflictStrategy.userChoice:
        return strategy.ConflictResolutionStrategy.userChoice;
    }
  }
}

/// Función helper para mostrar el diálogo de resolución de conflictos
Future<ConflictResolution?>
    showConflictResolutionDialog<T extends SyncableEntity>({
  required BuildContext context,
  required ConflictInfo<T> conflict,
  bool allowMerge = true,
  bool showPreview = true,
}) {
  return showDialog<ConflictResolution>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ConflictResolutionDialog<T>(
      conflict: conflict,
      onResolved: (resolution) {},
      allowMerge: allowMerge,
      showPreview: showPreview,
    ),
  );
}
