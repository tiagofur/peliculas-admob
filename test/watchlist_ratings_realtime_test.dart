import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peliculas/core/services/realtime_listener_service.dart';
import 'package:peliculas/domain/entities/syncable_user_movie_rating.dart';
import 'package:peliculas/domain/entities/syncable_watchlist_movie.dart';
import 'package:peliculas/infrastructure/services/multiplatform_sync_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Generate mocks for testing
@GenerateMocks([
  SupabaseClient,
  RealtimeChannel,
  MultiplataformSyncManager,
])
import 'watchlist_ratings_realtime_test.mocks.dart';

void main() {
  group('Watchlist and Ratings Realtime Sync Tests', () {
    late MockSupabaseClient mockSupabaseClient;
    late MockRealtimeChannel mockWatchlistChannel;
    late MockRealtimeChannel mockRatingsChannel;
    late MockMultiplataformSyncManager mockSyncManager;
    late RealtimeListenerService realtimeService;

    setUp(() {
      mockSupabaseClient = MockSupabaseClient();
      mockWatchlistChannel = MockRealtimeChannel();
      mockRatingsChannel = MockRealtimeChannel();
      mockSyncManager = MockMultiplataformSyncManager();

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

    group('Watchlist Realtime Events', () {
      test('should handle watchlist INSERT events correctly', () async {
        // Arrange
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

        // Act
        await realtimeService.initialize();

        // Simulate INSERT event
        final payload = PostgresChangePayload(
          eventType: PostgresChangeEvent.insert,
          newRecord: watchlistData,
          oldRecord: {},
          schema: 'public',
          table: 'user_watchlist',
          commitTimestamp: '',
        );

        watchlistCallback(payload);

        // Wait for throttling
        await Future.delayed(const Duration(milliseconds: 350));

        // Assert
        verify(mockSyncManager.handleRealtimeInsert(
          'user_watchlist',
          any,
        )).called(1);
      });

      test('should handle watchlist UPDATE events correctly', () async {
        // Arrange
        final watchlistData = {
          'id': 'test-id',
          'user_id': 'user-123',
          'movie_id': 550,
          'movie_title': 'Fight Club',
          'movie_poster_path': '/poster.jpg',
          'priority': 'baja', // Changed priority
          'added_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
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
        await realtimeService.initialize();

        // Simulate UPDATE event
        final payload = PostgresChangePayload(
          eventType: PostgresChangeEvent.update,
          newRecord: watchlistData,
          oldRecord: {},
          schema: 'public',
          table: 'user_watchlist',
          commitTimestamp: '',
        );

        watchlistCallback(payload);

        // Wait for throttling
        await Future.delayed(const Duration(milliseconds: 350));

        // Assert
        verify(mockSyncManager.handleRealtimeUpdate(
          'user_watchlist',
          any,
        )).called(1);
      });

      test('should handle watchlist DELETE events correctly', () async {
        // Arrange
        final oldWatchlistData = {
          'id': 'test-id',
          'user_id': 'user-123',
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

        // Wait for throttling
        await Future.delayed(const Duration(milliseconds: 350));

        // Assert
        verify(mockSyncManager.handleRealtimeDelete(
          'user_watchlist',
          'test-id',
        )).called(1);
      });
    });

    group('Ratings Realtime Events', () {
      test('should handle rating INSERT events correctly', () async {
        // Arrange
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

        // Act
        await realtimeService.initialize();

        // Simulate INSERT event
        final payload = PostgresChangePayload(
          eventType: PostgresChangeEvent.insert,
          newRecord: ratingData,
          oldRecord: {},
          schema: 'public',
          table: 'user_movie_ratings',
          commitTimestamp: '',
        );

        ratingsCallback(payload);

        // Wait for throttling
        await Future.delayed(const Duration(milliseconds: 350));

        // Assert
        verify(mockSyncManager.handleRealtimeInsert(
          'user_movie_ratings',
          any,
        )).called(1);
      });

      test('should handle rating UPDATE events correctly', () async {
        // Arrange
        final ratingData = {
          'id': 'rating-id',
          'user_id': 'user-123',
          'movie_id': 550,
          'movie_title': 'Fight Club',
          'movie_poster_path': '/poster.jpg',
          'rating': 4, // Changed rating
          'personal_note': 'Good movie, updated review',
          'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
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
        await realtimeService.initialize();

        // Simulate UPDATE event
        final payload = PostgresChangePayload(
          eventType: PostgresChangeEvent.update,
          newRecord: ratingData,
          oldRecord: {},
          schema: 'public',
          table: 'user_movie_ratings',
          commitTimestamp: '',
        );

        ratingsCallback(payload);

        // Wait for throttling
        await Future.delayed(const Duration(milliseconds: 350));

        // Assert
        verify(mockSyncManager.handleRealtimeUpdate(
          'user_movie_ratings',
          any,
        )).called(1);
      });

      test('should handle rating DELETE events correctly', () async {
        // Arrange
        final oldRatingData = {
          'id': 'rating-id',
          'user_id': 'user-123',
          'movie_id': 550,
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
        await realtimeService.initialize();

        // Simulate DELETE event
        final payload = PostgresChangePayload(
          eventType: PostgresChangeEvent.delete,
          newRecord: {},
          oldRecord: oldRatingData,
          schema: 'public',
          table: 'user_movie_ratings',
          commitTimestamp: '',
        );

        ratingsCallback(payload);

        // Wait for throttling
        await Future.delayed(const Duration(milliseconds: 350));

        // Assert
        verify(mockSyncManager.handleRealtimeDelete(
          'user_movie_ratings',
          'rating-id',
        )).called(1);
      });
    });

    group('Performance and Latency Tests', () {
      test('should process events within acceptable latency (<1.5s)', () async {
        // Arrange
        final stopwatch = Stopwatch();
        final completer = Completer<void>();

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

        when(mockSyncManager.handleRealtimeInsert(any, any))
            .thenAnswer((_) async {
          stopwatch.stop();
          completer.complete();
        });

        // Act
        await realtimeService.initialize();
        stopwatch.start();

        final payload = PostgresChangePayload(
          eventType: PostgresChangeEvent.insert,
          newRecord: watchlistData,
          oldRecord: {},
          schema: 'public',
          table: 'user_watchlist',
          commitTimestamp: '',
        );

        watchlistCallback(payload);

        // Wait for completion
        await completer.future.timeout(const Duration(seconds: 2));

        // Assert
        expect(stopwatch.elapsedMilliseconds, lessThan(1500),
            reason: 'Event processing should complete in less than 1.5 seconds');
      });

      test('should handle multiple rapid events with proper throttling', () async {
        // Arrange
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
        await realtimeService.initialize();

        // Send 5 rapid events
        for (int i = 0; i < 5; i++) {
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
          await Future.delayed(const Duration(milliseconds: 50));
        }

        // Wait for throttling to settle
        await Future.delayed(const Duration(seconds: 2));

        // Assert - Should be throttled to max 3 events per second
        verify(mockSyncManager.handleRealtimeInsert('user_watchlist', any))
            .called(lessThanOrEqualTo(3));
      });
    });

    group('Error Handling', () {
      test('should handle malformed watchlist payloads gracefully', () async {
        // Arrange
        final malformedData = {
          'invalid': 'data',
          // Missing required fields
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
        await realtimeService.initialize();

        final payload = PostgresChangePayload(
          eventType: PostgresChangeEvent.insert,
          newRecord: malformedData,
          oldRecord: {},
          schema: 'public',
          table: 'user_watchlist',
          commitTimestamp: '',
        );

        // Should not throw an exception
        expect(() => watchlistCallback(payload), returnsNormally);

        await Future.delayed(const Duration(milliseconds: 350));

        // Assert - Should not call sync manager for malformed data
        verifyNever(mockSyncManager.handleRealtimeInsert('user_watchlist', any));
      });
    });
  });
}