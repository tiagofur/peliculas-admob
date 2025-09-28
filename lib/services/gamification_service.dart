import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import '../core/logging/logger_factory.dart';
import '../domain/entities/achievement.dart';
import '../domain/entities/achievement_progress.dart';
import '../domain/entities/movie.dart';
import '../domain/entities/user_achievements.dart';
import '../infrastructure/services/cross_platform_init_service.dart';

/// Servicio principal para el manejo de gamificación, logros y progreso del usuario
class GamificationService {
  static const String _userAchievementsBoxName = 'userAchievements';
  static const String _achievementProgressBoxName = 'achievementProgress';
  static const String _achievementsBoxName = 'achievements';

  late Box<UserAchievements> _userAchievementsBox;
  late Box<AchievementProgress> _achievementProgressBox;
  late Box<Achievement> _achievementsBox;

  bool _isInitialized = false;

  /// Stream controller para notificar cambios en logros
  final _achievementUnlockedController =
      StreamController<Achievement>.broadcast();
  Stream<Achievement> get onAchievementUnlocked =>
      _achievementUnlockedController.stream;

  /// Stream controller para notificar cambios en progreso
  final _progressUpdatedController =
      StreamController<AchievementProgress>.broadcast();
  Stream<AchievementProgress> get onProgressUpdated =>
      _progressUpdatedController.stream;

  /// Inicializa el servicio y carga los logros predefinidos
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      LoggerFactory.info('Inicializando GamificationService...');

      // Asegurar que Hive y los adaptadores estén listos en todas las plataformas
      await CrossPlatformInitService.instance.initialize();

      _userAchievementsBox =
          await Hive.openBox<UserAchievements>(_userAchievementsBoxName);
      _achievementProgressBox =
          await Hive.openBox<AchievementProgress>(_achievementProgressBoxName);
      _achievementsBox = await Hive.openBox<Achievement>(_achievementsBoxName);

      await _initializeDefaultAchievements();
      _isInitialized = true;

