// lib/services/ux_community/personalization/personalization_engine_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/logger_factory.dart';

enum PersonalizationLevel {
  minimal,
  standard,
  advanced,
  comprehensive,
}

enum PrivacyLevel {
  strict,
  moderate,
  relaxed,
  minimal,
}

enum RecommendationSource {
  viewingHistory,
  ratings,
  genres,
  similarUsers,
  trending,
  social,
  collaborative,
  contentBased,
}

class PersonalizationPreferences {
  const PersonalizationPreferences({
    required this.userId,
    this.level = PersonalizationLevel.standard,
    this.privacyLevel = PrivacyLevel.moderate,
    this.featureToggles = const {},
    this.preferences = const {},
    this.disabledSources = const [],
    this.sourceWeights = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory PersonalizationPreferences.fromJson(Map<String, dynamic> json) {
    return PersonalizationPreferences(
      userId: json['userId'],
      level: PersonalizationLevel.values.firstWhere(
        (e) => e.toString() == json['level'],
        orElse: () => PersonalizationLevel.standard,
      ),
      privacyLevel: PrivacyLevel.values.firstWhere(
        (e) => e.toString() == json['privacyLevel'],
        orElse: () => PrivacyLevel.moderate,
      ),
      featureToggles: Map<String, bool>.from(json['featureToggles'] ?? {}),
      preferences: Map<String, dynamic>.from(json['preferences'] ?? {}),
      disabledSources: List<String>.from(json['disabledSources'] ?? []),
      sourceWeights: Map<String, double>.from(json['sourceWeights'] ?? {}),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
  final String userId;
  final PersonalizationLevel level;
  final PrivacyLevel privacyLevel;
  final Map<String, bool> featureToggles;
  final Map<String, dynamic> preferences;
  final List<String> disabledSources;
  final Map<String, double> sourceWeights;
  final DateTime createdAt;
  final DateTime updatedAt;

  PersonalizationPreferences copyWith({
    String? userId,
    PersonalizationLevel? level,
    PrivacyLevel? privacyLevel,
    Map<String, bool>? featureToggles,
    Map<String, dynamic>? preferences,
    List<String>? disabledSources,
    Map<String, double>? sourceWeights,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PersonalizationPreferences(
      userId: userId ?? this.userId,
      level: level ?? this.level,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      featureToggles: featureToggles ?? this.featureToggles,
      preferences: preferences ?? this.preferences,
      disabledSources: disabledSources ?? this.disabledSources,
      sourceWeights: sourceWeights ?? this.sourceWeights,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'level': level.toString(),
      'privacyLevel': privacyLevel.toString(),
      'featureToggles': featureToggles,
      'preferences': preferences,
      'disabledSources': disabledSources,
      'sourceWeights': sourceWeights,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class UserBehaviorProfile {
  const UserBehaviorProfile({
    required this.userId,
    this.genrePreferences = const {},
    this.ratingPatterns = const {},
    this.lastViewedByGenre = const {},
    this.activityByTimeOfDay = const {},
    this.activityByDayOfWeek = const {},
    this.watchedMovieIds = const [],
    this.favoriteDirectors = const [],
    this.favoriteActors = const [],
    this.viewingPatterns = const {},
    this.interactionPatterns = const {},
    required this.profileCreated,
    required this.lastUpdated,
  });

  factory UserBehaviorProfile.fromJson(Map<String, dynamic> json) {
    return UserBehaviorProfile(
      userId: json['userId'],
      genrePreferences: Map<String, int>.from(json['genrePreferences'] ?? {}),
      ratingPatterns: Map<String, double>.from(json['ratingPatterns'] ?? {}),
      lastViewedByGenre:
          (json['lastViewedByGenre'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, DateTime.parse(v)),
      ),
      activityByTimeOfDay:
          Map<String, int>.from(json['activityByTimeOfDay'] ?? {}),
      activityByDayOfWeek:
          Map<String, int>.from(json['activityByDayOfWeek'] ?? {}),
      watchedMovieIds: List<String>.from(json['watchedMovieIds'] ?? []),
      favoriteDirectors: List<String>.from(json['favoriteDirectors'] ?? []),
      favoriteActors: List<String>.from(json['favoriteActors'] ?? []),
      viewingPatterns: Map<String, dynamic>.from(json['viewingPatterns'] ?? {}),
      interactionPatterns:
          Map<String, dynamic>.from(json['interactionPatterns'] ?? {}),
      profileCreated: DateTime.parse(json['profileCreated']),
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }
  final String userId;
  final Map<String, int> genrePreferences; // genre -> view count
  final Map<String, double> ratingPatterns; // genre -> average rating
  final Map<String, DateTime> lastViewedByGenre;
  final Map<String, int> activityByTimeOfDay; // hour -> activity count
  final Map<String, int> activityByDayOfWeek; // dayName -> activity count
  final List<String> watchedMovieIds;
  final List<String> favoriteDirectors;
  final List<String> favoriteActors;
  final Map<String, dynamic> viewingPatterns;
  final Map<String, dynamic> interactionPatterns;
  final DateTime profileCreated;
  final DateTime lastUpdated;

  UserBehaviorProfile copyWith({
    String? userId,
    Map<String, int>? genrePreferences,
    Map<String, double>? ratingPatterns,
    Map<String, DateTime>? lastViewedByGenre,
    Map<String, int>? activityByTimeOfDay,
    Map<String, int>? activityByDayOfWeek,
    List<String>? watchedMovieIds,
    List<String>? favoriteDirectors,
    List<String>? favoriteActors,
    Map<String, dynamic>? viewingPatterns,
    Map<String, dynamic>? interactionPatterns,
    DateTime? profileCreated,
    DateTime? lastUpdated,
  }) {
    return UserBehaviorProfile(
      userId: userId ?? this.userId,
      genrePreferences: genrePreferences ?? this.genrePreferences,
      ratingPatterns: ratingPatterns ?? this.ratingPatterns,
      lastViewedByGenre: lastViewedByGenre ?? this.lastViewedByGenre,
      activityByTimeOfDay: activityByTimeOfDay ?? this.activityByTimeOfDay,
      activityByDayOfWeek: activityByDayOfWeek ?? this.activityByDayOfWeek,
      watchedMovieIds: watchedMovieIds ?? this.watchedMovieIds,
      favoriteDirectors: favoriteDirectors ?? this.favoriteDirectors,
      favoriteActors: favoriteActors ?? this.favoriteActors,
      viewingPatterns: viewingPatterns ?? this.viewingPatterns,
      interactionPatterns: interactionPatterns ?? this.interactionPatterns,
      profileCreated: profileCreated ?? this.profileCreated,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'genrePreferences': genrePreferences,
      'ratingPatterns': ratingPatterns,
      'lastViewedByGenre':
          lastViewedByGenre.map((k, v) => MapEntry(k, v.toIso8601String())),
      'activityByTimeOfDay': activityByTimeOfDay,
      'activityByDayOfWeek': activityByDayOfWeek,
      'watchedMovieIds': watchedMovieIds,
      'favoriteDirectors': favoriteDirectors,
      'favoriteActors': favoriteActors,
      'viewingPatterns': viewingPatterns,
      'interactionPatterns': interactionPatterns,
      'profileCreated': profileCreated.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

class Recommendation {
  const Recommendation({
    required this.id,
    required this.movieId,
    required this.title,
    this.description,
    this.posterUrl,
    required this.confidence,
    required this.source,
    this.reasons = const {},
    this.tags = const [],
    required this.generatedAt,
    this.expiresAt,
    this.metadata = const {},
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      id: json['id'],
      movieId: json['movieId'],
      title: json['title'],
      description: json['description'],
      posterUrl: json['posterUrl'],
      confidence: json['confidence']?.toDouble() ?? 0.0,
      source: RecommendationSource.values.firstWhere(
        (e) => e.toString() == json['source'],
        orElse: () => RecommendationSource.contentBased,
      ),
      reasons: Map<String, dynamic>.from(json['reasons'] ?? {}),
      tags: List<String>.from(json['tags'] ?? []),
      generatedAt: DateTime.parse(json['generatedAt']),
      expiresAt:
          json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
  final String id;
  final String movieId;
  final String title;
  final String? description;
  final String? posterUrl;
  final double confidence;
  final RecommendationSource source;
  final Map<String, dynamic> reasons;
  final List<String> tags;
  final DateTime generatedAt;
  final DateTime? expiresAt;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'movieId': movieId,
      'title': title,
      'description': description,
      'posterUrl': posterUrl,
      'confidence': confidence,
      'source': source.toString(),
      'reasons': reasons,
      'tags': tags,
      'generatedAt': generatedAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'metadata': metadata,
    };
  }
}

class DeviceSyncProfile {
  const DeviceSyncProfile({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.lastSyncAt,
    this.syncedData = const {},
    this.syncableFeatures = const [],
    this.featureLastSync = const {},
  });

  factory DeviceSyncProfile.fromJson(Map<String, dynamic> json) {
    return DeviceSyncProfile(
      deviceId: json['deviceId'],
      deviceName: json['deviceName'],
      platform: json['platform'],
      lastSyncAt: DateTime.parse(json['lastSyncAt']),
      syncedData: Map<String, dynamic>.from(json['syncedData'] ?? {}),
      syncableFeatures: List<String>.from(json['syncableFeatures'] ?? []),
      featureLastSync:
          (json['featureLastSync'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, DateTime.parse(v)),
      ),
    );
  }
  final String deviceId;
  final String deviceName;
  final String platform;
  final DateTime lastSyncAt;
  final Map<String, dynamic> syncedData;
  final List<String> syncableFeatures;
  final Map<String, DateTime> featureLastSync;

  DeviceSyncProfile copyWith({
    String? deviceId,
    String? deviceName,
    String? platform,
    DateTime? lastSyncAt,
    Map<String, dynamic>? syncedData,
    List<String>? syncableFeatures,
    Map<String, DateTime>? featureLastSync,
  }) {
    return DeviceSyncProfile(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      platform: platform ?? this.platform,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      syncedData: syncedData ?? this.syncedData,
      syncableFeatures: syncableFeatures ?? this.syncableFeatures,
      featureLastSync: featureLastSync ?? this.featureLastSync,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': platform,
      'lastSyncAt': lastSyncAt.toIso8601String(),
      'syncedData': syncedData,
      'syncableFeatures': syncableFeatures,
      'featureLastSync':
          featureLastSync.map((k, v) => MapEntry(k, v.toIso8601String())),
    };
  }
}

class ContentInteraction {
  const ContentInteraction({
    required this.userId,
    required this.contentId,
    required this.contentType,
    required this.interactionType,
    required this.timestamp,
    this.context = const {},
    this.duration,
  });

  factory ContentInteraction.fromJson(Map<String, dynamic> json) {
    return ContentInteraction(
      userId: json['userId'],
      contentId: json['contentId'],
      contentType: json['contentType'],
      interactionType: json['interactionType'],
      timestamp: DateTime.parse(json['timestamp']),
      context: Map<String, dynamic>.from(json['context'] ?? {}),
      duration: json['duration'] != null
          ? Duration(milliseconds: json['duration'])
          : null,
    );
  }
  final String userId;
  final String contentId;
  final String contentType; // movie, review, list, etc.
  final String interactionType; // view, like, share, comment, etc.
  final DateTime timestamp;
  final Map<String, dynamic> context;
  final Duration? duration;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'contentId': contentId,
      'contentType': contentType,
      'interactionType': interactionType,
      'timestamp': timestamp.toIso8601String(),
      'context': context,
      'duration': duration?.inMilliseconds,
    };
  }
}

class PersonalizationEngineService {
  static const String _preferencesKey = 'personalization_preferences';
  static const String _behaviorProfilesKey = 'behavior_profiles';
  static const String _recommendationsKey = 'recommendations';
  static const String _deviceSyncKey = 'device_sync_profiles';
  static const String _interactionsKey = 'content_interactions';

  SharedPreferences? _prefs;
  final Map<String, PersonalizationPreferences> _userPreferences = {};
  final Map<String, UserBehaviorProfile> _behaviorProfiles = {};
  final Map<String, List<Recommendation>> _userRecommendations =
      {}; // userId -> recommendations
  final Map<String, List<DeviceSyncProfile>> _userDevices =
      {}; // userId -> devices
  final Map<String, List<ContentInteraction>> _userInteractions =
      {}; // userId -> interactions

  final StreamController<PersonalizationPreferences> _preferencesController =
      StreamController.broadcast();
  final StreamController<List<Recommendation>> _recommendationsController =
      StreamController.broadcast();
  final StreamController<UserBehaviorProfile> _profileController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _syncController =
      StreamController.broadcast();

  // Getters
  Stream<PersonalizationPreferences> get preferencesStream =>
      _preferencesController.stream;
  Stream<List<Recommendation>> get recommendationsStream =>
      _recommendationsController.stream;
  Stream<UserBehaviorProfile> get profileStream => _profileController.stream;
  Stream<Map<String, dynamic>> get syncStream => _syncController.stream;

  // Initialize
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadPersonalizationPreferences();
      await _loadBehaviorProfiles();
      await _loadRecommendations();
      await _loadDeviceSyncProfiles();
      await _loadContentInteractions();
      LoggerFactory.info('PersonalizationEngineService initialized successfully');
    } catch (e) {
      LoggerFactory.error('Error initializing PersonalizationEngineService: $e');
    }
  }

  // Preferences Management
  Future<void> updatePersonalizationPreferences(
      PersonalizationPreferences preferences) async {
    try {
      final updatedPreferences =
          preferences.copyWith(updatedAt: DateTime.now());
      _userPreferences[preferences.userId] = updatedPreferences;

      await _savePersonalizationPreferences();
      _preferencesController.add(updatedPreferences);

      // Regenerate recommendations based on new preferences
      await _generateRecommendationsForUser(preferences.userId);

      LoggerFactory.info(
          'Personalization preferences updated for user ${preferences.userId}');
    } catch (e) {
      LoggerFactory.error('Error updating personalization preferences: $e');
    }
  }

  PersonalizationPreferences getUserPreferences(String userId) {
    return _userPreferences[userId] ??
        PersonalizationPreferences(
          userId: userId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
  }

  Future<void> setPersonalizationLevel(
      String userId, PersonalizationLevel level) async {
    final preferences = getUserPreferences(userId);
    await updatePersonalizationPreferences(preferences.copyWith(level: level));
  }

  Future<void> setPrivacyLevel(String userId, PrivacyLevel level) async {
    final preferences = getUserPreferences(userId);
    await updatePersonalizationPreferences(
        preferences.copyWith(privacyLevel: level));
  }

  Future<void> toggleFeature(
      String userId, String feature, bool enabled) async {
    final preferences = getUserPreferences(userId);
    final updatedToggles = Map<String, bool>.from(preferences.featureToggles);
    updatedToggles[feature] = enabled;

    await updatePersonalizationPreferences(
        preferences.copyWith(featureToggles: updatedToggles));
  }

  bool isFeatureEnabled(String userId, String feature) {
    final preferences = getUserPreferences(userId);
    return preferences.featureToggles[feature] ?? true; // Default to enabled
  }

  // Behavior Tracking
  Future<void> trackContentInteraction({
    required String userId,
    required String contentId,
    required String contentType,
    required String interactionType,
    Map<String, dynamic> context = const {},
    Duration? duration,
  }) async {
    try {
      // Check privacy settings
      final preferences = getUserPreferences(userId);
      if (preferences.privacyLevel == PrivacyLevel.strict) {
        return; // Don't track if strict privacy
      }

      final interaction = ContentInteraction(
        userId: userId,
        contentId: contentId,
        contentType: contentType,
        interactionType: interactionType,
        timestamp: DateTime.now(),
        context: context,
        duration: duration,
      );

      _userInteractions.putIfAbsent(userId, () => []);
      _userInteractions[userId]!.add(interaction);

      // Keep only recent interactions (e.g., last 10000)
      if (_userInteractions[userId]!.length > 10000) {
        _userInteractions[userId] =
            _userInteractions[userId]!.skip(1000).toList();
      }

      await _saveContentInteractions();

      // Update behavior profile
      await _updateBehaviorProfileFromInteraction(userId, interaction);

      LoggerFactory.debug(
          'Tracked interaction: $interactionType for $contentType $contentId by user $userId');
    } catch (e) {
      LoggerFactory.error('Error tracking content interaction: $e');
    }
  }

  Future<void> _updateBehaviorProfileFromInteraction(
      String userId, ContentInteraction interaction) async {
    try {
      final profile = _behaviorProfiles[userId] ??
          UserBehaviorProfile(
            userId: userId,
            profileCreated: DateTime.now(),
            lastUpdated: DateTime.now(),
          );

      final now = DateTime.now();
      final hour = now.hour.toString();
      final dayOfWeek = _getDayOfWeek(now.weekday);

      // Update activity patterns
      final updatedTimeActivity =
          Map<String, int>.from(profile.activityByTimeOfDay);
      updatedTimeActivity[hour] = (updatedTimeActivity[hour] ?? 0) + 1;

      final updatedDayActivity =
          Map<String, int>.from(profile.activityByDayOfWeek);
      updatedDayActivity[dayOfWeek] = (updatedDayActivity[dayOfWeek] ?? 0) + 1;

      // Update interaction patterns
      final updatedInteractionPatterns =
          Map<String, dynamic>.from(profile.interactionPatterns);
      final interactionKey =
          '${interaction.contentType}_${interaction.interactionType}';
      updatedInteractionPatterns[interactionKey] =
          (updatedInteractionPatterns[interactionKey] ?? 0) + 1;

      // Update specific patterns based on interaction type
      final updatedProfile = await _updateSpecificBehaviorPatterns(
        profile.copyWith(
          activityByTimeOfDay: updatedTimeActivity,
          activityByDayOfWeek: updatedDayActivity,
          interactionPatterns: updatedInteractionPatterns,
          lastUpdated: now,
        ),
        interaction,
      );

      _behaviorProfiles[userId] = updatedProfile;
      await _saveBehaviorProfiles();
      _profileController.add(updatedProfile);
    } catch (e) {
      LoggerFactory.error('Error updating behavior profile: $e');
    }
  }

  Future<UserBehaviorProfile> _updateSpecificBehaviorPatterns(
    UserBehaviorProfile profile,
    ContentInteraction interaction,
  ) async {
    if (interaction.contentType == 'movie' &&
        interaction.interactionType == 'view') {
      // Update watched movies
      final updatedWatchedIds = List<String>.from(profile.watchedMovieIds);
      if (!updatedWatchedIds.contains(interaction.contentId)) {
        updatedWatchedIds.add(interaction.contentId);
      }

      // Extract genre from context if available
      final genre = interaction.context['genre'] as String?;
      if (genre != null) {
        final updatedGenrePrefs =
            Map<String, int>.from(profile.genrePreferences);
        updatedGenrePrefs[genre] = (updatedGenrePrefs[genre] ?? 0) + 1;

        final updatedLastViewed =
            Map<String, DateTime>.from(profile.lastViewedByGenre);
        updatedLastViewed[genre] = DateTime.now();

        return profile.copyWith(
          watchedMovieIds: updatedWatchedIds,
          genrePreferences: updatedGenrePrefs,
          lastViewedByGenre: updatedLastViewed,
        );
      }

      return profile.copyWith(watchedMovieIds: updatedWatchedIds);
    }

    if (interaction.contentType == 'movie' &&
        interaction.interactionType == 'rate') {
      final genre = interaction.context['genre'] as String?;
      final rating = interaction.context['rating'] as double?;

      if (genre != null && rating != null) {
        final updatedRatingPatterns =
            Map<String, double>.from(profile.ratingPatterns);
        final currentAvg = updatedRatingPatterns[genre] ?? 0.0;
        final genreCount = profile.genrePreferences[genre] ?? 1;

        // Calculate new average rating for genre
        final newAvg = ((currentAvg * genreCount) + rating) / (genreCount + 1);
        updatedRatingPatterns[genre] = newAvg;

        return profile.copyWith(ratingPatterns: updatedRatingPatterns);
      }
    }

    return profile;
  }

  String _getDayOfWeek(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday - 1];
  }

  UserBehaviorProfile getUserBehaviorProfile(String userId) {
    return _behaviorProfiles[userId] ??
        UserBehaviorProfile(
          userId: userId,
          profileCreated: DateTime.now(),
          lastUpdated: DateTime.now(),
        );
  }

  List<ContentInteraction> getUserInteractions(String userId,
      {int limit = 100}) {
    final interactions = _userInteractions[userId] ?? [];
    return interactions.reversed.take(limit).toList();
  }

  // Recommendations Engine
  Future<void> generateRecommendations(String userId,
      {bool forceRefresh = false}) async {
    try {
      final preferences = getUserPreferences(userId);
      if (preferences.level == PersonalizationLevel.minimal) {
        return; // No personalized recommendations
      }

      // Check if we have recent recommendations and don't need refresh
      final existing = _userRecommendations[userId] ?? [];
      if (!forceRefresh && existing.isNotEmpty) {
        final latestRec = existing.first;
        final hoursSinceGenerated =
            DateTime.now().difference(latestRec.generatedAt).inHours;
        if (hoursSinceGenerated < 6) {
          // Refresh every 6 hours
          return;
        }
      }

      await _generateRecommendationsForUser(userId);
    } catch (e) {
      LoggerFactory.error('Error generating recommendations: $e');
    }
  }

  Future<void> _generateRecommendationsForUser(String userId) async {
    try {
      final preferences = getUserPreferences(userId);
      final profile = getUserBehaviorProfile(userId);

      final recommendations = <Recommendation>[];

      // Generate recommendations from different sources based on preferences
      if (!preferences.disabledSources
          .contains(RecommendationSource.viewingHistory.toString())) {
        recommendations.addAll(
            await _generateFromViewingHistory(userId, profile, preferences));
      }

      if (!preferences.disabledSources
          .contains(RecommendationSource.genres.toString())) {
        recommendations.addAll(
            await _generateFromGenrePreferences(userId, profile, preferences));
      }

      if (!preferences.disabledSources
          .contains(RecommendationSource.ratings.toString())) {
        recommendations
            .addAll(await _generateFromRatings(userId, profile, preferences));
      }

      if (!preferences.disabledSources
          .contains(RecommendationSource.trending.toString())) {
        recommendations
            .addAll(await _generateFromTrending(userId, preferences));
      }

      if (preferences.level == PersonalizationLevel.advanced ||
          preferences.level == PersonalizationLevel.comprehensive) {
        if (!preferences.disabledSources
            .contains(RecommendationSource.similarUsers.toString())) {
          recommendations.addAll(
              await _generateFromSimilarUsers(userId, profile, preferences));
        }
      }

      // Sort by confidence and remove duplicates
      recommendations.sort((a, b) => b.confidence.compareTo(a.confidence));
      final uniqueRecommendations =
          _removeDuplicateRecommendations(recommendations);

      // Limit recommendations based on personalization level
      final limit = _getRecommendationLimit(preferences.level);
      final finalRecommendations = uniqueRecommendations.take(limit).toList();

      _userRecommendations[userId] = finalRecommendations;
      await _saveRecommendations();
      _recommendationsController.add(finalRecommendations);

      LoggerFactory.info(
          'Generated ${finalRecommendations.length} recommendations for user $userId');
    } catch (e) {
      LoggerFactory.error('Error generating recommendations for user: $e');
    }
  }

  Future<List<Recommendation>> _generateFromViewingHistory(
    String userId,
    UserBehaviorProfile profile,
    PersonalizationPreferences preferences,
  ) async {
    // Mock implementation - in real app, this would use ML algorithms
    final recommendations = <Recommendation>[];

    if (profile.watchedMovieIds.isNotEmpty) {
      // Generate recommendations based on last watched movies
      final recentMovies = profile.watchedMovieIds.take(10).toList();

      for (int i = 0;
          i < recentMovies.length && recommendations.length < 5;
          i++) {
        final movieId = recentMovies[i];
        recommendations.add(Recommendation(
          id: 'history_${DateTime.now().millisecondsSinceEpoch}_$i',
          movieId: 'similar_to_$movieId',
          title: 'Similar to Recently Watched #${i + 1}',
          description: 'Based on your viewing history',
          confidence: 0.8 - (i * 0.1),
          source: RecommendationSource.viewingHistory,
          reasons: {'basedOn': movieId, 'similarity': 0.8 - (i * 0.1)},
          tags: ['viewing_history', 'similar'],
          generatedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 7)),
        ));
      }
    }

    return recommendations;
  }

  Future<List<Recommendation>> _generateFromGenrePreferences(
    String userId,
    UserBehaviorProfile profile,
    PersonalizationPreferences preferences,
  ) async {
    final recommendations = <Recommendation>[];

    // Get top 3 genres by preference
    final sortedGenres = profile.genrePreferences.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (int i = 0;
        i < sortedGenres.length && i < 3 && recommendations.length < 8;
        i++) {
      final genre = sortedGenres[i];
      final confidence = 0.7 + (genre.value / 100.0).clamp(0.0, 0.2); // Max 0.9

      recommendations.add(Recommendation(
        id: 'genre_${DateTime.now().millisecondsSinceEpoch}_$i',
        movieId: 'popular_${genre.key}_movie_$i',
        title: 'Popular ${genre.key} Movie #${i + 1}',
        description: 'You\'ve watched ${genre.value} ${genre.key} movies',
        confidence: confidence,
        source: RecommendationSource.genres,
        reasons: {'genre': genre.key, 'watchCount': genre.value},
        tags: [genre.key.toLowerCase(), 'genre_based'],
        generatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 5)),
      ));
    }

    return recommendations;
  }

  Future<List<Recommendation>> _generateFromRatings(
    String userId,
    UserBehaviorProfile profile,
    PersonalizationPreferences preferences,
  ) async {
    final recommendations = <Recommendation>[];

    // Generate recommendations based on highly rated genres
    final highRatedGenres = profile.ratingPatterns.entries
        .where((entry) => entry.value >= 4.0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (int i = 0; i < highRatedGenres.length && i < 3; i++) {
      final genre = highRatedGenres[i];

      recommendations.add(Recommendation(
        id: 'rating_${DateTime.now().millisecondsSinceEpoch}_$i',
        movieId: 'highly_rated_${genre.key}_$i',
        title: 'Highly Rated ${genre.key} Movie',
        description:
            'You rate ${genre.key} movies ${genre.value.toStringAsFixed(1)}/5 on average',
        confidence: 0.75 + ((genre.value - 4.0) * 0.15),
        source: RecommendationSource.ratings,
        reasons: {'genre': genre.key, 'averageRating': genre.value},
        tags: [genre.key.toLowerCase(), 'highly_rated'],
        generatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 3)),
      ));
    }

    return recommendations;
  }

  Future<List<Recommendation>> _generateFromTrending(
    String userId,
    PersonalizationPreferences preferences,
  ) async {
    final recommendations = <Recommendation>[];

    // Mock trending content
    for (int i = 0; i < 5; i++) {
      recommendations.add(Recommendation(
        id: 'trending_${DateTime.now().millisecondsSinceEpoch}_$i',
        movieId: 'trending_movie_$i',
        title: 'Trending Movie #${i + 1}',
        description: 'Popular right now',
        confidence: 0.6 - (i * 0.05),
        source: RecommendationSource.trending,
        reasons: {'trendingRank': i + 1, 'popularity': 0.9 - (i * 0.1)},
        tags: ['trending', 'popular'],
        generatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 12)),
      ));
    }

    return recommendations;
  }

  Future<List<Recommendation>> _generateFromSimilarUsers(
    String userId,
    UserBehaviorProfile profile,
    PersonalizationPreferences preferences,
  ) async {
    final recommendations = <Recommendation>[];

    // Mock similar user recommendations
    // In real implementation, this would use collaborative filtering
    for (int i = 0; i < 3; i++) {
      recommendations.add(Recommendation(
        id: 'similar_users_${DateTime.now().millisecondsSinceEpoch}_$i',
        movieId: 'similar_user_rec_$i',
        title: 'Recommended by Similar Users #${i + 1}',
        description: 'Users with similar taste loved this',
        confidence: 0.65 - (i * 0.05),
        source: RecommendationSource.similarUsers,
        reasons: {'similarityScore': 0.8 - (i * 0.1)},
        tags: ['collaborative', 'similar_users'],
        generatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 2)),
      ));
    }

