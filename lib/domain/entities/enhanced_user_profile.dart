import 'movie.dart';

/// Estadísticas avanzadas del perfil de usuario
class EnhancedUserStats {
  const EnhancedUserStats({
    required this.totalMoviesWatched,
    required this.totalMoviesRated,
    required this.averageRating,
    required this.totalWatchTimeMinutes,
    required this.genrePreferences,
    required this.yearPreferences,
    required this.countryPreferences,
    required this.achievements,
    required this.annualStats,
    required this.lastUpdated,
  });

  factory EnhancedUserStats.empty() {
    return EnhancedUserStats(
      totalMoviesWatched: 0,
      totalMoviesRated: 0,
      averageRating: 0.0,
      totalWatchTimeMinutes: 0,
      genrePreferences: {},
      yearPreferences: {},
      countryPreferences: {},
      achievements: [],
      annualStats: {},
      lastUpdated: DateTime.now(),
    );
  }
  final int totalMoviesWatched;
  final int totalMoviesRated;
  final double averageRating;
  final int totalWatchTimeMinutes;
  final Map<String, int> genrePreferences;
  final Map<int, int> yearPreferences; // año -> count
  final Map<String, int> countryPreferences;
  final List<UserAchievement> achievements;
  final Map<String, dynamic> annualStats; // estadísticas del año actual
  final DateTime lastUpdated;

  /// Géneros favoritos ordenados por preferencia
  List<String> get topGenres {
    var sortedGenres = genrePreferences.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedGenres.take(5).map((e) => e.key).toList();
  }

  /// Décadas favoritas
  List<String> get favoriteDecades {
    Map<String, int> decades = {};
    for (var entry in yearPreferences.entries) {
      String decade = '${(entry.key ~/ 10) * 10}s';
      decades[decade] = (decades[decade] ?? 0) + entry.value;
    }
    var sortedDecades = decades.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedDecades.take(3).map((e) => e.key).toList();
  }

  /// Tiempo total de visualización en horas
  double get totalWatchTimeHours => totalWatchTimeMinutes / 60.0;

  /// Promedio de películas por mes
  double get averageMoviesPerMonth {
    if (totalMoviesWatched == 0) return 0;
    final now = DateTime.now();
    final monthsActive =
        now.difference(lastUpdated.subtract(const Duration(days: 365))).inDays /
            30;
    return totalMoviesWatched / monthsActive.clamp(1, double.infinity);
  }

  EnhancedUserStats copyWith({
    int? totalMoviesWatched,
    int? totalMoviesRated,
    double? averageRating,
    int? totalWatchTimeMinutes,
    Map<String, int>? genrePreferences,
    Map<int, int>? yearPreferences,
    Map<String, int>? countryPreferences,
    List<UserAchievement>? achievements,
    Map<String, dynamic>? annualStats,
    DateTime? lastUpdated,
  }) {
    return EnhancedUserStats(
      totalMoviesWatched: totalMoviesWatched ?? this.totalMoviesWatched,
      totalMoviesRated: totalMoviesRated ?? this.totalMoviesRated,
      averageRating: averageRating ?? this.averageRating,
      totalWatchTimeMinutes:
          totalWatchTimeMinutes ?? this.totalWatchTimeMinutes,
      genrePreferences: genrePreferences ?? this.genrePreferences,
      yearPreferences: yearPreferences ?? this.yearPreferences,
      countryPreferences: countryPreferences ?? this.countryPreferences,
      achievements: achievements ?? this.achievements,
      annualStats: annualStats ?? this.annualStats,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Logros del usuario
class UserAchievement {
  const UserAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconPath,
    required this.category,
    required this.unlockedAt,
    required this.progress,
    required this.target,
    required this.isUnlocked,
  });

  factory UserAchievement.locked({
    required String id,
    required String title,
    required String description,
    required String iconPath,
    required AchievementCategory category,
    required int target,
    int progress = 0,
  }) {
    return UserAchievement(
      id: id,
      title: title,
      description: description,
      iconPath: iconPath,
      category: category,
      unlockedAt: DateTime(1970), // Fecha placeholder
      progress: progress,
      target: target,
      isUnlocked: false,
    );
  }
  final String id;
  final String title;
  final String description;
  final String iconPath;
  final AchievementCategory category;
  final DateTime unlockedAt;
  final int progress; // 0-100
  final int target;
  final bool isUnlocked;

  /// Porcentaje de progreso
  double get progressPercentage => (progress / target * 100).clamp(0, 100);

  UserAchievement unlock() {
    return UserAchievement(
      id: id,
      title: title,
      description: description,
      iconPath: iconPath,
      category: category,
      unlockedAt: DateTime.now(),
      progress: target,
      target: target,
      isUnlocked: true,
    );
  }

  UserAchievement updateProgress(int newProgress) {
    final updatedProgress = newProgress.clamp(0, target);
    return UserAchievement(
      id: id,
      title: title,
      description: description,
      iconPath: iconPath,
      category: category,
      unlockedAt: updatedProgress >= target ? DateTime.now() : unlockedAt,
      progress: updatedProgress,
      target: target,
      isUnlocked: updatedProgress >= target,
    );
  }
}

/// Categorías de logros
enum AchievementCategory {
  watching, // Relacionados con ver películas
  rating, // Relacionados con calificar películas
  social, // Relacionados con actividad social
  discovery, // Relacionados con descubrir nuevas películas
  collector, // Relacionados con coleccionar (favoritos, listas)
  critic, // Relacionados con escribir reseñas
  explorer, // Relacionados con explorar géneros/países
}

/// Preferencias detalladas del usuario
class UserPreferences {
  const UserPreferences({
    required this.genreWeights,
    required this.favoriteActors,
    required this.favoriteDirectors,
    required this.favoriteStudios,
    required this.preferredLanguages,
    required this.maxContentRating,
    required this.minReleaseYear,
    required this.maxReleaseYear,
    required this.minRuntime,
    required this.maxRuntime,
    required this.minRating,
    required this.includeAdultContent,
    required this.preferSubtitles,
    required this.preferDubbing,
    required this.notifications,
    required this.privacy,
  });

