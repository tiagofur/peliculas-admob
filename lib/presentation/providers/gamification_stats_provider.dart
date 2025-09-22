import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/gamification/gamification_manager.dart';
import '../../core/logging/logger_factory.dart';
import 'movie_ratings_provider.dart' as ratings;
import 'user_stats_provider.dart';

/// Provider para obtener el número total de ratings del usuario
final totalUserRatingsProvider = FutureProvider<int>((ref) async {
  final ratingsStats = ref.watch(ratings.userRatingStatsProvider);
  return ratingsStats?['totalRatings'] ?? 0;
});

/// Provider para obtener el número total de contenido compartido
final totalSharedContentProvider = FutureProvider<int>((ref) async {
  try {
    final analyticsService = AnalyticsService.instance;
    final events = analyticsService.getEvents();

    // Contar eventos de compartir (movieShare, listShare, etc.)
    final shareEvents = events
        .where((event) =>
            event.type == AnalyticsEventType.movieShare ||
            event.properties['activity_type'] == 'movie_shared' ||
            event.properties['activity_type'] == 'list_shared' ||
            event.properties['activity_type'] == 'recommendation_shared')
        .length;

    return shareEvents;
  } catch (e) {
    LoggerFactory.error('❌ Error obteniendo total de contenido compartido: $e');
    return 0;
  }
});

/// Provider que integra las estadísticas del usuario con el sistema de gamificación
final gamificationStatsIntegrationProvider = FutureProvider<void>((ref) async {
  // Observar cambios en las estadísticas básicas del usuario
  final basicStats = ref.watch(basicUserStatsProvider);
  final totalRatings = await ref.watch(totalUserRatingsProvider.future);
  final totalShared = await ref.watch(totalSharedContentProvider.future);
  final gamificationManager = GamificationManager.instance;

  try {
    // FIXED: Actualizar estadísticas de gamificación con datos reales
    await gamificationManager.updateUserStats(
      totalWatched: basicStats.totalWatched,
      totalFavorites: basicStats.totalFavorites,
      totalRatings: totalRatings,
      totalLists: basicStats.totalLists,
      totalShared: totalShared,
    );

    LoggerFactory.info(
        '🏆 Estadísticas de gamificación actualizadas: ${basicStats.totalFavorites} favoritos, ${basicStats.totalWatched} vistas');
  } catch (e) {
    LoggerFactory.error(
        '❌ Error actualizando estadísticas de gamificación: $e');
  }
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
