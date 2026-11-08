import 'package:flutter/material.dart';

import '../models/achievement.dart';

/// Widget para mostrar una tarjeta de logro individual
class AchievementCard extends StatelessWidget {
  const AchievementCard({
    super.key,
    required this.achievement,
    required this.isUnlocked,
    this.progress = 0.0,
    this.currentValue = 0,
    this.onTap,
    this.showProgress = true,
    this.isCompact = false,
  });
  final Achievement achievement;
  final bool isUnlocked;
  final double progress; // 0.0 a 1.0
  final int currentValue;
  final VoidCallback? onTap;
  final bool showProgress;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: isUnlocked ? 8 : 4,
      margin: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 16,
        vertical: isCompact ? 4 : 8,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isUnlocked
            ? BorderSide(
                color: _getBadgeColor(achievement.rarity),
                width: 2,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isUnlocked
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getBadgeColor(achievement.rarity).withValues(alpha: 0.1),
                      _getBadgeColor(achievement.rarity)
                          .withValues(alpha: 0.05),
                    ],
                  )
                : null,
          ),
          child: isCompact
              ? _buildCompactContent(theme)
              : _buildFullContent(theme),
        ),
      ),
    );
  }

  Widget _buildFullContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildAchievementIcon(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isUnlocked
                          ? _getBadgeColor(achievement.rarity)
                          : theme.textTheme.titleMedium?.color
                              ?.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: isUnlocked ? 1.0 : 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildBadge(),
          ],
        ),
        if (showProgress && !isUnlocked) ...[
          const SizedBox(height: 12),
          _buildProgressSection(theme),
        ],
        if (isUnlocked) ...[
          const SizedBox(height: 8),
          _buildRewardSection(theme),
        ],
      ],
    );
  }

  Widget _buildCompactContent(ThemeData theme) {
    return Row(
      children: [
        _buildAchievementIcon(size: 32),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                achievement.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isUnlocked
                      ? _getBadgeColor(achievement.rarity)
                      : theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (showProgress && !isUnlocked)
                Text(
                  '$currentValue/${achievement.maxProgress}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ),
        _buildBadge(size: 24),
      ],
    );
  }

  Widget _buildAchievementIcon({double size = 48}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getBadgeColor(achievement.rarity).withValues(
          alpha: isUnlocked ? 0.2 : 0.1,
        ),
        border: Border.all(
          color: _getBadgeColor(achievement.rarity).withValues(
            alpha: isUnlocked ? 0.5 : 0.3,
          ),
          width: 2,
        ),
      ),
      child: Icon(
        _getAchievementIcon(),
        size: size * 0.5,
        color: _getBadgeColor(achievement.rarity).withValues(
          alpha: isUnlocked ? 1.0 : 0.5,
        ),
      ),
    );
  }

  Widget _buildBadge({double size = 32}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getBadgeColor(achievement.rarity),
            _getBadgeColor(achievement.rarity).withValues(alpha: 0.7),
          ],
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color:
                      _getBadgeColor(achievement.rarity).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Icon(
        _getBadgeIcon(),
        size: size * 0.6,
        color: Colors.white,
      ),
    );
  }

  Widget _buildProgressSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progreso',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$currentValue/${achievement.maxProgress}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: _getBadgeColor(achievement.rarity),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: theme.dividerColor.withValues(alpha: 0.3),
          valueColor: AlwaysStoppedAnimation<Color>(
            _getBadgeColor(achievement.rarity),
          ),
          minHeight: 6,
        ),
      ],
    );
  }

  Widget _buildRewardSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getBadgeColor(achievement.rarity).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.stars,
            size: 16,
            color: _getBadgeColor(achievement.rarity),
          ),
          const SizedBox(width: 4),
          Text(
            '+${achievement.points} puntos',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: _getBadgeColor(achievement.rarity),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBadgeColor(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return const Color(0xFFCD7F32); // Bronze
      case AchievementRarity.uncommon:
        return const Color(0xFFC0C0C0); // Silver
      case AchievementRarity.rare:
        return const Color(0xFFFFD700); // Gold
      case AchievementRarity.epic:
        return const Color(0xFFE5E4E2); // Platinum
      case AchievementRarity.legendary:
        return const Color(0xFFB9F2FF); // Diamond
    }
  }

  IconData _getBadgeIcon() {
    switch (achievement.rarity) {
      case AchievementRarity.common:
        return Icons.workspace_premium;
      case AchievementRarity.uncommon:
        return Icons.military_tech;
      case AchievementRarity.rare:
        return Icons.emoji_events;
      case AchievementRarity.epic:
        return Icons.diamond;
      case AchievementRarity.legendary:
        return Icons.auto_awesome;
    }
  }

  IconData _getAchievementIcon() {
    switch (achievement.category) {
      case AchievementCategory.movies:
        return Icons.movie;
      case AchievementCategory.social:
        return Icons.share;
      case AchievementCategory.discovery:
        return Icons.explore;
      case AchievementCategory.collection:
        return Icons.collections;
      case AchievementCategory.engagement:
        return Icons.rate_review;
      case AchievementCategory.general:
        return Icons.star;
    }
  }
}
