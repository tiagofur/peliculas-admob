import 'package:flutter/material.dart';

import '../../../domain/entities/achievement.dart';
import '../../../domain/entities/achievement_progress.dart';

/// Widget para mostrar una tarjeta individual de logro
class AchievementCardWidget extends StatefulWidget {
  const AchievementCardWidget({
    super.key,
    required this.achievement,
    this.progress,
    this.onTap,
  });
  final Achievement achievement;
  final AchievementProgress? progress;
  final VoidCallback? onTap;

  @override
  State<AchievementCardWidget> createState() => _AchievementCardWidgetState();
}

class _AchievementCardWidgetState extends State<AchievementCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnlocked = widget.progress?.isUnlocked ?? false;
    final progressValue = widget.progress
            ?.getProgressPercentage(widget.achievement.targetValue) ??
        0.0;

    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: isUnlocked
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.1)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                border: isUnlocked
                    ? Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        width: 1.5,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: isUnlocked
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: isUnlocked ? 12 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Contenido principal
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icono principal
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: isUnlocked
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline
                                    .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isUnlocked
                                ? [
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            isUnlocked
                                ? Icons.emoji_events
                                : Icons.emoji_events_outlined,
                            color: isUnlocked
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.outline,
                            size: 24,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Título del logro
                        Text(
                          widget.achievement.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isUnlocked
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 8),

                        // Descripción más sutil
                        Text(
                          widget.achievement.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const Spacer(),

                        // Progreso simplificado
                        if (!isUnlocked) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.outline
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: progressValue,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${widget.progress?.currentValue ?? 0}/${widget.achievement.targetValue}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          // Badge de completado
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '+${widget.achievement.points} puntos',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Sutil indicador de desbloqueo en la esquina
                  if (isUnlocked)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.check,
                          color: theme.colorScheme.onPrimary,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
