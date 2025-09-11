import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../analytics/analytics_service.dart';
import '../services/logger_factory.dart';
import 'challenge_system.dart';
import 'models/challenge_enums.dart';

/// Types of challenge notifications
enum ChallengeNotificationType {
  newChallenge,
  progressUpdate,
  challengeCompleted,
  challengeExpiring,
  weeklyDigest,
  monthlyDigest,
}

/// Challenge notification data
class ChallengeNotification {
  const ChallengeNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.challenge,
    required this.createdAt,
    this.isRead = false,
    this.data = const {},
    this.rewardPoints,
    this.badgeEarned,
  });

  factory ChallengeNotification.fromJson(Map<String, dynamic> json) {
    return ChallengeNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: ChallengeNotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ChallengeNotificationType.newChallenge,
      ),
      challenge: json['challenge'] != null
          ? Challenge.fromJson(json['challenge'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
      data: json['data'] as Map<String, dynamic>? ?? {},
      rewardPoints: json['rewardPoints'] as int?,
      badgeEarned: json['badgeEarned'] as String?,
    );
  }
  final String id;
  final String title;
  final String message;
  final ChallengeNotificationType type;
  final Challenge? challenge;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic> data;
  final int? rewardPoints;
  final String? badgeEarned;

  /// Getter for timestamp (alias for createdAt)
  DateTime get timestamp => createdAt;

  ChallengeNotification copyWith({
    String? id,
    String? title,
    String? message,
    ChallengeNotificationType? type,
    Challenge? challenge,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? data,
    int? rewardPoints,
    String? badgeEarned,
  }) {
    return ChallengeNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      challenge: challenge ?? this.challenge,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      badgeEarned: badgeEarned ?? this.badgeEarned,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.name,
      'challenge': challenge?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'data': data,
      'rewardPoints': rewardPoints,
      'badgeEarned': badgeEarned,
    };
  }
}

/// Challenge notification service
class ChallengeNotificationService extends ChangeNotifier {
  factory ChallengeNotificationService() => _instance;
  ChallengeNotificationService._internal();
  static final ChallengeNotificationService _instance =
      ChallengeNotificationService._internal();
  static ChallengeNotificationService get instance => _instance;

  final List<ChallengeNotification> _notifications = [];
  final AnalyticsService _analytics = AnalyticsService();
  Timer? _expirationTimer;
  bool _isInitialized = false;

  /// Get all notifications
  List<ChallengeNotification> get notifications =>
      List.unmodifiable(_notifications);

  /// Get unread notifications
  List<ChallengeNotification> get unreadNotifications {
    return _notifications.where((n) => !n.isRead).toList();
  }

  /// Get unread notification count
  int get unreadCount => unreadNotifications.length;

  /// Initialize the notification service
  void initialize() {
    if (_isInitialized) return;

    _startExpirationTimer();
    _isInitialized = true;

    LoggerFactory.info('ChallengeNotificationService initialized');
  }

  /// Start timer to check for expiring challenges
  void _startExpirationTimer() {
    _expirationTimer?.cancel();
    _expirationTimer = Timer.periodic(
      const Duration(hours: 1), // Check every hour
      (_) => _checkExpiringChallenges(),
    );
  }

  /// Check for challenges that are about to expire
  void _checkExpiringChallenges() {
    final challengeSystem = ChallengeSystem();

    for (final challenge in challengeSystem.activeChallenges) {
      if (challenge.isCompleted || challenge.isExpired) continue;

      final timeRemaining = challenge.timeRemaining;

      // Notify if challenge expires in 24 hours
      if (timeRemaining.inHours <= 24 && timeRemaining.inHours > 0) {
        _sendChallengeExpiringNotification(challenge);
      }
    }
  }

  /// Send notification for new challenge
  void sendNewChallengeNotification(Challenge challenge) {
    final notification = ChallengeNotification(
      id: _generateNotificationId(),
      title: 'New Challenge Available!',
      message:
          'Take on the "${challenge.title}" challenge and earn ${challenge.rewardPoints} points!',
      type: ChallengeNotificationType.newChallenge,
      challenge: challenge,
      createdAt: DateTime.now(),
    );

    _addNotification(notification);
    _triggerHapticFeedback();

    _analytics.trackEvent(AnalyticsEventType.userEngagement, {
      'type': 'new_challenge',
      'challenge_id': challenge.id,
      'challenge_type': challenge.type.name,
    });

    LoggerFactory.info('New challenge notification sent: ${challenge.title}');
  }

