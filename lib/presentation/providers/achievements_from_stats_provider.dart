import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/entities/achievement.dart';
import 'storage/direct_favorites_provider.dart';
import 'storage/direct_watchlist_provider.dart';
import 'user_stats_provider.dart';

/// Provider que calcula el progreso de logros DIRECTAMENTE desde las estadísticas reales
/// En lugar de tracking manual, simplemente lee los contadores existentes
final achievementsFromStatsProvider =
    FutureProvider.autoDispose<List<AchievementWithProgress>>((ref) async {
  // Obtener estadísticas reales
  final basicStats = ref.watch(basicUserStatsProvider);
  final ratingStats = await ref.watch(userRatingStatsProvider.future);
  final watchlistMap = ref.watch(directWatchlistMoviesProvider);
  final favoritesMap = ref.watch(directFavoriteMoviesProvider);

  // Contadores reales
  final moviesWatched = basicStats.totalWatched;
  final moviesRated = ratingStats.totalRatings;
  final moviesFavorited = favoritesMap.length;
  final moviesInWatchlist = watchlistMap.length;

  LoggerFactory.info(
      '📊 Calculando logros desde estadísticas: Vistas=$moviesWatched, Calificadas=$moviesRated, Favoritos=$moviesFavorited, Watchlist=$moviesInWatchlist');

  // Definir todos los logros con su progreso calculado desde estadísticas
  final achievements = <AchievementWithProgress>[
    // PELÍCULAS VISTAS
    _createAchievement(
      id: 'first_movie',
      title: 'Primera Película',
      description: 'Ver tu primera película',
      target: 1,
      currentProgress: moviesWatched,
      category: AchievementCategory.movies,
      rarity: AchievementRarity.common,
      points: 5,
    ),
    _createAchievement(
      id: 'movie_enthusiast',
      title: 'Entusiasta del Cine',
      description: 'Ver 50 películas',
      target: 50,
      currentProgress: moviesWatched,
      category: AchievementCategory.movies,
      rarity: AchievementRarity.uncommon,
      points: 25,
    ),
    _createAchievement(
      id: 'movie_addict',
      title: 'Adicto al Cine',
      description: 'Ver 200 películas',
      target: 200,
      currentProgress: moviesWatched,
      category: AchievementCategory.movies,
      rarity: AchievementRarity.rare,
      points: 100,
    ),

    // CALIFICACIONES
    _createAchievement(
      id: 'critic',
      title: 'Crítico Novato',
      description: 'Calificar 25 películas',
      target: 25,
      currentProgress: moviesRated,
      category: AchievementCategory.social,
      rarity: AchievementRarity.common,
      points: 15,
    ),
    _createAchievement(
      id: 'expert_critic',
      title: 'Crítico Experto',
      description: 'Calificar 100 películas',
      target: 100,
      currentProgress: moviesRated,
      category: AchievementCategory.social,
      rarity: AchievementRarity.rare,
      points: 50,
    ),

    // FAVORITOS
    _createAchievement(
      id: 'collector',
      title: 'Coleccionista',
      description: 'Agregar 20 películas a favoritos',
      target: 20,
      currentProgress: moviesFavorited,
      category: AchievementCategory.favorites,
      rarity: AchievementRarity.uncommon,
      points: 20,
    ),

    // WATCHLIST
    _createAchievement(
      id: 'watchlist_starter',
      title: 'Lista en Marcha',
      description: 'Agregar 10 películas a tu watchlist',
      target: 10,
      currentProgress: moviesInWatchlist,
      category: AchievementCategory.social,
      rarity: AchievementRarity.common,
      points: 10,
    ),
    _createAchievement(
      id: 'watchlist_master',
      title: 'Maestro de la Lista',
      description: 'Agregar 50 películas a tu watchlist',
      target: 50,
      currentProgress: moviesInWatchlist,
      category: AchievementCategory.social,
      rarity: AchievementRarity.uncommon,
      points: 25,
    ),
  ];

  return achievements;
});

