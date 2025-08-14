import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/entities.dart';
import '../../providers/achievements/achievements_provider.dart';
import '../../widgets/widgets.dart';

class AchievementsView extends ConsumerWidget {
  const AchievementsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementsState = ref.watch(achievementsProvider);
    final colors = Theme.of(context).colorScheme;

    if (achievementsState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (achievementsState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: colors.error),
            const SizedBox(height: 16),
            Text(
              'Error al cargar logros',
              style: TextStyle(fontSize: 18, color: colors.error),
            ),
            const SizedBox(height: 8),
            Text(
              achievementsState.error!,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(achievementsProvider.notifier).refresh(),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final achievements = achievementsState.achievements;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          if (achievements.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No hay logros disponibles',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final achievement = achievements[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AchievementCardWithShare(
                        achievement: achievement,
                      ),
                    );
                  },
                  childCount: achievements.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AchievementCardWithShare extends StatelessWidget {
  const _AchievementCardWithShare({
    required this.achievement,
  });

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: achievement.isUnlocked
              ? LinearGradient(
                  colors: [
                    Colors.amber.shade100,
                    Colors.orange.shade50,
                  ],
                )
              : null,
        ),
        child: Row(
          children: [
            // Ícono del logro
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: achievement.isUnlocked
                    ? Colors.amber.shade600
                    : Colors.grey.shade400,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getAchievementIcon(achievement.id),
                color: Colors.white,
                size: 30,
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Progreso
                  if (!achievement.isUnlocked)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          value: _getAchievementProgress(achievement),
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.amber.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${achievement.currentValue}/${achievement.targetValue}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  if (achievement.isUnlocked)
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Desbloqueado',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Botón de compartir (solo para logros desbloqueados)
            if (achievement.isUnlocked)
              IconButton(
                onPressed: () => _showShareDialog(context, achievement),
                icon: const Icon(Icons.share),
                tooltip: 'Compartir logro',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.amber.shade100,
                  foregroundColor: Colors.amber.shade800,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getAchievementIcon(String achievementId) {
    switch (achievementId) {
      case 'first_movie':
        return Icons.play_circle_filled;
      case 'movie_explorer':
        return Icons.explore;
      case 'movie_enthusiast':
        return Icons.local_movies;
      case 'movie_master':
        return Icons.star;
      case 'cinema_legend':
        return Icons.military_tech;
      case 'marathon_runner':
        return Icons.speed;
      case 'first_favorite':
        return Icons.favorite;
      case 'favorite_collector':
        return Icons.collections;
      case 'favorite_curator':
        return Icons.auto_awesome;
      case 'quality_seeker':
        return Icons.diamond;
      case 'genre_explorer':
        return Icons.category;
      case 'genre_master':
        return Icons.psychology;
      case 'nostalgic':
        return Icons.history;
      case 'blockbuster_fan':
        return Icons.whatshot;
      case 'indie_discoverer':
        return Icons.lightbulb;
      case 'aligned_critic':
        return Icons.thumb_up;
      case 'list_creator':
        return Icons.playlist_add;
      case 'expert_organizer':
        return Icons.folder_special;
      case 'decade_traveler':
        return Icons.access_time;
      default:
        return Icons.emoji_events;
    }
  }

  void _showShareDialog(BuildContext context, Achievement achievement) {
    showDialog(
      context: context,
      builder: (context) => AchievementShareDialog(achievement: achievement),
    );
  }

  double _getAchievementProgress(Achievement achievement) {
    return (achievement.currentValue / achievement.targetValue).clamp(0.0, 1.0);
  }
}
