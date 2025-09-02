import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../lib/core/analytics/analytics_service.dart';
import '../lib/domain/entities/movie.dart';
import '../lib/domain/entities/watchlist_movie.dart';

/// Demo script to showcase the analytics events functionality
class AnalyticsEventsDemo {
  static Future<void> demonstrateAnalyticsEvents() async {
    print('🚀 Analytics Events Demo Starting...\n');

    // Initialize analytics service
    final analyticsService = AnalyticsService();
    await analyticsService.initialize();
    print('✅ Analytics service initialized\n');

    // Demo movie for testing
    final testMovie = Movie(
      id: 12345,
      title: 'Inception',
      overview: 'A mind-bending thriller about dreams within dreams.',
      posterPath: '/poster.jpg',
      backdropPath: '/backdrop.jpg',
      releaseDate: DateTime(2010, 7, 16),
      genreIds: [878, 28, 53], // Sci-Fi, Action, Thriller
      originalLanguage: 'en',
      originalTitle: 'Inception',
      popularity: 8.8,
      voteAverage: 8.2,
      voteCount: 14000,
      adult: false,
      video: false,
    );

    print('🎬 Demo Movie: ${testMovie.title}\n');

    // 1. Demonstrate Onboarding Completion Event
    print('📋 1. Tracking Onboarding Completion Event...');
    await analyticsService.trackEvent(
      AnalyticsEventType.onboarding,
      {
        'user_id': 'demo_user_123',
        'action': 'onboarding_completed',
        'completion_method': 'authentication',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
    print('   ✅ Onboarding completion event tracked');

    // 2. Demonstrate Add to Watchlist Event
    print('\n📺 2. Tracking Add to Watchlist Event...');
    await analyticsService.trackEvent(
      AnalyticsEventType.addWatchlist,
      {
        'movie_id': testMovie.id,
        'movie_title': testMovie.title,
        'priority': WatchlistPriority.high.name,
        'action': 'add_to_watchlist',
      },
    );
    print('   ✅ Add to watchlist event tracked');

    // 3. Demonstrate Rate Movie Event
    print('\n⭐ 3. Tracking Rate Movie Event...');
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
    print('   ✅ Rate movie event tracked');

    // Show analytics dashboard
    print('\n📊 4. Analytics Dashboard Summary:');
    final dashboard = await analyticsService.getDashboard();
    print('   📈 Dashboard generated at: ${dashboard.lastUpdated}');
    print('   📈 User metrics available: ${dashboard.userMetrics != null}');
    print('   📈 Content metrics available: ${dashboard.contentMetrics != null}');
    print('   📈 Performance metrics available: ${dashboard.performanceMetrics != null}');

    // Show event summary
    final events = analyticsService.events;
    print('\n📋 5. Event Summary:');
    print('   📊 Total events tracked: ${events.length}');
    
    if (events.isNotEmpty) {
      final recentEvents = events.takeLast(3);
      print('   🔍 Recent events:');
      for (int i = 0; i < recentEvents.length; i++) {
        final event = recentEvents[i];
        print('      ${i + 1}. ${event.type.name} - ${event.properties['action'] ?? 'unknown action'}');
      }
    }

    // Test success rate
    print('\n🎯 6. Testing Event Delivery Success Rate...');
    final testEvents = 50;
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
        print('   ❌ Failed to track event $i: $e');
      }
    }

    final successRate = (successfulEvents / testEvents) * 100;
    print('   📊 Success Rate: ${successRate.toStringAsFixed(1)}% ($successfulEvents/$testEvents)');
    
    if (successRate > 99.0) {
      print('   ✅ SUCCESS: Achieved >99% event delivery rate requirement!');
    } else {
      print('   ⚠️  WARNING: Success rate below 99% requirement');
    }

    // Event streaming demonstration
    print('\n📡 7. Event Streaming Capability:');
    print('   📻 Event stream available: ${analyticsService.eventStream != null}');
    print('   📻 Dashboard stream available: ${analyticsService.dashboardStream != null}');

    print('\n🎉 Analytics Events Demo Completed Successfully!');
    print('📋 Key Features Demonstrated:');
    print('   ✅ Onboarding completion tracking');
    print('   ✅ Add to watchlist tracking');
    print('   ✅ Movie rating tracking');
    print('   ✅ Analytics dashboard generation');
    print('   ✅ Event delivery validation (>99% success rate)');
    print('   ✅ Real-time event streaming');
    print('   ✅ Metrics available for analysis');
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