  /// Send notification for challenge progress update
  void sendProgressUpdateNotification(Challenge challenge) {
    // Only send progress notifications for significant milestones
    final progressPercentage = challenge.progressPercentage;
    final milestones = [0.25, 0.5, 0.75];

    bool shouldNotify = false;
    String milestoneText = '';

    for (final milestone in milestones) {
      if (progressPercentage >= milestone &&
          progressPercentage < milestone + 0.1) {
        shouldNotify = true;
        milestoneText = '${(milestone * 100).round()}%';
        break;
      }
    }

    if (!shouldNotify) return;

    final notification = ChallengeNotification(
      id: _generateNotificationId(),
      title: 'Challenge Progress!',
      message:
          'You\'re $milestoneText through "${challenge.title}"! Keep going!',
      type: ChallengeNotificationType.progressUpdate,
      challenge: challenge,
      createdAt: DateTime.now(),
      data: {'progress_percentage': progressPercentage},
    );

    _addNotification(notification);

    _analytics.trackEvent(AnalyticsEventType.userEngagement, {
      'type': 'progress_update',
      'challenge_id': challenge.id,
      'progress_percentage': progressPercentage,
    });

    LoggerFactory.info(
        'Progress notification sent: ${challenge.title} - $milestoneText');
  }

  /// Send notification for completed challenge
  void sendChallengeCompletedNotification(Challenge challenge) {
    final badgeText = challenge.rewardBadges.isNotEmpty
        ? ' and earned the ${challenge.rewardBadges.join(', ')} badge${challenge.rewardBadges.length > 1 ? 's' : ''}'
        : '';

    final notification = ChallengeNotification(
      id: _generateNotificationId(),
      title: '🎉 Challenge Completed!',
      message:
          'Congratulations! You completed "${challenge.title}" and earned ${challenge.rewardPoints} points$badgeText!',
      type: ChallengeNotificationType.challengeCompleted,
      challenge: challenge,
      createdAt: DateTime.now(),
      data: {
        'reward_points': challenge.rewardPoints,
        'reward_badges': challenge.rewardBadges,
      },
    );

    _addNotification(notification);
    _triggerCelebrationEffects();

    _analytics.trackEvent(AnalyticsEventType.userEngagement, {
      'type': 'challenge_completed',
      'challenge_id': challenge.id,
      'challenge_type': challenge.type.name,
      'reward_points': challenge.rewardPoints,
      'reward_badges': challenge.rewardBadges,
    });

    LoggerFactory.info(
        'Challenge completed notification sent: ${challenge.title}');
  }

  /// Send notification for expiring challenge
  void _sendChallengeExpiringNotification(Challenge challenge) {
    // Check if we already sent an expiring notification for this challenge
    final existingNotification = _notifications.any((n) =>
        n.type == ChallengeNotificationType.challengeExpiring &&
        n.challenge?.id == challenge.id);

    if (existingNotification) return;

    final timeRemaining = challenge.timeRemaining;
    String timeText;

    if (timeRemaining.inHours > 1) {
      timeText = '${timeRemaining.inHours} hours';
    } else {
      timeText = '${timeRemaining.inMinutes} minutes';
    }

    final notification = ChallengeNotification(
      id: _generateNotificationId(),
      title: '⏰ Challenge Expiring Soon!',
      message:
          '"${challenge.title}" expires in $timeText. You\'re ${(challenge.progressPercentage * 100).round()}% complete!',
      type: ChallengeNotificationType.challengeExpiring,
      challenge: challenge,
      createdAt: DateTime.now(),
      data: {
        'time_remaining_hours': timeRemaining.inHours,
        'progress_percentage': challenge.progressPercentage,
      },
    );

    _addNotification(notification);
    _triggerHapticFeedback();

    _analytics.trackEvent(AnalyticsEventType.userEngagement, {
      'type': 'challenge_expiring',
      'challenge_id': challenge.id,
      'time_remaining_hours': timeRemaining.inHours,
    });

    LoggerFactory.info(
        'Challenge expiring notification sent: ${challenge.title}');
  }

  /// Send weekly digest notification
  void sendWeeklyDigest(
      List<Challenge> completedChallenges, List<Challenge> activeChallenges) {
    final totalPoints =
        completedChallenges.fold<int>(0, (sum, c) => sum + c.rewardPoints);
    final totalBadges =
        completedChallenges.expand((c) => c.rewardBadges).length;

    String message;
    if (completedChallenges.isEmpty) {
      message =
          'You have ${activeChallenges.length} active challenges. Time to make some progress!';
    } else {
      message =
          'This week you completed ${completedChallenges.length} challenge${completedChallenges.length != 1 ? 's' : ''}, earned $totalPoints points';
      if (totalBadges > 0) {
        message += ' and $totalBadges badge${totalBadges != 1 ? 's' : ''}';
      }
      message += '!';
    }

    final notification = ChallengeNotification(
      id: _generateNotificationId(),
      title: '📊 Weekly Challenge Summary',
      message: message,
      type: ChallengeNotificationType.weeklyDigest,
      createdAt: DateTime.now(),
      data: {
        'completed_challenges': completedChallenges.length,
        'active_challenges': activeChallenges.length,
        'total_points': totalPoints,
        'total_badges': totalBadges,
      },
    );

    _addNotification(notification);

    _analytics.trackEvent(AnalyticsEventType.userEngagement, {
      'type': 'weekly_digest',
      'completed_challenges': completedChallenges.length,
      'total_points': totalPoints,
    });

    LoggerFactory.info('Weekly digest notification sent');
  }