/// Helper para crear un logro con progreso
AchievementWithProgress _createAchievement({
  required String id,
  required String title,
  required String description,
  required int target,
  required int currentProgress,
  required AchievementCategory category,
  required AchievementRarity rarity,
  required int points,
}) {
  // Calcular si está desbloqueado
  final isUnlocked = currentProgress >= target;
  final progressPercentage = target > 0 ? (currentProgress / target) : 0.0;

  return AchievementWithProgress(
    achievement: Achievement(
      id: id,
      title: title,
      description: description,
      iconName: _getIconForCategory(category),
      targetValue: target,
      currentValue: currentProgress,
      category: category,
      type: _getTypeForCategory(category),
      rarity: rarity,
      points: points,
      unlockMessage: '¡Logro desbloqueado!',
      isUnlocked: isUnlocked,
      unlockedDate: isUnlocked ? DateTime.now() : null,
    ),
    currentProgress: currentProgress,
    progressPercentage: progressPercentage.clamp(0.0, 1.0),
  );
}

/// Helper para obtener icono según categoría
String _getIconForCategory(AchievementCategory category) {
  switch (category) {
    case AchievementCategory.movies:
      return 'movie';
    case AchievementCategory.social:
      return 'star';
    case AchievementCategory.favorites:
      return 'favorite';
    case AchievementCategory.exploration:
      return 'explore';
  }
}

/// Helper para obtener tipo según categoría
AchievementType _getTypeForCategory(AchievementCategory category) {
  switch (category) {
    case AchievementCategory.movies:
      return AchievementType.moviesWatched;
    case AchievementCategory.social:
      return AchievementType.socialInteraction;
    case AchievementCategory.favorites:
      return AchievementType.qualityViewer;
    case AchievementCategory.exploration:
      return AchievementType.genreExplorer;
  }
}

/// Clase para representar un logro con su progreso calculado
class AchievementWithProgress {
  const AchievementWithProgress({
    required this.achievement,
    required this.currentProgress,
    required this.progressPercentage,
  });

  final Achievement achievement;
  final int currentProgress;
  final double progressPercentage;

  bool get isUnlocked => achievement.isUnlocked;
  bool get isNearCompletion => progressPercentage >= 0.75 && !isUnlocked;
  int get remainingProgress => achievement.targetValue - currentProgress;
}

/// Provider para estadísticas de logros
final achievementStatsFromRealDataProvider =
    Provider.autoDispose<AchievementStatsFromRealData>((ref) {
  final achievementsAsync = ref.watch(achievementsFromStatsProvider);

  return achievementsAsync.when(
    data: (achievements) {
      final totalAchievements = achievements.length;
      final unlockedAchievements =
          achievements.where((a) => a.isUnlocked).length;
      final totalPoints = achievements
          .where((a) => a.isUnlocked)
          .fold<int>(0, (sum, a) => sum + a.achievement.points);

      return AchievementStatsFromRealData(
        totalAchievements: totalAchievements,
        unlockedAchievements: unlockedAchievements,
        lockedAchievements: totalAchievements - unlockedAchievements,
        totalPoints: totalPoints,
        completionPercentage: totalAchievements > 0
            ? unlockedAchievements / totalAchievements
            : 0,
      );
    },
    loading: () => const AchievementStatsFromRealData(
      totalAchievements: 0,
      unlockedAchievements: 0,
      lockedAchievements: 0,
      totalPoints: 0,
      completionPercentage: 0,
    ),
    error: (_, _) => const AchievementStatsFromRealData(
      totalAchievements: 0,
      unlockedAchievements: 0,
      lockedAchievements: 0,
      totalPoints: 0,
      completionPercentage: 0,
    ),
  );
});

/// Estadísticas de logros calculadas desde datos reales
class AchievementStatsFromRealData {
  const AchievementStatsFromRealData({
    required this.totalAchievements,
    required this.unlockedAchievements,
    required this.lockedAchievements,
    required this.totalPoints,
    required this.completionPercentage,
  });

  final int totalAchievements;
  final int unlockedAchievements;
  final int lockedAchievements;
  final int totalPoints;
  final double completionPercentage;
}
