import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/logging/logger_factory.dart';
import '../../domain/entities/enhanced_user_profile.dart';
import '../../domain/entities/movie.dart';

/// Repository para gestionar perfiles de usuario en Supabase
class SupabaseUserProfileRepository {
  SupabaseUserProfileRepository._();

  static final SupabaseUserProfileRepository _instance =
      SupabaseUserProfileRepository._();
  static SupabaseUserProfileRepository get instance => _instance;

  SupabaseClient get _supabase => SupabaseConfig.client;

  /// Obtiene el perfil completo de un usuario desde Supabase
  Future<EnhancedUserProfile?> getUserProfile(String userId) async {
    try {
      LoggerFactory.info('🔄 Fetching user profile from Supabase: $userId');

      // Usar la función SQL personalizada para obtener todos los datos relacionados
      final response = await _supabase.rpc('get_enhanced_user_profile',
          params: {'profile_user_id': userId});

      if (response == null || response.isEmpty) {
        LoggerFactory.warning('📭 No profile found for user: $userId');
        return null;
      }

      final data = response.first;
      LoggerFactory.info('✅ Profile data retrieved successfully');

      return await _buildEnhancedUserProfile(data);
    } catch (e) {
      LoggerFactory.error('❌ Failed to fetch user profile: $e');
      rethrow;
    }
  }