  factory UserPreferences.defaultSettings() {
    final currentYear = DateTime.now().year;
    return UserPreferences(
      genreWeights: {},
      favoriteActors: [],
      favoriteDirectors: [],
      favoriteStudios: [],
      preferredLanguages: ['es', 'en'],
      maxContentRating: MovieContentRating.r,
      minReleaseYear: 1970,
      maxReleaseYear: currentYear + 2,
      minRuntime: 60,
      maxRuntime: 300,
      minRating: 0.0,
      includeAdultContent: false,
      preferSubtitles: false,
      preferDubbing: true,
      notifications: NotificationPreferences.defaultSettings(),
      privacy: PrivacySettings.defaultSettings(),
    );
  }
  final Map<String, double> genreWeights; // género -> peso (0.0-1.0)
  final List<String> favoriteActors;
  final List<String> favoriteDirectors;
  final List<String> favoriteStudios;
  final List<String> preferredLanguages;
  final MovieContentRating maxContentRating;
  final int minReleaseYear;
  final int maxReleaseYear;
  final int minRuntime;
  final int maxRuntime;
  final double minRating;
  final bool includeAdultContent;
  final bool preferSubtitles;
  final bool preferDubbing;
  final NotificationPreferences notifications;
  final PrivacySettings privacy;
}

/// Configuración de contenido por edades
enum MovieContentRating {
  g, // General
  pg, // Parental Guidance
  pg13, // Parents Strongly Cautioned
  r, // Restricted
  nc17, // No Children Under 17
}

/// Preferencias de notificaciones
class NotificationPreferences {
  const NotificationPreferences({
    required this.enablePushNotifications,
    required this.notifyNewRecommendations,
    required this.notifyFriendsActivity,
    required this.notifyNewReleases,
    required this.notifyWatchlistUpdates,
    required this.notifyAchievements,
    required this.emailDigest,
    required this.digestFrequency,
  });

  factory NotificationPreferences.defaultSettings() {
    return const NotificationPreferences(
      enablePushNotifications: true,
      notifyNewRecommendations: true,
      notifyFriendsActivity: false,
      notifyNewReleases: true,
      notifyWatchlistUpdates: true,
      notifyAchievements: true,
      emailDigest: false,
      digestFrequency: DigestFrequency.weekly,
    );
  }
  final bool enablePushNotifications;
  final bool notifyNewRecommendations;
  final bool notifyFriendsActivity;
  final bool notifyNewReleases;
  final bool notifyWatchlistUpdates;
  final bool notifyAchievements;
  final bool emailDigest;
  final DigestFrequency digestFrequency;
}

enum DigestFrequency {
  daily,
  weekly,
  monthly,
  never,
}

/// Configuración de privacidad
class PrivacySettings {
  const PrivacySettings({
    required this.profileVisibility,
    required this.showRatingsPublic,
    required this.showWatchlistPublic,
    required this.showFavoritesPublic,
    required this.showStatsPublic,
    required this.allowFriendRequests,
    required this.shareActivityOnSocial,
    required this.analyticsOptOut,
  });

