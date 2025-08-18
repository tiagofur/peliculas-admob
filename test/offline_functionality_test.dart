import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/domain/entities/custom_list.dart';
import 'package:peliculas/infrastructure/services/web_safe_storage_service.dart';

/// Pruebas básicas para funcionamiento offline con soporte Web
/// Enfocadas en lógica de negocio sin requerir inicialización de servicios nativos
void main() {
  // Inicializar binding para tests que requieren servicios de Flutter
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Functionality Tests (Web Compatible)', () {
    late ProviderContainer container;
    late Movie testMovie1;
    late Movie testMovie2;
    late CustomList testList;

    setUp(() async {
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

    tearDown(() async {
      container.dispose();
    });

    group('Web-Safe Storage Service Tests', () {
      test('WebSafeStorageService should be accessible', () {
        final storage = WebSafeStorageService.instance;
        expect(storage, isNotNull);
      });

      test('WebSafeStorageService basic operations should work', () async {
        final storage = WebSafeStorageService.instance;

        // Test string operations
        const testKey = 'test_string';
        const testValue = 'test_value';

        final saveResult = await storage.saveString(testKey, testValue);
        expect(saveResult, isTrue);

        final retrievedValue = await storage.getString(testKey);
        expect(retrievedValue, equals(testValue));

        final removeResult = await storage.remove(testKey);
        expect(removeResult, isTrue);

        final removedValue = await storage.getString(testKey);
        expect(removedValue, isNull);
      });

      test('WebSafeStorageService JSON operations should work', () async {
        final storage = WebSafeStorageService.instance;

        const testKey = 'test_json';
        final testData = {
          'id': 123,
          'name': 'Test Movie',
          'active': true,
          'tags': ['action', 'drama']
        };

        final saveResult = await storage.saveJson(testKey, testData);
        expect(saveResult, isTrue);

        final retrievedData = await storage.getJson(testKey);
        expect(retrievedData, isNotNull);
        expect(retrievedData!['id'], equals(123));
        expect(retrievedData['name'], equals('Test Movie'));
        expect(retrievedData['active'], equals(true));
        expect(retrievedData['tags'], equals(['action', 'drama']));

        await storage.remove(testKey);
      });

      test('WebSafeStorageService JSON list operations should work', () async {
        final storage = WebSafeStorageService.instance;

        const testKey = 'test_json_list';
        final testDataList = [
          {'id': 1, 'name': 'Movie 1'},
          {'id': 2, 'name': 'Movie 2'},
          {'id': 3, 'name': 'Movie 3'}
        ];

        final saveResult = await storage.saveJsonList(testKey, testDataList);
        expect(saveResult, isTrue);

        final retrievedList = await storage.getJsonList(testKey);
        expect(retrievedList, isNotNull);
        expect(retrievedList.length, equals(3));
        expect(retrievedList[0]['id'], equals(1));
        expect(retrievedList[1]['name'], equals('Movie 2'));

        await storage.remove(testKey);
      });
    });

    group('Entity Validation Tests', () {
      test('Test movies should be valid', () {
        expect(testMovie1.id, equals(11111));
        expect(testMovie1.title, equals('Offline Test Movie 1'));
        expect(testMovie1.overview, isNotEmpty);
        expect(testMovie1.voteAverage, greaterThan(0));

        expect(testMovie2.id, equals(22222));
        expect(testMovie2.title, equals('Offline Test Movie 2'));
        expect(testMovie2.originalLanguage, equals('es'));
      });

      test('Test custom list should be valid', () {
        expect(testList.id, equals('offline-list-id'));
        expect(testList.name, equals('Lista Offline'));
        expect(testList.description, equals('Lista creada sin conexión'));
        expect(testList.emoji, equals('🎬'));
        expect(testList.movieIds, isEmpty);
        expect(testList.color, equals('#9C27B0'));
        expect(testList.createdAt, isNotNull);
        expect(testList.updatedAt, isNotNull);
      });
    });

    group('Business Logic Tests', () {
      test('Movie entities should support serialization patterns', () {
        // Simular serialización como se haría en el almacenamiento
        final movieData = {
          'id': testMovie1.id,
          'title': testMovie1.title,
          'overview': testMovie1.overview,
          'posterPath': testMovie1.posterPath,
          'backdropPath': testMovie1.backdropPath,
          'releaseDate': testMovie1.releaseDate.toIso8601String(),
          'voteAverage': testMovie1.voteAverage,
          'genreIds': testMovie1.genreIds,
          'adult': testMovie1.adult,
          'originalLanguage': testMovie1.originalLanguage,
          'originalTitle': testMovie1.originalTitle,
          'popularity': testMovie1.popularity,
          'video': testMovie1.video,
          'voteCount': testMovie1.voteCount,
        };

        expect(movieData['id'], equals(11111));
        expect(movieData['title'], equals('Offline Test Movie 1'));
        expect(movieData['releaseDate'], isA<String>());
        expect(movieData['genreIds'], isA<List<String>>());
      });

      test('Custom list should support movie ID management', () {
        // Simular agregar películas a la lista
        final updatedMovieIds = List<int>.from(testList.movieIds);
        updatedMovieIds.add(testMovie1.id);
        updatedMovieIds.add(testMovie2.id);

        expect(updatedMovieIds.length, equals(2));
        expect(updatedMovieIds.contains(testMovie1.id), isTrue);
        expect(updatedMovieIds.contains(testMovie2.id), isTrue);

        // Simular remover una película
        updatedMovieIds.remove(testMovie1.id);
        expect(updatedMovieIds.length, equals(1));
        expect(updatedMovieIds.contains(testMovie1.id), isFalse);
        expect(updatedMovieIds.contains(testMovie2.id), isTrue);
      });
    });

    group('Provider Container Tests', () {
      test('ProviderContainer should be creatable', () {
        expect(container, isNotNull);
      });

      test('ProviderContainer disposal should work', () {
        final testContainer = ProviderContainer();
        expect(testContainer, isNotNull);

        // Test that dispose doesn't throw an error
        expect(() => testContainer.dispose(), returnsNormally);
      });
    });

    group('Cross-Platform Compatibility Tests', () {
      test('DateTime serialization should work consistently', () {
        final now = DateTime.now();
        final isoString = now.toIso8601String();
        final parsedDate = DateTime.parse(isoString);

        expect(parsedDate.year, equals(now.year));
        expect(parsedDate.month, equals(now.month));
        expect(parsedDate.day, equals(now.day));
      });

      test('List operations should work consistently', () {
        final movieIds = <int>[];
        expect(movieIds.isEmpty, isTrue);

        movieIds.addAll([testMovie1.id, testMovie2.id]);
        expect(movieIds.length, equals(2));

        final filteredIds = movieIds.where((id) => id > 15000).toList();
        expect(filteredIds.length, equals(1));
        expect(filteredIds.first, equals(testMovie2.id));
      });

      test('Map operations should work consistently', () {
        final movieMap = <int, Movie>{};
        expect(movieMap.isEmpty, isTrue);

        movieMap[testMovie1.id] = testMovie1;
        movieMap[testMovie2.id] = testMovie2;

        expect(movieMap.length, equals(2));
        expect(movieMap.containsKey(testMovie1.id), isTrue);
        expect(movieMap[testMovie1.id]?.title, equals('Offline Test Movie 1'));
      });
    });
  });
}
