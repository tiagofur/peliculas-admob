import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/providers/gamification_providers.dart';
import '../achievement_system.dart' hide unlockedAchievementsProvider;
import '../models/achievement.dart';
import 'achievement_card.dart';

/// Widget for displaying achievement grid
class AchievementGridWidget extends ConsumerWidget {
  const AchievementGridWidget({
    super.key,
    this.category,
    this.showOnlyUnlocked = false,
  });

  final AchievementCategory? category;
  final bool showOnlyUnlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(allAchievementsProvider);
    final unlockedAchievements = ref.watch(unlockedAchievementsProvider);
    final unlockedIds = unlockedAchievements.map((a) => a.id).toSet();

    List<Achievement> filteredAchievements = achievements;

    if (category != null) {
      filteredAchievements =
          achievements.where((a) => a.category == category).toList();
    }

    if (showOnlyUnlocked) {
      filteredAchievements = filteredAchievements
          .where((a) => unlockedIds.contains(a.id))
          .toList();
    }

    if (filteredAchievements.isEmpty) {
      return _buildEmptyState(context);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: filteredAchievements.length,
      itemBuilder: (context, index) {
        final achievement = filteredAchievements[index];
        return AchievementCard(
          achievement: achievement,
          isUnlocked: unlockedIds.contains(achievement.id),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            showOnlyUnlocked
                ? 'No achievements unlocked yet'
                : 'No achievements available',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            showOnlyUnlocked
                ? 'Start watching movies to unlock achievements!'
                : 'Check back later for new achievements',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
