import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/sync/conflict_resolution/multiplatform_conflict_resolver.dart';
import 'package:peliculas/core/sync/conflict_resolution/strategies/watchlist_conflict_strategy.dart';
import 'package:peliculas/core/sync/conflict_resolution/strategies/ratings_conflict_strategy.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/domain/entities/syncable_watchlist_movie.dart';
import 'package:peliculas/domain/entities/syncable_user_movie_rating.dart';
import 'package:peliculas/domain/entities/watchlist_movie.dart';

/// Tests for watchlist and ratings conflict resolution strategies
void main() {
  group('Watchlist and Ratings Conflict Resolution', () {
    late WatchlistConflictStrategy watchlistStrategy;
    late RatingsConflictStrategy ratingsStrategy;

    setUp(() {
      watchlistStrategy = WatchlistConflictStrategy();
      ratingsStrategy = RatingsConflictStrategy();
    });

    group('Watchlist Conflict Resolution', () {
      test('should resolve simultaneous modifications using last-write-wins', () {
        final baseTime = DateTime.now().subtract(const Duration(minutes: 10));
        
        final localItem = SyncableWatchlistMovie(
          id: 'watchlist_1',
          userId: 'user_1',
          movieId: 123,
          movieTitle: 'Test Movie',
          priority: WatchlistPriority.normal,
          addedAt: baseTime,
          updatedAt: baseTime.add(const Duration(minutes: 5)), // Local is newer
        );

        final remoteItem = SyncableWatchlistMovie(
          id: 'watchlist_1',
          userId: 'user_1',
          movieId: 123,
          movieTitle: 'Test Movie',
          priority: WatchlistPriority.alta,
          addedAt: baseTime,
          updatedAt: baseTime.add(const Duration(minutes: 2)), // Remote is older
        );

        final result = watchlistStrategy.resolveConflict(
          localItem,
          remoteItem,
          ConflictType.simultaneousModification,
        );

        // Local should win (newer timestamp)
        expect(result.resolvedItem.priority, equals(WatchlistPriority.normal));
        expect(result.conflictType, equals(ConflictType.simultaneousModification));
        expect(result.dataLoss, isFalse);
        expect(result.requiresManualIntervention, isFalse);
      });

      test('should merge simultaneous additions preserving higher priority', () {
        final baseTime = DateTime.now().subtract(const Duration(minutes: 10));
        
        final localItem = SyncableWatchlistMovie(
          id: 'watchlist_1',
          userId: 'user_1',
          movieId: 123,
          movieTitle: 'Test Movie',
          priority: WatchlistPriority.normal,
          addedAt: baseTime.add(const Duration(minutes: 2)), // Local added later
          updatedAt: baseTime.add(const Duration(minutes: 5)),
        );

        final remoteItem = SyncableWatchlistMovie(
          id: 'watchlist_1',
          userId: 'user_1',
          movieId: 123,
          movieTitle: 'Test Movie',
          priority: WatchlistPriority.alta, // Higher priority
          addedAt: baseTime, // Remote added first
          updatedAt: baseTime.add(const Duration(minutes: 3)),
        );

        final result = watchlistStrategy.resolveConflict(
          localItem,
          remoteItem,
          ConflictType.simultaneousAddition,
        );

        // Should preserve higher priority and earliest addedAt
        expect(result.resolvedItem.priority, equals(WatchlistPriority.alta));
        expect(result.resolvedItem.addedAt, equals(baseTime)); // Earliest
        expect(result.conflictType, equals(ConflictType.simultaneousAddition));
        expect(result.dataLoss, isFalse);
      });

      test('should handle deletion vs modification correctly', () {
        final baseTime = DateTime.now().subtract(const Duration(minutes: 10));
        
        final localItem = SyncableWatchlistMovie(
          id: 'watchlist_1',
          userId: 'user_1',
          movieId: 123,
          movieTitle: 'Test Movie',
          priority: WatchlistPriority.normal,
          addedAt: baseTime,
          updatedAt: baseTime.add(const Duration(minutes: 5)),
        );

        final remoteItem = SyncableWatchlistMovie(
          id: 'watchlist_1',
          userId: 'user_1',
          movieId: 123,
          movieTitle: 'Test Movie',
          priority: WatchlistPriority.alta,
          addedAt: baseTime,
          updatedAt: baseTime.add(const Duration(minutes: 8)),
          deletedAt: baseTime.add(const Duration(minutes: 8)), // Deleted remotely
        );

        final result = watchlistStrategy.resolveConflict(
          localItem,
          remoteItem,
          ConflictType.modificationVsDeletion,
        );

        // Deletion should win
        expect(result.resolvedItem.isDeleted, isTrue);
        expect(result.conflictType, equals(ConflictType.modificationVsDeletion));
        expect(result.dataLoss, isTrue); // Local modifications lost
      });
    });

    group('Ratings Conflict Resolution', () {
      test('should resolve simultaneous modifications using last-write-wins', () {
        final baseTime = DateTime.now().subtract(const Duration(minutes: 10));
        
        final localItem = SyncableUserMovieRating(
          id: 'rating_1',
          userId: 'user_1',
          movieId: 123,
          movieTitle: 'Test Movie',
          rating: 4,
          personalNote: 'Great movie!',
          createdAt: baseTime,
          updatedAt: baseTime.add(const Duration(minutes: 5)), // Local is newer
        );

        final remoteItem = SyncableUserMovieRating(
          id: 'rating_1',
          userId: 'user_1',
          movieId: 123,
          movieTitle: 'Test Movie',
          rating: 3,
          personalNote: 'Good movie',
          createdAt: baseTime,
          updatedAt: baseTime.add(const Duration(minutes: 2)), // Remote is older
        );

        final result = ratingsStrategy.resolveConflict(
          localItem,
          remoteItem,
          ConflictType.simultaneousModification,
        );

        // Local should win (newer timestamp)
        expect(result.resolvedItem.rating, equals(4));
        expect(result.resolvedItem.personalNote, equals('Great movie!'));
        expect(result.conflictType, equals(ConflictType.simultaneousModification));
        expect(result.dataLoss, isFalse);
      });

      test('should require manual intervention for significantly different ratings', () {
        final baseTime = DateTime.now().subtract(const Duration(minutes: 10));
        
        final localItem = SyncableUserMovieRating(
          id: 'rating_1',
          userId: 'user_1',
          movieId: 123,
          movieTitle: 'Test Movie',
          rating: 5,
          personalNote: 'Amazing!',
          createdAt: baseTime,
          updatedAt: baseTime.add(const Duration(minutes: 5)),
        );

        final remoteItem = SyncableUserMovieRating(
          id: 'rating_1',
          userId: 'user_1',
          movieId: 123,
          movieTitle: 'Test Movie',
          rating: 1, // Very different rating
          personalNote: 'Terrible movie',
          createdAt: baseTime,
          updatedAt: baseTime.add(const Duration(minutes: 2)),
        );

        final result = ratingsStrategy.resolveConflict(
          localItem,
          remoteItem,
          ConflictType.simultaneousModification,
        );

        // Should require manual intervention due to large rating difference
        expect(result.requiresManualIntervention, isTrue);
        expect(result.dataLoss, isTrue); // Significant difference in ratings
      });

      test('should merge similar personal notes intelligently', () {
        final baseTime = DateTime.now().subtract(const Duration(minutes: 10));
        
        final localItem = SyncableUserMovieRating(
          id: 'rating_1',
          userId: 'user_1',
          movieId: 123,
          movieTitle: 'Test Movie',
          rating: 4,
          personalNote: 'Great action scenes and plot',
          createdAt: baseTime,
          updatedAt: baseTime.add(const Duration(minutes: 5)), // Local is newer
        );

        final remoteItem = SyncableUserMovieRating(
          id: 'rating_1',
          userId: 'user_1',
          movieId: 123,
          movieTitle: 'Test Movie',
          rating: 4,
          personalNote: 'Great action scenes', // Similar but shorter
          createdAt: baseTime,
          updatedAt: baseTime.add(const Duration(minutes: 2)),
        );

        final result = ratingsStrategy.resolveConflict(
          localItem,
          remoteItem,
          ConflictType.simultaneousModification,
        );

        // Should keep the longer, more detailed note
        expect(result.resolvedItem.personalNote, equals('Great action scenes and plot'));
        expect(result.dataLoss, isFalse);
        expect(result.requiresManualIntervention, isFalse);
      });

      test('should merge simultaneous additions preserving most recent data', () {
        final baseTime = DateTime.now().subtract(const Duration(minutes: 10));
        
        final localItem = SyncableUserMovieRating(
          id: 'rating_1',
          userId: 'user_1',
          movieId: 123,
          movieTitle: 'Test Movie',
          rating: 4,
          personalNote: 'Good movie',
          createdAt: baseTime.add(const Duration(minutes: 2)), // Local created later
          updatedAt: baseTime.add(const Duration(minutes: 5)), // Local updated later
        );

        final remoteItem = SyncableUserMovieRating(
          id: 'rating_1',
          userId: 'user_1',
          movieId: 123,
          movieTitle: 'Test Movie',
          rating: 3,
          personalNote: 'Decent',
          createdAt: baseTime, // Remote created first
          updatedAt: baseTime.add(const Duration(minutes: 3)),
        );

        final result = ratingsStrategy.resolveConflict(
          localItem,
          remoteItem,
          ConflictType.simultaneousAddition,
        );

        // Should preserve earliest createdAt and latest updatedAt data
        expect(result.resolvedItem.createdAt, equals(baseTime)); // Earliest
        expect(result.resolvedItem.rating, equals(4)); // From more recent update
        expect(result.resolvedItem.personalNote, equals('Good movie')); // From more recent update
        expect(result.dataLoss, isFalse);
      });
    });

    group('Strategy Integration', () {
      test('strategies should be registerable in conflict resolver', () {
        final resolver = MultiplataformConflictResolver();
        
        expect(() {
          resolver.registerStrategy<SyncableWatchlistMovie>(watchlistStrategy);
          resolver.registerStrategy<SyncableUserMovieRating>(ratingsStrategy);
        }, returnsNormally);
      });

      test('conflict resolver should use registered strategies', () {
        final resolver = MultiplataformConflictResolver();
        resolver.registerStrategy<SyncableWatchlistMovie>(watchlistStrategy);
        
        final baseTime = DateTime.now().subtract(const Duration(minutes: 10));
        
        final localItem = SyncableWatchlistMovie(
          id: 'watchlist_1',
          userId: 'user_1',
          movieId: 123,
          movieTitle: 'Test Movie',
          priority: WatchlistPriority.normal,
          addedAt: baseTime,
          updatedAt: baseTime.add(const Duration(minutes: 5)),
        );

        final remoteItem = SyncableWatchlistMovie(
          id: 'watchlist_1',
          userId: 'user_1',
          movieId: 123,
          movieTitle: 'Test Movie',
          priority: WatchlistPriority.alta,
          addedAt: baseTime,
          updatedAt: baseTime.add(const Duration(minutes: 2)),
        );

        final result = resolver.resolveConflict(
          localItem,
          remoteItem,
          ConflictType.simultaneousModification,
        );

        expect(result.resolvedItem.priority, equals(WatchlistPriority.normal));
      });
    });
  });
}