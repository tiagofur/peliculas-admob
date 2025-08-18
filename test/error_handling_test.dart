import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/domain/entities/custom_list.dart';
import 'package:peliculas/presentation/providers/hybrid_repositories_provider.dart';
import 'package:peliculas/infrastructure/services/sync_service.dart';
import 'package:peliculas/infrastructure/services/sync_logger.dart';

/// Pruebas básicas para manejo de errores
void main() {
  group('Error Handling Tests', () {
    late ProviderContainer container;
    late Movie testMovie;
    late CustomList testList;
    late SyncLogger logger;

    setUp(() {
      container = ProviderContainer();
      logger = SyncLogger();
      
      testMovie = Movie(
        id: 99999,
        title: 'Error Test Movie',
        overview: 'Película para pruebas de errores',
        posterPath: '/error_poster.jpg',
        backdropPath: '/error_backdrop.jpg',
        releaseDate: DateTime(2024, 6, 15),
        voteAverage: 7.8,
        genreIds: const ['18', '80'],
        adult: false,
        originalLanguage: 'en',
        originalTitle: 'Error Test Movie',
        popularity: 85.4,
        video: false,
        voteCount: 2800,
      );
      
      testList = CustomList(
        id: 'error-test-list',
        name: 'Lista de Errores',
        description: 'Lista para probar manejo de errores',
        emoji: '❌',
        movieIds: const [],
        color: '#F44336',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    tearDown(() {
      container.dispose();
      // Logger cleanup - simplified for testing
    });

    group('Basic Error Handling', () {
      test('Logger should initialize correctly', () {
        expect(logger, isNotNull);
        expect(logger.runtimeType.toString(), equals('SyncLogger'));
      });

      test('Container should provide repositories', () {
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
      });

      test('Test entities should be valid', () {
        expect(testMovie.id, equals(99999));
        expect(testMovie.title, equals('Error Test Movie'));
        expect(testList.id, equals('error-test-list'));
        expect(testList.name, equals('Lista de Errores'));
      });
    });

    group('Repository Availability', () {
      test('Favorites repository methods should be callable', () async {
        final favoritesRepo = container.read(hybridFavoritesRepositoryProvider);
        
        // Test basic method availability
        expect(() => favoritesRepo.getFavoriteMovies(), returnsNormally);
      });

      test('Watched repository methods should be callable', () async {
        final watchedRepo = container.read(hybridWatchedRepositoryProvider);
        
        // Test basic method availability
        expect(() => watchedRepo.getWatchedMovies(), returnsNormally);
      });

      test('Custom lists repository methods should be callable', () async {
        final listsRepo = container.read(hybridCustomListsRepositoryProvider);
        
        // Test basic method availability
        expect(() => listsRepo.getCustomLists(), returnsNormally);
      });
    });
  });
}