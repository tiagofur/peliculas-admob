import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/gamification/widgets/badge_display.dart';
import '../../../core/gamification/widgets/level_progress_indicator.dart';
import '../providers/gamification_providers.dart';

/// Ejemplo de widget para integrar gamificación en el perfil
class GamificationProfileSection extends ConsumerWidget {
  const GamificationProfileSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProgressAsync = ref.watch(userProgressProvider);
    final recentAchievementsAsync = ref.watch(recentAchievementsProvider);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progreso de Gamificación',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // User Progress Section
            userProgressAsync.when(
              data: (progress) => Column(
                children: [
                  // Level and Points
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(
                        context,
                        'Nivel',
                        progress.currentLevel.toString(),
                        Icons.star,
                        Colors.amber,
                      ),
                      _buildStatColumn(
                        context,
                        'Puntos',
                        progress.totalPoints.toString(),
                        Icons.emoji_events,
                        Colors.orange,
                      ),
                      _buildStatColumn(
                        context,
                        'Racha',
                        '${progress.streakDays}d',
                        Icons.local_fire_department,
                        Colors.red,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Level Progress Indicator
                  LevelProgressIndicator(
                    userProgress: progress,
                    showDetails: true,
                  ),

                  const SizedBox(height: 16),

                  // Activity Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(
                        context,
                        'Películas',
                        progress.moviesFavorited.toString(),
                        Icons.movie,
                        Colors.blue,
                      ),
                      _buildStatColumn(
                        context,
                        'Compartidas',
                        progress.moviesShared.toString(),
                        Icons.share,
                        Colors.green,
                      ),
                      _buildStatColumn(
                        context,
                        'Reseñas',
                        progress.reviewsWritten.toString(),
                        Icons.rate_review,
                        Colors.purple,
                      ),
                    ],
                  ),
                ],
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Text(
                'Error cargando progreso: $error',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),

            const SizedBox(height: 20),

            // Recent Achievements Section
            Text(
              'Logros Recientes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            recentAchievementsAsync.when(
              data: (achievements) {
                if (achievements.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.emoji_events_outlined,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Completa actividades para desbloquear logros',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return BadgeDisplay(
                  unlockedAchievements: achievements,
                  showCount: true,
                  maxVisible: 3,
                  onViewAll: () {
                    // Navigate to full achievements view
                    _showAchievementsDialog(context, ref);
                  },
                );
              },
              loading: () => const SizedBox(
                height: 50,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Text(
                'Error cargando logros: $error',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),

            const SizedBox(height: 16),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showFullGamificationView(context),
                icon: const Icon(Icons.emoji_events),
                label: const Text('Ver Todos los Logros'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  void _showAchievementsDialog(BuildContext context, WidgetRef ref) {
    final manager = ref.read(gamificationManagerProvider);
    final allAchievements = manager.getUnlockedAchievements();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mis Logros'),
        content: SizedBox(
          width: double.maxFinite,
          child: allAchievements.isEmpty
              ? const Text('No hay logros desbloqueados aún')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: allAchievements.length,
                  itemBuilder: (context, index) {
                    final achievement = allAchievements[index];
                    return ListTile(
                      leading: const Icon(Icons.star, color: Colors.amber),
                      title: Text(achievement.name),
                      subtitle: Text(achievement.description),
                      trailing: Text('${achievement.points} pts'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showFullGamificationView(BuildContext context) {
    // In a real app, this would navigate to the gamification dashboard
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Aquí se abriría la vista completa de gamificación'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