      LoggerFactory.info('GamificationService inicializado exitosamente');
    } catch (e) {
      LoggerFactory.error('Error inicializando GamificationService: $e');
      rethrow;
    }
  }

  /// Obtiene o crea el perfil de logros para un usuario
  Future<UserAchievements> getUserAchievements(String userId) async {
    _ensureInitialized();

    var userAchievements = _userAchievementsBox.get(userId);
    if (userAchievements == null) {
      userAchievements = UserAchievements(
        userId: userId,
        lastUpdated: DateTime.now(),
      );
      await _userAchievementsBox.put(userId, userAchievements);
      LoggerFactory.info('Creado nuevo perfil de logros para usuario: $userId');
    }

    return userAchievements;
  }

  /// Actualiza el progreso de un usuario basado en una acción específica
  Future<List<Achievement>> updateProgress(
    String userId,
    String action, {
    int amount = 1,
    Map<String, dynamic>? metadata,
  }) async {
    _ensureInitialized();

    LoggerFactory.info(
        'Actualizando progreso para usuario $userId: $action (+$amount)');

    final unlockedAchievements = <Achievement>[];
    final relevantAchievements = await _getRelevantAchievements(action);

    for (final achievement in relevantAchievements) {
      final progress = await _updateAchievementProgress(
          userId, achievement, amount, action, metadata);

      if (progress.isReadyToUnlock(achievement.targetValue) &&
          !progress.isUnlocked) {
        final unlockedAchievement =
            await _unlockAchievement(userId, achievement);
        if (unlockedAchievement != null) {
          unlockedAchievements.add(unlockedAchievement);
        }
      }
    }

    return unlockedAchievements;
  }

  /// Procesa eventos específicos de películas para actualizar progreso
  Future<List<Achievement>> processMovieEvent(
      String userId, String eventType, Movie movie) async {
    final metadata = {
      'movieId': movie.id.toString(),
      'movieTitle': movie.title,
      'movieYear': movie.releaseDate.year,
      'movieRating': movie.voteAverage,
      'genres': movie.genreIds,
    };

    switch (eventType) {
      case 'movie_watched':
        return await updateProgress(userId, 'movies_watched',
            metadata: metadata);
      case 'movie_rated':
        return await updateProgress(userId, 'movies_rated', metadata: metadata);
      case 'movie_favorited':
        return await updateProgress(userId, 'movies_favorited',
            metadata: metadata);
      case 'genre_explored':
        final genreUpdates = <Achievement>[];
        for (final genre in movie.genreIds) {
          final achievements = await updateProgress(
              userId, 'genre_${genre.toLowerCase()}',
              metadata: metadata);
          genreUpdates.addAll(achievements);
        }
        return genreUpdates;
      default:
        LoggerFactory.warning('Evento de película desconocido: $eventType');
        return [];
    }
  }

  /// Obtiene todos los logros disponibles
  Future<List<Achievement>> getAllAchievements() async {
    _ensureInitialized();
    return _achievementsBox.values.toList();
  }

  /// Obtiene el progreso detallado de todos los logros de un usuario
  Future<Map<String, AchievementProgress>> getUserProgressDetails(
      String userId) async {
    _ensureInitialized();

    final progressMap = <String, AchievementProgress>{};
    final allAchievements = await getAllAchievements();

    for (final achievement in allAchievements) {
      final key = '${userId}_${achievement.id}';
      var progress = _achievementProgressBox.get(key);

      if (progress == null) {
        progress = AchievementProgress(
          achievementId: achievement.id,
          userId: userId,
          lastUpdated: DateTime.now(),
        );
        await _achievementProgressBox.put(key, progress);
      }

      progressMap[achievement.id] = progress;
    }

    return progressMap;
  }

  /// Calcula estadísticas de gamificación para un usuario
  Future<GamificationStats> getGamificationStats(String userId) async {
    _ensureInitialized();

    final userAchievements = await getUserAchievements(userId);
    // final progressDetails = await getUserProgressDetails(userId); // Para uso futuro
    final allAchievements = await getAllAchievements();

    final totalAchievements = allAchievements.length;
    final unlockedCount = userAchievements.unlockedAchievements.length;
    final completionRate =
        totalAchievements > 0 ? (unlockedCount / totalAchievements) : 0.0;

    final rarityDistribution = <AchievementRarity, int>{};
    for (final achievementId in userAchievements.unlockedAchievements) {
      final achievement =
          allAchievements.firstWhere((a) => a.id == achievementId);
      rarityDistribution[achievement.rarity] =
          (rarityDistribution[achievement.rarity] ?? 0) + 1;
    }

    return GamificationStats(
      userId: userId,
      totalPoints: userAchievements.totalPoints,
      totalAchievements: totalAchievements,
      unlockedAchievements: unlockedCount,
      completionRate: completionRate,
      rarityDistribution: rarityDistribution,
      currentStreaks: userAchievements.streaks,
      recentUnlocks: userAchievements.getRecentUnlocks().length,
    );
  }

  /// Actualiza el progreso específico de un logro
  Future<AchievementProgress> _updateAchievementProgress(
    String userId,
    Achievement achievement,
    int amount,
    String triggerEvent,
    Map<String, dynamic>? metadata,
  ) async {
    final key = '${userId}_${achievement.id}';
    var progress = _achievementProgressBox.get(key);

    progress ??= AchievementProgress(
      achievementId: achievement.id,
      userId: userId,
    );

    if (progress.isUnlocked && !achievement.isRepeatable) {
      return progress; // No actualizar logros ya desbloqueados no repetibles
    }

    final newValue = progress.currentValue + amount;
    final progressEntry = ProgressEntry(
      timestamp: DateTime.now(),
      progressAmount: amount,
      triggerEvent: triggerEvent,
      metadata: metadata ?? {},
    );

    final updatedHistory = List<ProgressEntry>.from(progress.progressHistory)
      ..add(progressEntry);

    final updatedProgress = progress.copyWith(
      currentValue: newValue,
      progressHistory: updatedHistory,
      lastUpdated: DateTime.now(),
    );

    await _achievementProgressBox.put(key, updatedProgress);
    _progressUpdatedController.add(updatedProgress);

    return updatedProgress;
  }

  /// Desbloquea un logro para un usuario
  Future<Achievement?> _unlockAchievement(
      String userId, Achievement achievement) async {
    try {
      final userAchievements = await getUserAchievements(userId);

      if (userAchievements.isAchievementUnlocked(achievement.id) &&
          !achievement.isRepeatable) {
        return null; // Ya está desbloqueado
      }

      // Verificar prerequisitos
      if (achievement.prerequisites.isNotEmpty) {
        final hasAllPrerequisites = achievement.prerequisites
            .every((prereq) => userAchievements.isAchievementUnlocked(prereq));
        if (!hasAllPrerequisites) {
          LoggerFactory.info(
              'Logro ${achievement.id} no puede desbloquearse: faltan prerequisitos');
          return null;
        }
      }

      // Actualizar progreso específico
      final key = '${userId}_${achievement.id}';
      final progress = _achievementProgressBox.get(key);
      if (progress != null) {
        final unlockedProgress = progress.copyWith(
          isUnlocked: true,
          unlockedDate: DateTime.now(),
        );
        await _achievementProgressBox.put(key, unlockedProgress);
      }

      // Actualizar logros del usuario
      final newUnlockedList =
          List<String>.from(userAchievements.unlockedAchievements);
      if (!newUnlockedList.contains(achievement.id)) {
        newUnlockedList.add(achievement.id);
      }

      final updatedUserAchievements = userAchievements.copyWith(
        unlockedAchievements: newUnlockedList,
        totalPoints: userAchievements.totalPoints + achievement.points,
        lastUpdated: DateTime.now(),
      );

      await _userAchievementsBox.put(userId, updatedUserAchievements);

      LoggerFactory.info(
          'Logro desbloqueado: ${achievement.title} para usuario $userId (+${achievement.points} puntos)');
      _achievementUnlockedController.add(achievement);

      return achievement;
    } catch (e) {
      LoggerFactory.error('Error desbloqueando logro ${achievement.id}: $e');
      return null;
    }
  }

  /// Obtiene logros relevantes para una acción específica
  Future<List<Achievement>> _getRelevantAchievements(String action) async {
    final allAchievements = await getAllAchievements();

    // Mapear acciones a tipos de logros
    final actionToType = <String, List<AchievementType>>{
      'movies_watched': [
        AchievementType.moviesWatched,
        AchievementType.timeSpent
      ],
      'movies_rated': [AchievementType.socialInteraction],
      'movies_favorited': [AchievementType.qualityViewer],
      'year_active': [AchievementType.yearStreak],
    };

    // Incluir logros de géneros específicos
    final genreActions = allAchievements
        .where((a) => action.startsWith('genre_'))
        .map((a) => a.id)
        .toSet();

    if (action.startsWith('genre_')) {
      return allAchievements
          .where((a) =>
              a.type == AchievementType.genreExplorer ||
              genreActions.contains(a.id))
          .toList();
    }

    final relevantTypes = actionToType[action] ?? [];
    return allAchievements
        .where((a) => relevantTypes.contains(a.type))
        .toList();
  }

  /// Inicializa logros predefinidos del sistema
  Future<void> _initializeDefaultAchievements() async {
    if (_achievementsBox.isNotEmpty) {
      return; // Ya están inicializados
    }

    LoggerFactory.info('Inicializando logros predefinidos...');

    final defaultAchievements = [
      // Logros de películas vistas
      Achievement(
        id: 'first_movie',
        title: 'Primera Película',
        description: 'Ver tu primera película',
        iconName: 'movie',
        targetValue: 1,
        category: AchievementCategory.movies,
        type: AchievementType.moviesWatched,
        rarity: AchievementRarity.common,
        points: 5,
        unlockMessage: '¡Bienvenido al mundo del cine!',
      ),

      Achievement(
        id: 'movie_enthusiast',
        title: 'Entusiasta del Cine',
        description: 'Ver 50 películas',
        iconName: 'theaters',
        targetValue: 50,
        category: AchievementCategory.movies,
        type: AchievementType.moviesWatched,
        rarity: AchievementRarity.uncommon,
        points: 25,
        unlockMessage: '¡Tu pasión por el cine está creciendo!',
      ),

      Achievement(
        id: 'movie_addict',
        title: 'Adicto al Cine',
        description: 'Ver 200 películas',
        iconName: 'local_movies',
        targetValue: 200,
        category: AchievementCategory.movies,
        type: AchievementType.moviesWatched,
        rarity: AchievementRarity.rare,
        points: 100,
        unlockMessage: '¡Eres un verdadero cinéfilo!',
      ),

      // Logros de exploración de géneros
      Achievement(
        id: 'genre_explorer',
        title: 'Explorador de Géneros',
        description: 'Ver películas de 10 géneros diferentes',
        iconName: 'explore',
        targetValue: 10,
        category: AchievementCategory.exploration,
        type: AchievementType.genreExplorer,
        rarity: AchievementRarity.uncommon,
        points: 30,
        unlockMessage: '¡Tienes un gusto cinematográfico diverso!',
      ),

      // Logros sociales
      Achievement(
        id: 'critic',
        title: 'Crítico Novato',
        description: 'Calificar 25 películas',
        iconName: 'star',
        targetValue: 25,
        category: AchievementCategory.social,
        type: AchievementType.socialInteraction,
        rarity: AchievementRarity.common,
        points: 15,
        unlockMessage: '¡Tu opinión cuenta!',
      ),

      Achievement(
        id: 'expert_critic',
        title: 'Crítico Experto',
        description: 'Calificar 100 películas',
        iconName: 'verified',
        targetValue: 100,
        category: AchievementCategory.social,
        type: AchievementType.socialInteraction,
        rarity: AchievementRarity.rare,
        points: 50,
        unlockMessage: '¡Eres una voz respetada en la comunidad!',
      ),

      // Logros de favoritos
      Achievement(
        id: 'collector',
        title: 'Coleccionista',
        description: 'Agregar 20 películas a favoritos',
        iconName: 'favorite',
        targetValue: 20,
        category: AchievementCategory.favorites,
        type: AchievementType.qualityViewer,
        rarity: AchievementRarity.uncommon,
        points: 20,
        unlockMessage: '¡Tienes excelente gusto!',
      ),

      // Logros especiales y legendarios
      Achievement(
        id: 'time_traveler',
        title: 'Viajero del Tiempo',
        description: 'Ver películas de 8 décadas diferentes',
        iconName: 'schedule',
        targetValue: 8,
        category: AchievementCategory.exploration,
        type: AchievementType.discovery,
        rarity: AchievementRarity.epic,
        points: 75,
        unlockMessage: '¡Has viajado a través del tiempo cinematográfico!',
        isHidden: true,
      ),

      Achievement(
        id: 'perfectionist',
        title: 'Perfeccionista',
        description:
            'Ver solo películas con rating superior a 8.0 durante un mes',
        iconName: 'diamond',
        targetValue: 30,
        category: AchievementCategory.movies,
        type: AchievementType.qualityViewer,
        rarity: AchievementRarity.legendary,
        points: 150,
        unlockMessage: '¡Tu estándar de calidad es impecable!',
        isHidden: true,
      ),
    ];

    for (final achievement in defaultAchievements) {
      await _achievementsBox.put(achievement.id, achievement);
    }

    LoggerFactory.info(
        '${defaultAchievements.length} logros predefinidos inicializados');
  }

  /// Obtiene el progreso detallado de logros con información completa
  Future<List<DetailedAchievementProgress>> getDetailedAchievementProgress(
      String userId) async {
    _ensureInitialized();

    final allAchievements = _achievementsBox.values.toList();
    final detailedProgress = <DetailedAchievementProgress>[];

    for (final achievement in allAchievements) {
      final key = '${userId}_${achievement.id}';
      var progress = _achievementProgressBox.get(key);

      progress ??= AchievementProgress(
        achievementId: achievement.id,
        userId: userId,
      );

      final detailed = DetailedAchievementProgress(
        achievement: achievement,
        progress: progress,
      );

      detailedProgress.add(detailed);
    }

    return detailedProgress;
  }

  /// Obtiene el progreso detallado solo de logros activos (con progreso > 0 y no completados)
  Future<List<DetailedAchievementProgress>> getActiveAchievementProgress(
      String userId) async {
    final allProgress = await getDetailedAchievementProgress(userId);

    return allProgress
        .where((detailed) =>
            detailed.progress.currentValue > 0 && !detailed.progress.isUnlocked)
        .toList()
      ..sort((a, b) =>
          b.getProgressPercentage().compareTo(a.getProgressPercentage()));
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
          'GamificationService no ha sido inicializado. Llama a initialize() primero.');
    }
  }

  /// Cierra el servicio y libera recursos
  Future<void> dispose() async {
    await _achievementUnlockedController.close();
    await _progressUpdatedController.close();
  }
}

