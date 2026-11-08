import 'package:flutter/material.dart';

import '../../domain/entities/enhanced_user_profile.dart';

/// Widget para mostrar logros del usuario
class AchievementDisplayWidget extends StatelessWidget {
  const AchievementDisplayWidget({
    super.key,
    required this.achievements,
  });
  final List<UserAchievement> achievements;

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
      return _buildEmptyState();
    }

    // Separar logros desbloqueados y bloqueados
    final unlockedAchievements =
        achievements.where((a) => a.isUnlocked).toList();
    final lockedAchievements =
        achievements.where((a) => !a.isUnlocked).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (unlockedAchievements.isNotEmpty) ...[
          _buildSectionHeader(
            'Logros desbloqueados',
            '${unlockedAchievements.length}/${achievements.length}',
            Icons.emoji_events,
            Colors.amber,
          ),
          const SizedBox(height: 16),
          _buildAchievementsGrid(unlockedAchievements, true),
          const SizedBox(height: 24),
        ],
        if (lockedAchievements.isNotEmpty) ...[
          _buildSectionHeader(
            'Próximos logros',
            '${lockedAchievements.length} por desbloquear',
            Icons.lock,
            Colors.grey,
          ),
          const SizedBox(height: 16),
          _buildAchievementsGrid(lockedAchievements, false),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No tienes logros aún',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Sigue viendo películas para desbloquear logros',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      String title, String subtitle, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementsGrid(
      List<UserAchievement> achievements, bool isUnlocked) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        return _buildAchievementCard(achievements[index], isUnlocked);
      },
    );
  }

  Widget _buildAchievementCard(UserAchievement achievement, bool isUnlocked) {
    return Card(
      elevation: isUnlocked ? 4 : 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isUnlocked
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getAchievementColor(achievement.category)
                        .withValues(alpha: 0.1),
                    _getAchievementColor(achievement.category)
                        .withValues(alpha: 0.05),
                  ],
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícono del logro
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isUnlocked
                          ? _getAchievementColor(achievement.category)
                          : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getAchievementIcon(achievement.category),
                      color: isUnlocked ? Colors.white : Colors.grey[500],
                      size: 24,
                    ),
                  ),
                  if (!isUnlocked)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Título del logro
              Text(
                achievement.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isUnlocked ? null : Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Descripción del logro
              Text(
                achievement.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isUnlocked ? Colors.grey[700] : Colors.grey[500],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              if (isUnlocked && achievement.isUnlocked) ...[
                const SizedBox(height: 4),
                Text(
                  _formatUnlockDate(achievement.unlockedAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: _getAchievementColor(achievement.category),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else if (!isUnlocked) ...[
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: achievement.progress / achievement.target,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getAchievementColor(achievement.category),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${achievement.progress}/${achievement.target}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getAchievementColor(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.watching:
        return Colors.blue;
      case AchievementCategory.rating:
        return Colors.orange;
      case AchievementCategory.social:
        return Colors.pink;
      case AchievementCategory.discovery:
        return Colors.green;
      case AchievementCategory.collector:
        return Colors.purple;
      case AchievementCategory.critic:
        return Colors.amber;
      case AchievementCategory.explorer:
        return Colors.red;
    }
  }

  IconData _getAchievementIcon(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.watching:
        return Icons.movie;
      case AchievementCategory.rating:
        return Icons.star;
      case AchievementCategory.social:
        return Icons.people;
      case AchievementCategory.discovery:
        return Icons.explore;
      case AchievementCategory.collector:
        return Icons.collections;
      case AchievementCategory.critic:
        return Icons.rate_review;
      case AchievementCategory.explorer:
        return Icons.language;
    }
  }

  String _formatUnlockDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Desbloqueado hoy';
    } else if (difference.inDays == 1) {
      return 'Desbloqueado ayer';
    } else if (difference.inDays < 30) {
      return 'Hace ${difference.inDays} días';
    } else {
      return 'Desbloqueado el ${date.day}/${date.month}/${date.year}';
    }
  }
}
