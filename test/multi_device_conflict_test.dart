import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/sync/conflict_resolution/conflict_detector.dart';
import 'package:peliculas/core/sync/conflict_resolution/multiplatform_conflict_resolver.dart';
import 'package:peliculas/core/sync/conflict_resolution/soft_delete_manager.dart';
import 'package:peliculas/core/sync/conflict_resolution/strategies/custom_lists_conflict_strategy.dart';
import 'package:peliculas/core/sync/conflict_resolution/strategies/favorites_conflict_strategy.dart';
import 'package:peliculas/core/sync/conflict_resolution/strategies/watched_movies_conflict_strategy.dart';
import 'package:peliculas/domain/entities/custom_list.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/domain/entities/sync_models.dart';
import 'package:peliculas/domain/entities/syncable_favorite_movie.dart';
// Removed unused import
import 'package:peliculas/infrastructure/sync/conflict_statistics_service.dart';

/// Pruebas para escenarios multi-dispositivo reales
void main() {
  group('Multi-Device Conflict Scenarios', () {
    // Removed unused severityClassifier
    late ConflictStatisticsService statisticsService;
    late ConflictDetector conflictDetector;
    late MultiplataformConflictResolver conflictResolver;
    late SoftDeleteManager softDeleteManager;

    setUp(() {
      // Removed unused severityClassifier
      statisticsService = ConflictStatisticsService();
      softDeleteManager = SoftDeleteManager();
      conflictDetector = ConflictDetector(
        softDeleteManager,
        statisticsService,
      );
      conflictResolver = MultiplataformConflictResolver();

      // Registrar estrategias
      conflictResolver.registerStrategy<SyncableFavoriteMovie>(
        FavoritesConflictStrategy()
            as ConflictResolutionStrategy<SyncableFavoriteMovie>,
      );
      conflictResolver.registerStrategy<SyncableWatchedMovie>(
        WatchedMoviesConflictStrategy()
            as ConflictResolutionStrategy<SyncableWatchedMovie>,
      );
      conflictResolver.registerStrategy<SyncableCustomList>(
        CustomListsConflictStrategy()
            as ConflictResolutionStrategy<SyncableCustomList>,
      );
    });

    group('Scenario: Phone vs Tablet Conflicts', () {
      test('User adds favorite on phone, removes on tablet simultaneously',
          () async {
        final movie = Movie(
          id: 1001,
          title: 'Avengers: Endgame',
          overview: 'The epic conclusion to the Infinity Saga',
          posterPath: '/or06FN3Dka5tukK1e9sl16pB3iy.jpg',
          backdropPath: '/7RyHsO4yDXtBv1zUU3mTpHeQ0d5.jpg',
          releaseDate: DateTime(2019, 4, 26),
          voteAverage: 8.3,
          genreIds: ['12', '878', '28'],
          adult: false,
          originalLanguage: 'en',
          originalTitle: 'Avengers: Endgame',
          popularity: 500.0,
          video: false,
          voteCount: 20000,
        );

        final baseTime = DateTime.now().subtract(Duration(minutes: 10));

        // Phone: User adds to favorites
        final phoneFavorite = SyncableFavoriteMovie.fromMovie(
          userId: 'user123',
          movie: movie,
          addedAt: baseTime.add(Duration(minutes: 2)),
        );

        // Tablet: User removes from favorites (soft delete)
        final tabletFavorite = SyncableFavoriteMovie.fromMovie(
          userId: 'user123',
          movie: movie,
          addedAt: baseTime.add(Duration(minutes: 3)),
        );
        final deletedTabletFavorite = tabletFavorite.copyWith(
          isDeleted: true,
          updatedAt: DateTime.now(),
        );

        // Detect conflict
        final conflict = conflictDetector.detectConflict(
          phoneFavorite,
          deletedTabletFavorite,
        );

        expect(conflict, isNotNull);
        expect(conflict!.type, equals(ConflictType.deletionVsModification));
        expect(conflict.severity, equals(ConflictSeverity.high));

        // Resolve conflict - deletion should win
        final resolution = conflictResolver.resolveConflict(
          phoneFavorite,
          deletedTabletFavorite,
          conflict.type,
        );

        expect(resolution.resolvedItem.isDeleted, isTrue);
        expect(resolution.resolution, equals('deletion_wins'));
        // User intent is preserved when deletion wins over modification
        expect(resolution.dataLoss, isFalse);
      });

      test('User watches movie on different devices with different timestamps',
          () async {
        final movie = Movie(
          id: 1002,
          title: 'The Matrix',
          overview: 'A computer hacker learns about the true nature of reality',
          posterPath: '/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg',
          backdropPath: '/fNG7i7RqMErkcqhohV2a6cV1Ehy.jpg',
          releaseDate: DateTime(1999, 3, 31),
          voteAverage: 8.7,
          genreIds: ['28', '878'],
          adult: false,
          originalLanguage: 'en',
          originalTitle: 'The Matrix',
          popularity: 400.0,
          video: false,
          voteCount: 15000,
        );

        final baseTime = DateTime.now().subtract(Duration(hours: 2));

        // Phone: User watches at home
        final phoneWatched = SyncableWatchedMovie.fromMovie(
          userId: 'user123',
          movie: movie,
        ).copyWith(
          watchedAt: baseTime.add(Duration(minutes: 30)),
          createdAt: baseTime.add(Duration(minutes: 30)),
          updatedAt: baseTime.add(Duration(minutes: 30)),
        );

        // Laptop: User watches at work (different session)
        final laptopWatched = SyncableWatchedMovie.fromMovie(
          userId: 'user123',
          movie: movie,
        ).copyWith(
          watchedAt: baseTime.add(Duration(hours: 1, minutes: 15)),
          createdAt: baseTime.add(Duration(hours: 1, minutes: 15)),
          updatedAt: baseTime.add(Duration(hours: 1, minutes: 15)),
        );

        // Detect conflict
        final conflict = conflictDetector.detectConflict(
          phoneWatched,
          laptopWatched,
        );

        expect(conflict, isNotNull);
        expect(conflict!.type, equals(ConflictType.simultaneousModification));

        // Resolve conflict - latest timestamp should win
        final resolution = conflictResolver.resolveConflict(
          phoneWatched,
          laptopWatched,
          conflict.type,
        );

        expect(
            resolution.resolvedItem.updatedAt, equals(laptopWatched.updatedAt));
        expect(resolution.resolution, equals('latest_timestamp_wins'));
      });
    });

    group('Scenario: Offline vs Online Modifications', () {
      test('User modifies list offline, server updates online simultaneously',
          () async {
        final baseTime = DateTime.now().subtract(Duration(hours: 1));

        // Offline device: User adds movies to "Watchlist"
        final offlineList = SyncableCustomList.fromCustomList(
          CustomList(
            id: 'watchlist-001',
            name: 'My Watchlist',
            description: 'Movies I want to watch',
            emoji: '📺',
            movieIds: [1001, 1002, 1003], // Added offline
            createdAt: baseTime.subtract(Duration(days: 1)),
            updatedAt: baseTime.add(Duration(minutes: 15)),
            color: 'blue',
          ),
          'user123',
        );

        // Online server: Another device adds different movies
        final onlineList = SyncableCustomList.fromCustomList(
          CustomList(
            id: 'watchlist-001',
            name: 'My Watchlist',
            description: 'Movies I want to watch soon',
            emoji: '🎬',
            movieIds: [1004, 1005, 1006], // Added online
            createdAt: baseTime.subtract(Duration(days: 1)),
            updatedAt: baseTime.add(Duration(minutes: 20)),
            color: 'red',
          ),
          'user123',
        );

        // Detect conflict
        final conflict = conflictDetector.detectConflict(
          offlineList,
          onlineList,
        );

        expect(conflict, isNotNull);
        expect(conflict!.type, equals(ConflictType.simultaneousModification));

        // Resolve conflict - should merge movie lists and use latest metadata
        final resolution = conflictResolver.resolveConflict(
          offlineList,
          onlineList,
          conflict.type,
        );

        final resolvedList = resolution.resolvedItem;

        // Should use latest metadata
        expect(resolvedList.description, equals('Movies I want to watch soon'));
        expect(resolvedList.emoji, equals('🎬'));
        expect(resolvedList.color, equals('red'));

        // Should merge all movie IDs
        expect(resolvedList.movieIds,
            containsAll([1001, 1002, 1003, 1004, 1005, 1006]));
        expect(resolvedList.movieIds.length, equals(6));
      });

      test('Network interruption causes duplicate favorite additions',
          () async {
        final movie = Movie(
          id: 1003,
          title: 'Inception',
          overview:
              'A thief who steals corporate secrets through dream-sharing',
          posterPath: '/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg',
          backdropPath: '/s3TBrRGB1iav7gFOCNx3H31MoES.jpg',
          releaseDate: DateTime(2010, 7, 16),
          voteAverage: 8.8,
          genreIds: ['28', '878', '53'],
          adult: false,
          originalLanguage: 'en',
          originalTitle: 'Inception',
          popularity: 450.0,
          video: false,
          voteCount: 25000,
        );

        final baseTime = DateTime.now().subtract(Duration(minutes: 30));

        // Device 1: Adds favorite during network interruption
        final device1Favorite = SyncableFavoriteMovie.fromMovie(
          userId: 'user123',
          movie: movie,
          addedAt: baseTime.add(Duration(minutes: 5)),
        );

        // Device 2: Adds same favorite when network is restored
        final device2Favorite = SyncableFavoriteMovie.fromMovie(
          userId: 'user123',
          movie: movie,
          addedAt: baseTime.add(Duration(minutes: 8)),
        );

        // This should NOT create a conflict since both are additions
        final conflict = conflictDetector.detectConflict(
          device1Favorite,
          device2Favorite,
        );

        // Should be null or very low severity since both are adding the same item
        if (conflict != null) {
          expect(conflict.severity, equals(ConflictSeverity.low));

          final resolution = conflictResolver.resolveConflict(
            device1Favorite,
            device2Favorite,
            conflict.type,
          );

          // Should keep the item as favorite
          expect(resolution.resolvedItem.isDeleted, isFalse);
        }
      });
    });

    group('Scenario: Family Account Conflicts', () {
      test('Multiple family members modify same custom list', () async {
        final baseTime = DateTime.now().subtract(Duration(hours: 2));

        // Parent adds family movies
        final parentList = SyncableCustomList.fromCustomList(
          CustomList(
            id: 'family-movies',
            name: 'Family Movie Night',
            description: 'Movies for the whole family',
            emoji: '👨‍👩‍👧‍👦',
            movieIds: [2001, 2002, 2003], // Family-friendly movies
            createdAt: baseTime.subtract(Duration(days: 7)),
            updatedAt: baseTime.add(Duration(minutes: 10)),
            color: 'green',
          ),
          'family_account',
        );

        // Child adds animated movies
        final childList = SyncableCustomList.fromCustomList(
          CustomList(
            id: 'family-movies',
            name: 'Family Movie Night',
            description: 'Fun movies for everyone!',
            emoji: '🎭',
            movieIds: [2004, 2005, 2006], // Animated movies
            createdAt: baseTime.subtract(Duration(days: 7)),
            updatedAt: baseTime.add(Duration(minutes: 15)),
            color: 'purple',
          ),
          'family_account',
        );

        // Detect conflict
        final conflict = conflictDetector.detectConflict(
          parentList,
          childList,
        );

        expect(conflict, isNotNull);
        expect(conflict!.type, equals(ConflictType.simultaneousModification));

        // Resolve conflict - should merge all movies
        final resolution = conflictResolver.resolveConflict(
          parentList,
          childList,
          conflict.type,
        );

        final resolvedList = resolution.resolvedItem;

        // Should use latest metadata (child's changes)
        expect(resolvedList.description, equals('Fun movies for everyone!'));
        expect(resolvedList.emoji, equals('🎭'));
        expect(resolvedList.color, equals('purple'));

        // Should include all movies from both lists
        expect(resolvedList.movieIds,
            containsAll([2001, 2002, 2003, 2004, 2005, 2006]));
      });
    });

    group('Scenario: Rapid Sequential Changes', () {
      test('User rapidly toggles favorite status', () async {
        final movie = Movie(
          id: 1004,
          title: 'Pulp Fiction',
          overview: 'The lives of two mob hitmen intersect',
          posterPath: '/d5iIlFn5s0ImszYzBPb8JPIfbXD.jpg',
          backdropPath: '/4cDFJr4HnXN5AdPw4AKrmLlMWdO.jpg',
          releaseDate: DateTime(1994, 10, 14),
          voteAverage: 8.9,
          genreIds: ['80', '18'],
          adult: false,
          originalLanguage: 'en',
          originalTitle: 'Pulp Fiction',
          popularity: 350.0,
          video: false,
          voteCount: 18000,
        );

        final baseTime = DateTime.now().subtract(Duration(minutes: 5));

        // Simulate rapid changes
        final changes = <SyncableFavoriteMovie>[];

        for (int i = 0; i < 5; i++) {
          final favorite = SyncableFavoriteMovie.fromMovie(
            userId: 'user123',
            movie: movie,
            addedAt: baseTime.add(Duration(seconds: i * 30)),
          );

          // Alternate between adding and removing
          if (i % 2 == 1) {
            final deletedFavorite = favorite.copyWith(
              isDeleted: true,
              updatedAt: DateTime.now(),
            );
            changes.add(deletedFavorite);
          } else {
            changes.add(favorite);
          }
        }

        // Test conflict detection between rapid changes
        for (int i = 0; i < changes.length - 1; i++) {
          final conflict = conflictDetector.detectConflict(
            changes[i],
            changes[i + 1],
          );

          if (conflict != null) {
            final resolution = conflictResolver.resolveConflict(
              changes[i],
              changes[i + 1],
              conflict.type,
            );

            // Latest change should always win
            expect(resolution.resolvedItem.updatedAt,
                equals(changes[i + 1].updatedAt));
          }
        }
      });
    });

    group('Scenario: Data Integrity Validation', () {
      test('Ensure no data loss in complex merge scenarios', () async {
        final baseTime = DateTime.now().subtract(Duration(hours: 3));

        // Create a complex list with many movies
        final originalMovieIds = List.generate(20, (index) => 3000 + index);

        final device1List = SyncableCustomList.fromCustomList(
          CustomList(
            id: 'complex-list',
            name: 'My Complex List',
            description: 'A list with many movies',
            emoji: '📚',
            movieIds: originalMovieIds.take(15).toList(), // First 15 movies
            createdAt: baseTime.subtract(Duration(days: 1)),
            updatedAt: baseTime.add(Duration(minutes: 10)),
            color: 'blue',
          ),
          'user123',
        );

        final device2List = SyncableCustomList.fromCustomList(
          CustomList(
            id: 'complex-list',
            name: 'My Complex List',
            description: 'Updated description',
            emoji: '📖',
            movieIds: originalMovieIds
                .skip(10)
                .toList(), // Last 10 movies (overlap with first list)
            createdAt: baseTime.subtract(Duration(days: 1)),
            updatedAt: baseTime.add(Duration(minutes: 12)),
            color: 'red',
          ),
          'user123',
        );

        // Detect and resolve conflict
        final conflict = conflictDetector.detectConflict(
          device1List,
          device2List,
        );

        expect(conflict, isNotNull);

        final resolution = conflictResolver.resolveConflict(
          device1List,
          device2List,
          conflict!.type,
        );

        final resolvedList = resolution.resolvedItem;

        // Verify no movies are lost
        final allOriginalMovies = originalMovieIds.toSet();
        final resolvedMovies = resolvedList.movieIds.toSet();

        expect(resolvedMovies, equals(allOriginalMovies));
        expect(resolvedList.movieIds.length, equals(20));

        // Verify latest metadata is preserved
        expect(resolvedList.description, equals('Updated description'));
        expect(resolvedList.emoji, equals('📖'));
        expect(resolvedList.color, equals('red'));
      });

      test('Validate conflict resolution preserves user intent', () async {
        final movie = Movie(
          id: 1005,
          title: 'The Godfather',
          overview: 'The aging patriarch of an organized crime dynasty',
          posterPath: '/3bhkrj58Vtu7enYsRolD1fZdja1.jpg',
          backdropPath: '/tmU7GeKVybMWFButWEGl2M4GeiP.jpg',
          releaseDate: DateTime(1972, 3, 24),
          voteAverage: 9.2,
          genreIds: ['80', '18'],
          adult: false,
          originalLanguage: 'en',
          originalTitle: 'The Godfather',
          popularity: 300.0,
          video: false,
          voteCount: 16000,
        );

        final baseTime = DateTime.now().subtract(Duration(minutes: 20));

        // User explicitly removes from favorites (clear intent)
        final userRemoval = SyncableFavoriteMovie.fromMovie(
          userId: 'user123',
          movie: movie,
          addedAt: baseTime.add(Duration(minutes: 10)),
        );
        final deletedUserRemoval = userRemoval.copyWith(
          isDeleted: true,
          updatedAt: DateTime.now(),
        );

        // System tries to re-add due to sync issue (should not override user intent)
        final systemAddition = SyncableFavoriteMovie.fromMovie(
          userId: 'user123',
          movie: movie,
          addedAt: baseTime.add(Duration(minutes: 5)), // Earlier timestamp
        );

        // Detect conflict
        final conflict = conflictDetector.detectConflict(
          systemAddition,
          deletedUserRemoval,
        );

        expect(conflict, isNotNull);
        expect(conflict!.type, equals(ConflictType.deletionVsModification));

        // Resolve conflict - user's deletion intent should be preserved
        final resolution = conflictResolver.resolveConflict(
          systemAddition,
          deletedUserRemoval,
          conflict.type,
        );

        expect(resolution.resolvedItem.isDeleted, isTrue);
        expect(resolution.resolution, equals('deletion_wins'));
      });
    });
  });
}
