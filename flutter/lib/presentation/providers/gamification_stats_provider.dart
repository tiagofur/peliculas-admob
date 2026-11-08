import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/gamification/gamification_manager.dart';
import '../../core/gamification/widgets/achievement_notification.dart';
import '../../core/logging/logger_factory.dart';
import '../../services/gamification_service.dart';
import 'social_sharing_provider.dart';
import 'user_stats_provider.dart';

final navigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) =>
    throw UnimplementedError('Debe proveerse el navigatorKey en main.dart'));

/// Provider que integra las estadísticas del usuario con el sistema de gamificación
final gamificationStatsIntegrationProvider = FutureProvider<void>((ref) async {
  // Observar cambios en las estadísticas básicas del usuario
  final basicStats = ref.watch(basicUserStatsProvider);
  final gamificationManager = GamificationManager.instance;
  final navigatorKey = ref.read(navigatorKeyProvider);

  // Mostrar notificación de logros con confetti para cualquier logro desbloqueado
  gamificationManager.achievementUnlockedStream.listen((achievement) {
    if (navigatorKey.currentContext != null) {
      AchievementNotification.show(
        navigatorKey.currentContext!,
        achievement,
        showConfetti: true,
      );
    }
  });

  // Escuchar eventos de compartir en tiempo real
  ref.listen<ShareState>(shareStateProvider, (prev, next) async {
    if (next is ShareStateSuccess && next.message.contains('compartida')) {
      // Actualizar progreso local y logros
      // Aquí deberías pasar el movieId real si lo tienes
      await gamificationManager.trackMovieShared('shared_movie_id');
      // Sincronizar con Supabase (stub, implementar real)
      await gamificationManager.syncProgressWithSupabase.call();
      // Verificar logros desbloqueados
      final newAchievements = await gamificationManager.checkAchievements();
      if (newAchievements.isNotEmpty) {
        for (final achievement in newAchievements) {
          if (navigatorKey.currentContext != null) {
            AchievementNotification.show(
              navigatorKey.currentContext!,
              achievement,
              showConfetti: true,
            );
          }
        }
      }
    }
  });

  try {
    // Actualizar estadísticas de gamificación con datos reales
    await gamificationManager.updateUserStats(
      totalWatched: basicStats.totalWatched,
      totalFavorites: basicStats.totalFavorites,
      totalRatings: ref.read(userRatingStatsProvider).maybeWhen(
            data: (stats) => stats.totalRatings,
            orElse: () => 0,
          ),
      totalLists: basicStats.totalLists,
      totalShared: (await gamificationManager.getUserProgress()).contentShared,
    );

    // Sincronizar progreso inicial con Supabase
    await gamificationManager.syncProgressWithSupabase();

    LoggerFactory.info(
      '🏆 Estadísticas de gamificación actualizadas: ${basicStats.totalFavorites} favoritos, ${basicStats.totalWatched} vistas',
    );
  } catch (e) {
    LoggerFactory.error(
      '❌ Error actualizando estadísticas de gamificación: $e',
    );
  }

  /// Provider global para acceder al navigatorKey (debe estar definido en main.dart)
// Si tienes un navigatorKey global, puedes proveerlo aquí correctamente
});

/// Provider que notifica cuando hay nuevos logros desbloqueados
final newAchievementsProvider = StreamProvider<int>((ref) async* {
  // Escuchar cambios en las estadísticas
  ref.watch(gamificationStatsIntegrationProvider);

  final gamificationManager = GamificationManager.instance;

  // Emitir el número de logros nuevos cada vez que se actualicen las estadísticas
  await for (final achievement
      in gamificationManager.achievementUnlockedStream) {
    LoggerFactory.info('🏆 Nuevo logro desbloqueado: ${achievement.name}');
    yield 1; // Emitir que hay un nuevo logro
  }
});

/// Provider para obtener el progreso actual de gamificación
final gamificationProgressProvider = FutureProvider.autoDispose((ref) async {
  // Asegurar que las estadísticas estén actualizadas
  await ref.watch(gamificationStatsIntegrationProvider.future);

  final gamificationManager = GamificationManager.instance;
  return await gamificationManager.getUserProgress();
});

/// Provider para obtener los logros del usuario
final userAchievementsProvider = FutureProvider.autoDispose((ref) async {
  await ref.watch(gamificationStatsIntegrationProvider.future);

  final gamificationManager = GamificationManager.instance;
  return await gamificationManager.getUserAchievements();
});

/// Provider para obtener los logros desbloqueados recientemente
final recentAchievementsProvider = FutureProvider.autoDispose((ref) async {
  await ref.watch(gamificationStatsIntegrationProvider.future);

  final gamificationManager = GamificationManager.instance;
  return await gamificationManager.getRecentAchievements(limit: 5);
});

// === Providers para el nuevo GamificationService ===

/// Provider para el servicio de gamificación
final gamificationServiceProvider = Provider<GamificationService>((ref) {
  return gamificationServiceInstance;
});

/// Provider para obtener las estadísticas de gamificación de un usuario
final gamificationStatsProvider =
    FutureProvider.family<GamificationStats, String>((ref, userId) async {
  final service = ref.read(gamificationServiceProvider);
  return await service.getGamificationStats(userId);
});

/// Provider para obtener el progreso detallado de logros activos
final activeAchievementProgressProvider =
    FutureProvider.family<List<DetailedAchievementProgress>, String>(
        (ref, userId) async {
  final service = ref.read(gamificationServiceProvider);
  return await service.getActiveAchievementProgress(userId);
});

/// Provider para obtener todo el progreso detallado de logros
final detailedAchievementProgressProvider =
    FutureProvider.family<List<DetailedAchievementProgress>, String>(
        (ref, userId) async {
  final service = ref.read(gamificationServiceProvider);
  return await service.getDetailedAchievementProgress(userId);
});