  /// Crea o actualiza el perfil básico del usuario
  Future<void> upsertUserProfile({
    required String userId,
    required String displayName,
    String? email,
    String? bio,
    String? avatarUrl,
    String? bannerUrl,
    Map<String, dynamic>? customFields,
  }) async {
    try {
      LoggerFactory.info('💾 Upserting user profile: $userId');

      final profileData = {
        'user_id': userId,
        'display_name': displayName,
        'email': email,
        'bio': bio,
        'avatar_url': avatarUrl,
        'banner_url': bannerUrl,
        'last_active_date': DateTime.now().toIso8601String(),
        'custom_fields': customFields ?? {},
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('user_profiles').upsert(profileData);

      LoggerFactory.info('✅ User profile upserted successfully');
    } catch (e) {
      LoggerFactory.error('❌ Failed to upsert user profile: $e');

      // Si el error es porque la tabla no existe o tiene estructura incorrecta
      if (e.toString().contains('400') ||
          e.toString().contains('Bad Request') ||
          e.toString().contains('table') ||
          e.toString().contains('column')) {
        LoggerFactory.warning(
            '⚠️ user_profiles table issue detected. Please run migration script.');
        // No hacer rethrow para evitar romper la aplicación
        return;
      }

      rethrow;
    }
  }

  /// Actualiza las estadísticas del usuario
  Future<void> updateUserStatistics({
    required String userId,
    int moviesWatchedDelta = 0,
    int moviesRatedDelta = 0,
    double? newAverageRating,
    int watchTimeDelta = 0,
    Map<String, int>? genrePreferences,
    Map<int, int>? yearPreferences,
    Map<String, int>? countryPreferences,
    Map<String, dynamic>? annualStats,
  }) async {
    try {
      LoggerFactory.info(
          '📊 Updating user statistics: $userId (+$moviesWatchedDelta watched, +$moviesRatedDelta rated)');

      // Usar la función SQL para actualizar estadísticas de forma eficiente
      await _supabase.rpc('update_user_statistics', params: {
        'profile_user_id': userId,
        'movies_watched_delta': moviesWatchedDelta,
        'movies_rated_delta': moviesRatedDelta,
        'new_average_rating': newAverageRating,
        'watch_time_delta': watchTimeDelta,
        'genre_data': genrePreferences != null
            ? _convertMapToJsonb(genrePreferences)
            : null,
        'year_data': yearPreferences != null
            ? _convertMapToJsonb(
                yearPreferences.map((k, v) => MapEntry(k.toString(), v)))
            : null,
        'country_data': countryPreferences != null
            ? _convertMapToJsonb(countryPreferences)
            : null,
      });

      // Si tenemos annual_stats, actualizarlos por separado
      if (annualStats != null) {
        await _supabase.from('user_statistics').update({
          'annual_stats': annualStats,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('user_id', userId);
      }

      LoggerFactory.info('✅ User statistics updated successfully');
    } catch (e) {
      LoggerFactory.error('❌ Failed to update user statistics: $e');
      rethrow;
    }
  }

  /// Actualiza las preferencias del usuario
  Future<void> updateUserPreferences(
      String userId, UserPreferences preferences) async {
    try {
      LoggerFactory.info('⚙️ Updating user preferences: $userId');

      final preferencesData = {
        'user_id': userId,
        'genre_weights': preferences.genreWeights,
        'favorite_actors': preferences.favoriteActors,
        'favorite_directors': preferences.favoriteDirectors,
        'favorite_studios': preferences.favoriteStudios,
        'preferred_languages': preferences.preferredLanguages,
        'max_content_rating': preferences.maxContentRating.name,
        'min_release_year': preferences.minReleaseYear,
        'max_release_year': preferences.maxReleaseYear,
        'min_runtime': preferences.minRuntime,
        'max_runtime': preferences.maxRuntime,
        'min_rating': preferences.minRating,
        'include_adult_content': preferences.includeAdultContent,
        'prefer_subtitles': preferences.preferSubtitles,
        'prefer_dubbing': preferences.preferDubbing,
        'notifications':
            _notificationPreferencesToJson(preferences.notifications),
        'privacy': _privacySettingsToJson(preferences.privacy),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('user_preferences').upsert(preferencesData);

      LoggerFactory.info('✅ User preferences updated successfully');
    } catch (e) {
      LoggerFactory.error('❌ Failed to update user preferences: $e');
      rethrow;
    }
  }

  /// Guarda o actualiza un logro del usuario
  Future<void> upsertUserAchievement({
    required String userId,
    required String achievementId,
    required String title,
    required String description,
    required String iconPath,
    required AchievementCategory category,
    required int progress,
    required int target,
    bool isUnlocked = false,
    DateTime? unlockedAt,
  }) async {
    try {
      LoggerFactory.info(
          '🏆 Upserting user achievement: $userId - $achievementId');

      final achievementData = {
        'user_id': userId,
        'achievement_id': achievementId,
        'title': title,
        'description': description,
        'icon_path': iconPath,
        'category': category.name,
        'progress': progress,
        'target': target,
        'is_unlocked': isUnlocked,
        'unlocked_at': unlockedAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('user_achievements').upsert(achievementData);

      LoggerFactory.info('✅ User achievement upserted successfully');
    } catch (e) {
      LoggerFactory.error('❌ Failed to upsert user achievement: $e');
      rethrow;
    }
  }

  /// Obtiene todos los logros de un usuario
  Future<List<UserAchievement>> getUserAchievements(String userId) async {
    try {
      LoggerFactory.info('🏆 Fetching user achievements: $userId');

      final response = await _supabase
          .from('user_achievements')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final achievements = <UserAchievement>[];
      for (final data in response) {
        achievements.add(_buildUserAchievementFromData(data));
      }

      LoggerFactory.info('✅ Found ${achievements.length} achievements');
      return achievements;
    } catch (e) {
      LoggerFactory.error('❌ Failed to fetch user achievements: $e');
      rethrow;
    }
  }

  /// Desbloquea un logro específico
  Future<bool> unlockAchievement(String userId, String achievementId) async {
    try {
      LoggerFactory.info('🔓 Unlocking achievement: $userId - $achievementId');

      final response = await _supabase
          .from('user_achievements')
          .update({
            'is_unlocked': true,
            'unlocked_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('achievement_id', achievementId)
          .select();

      final success = response.isNotEmpty;
      LoggerFactory.info('✅ Achievement unlock result: $success');
      return success;
    } catch (e) {
      LoggerFactory.error('❌ Failed to unlock achievement: $e');
      return false;
    }
  }

  /// Obtiene estadísticas de un usuario específico
  Future<EnhancedUserStats?> getUserStatistics(String userId) async {
    try {
      LoggerFactory.info('📊 Fetching user statistics: $userId');

      final response = await _supabase
          .from('user_statistics')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        LoggerFactory.warning('📭 No statistics found for user: $userId');
        return null;
      }

      return _buildUserStatsFromData(response);
    } catch (e) {
      LoggerFactory.error('❌ Failed to fetch user statistics: $e');
      rethrow;
    }
  }

  /// Obtiene las preferencias de un usuario
  Future<UserPreferences?> getUserPreferences(String userId) async {
    try {
      LoggerFactory.info('⚙️ Fetching user preferences: $userId');

      final response = await _supabase
          .from('user_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        LoggerFactory.warning('📭 No preferences found for user: $userId');
        return null;
      }

      return _buildUserPreferencesFromData(response);
    } catch (e) {
      LoggerFactory.error('❌ Failed to fetch user preferences: $e');
      rethrow;
    }
  }

  /// Elimina el perfil completo de un usuario
  Future<void> deleteUserProfile(String userId) async {
    try {
      LoggerFactory.info('🗑️ Deleting user profile: $userId');

      // Las eliminaciones en cascada se encargarán de las tablas relacionadas
      await _supabase.from('user_profiles').delete().eq('user_id', userId);

      LoggerFactory.info('✅ User profile deleted successfully');
    } catch (e) {
      LoggerFactory.error('❌ Failed to delete user profile: $e');
      rethrow;
    }
  }

  // ===================
  // MÉTODOS PRIVADOS DE CONSTRUCCIÓN
  // ===================

  /// Obtiene las películas favoritas del usuario basadas en ratings altos (4+ estrellas)
  Future<List<Movie>> _getUserFavoriteMovies(String userId) async {
    try {
      LoggerFactory.info('🎬 Fetching favorite movies for user: $userId');

      // Consultar ratings altos del usuario desde Supabase
      final response = await _supabase
          .from('movie_ratings')
          .select('''
            movie_id,
            rating,
            movie_title,
            movie_poster_path,
            movie_overview,
            movie_release_date,
            movie_genre_ids,
            movie_vote_average,
            movie_vote_count,
            movie_popularity,
            movie_adult,
            movie_video,
            movie_original_language,
            movie_original_title,
            movie_backdrop_path
          ''')
          .eq('user_id', userId)
          .gte('rating', 4.0) // Solo películas con 4+ estrellas
          .order('rating', ascending: false)
          .order('created_at', ascending: false)
          .limit(20); // Máximo 20 películas favoritas

      final favoriteMovies = <Movie>[];
      for (final data in response) {
        try {
          // Construir objeto Movie desde los datos guardados
          final movie = Movie(
            id: data['movie_id'] as int,
            title: data['movie_title'] as String? ?? 'Título desconocido',
            overview: data['movie_overview'] as String? ?? '',
            posterPath: data['movie_poster_path'] as String? ?? '',
            backdropPath: data['movie_backdrop_path'] as String? ?? '',
            releaseDate: data['movie_release_date'] != null
                ? DateTime.parse(data['movie_release_date'] as String)
                : DateTime.now(),
            genreIds: _parseGenreIds(data['movie_genre_ids']),
            voteAverage:
                (data['movie_vote_average'] as num?)?.toDouble() ?? 0.0,
            voteCount: data['movie_vote_count'] as int? ?? 0,
            popularity: (data['movie_popularity'] as num?)?.toDouble() ?? 0.0,
            adult: data['movie_adult'] as bool? ?? false,
            video: data['movie_video'] as bool? ?? false,
            originalLanguage:
                data['movie_original_language'] as String? ?? 'en',
            originalTitle: data['movie_original_title'] as String? ?? '',
          );
          favoriteMovies.add(movie);
        } catch (movieError) {
          LoggerFactory.warning(
              '⚠️ Error parsing favorite movie ${data['movie_id']}: $movieError');
        }
      }

      LoggerFactory.info('✅ Found ${favoriteMovies.length} favorite movies');
      return favoriteMovies;
    } catch (e) {
      LoggerFactory.error('❌ Failed to fetch favorite movies: $e');
      return []; // Devolver lista vacía en caso de error
    }
  }

  /// Parsea lista de IDs de géneros desde diferentes formatos
  List<String> _parseGenreIds(dynamic genreData) {
    if (genreData == null) return [];

    if (genreData is String) {
      // Si es string, podría ser JSON array o lista separada por comas
      try {
        if (genreData.startsWith('[') && genreData.endsWith(']')) {
          // Formato JSON array
          final parsed = genreData
              .substring(1, genreData.length - 1)
              .split(',')
              .map((s) => s.trim().replaceAll('"', ''))
              .where((s) => s.isNotEmpty)
              .toList();
          return parsed;
        } else {
          // Lista separada por comas
          return genreData
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      } catch (e) {
        LoggerFactory.warning('⚠️ Error parsing genre string: $e');
        return [];
      }
    }

    if (genreData is List) {
      return genreData.map((e) => e.toString()).toList();
    }

    return [];
  }

  /// Construye EnhancedUserProfile desde datos de Supabase
  Future<EnhancedUserProfile> _buildEnhancedUserProfile(
      Map<String, dynamic> data) async {
    final profileData = data['profile_data'] as Map<String, dynamic>;
    final statsData = data['statistics_data'] as Map<String, dynamic>?;
    final preferencesData = data['preferences_data'] as Map<String, dynamic>?;
    final achievementsData = data['achievements_data'] as List<dynamic>?;

    // Construir estadísticas
    final stats = statsData != null
        ? _buildUserStatsFromData(statsData)
        : EnhancedUserStats.empty();

    // Construir preferencias
    final preferences = preferencesData != null
        ? _buildUserPreferencesFromData(preferencesData)
        : UserPreferences.defaultSettings();

    // Construir logros
    final achievements = <UserAchievement>[];
    if (achievementsData != null) {
      for (final achievementData in achievementsData) {
        achievements.add(_buildUserAchievementFromData(achievementData));
      }
    }

    // Actualizar estadísticas con logros
    final updatedStats = stats.copyWith(achievements: achievements);

    return EnhancedUserProfile(
      id: profileData['user_id'] as String,
      displayName: profileData['display_name'] as String? ?? 'Usuario Anónimo',
      email: profileData['email'] as String?,
      bio: profileData['bio'] as String?,
      avatarUrl: profileData['avatar_url'] as String?,
      bannerUrl: profileData['banner_url'] as String?,
      joinedDate: DateTime.parse(profileData['joined_date'] as String),
      lastActiveDate: profileData['last_active_date'] != null
          ? DateTime.parse(profileData['last_active_date'] as String)
          : DateTime.now(),
      preferences: preferences,
      stats: updatedStats,
      favoriteMovies:
          await _getUserFavoriteMovies(profileData['user_id'] as String),
      customFields:
          (profileData['custom_fields'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// Construye UserStats desde datos de Supabase
  EnhancedUserStats _buildUserStatsFromData(Map<String, dynamic> data) {
    return EnhancedUserStats(
      totalMoviesWatched: data['total_movies_watched'] as int? ?? 0,
      totalMoviesRated: data['total_movies_rated'] as int? ?? 0,
      averageRating: (data['average_rating'] as num?)?.toDouble() ?? 0.0,
      totalWatchTimeMinutes: data['total_watch_time_minutes'] as int? ?? 0,
      genrePreferences: _convertJsonbToMapStringInt(data['genre_preferences']),
      yearPreferences: _convertJsonbToMapIntInt(data['year_preferences']),
      countryPreferences:
          _convertJsonbToMapStringInt(data['country_preferences']),
      achievements: [], // Se llenarán desde la consulta principal
      annualStats: (data['annual_stats'] as Map<String, dynamic>?) ??
          <String, dynamic>{},
      lastUpdated: data['last_updated'] != null
          ? DateTime.parse(data['last_updated'] as String)
          : DateTime.now(),
    );
  }

  /// Construye UserPreferences desde datos de Supabase
  UserPreferences _buildUserPreferencesFromData(Map<String, dynamic> data) {
    return UserPreferences(
      genreWeights: _convertJsonbToMapStringDouble(data['genre_weights']),
      favoriteActors: _convertToStringList(data['favorite_actors']),
      favoriteDirectors: _convertToStringList(data['favorite_directors']),
      favoriteStudios: _convertToStringList(data['favorite_studios']),
      preferredLanguages: _convertToStringList(data['preferred_languages']),
      maxContentRating: _parseContentRating(data['max_content_rating']),
      minReleaseYear: data['min_release_year'] as int? ?? 1970,
      maxReleaseYear:
          data['max_release_year'] as int? ?? DateTime.now().year + 2,
      minRuntime: data['min_runtime'] as int? ?? 60,
      maxRuntime: data['max_runtime'] as int? ?? 300,
      minRating: (data['min_rating'] as num?)?.toDouble() ?? 0.0,
      includeAdultContent: data['include_adult_content'] as bool? ?? false,
      preferSubtitles: data['prefer_subtitles'] as bool? ?? false,
      preferDubbing: data['prefer_dubbing'] as bool? ?? true,
      notifications: _parseNotificationPreferences(data['notifications']),
      privacy: _parsePrivacySettings(data['privacy']),
    );
  }

  /// Construye UserAchievement desde datos de Supabase
  UserAchievement _buildUserAchievementFromData(Map<String, dynamic> data) {
    final isUnlocked = data['is_unlocked'] as bool? ?? false;
    final unlockedAt = data['unlocked_at'] != null
        ? DateTime.parse(data['unlocked_at'] as String)
        : DateTime(1970);

    return UserAchievement(
      id: data['achievement_id'] as String,
      title: data['title'] as String,
      description: data['description'] as String? ?? '',
      iconPath: data['icon_path'] as String? ?? '',
      category: _parseAchievementCategory(data['category']),
      unlockedAt: unlockedAt,
      progress: data['progress'] as int? ?? 0,
      target: data['target'] as int? ?? 1,
      isUnlocked: isUnlocked,
    );
  }

  // ===================
  // MÉTODOS DE CONVERSIÓN
  // ===================

  Map<String, int> _convertJsonbToMapStringInt(dynamic jsonData) {
    if (jsonData == null) return {};
    if (jsonData is Map) {
      return Map<String, int>.from(
          jsonData.map((k, v) => MapEntry(k.toString(), v as int? ?? 0)));
    }
    return {};
  }

  Map<int, int> _convertJsonbToMapIntInt(dynamic jsonData) {
    if (jsonData == null) return {};
    if (jsonData is Map) {
      return Map<int, int>.from(jsonData.map(
          (k, v) => MapEntry(int.tryParse(k.toString()) ?? 0, v as int? ?? 0)));
    }
    return {};
  }

  Map<String, double> _convertJsonbToMapStringDouble(dynamic jsonData) {
    if (jsonData == null) return {};
    if (jsonData is Map) {
      return Map<String, double>.from(jsonData.map(
          (k, v) => MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0.0)));
    }
    return {};
  }

  List<String> _convertToStringList(dynamic listData) {
    if (listData == null) return [];
    if (listData is List) {
      return listData.map((e) => e.toString()).toList();
    }
    return [];
  }

  Map<String, dynamic> _convertMapToJsonb(Map<String, dynamic> map) {
    return Map<String, dynamic>.from(map);
  }

  MovieContentRating _parseContentRating(dynamic rating) {
    if (rating == null) return MovieContentRating.r;
    switch (rating.toString().toLowerCase()) {
      case 'g':
        return MovieContentRating.g;
      case 'pg':
        return MovieContentRating.pg;
      case 'pg13':
        return MovieContentRating.pg13;
      case 'r':
        return MovieContentRating.r;
      case 'nc17':
        return MovieContentRating.nc17;
      default:
        return MovieContentRating.r;
    }
  }

  AchievementCategory _parseAchievementCategory(dynamic category) {
    if (category == null) return AchievementCategory.watching;
    switch (category.toString().toLowerCase()) {
      case 'watching':
        return AchievementCategory.watching;
      case 'rating':
        return AchievementCategory.rating;
      case 'social':
        return AchievementCategory.social;
      case 'discovery':
        return AchievementCategory.discovery;
      case 'collector':
        return AchievementCategory.collector;
      case 'critic':
        return AchievementCategory.critic;
      case 'explorer':
        return AchievementCategory.explorer;
      default:
        return AchievementCategory.watching;
    }
  }

  NotificationPreferences _parseNotificationPreferences(dynamic data) {
    if (data == null) return NotificationPreferences.defaultSettings();
    if (data is! Map) return NotificationPreferences.defaultSettings();

    final map = Map<String, dynamic>.from(data);
    return NotificationPreferences(
      enablePushNotifications: map['enablePushNotifications'] as bool? ?? true,
      notifyNewRecommendations:
          map['notifyNewRecommendations'] as bool? ?? true,
      notifyFriendsActivity: map['notifyFriendsActivity'] as bool? ?? false,
      notifyNewReleases: map['notifyNewReleases'] as bool? ?? true,
      notifyWatchlistUpdates: map['notifyWatchlistUpdates'] as bool? ?? true,
      notifyAchievements: map['notifyAchievements'] as bool? ?? true,
      emailDigest: map['emailDigest'] as bool? ?? false,
      digestFrequency: _parseDigestFrequency(map['digestFrequency']),
    );
  }

  PrivacySettings _parsePrivacySettings(dynamic data) {
    if (data == null) return PrivacySettings.defaultSettings();
    if (data is! Map) return PrivacySettings.defaultSettings();

    final map = Map<String, dynamic>.from(data);
    return PrivacySettings(
      profileVisibility: _parseProfileVisibility(map['profileVisibility']),
      showRatingsPublic: map['showRatingsPublic'] as bool? ?? true,
      showWatchlistPublic: map['showWatchlistPublic'] as bool? ?? true,
      showFavoritesPublic: map['showFavoritesPublic'] as bool? ?? true,
      showStatsPublic: map['showStatsPublic'] as bool? ?? true,
      allowFriendRequests: map['allowFriendRequests'] as bool? ?? true,
      shareActivityOnSocial: map['shareActivityOnSocial'] as bool? ?? false,
      analyticsOptOut: map['analyticsOptOut'] as bool? ?? false,
    );
  }

  DigestFrequency _parseDigestFrequency(dynamic frequency) {
    if (frequency == null) return DigestFrequency.weekly;
    switch (frequency.toString().toLowerCase()) {
      case 'daily':
        return DigestFrequency.daily;
      case 'weekly':
        return DigestFrequency.weekly;
      case 'monthly':
        return DigestFrequency.monthly;
      case 'never':
        return DigestFrequency.never;
      default:
        return DigestFrequency.weekly;
    }
  }

  ProfileVisibility _parseProfileVisibility(dynamic visibility) {
    if (visibility == null) return ProfileVisibility.public;
    switch (visibility.toString().toLowerCase()) {
      case 'private':
        return ProfileVisibility.private;
      case 'friends':
        return ProfileVisibility.friends;
      case 'public':
        return ProfileVisibility.public;
      default:
        return ProfileVisibility.public;
    }
  }

  Map<String, dynamic> _notificationPreferencesToJson(
      NotificationPreferences prefs) {
    return {
      'enablePushNotifications': prefs.enablePushNotifications,
      'notifyNewRecommendations': prefs.notifyNewRecommendations,
      'notifyFriendsActivity': prefs.notifyFriendsActivity,
      'notifyNewReleases': prefs.notifyNewReleases,
      'notifyWatchlistUpdates': prefs.notifyWatchlistUpdates,
      'notifyAchievements': prefs.notifyAchievements,
      'emailDigest': prefs.emailDigest,
      'digestFrequency': prefs.digestFrequency.name,
    };
  }

  Map<String, dynamic> _privacySettingsToJson(PrivacySettings privacy) {
    return {
      'profileVisibility': privacy.profileVisibility.name,
      'showRatingsPublic': privacy.showRatingsPublic,
      'showWatchlistPublic': privacy.showWatchlistPublic,
      'showFavoritesPublic': privacy.showFavoritesPublic,
      'showStatsPublic': privacy.showStatsPublic,
      'allowFriendRequests': privacy.allowFriendRequests,
      'shareActivityOnSocial': privacy.shareActivityOnSocial,
      'analyticsOptOut': privacy.analyticsOptOut,
    };
  }
}
