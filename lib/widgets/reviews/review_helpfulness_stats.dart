import 'package:flutter/material.dart';

import '../../models/rating_helpfulness.dart';

/// Widget para mostrar estadísticas detalladas de utilidad de reseñas
class ReviewHelpfulnessStats extends StatelessWidget {
  const ReviewHelpfulnessStats({
    super.key,
    required this.stats,
    this.showDescription = true,
    this.compact = false,
  });
  final RatingHelpfulnessStats stats;
  final bool showDescription;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactStats(context);
    }

    return _buildDetailedStats(context);
  }

  Widget _buildCompactStats(BuildContext context) {
    final theme = Theme.of(context);

    if (stats.totalVotes == 0) {
      return Text(
        'Sin votos aún',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icono de utilidad
        Icon(
          stats.isMostlyHelpful ? Icons.thumb_up : Icons.thumbs_up_down,
          size: 14,
          color: stats.isMostlyHelpful
              ? Colors.green.withValues(alpha: 0.7)
              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 4),

        // Texto descriptivo
        Text(
          stats.helpfulnessDescription,
          style: theme.textTheme.bodySmall?.copyWith(
            color: stats.isMostlyHelpful
                ? Colors.green.withValues(alpha: 0.8)
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: stats.hasSignificantVotes ? FontWeight.w500 : null,
          ),
        ),

        // Total de votos
        Text(
          ' (${stats.totalVotes})',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedStats(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Encabezado
        Row(
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Utilidad de la reseña',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (stats.totalVotes == 0) ...[
          // Estado sin votos
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.help_outline,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
                Text(
                  'Esta reseña aún no tiene votos de utilidad',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Indicador de score principal
          _buildScoreIndicator(context),
          const SizedBox(height: 12),

          // Distribución de votos
          _buildVoteDistribution(context),

          if (showDescription) ...[
            const SizedBox(height: 8),
            _buildDescription(context),
          ],
        ],
      ],
    );
  }

  Widget _buildScoreIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final scorePercentage = (stats.helpfulnessScore * 100).round();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: stats.isMostlyHelpful
              ? [
                  Colors.green.withValues(alpha: 0.1),
                  Colors.green.withValues(alpha: 0.05),
                ]
              : [
                  Colors.orange.withValues(alpha: 0.1),
                  Colors.orange.withValues(alpha: 0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: stats.isMostlyHelpful
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // Icono de estado
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: stats.isMostlyHelpful
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.orange.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              stats.isMostlyHelpful ? Icons.thumb_up : Icons.thumbs_up_down,
              size: 16,
              color: stats.isMostlyHelpful ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Score principal
                Text(
                  '$scorePercentage% útil',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: stats.isMostlyHelpful
                        ? Colors.green.withValues(alpha: 0.9)
                        : Colors.orange.withValues(alpha: 0.9),
                  ),
                ),

                // Descripción del nivel
                Text(
                  stats.helpfulnessDescription,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          // Total de votos
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${stats.totalVotes} votos',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoteDistribution(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // Votos útiles
        Expanded(
          flex: stats.helpfulVotes,
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.7),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                bottomLeft: Radius.circular(4),
              ),
            ),
          ),
        ),

        // Votos no útiles
        Expanded(
          flex: stats.notHelpfulVotes,
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.7),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Leyenda
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Útil (${stats.helpfulVotes})',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'No útil (${stats.notHelpfulVotes})',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescription(BuildContext context) {
    final theme = Theme.of(context);

    String description = '';
    if (!stats.hasSignificantVotes) {
      description =
          'Se necesitan más votos para determinar la utilidad con precisión.';
    } else if (stats.isMostlyHelpful) {
      description = 'La comunidad considera esta reseña útil y bien elaborada.';
    } else {
      description = 'La utilidad de esta reseña es mixta según la comunidad.';
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        description,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
