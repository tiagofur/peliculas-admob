import 'dart:async';

import '../../domain/entities/streaming_platform.dart';
import '../../domain/entities/subscription.dart';
import '../analytics/analytics_service.dart';
import '../cache/cache_service.dart';
import '../logging/app_logger.dart';

/// Service for tracking and managing user subscriptions across streaming platforms
class SubscriptionTracker {
  SubscriptionTracker({
    CacheService? cacheService,
    AnalyticsService? analyticsService,
    AppLogger? logger,
  })  : _cacheService = cacheService ?? CacheService.instance,
        _analyticsService = analyticsService ?? AnalyticsService(),
        _logger = logger ?? AppLogger.instance,
        _eventController = StreamController<SubscriptionEvent>.broadcast();
  final CacheService _cacheService;
  final AnalyticsService _analyticsService;
  final AppLogger _logger;
  final StreamController<SubscriptionEvent> _eventController;

  // Cache duration for subscription data
  static const Duration _cacheDuration = Duration(hours: 1);
  static const String _cacheKeyPrefix = 'subscription_';
  static const String _allSubscriptionsCacheKey = 'all_subscriptions';

  /// Stream of subscription events
  Stream<SubscriptionEvent> get events => _eventController.stream;

  /// Add or update a user subscription
  Future<bool> addSubscription({
    required String userId,
    required StreamingPlatform platform,
    required SubscriptionStatus status,
    required SubscriptionTier tier,
    required DateTime startDate,
    DateTime? endDate,
    DateTime? nextBillingDate,
    required double monthlyPrice,
    required String currency,
    bool autoRenew = true,
    List<String>? features,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _logger.info('Adding subscription for user $userId on ${platform.name}');

      final subscription = Subscription(
        id: _generateSubscriptionId(userId, platform.id),
        userId: userId,
        platform: platform,
        status: status,
        tier: tier,
        startDate: startDate,
        endDate: endDate,
        nextBillingDate: nextBillingDate,
        monthlyPrice: monthlyPrice,
        currency: currency,
        autoRenew: autoRenew,
        features: features ?? [],
        metadata: metadata ?? {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Cache the subscription
      final cacheKey = '$_cacheKeyPrefix${subscription.id}';
      await _cacheService.set(
        cacheKey,
        subscription.toJson(),
        expiration: _cacheDuration,
      );

      // Update user's subscription list
      await _updateUserSubscriptionsList(userId, subscription);

      // Track analytics
      _analyticsService.trackEvent(
        AnalyticsEventType.userEngagement,
        {
          'user_id': userId,
          'platform': platform.id,
          'status': status.name,
          'tier': tier.name,
          'monthly_price': monthlyPrice,
          'currency': currency,
          'auto_renew': autoRenew,
          'action': 'subscription_added',
        },
      );

      // Emit event
      _eventController.add(SubscriptionEvent.added(subscription));

      return true;
    } catch (e) {
      _logger.error('Error adding subscription: $e');
      _analyticsService.trackEvent(
        AnalyticsEventType.error,
        {
          'user_id': userId,
          'platform': platform.id,
          'error': e.toString(),
        },
      );
      return false;
    }
  }

  /// Get user's subscription for a specific platform
  Future<Subscription?> getSubscription({
    required String userId,
    required String platformId,
  }) async {
    try {
      final subscriptionId = _generateSubscriptionId(userId, platformId);
      final cacheKey = '$_cacheKeyPrefix$subscriptionId';

      final cached = await _cacheService.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        return Subscription.fromJson(cached);
      }

      return null;
    } catch (e) {
      _logger.error('Error getting subscription: $e');
      return null;
    }
  }

  /// Get all subscriptions for a user
  Future<List<Subscription>> getUserSubscriptions(String userId) async {
    try {
      final cacheKey = '${_allSubscriptionsCacheKey}_$userId';
      final cached = await _cacheService.get<List<dynamic>>(cacheKey);

      if (cached != null) {
        return cached
            .map((json) => Subscription.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      _logger.error('Error getting user subscriptions: $e');
      return [];
    }
  }

  /// Get active subscriptions for a user
  Future<List<Subscription>> getActiveSubscriptions(String userId) async {
    try {
      final allSubscriptions = await getUserSubscriptions(userId);
      return allSubscriptions.where((sub) => sub.isActive).toList();
    } catch (e) {
      _logger.error('Error getting active subscriptions: $e');
      return [];
    }
  }

  /// Update subscription status
  Future<bool> updateSubscriptionStatus({
    required String userId,
    required String platformId,
    required SubscriptionStatus newStatus,
    DateTime? endDate,
    String? reason,
  }) async {
    try {
      final subscription = await getSubscription(
        userId: userId,
        platformId: platformId,
      );

      if (subscription == null) {
        _logger
            .warning('Subscription not found for update: $userId, $platformId');
        return false;
      }

      final updatedSubscription = subscription.copyWith(
        status: newStatus,
        endDate: endDate,
        updatedAt: DateTime.now(),
      );

      // Update cache
      final cacheKey = '$_cacheKeyPrefix${subscription.id}';
      await _cacheService.set(
        cacheKey,
        updatedSubscription.toJson(),
        expiration: _cacheDuration,
      );

      // Update user's subscription list
      await _updateUserSubscriptionsList(userId, updatedSubscription);

      // Track analytics
      _analyticsService.trackEvent(
        AnalyticsEventType.userEngagement,
        {
          'user_id': userId,
          'platform': platformId,
          'old_status': subscription.status.name,
          'new_status': newStatus.name,
          'reason': reason,
          'action': 'subscription_updated',
        },
      );

      // Emit event
      _eventController.add(SubscriptionEvent.updated(updatedSubscription));

      return true;
    } catch (e) {
      _logger.error('Error updating subscription status: $e');
      return false;
    }
  }

  /// Cancel a subscription
  Future<bool> cancelSubscription({
    required String userId,
    required String platformId,
    String? reason,
    bool immediate = false,
  }) async {
    try {
      final endDate = immediate ? DateTime.now() : null;

      final success = await updateSubscriptionStatus(
        userId: userId,
        platformId: platformId,
        newStatus: SubscriptionStatus.cancelled,
        endDate: endDate,
        reason: reason,
      );

      if (success) {
        _analyticsService.trackEvent(
          AnalyticsEventType.userEngagement,
          {
            'user_id': userId,
            'platform': platformId,
            'immediate': immediate,
            'reason': reason,
            'action': 'subscription_cancelled',
          },
        );
      }

      return success;
    } catch (e) {
      _logger.error('Error cancelling subscription: $e');
      return false;
    }
  }

  /// Reactivate a cancelled subscription
  Future<bool> reactivateSubscription({
    required String userId,
    required String platformId,
    DateTime? newEndDate,
  }) async {
    try {
      return await updateSubscriptionStatus(
        userId: userId,
        platformId: platformId,
        newStatus: SubscriptionStatus.active,
        endDate: newEndDate,
        reason: 'reactivated',
      );
    } catch (e) {
      _logger.error('Error reactivating subscription: $e');
      return false;
    }
  }

  /// Check for expiring subscriptions
  Future<List<Subscription>> getExpiringSubscriptions({
    required String userId,
    Duration warningPeriod = const Duration(days: 7),
  }) async {
    try {
      final subscriptions = await getActiveSubscriptions(userId);
      final now = DateTime.now();
      final warningDate = now.add(warningPeriod);

      return subscriptions.where((sub) {
        if (sub.endDate == null) return false;
        return (sub.endDate?.isBefore(warningDate) ?? false) &&
            (sub.endDate?.isAfter(now) ?? false);
      }).toList();
    } catch (e) {
      _logger.error('Error getting expiring subscriptions: $e');
      return [];
    }
  }

  /// Get subscription summary for a user
  Future<SubscriptionSummary> getSubscriptionSummary(String userId) async {
    try {
      final subscriptions = await getUserSubscriptions(userId);

      final activeSubscriptions =
          subscriptions.where((sub) => sub.isActive).toList();
      final totalMonthlySpend = activeSubscriptions.fold<double>(
          0, (sum, sub) => sum + (sub.monthlyPrice ?? 0.0));

      final platformCounts = <String, int>{};
      for (final sub in activeSubscriptions) {
        platformCounts[sub.platform.id] =
            (platformCounts[sub.platform.id] ?? 0) + 1;
      }

      return SubscriptionSummary(
        userId: userId,
        totalSubscriptions: subscriptions.length,
        activeSubscriptions: activeSubscriptions.length,
        totalMonthlySpend: totalMonthlySpend,
        currency: activeSubscriptions.isNotEmpty
            ? (activeSubscriptions.first.currency ?? 'USD')
            : 'USD',
        platformCounts: platformCounts,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      _logger.error('Error getting subscription summary: $e');
      return SubscriptionSummary(
        userId: userId,
        totalSubscriptions: 0,
        activeSubscriptions: 0,
        totalMonthlySpend: 0,
        currency: 'USD',
        platformCounts: {},
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// Sync subscriptions with external services
  Future<bool> syncSubscriptions(String userId) async {
    try {
      _logger.info('Syncing subscriptions for user: $userId');

      // This would typically call external APIs to verify subscription status
      // For now, we'll simulate the sync process

      final subscriptions = await getUserSubscriptions(userId);
      int syncedCount = 0;

      for (final subscription in subscriptions) {
        try {
          // Simulate external API call to verify subscription
          final isStillActive = await _verifySubscriptionWithProvider(
            subscription.platform.id,
            subscription.id,
          );

          if (!isStillActive && subscription.isActive) {
            await updateSubscriptionStatus(
              userId: userId,
              platformId: subscription.platform.id,
              newStatus: SubscriptionStatus.expired,
              reason: 'sync_verification_failed',
            );
          }

          syncedCount++;
        } catch (e) {
          _logger.warning('Error syncing subscription ${subscription.id}: $e');
        }
      }

      _analyticsService.trackEvent(
        AnalyticsEventType.userEngagement,
        {
          'user_id': userId,
          'total_subscriptions': subscriptions.length,
          'synced_count': syncedCount,
          'action': 'subscriptions_synced',
        },
      );

      return true;
    } catch (e) {
      _logger.error('Error syncing subscriptions: $e');
      return false;
    }
  }

  /// Remove a subscription
  Future<bool> removeSubscription({
    required String userId,
    required String platformId,
  }) async {
    try {
      final subscriptionId = _generateSubscriptionId(userId, platformId);
      final cacheKey = '$_cacheKeyPrefix$subscriptionId';

      // Remove from cache
      await _cacheService.remove(cacheKey);

      // Update user's subscription list
      final userSubscriptions = await getUserSubscriptions(userId);
      final updatedSubscriptions =
          userSubscriptions.where((sub) => sub.id != subscriptionId).toList();

      final userCacheKey = '${_allSubscriptionsCacheKey}_$userId';
      await _cacheService.set(
        userCacheKey,
        updatedSubscriptions.map((sub) => sub.toJson()).toList(),
        expiration: _cacheDuration,
      );

      _analyticsService.trackEvent(
        AnalyticsEventType.userEngagement,
        {
          'user_id': userId,
          'platform': platformId,
          'action': 'subscription_removed',
        },
      );

      return true;
    } catch (e) {
      _logger.error('Error removing subscription: $e');
      return false;
    }
  }

  /// Generate subscription ID
  String _generateSubscriptionId(String userId, String platformId) {
    return '${userId}_$platformId';
  }

  /// Update user's subscriptions list in cache
  Future<void> _updateUserSubscriptionsList(
    String userId,
    Subscription subscription,
  ) async {
    try {
      final userSubscriptions = await getUserSubscriptions(userId);

      // Remove existing subscription for the same platform
      final updatedSubscriptions = userSubscriptions
          .where((sub) => sub.platform.id != subscription.platform.id)
          .toList();

      // Add the new/updated subscription
      updatedSubscriptions.add(subscription);

      // Cache the updated list
      final userCacheKey = '${_allSubscriptionsCacheKey}_$userId';
      await _cacheService.set(
        userCacheKey,
        userSubscriptions.map((sub) => sub.toJson()).toList(),
        expiration: _cacheDuration,
      );
    } catch (e) {
      _logger.error('Error updating user subscriptions list: $e');
    }
  }

  /// Verify subscription with external provider (simulated)
  Future<bool> _verifySubscriptionWithProvider(
    String platformId,
    String subscriptionId,
  ) async {
    // Simulate external API call
    await Future.delayed(const Duration(milliseconds: 500));

    // Simulate 90% success rate
    return DateTime.now().millisecondsSinceEpoch % 10 != 0;
  }

  /// Dispose resources
  void dispose() {
    _eventController.close();
  }
}

/// Subscription events
class SubscriptionEvent {
  const SubscriptionEvent._(
    this.type,
    this.subscription,
    this.timestamp,
  );

  factory SubscriptionEvent.added(Subscription subscription) {
    return SubscriptionEvent._(
      SubscriptionEventType.added,
      subscription,
      DateTime.now(),
    );
  }

  factory SubscriptionEvent.updated(Subscription subscription) {
    return SubscriptionEvent._(
      SubscriptionEventType.updated,
      subscription,
      DateTime.now(),
    );
  }

  factory SubscriptionEvent.cancelled(Subscription subscription) {
    return SubscriptionEvent._(
      SubscriptionEventType.cancelled,
      subscription,
      DateTime.now(),
    );
  }

  factory SubscriptionEvent.expired(Subscription subscription) {
    return SubscriptionEvent._(
      SubscriptionEventType.expired,
      subscription,
      DateTime.now(),
    );
  }
  final SubscriptionEventType type;
  final Subscription subscription;
  final DateTime timestamp;
}

enum SubscriptionEventType {
  added,
  updated,
  cancelled,
  expired,
  reactivated,
}

/// Summary of user's subscription data
class SubscriptionSummary {
  SubscriptionSummary({
    required this.userId,
    required this.totalSubscriptions,
    required this.activeSubscriptions,
    required this.totalMonthlySpend,
    required this.currency,
    required this.platformCounts,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  factory SubscriptionSummary.fromJson(Map<String, dynamic> json) {
    return SubscriptionSummary(
      userId: json['userId'] ?? '',
      totalSubscriptions: json['totalSubscriptions'] ?? 0,
      activeSubscriptions: json['activeSubscriptions'] ?? 0,
      totalMonthlySpend: (json['totalMonthlySpend'] ?? 0.0).toDouble(),
      currency: json['currency'] ?? 'USD',
      platformCounts: Map<String, int>.from(json['platformCounts'] ?? {}),
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
    );
  }
  final String userId;
  final int totalSubscriptions;
  final int activeSubscriptions;
  final double totalMonthlySpend;
  final String currency;
  final Map<String, int> platformCounts;
  final DateTime lastUpdated;

  // Convenience getter for backward compatibility
  double get monthlyTotal => totalMonthlySpend;
  List<StreamingPlatform> get platforms => [];

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'totalSubscriptions': totalSubscriptions,
      'activeSubscriptions': activeSubscriptions,
      'totalMonthlySpend': totalMonthlySpend,
      'currency': currency,
      'platformCounts': platformCounts,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}
