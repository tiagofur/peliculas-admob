import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/streaming_platform.dart';
import '../../domain/entities/user_subscription.dart';
import '../analytics/analytics_service.dart';
import '../logging/logger_factory.dart';

/// Service for managing user streaming subscriptions
class SubscriptionManager {
  factory SubscriptionManager() => _instance;
  SubscriptionManager._internal();

  static final SubscriptionManager _instance = SubscriptionManager._internal();

  final _logger = LoggerFactory.getLogger('SubscriptionManager');
  final AnalyticsService _analytics = AnalyticsService.instance;

  static const String _subscriptionsKey = 'user_subscriptions';
  static const String _preferencesKey = 'subscription_preferences';

  List<UserSubscription> _subscriptions = [];
  SubscriptionPreferences _preferences = const SubscriptionPreferences();
  bool _isInitialized = false;

  /// Initialize the subscription manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadSubscriptions();
      await _loadPreferences();
      _isInitialized = true;
      _logger.info(
          'SubscriptionManager initialized with ${_subscriptions.length} subscriptions');
    } catch (e) {
      _logger.error('Failed to initialize SubscriptionManager: $e');
      rethrow;
    }
  }

  /// Get all user subscriptions
  List<UserSubscription> get subscriptions => List.unmodifiable(_subscriptions);

  /// Get active subscriptions only
  List<UserSubscription> get activeSubscriptions =>
      _subscriptions.where((s) => s.isActive).toList();

  /// Get subscription preferences
  SubscriptionPreferences get preferences => _preferences;

  /// Check if user has subscription to a platform
  bool hasSubscription(String platformId) {
    return _subscriptions.any((s) => s.platformId == platformId && s.isActive);
  }

  /// Get subscription for a specific platform
  UserSubscription? getSubscription(String platformId) {
    try {
      return _subscriptions.firstWhere(
        (s) => s.platformId == platformId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Add a new subscription
  Future<void> addSubscription(UserSubscription subscription) async {
    try {
      // Remove existing subscription for the same platform
      _subscriptions
          .removeWhere((s) => s.platformId == subscription.platformId);

      // Add new subscription
      _subscriptions.add(subscription);

      await _saveSubscriptions();

      _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'platform_id': subscription.platformId,
        'subscription_type': subscription.type.name,
        'monthly_cost': subscription.monthlyCost,
      });

      _logger.info('Added subscription for ${subscription.platformId}');
    } catch (e) {
      _logger.error('Failed to add subscription: $e');
      rethrow;
    }
  }

  /// Update an existing subscription
  Future<void> updateSubscription(UserSubscription subscription) async {
    try {
      final index = _subscriptions.indexWhere(
        (s) => s.platformId == subscription.platformId,
      );

      if (index != -1) {
        _subscriptions[index] = subscription;
        await _saveSubscriptions();

        _analytics.trackEvent(AnalyticsEventType.userEngagement, {
          'platform_id': subscription.platformId,
          'subscription_type': subscription.type.name,
          'is_active': subscription.isActive,
        });

        _logger.info('Updated subscription for ${subscription.platformId}');
      } else {
        throw Exception(
            'Subscription not found for platform: ${subscription.platformId}');
      }
    } catch (e) {
      _logger.error('Failed to update subscription: $e');
      rethrow;
    }
  }

  /// Remove a subscription
  Future<void> removeSubscription(String platformId) async {
    try {
      final initialLength = _subscriptions.length;
      _subscriptions.removeWhere((s) => s.platformId == platformId);
      final removed = initialLength - _subscriptions.length;

      if (removed > 0) {
        await _saveSubscriptions();

        _analytics.trackEvent(AnalyticsEventType.userEngagement, {
          'platform_id': platformId,
        });

        _logger.info('Removed subscription for $platformId');
      }
    } catch (e) {
      _logger.error('Failed to remove subscription: $e');
      rethrow;
    }
  }

  /// Toggle subscription status
  Future<void> toggleSubscription(String platformId) async {
    try {
      final subscription = getSubscription(platformId);
      if (subscription != null) {
        final updated = subscription.copyWith(isActive: !subscription.isActive);
        await updateSubscription(updated);
      }
    } catch (e) {
      _logger.error('Failed to toggle subscription: $e');
      rethrow;
    }
  }

  /// Update subscription preferences
  Future<void> updatePreferences(SubscriptionPreferences preferences) async {
    try {
      _preferences = preferences;
      await _savePreferences();

      _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'show_free_only': preferences.showFreeOnly,
        'hide_unavailable': preferences.hideUnavailable,
        'preferred_platforms_count': preferences.preferredPlatforms.length,
      });

      _logger.info('Updated subscription preferences');
    } catch (e) {
      _logger.error('Failed to update preferences: $e');
      rethrow;
    }
  }

  /// Get total monthly cost of all active subscriptions
  double getTotalMonthlyCost() {
    return activeSubscriptions
        .map((s) => s.monthlyCost)
        .fold(0.0, (sum, cost) => sum + cost);
  }

  /// Get subscriptions expiring soon (within specified days)
  List<UserSubscription> getExpiringSoon({int days = 7}) {
    final cutoffDate = DateTime.now().add(Duration(days: days));

    return activeSubscriptions
        .where((s) =>
            s.nextBillingDate != null &&
            s.nextBillingDate!.isBefore(cutoffDate))
        .toList();
  }

  /// Get all subscriptions (alias for subscriptions getter)
  List<UserSubscription> getAllSubscriptions() {
    return subscriptions;
  }

  /// Get subscription statistics (alias for getStats)
  SubscriptionStats getSubscriptionStats() {
    return getStats();
  }

  /// Get subscription statistics
  SubscriptionStats getStats() {
    final active = activeSubscriptions;
    final totalCost = getTotalMonthlyCost();
    final expiringSoon = getExpiringSoon();

    return SubscriptionStats(
      totalSubscriptions: _subscriptions.length,
      activeSubscriptions: active.length,
      totalMonthlyCost: totalCost,
      expiringSoonCount: expiringSoon.length,
      mostExpensiveSubscription: active.isNotEmpty
          ? active.reduce((a, b) => a.monthlyCost > b.monthlyCost ? a : b)
          : null,
      subscriptionsByType: _groupSubscriptionsByType(active),
    );
  }

  /// Filter platforms based on user subscriptions and preferences
  List<StreamingPlatform> filterPlatformsBySubscriptions(
    List<StreamingPlatform> platforms,
  ) {
    if (_preferences.showSubscriptionsOnly) {
      final subscribedPlatformIds =
          activeSubscriptions.map((s) => s.platformId).toSet();

      platforms =
          platforms.where((p) => subscribedPlatformIds.contains(p.id)).toList();
    }

    if (_preferences.preferredPlatforms.isNotEmpty) {
      // Sort by preferred platforms first
      platforms.sort((a, b) {
        final aPreferred = _preferences.preferredPlatforms.contains(a.id);
        final bPreferred = _preferences.preferredPlatforms.contains(b.id);

        if (aPreferred && !bPreferred) return -1;
        if (!aPreferred && bPreferred) return 1;
        return 0;
      });
    }

    return platforms;
  }

  /// Load subscriptions from storage
  Future<void> _loadSubscriptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final subscriptionsJson = prefs.getString(_subscriptionsKey);

      if (subscriptionsJson != null) {
        final List<dynamic> subscriptionsList = json.decode(subscriptionsJson);
        _subscriptions = subscriptionsList
            .map((json) => UserSubscription.fromJson(json))
            .toList();
      }
    } catch (e) {
      _logger.error('Failed to load subscriptions: $e');
      _subscriptions = [];
    }
  }

  /// Save subscriptions to storage
  Future<void> _saveSubscriptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final subscriptionsJson = json.encode(
        _subscriptions.map((s) => s.toJson()).toList(),
      );
      await prefs.setString(_subscriptionsKey, subscriptionsJson);
    } catch (e) {
      _logger.error('Failed to save subscriptions: $e');
      rethrow;
    }
  }

  /// Load preferences from storage
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final preferencesJson = prefs.getString(_preferencesKey);

      if (preferencesJson != null) {
        final Map<String, dynamic> preferencesMap =
            json.decode(preferencesJson);
        _preferences = SubscriptionPreferences.fromJson(preferencesMap);
      }
    } catch (e) {
      _logger.error('Failed to load preferences: $e');
      _preferences = const SubscriptionPreferences();
    }
  }

  /// Save preferences to storage
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final preferencesJson = json.encode(_preferences.toJson());
      await prefs.setString(_preferencesKey, preferencesJson);
    } catch (e) {
      _logger.error('Failed to save preferences: $e');
      rethrow;
    }
  }

  /// Group subscriptions by type
  Map<SubscriptionType, int> _groupSubscriptionsByType(
      List<UserSubscription> subscriptions) {
    final Map<SubscriptionType, int> groups = {};

    for (final subscription in subscriptions) {
      groups[subscription.type] = (groups[subscription.type] ?? 0) + 1;
    }

    return groups;
  }

  /// Clear all data (for testing or reset)
  Future<void> clearAll() async {
    try {
      _subscriptions.clear();
      _preferences = const SubscriptionPreferences();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_subscriptionsKey);
      await prefs.remove(_preferencesKey);

      _logger.info('Cleared all subscription data');
    } catch (e) {
      _logger.error('Failed to clear subscription data: $e');
      rethrow;
    }
  }
}

