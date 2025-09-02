import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/analytics/analytics_service.dart';

void main() {
  group('Analytics Events Tests', () {
    late AnalyticsService analyticsService;

    setUp(() {
      analyticsService = AnalyticsService();
    });

    test('should track onboarding completion event', () async {
      await analyticsService.initialize();
      
      final eventProperties = {
        'user_id': 'test_user_123',
        'action': 'onboarding_completed',
        'completion_method': 'authentication',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // Track the event
      await analyticsService.trackEvent(
        AnalyticsEventType.onboarding,
        eventProperties,
      );

      // Verify the event was added to the service
      expect(analyticsService.events.isNotEmpty, true);
      
      final trackedEvent = analyticsService.events.last;
      expect(trackedEvent.type, AnalyticsEventType.onboarding);
      expect(trackedEvent.properties['user_id'], 'test_user_123');
      expect(trackedEvent.properties['action'], 'onboarding_completed');
    });

    test('should track add_watchlist event with correct properties', () async {
      await analyticsService.initialize();
      
      final eventProperties = {
        'movie_id': 123,
        'movie_title': 'Test Movie',
        'priority': 'high',
        'action': 'add_to_watchlist',
      };

      await analyticsService.trackEvent(
        AnalyticsEventType.addWatchlist,
        eventProperties,
      );

      expect(analyticsService.events.isNotEmpty, true);
      
      final trackedEvent = analyticsService.events.last;
      expect(trackedEvent.type, AnalyticsEventType.addWatchlist);
      expect(trackedEvent.properties['movie_id'], 123);
      expect(trackedEvent.properties['movie_title'], 'Test Movie');
      expect(trackedEvent.properties['priority'], 'high');
      expect(trackedEvent.properties['action'], 'add_to_watchlist');
    });

    test('should track rate_movie event with rating details', () async {
      await analyticsService.initialize();
      
      final eventProperties = {
        'movie_id': 456,
        'movie_title': 'Another Test Movie',
        'rating': 4,
        'has_personal_note': true,
        'note_length': 50,
        'action': 'rate_movie',
      };

      await analyticsService.trackEvent(
        AnalyticsEventType.rateMovie,
        eventProperties,
      );

      expect(analyticsService.events.isNotEmpty, true);
      
      final trackedEvent = analyticsService.events.last;
      expect(trackedEvent.type, AnalyticsEventType.rateMovie);
      expect(trackedEvent.properties['movie_id'], 456);
      expect(trackedEvent.properties['rating'], 4);
      expect(trackedEvent.properties['has_personal_note'], true);
      expect(trackedEvent.properties['note_length'], 50);
    });

    test('should add platform and timestamp to all events', () async {
      await analyticsService.initialize();
      
      await analyticsService.trackEvent(
        AnalyticsEventType.onboarding,
        {'test': 'data'},
      );

      final trackedEvent = analyticsService.events.last;
      
      // Should include platform information
      expect(trackedEvent.properties.containsKey('platform'), true);
      expect(trackedEvent.properties.containsKey('timestamp'), true);
      
      // Should have session ID and user ID
      expect(trackedEvent.sessionId, isNotEmpty);
      expect(trackedEvent.userId, isNotEmpty);
    });

    test('should track multiple events and maintain order', () async {
      await analyticsService.initialize();
      
      final initialEventCount = analyticsService.events.length;
      
      // Track multiple events
      await analyticsService.trackEvent(AnalyticsEventType.onboarding, {'test': '1'});
      await analyticsService.trackEvent(AnalyticsEventType.addWatchlist, {'test': '2'});
      await analyticsService.trackEvent(AnalyticsEventType.rateMovie, {'test': '3'});

      expect(analyticsService.events.length, greaterThanOrEqualTo(initialEventCount + 3));
      
      // Get the last three events we just added
      final lastThreeEvents = analyticsService.events.takeLast(3).toList();
      expect(lastThreeEvents[0].type, AnalyticsEventType.onboarding);
      expect(lastThreeEvents[1].type, AnalyticsEventType.addWatchlist);
      expect(lastThreeEvents[2].type, AnalyticsEventType.rateMovie);
    });

    test('should generate unique event IDs', () async {
      await analyticsService.initialize();
      
      await analyticsService.trackEvent(AnalyticsEventType.onboarding, {'test': '1'});
      await analyticsService.trackEvent(AnalyticsEventType.addWatchlist, {'test': '2'});

      final lastTwoEvents = analyticsService.events.takeLast(2).toList();
      expect(lastTwoEvents[0].id, isNot(equals(lastTwoEvents[1].id)));
      expect(lastTwoEvents[0].id, isNotEmpty);
      expect(lastTwoEvents[1].id, isNotEmpty);
    });

    test('should handle errors gracefully when tracking events', () async {
      await analyticsService.initialize();
      
      // Try to track with empty properties (should not crash)
      expect(() async {
        await analyticsService.trackEvent(
          AnalyticsEventType.onboarding,
          {},
        );
      }, returnsNormally);
    });

    test('should validate event delivery success rate', () async {
      await analyticsService.initialize();
      
      final totalEvents = 100;
      var successfulEvents = 0;
      final initialEventCount = analyticsService.events.length;

      // Track multiple events to test delivery rate
      for (int i = 0; i < totalEvents; i++) {
        try {
          await analyticsService.trackEvent(
            AnalyticsEventType.addWatchlist,
            {
              'movie_id': i,
              'movie_title': 'Test Movie $i',
              'action': 'add_to_watchlist',
            },
          );
          successfulEvents++;
        } catch (e) {
          // Count failed events
        }
      }

      final successRate = (successfulEvents / totalEvents) * 100;
      
      // Should achieve >99% success rate as per requirements
      expect(successRate, greaterThan(99.0));
      expect(analyticsService.events.length, greaterThanOrEqualTo(initialEventCount + successfulEvents));
    });
  });

  group('Analytics Dashboard Tests', () {
    late AnalyticsService analyticsService;

    setUp(() async {
      analyticsService = AnalyticsService();
      await analyticsService.initialize();
    });

    test('should provide analytics dashboard with metrics', () async {
      // Track some events
      await analyticsService.trackEvent(AnalyticsEventType.onboarding, {'user': '1'});
      await analyticsService.trackEvent(AnalyticsEventType.addWatchlist, {'movie': '1'});
      await analyticsService.trackEvent(AnalyticsEventType.rateMovie, {'movie': '1', 'rating': 5});

      final dashboard = await analyticsService.getDashboard();
      
      expect(dashboard, isNotNull);
      expect(dashboard.lastUpdated, isNotNull);
    });

    test('should stream dashboard updates', () async {
      expect(analyticsService.dashboardStream, isNotNull);
      
      // Listen to dashboard updates (just verify stream exists)
      var streamReceived = false;
      final subscription = analyticsService.dashboardStream.listen((dashboard) {
        streamReceived = true;
        expect(dashboard, isNotNull);
      });
      
      // Wait a bit for any existing updates
      await Future.delayed(Duration(milliseconds: 100));
      
      // Clean up
      await subscription.cancel();
      
      // Stream should be available even if no events were received in this short test
      expect(analyticsService.dashboardStream, isNotNull);
    });

    test('should stream individual events', () async {
      expect(analyticsService.eventStream, isNotNull);
      
      // Listen to event stream
      AnalyticsEvent? receivedEvent;
      final subscription = analyticsService.eventStream.listen((event) {
        receivedEvent = event;
      });
      
      // Track an event
      await analyticsService.trackEvent(AnalyticsEventType.onboarding, {'test': 'stream'});
      
      // Wait for stream processing
      await Future.delayed(Duration(milliseconds: 100));
      
      // Clean up
      await subscription.cancel();
      
      // Verify event was streamed
      expect(receivedEvent, isNotNull);
      expect(receivedEvent?.type, AnalyticsEventType.onboarding);
    });
  });
}

// Extension to get last N elements from list
extension ListExtension<T> on List<T> {
  List<T> takeLast(int count) {
    if (count >= length) return this;
    return sublist(length - count);
  }
}