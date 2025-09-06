import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/core/sync/watched_sync_manager.dart';
import '../lib/domain/entities/movie.dart';
import '../lib/domain/entities/syncable_watched_movie.dart';
import '../lib/infrastructure/repositories/hybrid_watched_repository.dart';
import '../lib/infrastructure/services/realtime_sync_service.dart';
import '../lib/presentation/providers/watched_movies_provider.dart';
import '../lib/presentation/providers/hybrid_repositories_provider.dart';

void main() {
  group('Multi-Device Watched Movies Synchronization Tests', () {
    late ProviderContainer deviceA;
    late ProviderContainer deviceB;
    late HybridWatchedRepository repoA;
    late HybridWatchedRepository repoB;
    const String testUserId = 'multi_device_user_123';

    setUp(() async {
      // Initialize shared preferences for testing
      SharedPreferences.setMockInitialValues({});
      
      // Create two provider containers simulating different devices
      deviceA = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWithValue(testUserId),
      ]);
      
      deviceB = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWithValue(testUserId),
      ]);
      
      // Initialize repositories for both devices
      repoA = deviceA.read(hybridWatchedRepositoryProvider);
      repoB = deviceB.read(hybridWatchedRepositoryProvider);
      
      await repoA.initializeLocal();
      await repoB.initializeLocal();
    });

    tearDown(() {
      deviceA.dispose();
      deviceB.dispose();
    });

    test('should sync watched movie from device A to device B', () async {
      // Create test movie
      final testMovie = Movie(
        id: 1001,
        title: 'Multi-Device Test Movie',
        adult: false,
        backdropPath: '/multi_backdrop.jpg',
        genreIds: [1, 2],
        originalLanguage: 'en',
        originalTitle: 'Multi-Device Test Movie',
        overview: 'Testing multi-device sync',
        popularity: 8.5,
        posterPath: '/multi_poster.jpg',
        releaseDate: DateTime(2023, 8, 15),
        video: false,
        voteAverage: 8.2,
        voteCount: 150,
      );

      // Device A marks movie as watched
      await repoA.markAsWatched(
        movieId: testMovie.id,
        watchedAt: DateTime(2023, 12, 25),
        rating: 4.5,
        review: 'Excellent movie from Device A',
      );

      // Verify movie is watched on Device A
      final isWatchedA = await repoA.isMovieWatched(testMovie.id);
      expect(isWatchedA, isTrue);

      // Simulate real-time sync by getting remote changes for Device B
      final syncManagerB = WatchedSyncManager(userId: testUserId);
      final remoteChanges = await syncManagerB.getRemoteChanges();
      
      // Download changes to Device B
      if (remoteChanges.isNotEmpty) {
        await syncManagerB.downloadChanges(remoteChanges);
        for (final change in remoteChanges) {
          await repoB.saveToLocal(change);
        }
      }

      // Verify movie is now watched on Device B
      final isWatchedB = await repoB.isMovieWatched(testMovie.id);
      expect(isWatchedB, isTrue);

      // Verify details match
      final watchedMovieB = await repoB.getWatchedMovieByMovieId(testMovie.id);
      expect(watchedMovieB, isNotNull);
      expect(watchedMovieB!.personalRating, equals(4.5));
      expect(watchedMovieB.personalNotes, equals('Excellent movie from Device A'));
    });

    test('should handle conflict resolution between devices', () async {
      // Create test movie
      final testMovie = Movie(
        id: 2001,
        title: 'Conflict Test Movie',
        adult: false,
        backdropPath: '/conflict_backdrop.jpg',
        genreIds: [3, 4],
        originalLanguage: 'es',
        originalTitle: 'Película de Conflicto',
        overview: 'Testing conflict resolution',
        popularity: 7.8,
        posterPath: '/conflict_poster.jpg',
        releaseDate: DateTime(2023, 9, 20),
        video: false,
        voteAverage: 7.5,
        voteCount: 80,
      );

      // Both devices mark the same movie as watched with different details
      // Device A version (earlier timestamp)
      await repoA.markAsWatched(
        movieId: testMovie.id,
        watchedAt: DateTime(2023, 12, 25, 10, 0),
        rating: 3.5,
        review: 'Good movie - Device A review',
      );

      // Device B version (later timestamp)
      await repoB.markAsWatched(
        movieId: testMovie.id,
        watchedAt: DateTime(2023, 12, 25, 11, 0),
        rating: 4.8,
        review: 'Amazing movie - Device B review',
      );

      // Get local data from both devices
      final watchedA = await repoA.getWatchedMovieByMovieId(testMovie.id);
      final watchedB = await repoB.getWatchedMovieByMovieId(testMovie.id);

      expect(watchedA, isNotNull);
      expect(watchedB, isNotNull);

      // Simulate conflict resolution
      final syncManagerA = WatchedSyncManager(userId: testUserId);
      
      // Create conflict scenario
      final conflict = ConflictInfo<SyncableWatchedMovie>(
        localEntity: watchedA!,
        remoteEntity: watchedB!,
        conflictType: ConflictType.dataConflict,
      );

      // Resolve conflict - should choose later timestamp (Device B)
      final resolved = await syncManagerA.resolveConflict(conflict);
      expect(resolved.personalRating, equals(4.8));
      expect(resolved.personalNotes, equals('Amazing movie - Device B review'));
      expect(resolved.watchedDate, equals(DateTime(2023, 12, 25, 11, 0)));
    });

    test('should handle watched movie removal across devices', () async {
      // Create test movie
      final testMovie = Movie(
        id: 3001,
        title: 'Removal Test Movie',
        adult: false,
        backdropPath: '/removal_backdrop.jpg',
        genreIds: [5, 6],
        originalLanguage: 'fr',
        originalTitle: 'Film de Test de Suppression',
        overview: 'Testing removal sync',
        popularity: 6.5,
        posterPath: '/removal_poster.jpg',
        releaseDate: DateTime(2023, 10, 5),
        video: false,
        voteAverage: 6.8,
        voteCount: 45,
      );

      // Device A marks movie as watched
      await repoA.markAsWatched(
        movieId: testMovie.id,
        watchedAt: DateTime(2023, 12, 26),
        rating: 3.0,
        review: 'Meh movie',
      );

      // Verify it's watched on Device A
      expect(await repoA.isMovieWatched(testMovie.id), isTrue);

      // Simulate sync to Device B
      final syncManagerB = WatchedSyncManager(userId: testUserId);
      final remoteChanges = await syncManagerB.getRemoteChanges();
      if (remoteChanges.isNotEmpty) {
        await syncManagerB.downloadChanges(remoteChanges);
        for (final change in remoteChanges) {
          await repoB.saveToLocal(change);
        }
      }

      // Verify it's watched on Device B
      expect(await repoB.isMovieWatched(testMovie.id), isTrue);

      // Device B removes the movie from watched
      await repoB.unmarkAsWatched(testMovie.id);
      expect(await repoB.isMovieWatched(testMovie.id), isFalse);

      // Simulate sync back to Device A
      final syncManagerA = WatchedSyncManager(userId: testUserId);
      final remoteChangesA = await syncManagerA.getRemoteChanges();
      if (remoteChangesA.isNotEmpty) {
        await syncManagerA.downloadChanges(remoteChangesA);
        for (final change in remoteChangesA) {
          if (change.isDeleted) {
            await repoA.removeFromLocal(change.id);
          } else {
            await repoA.saveToLocal(change);
          }
        }
      }

      // Verify it's removed on Device A
      expect(await repoA.isMovieWatched(testMovie.id), isFalse);
    });

    test('should handle rapid updates from multiple devices', () async {
      // Create test movies for rapid updates
      final movies = List.generate(5, (index) => Movie(
        id: 4000 + index,
        title: 'Rapid Update Movie ${index + 1}',
        adult: false,
        backdropPath: '/rapid_backdrop_$index.jpg',
        genreIds: [index + 1],
        originalLanguage: 'en',
        originalTitle: 'Rapid Update Movie ${index + 1}',
        overview: 'Testing rapid updates $index',
        popularity: 5.0 + index,
        posterPath: '/rapid_poster_$index.jpg',
        releaseDate: DateTime(2023, 11, index + 1),
        video: false,
        voteAverage: 5.0 + index,
        voteCount: 10 + index,
      ));

      // Device A rapidly marks multiple movies as watched
      for (int i = 0; i < movies.length; i++) {
        await repoA.markAsWatched(
          movieId: movies[i].id,
          watchedAt: DateTime(2023, 12, 27, 10, i),
          rating: 3.0 + i * 0.5,
          review: 'Device A review for movie ${i + 1}',
        );
      }

      // Device B marks some of the same movies with different details
      for (int i = 2; i < movies.length; i++) {
        await repoB.markAsWatched(
          movieId: movies[i].id,
          watchedAt: DateTime(2023, 12, 27, 11, i), // Later time
          rating: 4.0 + i * 0.3,
          review: 'Device B review for movie ${i + 1}',
        );
      }

      // Verify all movies are watched on both devices
      for (final movie in movies) {
        expect(await repoA.isMovieWatched(movie.id), isTrue);
        if (movie.id >= 4002) { // Movies marked by Device B
          expect(await repoB.isMovieWatched(movie.id), isTrue);
        }
      }

      // Get statistics from both devices
      final statsA = await repoA.getWatchedStats();
      final statsB = await repoB.getWatchedStats();

      expect(statsA['totalWatched'], equals(5));
      expect(statsB['totalWatched'], equals(3)); // Only movies 4002, 4003, 4004
    });

    test('should maintain data integrity during real-time updates', () async {
      // Create test movie
      final testMovie = Movie(
        id: 5001,
        title: 'Data Integrity Test Movie',
        adult: false,
        backdropPath: '/integrity_backdrop.jpg',
        genreIds: [7, 8, 9],
        originalLanguage: 'en',
        originalTitle: 'Data Integrity Test Movie',
        overview: 'Testing data integrity',
        popularity: 9.1,
        posterPath: '/integrity_poster.jpg',
        releaseDate: DateTime(2023, 7, 12),
        video: false,
        voteAverage: 9.2,
        voteCount: 300,
      );

      // Device A marks movie as watched
      await repoA.markAsWatched(
        movieId: testMovie.id,
        watchedAt: DateTime(2023, 12, 28),
        rating: 5.0,
        review: 'Perfect movie!',
      );

      // Get the watched movie from Device A
      final originalWatched = await repoA.getWatchedMovieByMovieId(testMovie.id);
      expect(originalWatched, isNotNull);

      // Verify all data is preserved correctly
      expect(originalWatched!.movieId, equals(testMovie.id));
      expect(originalWatched.movieTitle, equals(testMovie.title));
      expect(originalWatched.personalRating, equals(5.0));
      expect(originalWatched.personalNotes, equals('Perfect movie!'));
      expect(originalWatched.userId, equals(testUserId));
      expect(originalWatched.isDeleted, isFalse);
      expect(originalWatched.syncVersion, greaterThan(0));
      expect(originalWatched.deviceId, isNotNull);

      // Serialize and deserialize to test data integrity
      final syncManager = WatchedSyncManager(userId: testUserId);
      
      // Test local serialization
      final localData = syncManager.serializeForLocal(originalWatched);
      final deserializedLocal = syncManager.deserializeFromLocal(localData);
      
      expect(deserializedLocal.movieId, equals(originalWatched.movieId));
      expect(deserializedLocal.movieTitle, equals(originalWatched.movieTitle));
      expect(deserializedLocal.personalRating, equals(originalWatched.personalRating));
      expect(deserializedLocal.personalNotes, equals(originalWatched.personalNotes));
      
      // Test remote serialization
      final remoteData = syncManager.serializeForRemote(originalWatched);
      final deserializedRemote = syncManager.deserializeFromRemote(remoteData);
      
      expect(deserializedRemote.movieId, equals(originalWatched.movieId));
      expect(deserializedRemote.movieTitle, equals(originalWatched.movieTitle));
      expect(deserializedRemote.personalRating, equals(originalWatched.personalRating));
      expect(deserializedRemote.personalNotes, equals(originalWatched.personalNotes));
    });
  });

  group('Provider Integration Tests', () {
    late ProviderContainer container;
    
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWithValue('provider_test_user'),
      ]);
    });

    tearDown(() {
      container.dispose();
    });

    test('should provide correct watched movies repository', () {
      final repository = container.read(hybridWatchedRepositoryProvider);
      expect(repository, isA<HybridWatchedRepository>());
      expect(repository.userId, equals('provider_test_user'));
    });

    test('should create watched movies provider with correct notifier', () {
      final provider = container.read(watchedMoviesProvider.notifier);
      expect(provider, isA<WatchedMoviesNotifier>());
      expect(provider.repository, isA<HybridWatchedRepository>());
    });

    test('should handle movie watched status check', () async {
      const movieId = 6001;
      
      // Initially not watched
      final initialStatus = await container.read(isMovieWatchedProvider(movieId).future);
      expect(initialStatus, isFalse);
      
      // Mark as watched through repository
      final repo = container.read(hybridWatchedRepositoryProvider);
      await repo.markAsWatched(movieId: movieId);
      
      // Refresh provider and check status
      container.invalidate(isMovieWatchedProvider(movieId));
      final updatedStatus = await container.read(isMovieWatchedProvider(movieId).future);
      expect(updatedStatus, isTrue);
    });
  });
}