import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/domain/entities/custom_list.dart';

/// Pruebas básicas para resolución de conflictos
void main() {
  group('Resolución de Conflictos Tests', () {
    late ProviderContainer container;
    late Movie testMovie;
    late CustomList testList;

    setUp(() {
      container = ProviderContainer();
      testMovie = Movie(
        id: 99999,
        title: 'Conflict Test Movie',
        overview: 'Película para probar resolución de conflictos',
        posterPath: '/conflict_poster.jpg',
        backdropPath: '/conflict_backdrop.jpg',
        releaseDate: DateTime(2024, 6, 15),
        voteAverage: 7.8,
        genreIds: ['18', '35'],
        adult: false,
        originalLanguage: 'es',
        originalTitle: 'Película de Conflicto',
        popularity: 85.5,
        video: false,
        voteCount: 2500,
      );
      
      testList = CustomList(
        id: 'conflict-list-id',
        name: 'Lista de Conflictos',
        description: 'Lista para probar resolución de conflictos',
        emoji: '🎬',
        movieIds: [],
        createdAt: DateTime.now().subtract(Duration(hours: 1)),
        updatedAt: DateTime.now().subtract(Duration(minutes: 30)),
        color: 'blue',
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Test Movie Entity Creation', () {
      expect(testMovie.id, equals(99999));
      expect(testMovie.title, equals('Conflict Test Movie'));
      expect(testMovie.voteAverage, equals(7.8));
    });

    test('Test CustomList Entity Creation', () {
      expect(testList.id, equals('conflict-list-id'));
      expect(testList.name, equals('Lista de Conflictos'));
      expect(testList.color, equals('blue'));
    });

    test('Timestamp Comparison Logic', () {
      final older = DateTime.now().subtract(Duration(hours: 2));
      final newer = DateTime.now().subtract(Duration(minutes: 30));
      
      expect(newer.isAfter(older), isTrue);
      expect(older.isBefore(newer), isTrue);
    });

    test('Movie Properties Access', () {
      expect(testMovie.title, equals('Conflict Test Movie'));
      expect(testMovie.voteAverage, equals(7.8));
      expect(testMovie.id, equals(99999));
      expect(testMovie.genreIds, equals(['18', '35']));
      expect(testMovie.adult, equals(false));
    });

    test('CustomList Copy With Functionality', () {
      final modifiedList = testList.copyWith(
        name: 'Modified List Name',
        description: 'Modified description',
      );
      
      expect(modifiedList.name, equals('Modified List Name'));
      expect(modifiedList.description, equals('Modified description'));
      expect(modifiedList.id, equals(testList.id)); // Should remain the same
    });
  });
}