    return recommendations;
  }

  List<Recommendation> _removeDuplicateRecommendations(
      List<Recommendation> recommendations) {
    final seen = <String>{};
    return recommendations.where((rec) {
      if (seen.contains(rec.movieId)) {
        return false;
      }
      seen.add(rec.movieId);
      return true;
    }).toList();
  }

  int _getRecommendationLimit(PersonalizationLevel level) {
    switch (level) {
      case PersonalizationLevel.minimal:
        return 5;
      case PersonalizationLevel.standard:
        return 15;
      case PersonalizationLevel.advanced:
        return 25;
      case PersonalizationLevel.comprehensive:
        return 50;
    }
  }

  List<Recommendation> getUserRecommendations(String userId) {
    return _userRecommendations[userId] ?? [];
  }

  Future<void> markRecommendationViewed(
      String userId, String recommendationId) async {
    try {
      await trackContentInteraction(
        userId: userId,
        contentId: recommendationId,
        contentType: 'recommendation',
        interactionType: 'view',
      );
    } catch (e) {
      LoggerFactory.error('Error marking recommendation viewed: $e');
    }
  }

  Future<void> rateRecommendation(
      String userId, String recommendationId, double rating) async {
    try {
      await trackContentInteraction(
        userId: userId,
        contentId: recommendationId,
        contentType: 'recommendation',
        interactionType: 'rate',
        context: {'rating': rating},
      );
    } catch (e) {
      LoggerFactory.error('Error rating recommendation: $e');
    }
  }

  // Multi-Device Sync
  Future<void> registerDevice(String userId, String deviceId, String deviceName,
      String platform) async {
    try {
      final devices = _userDevices[userId] ?? [];

      // Check if device already exists
      final existingDeviceIndex =
          devices.indexWhere((d) => d.deviceId == deviceId);

      final deviceProfile = DeviceSyncProfile(
        deviceId: deviceId,
        deviceName: deviceName,
        platform: platform,
        lastSyncAt: DateTime.now(),
        syncableFeatures: _getDefaultSyncableFeatures(),
      );

      if (existingDeviceIndex >= 0) {
        devices[existingDeviceIndex] = deviceProfile;
      } else {
        devices.add(deviceProfile);
      }

      _userDevices[userId] = devices;
      await _saveDeviceSyncProfiles();

      _syncController.add({
        'type': 'device_registered',
        'userId': userId,
        'deviceId': deviceId,
        'deviceName': deviceName,
      });

      LoggerFactory.info('Device registered: $deviceName ($deviceId) for user $userId');
    } catch (e) {
      LoggerFactory.error('Error registering device: $e');
    }
  }

  List<String> _getDefaultSyncableFeatures() {
    return [
      'preferences',
      'watchlist',
      'recommendations',
      'behavior_profile',
      'theme_settings',
      'app_settings',
    ];
  }

  Future<void> syncDataToDevice(
      String userId, String deviceId, List<String> features) async {
    try {
      final devices = _userDevices[userId] ?? [];
      final deviceIndex = devices.indexWhere((d) => d.deviceId == deviceId);

      if (deviceIndex == -1) {
        throw Exception('Device not found');
      }

      final device = devices[deviceIndex];
      final syncData = <String, dynamic>{};

      for (final feature in features) {
        switch (feature) {
          case 'preferences':
            syncData['preferences'] = getUserPreferences(userId).toJson();
            break;
          case 'behavior_profile':
            syncData['behavior_profile'] =
                getUserBehaviorProfile(userId).toJson();
            break;
          case 'recommendations':
            syncData['recommendations'] =
                getUserRecommendations(userId).map((r) => r.toJson()).toList();
            break;
        }
      }

      final now = DateTime.now();
      final updatedFeatureSync =
          Map<String, DateTime>.from(device.featureLastSync);
      for (final feature in features) {
        updatedFeatureSync[feature] = now;
      }

      devices[deviceIndex] = device.copyWith(
        lastSyncAt: now,
        syncedData: {...device.syncedData, ...syncData},
        featureLastSync: updatedFeatureSync,
      );

      _userDevices[userId] = devices;
      await _saveDeviceSyncProfiles();

      _syncController.add({
        'type': 'data_synced',
        'userId': userId,
        'deviceId': deviceId,
        'features': features,
        'syncedAt': now.toIso8601String(),
      });

      LoggerFactory.info(
          'Synced ${features.length} features to device $deviceId for user $userId');
    } catch (e) {
      LoggerFactory.error('Error syncing data to device: $e');
    }
  }

  List<DeviceSyncProfile> getUserDevices(String userId) {
    return _userDevices[userId] ?? [];
  }

  Future<void> removeDevice(String userId, String deviceId) async {
    try {
      final devices = _userDevices[userId] ?? [];
      devices.removeWhere((d) => d.deviceId == deviceId);

      _userDevices[userId] = devices;
      await _saveDeviceSyncProfiles();

      _syncController.add({
        'type': 'device_removed',
        'userId': userId,
        'deviceId': deviceId,
      });

      LoggerFactory.info('Device removed: $deviceId for user $userId');
    } catch (e) {
      LoggerFactory.error('Error removing device: $e');
    }
  }

  // Analytics and Insights
  Map<String, dynamic> getUserAnalytics(String userId) {
    final profile = getUserBehaviorProfile(userId);
    final interactions = getUserInteractions(userId, limit: 1000);

    return {
      'totalInteractions': interactions.length,
      'favoriteGenres': _getTopGenres(profile.genrePreferences, 5),
      'activityPattern': _getActivityPattern(profile.activityByTimeOfDay),
      'engagementScore': _calculateEngagementScore(interactions),
      'diversityScore': _calculateDiversityScore(profile.genrePreferences),
      'recommendationAccuracy': _calculateRecommendationAccuracy(userId),
    };
  }

  List<Map<String, dynamic>> _getTopGenres(
      Map<String, int> genrePreferences, int limit) {
    final sorted = genrePreferences.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .take(limit)
        .map((entry) => {
              'genre': entry.key,
              'count': entry.value,
            })
        .toList();
  }

  Map<String, dynamic> _getActivityPattern(Map<String, int> activityByHour) {
    if (activityByHour.isEmpty) return {'pattern': 'unknown', 'peakHour': -1};

    final sortedHours = activityByHour.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final peakHour = int.parse(sortedHours.first.key);

    String pattern;
    if (peakHour >= 6 && peakHour < 12) {
      pattern = 'morning';
    } else if (peakHour >= 12 && peakHour < 18) {
      pattern = 'afternoon';
    } else if (peakHour >= 18 && peakHour < 22) {
      pattern = 'evening';
    } else {
      pattern = 'night';
    }

    return {
      'pattern': pattern,
      'peakHour': peakHour,
      'distribution': activityByHour,
    };
  }

  double _calculateEngagementScore(List<ContentInteraction> interactions) {
    if (interactions.isEmpty) return 0.0;

    final weights = {
      'view': 1.0,
      'like': 2.0,
      'share': 3.0,
      'comment': 4.0,
      'rate': 2.5,
    };

    double totalScore = 0;
    for (final interaction in interactions) {
      totalScore += weights[interaction.interactionType] ?? 1.0;
    }

    return (totalScore / interactions.length).clamp(0.0, 5.0);
  }

  double _calculateDiversityScore(Map<String, int> genrePreferences) {
    if (genrePreferences.isEmpty) return 0.0;

    final totalViews =
        genrePreferences.values.fold(0, (sum, count) => sum + count);
    if (totalViews == 0) return 0.0;

    // Calculate genre diversity using Shannon diversity index
    double diversity = 0.0;
    for (final count in genrePreferences.values) {
      final proportion = count / totalViews;
      if (proportion > 0) {
        diversity -= proportion *
            (proportion > 0
                ? math.log(proportion) / math.ln2
                : 0); // log base 2
      }
    }

    return (diversity / 4.0).clamp(0.0, 1.0); // Normalize to 0-1
  }

  double _calculateRecommendationAccuracy(String userId) {
    // Mock implementation - would calculate based on user feedback
    return 0.75; // 75% accuracy
  }

  // Persistence Methods
  Future<void> _loadPersonalizationPreferences() async {
    final json = _prefs?.getString(_preferencesKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _userPreferences.clear();
      data.forEach((key, value) {
        _userPreferences[key] = PersonalizationPreferences.fromJson(value);
      });
    }
  }

  Future<void> _savePersonalizationPreferences() async {
    final data = <String, dynamic>{};
    _userPreferences.forEach((key, preferences) {
      data[key] = preferences.toJson();
    });
    await _prefs?.setString(_preferencesKey, jsonEncode(data));
  }

  Future<void> _loadBehaviorProfiles() async {
    final json = _prefs?.getString(_behaviorProfilesKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _behaviorProfiles.clear();
      data.forEach((key, value) {
        _behaviorProfiles[key] = UserBehaviorProfile.fromJson(value);
      });
    }
  }

  Future<void> _saveBehaviorProfiles() async {
    final data = <String, dynamic>{};
    _behaviorProfiles.forEach((key, profile) {
      data[key] = profile.toJson();
    });
    await _prefs?.setString(_behaviorProfilesKey, jsonEncode(data));
  }

  Future<void> _loadRecommendations() async {
    final json = _prefs?.getString(_recommendationsKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _userRecommendations.clear();
      data.forEach((userId, recommendationsList) {
        _userRecommendations[userId] = (recommendationsList as List<dynamic>)
            .map((r) => Recommendation.fromJson(r))
            .toList();
      });
    }
  }

  Future<void> _saveRecommendations() async {
    final data = <String, dynamic>{};
    _userRecommendations.forEach((userId, recommendations) {
      data[userId] = recommendations.map((r) => r.toJson()).toList();
    });
    await _prefs?.setString(_recommendationsKey, jsonEncode(data));
  }

  Future<void> _loadDeviceSyncProfiles() async {
    final json = _prefs?.getString(_deviceSyncKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _userDevices.clear();
      data.forEach((userId, devicesList) {
        _userDevices[userId] = (devicesList as List<dynamic>)
            .map((d) => DeviceSyncProfile.fromJson(d))
            .toList();
      });
    }
  }

  Future<void> _saveDeviceSyncProfiles() async {
    final data = <String, dynamic>{};
    _userDevices.forEach((userId, devices) {
      data[userId] = devices.map((d) => d.toJson()).toList();
    });
    await _prefs?.setString(_deviceSyncKey, jsonEncode(data));
  }

  Future<void> _loadContentInteractions() async {
    final json = _prefs?.getString(_interactionsKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _userInteractions.clear();
      data.forEach((userId, interactionsList) {
        _userInteractions[userId] = (interactionsList as List<dynamic>)
            .map((i) => ContentInteraction.fromJson(i))
            .toList();
      });
    }
  }

  Future<void> _saveContentInteractions() async {
    final data = <String, dynamic>{};
    _userInteractions.forEach((userId, interactions) {
      data[userId] = interactions.map((i) => i.toJson()).toList();
    });
    await _prefs?.setString(_interactionsKey, jsonEncode(data));
  }

  // Dispose
  void dispose() {
    _preferencesController.close();
    _recommendationsController.close();
    _profileController.close();
    _syncController.close();
  }
}
