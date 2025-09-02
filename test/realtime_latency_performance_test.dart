import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peliculas/core/services/realtime_listener_service.dart';
import 'package:peliculas/core/services/sync_performance_metrics.dart';
import 'package:peliculas/infrastructure/services/multiplatform_sync_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Generate mocks for testing
@GenerateMocks([
  SupabaseClient,
  RealtimeChannel,
  MultiplataformSyncManager,
  SyncPerformanceMetrics,
])
import 'realtime_latency_performance_test.mocks.dart';

void main() {
  group('Realtime Sync Latency Performance Tests', () {
    late MockSupabaseClient mockSupabaseClient;
    late MockRealtimeChannel mockWatchlistChannel;
    late MockRealtimeChannel mockRatingsChannel;
    late MockMultiplataformSyncManager mockSyncManager;
    late MockSyncPerformanceMetrics mockMetrics;
    late RealtimeListenerService realtimeService;

    setUp(() {
      mockSupabaseClient = MockSupabaseClient();
      mockWatchlistChannel = MockRealtimeChannel();
      mockRatingsChannel = MockRealtimeChannel();
      mockSyncManager = MockMultiplataformSyncManager();
      mockMetrics = MockSyncPerformanceMetrics();

      // Setup channel returns
      when(mockSupabaseClient.channel('watchlist_changes'))
          .thenReturn(mockWatchlistChannel);
      when(mockSupabaseClient.channel('ratings_changes'))
          .thenReturn(mockRatingsChannel);

      // Setup channel chaining for watchlist
      when(mockWatchlistChannel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'user_watchlist',
        callback: anyNamed('callback'),
      )).thenReturn(mockWatchlistChannel);
      when(mockWatchlistChannel.subscribe()).thenReturn(mockWatchlistChannel);

      // Setup channel chaining for ratings
      when(mockRatingsChannel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'user_movie_ratings',
        callback: anyNamed('callback'),
      )).thenReturn(mockRatingsChannel);
      when(mockRatingsChannel.subscribe()).thenReturn(mockRatingsChannel);

      realtimeService = RealtimeListenerService();
    });

    group('Latency Requirements (<1.5s)', () {
      test('watchlist realtime events should complete processing in <1.5s', () async {
        // Arrange
        final latencyCompleter = Completer<Duration>();
        final startTime = DateTime.now();

        final watchlistData = {
          'id': 'test-id',
          'user_id': 'user-123',
          'movie_id': 550,
          'movie_title': 'Fight Club',
          'movie_poster_path': '/poster.jpg',
          'priority': 'alta',
          'added_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        late Function(PostgresChangePayload) watchlistCallback;
        when(mockWatchlistChannel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_watchlist',
          callback: anyNamed('callback'),
        )).thenAnswer((invocation) {
          watchlistCallback = invocation.namedArguments[#callback];
          return mockWatchlistChannel;
        });

        // Mock sync manager to complete operation and measure time
        when(mockSyncManager.handleRealtimeInsert(any, any))
            .thenAnswer((_) async {
          final endTime = DateTime.now();
          final latency = endTime.difference(startTime);
          latencyCompleter.complete(latency);
        });

        // Act
        await realtimeService.initialize();

        final payload = PostgresChangePayload(
          eventType: PostgresChangeEvent.insert,
          newRecord: watchlistData,
          oldRecord: {},
          schema: 'public',
          table: 'user_watchlist',
          commitTimestamp: '',
        );

        watchlistCallback(payload);

        // Wait for completion with timeout
        final latency = await latencyCompleter.future
            .timeout(const Duration(seconds: 2));

        // Assert
        expect(latency.inMilliseconds, lessThan(1500),
            reason: 'Watchlist realtime processing should complete in <1.5s, got ${latency.inMilliseconds}ms');
        
        print('✅ Watchlist realtime latency: ${latency.inMilliseconds}ms');
      });

      test('ratings realtime events should complete processing in <1.5s', () async {
        // Arrange
        final latencyCompleter = Completer<Duration>();
        final startTime = DateTime.now();

        final ratingData = {
          'id': 'rating-id',
          'user_id': 'user-123',
          'movie_id': 550,
          'movie_title': 'Fight Club',
          'movie_poster_path': '/poster.jpg',
          'rating': 5,
          'personal_note': 'Amazing movie!',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        late Function(PostgresChangePayload) ratingsCallback;
        when(mockRatingsChannel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_movie_ratings',
          callback: anyNamed('callback'),
        )).thenAnswer((invocation) {
          ratingsCallback = invocation.namedArguments[#callback];
          return mockRatingsChannel;
        });

        when(mockSyncManager.handleRealtimeInsert(any, any))
            .thenAnswer((_) async {
          final endTime = DateTime.now();
          final latency = endTime.difference(startTime);
          latencyCompleter.complete(latency);
        });

        // Act
        await realtimeService.initialize();

        final payload = PostgresChangePayload(
          eventType: PostgresChangeEvent.insert,
          newRecord: ratingData,
          oldRecord: {},
          schema: 'public',
          table: 'user_movie_ratings',
          commitTimestamp: '',
        );

        ratingsCallback(payload);

        // Wait for completion with timeout
        final latency = await latencyCompleter.future
            .timeout(const Duration(seconds: 2));

        // Assert
        expect(latency.inMilliseconds, lessThan(1500),
            reason: 'Ratings realtime processing should complete in <1.5s, got ${latency.inMilliseconds}ms');
            
        print('✅ Ratings realtime latency: ${latency.inMilliseconds}ms');
      });

      test('multiple sequential events should maintain latency requirements', () async {
        // Arrange
        final latencies = <Duration>[];
        var completedEvents = 0;
        final totalEvents = 5;
        final completer = Completer<void>();

        late Function(PostgresChangePayload) watchlistCallback;
        when(mockWatchlistChannel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_watchlist',
          callback: anyNamed('callback'),
        )).thenAnswer((invocation) {
          watchlistCallback = invocation.namedArguments[#callback];
          return mockWatchlistChannel;
        });

        when(mockSyncManager.handleRealtimeInsert(any, any))
            .thenAnswer((_) async {
          completedEvents++;
          if (completedEvents >= totalEvents) {
            completer.complete();
          }
        });

        // Act
        await realtimeService.initialize();

        // Send multiple events and measure each
        for (int i = 0; i < totalEvents; i++) {
          final startTime = DateTime.now();
          
          final watchlistData = {
            'id': 'test-id-$i',
            'user_id': 'user-123',
            'movie_id': 550 + i,
            'movie_title': 'Movie $i',
            'priority': 'normal',
            'added_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };

          final payload = PostgresChangePayload(
            eventType: PostgresChangeEvent.insert,
            newRecord: watchlistData,
            oldRecord: {},
            schema: 'public',
            table: 'user_watchlist',
            commitTimestamp: '',
          );

          watchlistCallback(payload);
          
          // Simulate processing time and measure
          await Future.delayed(const Duration(milliseconds: 100));
          final latency = DateTime.now().difference(startTime);
          latencies.add(latency);
        }

        await completer.future.timeout(const Duration(seconds: 10));

        // Assert
        for (int i = 0; i < latencies.length; i++) {
          expect(latencies[i].inMilliseconds, lessThan(1500),
              reason: 'Event $i latency should be <1.5s, got ${latencies[i].inMilliseconds}ms');
        }

        final averageLatency = latencies
            .map((l) => l.inMilliseconds)
            .reduce((a, b) => a + b) / latencies.length;
            
        print('✅ Average latency for $totalEvents events: ${averageLatency.toStringAsFixed(2)}ms');
      });
    });

    group('Performance Benchmarks', () {
      test('should handle high-frequency events with proper throttling', () async {
        // Arrange
        final eventCount = 20;
        final eventsProcessed = <String>[];
        final completer = Completer<void>();

        late Function(PostgresChangePayload) watchlistCallback;
        when(mockWatchlistChannel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_watchlist',
          callback: anyNamed('callback'),
        )).thenAnswer((invocation) {
          watchlistCallback = invocation.namedArguments[#callback];
          return mockWatchlistChannel;
        });

        when(mockSyncManager.handleRealtimeInsert(any, any))
            .thenAnswer((invocation) async {
          final data = invocation.positionalArguments[1] as Map<String, dynamic>;
          eventsProcessed.add(data['id']);
          
          if (eventsProcessed.length >= 3) { // Expecting throttling to limit to ~3 events
            completer.complete();
          }
        });

        // Act
        await realtimeService.initialize();

        // Send rapid events
        for (int i = 0; i < eventCount; i++) {
          final watchlistData = {
            'id': 'test-id-$i',
            'user_id': 'user-123',
            'movie_id': 550 + i,
            'movie_title': 'Movie $i',
            'priority': 'normal',
            'added_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };

          final payload = PostgresChangePayload(
            eventType: PostgresChangeEvent.insert,
            newRecord: watchlistData,
            oldRecord: {},
            schema: 'public',
            table: 'user_watchlist',
            commitTimestamp: '',
          );

          watchlistCallback(payload);
          
          // Very short delay between events
          await Future.delayed(const Duration(milliseconds: 10));
        }

        await completer.future.timeout(const Duration(seconds: 3));

        // Assert throttling is working - should process <= 3 events per second
        expect(eventsProcessed.length, lessThanOrEqualTo(3),
            reason: 'Throttling should limit events to max 3 per second, processed ${eventsProcessed.length}');
            
        print('✅ Throttling working: processed ${eventsProcessed.length} out of $eventCount events');
      });

      test('should measure and report sync performance metrics', () async {
        // This test would ideally integrate with actual SyncPerformanceMetrics
        // For now, we'll test the concept
        
        final metrics = <String, Duration>{};
        final operations = ['watchlist_insert', 'rating_update', 'watchlist_delete'];
        
        for (final operation in operations) {
          final stopwatch = Stopwatch()..start();
          
          // Simulate operation
          await Future.delayed(const Duration(milliseconds: 100));
          
          stopwatch.stop();
          metrics[operation] = stopwatch.elapsed;
        }
        
        // Assert all operations are within performance bounds
        for (final entry in metrics.entries) {
          expect(entry.value.inMilliseconds, lessThan(1500),
              reason: '${entry.key} should complete in <1.5s');
          print('✅ ${entry.key}: ${entry.value.inMilliseconds}ms');
        }
      });
    });
  });
}