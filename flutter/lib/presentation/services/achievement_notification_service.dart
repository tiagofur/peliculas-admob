import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entities.dart';
import '../widgets/widgets.dart';

class AchievementNotificationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static void showAchievementUnlocked(Achievement achievement) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    // Mostrar notificación flotante
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: AchievementUnlockedNotification(
            achievement: achievement,
            onTap: () {
              overlayEntry.remove();
              _showShareDialog(context, achievement);
            },
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Auto-remover después de 4 segundos
    Future.delayed(const Duration(seconds: 4), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  static void _showShareDialog(BuildContext context, Achievement achievement) {
    showDialog(
      context: context,
      builder: (context) => AchievementShareDialog(achievement: achievement),
    );
  }
}

// Provider para el servicio de notificaciones
final achievementNotificationServiceProvider =
    Provider<AchievementNotificationService>((ref) {
  return AchievementNotificationService();
});
