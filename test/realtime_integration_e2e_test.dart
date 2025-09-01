import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peliculas/core/services/realtime_listener_service.dart';
import 'package:peliculas/infrastructure/services/multiplatform_sync_manager.dart';
import 'package:peliculas/presentation/providers/watchlist_provider.dart';
import 'package:peliculas/presentation/providers/user_movie_ratings_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Generate mocks for integration testing
@GenerateMocks([
  SupabaseClient,
  RealtimeChannel,
  ProviderContainer,
])
import 'realtime_integration_e2e_test.mocks.dart';

void main() {
  group('Realtime Sync End-to-End Integration Tests', () {
    late MockSupabaseClient mockSupabaseClient;
    late MockRealtimeChannel mockWatchlistChannel;
    late MockRealtimeChannel mockRatingsChannel;
    late MockProviderContainer mockContainer;
    late RealtimeListenerService realtimeService;
    late MultiplataformSyncManager syncManager;

    setUp(() {
      mockSupabaseClient = MockSupabaseClient();
      mockWatchlistChannel = MockRealtimeChannel();
      mockRatingsChannel = MockRealtimeChannel();
      mockContainer = MockProviderContainer();

      // Setup channel returns
      when(mockSupabaseClient.channel('watchlist_changes'))
          .thenReturn(mockWatchlistChannel);
      when(mockSupabaseClient.channel('ratings_changes'))
          .thenReturn(mockRatingsChannel);

      // Setup channel chaining
      when(mockWatchlistChannel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'user_watchlist',
        callback: anyNamed('callback'),
      )).thenReturn(mockWatchlistChannel);
      when(mockWatchlistChannel.subscribe()).thenReturn(mockWatchlistChannel);

      when(mockRatingsChannel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'user_movie_ratings',
        callback: anyNamed('callback'),
      )).thenReturn(mockRatingsChannel);
      when(mockRatingsChannel.subscribe()).thenReturn(mockRatingsChannel);

      realtimeService = RealtimeListenerService();
      syncManager = MultiplataformSyncManager.instance;
    });

    group('Complete Flow Integration Tests', () {
      test('should handle complete watchlist realtime flow with provider invalidation', () async {
        // Arrange
        final watchlistData = {
          'id': 'watchlist-123',
          'user_id': 'user-456',
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

        // Act
        await syncManager.initialize(mockContainer);
        await realtimeService.initialize();

        // Simulate realtime event
        final payload = PostgresChangePayload(
          eventType: PostgresChangeEvent.insert,
          newRecord: watchlistData,
          oldRecord: {},
          schema: 'public',
          table: 'user_watchlist',
          commitTimestamp: '',
        );

        watchlistCallback(payload);

        // Wait for throttling and processing
        await Future.delayed(const Duration(milliseconds: 400));

        // Assert provider invalidation was called
        verify(mockContainer.invalidate(watchlistProvider)).called(1);
        verify(mockContainer.invalidate(watchlistCountProvider)).called(1);
        verify(mockContainer.invalidate(isMovieInWatchlistProvider)).called(1);
        verify(mockContainer.invalidate(watchlistMovieProvider)).called(1);
      });

      test('should handle complete ratings realtime flow with provider invalidation', () async {
        // Arrange
        final ratingData = {
          'id': 'rating-789',
          'user_id': 'user-456',
          'movie_id': 550,
          'movie_title': 'Fight Club',
          'movie_poster_path': '/poster.jpg',
          'rating': 5,
          'personal_note': 'Excellent movie!',
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

        // Act
        await syncManager.initialize(mockContainer);
        await realtimeService.initialize();

        // Simulate realtime event
        final payload = PostgresChangePayload(
          eventType: PostgresChangeEvent.update,
          newRecord: ratingData,
          oldRecord: {},
          schema: 'public',
          table: 'user_movie_ratings',
          commitTimestamp: '',
        );

        ratingsCallback(payload);

        // Wait for throttling and processing
        await Future.delayed(const Duration(milliseconds: 400));

        // Assert provider invalidation was called
        verify(mockContainer.invalidate(userRatingsProvider)).called(1);
        verify(mockContainer.invalidate(ratingStatsProvider)).called(1);
        verify(mockContainer.invalidate(topRatedMoviesProvider)).called(1);
        verify(mockContainer.invalidate(recentRatingsProvider)).called(1);
      });

      test('should handle DELETE events and invalidate providers', () async {
        // Arrange
        final oldWatchlistData = {
          'id': 'watchlist-to-delete',
          'user_id': 'user-456',
          'movie_id': 550,
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

        // Act
        await syncManager.initialize(mockContainer);
        await realtimeService.initialize();

        // Simulate DELETE event
        final payload = PostgresChangePayload(
          eventType: PostgresChangeEvent.delete,
          newRecord: {},
          oldRecord: oldWatchlistData,
          schema: 'public',
          table: 'user_watchlist',
          commitTimestamp: '',
        );

        watchlistCallback(payload);

        // Wait for throttling and processing
        await Future.delayed(const Duration(milliseconds: 400));

        // Assert provider invalidation was called for DELETE
        verify(mockContainer.invalidate(watchlistProvider)).called(1);
        verify(mockContainer.invalidate(watchlistCountProvider)).called(1);
      });

      test('should demonstrate multi-device sync simulation', () async {
        // This test simulates what would happen across multiple devices
        
        final events = [
          // Device 1 adds movie to watchlist
          {
            'type': 'watchlist_insert',
            'data': {
              'id': 'w1',
              'user_id': 'user-123',
              'movie_id': 100,
              'movie_title': 'Movie 1',
              'priority': 'alta',
              'added_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            }
          },
          // Device 2 rates the same movie
          {
            'type': 'rating_insert',
            'data': {
              'id': 'r1',
              'user_id': 'user-123',
              'movie_id': 100,
              'movie_title': 'Movie 1',
              'rating': 4,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            }
          },
          // Device 3 updates watchlist priority
          {
            'type': 'watchlist_update',
            'data': {
              'id': 'w1',
              'user_id': 'user-123',
              'movie_id': 100,
              'movie_title': 'Movie 1',
              'priority': 'normal', // Changed from 'alta'
              'updated_at': DateTime.now().toIso8601String(),
            }
          },
        ];

        late Function(PostgresChangePayload) watchlistCallback;
        late Function(PostgresChangePayload) ratingsCallback;

        when(mockWatchlistChannel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_watchlist',
          callback: anyNamed('callback'),
        )).thenAnswer((invocation) {
          watchlistCallback = invocation.namedArguments[#callback];
          return mockWatchlistChannel;
        });

        when(mockRatingsChannel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_movie_ratings',
          callback: anyNamed('callback'),
        )).thenAnswer((invocation) {
          ratingsCallback = invocation.namedArguments[#callback];
          return mockRatingsChannel;
        });

        // Act
        await syncManager.initialize(mockContainer);
        await realtimeService.initialize();

        // Simulate multi-device events with realistic timing
        for (final event in events) {
          switch (event['type']) {
            case 'watchlist_insert':
              final payload = PostgresChangePayload(
                eventType: PostgresChangeEvent.insert,
                newRecord: event['data'] as Map<String, dynamic>,
                oldRecord: {},
                schema: 'public',
                table: 'user_watchlist',
                commitTimestamp: '',
              );
              watchlistCallback(payload);
              break;

            case 'watchlist_update':
              final payload = PostgresChangePayload(
                eventType: PostgresChangeEvent.update,
                newRecord: event['data'] as Map<String, dynamic>,
                oldRecord: {},
                schema: 'public',
                table: 'user_watchlist',
                commitTimestamp: '',
              );
              watchlistCallback(payload);
              break;

            case 'rating_insert':
              final payload = PostgresChangePayload(
                eventType: PostgresChangeEvent.insert,
                newRecord: event['data'] as Map<String, dynamic>,
                oldRecord: {},
                schema: 'public',
                table: 'user_movie_ratings',
                commitTimestamp: '',
              );
              ratingsCallback(payload);
              break;
          }

          // Simulate real-world timing between device actions
          await Future.delayed(const Duration(milliseconds: 200));
        }

        // Wait for all events to process
        await Future.delayed(const Duration(seconds: 1));

        // Assert all devices would receive updates
        verify(mockContainer.invalidate(watchlistProvider)).called(2); // Insert + Update
        verify(mockContainer.invalidate(userRatingsProvider)).called(1); // Insert
        
        print('✅ Multi-device sync simulation completed successfully');
      });
    });

    group('Error Handling and Resilience', () {
      test('should handle malformed payloads gracefully', () async {
        // Arrange
        final malformedData = {
          'invalid': 'payload',
          'missing': 'required_fields',
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

        // Act
        await syncManager.initialize(mockContainer);
        await realtimeService.initialize();

        // Should not throw an exception
        expect(() {
          final payload = PostgresChangePayload(
            eventType: PostgresChangeEvent.insert,
            newRecord: malformedData,
            oldRecord: {},
            schema: 'public',
            table: 'user_watchlist',
            commitTimestamp: '',
          );
          watchlistCallback(payload);
        }, returnsNormally);

        // Should not invalidate providers for malformed data
        await Future.delayed(const Duration(milliseconds: 400));
        verifyNever(mockContainer.invalidate(any));
      });

      test('should handle provider container not available', () async {
        // Arrange - Initialize without container
        await syncManager.initialize(); // No container provided

        final watchlistData = {
          'id': 'test-id',
          'user_id': 'user-123',
          'movie_id': 550,
          'movie_title': 'Fight Club',
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

        await realtimeService.initialize();

        // Act - Should handle gracefully
        expect(() {
          final payload = PostgresChangePayload(
            eventType: PostgresChangeEvent.insert,
            newRecord: watchlistData,
            oldRecord: {},
            schema: 'public',
            table: 'user_watchlist',
            commitTimestamp: '',
          );
          watchlistCallback(payload);
        }, returnsNormally);

        print('✅ Graceful handling of missing provider container verified');
      });
    });
  });
}