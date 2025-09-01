import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../presentation/providers/challenge_providers.dart';
import 'models/achievement.dart';
import 'models/badge.dart' as gamification_badge;
import 'models/challenge.dart';
import 'models/user_level.dart';

/// Service for handling gamification notifications
class GamificationNotificationService {
  factory GamificationNotificationService() => _instance;
  GamificationNotificationService._internal();
  static final GamificationNotificationService _instance =
      GamificationNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<NotificationEvent> _notificationController =
      StreamController<NotificationEvent>.broadcast();

  Stream<NotificationEvent> get notificationStream =>
      _notificationController.stream;

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  /// Handle notification tap events
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      _notificationController.add(NotificationEvent(
        type: NotificationEventType.tapped,
        payload: payload,
      ));
    }
  }

  /// Show achievement unlocked notification
  Future<void> showAchievementNotification(Achievement achievement) async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'achievements',
      'Achievement Notifications',
      channelDescription: 'Notifications for unlocked achievements',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF6366F1),
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      achievement.id.hashCode,
      '🏆 Achievement Unlocked!',
      '${achievement.name} - ${achievement.description}',
      details,
      payload: 'achievement:${achievement.id}',
    );

    _notificationController.add(NotificationEvent(
      type: NotificationEventType.achievementUnlocked,
      achievement: achievement,
    ));
  }

  /// Show level up notification
  Future<void> showLevelUpNotification(UserLevel level) async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'level_ups',
      'Level Up Notifications',
      channelDescription: 'Notifications for level ups',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF10B981),
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      level.hashCode,
      '🎉 Level Up!',
      'Congratulations! You reached ${level.name}',
      details,
      payload: 'level_up:${level.name}',
    );

    _notificationController.add(NotificationEvent(
      type: NotificationEventType.levelUp,
      level: level,
    ));
  }

  /// Show badge earned notification
  Future<void> showBadgeNotification(gamification_badge.Badge badge) async {
    if (!_isInitialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'badges',
      'Badge Notifications',
      channelDescription: 'Notifications for earned badges',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFF59E0B),
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      badge.id.hashCode,
      '🎖️ Badge Earned!',
      '${badge.title} - ${badge.description}',
      details,
      payload: 'badge:${badge.id}',
    );

    _notificationController.add(NotificationEvent(
      type: NotificationEventType.badgeEarned,
      badge: badge,
    ));
  }

  /// Show challenge completed notification
  Future<void> showChallengeCompletedNotification(Challenge challenge) async {
    if (!_isInitialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'challenges',
      'Challenge Notifications',
      channelDescription: 'Notifications for completed challenges',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF8B5CF6),
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      challenge.id.hashCode,
      '✅ Challenge Complete!',
      '${challenge.title} - Earned ${challenge.pointsReward} points',
      details,
      payload: 'challenge:${challenge.id}',
    );

    _notificationController.add(NotificationEvent(
      type: NotificationEventType.challengeCompleted,
      challenge: challenge,
    ));
  }

  /// Show streak milestone notification
  Future<void> showStreakNotification(int streakDays, int points) async {
    if (!_isInitialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'streaks',
      'Streak Notifications',
      channelDescription: 'Notifications for streak milestones',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFEF4444),
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      streakDays.hashCode,
      '🔥 Streak Milestone!',
      '$streakDays days in a row! Earned $points bonus points',
      details,
      payload: 'streak:$streakDays',
    );

    _notificationController.add(NotificationEvent(
      type: NotificationEventType.streakMilestone,
      streakDays: streakDays,
      points: points,
    ));
  }

  /// Show daily reminder notification
  Future<void> scheduleDailyReminder() async {
    if (!_isInitialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'daily_reminders',
      'Daily Reminders',
      channelDescription: 'Daily reminders to use the app',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF6366F1),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      999, // Fixed ID for daily reminder
      '🎬 Movie Time!',
      'Discover new movies and earn rewards today!',
      _nextInstanceOfTime(20, 0), // 8 PM daily
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,

      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_reminder',
    );
  }

  /// Calculate next instance of a specific time
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Dispose resources
  void dispose() {
    _notificationController.close();
  }
}

/// Notification event types
enum NotificationEventType {
  achievementUnlocked,
  levelUp,
  badgeEarned,
  challengeCompleted,
  streakMilestone,
  tapped,
}

/// Notification event data
class NotificationEvent {
  const NotificationEvent({
    required this.type,
    this.payload,
    this.achievement,
    this.level,
    this.badge,
    this.challenge,
    this.streakDays,
    this.points,
  });
  final NotificationEventType type;
  final String? payload;
  final Achievement? achievement;
  final UserLevel? level;
  final gamification_badge.Badge? badge;
  final Challenge? challenge;
  final int? streakDays;
  final int? points;
}

/// Provider for notification service
final notificationServiceProvider =
    Provider<GamificationNotificationService>((ref) {
  return GamificationNotificationService();
});

/// Provider for notification events stream
final notificationEventsProvider = StreamProvider<NotificationEvent>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.notificationStream;
});

/// Provider to handle automatic notifications based on gamification events
final autoNotificationHandlerProvider = Provider<void>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  final gamificationManager = ref.watch(gamificationManagerProvider);

  // Listen to achievement unlocks
  gamificationManager.achievementStream.listen((achievement) {
    notificationService.showAchievementNotification(achievement);
  });

  // Listen to level ups
  gamificationManager.levelUpStream.listen((level) {
    notificationService.showLevelUpNotification(level);
  });

  // Listen to badge earnings
  gamificationManager.badgeStream.listen((gamification_badge.Badge badge) {
    notificationService.showBadgeNotification(badge);
  });

  // Listen to challenge completions
  gamificationManager.challengeCompletionStream.listen((challenge) {
    notificationService.showChallengeCompletedNotification(challenge);
  });

  return;
});
