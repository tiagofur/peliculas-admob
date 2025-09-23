import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/infrastructure/mappers/movie_mapper.dart';

void main() {
  group('Day 4 - Genre Mapping Tests', () {
    test('should map genre IDs to Spanish names correctly', () {
      // Arrange
      final genreIds = [28, 12, 16, 35, 80, 99, 18];
      
      // Act
      final genreNames = MovieMapper.getGenreNames(genreIds);
      
      // Assert
      expect(genreNames, contains('Acción'));
      expect(genreNames, contains('Aventura'));
      expect(genreNames, contains('Animación'));
      expect(genreNames, contains('Comedia'));
      expect(genreNames, contains('Crimen'));
      expect(genreNames, contains('Documental'));
      expect(genreNames, contains('Drama'));
      
      // Verify no English names
      expect(genreNames, isNot(contains('Action')));
      expect(genreNames, isNot(contains('Adventure')));
      expect(genreNames, isNot(contains('Animation')));
    });

    test('should handle unknown genre IDs gracefully', () {
      // Arrange
      final genreIds = [99999, 88888, 77777];
      
      // Act
      final genreNames = MovieMapper.getGenreNames(genreIds);
      
      // Assert
      expect(genreNames, isEmpty);
    });

    test('should handle mixed known and unknown genre IDs', () {
      // Arrange
      final genreIds = [28, 99999, 12, 88888];
      
      // Act
      final genreNames = MovieMapper.getGenreNames(genreIds);
      
      // Assert
      expect(genreNames, hasLength(2));
      expect(genreNames, contains('Acción'));
      expect(genreNames, contains('Aventura'));
      expect(genreNames, isNot(contains('Unknown')));
    });

    test('should handle empty genre IDs list', () {
      // Arrange
      final genreIds = <int>[];
      
      // Act
      final genreNames = MovieMapper.getGenreNames(genreIds);
      
      // Assert
      expect(genreNames, isEmpty);
    });
  });
}