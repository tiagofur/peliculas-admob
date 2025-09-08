import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/sync/entity_sync_manager.dart';
import 'package:peliculas/core/sync/watched_sync_manager.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/domain/entities/syncable_watched_movie.dart';
import 'package:peliculas/presentation/providers/hybrid_repositories_provider.dart';
import 'package:peliculas/presentation/providers/watched_movies_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Watched Movies Real-time Sync Integration Tests', () {
    late ProviderContainer container;
    const String testUserId = 'integration_test_user';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWithValue(testUserId),
      ]);
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('Complete watched movies sync flow integration test',
        (tester) async {
      // Get repository and notifier
      final repository = container.read(hybridWatchedRepositoryProvider);
      final notifier = container.read(watchedMoviesProvider.notifier);

      await repository.initializeLocal();

      // Create test movie
      final testMovie = Movie(
        id: 7001,
        title: 'Integration Test Movie',
        adult: false,
        backdropPath: '/integration_backdrop.jpg',
        genreIds: ['1', '2', '3'],
        originalLanguage: 'en',
        originalTitle: 'Integration Test Movie',
        overview: 'Testing complete integration flow',
        popularity: 8.8,
        posterPath: '/integration_poster.jpg',
        releaseDate: DateTime(2023, 5, 20),
        video: false,
        voteAverage: 8.7,
        voteCount: 250,
      );

      // Test: Mark movie as watched through UI provider
      await notifier.markAsWatched(testMovie);

      // Verify: Movie is marked as watched
      final isWatched = await repository.isMovieWatched(testMovie.id);
      expect(isWatched, isTrue);

      // Verify: Movie appears in watched list
      final watchedMovie =
          await repository.getWatchedMovieByMovieId(testMovie.id);
      expect(watchedMovie, isNotNull);
      expect(watchedMovie!.movieId, equals(testMovie.id));
      expect(watchedMovie.movieTitle, equals(testMovie.title));

      // Test: Remove movie from watched through UI provider
      await notifier.removeFromWatched(testMovie.id);

      // Verify: Movie is no longer watched
      final isStillWatched = await repository.isMovieWatched(testMovie.id);
      expect(isStillWatched, isFalse);
    });

    test('Sync manager queue operations work correctly', () async {
      final syncManager = WatchedSyncManager(userId: testUserId);

      // Create test watched movie
      final testMovie = Movie(
        id: 7002,
        title: 'Queue Test Movie',
        adult: false,
        backdropPath: '/queue_backdrop.jpg',
        genreIds: ['4', '5'],
        originalLanguage: 'es',
        originalTitle: 'Película de Prueba de Cola',
        overview: 'Testing queue operations',
        popularity: 7.3,
        posterPath: '/queue_poster.jpg',
        releaseDate: DateTime(2023, 4, 8),
        video: false,
        voteAverage: 7.1,
        voteCount: 120,
      );

      final watchedMovie = SyncableWatchedMovie.fromMovie(
        userId: testUserId,
        movie: testMovie,
        watchedDate: DateTime(2023, 12, 29),
        personalRating: 3.8,
        personalNotes: 'Good movie for testing',
      );

      // Test: Add watched movie to sync queue
      await syncManager.addWatchedMovie(watchedMovie);

      // Test: Process queued operations
      final queueResult = await syncManager.processQueuedOperations();
      expect(queueResult.success, isTrue);
      expect(queueResult.itemsProcessed, greaterThanOrEqualTo(0));

      // Test: Remove watched movie from sync queue
      await syncManager.removeWatchedMovie(watchedMovie.id);

      // Test: Process removal queue
      final removalResult = await syncManager.processQueuedOperations();
      expect(removalResult.success, isTrue);
    });

    test('Conflict detection and resolution works', () async {
      final syncManager = WatchedSyncManager(userId: testUserId);

      // Test conflict detection (should return empty list for now)
      final conflicts = await syncManager.detectConflicts();
      expect(conflicts, isEmpty);

      // Create test conflict scenario
      final testMovie = Movie(
        id: 7003,
        title: 'Conflict Resolution Movie',
        adult: false,
        backdropPath: '/conflict_res_backdrop.jpg',
        genreIds: ['6', '7'],
        originalLanguage: 'fr',
        originalTitle: 'Film de Résolution de Conflit',
        overview: 'Testing conflict resolution',
        popularity: 6.9,
        posterPath: '/conflict_res_poster.jpg',
        releaseDate: DateTime(2023, 3, 15),
        video: false,
        voteAverage: 6.8,
        voteCount: 85,
      );

      final earlierTime = DateTime(2023, 12, 29, 14, 0);
      final laterTime = DateTime(2023, 12, 29, 15, 0);

      final localEntity = SyncableWatchedMovie.fromMovie(
        userId: testUserId,
        movie: testMovie,
        watchedDate: earlierTime,
        personalRating: 2.5,
        personalNotes: 'Local version',
      ).copyWithData(lastModifiedAt: earlierTime);

      final remoteEntity = SyncableWatchedMovie.fromMovie(
        userId: testUserId,
        movie: testMovie,
        watchedDate: laterTime,
        personalRating: 4.2,
        personalNotes: 'Remote version',
      ).copyWithData(lastModifiedAt: laterTime);

      final conflict = ConflictInfo<SyncableWatchedMovie>(
        localEntity: localEntity,
        remoteEntity: remoteEntity,
        conflictType: ConflictType.concurrentModification,
        detectedAt: DateTime.now(),
      );

      // Test conflict resolution
      final resolved = await syncManager.resolveConflict(conflict);

      // Should choose remote version (later timestamp)
      expect(resolved.personalRating, equals(4.2));
      expect(resolved.personalNotes, equals('Remote version'));
      expect(resolved.lastModifiedAt, equals(laterTime));
    });

    test('Provider state management works correctly', () async {
      final notifier = container.read(watchedMoviesProvider.notifier);
      final initialState = container.read(watchedMoviesProvider);

      // Initial state should be empty
      expect(initialState.movies, isEmpty);
      expect(initialState.isLoading, isFalse);
      expect(initialState.currentPage, equals(0));
      expect(initialState.isLastPage, isFalse);

      // Test refresh functionality
      await notifier.refresh();

      // State should still be valid after refresh
      final refreshedState = container.read(watchedMoviesProvider);
      expect(refreshedState.movies, isA<List<SyncableWatchedMovie>>());
      expect(refreshedState.currentPage, greaterThanOrEqualTo(0));
    });

    test('Upload and download changes work correctly', () async {
      final syncManager = WatchedSyncManager(userId: testUserId);

      // Create test watched movies
      final testMovies = [
        Movie(
          id: 7004,
          title: 'Upload Test Movie 1',
          adult: false,
          backdropPath: '/upload1_backdrop.jpg',
          genreIds: ['8'],
          originalLanguage: 'en',
          originalTitle: 'Upload Test Movie 1',
          overview: 'Testing upload 1',
          popularity: 5.5,
          posterPath: '/upload1_poster.jpg',
          releaseDate: DateTime(2023, 2, 10),
          video: false,
          voteAverage: 5.3,
          voteCount: 30,
        ),
        Movie(
          id: 7005,
          title: 'Upload Test Movie 2',
          adult: false,
          backdropPath: '/upload2_backdrop.jpg',
          genreIds: ['9'],
          originalLanguage: 'en',
          originalTitle: 'Upload Test Movie 2',
          overview: 'Testing upload 2',
          popularity: 6.2,
          posterPath: '/upload2_poster.jpg',
          releaseDate: DateTime(2023, 2, 12),
          video: false,
          voteAverage: 6.0,
          voteCount: 45,
        ),
      ];

      final watchedMovies = testMovies
          .map((movie) => SyncableWatchedMovie.fromMovie(
                userId: testUserId,
                movie: movie,
                watchedDate: DateTime(2023, 12, 30),
                personalRating: 4.0,
                personalNotes: 'Upload test',
              ))
          .toList();

      // Test upload changes
      final uploadResult = await syncManager.uploadChanges(watchedMovies);
      expect(uploadResult.success, isTrue);
      expect(uploadResult.itemsProcessed, equals(2));
      expect(uploadResult.errors, isEmpty);

      // Test download changes (empty list for mock scenario)
      final downloadResult = await syncManager.downloadChanges([]);
      expect(downloadResult.success, isTrue);
      expect(downloadResult.itemsProcessed, equals(0));
    });

    test('Data serialization maintains integrity', () async {
      final syncManager = WatchedSyncManager(userId: testUserId);

      final testMovie = Movie(
        id: 7006,
        title: 'Serialization Test Movie',
        adult: false,
        backdropPath: '/serialization_backdrop.jpg',
        genreIds: ['10', '11', '12'],
        originalLanguage: 'de',
        originalTitle: 'Serialisierungstest Film',
        overview: 'Testing data serialization integrity',
        popularity: 7.8,
        posterPath: '/serialization_poster.jpg',
        releaseDate: DateTime(2023, 1, 25),
        video: false,
        voteAverage: 7.6,
        voteCount: 180,
      );

      final originalWatched = SyncableWatchedMovie.fromMovie(
        userId: testUserId,
        movie: testMovie,
        watchedDate: DateTime(2023, 12, 31, 23, 59),
        personalRating: 4.9,
        personalNotes: 'Amazing serialization test!',
        watchedLocation: 'Test Cinema',
        rewatchCount: 2,
      );

      // Test local serialization roundtrip
      final localData = syncManager.serializeForLocal(originalWatched);
      final localDeserialized = syncManager.deserializeFromLocal(localData);

      expect(localDeserialized.id, equals(originalWatched.id));
      expect(localDeserialized.userId, equals(originalWatched.userId));
      expect(localDeserialized.movieId, equals(originalWatched.movieId));
      expect(localDeserialized.movieTitle, equals(originalWatched.movieTitle));
      expect(localDeserialized.personalRating,
          equals(originalWatched.personalRating));
      expect(localDeserialized.personalNotes,
          equals(originalWatched.personalNotes));
      expect(localDeserialized.watchedLocation,
          equals(originalWatched.watchedLocation));
      expect(
          localDeserialized.rewatchCount, equals(originalWatched.rewatchCount));

      // Test remote serialization roundtrip
      final remoteData = syncManager.serializeForRemote(originalWatched);
      final remoteDeserialized = syncManager.deserializeFromRemote(remoteData);

      expect(remoteDeserialized.id, equals(originalWatched.id));
      expect(remoteDeserialized.userId, equals(originalWatched.userId));
      expect(remoteDeserialized.movieId, equals(originalWatched.movieId));
      expect(remoteDeserialized.movieTitle, equals(originalWatched.movieTitle));
      expect(remoteDeserialized.personalRating,
          equals(originalWatched.personalRating));
      expect(remoteDeserialized.personalNotes,
          equals(originalWatched.personalNotes));
      expect(remoteDeserialized.watchedLocation,
          equals(originalWatched.watchedLocation));
      expect(remoteDeserialized.rewatchCount,
          equals(originalWatched.rewatchCount));
    });
  });
}