/// Clase que combina información del logro con su progreso actual
class DetailedAchievementProgress {
  const DetailedAchievementProgress({
    required this.achievement,
    required this.progress,
  });

  final Achievement achievement;
  final AchievementProgress progress;

  /// Calcula el progreso como porcentaje
  double getProgressPercentage() {
    return progress.getProgressPercentage(achievement.targetValue);
  }

  /// Indica si está cerca de completarse (75% o más)
  bool get isNearCompletion => getProgressPercentage() >= 0.75;

  /// Indica si está completado pero no desbloqueado
  bool get isReadyToUnlock => progress.isReadyToUnlock(achievement.targetValue);

  @override
  String toString() {
    return 'DetailedAchievementProgress(${achievement.title}: '
        '${progress.currentValue}/${achievement.targetValue} = '
        '${(getProgressPercentage() * 100).toInt()}%)';
  }
}

/// Estadísticas de gamificación para un usuario
class GamificationStats {
  const GamificationStats({
    required this.userId,
    required this.totalPoints,
    required this.totalAchievements,
    required this.unlockedAchievements,
    required this.completionRate,
    required this.rarityDistribution,
    required this.currentStreaks,
    required this.recentUnlocks,
  });

  final String userId;
  final int totalPoints;
  final int totalAchievements;
  final int unlockedAchievements;
  final double completionRate;
  final Map<AchievementRarity, int> rarityDistribution;
  final Map<String, int> currentStreaks;
  final int recentUnlocks;

