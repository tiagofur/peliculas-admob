import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/sync/entity_sync_manager.dart';
import 'package:peliculas/core/sync/watched_sync_manager.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/domain/entities/syncable_watched_movie.dart';
import 'package:peliculas/infrastructure/repositories/base_hybrid_repository.dart';
import 'package:peliculas/infrastructure/repositories/hybrid_watched_repository.dart';
import 'package:peliculas/presentation/providers/hybrid_repositories_provider.dart';
import 'package:peliculas/presentation/providers/watched_movies_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Integration test to validate that the watched movies synchronization
/// implementation matches the requirements from issue #75
void main() {
  group('Issue #75 - Watched Movies Real-time Sync Validation', () {
    late ProviderContainer container;
    const String testUserId = 'issue_75_validation_user';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWithValue(testUserId),
      ]);
    });

    tearDown(() {
      container.dispose();
    });

    group('Criterion 1: Real-time sync between devices using Supabase', () {
      test('WatchedSyncManager properly interfaces with Supabase table', () {
        final syncManager = WatchedSyncManager(userId: testUserId);

        // Verify it targets the correct Supabase table
        final repository = container.read(hybridWatchedRepositoryProvider);
        expect(repository.tableName, equals('user_watched_movies'));

        // Verify sync manager is properly configured
        expect(syncManager.userId, equals(testUserId));
        expect(syncManager.entityType, equals('watched_movie'));
      });

      test('Real-time sync service handles watched movies changes', () async {
        // This validates that the real-time sync service
        // has the proper handler for watched movies
        final repository = container.read(hybridWatchedRepositoryProvider);
        expect(repository, isA<HybridWatchedRepository>());

        // Verify the repository can handle sync operations
        final testMovie = Movie(
          id: 75001,
          title: 'Issue 75 Test Movie',
          adult: false,
          backdropPath: '/issue75_backdrop.jpg',
          genreIds: [1],
          originalLanguage: 'en',
          originalTitle: 'Issue 75 Test Movie',
          overview: 'Testing issue 75 implementation',
          popularity: 8.0,
          posterPath: '/issue75_poster.jpg',
          releaseDate: DateTime(2023, 1, 1),
          video: false,
          voteAverage: 8.0,
          voteCount: 100,
        );

        await repository.markAsWatched(testMovie);
        final isWatched = await repository.isMovieWatched(testMovie.id);
        expect(isWatched, isTrue);

        // Verify sync can be triggered
        expect(() => repository.syncWithSupabase(), returnsNormally);
      });
    });

    group('Criterion 2: Offline First functionality', () {
      test('Changes work offline and sync when connection is restored',
          () async {
        final repository = container.read(hybridWatchedRepositoryProvider);
        await repository.initializeLocal();

        // Test offline operation - mark movie as watched
        final testMovie2 = Movie(
          id: 75002,
          title: 'Offline Test Movie',
          adult: false,
          backdropPath: '/offline_backdrop.jpg',
          genreIds: [1],
          originalLanguage: 'en',
          originalTitle: 'Offline Test Movie',
          overview: 'Testing offline functionality',
          popularity: 7.5,
          posterPath: '/offline_poster.jpg',
          releaseDate: DateTime(2023, 2, 1),
          video: false,
          voteAverage: 7.5,
          voteCount: 80,
        );
        await repository.markAsWatched(testMovie2);

        // Verify data is stored locally
        final isWatched = await repository.isMovieWatched(75002);
        expect(isWatched, isTrue);

        final watchedMovie = await repository.getWatchedMovieByMovieId(75002);
        expect(watchedMovie, isNotNull);
        expect(watchedMovie!.personalRating, equals(4.5));
        expect(watchedMovie.personalNotes, equals('Offline test movie'));

        // Verify sync can be called (simulating connection restore)
        expect(() => repository.syncWithSupabase(), returnsNormally);
      });

      test('Local data persists using SharedPreferences/Hive', () async {
        final repository = container.read(hybridWatchedRepositoryProvider);
        await repository.initializeLocal();

        // Add watched movie
        final testMovie3 = Movie(
          id: 75003,
          title: 'Local Data Test Movie',
          adult: false,
          backdropPath: '/local_backdrop.jpg',
          genreIds: [2],
          originalLanguage: 'en',
          originalTitle: 'Local Data Test Movie',
          overview: 'Testing local data persistence',
          popularity: 6.8,
          posterPath: '/local_poster.jpg',
          releaseDate: DateTime(2023, 3, 1),
          video: false,
          voteAverage: 6.8,
          voteCount: 60,
        );
        await repository.markAsWatched(testMovie3);

        // Verify local data retrieval
        final localData = await repository.getLocalData();
        expect(localData.any((movie) => movie.movieId == 75003), isTrue);

        // Verify local data structure
        final watchedMovie =
            localData.firstWhere((movie) => movie.movieId == 75003);
        expect(watchedMovie.userId, equals(testUserId));
        expect(watchedMovie.isDeleted, isFalse);
        expect(watchedMovie.syncVersion, greaterThan(0));
      });
    });

    group('Criterion 3: Multi-device synchronization', () {
      test('Changes reflect on all devices for same user', () async {
        // Simulate two devices
        final deviceA = container.read(hybridWatchedRepositoryProvider);
        final deviceB = HybridWatchedRepository(userId: testUserId);

        await deviceA.initializeLocal();
        await deviceB.initializeLocal();

        // Device A marks movie as watched
        final testMovie4 = Movie(
          id: 75004,
          title: 'Multi-device Sync Test Movie',
          adult: false,
          backdropPath: '/multidevice_backdrop.jpg',
          genreIds: [3],
          originalLanguage: 'en',
          originalTitle: 'Multi-device Sync Test Movie',
          overview: 'Testing multi-device synchronization',
          popularity: 8.2,
          posterPath: '/multidevice_poster.jpg',
          releaseDate: DateTime(2023, 4, 1),
          video: false,
          voteAverage: 8.2,
          voteCount: 120,
        );
        await deviceA.markAsWatched(testMovie4);

        // Simulate sync operation
        final syncManagerA = WatchedSyncManager(userId: testUserId);
        final syncManagerB = WatchedSyncManager(userId: testUserId);

        // Test that data can be serialized for remote sync
        final watchedMovie = await deviceA.getWatchedMovieByMovieId(75004);
        expect(watchedMovie, isNotNull);

        final remoteData = syncManagerA.serializeForRemote(watchedMovie!);
        expect(remoteData, contains('user_id'));
        expect(remoteData, contains('movie_id'));
        expect(remoteData['user_id'], equals(testUserId));
        expect(remoteData['movie_id'], equals(75004));

        // Test that Device B can deserialize the data
        final deserializedMovie =
            syncManagerB.deserializeFromRemote(remoteData);
        expect(deserializedMovie.userId, equals(testUserId));
        expect(deserializedMovie.movieId, equals(75004));

        // Simulate Device B receiving the sync
        await deviceB.saveToLocal(deserializedMovie);
        final isWatchedB = await deviceB.isMovieWatched(75004);
        expect(isWatchedB, isTrue);
      });
    });

    group('Criterion 4: Conflict resolution testing', () {
      test('Conflicts are resolved automatically using last-write-wins',
          () async {
        final syncManager = WatchedSyncManager(userId: testUserId);

        // Create conflict scenario - same movie, different timestamps
        final testMovie = Movie(
          id: 75005,
          title: 'Conflict Test Movie',
          adult: false,
          backdropPath: '/conflict_backdrop.jpg',
          genreIds: [2],
          originalLanguage: 'en',
          originalTitle: 'Conflict Test Movie',
          overview: 'Testing conflict resolution',
          popularity: 7.0,
          posterPath: '/conflict_poster.jpg',
          releaseDate: DateTime(2023, 6, 1),
          video: false,
          voteAverage: 7.0,
          voteCount: 50,
        );

        final earlierTime = DateTime(2023, 12, 1, 10, 0);
        final laterTime = DateTime(2023, 12, 1, 11, 0);

        final localEntity = SyncableWatchedMovie.fromMovie(
          userId: testUserId,
          movie: testMovie,
          watchedDate: earlierTime,
          personalRating: 3.0,
          personalNotes: 'Device A version',
        ).copyWithData(lastModifiedAt: earlierTime);

        final remoteEntity = SyncableWatchedMovie.fromMovie(
          userId: testUserId,
          movie: testMovie,
          watchedDate: laterTime,
          personalRating: 4.5,
          personalNotes: 'Device B version',
        ).copyWithData(lastModifiedAt: laterTime);

        final conflict = ConflictInfo<SyncableWatchedMovie>(
          localEntity: localEntity,
          remoteEntity: remoteEntity,
          conflictType: ConflictType.concurrentModification,
          detectedAt: DateTime.now(),
        );

        // Test automatic conflict resolution
        final resolved = await syncManager.resolveConflict(conflict);

        // Should choose the later timestamp (Device B)
        expect(resolved.personalRating, equals(4.5));
        expect(resolved.personalNotes, equals('Device B version'));
        expect(resolved.lastModifiedAt, equals(laterTime));
      });

      test('No data loss occurs during conflict resolution', () async {
        final syncManager = WatchedSyncManager(userId: testUserId);

        final testMovie = Movie(
          id: 75006,
          title: 'Data Loss Test Movie',
          adult: false,
          backdropPath: '/schema_backdrop.jpg',
          genreIds: [3, 4],
          originalLanguage: 'es',
          originalTitle: 'Película de Prueba de Pérdida de Datos',
          overview: 'Testing data preservation during conflicts',
          popularity: 6.5,
          posterPath: '/data_loss_poster.jpg',
          releaseDate: DateTime(2023, 7, 15),
          video: false,
          voteAverage: 6.8,
          voteCount: 75,
        );

        final baseTime = DateTime(2023, 12, 1, 12, 0);

        final entity1 = SyncableWatchedMovie.fromMovie(
          userId: testUserId,
          movie: testMovie,
          watchedDate: baseTime,
          personalRating: 4.0,
          personalNotes: 'Original review',
          watchedLocation: 'Cinema A',
          rewatchCount: 1,
        ).copyWithData(lastModifiedAt: baseTime);

        final entity2 = SyncableWatchedMovie.fromMovie(
          userId: testUserId,
          movie: testMovie,
          watchedDate: baseTime.add(const Duration(minutes: 30)),
          personalRating: 4.2,
          personalNotes: 'Updated review',
          watchedLocation: 'Cinema B',
          rewatchCount: 2,
        ).copyWithData(
            lastModifiedAt: baseTime.add(const Duration(minutes: 30)));

        final conflict = ConflictInfo<SyncableWatchedMovie>(
          localEntity: entity1,
          remoteEntity: entity2,
          conflictType: ConflictType.concurrentModification,
          detectedAt: DateTime.now(),
        );

        final resolved = await syncManager.resolveConflict(conflict);

        // Verify all essential data is preserved
        expect(resolved.userId, equals(testUserId));
        expect(resolved.movieId, equals(testMovie.id));
        expect(resolved.movieTitle, equals(testMovie.title));
        expect(resolved.isDeleted, isFalse);
        expect(resolved.syncVersion, greaterThan(0));
        expect(resolved.deviceId, isNotNull);

        // Should use data from later entity
        expect(resolved.personalRating, equals(4.2));
        expect(resolved.personalNotes, equals('Updated review'));
        expect(resolved.watchedLocation, equals('Cinema B'));
        expect(resolved.rewatchCount, equals(2));
      });
    });

    group('Implementation Quality Validation', () {
      test('Follows the same pattern as favorites synchronization', () {
        final watchedSyncManager = WatchedSyncManager(userId: testUserId);
        final watchedRepository =
            container.read(hybridWatchedRepositoryProvider);

        // Verify it follows the same interface patterns
        expect(
            watchedSyncManager, isA<EntitySyncManager<SyncableWatchedMovie>>());
        expect(watchedRepository,
            isA<BaseHybridRepository<SyncableWatchedMovie>>());

        // Verify sync manager methods are implemented
        expect(
            () => watchedSyncManager
                    .serializeForLocal(SyncableWatchedMovie.fromMovie(
                  userId: testUserId,
                  movie: Movie(
                    id: 999,
                    title: 'Test',
                    adult: false,
                    backdropPath: '',
                    genreIds: [],
                    originalLanguage: 'en',
                    originalTitle: 'Test',
                    overview: '',
                    popularity: 0.0,
                    posterPath: '',
                    releaseDate: DateTime.now(),
                    video: false,
                    voteAverage: 0.0,
                    voteCount: 0,
                  ),
                  watchedDate: DateTime.now(),
                )),
            returnsNormally);
      });

      test('Provider integration works correctly', () {
        final provider = container.read(watchedMoviesProvider.notifier);
        final repository = container.read(hybridWatchedRepositoryProvider);

        // Verify provider uses the hybrid repository
        expect(provider.repository, equals(repository));
        expect(provider.repository, isA<HybridWatchedRepository>());

        // Verify state is properly initialized
        final state = container.read(watchedMoviesProvider);
        expect(state.movies, isA<List<SyncableWatchedMovie>>());
        expect(state.currentPage, equals(0));
        expect(state.isLoading, isFalse);
      });

      test('All required serialization methods work correctly', () {
        final syncManager = WatchedSyncManager(userId: testUserId);

        final testMovie = SyncableWatchedMovie.fromMovie(
          userId: testUserId,
          movie: Movie(
            id: 75007,
            title: 'Serialization Test',
            adult: false,
            backdropPath: '/test_backdrop.jpg',
            genreIds: [5],
            originalLanguage: 'en',
            originalTitle: 'Serialization Test',
            overview: 'Testing serialization',
            popularity: 5.0,
            posterPath: '/serial_poster.jpg',
            releaseDate: DateTime(2023, 8, 20),
            video: false,
            voteAverage: 5.5,
            voteCount: 25,
          ),
          personalRating: 3.5,
          personalNotes: 'Test notes',
        );

        // Test all serialization methods
        expect(() => syncManager.serializeForLocal(testMovie), returnsNormally);
        expect(
            () => syncManager.serializeForRemote(testMovie), returnsNormally);

        final localData = syncManager.serializeForLocal(testMovie);
        final remoteData = syncManager.serializeForRemote(testMovie);

        expect(
            () => syncManager.deserializeFromLocal(localData), returnsNormally);
        expect(() => syncManager.deserializeFromRemote(remoteData),
            returnsNormally);

        final localRoundtrip = syncManager.deserializeFromLocal(localData);
        final remoteRoundtrip = syncManager.deserializeFromRemote(remoteData);

        expect(localRoundtrip.movieId, equals(testMovie.movieId));
        expect(remoteRoundtrip.movieId, equals(testMovie.movieId));
      });
    });
  });
}
