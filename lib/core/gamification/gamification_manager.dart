import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/base_logger.dart';
import '../logging/logger_factory.dart';
import 'models/achievement.dart';
import 'models/activity_type.dart' as activity;
import 'models/badge.dart' as gamification_badge;
import 'models/challenge.dart';
import 'models/user_level.dart';
import 'models/user_progress.dart';

// Gestor principal de gamificación
class GamificationManager extends ChangeNotifier {
  factory GamificationManager() => _instance;
  GamificationManager._internal();
  // Track last checked achievement IDs
  final Set<String> _lastCheckedAchievementIds = {};

  /// Returns newly unlocked achievements since last check
  Future<List<Achievement>> checkAchievements() async {
    // Get all achievements
    final allAchievements = await getUserAchievements();
    // Filter achievements that were not previously checked
    final newAchievements = allAchievements
        .where((a) => !_lastCheckedAchievementIds.contains(a.id))
        .toList();
    // Update last checked set
    _lastCheckedAchievementIds.addAll(newAchievements.map((a) => a.id));
    return newAchievements;
  }

  static final GamificationManager _instance = GamificationManager._internal();
  static GamificationManager get instance => _instance;

  UserProgress _userProgress = UserProgress(
    userId: 'default',
    totalPoints: 0,
    currentLevel: 1,
    moviesWatched: 0,
    moviesFavorited: 0,
    contentShared: 0,
    reviewsWritten: 0,
    watchlistsCompleted: 0,
    genresExplored: 0,
    streakDays: 0,
    lastActivityDate: DateTime.now(),
  );
  List<Achievement> _availableAchievements = [];
  List<Challenge> _activeChallenges = [];
  final StreamController<Achievement> _achievementUnlockedController =
      StreamController<Achievement>.broadcast();
  final StreamController<Challenge> _challengeCompletedController =
      StreamController<Challenge>.broadcast();
  final _levelUpController = StreamController<UserLevel>.broadcast();
  final _badgeController =
      StreamController<gamification_badge.Badge>.broadcast();

  // Getters
  UserProgress get userProgress => _userProgress;
  List<Achievement> get availableAchievements => _availableAchievements;
  List<Challenge> get activeChallenges => _activeChallenges;
  Stream<Achievement> get achievementUnlockedStream =>
      _achievementUnlockedController.stream;
  Stream<Achievement> get achievementStream =>
      _achievementUnlockedController.stream;
  Stream<Challenge> get challengeCompletedStream =>
      _challengeCompletedController.stream;

  // Inicialización
  Future<void> initialize() async {
    await _loadUserProgress();
    await _initializeAchievements();
    await _loadActiveChallenges();
    _generateWeeklyChallenges();
  }

