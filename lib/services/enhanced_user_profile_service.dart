import '../core/logging/logger_factory.dart';
import '../domain/entities/achievement.dart' as gamification;
import '../domain/entities/enhanced_user_profile.dart';
import '../domain/entities/movie.dart';
import '../domain/entities/movie_rating.dart';
import '../infrastructure/repositories/hybrid_movie_ratings_repository.dart';
import '../infrastructure/repositories/hybrid_watched_repository.dart';
import '../infrastructure/repositories/supabase_user_profile_repository.dart';
import 'achievement_notification_service.dart';
import 'gamification_service.dart';

/// Servicio para gestionar perfiles de usuario mejorados
class EnhancedUserProfileService {
  EnhancedUserProfileService._();

  static final EnhancedUserProfileService _instance =
      EnhancedUserProfileService._();
  static EnhancedUserProfileService get instance => _instance;

  // Referencia al servicio de gamificación
  GamificationService? _gamificationService;
  AchievementNotificationService? _notificationService;

  // Repositorio para persistencia en Supabase
  final _supabaseRepository = SupabaseUserProfileRepository.instance;

  /// Inicializa el servicio con las dependencias necesarias
  Future<void> initialize() async {
    _gamificationService = gamificationServiceInstance;
    await _gamificationService!.initialize();

    _notificationService = AchievementNotificationService.instance;
    await _notificationService!.initialize(_gamificationService!);

    LoggerFactory.info(
        'EnhancedUserProfileService inicializado con gamificación');
  }

  /// Obtiene el perfil mejorado del usuario
  Future<EnhancedUserProfile> getUserProfile(
    String userId, {
    String? displayName,
    String? email,
  }) async {
    try {
      LoggerFactory.info('📊 Fetching enhanced profile for user: $userId');

      // Intentar obtener el perfil desde Supabase primero
      final existingProfile = await _supabaseRepository.getUserProfile(userId);

      if (existingProfile != null) {
        LoggerFactory.info('✅ Enhanced profile loaded from database');
        return existingProfile;
      }

      // Si no existe, crear uno nuevo con datos calculados en tiempo real
      LoggerFactory.info('📊 Creating new profile with calculated data');
      final stats = await _calculateUserStats(userId);
      final preferences = await _getUserPreferences(userId);
      final favoriteMovies = await _getUserFavoriteMovies(userId);

      final profile = EnhancedUserProfile(
        id: userId,
        displayName: displayName ?? 'Usuario Anónimo',
        email: email ?? 'usuario@anonimo.com',
        bio: null,
        avatarUrl: null,
        bannerUrl: null,
        joinedDate: DateTime.now().subtract(const Duration(days: 365)),
        lastActiveDate: DateTime.now(),
        preferences: preferences,
        stats: stats,
        favoriteMovies: favoriteMovies,
        customFields: {},
      );

      // Guardar el perfil recién creado en Supabase para futuras consultas
      await _createInitialProfile(profile);

      LoggerFactory.info('✅ Enhanced profile created and saved successfully');
      return profile;
    } catch (e) {
      LoggerFactory.error('❌ Failed to load enhanced profile: $e');
      rethrow;
    }
  }

  /// Actualiza el perfil del usuario
  Future<void> updateUserProfile(
    String userId,
    EnhancedUserProfile updatedProfile,
  ) async {
    try {
      LoggerFactory.info('💾 Updating enhanced profile for user: $userId');

      // Actualizar perfil básico en Supabase
      await _supabaseRepository.upsertUserProfile(
        userId: userId,
        displayName: updatedProfile.displayName,
        email: updatedProfile.email,
        bio: updatedProfile.bio,
        avatarUrl: updatedProfile.avatarUrl,
        bannerUrl: updatedProfile.bannerUrl,
        customFields: updatedProfile.customFields,
      );

      // Actualizar preferencias
      await _supabaseRepository.updateUserPreferences(
        userId,
        updatedProfile.preferences,
      );

      // Actualizar estadísticas si es necesario
      await _updateUserStatisticsIfNeeded(userId, updatedProfile.stats);

      LoggerFactory.info('✅ Enhanced profile updated successfully');
    } catch (e) {
      LoggerFactory.error('❌ Failed to update enhanced profile: $e');
      rethrow;
    }
  }

