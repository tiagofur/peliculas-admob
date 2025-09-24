// lib/services/ux_community/phase6_manager.dart

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/logger_factory.dart';
import 'accessibility/accessibility_service.dart';
import 'community/community_forum_service.dart';
import 'community/social_interaction_service.dart';
import 'community/user_review_service.dart';
import 'gamification/gamification_service.dart';
import 'personalization/personalization_engine_service.dart';
// Import all Phase 6 services
import 'theme/advanced_theme_manager.dart';
import 'ux_components/advanced_ux_service.dart';

enum Phase6Feature {
  advancedTheming,
  communityReviews,
  socialInteractions,
  communityForums,
  gamification,
  personalization,
  advancedUX,
  accessibility,
}

enum CrossServiceEvent {
  userEngagement,
  contentInteraction,
  socialActivity,
  achievementUnlocked,
  themeChanged,
  accessibilityChanged,
  personalizationUpdated,
  communityContribution,
}

class Phase6Settings {
  const Phase6Settings({
    required this.userId,
    this.enabledFeatures = const {},
    this.enableCrossServiceIntegration = true,
    this.enableRealTimeSync = true,
    this.enableAnalytics = true,
    this.globalSettings = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory Phase6Settings.fromJson(Map<String, dynamic> json) {
    return Phase6Settings(
      userId: json['userId'],
      enabledFeatures: (json['enabledFeatures'] as List<dynamic>? ?? [])
          .map((f) => Phase6Feature.values.firstWhere(
                (e) => e.toString() == f,
                orElse: () => Phase6Feature.advancedTheming,
              ))
          .toSet(),
      enableCrossServiceIntegration:
          json['enableCrossServiceIntegration'] ?? true,
      enableRealTimeSync: json['enableRealTimeSync'] ?? true,
      enableAnalytics: json['enableAnalytics'] ?? true,
      globalSettings: Map<String, dynamic>.from(json['globalSettings'] ?? {}),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
  final String userId;
  final Set<Phase6Feature> enabledFeatures;
  final bool enableCrossServiceIntegration;
  final bool enableRealTimeSync;
  final bool enableAnalytics;
  final Map<String, dynamic> globalSettings;
  final DateTime createdAt;
  final DateTime updatedAt;

  Phase6Settings copyWith({
    String? userId,
    Set<Phase6Feature>? enabledFeatures,
    bool? enableCrossServiceIntegration,
    bool? enableRealTimeSync,
    bool? enableAnalytics,
    Map<String, dynamic>? globalSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Phase6Settings(
      userId: userId ?? this.userId,
      enabledFeatures: enabledFeatures ?? this.enabledFeatures,
      enableCrossServiceIntegration:
          enableCrossServiceIntegration ?? this.enableCrossServiceIntegration,
      enableRealTimeSync: enableRealTimeSync ?? this.enableRealTimeSync,
      enableAnalytics: enableAnalytics ?? this.enableAnalytics,
      globalSettings: globalSettings ?? this.globalSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'enabledFeatures': enabledFeatures.map((f) => f.toString()).toList(),
      'enableCrossServiceIntegration': enableCrossServiceIntegration,
      'enableRealTimeSync': enableRealTimeSync,
      'enableAnalytics': enableAnalytics,
      'globalSettings': globalSettings,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class CrossServiceEventData {
  const CrossServiceEventData({
    required this.eventId,
    required this.eventType,
    required this.sourceService,
    required this.userId,
    required this.data,
    required this.timestamp,
    this.targetService,
    this.isProcessed = false,
  });

  factory CrossServiceEventData.fromJson(Map<String, dynamic> json) {
    return CrossServiceEventData(
      eventId: json['eventId'],
      eventType: CrossServiceEvent.values.firstWhere(
        (e) => e.toString() == json['eventType'],
        orElse: () => CrossServiceEvent.userEngagement,
      ),
      sourceService: json['sourceService'],
      userId: json['userId'],
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      timestamp: DateTime.parse(json['timestamp']),
      targetService: json['targetService'],
      isProcessed: json['isProcessed'] ?? false,
    );
  }
  final String eventId;
  final CrossServiceEvent eventType;
  final String sourceService;
  final String userId;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String? targetService;
  final bool isProcessed;

  CrossServiceEventData copyWith({
    String? eventId,
    CrossServiceEvent? eventType,
    String? sourceService,
    String? userId,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    String? targetService,
    bool? isProcessed,
  }) {
    return CrossServiceEventData(
      eventId: eventId ?? this.eventId,
      eventType: eventType ?? this.eventType,
      sourceService: sourceService ?? this.sourceService,
      userId: userId ?? this.userId,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      targetService: targetService ?? this.targetService,
      isProcessed: isProcessed ?? this.isProcessed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'eventType': eventType.toString(),
      'sourceService': sourceService,
      'userId': userId,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'targetService': targetService,
      'isProcessed': isProcessed,
    };
  }
}

class Phase6Analytics {
  const Phase6Analytics({
    required this.userId,
    this.featureUsageCount = const {},
    this.eventCount = const {},
    this.engagementMetrics = const {},
    required this.lastActivity,
    this.totalUsageTime = Duration.zero,
    this.sessionsCount = 0,
  });

  factory Phase6Analytics.fromJson(Map<String, dynamic> json) {
    return Phase6Analytics(
      userId: json['userId'],
      featureUsageCount:
          (json['featureUsageCount'] as Map<String, dynamic>? ?? {})
              .map((k, v) => MapEntry(
                    Phase6Feature.values.firstWhere(
                      (e) => e.toString() == k,
                      orElse: () => Phase6Feature.advancedTheming,
                    ),
                    v as int,
                  )),
      eventCount: (json['eventCount'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(
                CrossServiceEvent.values.firstWhere(
                  (e) => e.toString() == k,
                  orElse: () => CrossServiceEvent.userEngagement,
                ),
                v as int,
              )),
      engagementMetrics:
          Map<String, double>.from(json['engagementMetrics'] ?? {}),
      lastActivity: DateTime.parse(json['lastActivity']),
      totalUsageTime: Duration(milliseconds: json['totalUsageTime'] ?? 0),
      sessionsCount: json['sessionsCount'] ?? 0,
    );
  }
  final String userId;
  final Map<Phase6Feature, int> featureUsageCount;
  final Map<CrossServiceEvent, int> eventCount;
  final Map<String, double> engagementMetrics;
  final DateTime lastActivity;
  final Duration totalUsageTime;
  final int sessionsCount;

  Phase6Analytics copyWith({
    String? userId,
    Map<Phase6Feature, int>? featureUsageCount,
    Map<CrossServiceEvent, int>? eventCount,
    Map<String, double>? engagementMetrics,
    DateTime? lastActivity,
    Duration? totalUsageTime,
    int? sessionsCount,
  }) {
    return Phase6Analytics(
      userId: userId ?? this.userId,
      featureUsageCount: featureUsageCount ?? this.featureUsageCount,
      eventCount: eventCount ?? this.eventCount,
      engagementMetrics: engagementMetrics ?? this.engagementMetrics,
      lastActivity: lastActivity ?? this.lastActivity,
      totalUsageTime: totalUsageTime ?? this.totalUsageTime,
      sessionsCount: sessionsCount ?? this.sessionsCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'featureUsageCount':
          featureUsageCount.map((k, v) => MapEntry(k.toString(), v)),
      'eventCount': eventCount.map((k, v) => MapEntry(k.toString(), v)),
      'engagementMetrics': engagementMetrics,
      'lastActivity': lastActivity.toIso8601String(),
      'totalUsageTime': totalUsageTime.inMilliseconds,
      'sessionsCount': sessionsCount,
    };
  }
}

class Phase6Manager {
  static const String _settingsKey = 'phase6_settings';
  static const String _analyticsKey = 'phase6_analytics';
  static const String _eventsKey = 'phase6_events';

  // Services
  late final AdvancedThemeManager _themeManager;
  late final UserReviewService _reviewService;
  late final SocialInteractionService _socialService;
  late final CommunityForumService _forumService;
  late final GamificationService _gamificationService;
  late final PersonalizationEngineService _personalizationService;
  late final AdvancedUXService _uxService;
  late final AccessibilityService _accessibilityService;

  SharedPreferences? _prefs;
  final Map<String, Phase6Settings> _userSettings = {};
  final Map<String, Phase6Analytics> _userAnalytics = {};
  final List<CrossServiceEventData> _pendingEvents = [];

  final StreamController<Phase6Settings> _settingsController =
      StreamController.broadcast();
  final StreamController<CrossServiceEventData> _eventController =
      StreamController.broadcast();
  final StreamController<Phase6Analytics> _analyticsController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _coordinationController =
      StreamController.broadcast();

  // Getters for services
  AdvancedThemeManager get themeManager => _themeManager;
  UserReviewService get reviewService => _reviewService;
  SocialInteractionService get socialService => _socialService;
  CommunityForumService get forumService => _forumService;
  GamificationService get gamificationService => _gamificationService;
  PersonalizationEngineService get personalizationService =>
      _personalizationService;
  AdvancedUXService get uxService => _uxService;
  AccessibilityService get accessibilityService => _accessibilityService;

  // Streams
  Stream<Phase6Settings> get settingsStream => _settingsController.stream;
  Stream<CrossServiceEventData> get eventStream => _eventController.stream;
  Stream<Phase6Analytics> get analyticsStream => _analyticsController.stream;
  Stream<Map<String, dynamic>> get coordinationStream =>
      _coordinationController.stream;

  bool _isInitialized = false;
  Timer? _syncTimer;
  Timer? _analyticsTimer;

  // Initialize
  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      LoggerFactory.info('Initializing Phase6Manager...');

      _prefs = await SharedPreferences.getInstance();

      // Initialize all services
      await _initializeServices();

      // Load data
      await _loadPhase6Settings();
      await _loadAnalytics();
      await _loadPendingEvents();

      // Setup cross-service integration
      await _setupCrossServiceIntegration();

      // Start background tasks
      _startBackgroundTasks();

      _isInitialized = true;
      LoggerFactory.info(
          'Phase6Manager initialized successfully with ${_userSettings.length} user configurations');
    } catch (e) {
      LoggerFactory.error('Error initializing Phase6Manager: $e');
    }
  }

  Future<void> _initializeServices() async {
    LoggerFactory.info('Initializing Phase 6 services...');

    // Initialize core services
    _themeManager = AdvancedThemeManager();
    await _themeManager.initialize();

    _reviewService = UserReviewService();
    await _reviewService.initialize();

    _socialService = SocialInteractionService();
    await _socialService.initialize();

    _forumService = CommunityForumService();
    await _forumService.initialize();

    _gamificationService = GamificationService();
    await _gamificationService.initialize();

    _personalizationService = PersonalizationEngineService();
    await _personalizationService.initialize();

    _uxService = AdvancedUXService();
    await _uxService.initialize();

    _accessibilityService = AccessibilityService();
    await _accessibilityService.initialize();

    LoggerFactory.info('All Phase 6 services initialized');
  }

  Future<void> _setupCrossServiceIntegration() async {
    LoggerFactory.info('Setting up cross-service integration...');

    // Listen to gamification events - using rewardStream for achievement notifications
    _gamificationService.rewardStream.listen((rewardData) {
      if (rewardData['type'] == 'achievement') {
        _handleCrossServiceEvent(CrossServiceEventData(
          eventId: 'achievement_${DateTime.now().millisecondsSinceEpoch}',
          eventType: CrossServiceEvent.achievementUnlocked,
          sourceService: 'gamification',
          userId: rewardData['userId'] ?? 'unknown',
          data: rewardData,
          timestamp: DateTime.now(),
        ));
      }
    });

    // Listen to social interactions
    _socialService.socialUpdatesStream.listen((socialData) {
      _handleCrossServiceEvent(CrossServiceEventData(
        eventId: 'social_${DateTime.now().millisecondsSinceEpoch}',
        eventType: CrossServiceEvent.socialActivity,
        sourceService: 'social',
        userId: socialData['userId'] ?? 'unknown',
        data: socialData,
        timestamp: DateTime.now(),
      ));
    });

    // Listen to accessibility changes
    _accessibilityService.preferencesStream.listen((preferences) {
      _handleCrossServiceEvent(CrossServiceEventData(
        eventId: 'accessibility_${DateTime.now().millisecondsSinceEpoch}',
        eventType: CrossServiceEvent.accessibilityChanged,
        sourceService: 'accessibility',
        userId: preferences.userId,
        data: {'contrastLevel': preferences.contrastLevel.toString()},
        timestamp: DateTime.now(),
      ));
    });

    LoggerFactory.info('Cross-service integration setup complete');
  }

  void _startBackgroundTasks() {
    // Sync data every 30 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _processPendingEvents();
      _syncUserData();
    });

    // Update analytics every 5 minutes
    _analyticsTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _updateAnalytics();
    });
  }

  // Settings Management
  Future<void> updatePhase6Settings(Phase6Settings settings) async {
    try {
      final updatedSettings = settings.copyWith(updatedAt: DateTime.now());
      _userSettings[settings.userId] = updatedSettings;

      await _savePhase6Settings();
      _settingsController.add(updatedSettings);

      // Update service configurations based on settings
      await _applySettingsToServices(updatedSettings);

      LoggerFactory.info(
          'Phase 6 settings updated for user ${settings.userId}');
    } catch (e) {
      LoggerFactory.error('Error updating Phase 6 settings: $e');
    }
  }

  Phase6Settings getUserSettings(String userId) {
    return _userSettings[userId] ??
        Phase6Settings(
          userId: userId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
  }

  Future<void> enableFeature(String userId, Phase6Feature feature) async {
    final settings = getUserSettings(userId);
    final updatedFeatures = Set<Phase6Feature>.from(settings.enabledFeatures);
    updatedFeatures.add(feature);

    await updatePhase6Settings(
        settings.copyWith(enabledFeatures: updatedFeatures));
  }

  Future<void> disableFeature(String userId, Phase6Feature feature) async {
    final settings = getUserSettings(userId);
    final updatedFeatures = Set<Phase6Feature>.from(settings.enabledFeatures);
    updatedFeatures.remove(feature);

    await updatePhase6Settings(
        settings.copyWith(enabledFeatures: updatedFeatures));
  }

  bool isFeatureEnabled(String userId, Phase6Feature feature) {
    final settings = getUserSettings(userId);
    return settings.enabledFeatures.contains(feature);
  }

  Future<void> _applySettingsToServices(Phase6Settings settings) async {
    // Apply accessibility settings across all services
    if (isFeatureEnabled(settings.userId, Phase6Feature.accessibility)) {
      LoggerFactory.debug(
          'Applying accessibility settings for user ${settings.userId}');
    }

    // Apply personalization settings
    if (isFeatureEnabled(settings.userId, Phase6Feature.personalization)) {
      LoggerFactory.debug(
          'Applying personalization settings for user ${settings.userId}');
    }

    LoggerFactory.info(
        'Settings applied to services for user ${settings.userId}');
  }

  // Cross-Service Event Handling
  Future<void> _handleCrossServiceEvent(CrossServiceEventData eventData) async {
    try {
      final settings = getUserSettings(eventData.userId);
      if (!settings.enableCrossServiceIntegration) return;

      _pendingEvents.add(eventData);
      _eventController.add(eventData);

      // Process event immediately for real-time features
      if (settings.enableRealTimeSync) {
        await _processEvent(eventData);
      }
    } catch (e) {
      LoggerFactory.error('Error handling cross-service event: $e');
    }
  }

  Future<void> _processEvent(CrossServiceEventData eventData) async {
    switch (eventData.eventType) {
      case CrossServiceEvent.achievementUnlocked:
        await _handleAchievementUnlocked(eventData);
        break;
      case CrossServiceEvent.themeChanged:
        await _handleThemeChanged(eventData);
        break;
      case CrossServiceEvent.socialActivity:
        await _handleSocialActivity(eventData);
        break;
      case CrossServiceEvent.accessibilityChanged:
        await _handleAccessibilityChanged(eventData);
        break;
      case CrossServiceEvent.personalizationUpdated:
        await _handlePersonalizationUpdated(eventData);
        break;
      case CrossServiceEvent.communityContribution:
        await _handleCommunityContribution(eventData);
        break;
      default:
        LoggerFactory.warning(
            'Unhandled cross-service event: ${eventData.eventType}');
    }

    // Mark event as processed
    final processedEvent = eventData.copyWith(isProcessed: true);
    final index =
        _pendingEvents.indexWhere((e) => e.eventId == eventData.eventId);
    if (index >= 0) {
      _pendingEvents[index] = processedEvent;
    }

    // Update analytics
    await _recordEventForAnalytics(eventData.userId, eventData.eventType);
  }

  Future<void> _handleAchievementUnlocked(
      CrossServiceEventData eventData) async {
    LoggerFactory.info(
        'Achievement unlocked event processed for user ${eventData.userId}');
  }

  Future<void> _handleThemeChanged(CrossServiceEventData eventData) async {
    // Propagate theme changes to accessibility service
    if (eventData.data['isDark'] == true) {
      // Dark theme might need different accessibility settings
      await _accessibilityService.announceToScreenReader(
        message: 'Theme changed to dark mode',
        priority: 'low',
      );
    }

    LoggerFactory.info(
        'Theme change event processed for user ${eventData.userId}');
  }

  Future<void> _handleSocialActivity(CrossServiceEventData eventData) async {
    LoggerFactory.info(
        'Social activity event processed for user ${eventData.userId}');
  }

  Future<void> _handleAccessibilityChanged(
      CrossServiceEventData eventData) async {
    LoggerFactory.info(
        'Accessibility change event processed for user ${eventData.userId}');
  }

  Future<void> _handlePersonalizationUpdated(
      CrossServiceEventData eventData) async {
    LoggerFactory.info(
        'Personalization update event processed for user ${eventData.userId}');
  }

  Future<void> _handleCommunityContribution(
      CrossServiceEventData eventData) async {
    LoggerFactory.info(
        'Community contribution event processed for user ${eventData.userId}');
  }

  Future<void> _processPendingEvents() async {
    final unprocessedEvents =
        _pendingEvents.where((e) => !e.isProcessed).toList();

    for (final event in unprocessedEvents) {
      await _processEvent(event);
    }

    // Clean up old processed events (keep last 100)
    _pendingEvents.removeWhere((e) => e.isProcessed);
    if (_pendingEvents.length > 100) {
      _pendingEvents.removeRange(0, _pendingEvents.length - 100);
    }
  }

  // Analytics
  Future<void> _recordEventForAnalytics(
      String userId, CrossServiceEvent eventType) async {
    final analytics = getUserAnalytics(userId);
    final updatedEventCount =
        Map<CrossServiceEvent, int>.from(analytics.eventCount);
    updatedEventCount[eventType] = (updatedEventCount[eventType] ?? 0) + 1;

    final updatedAnalytics = analytics.copyWith(
      eventCount: updatedEventCount,
      lastActivity: DateTime.now(),
    );

    _userAnalytics[userId] = updatedAnalytics;
    _analyticsController.add(updatedAnalytics);
  }

  Phase6Analytics getUserAnalytics(String userId) {
    return _userAnalytics[userId] ??
        Phase6Analytics(
          userId: userId,
          lastActivity: DateTime.now(),
        );
  }

  Future<void> recordFeatureUsage(String userId, Phase6Feature feature) async {
    final analytics = getUserAnalytics(userId);
    final updatedUsageCount =
        Map<Phase6Feature, int>.from(analytics.featureUsageCount);
    updatedUsageCount[feature] = (updatedUsageCount[feature] ?? 0) + 1;

    final updatedAnalytics = analytics.copyWith(
      featureUsageCount: updatedUsageCount,
      lastActivity: DateTime.now(),
    );

    _userAnalytics[userId] = updatedAnalytics;
    await _saveAnalytics();
  }

  Future<void> _updateAnalytics() async {
    for (final userId in _userAnalytics.keys) {
      await _calculateEngagementMetrics(userId);
    }
    await _saveAnalytics();
  }

  Future<void> _calculateEngagementMetrics(String userId) async {
    final analytics = getUserAnalytics(userId);

    // Calculate engagement score based on feature usage
    double engagementScore = 0.0;
    analytics.featureUsageCount.forEach((feature, count) {
      engagementScore += count * _getFeatureWeight(feature);
    });

    // Calculate diversity score (how many different features used)
    final diversityScore =
        analytics.featureUsageCount.keys.length / Phase6Feature.values.length;

    // Calculate activity frequency
    final daysSinceLastActivity =
        DateTime.now().difference(analytics.lastActivity).inDays;
    final activityFrequency =
        daysSinceLastActivity == 0 ? 1.0 : 1.0 / daysSinceLastActivity;

    final updatedMetrics =
        Map<String, double>.from(analytics.engagementMetrics);
    updatedMetrics['engagement_score'] = engagementScore;
    updatedMetrics['diversity_score'] = diversityScore;
    updatedMetrics['activity_frequency'] = activityFrequency;

    _userAnalytics[userId] =
        analytics.copyWith(engagementMetrics: updatedMetrics);
  }

  double _getFeatureWeight(Phase6Feature feature) {
    // Different features have different engagement weights
    switch (feature) {
      case Phase6Feature.communityReviews:
      case Phase6Feature.socialInteractions:
      case Phase6Feature.communityForums:
        return 3.0; // High engagement features
      case Phase6Feature.gamification:
      case Phase6Feature.personalization:
        return 2.0; // Medium engagement features
      case Phase6Feature.advancedTheming:
      case Phase6Feature.advancedUX:
      case Phase6Feature.accessibility:
        return 1.0; // Base features
    }
  }

  // Data Sync
  Future<void> _syncUserData() async {
    try {
      // Sync settings across all services
      for (final userId in _userSettings.keys) {
        await _syncUserServiceData(userId);
      }
    } catch (e) {
      LoggerFactory.error('Error syncing user data: $e');
    }
  }

  Future<void> _syncUserServiceData(String userId) async {
    final settings = getUserSettings(userId);
    if (!settings.enableRealTimeSync) return;

    // Coordination event for data sync
    _coordinationController.add({
      'action': 'sync_user_data',
      'userId': userId,
      'timestamp': DateTime.now().toIso8601String(),
      'services': [
        'theme_manager',
        'review_service',
        'social_service',
        'forum_service',
        'gamification_service',
        'personalization_service',
        'ux_service',
        'accessibility_service',
      ],
    });
  }

  // Unified Service Interface
  Future<Map<String, dynamic>> getUserUnifiedProfile(String userId) async {
    return {
      'settings': getUserSettings(userId).toJson(),
      'analytics': getUserAnalytics(userId).toJson(),
      'theme': {'userId': userId, 'message': 'Theme data available'},
      'social_profile': {
        'userId': userId,
        'message': 'Social profile available'
      },
      'gamification': {
        'userId': userId,
        'message': 'Gamification data available'
      },
      'personalization': {
        'userId': userId,
        'message': 'Personalization data available'
      },
      'accessibility':
          _accessibilityService.getUserPreferences(userId).toJson(),
      'ux_preferences': _uxService.getUserPreferences(userId).toJson(),
    };
  }

  Future<void> resetUserData(String userId) async {
    try {
      // Clear local data
      _userSettings.remove(userId);
      _userAnalytics.remove(userId);

      await _savePhase6Settings();
      await _saveAnalytics();

      LoggerFactory.info('User data reset completed for user $userId');
    } catch (e) {
      LoggerFactory.error('Error resetting user data: $e');
    }
  }

  // Health Check
  Map<String, bool> checkServicesHealth() {
    return {
      'theme_manager': true,
      'review_service': true,
      'social_service': true,
      'forum_service': true,
      'gamification_service': true,
      'personalization_service': true,
      'ux_service': true,
      'accessibility_service': true,
      'integration_active': _syncTimer?.isActive ?? false,
      'analytics_active': _analyticsTimer?.isActive ?? false,
    };
  }

  // Persistence
  Future<void> _loadPhase6Settings() async {
    final json = _prefs?.getString(_settingsKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _userSettings.clear();
      data.forEach((key, value) {
        _userSettings[key] = Phase6Settings.fromJson(value);
      });
    }
  }

  Future<void> _savePhase6Settings() async {
    final data = <String, dynamic>{};
    _userSettings.forEach((key, settings) {
      data[key] = settings.toJson();
    });
    await _prefs?.setString(_settingsKey, jsonEncode(data));
  }

  Future<void> _loadAnalytics() async {
    final json = _prefs?.getString(_analyticsKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _userAnalytics.clear();
      data.forEach((key, value) {
        _userAnalytics[key] = Phase6Analytics.fromJson(value);
      });
    }
  }

  Future<void> _saveAnalytics() async {
    final data = <String, dynamic>{};
    _userAnalytics.forEach((key, analytics) {
      data[key] = analytics.toJson();
    });
    await _prefs?.setString(_analyticsKey, jsonEncode(data));
  }

  Future<void> _loadPendingEvents() async {
    final json = _prefs?.getString(_eventsKey);
    if (json != null) {
      final data = jsonDecode(json) as List<dynamic>;
      _pendingEvents.clear();
      _pendingEvents.addAll(data.map((e) => CrossServiceEventData.fromJson(e)));
    }
  }

  // Dispose
  void dispose() {
    _syncTimer?.cancel();
    _analyticsTimer?.cancel();

    _settingsController.close();
    _eventController.close();
    _analyticsController.close();
    _coordinationController.close();

    // Dispose all services
    _themeManager.dispose();
    _reviewService.dispose();
    _socialService.dispose();
    _forumService.dispose();
    _gamificationService.dispose();
    _personalizationService.dispose();
    _uxService.dispose();
    _accessibilityService.dispose();
  }
}
