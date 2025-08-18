import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/domain/entities/custom_list.dart';
import 'package:peliculas/presentation/providers/hybrid_repositories_provider.dart';
import 'package:peliculas/infrastructure/services/sync_service.dart';

/// Pruebas básicas para funcionamiento offline
void main() {
  group('Offline Functionality Tests', () {
    late ProviderContainer container;
    late Movie testMovie1;
    late Movie testMovie2;
    late CustomList testList;

    setUp(() {
      container = ProviderContainer();
      testMovie1 = Movie(
        id: 11111,
        title: 'Offline Test Movie 1',
        overview: 'Primera película para pruebas offline',
        posterPath: '/offline_poster1.jpg',
        backdropPath: '/offline_backdrop1.jpg',
        releaseDate: DateTime(2024, 4, 10),
        voteAverage: 8.2,
        genreIds: const ['28', '878'],
        adult: false,
        originalLanguage: 'en',
        originalTitle: 'Offline Test Movie 1',
        popularity: 92.3,
        video: false,
        voteCount: 3500,
      );
      
      testMovie2 = Movie(
        id: 22222,
        title: 'Offline Test Movie 2',
        overview: 'Segunda película para pruebas offline',
        posterPath: '/offline_poster2.jpg',
        backdropPath: '/offline_backdrop2.jpg',
        releaseDate: DateTime(2024, 5, 20),
        voteAverage: 7.5,
        genreIds: const ['35', '10749'],
        adult: false,
        originalLanguage: 'es',
        originalTitle: 'Película Offline 2',
        popularity: 76.8,
        video: false,
        voteCount: 2100,
      );
      
      testList = CustomList(
        id: 'offline-list-id',
        name: 'Lista Offline',
        description: 'Lista creada sin conexión',
        emoji: '🎬',
        movieIds: const [],
        color: '#9C27B0',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    tearDown(() {
      container.dispose();
    });

    group('Basic Offline Operations', () {
      test('Repositories should be available', () {
        final favoritesRepo = container.read(hybridFavoritesRepositoryProvider);
        final watchedRepo = container.read(hybridWatchedRepositoryProvider);
        final listsRepo = container.read(hybridCustomListsRepositoryProvider);
        
        expect(favoritesRepo, isNotNull);
        expect(watchedRepo, isNotNull);
        expect(listsRepo, isNotNull);
      });

      test('Sync service should be available', () {
        final syncService = container.read(syncServiceProvider);
        expect(syncService, isNotNull);
        
        final status = syncService.getSyncStatus();
        expect(status, isNotNull);
        expect(status['repositories_count'], equals(3));
      });

      test('Test entities should be valid', () {
        expect(testMovie1.id, equals(11111));
        expect(testMovie1.title, equals('Offline Test Movie 1'));
        expect(testMovie2.id, equals(22222));
        expect(testMovie2.title, equals('Offline Test Movie 2'));
        expect(testList.id, equals('offline-list-id'));
        expect(testList.name, equals('Lista Offline'));
      });
    });

    group('Repository Operations', () {
      test('Favorites repository basic operations', () async {
        final favoritesRepo = container.read(hybridFavoritesRepositoryProvider);
        
        // Test basic method availability
        expect(() => favoritesRepo.getFavoriteMovies(), returnsNormally);
        expect(() => favoritesRepo.toggleFavorite(testMovie1), returnsNormally);
      });

      test('Watched repository basic operations', () async {
        final watchedRepo = container.read(hybridWatchedRepositoryProvider);
        
        // Test basic method availability
        expect(() => watchedRepo.getWatchedMovies(), returnsNormally);
      });

      test('Custom lists repository basic operations', () async {
        final listsRepo = container.read(hybridCustomListsRepositoryProvider);
        
        // Test basic method availability
        expect(() => listsRepo.getCustomLists(), returnsNormally);
      });
    });

    group('Sync Operations', () {
      test('Sync service basic operations', () async {
        final syncService = container.read(syncServiceProvider);
        
        // Test basic method availability
        expect(() => syncService.syncAllData(), returnsNormally);
        expect(() => syncService.forceSyncAllData(), returnsNormally);
        expect(() => syncService.getSyncStatus(), returnsNormally);
      });

      test('Repository sync methods', () async {
        final favoritesRepo = container.read(hybridFavoritesRepositoryProvider);
        final watchedRepo = container.read(hybridWatchedRepositoryProvider);
        final listsRepo = container.read(hybridCustomListsRepositoryProvider);
        
        // Test sync method availability
        expect(() => favoritesRepo.syncWithSupabase(), returnsNormally);
        expect(() => watchedRepo.syncWithSupabase(), returnsNormally);
        expect(() => listsRepo.syncWithSupabase(), returnsNormally);
      });
    });
  });
}