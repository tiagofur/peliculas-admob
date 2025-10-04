import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/entities/achievement.dart';
import '../providers/achievements_from_stats_provider.dart';

/// Pantalla principal de logros y gamificación - Versión simplificada usando estadísticas reales
class AchievementsScreenNew extends ConsumerStatefulWidget {
  const AchievementsScreenNew({
    super.key,
    required this.userId,
  });
  final String userId;

  @override
  ConsumerState<AchievementsScreenNew> createState() =>
      _AchievementsScreenNewState();
}

class _AchievementsScreenNewState extends ConsumerState<AchievementsScreenNew> {
  @override
  void initState() {
    super.initState();
    LoggerFactory.info(
        'AchievementsScreenNew inicializada para usuario: ${widget.userId}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Logros'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: _buildAchievementsContent(),
    );
  }

  /// Contenido principal de logros - usa estadísticas reales
  Widget _buildAchievementsContent() {
    final achievementsAsync = ref.watch(achievementsFromStatsProvider);
    final stats = ref.watch(achievementStatsFromRealDataProvider);

    return achievementsAsync.when(
      loading: () => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Calculando logros desde estadísticas...'),
          ],
        ),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error al cargar logros: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(achievementsFromStatsProvider),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
      data: (achievements) {
        if (achievements.isEmpty) {
          return const Center(
            child: Text('No hay logros disponibles'),
          );
        }

        return CustomScrollView(
          slivers: [
            // Header con estadísticas
            SliverToBoxAdapter(
              child: _buildStatsHeader(stats),
            ),

            // Logros desbloqueados
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Desbloqueados (${stats.unlockedAchievements}/${stats.totalAchievements})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final unlockedAchievements = achievements
                      .where((a) => a.isUnlocked)
                      .toList()
                    ..sort((a, b) =>
                        b.achievement.points.compareTo(a.achievement.points));

                  if (index >= unlockedAchievements.length) return null;

                  return _buildAchievementCard(unlockedAchievements[index]);
                },
              ),
            ),

            // Logros bloqueados
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'En progreso (${stats.lockedAchievements})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final lockedAchievements = achievements
                      .where((a) => !a.isUnlocked)
                      .toList()
                    ..sort((a, b) =>
                        b.progressPercentage.compareTo(a.progressPercentage));

                  if (index >= lockedAchievements.length) return null;

                  return _buildAchievementCard(lockedAchievements[index]);
                },
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        );
      },
    );
  }

  Widget _buildStatsHeader(AchievementStatsFromRealData stats) {
    final theme = Theme.of(context);
    final completionPercentage = (stats.completionPercentage * 100).toInt();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Logros',
                '${stats.unlockedAchievements}/${stats.totalAchievements}',
                Icons.emoji_events,
              ),
              _buildStatItem(
                'Puntos',
                '${stats.totalPoints}',
                Icons.star,
              ),
              _buildStatItem(
                'Completado',
                '$completionPercentage%',
                Icons.trending_up,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: stats.completionPercentage,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 32, color: theme.colorScheme.onPrimaryContainer),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementCard(
      AchievementWithProgress achievementWithProgress) {
    final achievement = achievementWithProgress.achievement;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  achievement.isUnlocked
                      ? Icons.emoji_events
                      : Icons.lock_outline,
                  size: 40,
                  color: achievement.isUnlocked
                      ? Colors.amber
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        achievement.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        achievement.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getRarityColor(achievement.rarity)
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '+${achievement.points}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getRarityColor(achievement.rarity),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (!achievement.isUnlocked) ...[
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${achievementWithProgress.currentProgress} / ${achievement.targetValue}',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        '${(achievementWithProgress.progressPercentage * 100).toInt()}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: achievementWithProgress.progressPercentage,
                      minHeight: 6,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor:
                          AlwaysStoppedAnimation(theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getRarityColor(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return Colors.grey;
      case AchievementRarity.uncommon:
        return Colors.green;
      case AchievementRarity.rare:
        return Colors.blue;
      case AchievementRarity.epic:
        return Colors.purple;
      case AchievementRarity.legendary:
        return Colors.orange;
    }
  }
}
