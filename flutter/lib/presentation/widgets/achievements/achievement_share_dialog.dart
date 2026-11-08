import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../domain/entities/entities.dart';
import 'achievement_image_generator.dart';

class AchievementShareDialog extends StatelessWidget {
  const AchievementShareDialog({
    super.key,
    required this.achievement,
  });

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.purple.shade800,
              Colors.blue.shade600,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícono del logro
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getAchievementIcon(achievement.id),
                size: 40,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            // Título
            const Text(
              '¡Logro Desbloqueado!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Nombre del logro
            Text(
              achievement.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Descripción
            Text(
              achievement.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cerrar',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _shareAchievement(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.purple.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.share, size: 18),
                        SizedBox(width: 4),
                        Text('Compartir'),
                      ],
                    ),
                  ),
                ),
              ],
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
      case 'first_favorite':
        return Icons.favorite;
      case 'favorite_collector':
        return Icons.collections;
      case 'genre_explorer':
        return Icons.category;
      case 'decade_traveler':
        return Icons.access_time;
      default:
        return Icons.emoji_events;
    }
  }

  void _shareAchievement(BuildContext context) async {
    // Mostrar indicador de carga
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Generando imagen del logro...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }

    try {
      // Intentar generar y compartir imagen
      final imageFile =
          await AchievementImageGenerator.generateImage(achievement);

      if (imageFile != null) {
        // Compartir imagen
        await SharePlus.instance.share(ShareParams(
          files: [XFile(imageFile.path)],
          text:
              '🎬 ¡Nuevo logro desbloqueado en Películas! ${achievement.title}',
        ));

        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Imagen del logro compartida exitosamente!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }
    } catch (e) {
      // Error compartiendo imagen
    }

    // Fallback: compartir texto si falla la imagen
    try {
      final shareText = '''
🎬 ¡Logro Desbloqueado en Películas! 🎬

${achievement.iconName} ${achievement.title}

${achievement.description}

¡Descarga la app Películas y desbloquea tus propios logros!
''';

      await SharePlus.instance.share(ShareParams(
        text: shareText,
      ));

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logro compartido como texto'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Último fallback: copiar al portapapeles
      final shareText =
          '🎬 ¡Acabo de desbloquear el logro "${achievement.title}" en mi app de películas! ${achievement.description}';

      await Clipboard.setData(ClipboardData(text: shareText));

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logro copiado al portapapeles'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }
}

// Widget para mostrar notificación de logro desbloqueado con animaciones cinematográficas
class AchievementUnlockedNotification extends StatefulWidget {
  const AchievementUnlockedNotification({
    super.key,
    required this.achievement,
    required this.onTap,
  });

  final Achievement achievement;
  final VoidCallback onTap;

  @override
  State<AchievementUnlockedNotification> createState() =>
      _AchievementUnlockedNotificationState();
}

class _AchievementUnlockedNotificationState
    extends State<AchievementUnlockedNotification>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late AnimationController _sparkleController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _sparkleAnimation;

  @override
  void initState() {
    super.initState();

    // Animación de entrada deslizante
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    // Animación de escala
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.bounceOut,
    ));

    // Animación de brillo
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    // Animación de partículas
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _sparkleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.easeOut,
    ));

    // Iniciar animaciones
    _slideController.forward();
    _scaleController.forward();
    _glowController.repeat(reverse: true);
    _sparkleController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    _glowController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            margin: const EdgeInsets.all(16),
            child: Stack(
              children: [
                // Efecto de brillo de fondo
                AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.lerp(Colors.amber.shade700,
                                Colors.amber.shade400, _glowAnimation.value)!,
                            Color.lerp(Colors.orange.shade700,
                                Colors.orange.shade400, _glowAnimation.value)!,
                            Color.lerp(
                                Colors.deepOrange.shade600,
                                Colors.deepOrange.shade300,
                                _glowAnimation.value)!,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber
                                .withValues(alpha: 0.6 * _glowAnimation.value),
                            blurRadius: 20 * _glowAnimation.value,
                            spreadRadius: 2 * _glowAnimation.value,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Ícono animado del logro
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.9),
                                  Colors.white.withValues(alpha: 0.3),
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: AnimatedBuilder(
                              animation: _scaleController,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: 1.0 + (0.2 * _scaleAnimation.value),
                                  child: Icon(
                                    _getAchievementIcon(widget.achievement.id),
                                    color: Colors.amber.shade800,
                                    size: 32,
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Información del logro
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '🎬 ¡LOGRO DESBLOQUEADO! 🏆',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    shadows: [
                                      Shadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.5),
                                        offset: const Offset(1, 1),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.achievement.title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    shadows: [
                                      Shadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.3),
                                        offset: const Offset(1, 1),
                                        blurRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.achievement.description,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // Indicador de toque
                          Column(
                            children: [
                              Icon(
                                Icons.touch_app,
                                color: Colors.white.withValues(alpha: 0.8),
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Toca para\ncompartir',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Partículas brillantes
                AnimatedBuilder(
                  animation: _sparkleAnimation,
                  builder: (context, child) {
                    return Positioned.fill(
                      child: CustomPaint(
                        painter: SparklePainter(_sparkleAnimation.value),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
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
      case 'first_favorite':
        return Icons.favorite;
      case 'favorite_collector':
        return Icons.collections;
      case 'genre_explorer':
        return Icons.category;
      case 'decade_traveler':
        return Icons.access_time;
      default:
        return Icons.emoji_events;
    }
  }
}

// Painter para crear efectos de partículas brillantes
class SparklePainter extends CustomPainter {
  SparklePainter(this.animationValue);
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8 * (1 - animationValue))
      ..style = PaintingStyle.fill;

    // Crear partículas en posiciones aleatorias
    final sparkles = [
      Offset(size.width * 0.2, size.height * 0.3),
      Offset(size.width * 0.8, size.height * 0.2),
      Offset(size.width * 0.1, size.height * 0.7),
      Offset(size.width * 0.9, size.height * 0.8),
      Offset(size.width * 0.5, size.height * 0.1),
      Offset(size.width * 0.7, size.height * 0.6),
    ];

    for (int i = 0; i < sparkles.length; i++) {
      final sparkle = sparkles[i];
      final delay = i * 0.1;
      final sparkleProgress = (animationValue - delay).clamp(0.0, 1.0);

      if (sparkleProgress > 0) {
        final radius = 3.0 * sparkleProgress * (1 - sparkleProgress) * 4;
        canvas.drawCircle(sparkle, radius, paint);

        // Dibujar cruz brillante
        final crossPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.6 * (1 - sparkleProgress))
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

        final crossSize = radius * 2;
        canvas.drawLine(
          Offset(sparkle.dx - crossSize, sparkle.dy),
          Offset(sparkle.dx + crossSize, sparkle.dy),
          crossPaint,
        );
        canvas.drawLine(
          Offset(sparkle.dx, sparkle.dy - crossSize),
          Offset(sparkle.dx, sparkle.dy + crossSize),
          crossPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
