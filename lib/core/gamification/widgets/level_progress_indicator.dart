import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/user_level.dart';
import '../models/user_progress.dart';

/// Widget para mostrar el progreso del nivel del usuario
class LevelProgressIndicator extends StatefulWidget {
  const LevelProgressIndicator({
    super.key,
    required this.userProgress,
    this.size = 120,
    this.showDetails = true,
    this.animated = true,
    this.onTap,
  });
  final UserProgress userProgress;
  final double size;
  final bool showDetails;
  final bool animated;
  final VoidCallback? onTap;

  @override
  State<LevelProgressIndicator> createState() => _LevelProgressIndicatorState();
}

class _LevelProgressIndicatorState extends State<LevelProgressIndicator>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: _calculateProgress(),
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    if (widget.animated) {
      _progressController.forward();
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LevelProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userProgress.totalPoints != widget.userProgress.totalPoints) {
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: _calculateProgress(),
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeInOut,
      ));

      if (widget.animated) {
        _progressController.reset();
        _progressController.forward();
      }
    }
  }

  double _calculateProgress() {
    final progress = widget.userProgress.totalPoints /
        widget.userProgress.pointsForNextLevel;
    return progress.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: widget.animated
                ? _pulseAnimation
                : const AlwaysStoppedAnimation(1.0),
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: _buildCircularProgress(theme),
              );
            },
          ),
          if (widget.showDetails) ...[
            const SizedBox(height: 12),
            _buildLevelInfo(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildCircularProgress(ThemeData theme) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Fondo del círculo
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _getLevelColor().withValues(alpha: 0.1),
                  _getLevelColor().withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                color: _getLevelColor().withValues(alpha: 0.3),
                width: 2,
              ),
            ),
          ),

          // Progreso circular
          AnimatedBuilder(
            animation: widget.animated
                ? _progressAnimation
                : const AlwaysStoppedAnimation(1.0),
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: CircularProgressPainter(
                  progress: widget.animated
                      ? _progressAnimation.value
                      : _calculateProgress(),
                  color: _getLevelColor(),
                  strokeWidth: 6,
                ),
              );
            },
          ),

          // Contenido central
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getLevelIcon(),
                size: widget.size * 0.25,
                color: _getLevelColor(),
              ),
              const SizedBox(height: 4),
              Text(
                _getLevelName(),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _getLevelColor(),
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                '${widget.userProgress.totalPoints}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelInfo(ThemeData theme) {
    final isMaxLevel = widget.userProgress.level == UserLevel.legend;

    return Column(
      children: [
        Text(
          _getLevelName(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: _getLevelColor(),
          ),
        ),
        const SizedBox(height: 4),
        if (!isMaxLevel) ...[
          Text(
            'Siguiente: ${_getLevelName(widget.userProgress.level)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${widget.userProgress.pointsForNextLevel - widget.userProgress.totalPoints} puntos restantes',
            style: theme.textTheme.bodySmall?.copyWith(
              color: _getLevelColor(),
              fontWeight: FontWeight.w500,
            ),
          ),
        ] else ...[
          Text(
            '¡Nivel máximo alcanzado!',
            style: theme.textTheme.bodySmall?.copyWith(
              color: _getLevelColor(),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  Color _getLevelColor([UserLevel? level]) {
    final targetLevel = level ?? widget.userProgress.level;
    switch (targetLevel) {
      case UserLevel.novice:
        return const Color(0xFF8BC34A); // Verde claro
      case UserLevel.enthusiast:
        return const Color(0xFF2196F3); // Azul
      case UserLevel.expert:
        return const Color(0xFF9C27B0); // Púrpura
      case UserLevel.master:
        return const Color(0xFFFF9800); // Naranja
      case UserLevel.legend:
        return const Color(0xFFFFD700); // Dorado
    }
  }

  IconData _getLevelIcon([UserLevel? level]) {
    final targetLevel = level ?? widget.userProgress.level;
    switch (targetLevel) {
      case UserLevel.novice:
        return Icons.school;
      case UserLevel.enthusiast:
        return Icons.favorite;
      case UserLevel.expert:
        return Icons.star;
      case UserLevel.master:
        return Icons.emoji_events;
      case UserLevel.legend:
        return Icons.auto_awesome;
    }
  }

  String _getLevelName([UserLevel? level]) {
    final targetLevel = level ?? widget.userProgress.level;
    switch (targetLevel) {
      case UserLevel.novice:
        return 'Novato';
      case UserLevel.enthusiast:
        return 'Entusiasta';
      case UserLevel.expert:
        return 'Experto';
      case UserLevel.master:
        return 'Maestro';
      case UserLevel.legend:
        return 'Leyenda';
    }
  }
}

/// Painter personalizado para el progreso circular
class CircularProgressPainter extends CustomPainter {
  CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });
  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Fondo del progreso
    final backgroundPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progreso actual
    if (progress > 0) {
      final progressPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            color,
            color.withValues(alpha: 0.7),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // Comenzar desde arriba
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