/// Subscription preferences for filtering and display
class SubscriptionPreferences {
  const SubscriptionPreferences({
    this.showFreeOnly = false,
    this.showSubscriptionsOnly = false,
    this.hideUnavailable = false,
    this.preferredPlatforms = const [],
    this.notifyBeforeExpiry = true,
    this.expiryNotificationDays = 7,
  });

  factory SubscriptionPreferences.fromJson(Map<String, dynamic> json) {
    return SubscriptionPreferences(
      showFreeOnly: json['showFreeOnly'] ?? false,
      showSubscriptionsOnly: json['showSubscriptionsOnly'] ?? false,
      hideUnavailable: json['hideUnavailable'] ?? false,
      preferredPlatforms: List<String>.from(json['preferredPlatforms'] ?? []),
      notifyBeforeExpiry: json['notifyBeforeExpiry'] ?? true,
      expiryNotificationDays: json['expiryNotificationDays'] ?? 7,
    );
  }
  final bool showFreeOnly;
  final bool showSubscriptionsOnly;
  final bool hideUnavailable;
  final List<String> preferredPlatforms;
  final bool notifyBeforeExpiry;
  final int expiryNotificationDays;

  SubscriptionPreferences copyWith({
    bool? showFreeOnly,
    bool? showSubscriptionsOnly,
    bool? hideUnavailable,
    List<String>? preferredPlatforms,
    bool? notifyBeforeExpiry,
    int? expiryNotificationDays,
  }) {
    return SubscriptionPreferences(
      showFreeOnly: showFreeOnly ?? this.showFreeOnly,
      showSubscriptionsOnly:
          showSubscriptionsOnly ?? this.showSubscriptionsOnly,
      hideUnavailable: hideUnavailable ?? this.hideUnavailable,
      preferredPlatforms: preferredPlatforms ?? this.preferredPlatforms,
      notifyBeforeExpiry: notifyBeforeExpiry ?? this.notifyBeforeExpiry,
      expiryNotificationDays:
          expiryNotificationDays ?? this.expiryNotificationDays,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'showFreeOnly': showFreeOnly,
      'showSubscriptionsOnly': showSubscriptionsOnly,
      'hideUnavailable': hideUnavailable,
      'preferredPlatforms': preferredPlatforms,
      'notifyBeforeExpiry': notifyBeforeExpiry,
      'expiryNotificationDays': expiryNotificationDays,
    };
  }
}

/// Statistics about user subscriptions
class SubscriptionStats {
  const SubscriptionStats({
    required this.totalSubscriptions,
    required this.activeSubscriptions,
    required this.totalMonthlyCost,
    required this.expiringSoonCount,
    this.mostExpensiveSubscription,
    required this.subscriptionsByType,
  });
  final int totalSubscriptions;
  final int activeSubscriptions;
  final double totalMonthlyCost;
  final int expiringSoonCount;
  final UserSubscription? mostExpensiveSubscription;
  final Map<SubscriptionType, int> subscriptionsByType;
}