  /// Send monthly digest notification
  void sendMonthlyDigest(
      List<Challenge> completedChallenges, Map<String, dynamic> stats) {
    final totalPoints =
        completedChallenges.fold<int>(0, (sum, c) => sum + c.rewardPoints);
    final challengeTypes = <ChallengeType, int>{};

    for (final challenge in completedChallenges) {
      challengeTypes[challenge.type] =
          (challengeTypes[challenge.type] ?? 0) + 1;
    }

    final topType = challengeTypes.entries.isNotEmpty
        ? challengeTypes.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : null;

    String message =
        'This month you completed ${completedChallenges.length} challenges and earned $totalPoints points!';
    if (topType != null) {
      message +=
          ' You excelled at ${_getChallengeTypeDisplayName(topType)} challenges.';
    }

    final notification = ChallengeNotification(
      id: _generateNotificationId(),
      title: '🏆 Monthly Challenge Report',
      message: message,
      type: ChallengeNotificationType.monthlyDigest,
      createdAt: DateTime.now(),
      data: {
        'completed_challenges': completedChallenges.length,
        'total_points': totalPoints,
        'challenge_types': challengeTypes.map((k, v) => MapEntry(k.name, v)),
        'top_challenge_type': topType?.name,
        'stats': stats,
      },
    );

    _addNotification(notification);

    _analytics.trackEvent(AnalyticsEventType.userEngagement, {
      'type': 'monthly_digest',
      'completed_challenges': completedChallenges.length,
      'total_points': totalPoints,
    });

    LoggerFactory.info('Monthly digest notification sent');
  }

  /// Add notification to the list
  void _addNotification(ChallengeNotification notification) {
    _notifications.insert(
        0, notification); // Add to beginning for chronological order

    // Keep only the last 50 notifications
    if (_notifications.length > 50) {
      _notifications.removeRange(50, _notifications.length);
    }

    notifyListeners();
  }

  /// Mark notification as read
  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  /// Mark all notifications as read
  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
    notifyListeners();
  }

  /// Remove notification
  void removeNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();
  }

  /// Clear all notifications
  void clearAllNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  /// Trigger haptic feedback for notifications
  void _triggerHapticFeedback() {
    try {
      HapticFeedback.lightImpact();
    } catch (e) {
      // Haptic feedback not available on this platform
      LoggerFactory.debug('Haptic feedback not available: $e');
    }
  }

  /// Trigger celebration effects for completed challenges
  void _triggerCelebrationEffects() {
    try {
      HapticFeedback.heavyImpact();
      // Additional celebration effects could be added here
      // such as confetti animations, sound effects, etc.
    } catch (e) {
      LoggerFactory.debug('Celebration effects not available: $e');
    }
  }

  /// Generate unique notification ID
  String _generateNotificationId() {
    return 'notification_${DateTime.now().millisecondsSinceEpoch}_${_notifications.length}';
  }

  /// Get display name for challenge type
  String _getChallengeTypeDisplayName(ChallengeType type) {
    switch (type) {
      case ChallengeType.genreExplorer:
        return 'Genre Explorer';
      case ChallengeType.marathonWeekend:
        return 'Marathon Weekend';
      case ChallengeType.socialSharer:
        return 'Social Sharer';
      case ChallengeType.reviewMaster:
        return 'Review Master';
      case ChallengeType.discoveryQuest:
        return 'Discovery Quest';
    }
  }

  /// Get notifications by type
  List<ChallengeNotification> getNotificationsByType(
      ChallengeNotificationType type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  /// Get notifications for a specific challenge
  List<ChallengeNotification> getNotificationsForChallenge(String challengeId) {
    return _notifications.where((n) => n.challenge?.id == challengeId).toList();
  }

  /// Get recent notifications (last 24 hours)
  List<ChallengeNotification> getRecentNotifications() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _notifications.where((n) => n.createdAt.isAfter(yesterday)).toList();
  }

  /// Dispose of the service
  @override
  void dispose() {
    _expirationTimer?.cancel();
    super.dispose();
  }
}
