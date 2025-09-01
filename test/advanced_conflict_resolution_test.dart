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
import 'package:peliculas/domain/entities/watched_movie.dart';
// Removed unused import
import 'package:peliculas/infrastructure/sync/conflict_statistics_service.dart';

/// Pruebas avanzadas para el sistema de resolución de conflictos multiplataforma
void main() {
  group('Advanced Conflict Resolution System Tests', () {
    // Removed unused severityClassifier
    late ConflictStatisticsService statisticsService;
    late ConflictDetector conflictDetector;
    late MultiplataformConflictResolver conflictResolver;
    late SoftDeleteManager softDeleteManager;

    setUp(() {
      // Removed unused severityClassifier
      statisticsService = ConflictStatisticsService();
      conflictDetector = ConflictDetector(
        softDeleteManager,
        statisticsService,
      );
      conflictResolver = MultiplataformConflictResolver();
      softDeleteManager = SoftDeleteManager();

      // Registrar estrategias
      conflictResolver.registerStrategy<SyncableFavoriteMovie>(
        FavoritesConflictStrategy(),
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

    group('Conflict Detection Tests', () {
      test('should detect deletion vs modification conflict', () async {
        final movie = Movie(
          id: 1,
          title: 'Test Movie',
          overview: 'Test overview',
          posterPath: '/test.jpg',
          backdropPath: '/test_backdrop.jpg',
          releaseDate: DateTime.now(),
          voteAverage: 7.5,
          genreIds: ['18'],
          adult: false,
          originalLanguage: 'en',
          originalTitle: 'Test Movie',
          popularity: 100.0,
          video: false,
          voteCount: 1000,
        );

        final localFavorite = SyncableFavoriteMovie.fromMovie(
          userId: 'user1',
          movie: movie,
          addedAt: DateTime.now().subtract(Duration(minutes: 5)),
        );

        final remoteFavorite = SyncableFavoriteMovie.fromMovie(
          userId: 'user1',
          movie: movie,
          addedAt: DateTime.now().subtract(Duration(minutes: 3)),
        );
        final deletedRemoteFavorite = remoteFavorite.copyWith(
          isDeleted: true,
          updatedAt: DateTime.now(),
        );

        final conflict = conflictDetector.detectConflict(
          localFavorite,
          deletedRemoteFavorite,
        );

        expect(conflict, isNotNull);
        expect(conflict!.type, equals(ConflictType.deletionVsModification));
        expect(conflict.severity, equals(ConflictSeverity.high));
      });

      test('should detect simultaneous modification conflict', () async {
        final movie = Movie(
          id: 2,
          title: 'Test Movie 2',
          overview: 'Test overview 2',
          posterPath: '/test2.jpg',
          backdropPath: '/test2_backdrop.jpg',
          releaseDate: DateTime.now(),
          voteAverage: 8.0,
          genreIds: ['28'],
          adult: false,
          originalLanguage: 'en',
          originalTitle: 'Test Movie 2',
          popularity: 150.0,
          video: false,
          voteCount: 2000,
        );

        final baseTime = DateTime.now().subtract(Duration(minutes: 10));

        final localWatchedMovie = WatchedMovie(
          movie: movie,
          watchedDate: baseTime.add(Duration(minutes: 2)),
        );

        final remoteWatchedMovie = WatchedMovie(
          movie: movie,
          watchedDate: baseTime.add(Duration(minutes: 3)),
        );

        final localWatched = SyncableWatchedMovie.fromWatchedMovie(
          localWatchedMovie,
          'user1',
        );

        final remoteWatched = SyncableWatchedMovie.fromWatchedMovie(
          remoteWatchedMovie,
          'user1',
        );

        final conflict = conflictDetector.detectConflict(
          localWatched,
          remoteWatched,
        );

        expect(conflict, isNotNull);
        expect(conflict!.type, equals(ConflictType.simultaneousModification));
      });

      test('should not detect conflict for identical items', () async {
        final movie = Movie(
          id: 3,
          title: 'Identical Movie',
          overview: 'Same overview',
          posterPath: '/same.jpg',
          backdropPath: '/same_backdrop.jpg',
          releaseDate: DateTime.now(),
          voteAverage: 6.5,
          genreIds: ['35'],
          adult: false,
          originalLanguage: 'en',
          originalTitle: 'Identical Movie',
          popularity: 75.0,
          video: false,
          voteCount: 500,
        );

        final timestamp = DateTime.now();

        final localFavorite = SyncableFavoriteMovie.fromMovie(
          userId: 'user1',
          movie: movie,
          addedAt: timestamp,
        );

        final remoteFavorite = SyncableFavoriteMovie.fromMovie(
          userId: 'user1',
          movie: movie,
          addedAt: timestamp,
        );

        final conflict = conflictDetector.detectConflict(
          localFavorite,
          remoteFavorite,
        );

        expect(conflict, isNull);
      });
    });

    group('Conflict Resolution Tests', () {
      test('should resolve deletion vs modification - deletion wins', () async {
        final movie = Movie(
          id: 4,
          title: 'Resolution Test',
          overview: 'Test resolution',
          posterPath: '/resolution.jpg',
          backdropPath: '/resolution_backdrop.jpg',
          releaseDate: DateTime.now(),
          voteAverage: 7.0,
          genreIds: ['18', '35'],
          adult: false,
          originalLanguage: 'en',
          originalTitle: 'Resolution Test',
          popularity: 90.0,
          video: false,
          voteCount: 750,
        );

        final localFavorite = SyncableFavoriteMovie.fromMovie(
          userId: 'user1',
          movie: movie,
          addedAt: DateTime.now().subtract(Duration(minutes: 5)),
        );

        final remoteFavorite = SyncableFavoriteMovie.fromMovie(
          userId: 'user1',
          movie: movie,
          addedAt: DateTime.now().subtract(Duration(minutes: 3)),
        );
        final deletedRemoteFavorite2 = remoteFavorite.copyWith(
          isDeleted: true,
          updatedAt: DateTime.now(),
        );

        final conflict = conflictDetector.detectConflict(
          localFavorite,
          deletedRemoteFavorite2,
        );

        expect(conflict, isNotNull);

        final resolution = conflictResolver.resolveConflict(
          localFavorite,
          deletedRemoteFavorite2,
          conflict!.type,
        );

        expect(resolution.resolvedItem.isDeleted, isTrue);
        expect(resolution.resolution, equals('deletion_wins'));
      });

      test('should resolve simultaneous modification - latest timestamp wins',
          () async {
        final movie = Movie(
          id: 5,
          title: 'Timestamp Test',
          overview: 'Test timestamps',
          posterPath: '/timestamp.jpg',
          backdropPath: '/timestamp_backdrop.jpg',
          releaseDate: DateTime.now(),
          voteAverage: 8.5,
          genreIds: ['28', '12'],
          adult: false,
          originalLanguage: 'en',
          originalTitle: 'Timestamp Test',
          popularity: 120.0,
          video: false,
          voteCount: 1500,
        );

        final baseTime = DateTime.now().subtract(Duration(minutes: 10));

        final localWatchedMovie = WatchedMovie(
          movie: movie,
          watchedDate: baseTime.add(Duration(minutes: 2)), // Older
        );

        final remoteWatchedMovie = WatchedMovie(
          movie: movie,
          watchedDate: baseTime.add(Duration(minutes: 5)), // Newer
        );

        final localWatched = SyncableWatchedMovie.fromWatchedMovie(
          localWatchedMovie,
          'user1',
        );

        final remoteWatched = SyncableWatchedMovie.fromWatchedMovie(
          remoteWatchedMovie,
          'user1',
        );

        final conflict = conflictDetector.detectConflict(
          localWatched,
          remoteWatched,
        );

        expect(conflict, isNotNull);

        final resolution = conflictResolver.resolveConflict(
          localWatched,
          remoteWatched,
          conflict!.type,
        );

        final resolvedWatched = resolution.resolvedItem;
        expect(resolvedWatched.updatedAt, equals(remoteWatched.updatedAt));
        expect(resolution.resolution, equals('latest_timestamp_wins'));
      });

      test('should handle custom list conflicts with item merging', () async {
        final baseTime = DateTime.now().subtract(Duration(minutes: 10));

        final localList = SyncableCustomList.fromCustomList(
          CustomList(
            id: 'test-list',
            name: 'Test List',
            description: 'Local description',
            emoji: '🎬',
            movieIds: [1, 2, 3],
            createdAt: baseTime,
            updatedAt: baseTime.add(Duration(minutes: 2)),
            color: 'blue',
          ),
          'user1',
        );

        final remoteList = SyncableCustomList.fromCustomList(
          CustomList(
            id: 'test-list',
            name: 'Test List',
            description: 'Remote description',
            emoji: '🎭',
            movieIds: [2, 3, 4, 5],
            createdAt: baseTime,
            updatedAt: baseTime.add(Duration(minutes: 3)),
            color: 'red',
          ),
          'user1',
        );

        final conflict = conflictDetector.detectConflict(
          localList,
          remoteList,
        );

        expect(conflict, isNotNull);

        final resolution = conflictResolver.resolveConflict(
          localList,
          remoteList,
          conflict!.type,
        );

        final resolvedList = resolution.resolvedItem;

        // Should use latest metadata but merge movie IDs
        expect(resolvedList.description, equals('Remote description'));
        expect(resolvedList.emoji, equals('🎭'));
        expect(resolvedList.color, equals('red'));
        expect(resolvedList.movieIds, containsAll([1, 2, 3, 4, 5]));
      });
    });

    group('Conflict Statistics Tests', () {
      test('should track conflict statistics', () async {
        final movie = Movie(
          id: 6,
          title: 'Stats Test',
          overview: 'Test statistics',
          posterPath: '/stats.jpg',
          backdropPath: '/stats_backdrop.jpg',
          releaseDate: DateTime.now(),
          voteAverage: 7.2,
          genreIds: ['18'],
          adult: false,
          originalLanguage: 'en',
          originalTitle: 'Stats Test',
          popularity: 80.0,
          video: false,
          voteCount: 600,
        );

        final localFavorite = SyncableFavoriteMovie.fromMovie(
          userId: 'user1',
          movie: movie,
          addedAt: DateTime.now().subtract(Duration(minutes: 5)),
        );

        final remoteFavorite = SyncableFavoriteMovie.fromMovie(
          userId: 'user1',
          movie: movie,
          addedAt: DateTime.now().subtract(Duration(minutes: 3)),
        );
        final deletedRemoteFavorite3 = remoteFavorite.copyWith(
          isDeleted: true,
          updatedAt: DateTime.now(),
        );

        // Detect conflict
        final conflict = conflictDetector.detectConflict(
          localFavorite,
          deletedRemoteFavorite3,
        );

        expect(conflict, isNotNull);

        // Resolve conflict
        final resolution = conflictResolver.resolveConflict(
          localFavorite,
          deletedRemoteFavorite3,
          conflict!.type,
        );

        // Record resolution
        final conflictId =
            'conflict_${localFavorite.id}_${conflict.detectedAt.millisecondsSinceEpoch}';
        statisticsService.recordConflictResolved(
          conflictId,
          resolution.resolution,
          true, // wasAutoResolved
        );

        final stats = statisticsService.getStatistics();

        expect(stats.totalConflicts, greaterThan(0));
        expect(stats.conflictsByType[ConflictType.modificationVsDeletion],
            greaterThan(0));
      });

      test('should detect conflict patterns', () async {
        // Simulate multiple similar conflicts
        for (int i = 0; i < 5; i++) {
          final movie = Movie(
            id: 100 + i,
            title: 'Pattern Test $i',
            overview: 'Test pattern $i',
            posterPath: '/pattern$i.jpg',
            backdropPath: '/pattern${i}_backdrop.jpg',
            releaseDate: DateTime.now(),
            voteAverage: 7.0 + i * 0.1,
            genreIds: ['18'],
            adult: false,
            originalLanguage: 'en',
            originalTitle: 'Pattern Test $i',
            popularity: 70.0 + i * 5,
            video: false,
            voteCount: 500 + i * 100,
          );

          final localFavorite = SyncableFavoriteMovie.fromMovie(
            userId: 'user1',
            movie: movie,
            addedAt: DateTime.now().subtract(Duration(minutes: 5)),
          );

          final remoteFavorite = SyncableFavoriteMovie.fromMovie(
            userId: 'user1',
            movie: movie,
            addedAt: DateTime.now().subtract(Duration(minutes: 3)),
          );
          final deletedRemoteFavorite4 = remoteFavorite.copyWith(
            isDeleted: true,
            updatedAt: DateTime.now(),
          );

          final conflict = conflictDetector.detectConflict(
            localFavorite,
            deletedRemoteFavorite4,
          );

          if (conflict != null) {
            final resolution = conflictResolver.resolveConflict(
              localFavorite,
              deletedRemoteFavorite4,
              conflict.type,
            );

            final conflictId =
                'conflict_${localFavorite.id}_${conflict.detectedAt.millisecondsSinceEpoch}';
            statisticsService.recordConflictResolved(
              conflictId,
              resolution.resolution,
              true, // wasAutoResolved
            );
          }
        }

        final patterns = statisticsService.analyzePatterns();

        expect(patterns, isNotEmpty);
        expect(patterns.first.primaryType,
            equals(ConflictType.modificationVsDeletion));
        expect(patterns.first.occurrences, greaterThanOrEqualTo(5));
      });
    });

    group('Soft Delete Manager Tests', () {
      test('should handle soft delete propagation', () async {
        final movie = Movie(
          id: 7,
          title: 'Soft Delete Test',
          overview: 'Test soft delete',
          posterPath: '/softdelete.jpg',
          backdropPath: '/softdelete_backdrop.jpg',
          releaseDate: DateTime.now(),
          voteAverage: 6.8,
          genreIds: ['35'],
          adult: false,
          originalLanguage: 'en',
          originalTitle: 'Soft Delete Test',
          popularity: 65.0,
          video: false,
          voteCount: 400,
        );

        final favorite = SyncableFavoriteMovie.fromMovie(
          userId: 'user1',
          movie: movie,
          addedAt: DateTime.now(),
        );

        // Mark as soft deleted
        softDeleteManager.markAsDeleted(favorite);

        expect(favorite.isDeleted, isTrue);
        expect(favorite.isDeleted, isTrue);
      });

      test('should prevent resurrection of deleted items', () async {
        final movie = Movie(
          id: 8,
          title: 'Resurrection Test',
          overview: 'Test resurrection prevention',
          posterPath: '/resurrection.jpg',
          backdropPath: '/resurrection_backdrop.jpg',
          releaseDate: DateTime.now(),
          voteAverage: 7.5,
          genreIds: ['28'],
          adult: false,
          originalLanguage: 'en',
          originalTitle: 'Resurrection Test',
          popularity: 95.0,
          video: false,
          voteCount: 800,
        );

        final deletedFavorite = SyncableFavoriteMovie.fromMovie(
          userId: 'user1',
          movie: movie,
          addedAt: DateTime.now().subtract(Duration(hours: 1)),
        );
        final actualDeletedFavorite = deletedFavorite.copyWith(
          isDeleted: true,
          updatedAt: DateTime.now(),
        );

        final newFavorite = SyncableFavoriteMovie.fromMovie(
          userId: 'user1',
          movie: movie,
          addedAt: DateTime.now().subtract(Duration(minutes: 30)),
        );

        final shouldPrevent = softDeleteManager.shouldPreventResurrection(
          actualDeletedFavorite,
          newFavorite,
        );

        expect(shouldPrevent, isTrue);
      });
    });
  });
}