  factory PrivacySettings.defaultSettings() {
    return const PrivacySettings(
      profileVisibility: ProfileVisibility.public,
      showRatingsPublic: true,
      showWatchlistPublic: true,
      showFavoritesPublic: true,
      showStatsPublic: true,
      allowFriendRequests: true,
      shareActivityOnSocial: false,
      analyticsOptOut: false,
    );
  }
  final ProfileVisibility profileVisibility;
  final bool showRatingsPublic;
  final bool showWatchlistPublic;
  final bool showFavoritesPublic;
  final bool showStatsPublic;
  final bool allowFriendRequests;
  final bool shareActivityOnSocial;
  final bool analyticsOptOut;
}

enum ProfileVisibility {
  private, // Solo el usuario
  friends, // Solo amigos
  public, // Público
}

/// Perfil de usuario mejorado
class EnhancedUserProfile {
  const EnhancedUserProfile({
    required this.id,
    required this.displayName,
    this.email,
    this.bio,
    this.avatarUrl,
    this.bannerUrl,
    required this.joinedDate,
    required this.lastActiveDate,
    required this.preferences,
    required this.stats,
    required this.favoriteMovies,
    required this.customFields,
  });
  final String id;
  final String displayName;
  final String? email;
  final String? bio;
  final String? avatarUrl;
  final String? bannerUrl;
  final DateTime joinedDate;
  final DateTime lastActiveDate;
  final UserPreferences preferences;
  final EnhancedUserStats stats;
  final List<Movie> favoriteMovies;
  final Map<String, dynamic> customFields;

  /// Tiempo como miembro
  Duration get membershipDuration => DateTime.now().difference(joinedDate);

  /// Días desde la última actividad
  int get daysSinceLastActive =>
      DateTime.now().difference(lastActiveDate).inDays;

  /// Es usuario activo (activo en los últimos 7 días)
  bool get isActiveUser => daysSinceLastActive <= 7;

  /// Nivel del usuario basado en actividad
  UserLevel get userLevel {
    final moviesWatched = stats.totalMoviesWatched;
    final moviesRated = stats.totalMoviesRated;

    if (moviesWatched < 10 || moviesRated < 5) return UserLevel.newcomer;
    if (moviesWatched < 50 || moviesRated < 25) return UserLevel.movieFan;
    if (moviesWatched < 200 || moviesRated < 100) return UserLevel.cinephile;
    if (moviesWatched < 500 || moviesRated < 250) return UserLevel.movieExpert;
    return UserLevel.filmCritic;
  }

  EnhancedUserProfile copyWith({
    String? displayName,
    String? email,
    String? bio,
    String? avatarUrl,
    String? bannerUrl,
    DateTime? lastActiveDate,
    UserPreferences? preferences,
    EnhancedUserStats? stats,
    List<Movie>? favoriteMovies,
    Map<String, dynamic>? customFields,
  }) {
    return EnhancedUserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      joinedDate: joinedDate,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      preferences: preferences ?? this.preferences,
      stats: stats ?? this.stats,
      favoriteMovies: favoriteMovies ?? this.favoriteMovies,
      customFields: customFields ?? this.customFields,
    );
  }
}

/// Niveles de usuario
enum UserLevel {
  newcomer, // Nuevo (< 10 películas)
  movieFan, // Fan (10-49 películas)
  cinephile, // Cinéfilo (50-199 películas)
  movieExpert, // Experto (200-499 películas)
  filmCritic, // Crítico (500+ películas)
}

extension UserLevelExtension on UserLevel {
  String get displayName {
    switch (this) {
      case UserLevel.newcomer:
        return 'Recién llegado';
      case UserLevel.movieFan:
        return 'Fan del cine';
      case UserLevel.cinephile:
        return 'Cinéfilo';
      case UserLevel.movieExpert:
        return 'Experto en cine';
      case UserLevel.filmCritic:
        return 'Crítico de cine';
    }
  }

  String get description {
    switch (this) {
      case UserLevel.newcomer:
        return 'Está empezando su viaje cinematográfico';
      case UserLevel.movieFan:
        return 'Disfruta viendo y calificando películas';
      case UserLevel.cinephile:
        return 'Tiene un profundo amor por el cine';
      case UserLevel.movieExpert:
        return 'Conoce el cine como la palma de su mano';
      case UserLevel.filmCritic:
        return 'Un verdadero maestro del séptimo arte';
    }
  }

  String get iconPath {
    switch (this) {
      case UserLevel.newcomer:
        return 'assets/icons/level_newcomer.png';
      case UserLevel.movieFan:
        return 'assets/icons/level_fan.png';
      case UserLevel.cinephile:
        return 'assets/icons/level_cinephile.png';
      case UserLevel.movieExpert:
        return 'assets/icons/level_expert.png';
      case UserLevel.filmCritic:
        return 'assets/icons/level_critic.png';
    }
  }
}