  // Carga del progreso del usuario
  Future<void> _loadUserProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressJson = prefs.getString('user_progress');
      if (progressJson != null) {
        final progressData = jsonDecode(progressJson);
        _userProgress = UserProgress.fromJson(progressData);
      }
    } catch (e) {
      LoggerFactory.error('Error loading user progress: $e',
          category: LogCategory.general);
    }
  }

  // Guardado del progreso del usuario
  Future<void> _saveUserProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressJson = jsonEncode(_userProgress.toJson());
      await prefs.setString('user_progress', progressJson);
    } catch (e) {
      LoggerFactory.error('Error saving user progress: $e',
          category: LogCategory.general);
    }
  }

  // Inicialización de logros
  Future<void> _initializeAchievements() async {
    _availableAchievements = [
      // Movie Explorer Achievements
      const Achievement(
        id: 'first_movie',
        name: 'Primera Película',
        description: 'Agrega tu primera película a favoritos',
        category: AchievementCategory.general,
        rarity: AchievementRarity.common,
        points: 10,
        maxProgress: 1,
        iconPath: 'assets/icons/first_movie.png',
      ),
      const Achievement(
        id: 'movie_collector',
        name: 'Coleccionista',
        description: 'Agrega 5 películas a favoritos',
        category: AchievementCategory.collection,
        rarity: AchievementRarity.common,
        points: 50,
        maxProgress: 5,
        iconPath: 'assets/icons/collector.png',
      ),
      const Achievement(
        id: 'movie_enthusiast',
        name: 'Entusiasta',
        description: 'Agrega 25 películas a favoritos',
        category: AchievementCategory.collection,
        rarity: AchievementRarity.uncommon,
        points: 100,
        maxProgress: 25,
        iconPath: 'assets/icons/enthusiast.png',
      ),
      const Achievement(
        id: 'movie_master',
        name: 'Maestro del Cine',
        description: 'Agrega 200 películas a favoritos',
        category: AchievementCategory.collection,
        rarity: AchievementRarity.rare,
        points: 500,
        maxProgress: 200,
        iconPath: 'assets/icons/movie_master.png',
      ),

      // Genre Master Achievements
      const Achievement(
        id: 'action_fan',
        name: 'Fan de Acción',
        description: 'Agrega 20 películas de acción a favoritos',
        category: AchievementCategory.movies,
        rarity: AchievementRarity.common,
        points: 50,
        maxProgress: 20,
        iconPath: 'assets/icons/action_fan.png',
      ),
      const Achievement(
        id: 'horror_enthusiast',
        name: 'Amante del Terror',
        description: 'Agrega 15 películas de terror a favoritos',
        category: AchievementCategory.movies,
        rarity: AchievementRarity.uncommon,
        points: 75,
        maxProgress: 15,
        iconPath: 'assets/icons/horror_fan.png',
      ),
      const Achievement(
        id: 'comedy_lover',
        name: 'Risas Garantizadas',
        description: 'Agrega 25 comedias a favoritos',
        category: AchievementCategory.movies,
        rarity: AchievementRarity.common,
        points: 60,
        maxProgress: 25,
        iconPath: 'assets/icons/comedy_lover.png',
      ),

      // Social Butterfly Achievements
      const Achievement(
        id: 'first_share',
        name: 'Primera Compartida',
        description: 'Comparte tu primera película',
        category: AchievementCategory.social,
        rarity: AchievementRarity.common,
        points: 15,
        maxProgress: 1,
        iconPath: 'assets/icons/first_share.png',
      ),
      const Achievement(
        id: 'social_star',
        name: 'Estrella Social',
        description: 'Comparte 50 películas',
        category: AchievementCategory.social,
        rarity: AchievementRarity.rare,
        points: 200,
        maxProgress: 50,
        iconPath: 'assets/icons/social_star.png',
      ),

      // Critic Achievements
      const Achievement(
        id: 'first_review',
        name: 'Primera Reseña',
        description: 'Escribe tu primera reseña',
        category: AchievementCategory.engagement,
        rarity: AchievementRarity.common,
        points: 25,
        maxProgress: 1,
        iconPath: 'assets/icons/first_review.png',
      ),
      const Achievement(
        id: 'prolific_critic',
        name: 'Crítico Prolífico',
        description: 'Escribe 25 reseñas',
        category: AchievementCategory.engagement,
        rarity: AchievementRarity.uncommon,
        points: 150,
        maxProgress: 25,
        iconPath: 'assets/icons/prolific_critic.png',
      ),
      const Achievement(
        id: 'master_critic',
        name: 'Crítico Maestro',
        description: 'Escribe 100 reseñas',
        category: AchievementCategory.engagement,
        rarity: AchievementRarity.rare,
        points: 500,
        maxProgress: 100,
        iconPath: 'assets/icons/master_critic.png',
      ),

      // Binge Watcher Achievements
      const Achievement(
        id: 'weekend_warrior',
        name: 'Guerrero del Fin de Semana',
        description: 'Agrega 5 películas en un día',
        category: AchievementCategory.general,
        rarity: AchievementRarity.common,
        points: 30,
        maxProgress: 5,
        iconPath: 'assets/icons/weekend_warrior.png',
      ),
      const Achievement(
        id: 'binge_master',
        name: 'Maestro del Maratón',
        description: 'Agrega 10 películas en un día',
        category: AchievementCategory.general,
        rarity: AchievementRarity.uncommon,
        points: 75,
        maxProgress: 10,
        iconPath: 'assets/icons/binge_master.png',
      ),

      // Daily Streak Achievements
      const Achievement(
        id: 'streak_3_days',
        name: 'Racha de 3 Días',
        description: 'Interactúa con la app 3 días seguidos',
        category: AchievementCategory.engagement,
        rarity: AchievementRarity.common,
        points: 20,
        maxProgress: 3,
        iconPath: 'assets/icons/streak_3.png',
      ),
      const Achievement(
        id: 'streak_7_days',
        name: 'Semana Completa',
        description: 'Mantén una racha de 7 días',
        category: AchievementCategory.engagement,
        rarity: AchievementRarity.uncommon,
        points: 75,
        maxProgress: 7,
        iconPath: 'assets/icons/streak_7.png',
      ),
      const Achievement(
        id: 'streak_30_days',
        name: 'Dedicación Total',
        description: 'Mantén una racha de 30 días',
        category: AchievementCategory.engagement,
        rarity: AchievementRarity.rare,
        points: 300,
        maxProgress: 30,
        iconPath: 'assets/icons/streak_30.png',
      ),

      // Completionist Achievements
      const Achievement(
        id: 'watchlist_complete',
        name: 'Lista Completada',
        description: 'Completa tu primera lista de reproducción',
        category: AchievementCategory.collection,
        rarity: AchievementRarity.uncommon,
        points: 100,
        maxProgress: 1,
        iconPath: 'assets/icons/watchlist_complete.png',
      ),
    ];

    // Cargar progreso de logros guardado
    await _loadAchievementProgress();
  }

  // Carga del progreso de logros
  Future<void> _loadAchievementProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final achievementsJson = prefs.getString('achievements_progress');
      if (achievementsJson != null) {
        final achievementsData = jsonDecode(achievementsJson) as List<dynamic>;
        final savedAchievements = achievementsData
            .map((a) => Achievement.fromJson(a as Map<String, dynamic>))
            .toList();

        // Actualizar progreso de logros existentes
        for (int i = 0; i < _availableAchievements.length; i++) {
          final savedAchievement = savedAchievements.firstWhere(
            (a) => a.id == _availableAchievements[i].id,
            orElse: () => _availableAchievements[i],
          );
          _availableAchievements[i] = _availableAchievements[i].copyWith(
            isUnlocked: savedAchievement.isUnlocked,
            unlockedAt: savedAchievement.unlockedAt,
            progress: savedAchievement.progress,
          );
        }
      }
    } catch (e) {
      LoggerFactory.error('Error loading achievement progress: $e',
          category: LogCategory.general);
    }
  }

  // Guardado del progreso de logros
  Future<void> _saveAchievementProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final achievementsJson =
          jsonEncode(_availableAchievements.map((a) => a.toJson()).toList());
      await prefs.setString('achievements_progress', achievementsJson);
    } catch (e) {
      LoggerFactory.error('Error saving achievement progress: $e',
          category: LogCategory.general);
    }
  }

  // Carga de desafíos activos
  Future<void> _loadActiveChallenges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final challengesJson = prefs.getString('active_challenges');
      if (challengesJson != null) {
        final challengesData = jsonDecode(challengesJson) as List<dynamic>;
        _activeChallenges = challengesData
            .map((c) => Challenge.fromJson(c as Map<String, dynamic>))
            .where((c) => c.isActive && !c.isExpired)
            .toList();
      }
    } catch (e) {
      LoggerFactory.error('Error loading active challenges: $e',
          category: LogCategory.general);
    }
  }

  // Guardado de desafíos activos
  Future<void> _saveActiveChallenges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final challengesJson =
          jsonEncode(_activeChallenges.map((c) => c.toJson()).toList());
      await prefs.setString('active_challenges', challengesJson);
    } catch (e) {
      LoggerFactory.error('Error saving active challenges: $e',
          category: LogCategory.general);
    }
  }

  // Generación de desafíos semanales
  void _generateWeeklyChallenges() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    // Verificar si ya hay desafíos para esta semana
    final hasWeeklyChallenge = _activeChallenges.any((c) =>
        c.challengeType == 'weekly' &&
        c.startDate.isAfter(weekStart) &&
        c.endDate.isBefore(weekEnd.add(const Duration(days: 1))));

    if (!hasWeeklyChallenge) {
      final weeklyChallenges = [
        Challenge(
          id: 'weekly_explorer_${weekStart.millisecondsSinceEpoch}',
          title: 'Explorador Semanal',
          description: 'Agrega 10 películas a favoritos esta semana',
          pointsReward: 100,
          startDate: weekStart,
          endDate: weekEnd,
          targetValue: 10,
          challengeType: 'weekly',
        ),
        Challenge(
          id: 'weekly_social_${weekStart.millisecondsSinceEpoch}',
          title: 'Social de la Semana',
          description: 'Comparte 5 películas esta semana',
          pointsReward: 75,
          startDate: weekStart,
          endDate: weekEnd,
          targetValue: 5,
          challengeType: 'weekly',
        ),
        Challenge(
          id: 'weekly_critic_${weekStart.millisecondsSinceEpoch}',
          title: 'Crítico Semanal',
          description: 'Escribe 3 reseñas esta semana',
          pointsReward: 120,
          startDate: weekStart,
          endDate: weekEnd,
          targetValue: 3,
          challengeType: 'weekly',
        ),
      ];

      _activeChallenges.addAll(weeklyChallenges);
      _saveActiveChallenges();
    }
  }

  // Métodos de seguimiento de actividades
  Future<void> trackMovieAddedToFavorites(String movieId, String genre) async {
    await _updateProgress(
      moviesWatched: _userProgress.moviesWatched + 1,
      favoritesAdded: _userProgress.favoritesAdded + 1,
      points: 5,
    );

    // Actualizar estadísticas de género
    final updatedGenreStats = Map<String, int>.from(_userProgress.genreStats);
    updatedGenreStats[genre] = (updatedGenreStats[genre] ?? 0) + 1;

    _userProgress = _userProgress.copyWith(genreStats: updatedGenreStats);

    // Verificar logros relacionados
    await _checkAchievements({
      'favorites_added': _userProgress.favoritesAdded,
      'genre_$genre': updatedGenreStats[genre] ?? 0,
      'daily_movies': await _getDailyMovieCount(),
      'streak_days': _userProgress.streakDays,
    });

    // Verificar desafíos
    await _checkChallenges('favorites', 1);

    await _saveUserProgress();
    notifyListeners();
  }

  Future<void> trackMovieShared(String movieId) async {
    await _updateProgress(
      moviesShared: _userProgress.moviesShared + 1,
      points: 3,
    );

    await _checkAchievements({
      'movies_shared': _userProgress.moviesShared,
      'streak_days': _userProgress.streakDays,
    });

    await _checkChallenges('share', 1);

    await _saveUserProgress();
    notifyListeners();
  }

  Future<void> trackReviewWritten(String movieId, double rating) async {
    await _updateProgress(
      reviewsWritten: _userProgress.reviewsWritten + 1,
      points: 10,
    );

    await _checkAchievements({
      'reviews_written': _userProgress.reviewsWritten,
      'streak_days': _userProgress.streakDays,
    });

    await _checkChallenges('review', 1);

    await _saveUserProgress();
    notifyListeners();
  }

  Future<void> trackWatchlistCompleted(String watchlistId) async {
    await _updateProgress(
      watchlistsCompleted: _userProgress.watchlistsCompleted + 1,
      points: 50,
    );

    await _checkAchievements({
      'watchlists_completed': _userProgress.watchlistsCompleted,
      'streak_days': _userProgress.streakDays,
    });

    await _saveUserProgress();
    notifyListeners();
  }

  // Actualización del progreso del usuario
  Future<void> _updateProgress({
    int? moviesWatched,
    int? reviewsWritten,
    int? moviesShared,
    int? favoritesAdded,
    int? watchlistsCompleted,
    int points = 0,
  }) async {
    final oldLevel = _calculateLevel(_userProgress.totalPoints);
    final newTotalPoints = _userProgress.totalPoints + points;
    final newLevel = _calculateLevel(newTotalPoints);

    // Update daily streak
    final updatedStreakDays = await _updateDailyStreak();

    _userProgress = _userProgress.copyWith(
      totalPoints: newTotalPoints,
      currentLevel: newLevel.index + 1,
      moviesWatched: moviesWatched,
      reviewsWritten: reviewsWritten,
      contentShared: moviesShared,
      moviesFavorited: favoritesAdded,
      watchlistsCompleted: watchlistsCompleted,
      streakDays: updatedStreakDays,
      lastActivityDate: DateTime.now(),
    );

    // Detectar level up
    if (newLevel.index > oldLevel.index) {
      _levelUpController.add(newLevel);
      LoggerFactory.info('Level up! New level: ${newLevel.name}',
          category: LogCategory.general);
    }
  }

  // Cálculo del nivel del usuario
  UserLevel _calculateLevel(int totalPoints) {
    if (totalPoints >= 5000) return UserLevel.legend;
    if (totalPoints >= 3000) return UserLevel.master;
    if (totalPoints >= 1500) return UserLevel.expert;
    if (totalPoints >= 500) return UserLevel.enthusiast;
    return UserLevel.novice;
  }

  // Verificación de logros
  Future<void> _checkAchievements(Map<String, int> stats) async {
    for (int i = 0; i < _availableAchievements.length; i++) {
      final achievement = _availableAchievements[i];
      if (achievement.isUnlocked) continue;

      int currentProgress = 0;

      switch (achievement.id) {
        case 'first_movie':
        case 'movie_collector':
        case 'movie_enthusiast':
        case 'movie_master':
          currentProgress = stats['favorites_added'] ?? 0;
          break;
        case 'action_fan':
          currentProgress = stats['genre_Action'] ?? 0;
          break;
        case 'horror_enthusiast':
          currentProgress = stats['genre_Horror'] ?? 0;
          break;
        case 'comedy_lover':
          currentProgress = stats['genre_Comedy'] ?? 0;
          break;
        case 'first_share':
        case 'social_star':
          currentProgress = stats['movies_shared'] ?? 0;
          break;
        case 'first_review':
        case 'prolific_critic':
        case 'master_critic':
          currentProgress = stats['reviews_written'] ?? 0;
          break;
        case 'weekend_warrior':
        case 'binge_master':
          currentProgress = stats['daily_movies'] ?? 0;
          break;
        case 'streak_3_days':
        case 'streak_7_days':
        case 'streak_30_days':
          currentProgress = stats['streak_days'] ?? 0;
          break;
        case 'watchlist_complete':
          currentProgress = stats['watchlists_completed'] ?? 0;
          break;
      }

      // Actualizar progreso del logro
      _availableAchievements[i] = achievement.copyWith(
        progress: currentProgress,
      );

      // Verificar si se desbloqueó el logro
      if (currentProgress >= achievement.maxProgress &&
          !achievement.isUnlocked) {
        await _unlockAchievement(i);
      }
    }

    await _saveAchievementProgress();
  }

  // Desbloqueo de logros
  Future<void> _unlockAchievement(int achievementIndex) async {
    final achievement = _availableAchievements[achievementIndex];
    final unlockedAchievement = achievement.copyWith(
      isUnlocked: true,
      unlockedAt: DateTime.now(),
    );

    _availableAchievements[achievementIndex] = unlockedAchievement;

    // Otorgar puntos de recompensa
    _userProgress = _userProgress.copyWith(
      totalPoints: _userProgress.totalPoints + achievement.points,
    );

    // Notificar desbloqueo
    _achievementUnlockedController.add(unlockedAchievement);

    LoggerFactory.info('Achievement unlocked: ${achievement.name}',
        category: LogCategory.general);
  }

  // Verificación de desafíos
  Future<void> _checkChallenges(String activityType, int increment) async {
    for (int i = 0; i < _activeChallenges.length; i++) {
      final challenge = _activeChallenges[i];
      if (challenge.isCompleted || challenge.isExpired) continue;

      bool shouldUpdate = false;

      switch (challenge.challengeType) {
        case 'weekly':
          if ((challenge.id.contains('explorer') &&
                  activityType == 'favorites') ||
              (challenge.id.contains('social') && activityType == 'share') ||
              (challenge.id.contains('critic') && activityType == 'review')) {
            shouldUpdate = true;
          }
          break;
      }

      if (shouldUpdate) {
        final updatedChallenge = challenge.copyWith(
          currentProgress: challenge.currentProgress + increment,
        );

        _activeChallenges[i] = updatedChallenge;

        if (updatedChallenge.isCompleted && !challenge.isCompleted) {
          await _completeChallenge(i);
        }
      }
    }

    await _saveActiveChallenges();
  }

  // Completar desafío
  Future<void> _completeChallenge(int challengeIndex) async {
    final challenge = _activeChallenges[challengeIndex];

    // Otorgar puntos de recompensa
    _userProgress = _userProgress.copyWith(
      totalPoints: _userProgress.totalPoints + challenge.pointsReward,
    );

    // Notificar completado
    _challengeCompletedController.add(challenge);

    LoggerFactory.info('Challenge completed: ${challenge.title}',
        category: LogCategory.general);
  }

  // Obtener conteo diario de películas
  Future<int> _getDailyMovieCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    return prefs.getInt('daily_movies_$todayKey') ?? 0;
  }

  // Actualizar streak diario
  Future<int> _updateDailyStreak() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastActivity = DateTime(
      _userProgress.lastActivityDate.year,
      _userProgress.lastActivityDate.month,
      _userProgress.lastActivityDate.day,
    );

    // Si la última actividad fue hoy, mantener el streak actual
    if (today.isAtSameMomentAs(lastActivity)) {
      return _userProgress.streakDays;
    }

    // Si la última actividad fue ayer, incrementar el streak
    final yesterday = today.subtract(const Duration(days: 1));
    if (yesterday.isAtSameMomentAs(lastActivity)) {
      final newStreak = _userProgress.streakDays + 1;

      // Notificar hitos de streak
      if (newStreak % 7 == 0) {
        LoggerFactory.info('Weekly streak milestone reached: $newStreak days',
            category: LogCategory.general);
      }

      return newStreak;
    }

    // Si la última actividad fue hace más de un día, resetear el streak
    return 1; // Comenzar nuevo streak con la actividad de hoy
  }

  // Métodos de utilidad
  List<Achievement> getAchievementsByCategory(AchievementCategory category) {
    return _availableAchievements.where((a) => a.category == category).toList();
  }

  List<Achievement> getUnlockedAchievements() {
    return _availableAchievements.where((a) => a.isUnlocked).toList();
  }

  /// Get recent achievements ordered by unlock date
  Future<List<Achievement>> getRecentAchievements({int limit = 5}) async {
    final unlockedAchievements =
        getUnlockedAchievements().where((a) => a.unlockedAt != null).toList();

    // Sort by unlock date (most recent first)
    unlockedAchievements.sort((a, b) => (b.unlockedAt ?? DateTime(1970))
        .compareTo(a.unlockedAt ?? DateTime(1970)));

    // Return limited list
    return unlockedAchievements.take(limit).toList();
  }

  List<Achievement> getLockedAchievements() {
    return _availableAchievements.where((a) => !a.isUnlocked).toList();
  }

  List<Challenge> getActiveChallenges() {
    return _activeChallenges.where((c) => c.isActive && !c.isExpired).toList();
  }

  List<Challenge> getCompletedChallenges() {
    return _activeChallenges.where((c) => c.isCompleted).toList();
  }

  /// Get user progress
  Future<UserProgress> getUserProgress() async {
    return _userProgress;
  }

  /// Get current user level
  Future<UserLevel> getCurrentLevel() async {
    return _calculateLevel(_userProgress.totalPoints);
  }

  /// Get user achievements
  Future<List<Achievement>> getUserAchievements() async {
    return List<Achievement>.from(_availableAchievements);
  }

  /// Track user activity for gamification
  Future<void> trackActivity(activity.ActivityType activityType,
      {Map<String, dynamic>? metadata}) async {
    switch (activityType) {
      case activity.ActivityType.watchMovie:
        // Note: This method requires parameters, should be called with actual data
        // await trackMovieWatched(movieId);
        break;
      case activity.ActivityType.addToFavorites:
        // Note: This method requires parameters, should be called with actual data
        // await trackMovieFavorited(movieId);
        break;
      case activity.ActivityType.shareContent:
        // Note: This method requires parameters, should be called with actual data
        // await trackMovieShared(movieId);
        break;
      case activity.ActivityType.writeReview:
        // Note: This method requires parameters, should be called with actual data
        // await trackReviewWritten(movieId, rating);
        break;
      case activity.ActivityType.completeWatchlist:
        // Note: This method requires parameters, should be called with actual data
        // await trackWatchlistCompleted(watchlistId);
        break;
      case activity.ActivityType.exploreGenre:
        // Handle genre exploration
        break;
      case activity.ActivityType.bingeWatch:
        // Handle binge watching
        break;
      case activity.ActivityType.socialInteraction:
        // Handle social interactions
        break;
    }
  }

  /// Stream of challenge completion events
  Stream<Challenge> get challengeCompletionStream =>
      _challengeCompletedController.stream;

  /// Stream of level up events
  Stream<UserLevel> get levelUpStream => _levelUpController.stream;

  /// Stream of badge events
  Stream<gamification_badge.Badge> get badgeStream => _badgeController.stream;

  /// Reset user progress
  Future<void> resetProgress() async {
    _userProgress = UserProgress(
      userId: 'default',
      totalPoints: 0,
      currentLevel: 1,
      moviesWatched: 0,
      moviesFavorited: 0,
      contentShared: 0,
      reviewsWritten: 0,
      watchlistsCompleted: 0,
      genresExplored: 0,
      streakDays: 0,
      lastActivityDate: DateTime.now(),
    );
    await _initializeAchievements();
    _activeChallenges = [];
    await _saveUserProgress();
    await _saveAchievementProgress();
    await _saveActiveChallenges();
    notifyListeners();
  }

  // Check challenges for completion
  Future<List<Challenge>> checkChallenges() async {
    // Check all active challenges for completion
    List<Challenge> completed = [];
    _activeChallenges.removeWhere((challenge) {
      if (challenge.isCompleted) {
        completed.add(challenge);
        return true;
      }
      return false;
    });
    // Optionally, add to a completed challenges list if you track it
    // _completedChallenges.addAll(completed);
    notifyListeners();
    return completed;
  }



  // Limpieza
  @override
  void dispose() {
    _achievementUnlockedController.close();
    _challengeCompletedController.close();
    _levelUpController.close();
    _badgeController.close();
    super.dispose();
  }
}
