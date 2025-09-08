import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/sync/entity_sync_manager.dart';
import 'package:peliculas/core/sync/watched_sync_manager.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/domain/entities/syncable_watched_movie.dart';
import 'package:peliculas/infrastructure/repositories/hybrid_watched_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Watched Movies Real-time Sync Integration Tests', () {
    late ProviderContainer container;
    late HybridWatchedRepository repository;
    late WatchedSyncManager syncManager;
    const String testUserId = 'test_user_123';

    setUp(() async {
      // Initialize shared preferences for testing
      SharedPreferences.setMockInitialValues({});

      container = ProviderContainer();

      // Initialize sync manager
      syncManager = WatchedSyncManager(userId: testUserId);

      // Initialize repository with sync manager
      repository = HybridWatchedRepository(
        userId: testUserId,
        syncManager: syncManager,
      );

      await repository.initializeLocal();
    });

    tearDown(() {
      container.dispose();
    });

    test('should create WatchedSyncManager with correct table name', () {
      expect(syncManager.userId, equals(testUserId));
      expect(syncManager.entityType, equals('watched_movie'));
    });

    test('should initialize HybridWatchedRepository with WatchedSyncManager',
        () {
      expect(repository.userId, equals(testUserId));
      expect(repository.tableName, equals('user_watched_movies'));
    });

    test(
        'should serialize and deserialize SyncableWatchedMovie for local storage',
        () {
      // Create test movie
      final testMovie = Movie(
        id: 123,
        title: 'Test Movie',
        adult: false,
        backdropPath: '/backdrop.jpg',
        genreIds: ['1', '2', '3'],
        originalLanguage: 'en',
        originalTitle: 'Test Movie Original',
        overview: 'Test movie overview',
        popularity: 7.5,
        posterPath: '/poster.jpg',
        releaseDate: DateTime(2023, 1, 1),
        video: false,
        voteAverage: 8.0,
        voteCount: 100,
      );

      // Create syncable watched movie
      final watchedMovie = SyncableWatchedMovie.fromMovie(
        userId: testUserId,
        movie: testMovie,
        watchedDate: DateTime(2023, 12, 1),
        personalRating: 4.5,
        personalNotes: 'Great movie!',
      );

      // Test local serialization
      final localData = syncManager.serializeForLocal(watchedMovie);
      expect(localData, isA<Map<String, dynamic>>());
      expect(localData['user_id'], equals(testUserId));
      expect(localData['movie_id'], equals(123));
      expect(localData['movie_title'], equals('Test Movie'));

      // Test local deserialization
      final deserializedLocal = syncManager.deserializeFromLocal(localData);
      expect(deserializedLocal.userId, equals(testUserId));
      expect(deserializedLocal.movieId, equals(123));
      expect(deserializedLocal.movieTitle, equals('Test Movie'));
      expect(deserializedLocal.personalRating, equals(4.5));
      expect(deserializedLocal.personalNotes, equals('Great movie!'));
    });

    test(
        'should serialize and deserialize SyncableWatchedMovie for remote storage',
        () {
      // Create test movie
      final testMovie = Movie(
        id: 456,
        title: 'Remote Test Movie',
        adult: false,
        backdropPath: '/remote_backdrop.jpg',
        genreIds: ['4', '5', '6'],
        originalLanguage: 'es',
        originalTitle: 'Película de Prueba Remota',
        overview: 'Overview of remote test movie',
        popularity: 6.8,
        posterPath: '/remote_poster.jpg',
        releaseDate: DateTime(2023, 6, 15),
        video: false,
        voteAverage: 7.2,
        voteCount: 50,
      );

      // Create syncable watched movie
      final watchedMovie = SyncableWatchedMovie.fromMovie(
        userId: testUserId,
        movie: testMovie,
        watchedDate: DateTime(2023, 12, 15),
        personalRating: 3.8,
        personalNotes: 'Not bad',
        watchedLocation: 'Cinema',
        rewatchCount: 1,
      );

      // Test remote serialization
      final remoteData = syncManager.serializeForRemote(watchedMovie);
      expect(remoteData, isA<Map<String, dynamic>>());
      expect(remoteData['user_id'], equals(testUserId));
      expect(remoteData['movie_id'], equals(456));
      expect(remoteData['movie_title'], equals('Remote Test Movie'));
      expect(remoteData['watched_location'], equals('Cinema'));
      expect(remoteData['rewatch_count'], equals(1));

      // Test remote deserialization
      final deserializedRemote = syncManager.deserializeFromRemote(remoteData);
      expect(deserializedRemote.userId, equals(testUserId));
      expect(deserializedRemote.movieId, equals(456));
      expect(deserializedRemote.movieTitle, equals('Remote Test Movie'));
      expect(deserializedRemote.personalRating, equals(3.8));
      expect(deserializedRemote.personalNotes, equals('Not bad'));
      expect(deserializedRemote.watchedLocation, equals('Cinema'));
      expect(deserializedRemote.rewatchCount, equals(1));
    });

    test('should handle watched movie operations through repository', () async {
      // Create test movie
      final testMovie = Movie(
        id: 789,
        title: 'Repository Test Movie',
        adult: false,
        backdropPath: '/repo_backdrop.jpg',
        genreIds: ['7', '8', '9'],
        originalLanguage: 'fr',
        originalTitle: 'Film de Test du Référentiel',
        overview: 'Repository test movie overview',
        popularity: 8.2,
        posterPath: '/repo_poster.jpg',
        releaseDate: DateTime(2023, 9, 10),
        video: false,
        voteAverage: 8.5,
        voteCount: 200,
      );

      // Test marking as watched
      await repository.markAsWatched(testMovie);

      // Test checking if movie is watched
      final isWatched = await repository.isMovieWatched(testMovie.id);
      expect(isWatched, isTrue);

      // Test getting watched movie by movie ID
      final watchedMovie =
          await repository.getWatchedMovieByMovieId(testMovie.id);
      expect(watchedMovie, isNotNull);
      expect(watchedMovie!.movieId, equals(testMovie.id));
      expect(watchedMovie.personalRating, equals(4.2));
      expect(watchedMovie.personalNotes, equals('Excellent film!'));

      // Test updating watched movie
      await repository.updateWatchedMovie(
        movieId: testMovie.id,
        rating: 4.8,
        review: 'Updated: Truly excellent!',
      );

      final updatedMovie =
          await repository.getWatchedMovieByMovieId(testMovie.id);
      expect(updatedMovie!.personalRating, equals(4.8));
      expect(updatedMovie.personalNotes, equals('Updated: Truly excellent!'));

      // Test unmarking as watched
      await repository.removeFromWatched(testMovie.id);
      final isStillWatched = await repository.isMovieWatched(testMovie.id);
      expect(isStillWatched, isFalse);
    });

    test('should get watched statistics', () async {
      // Add multiple watched movies
      for (int i = 1; i <= 5; i++) {
        final testMovie = Movie(
          id: i,
          title: 'Test Movie $i',
          adult: false,
          backdropPath: '',
          genreIds: [],
          originalLanguage: 'en',
          originalTitle: 'Test Movie $i',
          overview: '',
          popularity: 0.0,
          posterPath: '',
          releaseDate: DateTime.now(),
          video: false,
          voteAverage: 0.0,
          voteCount: 0,
        );
        await repository.markAsWatched(testMovie);
      }

      final stats = await repository.getWatchedStats();
      expect(stats['totalWatched'], equals(5));
      expect(stats['moviesWithRating'], equals(5));
      expect(stats['moviesWithReview'], equals(2)); // Movies 2 and 4
      expect(stats['averageRating'], equals(3.0)); // (1+2+3+4+5)/5 = 3.0
    });

    test('should get sorted watched movies', () async {
      // Add movies with different watched dates
      final dates = [
        DateTime(2023, 12, 5),
        DateTime(2023, 12, 1),
        DateTime(2023, 12, 10),
        DateTime(2023, 12, 3),
      ];

      for (int i = 0; i < dates.length; i++) {
        final testMovie = Movie(
          id: 100 + i,
          title: 'Sorted Test Movie ${100 + i}',
          adult: false,
          backdropPath: '',
          genreIds: [],
          originalLanguage: 'en',
          originalTitle: 'Sorted Test Movie ${100 + i}',
          overview: '',
          popularity: 0.0,
          posterPath: '',
          releaseDate: DateTime.now(),
          video: false,
          voteAverage: 0.0,
          voteCount: 0,
        );
        await repository.markAsWatched(testMovie);
      }

      // Test descending order (default)
      final sortedDesc = await repository.getWatchedMoviesSorted();
      expect(sortedDesc.length, equals(4));
      expect(sortedDesc[0].watchedDate,
          equals(DateTime(2023, 12, 10))); // Latest first
      expect(sortedDesc[3].watchedDate,
          equals(DateTime(2023, 12, 1))); // Earliest last

      // Test ascending order
      final sortedAsc =
          await repository.getWatchedMoviesSorted(ascending: true);
      expect(sortedAsc.length, equals(4));
      expect(sortedAsc[0].watchedDate,
          equals(DateTime(2023, 12, 1))); // Earliest first
      expect(sortedAsc[3].watchedDate,
          equals(DateTime(2023, 12, 10))); // Latest last
    });

    test('should handle conflict resolution with last write wins strategy',
        () async {
      // Create two versions of the same watched movie with different timestamps
      final movie = Movie(
        id: 999,
        title: 'Conflict Test Movie',
        adult: false,
        backdropPath: '',
        genreIds: [],
        originalLanguage: 'en',
        originalTitle: 'Conflict Test Movie',
        overview: '',
        popularity: 0.0,
        posterPath: '',
        releaseDate: DateTime.now(),
        video: false,
        voteAverage: 0.0,
        voteCount: 0,
      );

      final earlierTime = DateTime(2023, 12, 1, 10, 0, 0);
      final laterTime = DateTime(2023, 12, 1, 11, 0, 0);

      final localEntity = SyncableWatchedMovie.fromMovie(
        userId: testUserId,
        movie: movie,
        watchedDate: earlierTime,
        personalRating: 3.0,
        personalNotes: 'Local version',
      ).copyWithData(lastModifiedAt: earlierTime);

      final remoteEntity = SyncableWatchedMovie.fromMovie(
        userId: testUserId,
        movie: movie,
        watchedDate: laterTime,
        personalRating: 4.0,
        personalNotes: 'Remote version',
      ).copyWithData(lastModifiedAt: laterTime);

      // Create conflict info
      final conflict = ConflictInfo<SyncableWatchedMovie>(
        localEntity: localEntity,
        remoteEntity: remoteEntity,
        conflictType: ConflictType.concurrentModification,
        detectedAt: DateTime.now(),
      );

      // Resolve conflict - should choose remote (later timestamp)
      final resolved = await syncManager.resolveConflict(conflict);
      expect(resolved.personalRating, equals(4.0));
      expect(resolved.personalNotes, equals('Remote version'));
      expect(resolved.lastModifiedAt, equals(laterTime));
    });
  });
}
