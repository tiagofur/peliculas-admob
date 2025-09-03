import 'package:flutter/material.dart';

import '../models/achievement.dart';

/// Widget para mostrar insignias del usuario
class BadgeDisplay extends StatelessWidget {
  const BadgeDisplay({
    super.key,
    required this.unlockedAchievements,
    this.showCount = true,
    this.isHorizontal = true,
    this.maxVisible = 5,
    this.onViewAll,
    this.badgeSize = 40,
  });
  final List<Achievement> unlockedAchievements;
  final bool showCount;
  final bool isHorizontal;
  final int maxVisible;
  final VoidCallback? onViewAll;
  final double badgeSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgesByType = _groupBadgesByType();

    if (unlockedAchievements.isEmpty) {
      return _buildEmptyState(theme);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showCount) _buildHeader(theme),
        const SizedBox(height: 8),
        isHorizontal
            ? _buildHorizontalBadges(theme, badgesByType)
            : _buildVerticalBadges(theme, badgesByType),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Insignias (${unlockedAchievements.length})',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (unlockedAchievements.length > maxVisible && onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: const Text('Ver todas'),
          ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 48,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Sin insignias aún',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.textTheme.titleMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Completa logros para ganar insignias',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalBadges(
      ThemeData theme, Map<AchievementRarity, List<Achievement>> badgesByType) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...badgesByType.entries.map((entry) {
            final rarity = entry.key;
            final achievements = entry.value;

            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _buildBadgeStack(theme, rarity, achievements),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVerticalBadges(
      ThemeData theme, Map<AchievementRarity, List<Achievement>> badgesByType) {
    return Column(
      children: badgesByType.entries.map((entry) {
        final rarity = entry.key;
        final achievements = entry.value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildBadgeRow(theme, rarity, achievements),
        );
      }).toList(),
    );
  }

  Widget _buildBadgeStack(ThemeData theme, AchievementRarity rarity,
      List<Achievement> achievements) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _buildBadgeIcon(rarity, achievements.length),
            if (achievements.length > 1)
              Positioned(
                top: -4,
                right: -4,
                child: _buildBadgeCount(theme, achievements.length),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _getBadgeName(rarity),
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeRow(ThemeData theme, AchievementRarity rarity,
      List<Achievement> achievements) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getBadgeColor(rarity).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getBadgeColor(rarity).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          _buildBadgeIcon(rarity, achievements.length),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getBadgeName(rarity),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _getBadgeColor(rarity),
                  ),
                ),
                Text(
                  '${achievements.length} logro${achievements.length != 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          _buildBadgeCount(theme, achievements.length),
        ],
      ),
    );
  }

  Widget _buildBadgeIcon(AchievementRarity rarity, int count) {
    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getBadgeColor(rarity),
            _getBadgeColor(rarity).withValues(alpha: 0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _getBadgeColor(rarity).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        _getBadgeIcon(rarity),
        size: badgeSize * 0.6,
        color: Colors.white,
      ),
    );
  }

  Widget _buildBadgeCount(ThemeData theme, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Map<AchievementRarity, List<Achievement>> _groupBadgesByType() {
    final Map<AchievementRarity, List<Achievement>> grouped = {};

    for (final achievement in unlockedAchievements) {
      final rarity = achievement.rarity;
      if (!grouped.containsKey(rarity)) {
        grouped[rarity] = [];
      }
      grouped[rarity]?.add(achievement);
    }

    // Ordenar por rareza (diamond primero, bronze último)
    final sortedEntries = grouped.entries.toList()
      ..sort(
          (a, b) => _getBadgeRarity(b.key).compareTo(_getBadgeRarity(a.key)));

    return Map.fromEntries(sortedEntries);
  }

  int _getBadgeRarity(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.legendary:
        return 5;
      case AchievementRarity.epic:
        return 4;
      case AchievementRarity.rare:
        return 3;
      case AchievementRarity.uncommon:
        return 2;
      case AchievementRarity.common:
        return 1;
    }
  }

  Color _getBadgeColor(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return const Color(0xFFCD7F32);
      case AchievementRarity.uncommon:
        return const Color(0xFFC0C0C0);
      case AchievementRarity.rare:
        return const Color(0xFFFFD700);
      case AchievementRarity.epic:
        return const Color(0xFFE5E4E2);
      case AchievementRarity.legendary:
        return const Color(0xFFB9F2FF);
    }
  }

  IconData _getBadgeIcon(AchievementRarity rarity) {
    switch (rarity) {
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

  String _getBadgeName(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return 'Común';
      case AchievementRarity.uncommon:
        return 'Poco común';
      case AchievementRarity.rare:
        return 'Raro';
      case AchievementRarity.epic:
        return 'Épico';
      case AchievementRarity.legendary:
        return 'Legendario';
    }
  }
}

/// Widget para mostrar una insignia individual con animación
class AnimatedBadge extends StatefulWidget {
  const AnimatedBadge({
    super.key,
    required this.rarity,
    this.size = 60,
    this.showAnimation = true,
    this.onTap,
  });
  final AchievementRarity rarity;
  final double size;
  final bool showAnimation;
  final VoidCallback? onTap;

  @override
  State<AnimatedBadge> createState() => _AnimatedBadgeState();
}

class _AnimatedBadgeState extends State<AnimatedBadge>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));

    if (widget.showAnimation) {
      _scaleController.forward();
      _rotationController.forward();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _rotationAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: widget.showAnimation ? _scaleAnimation.value : 1.0,
            child: Transform.rotate(
              angle:
                  widget.showAnimation ? _rotationAnimation.value * 0.1 : 0.0,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getBadgeColor(widget.rarity),
                      _getBadgeColor(widget.rarity).withValues(alpha: 0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          _getBadgeColor(widget.rarity).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _getBadgeIcon(widget.rarity),
                  size: widget.size * 0.6,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getBadgeColor(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return const Color(0xFFCD7F32);
      case AchievementRarity.uncommon:
        return const Color(0xFFC0C0C0);
      case AchievementRarity.rare:
        return const Color(0xFFFFD700);
      case AchievementRarity.epic:
        return const Color(0xFFE5E4E2);
      case AchievementRarity.legendary:
        return const Color(0xFFB9F2FF);
    }
  }

  IconData _getBadgeIcon(AchievementRarity rarity) {
    switch (rarity) {
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
}
