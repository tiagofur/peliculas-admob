import 'package:flutter/material.dart';

import '../../../domain/entities/entities.dart';

class AchievementCard extends StatelessWidget {
  const AchievementCard({super.key, required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: achievement.isUnlocked ? 4 : 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: achievement.isUnlocked
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primaryContainer,
                    colors.primaryContainer.withValues(alpha: 0.7),
                  ],
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Ícono del logro
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: achievement.isUnlocked
                      ? colors.primary
                      : colors.outline.withValues(alpha: 0.3),
                ),
                child: Icon(
                  _getIconData(achievement.iconName),
                  size: 30,
                  color: achievement.isUnlocked
                      ? colors.onPrimary
                      : colors.outline,
                ),
              ),
              const SizedBox(width: 16),
              // Información del logro
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      achievement.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: achievement.isUnlocked
                            ? colors.onPrimaryContainer
                            : colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achievement.description,
                      style: textTheme.bodyMedium?.copyWith(
                        color: achievement.isUnlocked
                            ? colors.onPrimaryContainer.withValues(alpha: 0.8)
                            : colors.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Barra de progreso
                    if (!achievement.isUnlocked) ...[
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: achievement.progress,
                              backgroundColor:
                                  colors.outline.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colors.primary.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${achievement.currentValue}/${achievement.targetValue}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Fecha de desbloqueo
                      if (achievement.unlockedDate != null)
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Desbloqueado el ${achievement.unlockedDate != null ? _formatDate(achievement.unlockedDate!) : 'Fecha desconocida'}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.onPrimaryContainer
                                    .withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
              // Badge de categoría
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _getCategoryColor(achievement.category, colors),
                ),
                child: Text(
                  _getCategoryName(achievement.category),
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'visibility':
        return Icons.visibility;
      case 'explore':
        return Icons.explore;
      case 'movie':
        return Icons.movie;
      case 'star':
        return Icons.star;
      case 'favorite':
        return Icons.favorite;
      case 'favorite_border':
        return Icons.favorite_border;
      case 'category':
        return Icons.category;
      case 'schedule':
        return Icons.schedule;
      default:
        return Icons.emoji_events;
    }
  }

  Color _getCategoryColor(AchievementCategory category, ColorScheme colors) {
    switch (category) {
      case AchievementCategory.movies:
        return colors.primary;
      case AchievementCategory.favorites:
        return Colors.red.shade400;
      case AchievementCategory.exploration:
        return Colors.green.shade400;
      case AchievementCategory.social:
        return Colors.blue.shade400;
    }
  }

  String _getCategoryName(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.movies:
        return 'Películas';
      case AchievementCategory.favorites:
        return 'Favoritos';
      case AchievementCategory.exploration:
        return 'Exploración';
      case AchievementCategory.social:
        return 'Social';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