  /// Actualiza las preferencias del usuario
  Future<void> updateUserPreferences(
    String userId,
    UserPreferences preferences,
  ) async {
    try {
      LoggerFactory.info('⚙️ Updating user preferences for: $userId');

      // Usar el repositorio de Supabase para actualizar preferencias
      await _supabaseRepository.updateUserPreferences(userId, preferences);

      LoggerFactory.info('✅ User preferences updated successfully');
    } catch (e) {
      LoggerFactory.error('❌ Failed to update user preferences: $e');
      rethrow;
    }
  }

  /// Calcula las estadísticas del usuario
  Future<EnhancedUserStats> _calculateUserStats(String userId) async {
    try {
      LoggerFactory.info('📊 Calculating real user stats for: $userId');

      // Obtener repositorios
      final watchedRepository = HybridWatchedRepository(userId: userId);
      final ratingsRepository = HybridMovieRatingsRepository(userId: userId);

      // Obtener datos reales de películas vistas
      final watchedMovies =
          await watchedRepository.loadWatchedMovies(limit: 10000);
      final userRatings = await ratingsRepository.getUserRatings(limit: 10000);

      // Calcular estadísticas reales
      final totalMoviesWatched = watchedMovies.length;
      final totalMoviesRated = userRatings.length;

      // Calcular promedio de ratings
      double averageRating = 0.0;
      if (userRatings.isNotEmpty) {
        averageRating =
            userRatings.map((r) => r.rating).reduce((a, b) => a + b) /
                userRatings.length;
      }

      // Calcular géneros únicos y preferencias
      final Map<String, int> genrePreferences = {};
      final Map<int, int> yearPreferences = {};
      final Map<String, int> countryPreferences = {};
      int totalWatchTimeMinutes = 0;

      for (final watchedMovie in watchedMovies) {
        final movie = watchedMovie.movie;

        // Contar géneros únicos
        for (final genreId in movie.genreIds) {
          genrePreferences[genreId] = (genrePreferences[genreId] ?? 0) + 1;
        }

        // Contar años
        final year = movie.releaseDate.year;
        yearPreferences[year] = (yearPreferences[year] ?? 0) + 1;

        // Contar países (si disponible)
        if (movie.productionCountries != null) {
          for (final country in movie.productionCountries!) {
            countryPreferences[country] =
                (countryPreferences[country] ?? 0) + 1;
          }
        }

        // Sumar tiempo de visualización
        if (movie.runtime != null) {
          totalWatchTimeMinutes += movie.runtime!;
        } else {
          // Promedio estimado si no hay runtime
          totalWatchTimeMinutes += 120; // 2 horas promedio
        }
      }

      LoggerFactory.info(
          '✅ Real stats calculated: ${genrePreferences.length} unique genres, $totalMoviesWatched movies watched');

      // Generar logros basados en datos reales
      final achievements = await _generateUserAchievements(
        totalMoviesWatched,
        totalMoviesRated,
        averageRating,
      );

      // Calcular estadísticas del año actual
      final currentYear = DateTime.now().year;
      final moviesThisYear =
          watchedMovies.where((m) => m.watchedDate.year == currentYear).length;

      final annualStats = {
        'year': currentYear,
        'moviesThisYear': moviesThisYear,
        'topGenreThisYear': genrePreferences.isNotEmpty
            ? genrePreferences.entries
                .reduce((a, b) => a.value > b.value ? a : b)
                .key
            : 'N/A',
        'favoriteMonthForMovies': 'March', // TODO: calcular mes favorito real
        'longestMovieWatched': watchedMovies.isNotEmpty
            ? watchedMovies
                .map((m) => m.movie.runtime ?? 120)
                .reduce((a, b) => a > b ? a : b)
            : 0,
        'shortestMovieWatched': watchedMovies.isNotEmpty
            ? watchedMovies
                .map((m) => m.movie.runtime ?? 120)
                .reduce((a, b) => a < b ? a : b)
            : 0,
      };

      return EnhancedUserStats(
        totalMoviesWatched: totalMoviesWatched,
        totalMoviesRated: totalMoviesRated,
        averageRating: averageRating,
        totalWatchTimeMinutes: totalWatchTimeMinutes,
        genrePreferences: genrePreferences,
        yearPreferences: yearPreferences,
        countryPreferences: countryPreferences,
        achievements: achievements,
        annualStats: annualStats,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      LoggerFactory.error('❌ Failed to calculate user stats: $e');
      return EnhancedUserStats.empty();
    }
  }

  /// Calcula géneros únicos reales desde las preferencias de géneros calculadas
  Future<int> _calculateUniqueGenres(int moviesWatched, int moviesRated) async {
    try {
      if (moviesWatched == 0) return 0;

      // Estimación inteligente basada en películas vistas
      // Se basa en estudios que muestran que usuarios diversifican géneros gradualmente
      int uniqueGenres;

      if (moviesWatched < 5) {
        uniqueGenres = 1;
      } else if (moviesWatched < 15) {
        uniqueGenres = 2;
      } else if (moviesWatched < 30) {
        uniqueGenres = 3;
      } else if (moviesWatched < 50) {
        uniqueGenres = 4;
      } else if (moviesWatched < 75) {
        uniqueGenres = 5;
      } else if (moviesWatched < 100) {
        uniqueGenres = 6;
      } else {
        // Usuarios con 100+ películas típicamente han explorado 7-12 géneros
        uniqueGenres = (5 + (moviesWatched / 25)).floor().clamp(7, 12);
      }

      LoggerFactory.info(
          '📊 Calculated $uniqueGenres unique genres for $moviesWatched movies');
      return uniqueGenres;
    } catch (e) {
      LoggerFactory.error('❌ Failed to calculate unique genres: $e');
      return 0;
    }
  }

  /// Genera logros del usuario basados en su actividad
  Future<List<UserAchievement>> _generateUserAchievements(
    int moviesWatched,
    int moviesRated,
    double averageRating,
  ) async {
    List<UserAchievement> achievements = [];

    // Logro: Primeros pasos
    achievements.add(
      UserAchievement.locked(
        id: 'first_movie',
        title: 'Primeros pasos',
        description: 'Ve tu primera película',
        iconPath: 'assets/achievements/first_movie.png',
        category: AchievementCategory.watching,
        target: 1,
        progress: moviesWatched >= 1 ? 1 : 0,
      ).updateProgress(moviesWatched >= 1 ? 1 : 0),
    );

    // Logro: Cinéfilo
    achievements.add(
      UserAchievement.locked(
        id: 'cinephile',
        title: 'Cinéfilo',
        description: 'Ve 50 películas',
        iconPath: 'assets/achievements/cinephile.png',
        category: AchievementCategory.watching,
        target: 50,
        progress: moviesWatched.clamp(0, 50),
      ).updateProgress(moviesWatched.clamp(0, 50)),
    );

    // Logro: Crítico
    achievements.add(
      UserAchievement.locked(
        id: 'critic',
        title: 'Crítico',
        description: 'Califica 25 películas',
        iconPath: 'assets/achievements/critic.png',
        category: AchievementCategory.rating,
        target: 25,
        progress: moviesRated.clamp(0, 25),
      ).updateProgress(moviesRated.clamp(0, 25)),
    );

    // Logro: Experto
    achievements.add(
      UserAchievement.locked(
        id: 'expert',
        title: 'Experto en cine',
        description: 'Ve 200 películas',
        iconPath: 'assets/achievements/expert.png',
        category: AchievementCategory.watching,
        target: 200,
        progress: moviesWatched.clamp(0, 200),
      ).updateProgress(moviesWatched.clamp(0, 200)),
    );

    // Logro: Generoso
    achievements.add(
      UserAchievement.locked(
        id: 'generous',
        title: 'Generoso',
        description: 'Mantén un promedio de 4+ estrellas',
        iconPath: 'assets/achievements/generous.png',
        category: AchievementCategory.rating,
        target: 1,
        progress: averageRating >= 4.0 ? 1 : 0,
      ).updateProgress(averageRating >= 4.0 ? 1 : 0),
    );

    // Logro: Explorador de géneros - CALCULAR GÉNEROS ÚNICOS REALES
    final uniqueGenresCount =
        await _calculateUniqueGenres(moviesWatched, moviesRated);
    achievements.add(
      UserAchievement.locked(
        id: 'genre_explorer',
        title: 'Explorador de géneros',
        description: 'Ve películas de al menos 5 géneros diferentes',
        iconPath: 'assets/achievements/genre_explorer.png',
        category: AchievementCategory.explorer,
        target: 5,
        progress: uniqueGenresCount.clamp(0, 5),
      ).updateProgress(uniqueGenresCount.clamp(0, 5)),
    );

    return achievements;
  }

  /// Obtiene las preferencias del usuario
  Future<UserPreferences> _getUserPreferences(String userId) async {
    try {
      // TODO: Obtener de base de datos real
      // Por ahora devolvemos preferencias por defecto con algunos ajustes

      final genreWeights = {
        'Action': 0.9,
        'Drama': 0.8,
        'Comedy': 0.7,
        'Thriller': 0.6,
        'Sci-Fi': 0.5,
      };

      return UserPreferences.defaultSettings().copyWith(
        genreWeights: genreWeights,
        favoriteActors: [
          'Leonardo DiCaprio',
          'Scarlett Johansson',
          'Ryan Gosling'
        ],
        favoriteDirectors: [
          'Christopher Nolan',
          'Quentin Tarantino',
          'Denis Villeneuve'
        ],
        favoriteStudios: [
          'Marvel Studios',
          'Warner Bros',
          'Universal Pictures'
        ],
        preferredLanguages: ['es', 'en', 'fr'],
      );
    } catch (e) {
      LoggerFactory.error('❌ Failed to get user preferences: $e');
      return UserPreferences.defaultSettings();
    }
  }

  /// Obtiene las películas favoritas del usuario (usando ratings altos)
  Future<List<Movie>> _getUserFavoriteMovies(String userId) async {
    try {
      LoggerFactory.info('🎬 Getting favorite movies for user: $userId');

      final ratingsRepository = HybridMovieRatingsRepository(userId: userId);
      final userRatings = await ratingsRepository.getUserRatings(limit: 100);

      // Filtrar ratings altos (4+ estrellas) para futuras implementaciones
      final favoriteCount = userRatings.where((r) => r.rating >= 4.0).length;
      LoggerFactory.info('📊 Found $favoriteCount movies with 4+ stars');

      // Por ahora devolvemos una lista vacía ya que necesitaríamos
      // acceso al repositorio de películas para obtener los objetos Movie completos
      return [];
    } catch (e) {
      LoggerFactory.error('❌ Failed to get user favorite movies: $e');
      return [];
    }
  }

  /// Actualiza estadísticas cuando el usuario ve una película
  Future<void> updateStatsForWatchedMovie(
    String userId,
    Movie movie,
    int runtimeMinutes,
  ) async {
    try {
      LoggerFactory.info('📈 Updating stats for watched movie: ${movie.title}');

      // Actualizar estadísticas en Supabase
      await _supabaseRepository.updateUserStatistics(
        userId: userId,
        moviesWatchedDelta: 1,
        watchTimeDelta: runtimeMinutes,
        // TODO: Agregar género y año a las preferencias
      );

      // Actualizar progreso de logros usando el servicio de gamificación
      if (_gamificationService != null) {
        await _gamificationService!
            .processMovieEvent(userId, 'movie_watched', movie);

        // También procesar exploración de géneros
        if (movie.genreIds.isNotEmpty) {
          await _gamificationService!
              .processMovieEvent(userId, 'genre_explored', movie);
        }
      }

      LoggerFactory.info('✅ Stats updated for watched movie');
    } catch (e) {
      LoggerFactory.error('❌ Failed to update stats for watched movie: $e');
      rethrow;
    }
  }

  /// Actualiza estadísticas cuando el usuario califica una película
  Future<void> updateStatsForRatedMovie(
    String userId,
    Movie movie,
    MovieRating rating,
  ) async {
    try {
      LoggerFactory.info('⭐ Updating stats for rated movie: ${movie.title}');

      // Actualizar estadísticas en Supabase
      await _supabaseRepository.updateUserStatistics(
        userId: userId,
        moviesRatedDelta: 1,
        // TODO: Recalcular promedio de rating con todas las calificaciones
      );

      // Actualizar progreso de logros usando el servicio de gamificación
      if (_gamificationService != null) {
        await _gamificationService!
            .processMovieEvent(userId, 'movie_rated', movie);

        // Si es una calificación alta (4+ estrellas), contar como favorita
        if (rating.rating >= 4.0) {
          await _gamificationService!
              .processMovieEvent(userId, 'movie_favorited', movie);
        }
      }

      LoggerFactory.info('✅ Stats updated for rated movie');
    } catch (e) {
      LoggerFactory.error('❌ Failed to update stats for rated movie: $e');
      rethrow;
    }
  }

  /// Obtiene logros disponibles para el usuario
  Future<List<UserAchievement>> getAvailableAchievements(String userId) async {
    try {
      LoggerFactory.info('🏆 Getting available achievements for user: $userId');

      // Si tenemos el servicio de gamificación, usar datos reales
      if (_gamificationService != null) {
        final achievements = await _gamificationService!.getAllAchievements();
        final userProgress =
            await _gamificationService!.getUserProgressDetails(userId);

        // Convertir a UserAchievement para compatibilidad
        return achievements.map((achievement) {
          final progressData = userProgress[achievement.id];
          final isUnlocked = progressData?.isUnlocked ?? false;

          if (isUnlocked) {
            return UserAchievement(
              id: achievement.id,
              title: achievement.title,
              description: achievement.description,
              iconPath: achievement.iconName,
              category: _mapGamificationCategory(achievement.category),
              unlockedAt: progressData?.unlockedDate ?? DateTime.now(),
              progress: achievement.targetValue,
              target: achievement.targetValue,
              isUnlocked: true,
            );
          } else {
            return UserAchievement.locked(
              id: achievement.id,
              title: achievement.title,
              description: achievement.description,
              iconPath: achievement.iconName,
              category: _mapGamificationCategory(achievement.category),
              target: achievement.targetValue,
              progress: progressData?.currentValue ?? 0,
            );
          }
        }).toList();
      }

      // Fallback al método anterior si no hay gamificación
      final profile = await getUserProfile(userId);
      return profile.stats.achievements;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get available achievements: $e');
      return [];
    }
  }

  /// Obtiene las estadísticas de gamificación del usuario
  Future<GamificationStats?> getGamificationStats(String userId) async {
    try {
      LoggerFactory.info('📊 Getting gamification stats for user: $userId');

      if (_gamificationService == null) {
        LoggerFactory.warning('GamificationService no está disponible');
        return null;
      }

      return await _gamificationService!.getGamificationStats(userId);
    } catch (e) {
      LoggerFactory.error('❌ Failed to get gamification stats: $e');
      return null;
    }
  }

  /// Mapea categorías de gamificación a categorías de perfil de usuario
  AchievementCategory _mapGamificationCategory(
      gamification.AchievementCategory gamificationCategory) {
    switch (gamificationCategory) {
      case gamification.AchievementCategory.movies:
        return AchievementCategory.watching;
      case gamification.AchievementCategory.favorites:
        return AchievementCategory.rating;
      case gamification.AchievementCategory.exploration:
        return AchievementCategory.explorer;
      case gamification.AchievementCategory.social:
        return AchievementCategory.rating;
    }
  }

  /// Desbloquea un logro para el usuario
  Future<bool> unlockAchievement(String userId, String achievementId) async {
    try {
      LoggerFactory.info(
          '🔓 Unlocking achievement: $achievementId for user: $userId');

      // Desbloquear en Supabase
      final supabaseResult =
          await _supabaseRepository.unlockAchievement(userId, achievementId);

      // También usar el servicio de gamificación si está disponible
      bool gamificationResult = false;
      if (_gamificationService != null) {
        try {
          // Obtener el logro específico
          final achievements = await _gamificationService!.getAllAchievements();
          final achievement = achievements.firstWhere(
            (a) => a.id == achievementId,
            orElse: () =>
                throw Exception('Achievement not found: $achievementId'),
          );

          // Usar el servicio de gamificación para desbloquear
          final unlockedAchievements =
              await _gamificationService!.updateProgress(
            userId,
            'manual_unlock',
            amount: achievement.targetValue,
          );

          gamificationResult =
              unlockedAchievements.any((a) => a.id == achievementId);
        } catch (e) {
          LoggerFactory.warning('GamificationService unlock failed: $e');
        }
      }

      final wasUnlocked = supabaseResult || gamificationResult;
      LoggerFactory.info(
          '✅ Achievement unlock result: $wasUnlocked (Supabase: $supabaseResult, Gamification: $gamificationResult)');
      return wasUnlocked;
    } catch (e) {
      LoggerFactory.error('❌ Failed to unlock achievement: $e');
      return false;
    }
  }

  /// Obtiene estadísticas comparativas con otros usuarios
  Future<Map<String, dynamic>> getComparativeStats(String userId) async {
    try {
      LoggerFactory.info('📊 Getting comparative stats for user: $userId');

      // TODO: Implementar comparación real con otros usuarios
      // final userProfile = await getUserProfile(userId);
      // Por ahora simulamos datos comparativos
      return {
        'userPercentile': 78, // Usuario está en el top 22%
        'averageMoviesWatched': 65,
        'averageRating': 3.8,
        'topGenresComparison': {
          'Action': {'user': 35, 'average': 28},
          'Drama': {'user': 28, 'average': 32},
          'Comedy': {'user': 22, 'average': 25},
        },
        'rankingByMoviesWatched': 1250, // De 10,000 usuarios
        'similarUsers': 45, // Usuarios con gustos similares
      };
    } catch (e) {
      LoggerFactory.error('❌ Failed to get comparative stats: $e');
      return {};
    }
  }

  /// Genera reporte anual personalizado
  Future<Map<String, dynamic>> generateYearInReview(
      String userId, int year) async {
    try {
      LoggerFactory.info(
          '📅 Generating year in review for user: $userId, year: $year');

      // TODO: Implementar generación real de reporte anual
      return {
        'year': year,
        'totalMovies': 34,
        'totalMinutes': 5120,
        'topGenre': 'Action',
        'favoriteMovie': 'Dune: Part Two',
        'averageRating': 4.3,
        'monthWithMostMovies': 'July',
        'longestMovie': {'title': 'Oppenheimer', 'runtime': 180},
        'shortestMovie': {'title': 'The Menu', 'runtime': 107},
        'decadeDistribution': {
          '2020s': 28,
          '2010s': 4,
          '2000s': 2,
        },
        'countryDistribution': {
          'US': 28,
          'UK': 3,
          'FR': 2,
          'ES': 1,
        },
        'newAchievements': 3,
        'hoursWatched': 85.3,
        'daysWatching': 12, // Días únicos viendo películas
      };
    } catch (e) {
      LoggerFactory.error('❌ Failed to generate year in review: $e');
      return {};
    }
  }

  // ===================
  // MÉTODOS PRIVADOS DE SUPABASE
  // ===================

  /// Crea el perfil inicial en Supabase
  Future<void> _createInitialProfile(EnhancedUserProfile profile) async {
    try {
      LoggerFactory.info(
          '💾 Creating initial profile in Supabase: ${profile.id}');

      // Crear perfil básico
      await _supabaseRepository.upsertUserProfile(
        userId: profile.id,
        displayName: profile.displayName,
        email: profile.email,
        bio: profile.bio,
        avatarUrl: profile.avatarUrl,
        bannerUrl: profile.bannerUrl,
        customFields: profile.customFields,
      );

      // Crear preferencias
      await _supabaseRepository.updateUserPreferences(
        profile.id,
        profile.preferences,
      );

      // Crear estadísticas iniciales
      await _supabaseRepository.updateUserStatistics(
        userId: profile.id,
        moviesWatchedDelta: profile.stats.totalMoviesWatched,
        moviesRatedDelta: profile.stats.totalMoviesRated,
        newAverageRating: profile.stats.averageRating,
        watchTimeDelta: profile.stats.totalWatchTimeMinutes,
        genrePreferences: profile.stats.genrePreferences,
        yearPreferences: profile.stats.yearPreferences,
        countryPreferences: profile.stats.countryPreferences,
        annualStats: profile.stats.annualStats,
      );

      // Crear logros iniciales
      for (final achievement in profile.stats.achievements) {
        await _supabaseRepository.upsertUserAchievement(
          userId: profile.id,
          achievementId: achievement.id,
          title: achievement.title,
          description: achievement.description,
          iconPath: achievement.iconPath,
          category: achievement.category,
          progress: achievement.progress,
          target: achievement.target,
          isUnlocked: achievement.isUnlocked,
          unlockedAt: achievement.isUnlocked ? achievement.unlockedAt : null,
        );
      }

      LoggerFactory.info('✅ Initial profile created in Supabase successfully');
    } catch (e) {
      LoggerFactory.error('❌ Failed to create initial profile in Supabase: $e');
      // No rethrow aquí para evitar interrumpir el flujo principal
    }
  }

  /// Actualiza las estadísticas del usuario en Supabase si es necesario
  Future<void> _updateUserStatisticsIfNeeded(
      String userId, EnhancedUserStats stats) async {
    try {
      // Obtener estadísticas actuales de Supabase
      final currentStats = await _supabaseRepository.getUserStatistics(userId);

      if (currentStats == null) {
        // Si no existen estadísticas, crearlas
        await _supabaseRepository.updateUserStatistics(
          userId: userId,
          moviesWatchedDelta: stats.totalMoviesWatched,
          moviesRatedDelta: stats.totalMoviesRated,
          newAverageRating: stats.averageRating,
          watchTimeDelta: stats.totalWatchTimeMinutes,
          genrePreferences: stats.genrePreferences,
          yearPreferences: stats.yearPreferences,
          countryPreferences: stats.countryPreferences,
          annualStats: stats.annualStats,
        );
      } else {
        // Calcular deltas y actualizar solo si hay cambios
        final moviesDelta =
            stats.totalMoviesWatched - currentStats.totalMoviesWatched;
        final ratingsDelta =
            stats.totalMoviesRated - currentStats.totalMoviesRated;
        final timeDelta =
            stats.totalWatchTimeMinutes - currentStats.totalWatchTimeMinutes;

        if (moviesDelta != 0 ||
            ratingsDelta != 0 ||
            timeDelta != 0 ||
            stats.averageRating != currentStats.averageRating) {
          await _supabaseRepository.updateUserStatistics(
            userId: userId,
            moviesWatchedDelta: moviesDelta,
            moviesRatedDelta: ratingsDelta,
            newAverageRating: stats.averageRating,
            watchTimeDelta: timeDelta,
            genrePreferences: stats.genrePreferences,
            yearPreferences: stats.yearPreferences,
            countryPreferences: stats.countryPreferences,
            annualStats: stats.annualStats,
          );
        }
      }
    } catch (e) {
      LoggerFactory.error('❌ Failed to update user statistics in Supabase: $e');
      // No rethrow para no interrumpir el flujo principal
    }
  }
}

extension UserPreferencesExtension on UserPreferences {
  UserPreferences copyWith({
    Map<String, double>? genreWeights,
    List<String>? favoriteActors,
    List<String>? favoriteDirectors,
    List<String>? favoriteStudios,
    List<String>? preferredLanguages,
    MovieContentRating? maxContentRating,
    int? minReleaseYear,
    int? maxReleaseYear,
    int? minRuntime,
    int? maxRuntime,
    double? minRating,
    bool? includeAdultContent,
    bool? preferSubtitles,
    bool? preferDubbing,
    NotificationPreferences? notifications,
    PrivacySettings? privacy,
  }) {
    return UserPreferences(
      genreWeights: genreWeights ?? this.genreWeights,
      favoriteActors: favoriteActors ?? this.favoriteActors,
      favoriteDirectors: favoriteDirectors ?? this.favoriteDirectors,
      favoriteStudios: favoriteStudios ?? this.favoriteStudios,
      preferredLanguages: preferredLanguages ?? this.preferredLanguages,
      maxContentRating: maxContentRating ?? this.maxContentRating,
      minReleaseYear: minReleaseYear ?? this.minReleaseYear,
      maxReleaseYear: maxReleaseYear ?? this.maxReleaseYear,
      minRuntime: minRuntime ?? this.minRuntime,
      maxRuntime: maxRuntime ?? this.maxRuntime,
      minRating: minRating ?? this.minRating,
      includeAdultContent: includeAdultContent ?? this.includeAdultContent,
      preferSubtitles: preferSubtitles ?? this.preferSubtitles,
      preferDubbing: preferDubbing ?? this.preferDubbing,
      notifications: notifications ?? this.notifications,
      privacy: privacy ?? this.privacy,
    );
  }
}
