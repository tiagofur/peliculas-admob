import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/domain/entities/custom_list.dart';

/// Pruebas básicas de integración para sincronización
void main() {
  group('Sincronización Bidireccional Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('Test básico de container', () {
      // Test básico para verificar que el container se puede instanciar
      expect(container, isNotNull);
    });

    test('Test básico de entidades Movie', () {
      // Test básico para verificar que las entidades se pueden crear
      final testMovie = Movie(
         id: 12345,
         title: 'Test Movie',
         overview: 'Una película de prueba',
         posterPath: '/test_poster.jpg',
         backdropPath: '/test_backdrop.jpg',
         releaseDate: DateTime(2024, 1, 1),
         voteAverage: 8.5,
         genreIds: ['28', '12'],
         adult: false,
         originalLanguage: 'en',
         originalTitle: 'Test Movie',
         popularity: 100.0,
         video: false,
         voteCount: 1000,
       );
      
      expect(testMovie.id, equals(12345));
      expect(testMovie.title, equals('Test Movie'));
      expect(testMovie.voteAverage, equals(8.5));
    });

    test('Test básico de entidades CustomList', () {
      final testList = CustomList(
        id: 'test-list-id',
        name: 'Test List',
        description: 'Una lista de prueba',
        emoji: '📋',
        movieIds: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        color: 'orange',
      );
      
      expect(testList.id, equals('test-list-id'));
      expect(testList.name, equals('Test List'));
      expect(testList.color, equals('orange'));
    });
  });
}