  /// Nivel del usuario basado en puntos totales
  int get level {
    if (totalPoints < 50) return 1;
    if (totalPoints < 150) return 2;
    if (totalPoints < 300) return 3;
    if (totalPoints < 500) return 4;
    if (totalPoints < 750) return 5;
    if (totalPoints < 1000) return 6;
    if (totalPoints < 1500) return 7;
    if (totalPoints < 2000) return 8;
    if (totalPoints < 3000) return 9;
    return 10; // Nivel máximo
  }

  /// Puntos necesarios para el siguiente nivel
  int get pointsToNextLevel {
    final nextLevelThresholds = [
      50,
      150,
      300,
      500,
      750,
      1000,
      1500,
      2000,
      3000
    ];

    for (final threshold in nextLevelThresholds) {
      if (totalPoints < threshold) {
        return threshold - totalPoints;
      }
    }
    return 0; // Ya está en el nivel máximo
  }

  @override
  String toString() {
    return 'GamificationStats(user: $userId, points: $totalPoints, level: $level, '
        'completion: ${(completionRate * 100).toStringAsFixed(1)}%)';
  }
}

/// Instancia singleton del servicio de gamificación
/// Para uso con Riverpod, usar el provider apropiado en los providers
GamificationService? _instance;
GamificationService get gamificationServiceInstance {
  _instance ??= GamificationService();
  return _instance!;
}
