import 'package:flutter/material.dart';

import '../../../core/sync/conflict_resolution/multiplatform_conflict_resolver.dart';

/// Widget que muestra información sobre conflictos resueltos al usuario
class ConflictNotificationWidget extends StatelessWidget {
  const ConflictNotificationWidget({
    super.key,
    required this.conflictResolution,
    this.onDismiss,
    this.showDetails = false,
  });

  final ConflictResolutionResult conflictResolution;
  final VoidCallback? onDismiss;
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _getColorsForSeverity(conflictResolution.severity, theme);

    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      color: colors.backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getIconForSeverity(conflictResolution.severity),
                  color: colors.iconColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getTitle(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onDismiss,
                    color: colors.iconColor,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              conflictResolution.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textColor.withValues(alpha: 0.8),
              ),
            ),
            if (showDetails) ...[
              const SizedBox(height: 8),
              _buildDetailsSection(theme, colors),
            ],
            if (conflictResolution.requiresManualIntervention) ...[
              const SizedBox(height: 12),
              _buildManualInterventionSection(theme, colors),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection(ThemeData theme, _ConflictColors colors) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: colors.backgroundColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detalles técnicos:',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tipo: ${_getConflictTypeDisplayName(conflictResolution.conflictType)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textColor.withValues(alpha: 0.7),
            ),
          ),
          Text(
            'Estrategia: ${conflictResolution.resolution}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textColor.withValues(alpha: 0.7),
            ),
          ),
          if (conflictResolution.dataLoss)
            Text(
              'Nota: Se perdieron algunos datos durante la resolución',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.warningColor,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildManualInterventionSection(
      ThemeData theme, _ConflictColors colors) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border.all(color: colors.warningColor, width: 1),
        borderRadius: BorderRadius.circular(8),
        color: colors.warningColor.withValues(alpha: 0.1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning,
            color: colors.warningColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Este conflicto podría requerir tu atención. Revisa los cambios para confirmar que son correctos.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.warningColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (conflictResolution.conflictType) {
      case ConflictType.simultaneousModification:
        return 'Cambios simultáneos resueltos';
      case ConflictType.simultaneousAddition:
        return 'Adiciones simultáneas combinadas';
      case ConflictType.deletionVsModification:
      case ConflictType.modificationVsDeletion:
        return 'Conflicto de eliminación resuelto';
      case ConflictType.listConflict:
        return 'Conflicto de lista resuelto';
    }
  }

  String _getConflictTypeDisplayName(ConflictType type) {
    switch (type) {
      case ConflictType.simultaneousModification:
        return 'Modificaciones simultáneas';
      case ConflictType.simultaneousAddition:
        return 'Adiciones simultáneas';
      case ConflictType.deletionVsModification:
        return 'Eliminación vs Modificación';
      case ConflictType.modificationVsDeletion:
        return 'Modificación vs Eliminación';
      case ConflictType.listConflict:
        return 'Conflicto de lista';
    }
  }

  IconData _getIconForSeverity(ConflictSeverity severity) {
    switch (severity) {
      case ConflictSeverity.low:
        return Icons.info_outline;
      case ConflictSeverity.medium:
        return Icons.warning_amber_outlined;
      case ConflictSeverity.high:
        return Icons.error_outline;
    }
  }

  _ConflictColors _getColorsForSeverity(
      ConflictSeverity severity, ThemeData theme) {
    switch (severity) {
      case ConflictSeverity.low:
        return _ConflictColors(
          backgroundColor: Colors.blue.withValues(alpha: 0.1),
          iconColor: Colors.blue,
          textColor: theme.colorScheme.onSurface,
          warningColor: Colors.orange,
        );
      case ConflictSeverity.medium:
        return _ConflictColors(
          backgroundColor: Colors.orange.withValues(alpha: 0.1),
          iconColor: Colors.orange,
          textColor: theme.colorScheme.onSurface,
          warningColor: Colors.deepOrange,
        );
      case ConflictSeverity.high:
        return _ConflictColors(
          backgroundColor: Colors.red.withValues(alpha: 0.1),
          iconColor: Colors.red,
          textColor: theme.colorScheme.onSurface,
          warningColor: Colors.red,
        );
    }
  }
}

class _ConflictColors {
  const _ConflictColors({
    required this.backgroundColor,
    required this.iconColor,
    required this.textColor,
    required this.warningColor,
  });

  final Color backgroundColor;
  final Color iconColor;
  final Color textColor;
  final Color warningColor;
}

/// Widget que muestra un resumen de estadísticas de conflictos
class ConflictStatsWidget extends StatelessWidget {
  const ConflictStatsWidget({
    super.key,
    required this.conflictStats,
    this.onViewDetails,
  });

  final Map<String, dynamic> conflictStats;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalConflicts = conflictStats['totalConflicts'] as int? ?? 0;

    if (totalConflicts == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync_problem, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Estadísticas de Sincronización',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (onViewDetails != null)
                  TextButton(
                    onPressed: onViewDetails,
                    child: const Text('Ver detalles'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Conflictos resueltos: $totalConflicts',
              style: theme.textTheme.bodyMedium,
            ),
            if (conflictStats['dataLossIncidents'] != null &&
                conflictStats['dataLossIncidents'] > 0)
              Text(
                'Incidentes con pérdida de datos: ${conflictStats['dataLossIncidents']}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
