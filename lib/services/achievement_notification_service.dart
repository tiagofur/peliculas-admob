import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/logging/logger_factory.dart';
import '../domain/entities/achievement.dart';
import 'gamification_service.dart';

/// Servicio para mostrar notificaciones cuando se desbloqueen logros
class AchievementNotificationService {
  AchievementNotificationService._internal();
  static AchievementNotificationService? _instance;
  static AchievementNotificationService get instance {
    _instance ??= AchievementNotificationService._internal();
    return _instance!;
  }

  StreamSubscription<Achievement>? _achievementSubscription;
  bool _isInitialized = false;

  /// Inicializa el servicio y conecta con el servicio de gamificación
  Future<void> initialize(GamificationService gamificationService) async {
    if (_isInitialized) return;

    try {
      LoggerFactory.info('Inicializando AchievementNotificationService...');

      // Suscribirse a logros desbloqueados
      _achievementSubscription =
          gamificationService.onAchievementUnlocked.listen(
        (achievement) => _showAchievementNotification(achievement),
        onError: (error) =>
            LoggerFactory.error('Error en notificaciones de logros: $error'),
      );

      _isInitialized = true;
      LoggerFactory.info(
          'AchievementNotificationService inicializado exitosamente');
    } catch (e) {
      LoggerFactory.error(
          'Error inicializando AchievementNotificationService: $e');
      rethrow;
    }
  }

  /// Muestra una notificación cuando se desbloquea un logro
  Future<void> _showAchievementNotification(Achievement achievement) async {
    try {
      LoggerFactory.info(
          'Mostrando notificación para logro: ${achievement.title}');

      // Vibración para feedback háptico
      await _triggerHapticFeedback(achievement.rarity);

      // Mostrar notificación visual
      await _showVisualNotification(achievement);

      // Log para analytics
      LoggerFactory.info('Notificación de logro mostrada: ${achievement.id}');
    } catch (e) {
      LoggerFactory.error('Error mostrando notificación de logro: $e');
    }
  }

  /// Genera feedback háptico basado en la rareza del logro
  Future<void> _triggerHapticFeedback(AchievementRarity rarity) async {
    try {
      switch (rarity) {
        case AchievementRarity.common:
          await HapticFeedback.lightImpact();
          break;
        case AchievementRarity.uncommon:
          await HapticFeedback.mediumImpact();
          break;
        case AchievementRarity.rare:
          await HapticFeedback.heavyImpact();
          break;
        case AchievementRarity.epic:
        case AchievementRarity.legendary:
          // Double haptic para logros especiales
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.heavyImpact();
          break;
      }
    } catch (e) {
      LoggerFactory.warning('Error con feedback háptico: $e');
    }
  }

  /// Muestra la notificación visual del logro
  Future<void> _showVisualNotification(Achievement achievement) async {
    final context = _getCurrentContext();
    if (context == null) {
      LoggerFactory.warning(
          'No se pudo obtener contexto para mostrar notificación');
      return;
    }

    // Mostrar SnackBar personalizada para logros
    final snackBar = SnackBar(
      content: AchievementNotificationWidget(achievement: achievement),
      duration: Duration(seconds: _getDurationByRarity(achievement.rarity)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(
        bottom: 100,
        left: 16,
        right: 16,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Obtiene el contexto actual de la aplicación
  BuildContext? _getCurrentContext() {
    try {
      // En una implementación real, esto debería ser obtenido del Navigator
      // o de un servicio de navegación global
      return null; // Placeholder - necesita implementación específica del proyecto
    } catch (e) {
      LoggerFactory.error('Error obteniendo contexto: $e');
      return null;
    }
  }

  /// Determina la duración de la notificación basada en la rareza
  int _getDurationByRarity(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return 3;
      case AchievementRarity.uncommon:
        return 4;
      case AchievementRarity.rare:
        return 5;
      case AchievementRarity.epic:
        return 6;
      case AchievementRarity.legendary:
        return 8;
    }
  }

  /// Obtiene el color del tema basado en la rareza del logro
  static Color getColorByRarity(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return Colors.grey.shade600;
      case AchievementRarity.uncommon:
        return Colors.green.shade600;
      case AchievementRarity.rare:
        return Colors.blue.shade600;
      case AchievementRarity.epic:
        return Colors.purple.shade600;
      case AchievementRarity.legendary:
        return Colors.orange.shade600;
    }
  }

  /// Obtiene el icono apropiado para el tipo de logro
  static IconData getIconByType(AchievementType type) {
    switch (type) {
      case AchievementType.moviesWatched:
        return Icons.movie;
      case AchievementType.genreExplorer:
        return Icons.explore;
      case AchievementType.yearStreak:
        return Icons.calendar_today;
      case AchievementType.socialInteraction:
        return Icons.people;
      case AchievementType.qualityViewer:
        return Icons.star;
      case AchievementType.timeSpent:
        return Icons.schedule;
      case AchievementType.discovery:
        return Icons.search;
    }
  }

  /// Muestra una notificación de progreso (opcional, para logros casi completados)
  Future<void> showProgressNotification(
      Achievement achievement, int currentProgress) async {
    if (currentProgress < achievement.targetValue * 0.8) {
      return; // Solo mostrar cuando esté cerca de completarse
    }

    final context = _getCurrentContext();
    if (context == null) return;

    final remaining = achievement.targetValue - currentProgress;
    final progressSnackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            getIconByType(achievement.type),
            color: Colors.white.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '¡Casi lo logras! ${achievement.title} - Faltan $remaining',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.grey.shade700,
    );

    ScaffoldMessenger.of(context).showSnackBar(progressSnackBar);
  }

  /// Limpia recursos y cierra suscripciones
  Future<void> dispose() async {
    await _achievementSubscription?.cancel();
    _achievementSubscription = null;
    _isInitialized = false;
    LoggerFactory.info('AchievementNotificationService disposed');
  }
}

/// Widget personalizado para mostrar notificaciones de logros desbloqueados
class AchievementNotificationWidget extends StatefulWidget {
  const AchievementNotificationWidget({
    super.key,
    required this.achievement,
  });
  final Achievement achievement;

  @override
  State<AchievementNotificationWidget> createState() =>
      _AchievementNotificationWidgetState();
}

class _AchievementNotificationWidgetState
    extends State<AchievementNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _animationController.forward();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AchievementNotificationService.getColorByRarity(
                        widget.achievement.rarity),
                    AchievementNotificationService.getColorByRarity(
                            widget.achievement.rarity)
                        .withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Icono del logro con animación de brillo
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      AchievementNotificationService.getIconByType(
                          widget.achievement.type),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Información del logro
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '🏆 ¡Logro Desbloqueado!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.achievement.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.achievement.unlockMessage != null)
                          Text(
                            widget.achievement.unlockMessage!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  // Puntos obtenidos
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '+${widget.achievement.points}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
