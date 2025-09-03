import 'package:flutter/material.dart';
import 'package:peliculas/core/analytics/analytics_service.dart';
import 'package:peliculas/core/logging/app_logger.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/domain/entities/watchlist_movie.dart';

/// Demo script to showcase the analytics events functionality
class AnalyticsEventsDemo {
  static Future<void> demonstrateAnalyticsEvents() async {
    AppLogger.instance.info('🚀 Analytics Events Demo Starting...\n');

    // Initialize analytics service
    final analyticsService = AnalyticsService();
    await analyticsService.initialize();
    AppLogger.instance.info('✅ Analytics service initialized\n');

    // Demo movie for testing
    final testMovie = Movie(
      id: 12345,
      title: 'Inception',
      overview: 'A mind-bending thriller about dreams within dreams.',
      posterPath: '/poster.jpg',
      backdropPath: '/backdrop.jpg',
      releaseDate: DateTime(2010, 7, 16),
      genreIds: ['878', '28', '53'], // Sci-Fi, Action, Thriller
      originalLanguage: 'en',
      originalTitle: 'Inception',
      popularity: 8.8,
      voteAverage: 8.2,
      voteCount: 14000,
      adult: false,
      video: false,
    );

    AppLogger.instance.info('🎬 Demo Movie: ${testMovie.title}\n');

    // 1. Demonstrate Onboarding Completion Event
    AppLogger.instance.info('📋 1. Tracking Onboarding Completion Event...');
    await analyticsService.trackEvent(
      AnalyticsEventType.onboarding,
      {
        'user_id': 'demo_user_123',
        'action': 'onboarding_completed',
        'completion_method': 'authentication',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
    AppLogger.instance.info('   ✅ Onboarding completion event tracked');

    // 2. Demonstrate Add to Watchlist Event
    AppLogger.instance.info('\n📺 2. Tracking Add to Watchlist Event...');
    await analyticsService.trackEvent(
      AnalyticsEventType.addWatchlist,
      {
        'movie_id': testMovie.id,
        'movie_title': testMovie.title,
        'priority': WatchlistPriority.alta.name,
        'action': 'add_to_watchlist',
      },
    );
    AppLogger.instance.info('   ✅ Add to watchlist event tracked');

    // 3. Demonstrate Rate Movie Event
    AppLogger.instance.info('\n⭐ 3. Tracking Rate Movie Event...');
    await analyticsService.trackEvent(
      AnalyticsEventType.rateMovie,
      {
        'movie_id': testMovie.id,
        'movie_title': testMovie.title,
        'rating': 5,
        'has_personal_note': true,
        'note_length': 125,
        'action': 'rate_movie',
      },
    );
    AppLogger.instance.info('   ✅ Rate movie event tracked');

    // Show analytics dashboard
    AppLogger.instance.info('\n📊 4. Analytics Dashboard Summary:');
    final dashboard = await analyticsService.getDashboard();
    AppLogger.instance
        .info('   📈 Dashboard generated at: ${dashboard.lastUpdated}');
    AppLogger.instance
        .info('   📈 User metrics available: ${dashboard.userMetrics}');
    AppLogger.instance
        .info('   📈 Content metrics available: ${dashboard.contentMetrics}');
    AppLogger.instance.info(
        '   📈 Performance metrics available: ${dashboard.performanceMetrics}');

    // Show event summary
    final events = analyticsService.events;
    AppLogger.instance.info('\n📋 5. Event Summary:');
    AppLogger.instance.info('   📊 Total events tracked: ${events.length}');

    if (events.isNotEmpty) {
      final recentEvents = events.takeLast(3);
      AppLogger.instance.info('   🔍 Recent events:');
      for (int i = 0; i < recentEvents.length; i++) {
        final event = recentEvents[i];
        AppLogger.instance.info(
            '      ${i + 1}. ${event.type.name} - ${event.properties['action'] ?? 'unknown action'}');
      }
    }

    // Test success rate
    AppLogger.instance.info('\n🎯 6. Testing Event Delivery Success Rate...');
    const testEvents = 50;
    var successfulEvents = 0;

    for (int i = 0; i < testEvents; i++) {
      try {
        await analyticsService.trackEvent(
          AnalyticsEventType.addWatchlist,
          {
            'movie_id': 1000 + i,
            'movie_title': 'Test Movie $i',
            'action': 'bulk_test',
          },
        );
        successfulEvents++;
      } catch (e) {
        AppLogger.instance.error('   ❌ Failed to track event $i: $e');
      }
    }

    final successRate = (successfulEvents / testEvents) * 100;
    AppLogger.instance.info(
        '   📊 Success Rate: ${successRate.toStringAsFixed(1)}% ($successfulEvents/$testEvents)');

    if (successRate > 99.0) {
      AppLogger.instance
          .info('   ✅ SUCCESS: Achieved >99% event delivery rate requirement!');
    } else {
      AppLogger.instance
          .warning('   ⚠️  WARNING: Success rate below 99% requirement');
    }

    // Event streaming demonstration
    AppLogger.instance.info('\n📡 7. Event Streaming Capability:');
    AppLogger.instance
        .info('   📻 Event stream available: ${analyticsService.eventStream}');
    AppLogger.instance.info(
        '   📻 Dashboard stream available: ${analyticsService.dashboardStream}');

    AppLogger.instance
        .info('\n🎉 Analytics Events Demo Completed Successfully!');
    AppLogger.instance.info('📋 Key Features Demonstrated:');
    AppLogger.instance.info('   ✅ Onboarding completion tracking');
    AppLogger.instance.info('   ✅ Add to watchlist tracking');
    AppLogger.instance.info('   ✅ Movie rating tracking');
    AppLogger.instance.info('   ✅ Analytics dashboard generation');
    AppLogger.instance
        .info('   ✅ Event delivery validation (>99% success rate)');
    AppLogger.instance.info('   ✅ Real-time event streaming');
    AppLogger.instance.info('   ✅ Metrics available for analysis');
  }
}

// Extension to get last N elements from list
extension ListExtension<T> on List<T> {
  List<T> takeLast(int count) {
    if (count >= length) return this;
    return sublist(length - count);
  }
}

// This would be called from main.dart or a test environment
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AnalyticsEventsDemo.demonstrateAnalyticsEvents();
}
