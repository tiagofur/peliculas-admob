import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/achievement.dart';

/// Widget para mostrar notificaciones de logros desbloqueados
class AchievementNotification extends StatefulWidget {
  const AchievementNotification({
    super.key,
    required this.achievement,
    this.onDismiss,
    this.displayDuration = const Duration(seconds: 4),
    this.showConfetti = true,
  });
  final Achievement achievement;
  final VoidCallback? onDismiss;
  final Duration displayDuration;
  final bool showConfetti;

  @override
  State<AchievementNotification> createState() =>
      _AchievementNotificationState();

  /// Muestra la notificación como overlay
  static void show(
    BuildContext context,
    Achievement achievement, {
    VoidCallback? onDismiss,
    Duration displayDuration = const Duration(seconds: 4),
    bool showConfetti = true,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => AchievementNotification(
        achievement: achievement,
        displayDuration: displayDuration,
        showConfetti: showConfetti,
        onDismiss: () {
          overlayEntry.remove();
          onDismiss?.call();
        },
      ),
    );

    overlay.insert(overlayEntry);
  }
}

class _AchievementNotificationState extends State<AchievementNotification>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _confettiController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _confettiAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _confettiAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _confettiController,
      curve: Curves.easeOut,
    ));

    _startAnimation();
  }

  void _startAnimation() async {
    // Vibración háptica
    HapticFeedback.mediumImpact();

    // Animaciones de entrada
    _slideController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _scaleController.forward();

    if (widget.showConfetti) {
      _confettiController.forward();
    }

    // Auto-dismiss después del tiempo especificado
    Future.delayed(widget.displayDuration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    await _slideController.reverse();
    widget.onDismiss?.call();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Positioned(
      top: mediaQuery.padding.top + 20,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Confetti background
              if (widget.showConfetti) _buildConfetti(),

              // Notification card
              _buildNotificationCard(theme),

              // Close button
              Positioned(
                top: 8,
                right: 8,
                child: _buildCloseButton(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getBadgeColor(widget.achievement.rarity),
            _getBadgeColor(widget.achievement.rarity).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _getBadgeColor(widget.achievement.rarity)
                .withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Achievement icon
          _buildAchievementIcon(),
          const SizedBox(width: 16),

          // Achievement details
          Expanded(
            child: _buildAchievementDetails(theme),
          ),

          // Points badge
          _buildPointsBadge(theme),
        ],
      ),
    );
  }

  Widget _buildAchievementIcon() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.2),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Icon(
        _getBadgeIcon(widget.achievement.rarity),
        size: 32,
        color: Colors.white,
      ),
    );
  }

  Widget _buildAchievementDetails(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '¡Logro Desbloqueado!',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          widget.achievement.name,
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          widget.achievement.description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildPointsBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.stars,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            '+${widget.achievement.points}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton(ThemeData theme) {
    return GestureDetector(
      onTap: _dismiss,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.2),
        ),
        child: Icon(
          Icons.close,
          size: 16,
          color: Colors.white.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildConfetti() {
    return AnimatedBuilder(
      animation: _confettiAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: ConfettiPainter(
            animation: _confettiAnimation.value,
            colors: [
              _getBadgeColor(widget.achievement.rarity),
              Colors.yellow,
              Colors.orange,
              Colors.pink,
              Colors.purple,
            ],
          ),
          size: const Size(double.infinity, 100),
        );
      },
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

  IconData _getBadgeIcon(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return Icons.military_tech;
      case AchievementRarity.uncommon:
        return Icons.workspace_premium;
      case AchievementRarity.rare:
        return Icons.emoji_events;
      case AchievementRarity.epic:
        return Icons.diamond;
      case AchievementRarity.legendary:
        return Icons.auto_awesome;
    }
  }
}

/// Painter para el efecto de confetti
class ConfettiPainter extends CustomPainter {
  ConfettiPainter({
    required this.animation,
    required this.colors,
  }) : particles = List.generate(
            20,
            (index) => ConfettiParticle(
                  x: (index * 20.0) % 400,
                  y: -20 + (index * 5.0),
                  color: colors[index % colors.length],
                  size: 4 + (index % 3) * 2,
                  rotation: index * 0.5,
                ));
  final double animation;
  final List<Color> colors;
  final List<ConfettiParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final paint = Paint()
        ..color = particle.color.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;

      final x = particle.x + (animation * 50) * (particle.x / size.width - 0.5);
      final y = particle.y + (animation * 120);

      if (y > size.height) continue;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(particle.rotation + animation * 6.28);

      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: particle.size,
          height: particle.size,
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Clase para representar una partícula de confetti
class ConfettiParticle {
  ConfettiParticle({
    required this.x,
    required this.y,
    required this.color,
    required this.size,
    required this.rotation,
  });
  final double x;
  final double y;
  final Color color;
  final double size;
  final double rotation;
}

/// Widget simplificado para mostrar notificaciones en snackbar
class SimpleAchievementNotification extends StatelessWidget {
  const SimpleAchievementNotification({
    super.key,
    required this.achievement,
    this.onTap,
  });
  final Achievement achievement;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _getBadgeColor(achievement.rarity),
              _getBadgeColor(achievement.rarity).withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getBadgeIcon(achievement.rarity),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '¡${achievement.name} desbloqueado! (+${achievement.points} pts)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
