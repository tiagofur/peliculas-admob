import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../lib/core/notifications/notification_categories.dart';
import '../lib/core/notifications/notification_manager.dart';
import '../lib/core/notifications/notification_metrics.dart';
import '../lib/core/notifications/notification_preferences.dart';
import '../lib/core/notifications/notification_services_initializer.dart';
import '../lib/infrastructure/datasources/watchlist_hive_datasource.dart';
import '../lib/domain/entities/watchlist_movie.dart';

void main() {
  group('Push Notification System Tests', () {
    late WeeklyWatchlistReminderService reminderService;
    late MovieReleaseNotificationService releaseService;
    late NotificationMetricsService metricsService;

    setUp(() {
      reminderService = WeeklyWatchlistReminderService.instance;
      releaseService = MovieReleaseNotificationService.instance;
      metricsService = NotificationMetricsService.instance;
    });

    tearDown(() {
      reminderService.stopWeeklyReminders();
      releaseService.stopReleaseMonitoring();
    });

    group('Weekly Watchlist Reminders', () {
      test('should start weekly reminder service', () {
        expect(() => reminderService.startWeeklyReminders(), returnsNormally);
      });

      test('should stop weekly reminder service', () {
        reminderService.startWeeklyReminders();
        expect(() => reminderService.stopWeeklyReminders(), returnsNormally);
      });

      test('should send manual reminder for testing', () async {
        // This would require mocking the watchlist repository
        expect(() => reminderService.sendManualReminder(), returnsNormally);
      });
    });

    group('Movie Release Notifications', () {
      test('should start release monitoring service', () {
        expect(() => releaseService.startReleaseMonitoring(), returnsNormally);
      });

      test('should stop release monitoring service', () {
        releaseService.startReleaseMonitoring();
        expect(() => releaseService.stopReleaseMonitoring(), returnsNormally);
      });

      test('should clear release history', () {
        expect(() => releaseService.clearReleaseHistory(), returnsNormally);
      });
    });

    group('Notification Types', () {
      test('should include new notification types', () {
        final types = NotificationType.values;
        expect(types, contains(NotificationType.weeklyWatchlistReminder));
        expect(types, contains(NotificationType.movieReleaseNotification));
      });

      test('should have correct default preferences for new types', () {
        final prefs = UserNotificationPreferences.defaultPreferences();
        
        expect(prefs.enabledTypes[NotificationType.weeklyWatchlistReminder], isTrue);
        expect(prefs.enabledTypes[NotificationType.movieReleaseNotification], isTrue);
        
        expect(prefs.frequencies[NotificationType.weeklyWatchlistReminder], 
               equals(NotificationFrequency.weekly));
        expect(prefs.frequencies[NotificationType.movieReleaseNotification], 
               equals(NotificationFrequency.immediate));

        expect(prefs.priorities[NotificationType.weeklyWatchlistReminder], 
               equals(NotificationPriority.normal));
        expect(prefs.priorities[NotificationType.movieReleaseNotification], 
               equals(NotificationPriority.high));
      });
    });

    group('Notification Metrics', () {
      test('should initialize metrics service', () async {
        await expectLater(metricsService.initialize(), completes);
      });

      test('should record notification sent', () async {
        await metricsService.initialize();
        
        await expectLater(
          metricsService.recordNotificationSent(
            notificationId: 'test-123',
            type: NotificationType.weeklyWatchlistReminder,
            scheduledFor: DateTime.now(),
          ),
          completes,
        );
      });

      test('should record notification delivered', () async {
        await metricsService.initialize();
        
        await metricsService.recordNotificationSent(
          notificationId: 'test-delivery',
          type: NotificationType.movieReleaseNotification,
          scheduledFor: DateTime.now(),
        );

        await expectLater(
          metricsService.recordNotificationDelivered(
            notificationId: 'test-delivery',
          ),
          completes,
        );
      });

      test('should calculate delivery rate', () {
        final stats = metricsService.getStats();
        expect(stats.deliveryRate, isA<double>());
        expect(stats.deliveryRate, greaterThanOrEqualTo(0.0));
        expect(stats.deliveryRate, lessThanOrEqualTo(1.0));
      });

      test('should check health status', () {
        expect(metricsService.isDeliveryRateHealthy, isA<bool>());
        expect(metricsService.isLatencyHealthy, isA<bool>());
      });

      test('should generate health report', () {
        final report = metricsService.getHealthReport();
        expect(report, isA<Map<String, dynamic>>());
        expect(report, containsPair('deliveryRateHealthy', isA<bool>()));
        expect(report, containsPair('latencyHealthy', isA<bool>()));
        expect(report, containsPair('last24Hours', isA<Map<String, dynamic>>()));
        expect(report, containsPair('lastWeek', isA<Map<String, dynamic>>()));
      });

      test('should clear all metrics', () async {
        await metricsService.initialize();
        await expectLater(metricsService.clearAllMetrics(), completes);
      });
    });

    group('Service Integration', () {
      test('should initialize services standalone', () async {
        final initializer = NotificationServicesInitializer.instance;
        
        await expectLater(
          initializer.initializeStandalone(),
          completes,
        );
        
        expect(initializer.isHealthy, isA<bool>());
        
        // Cleanup
        initializer.stopAllServices();
      });

      test('should provide services status', () {
        final initializer = NotificationServicesInitializer.instance;
        final status = initializer.getServicesStatus();
        
        expect(status, isA<Map<String, dynamic>>());
        expect(status, containsPair('initialized', isA<bool>()));
        expect(status, containsPair('notificationManagerInitialized', isA<bool>()));
      });

      test('should handle watchlist datasource configuration', () {
        final reminderService = WeeklyWatchlistReminderService.instance;
        final releaseService = MovieReleaseNotificationService.instance;
        final datasource = WatchlistHiveDatasource();
        
        expect(() => reminderService.setWatchlistDatasource(datasource), returnsNormally);
        expect(() => releaseService.setWatchlistDatasource(datasource), returnsNormally);
      });
    });

    group('Notification Coordinator', () {
      test('should include new services in coordinator', () {
        final coordinator = NotificationCategoriesCoordinator.instance;
        
        expect(coordinator.weeklyWatchlistReminderService, isNotNull);
        expect(coordinator.movieReleaseService, isNotNull);
      });

      test('should start all services including new ones', () async {
        final coordinator = NotificationCategoriesCoordinator.instance;
        
        await expectLater(
          coordinator.startAllServices(),
          completes,
        );
        
        // Clean up
        coordinator.stopAllServices();
      });
    });
  });
}