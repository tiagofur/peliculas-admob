import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/domain/entities/movie.dart';

void main() {
  group('Day 4 - Movie Details Data Tests', () {
    test('should parse genre IDs to Spanish names in Movie.fromJson', () {
      // Arrange
      final jsonData = {
        'id': 1,
        'adult': false,
        'backdrop_path': '/backdrop.jpg',
        'genre_ids': [28, 12, 16], // Action, Adventure, Animation
        'original_language': 'en',
        'original_title': 'Test Movie',
        'overview': 'Test overview',
        'popularity': 100.0,
        'poster_path': '/poster.jpg',
        'release_date': '2024-01-01',
        'title': 'Test Movie',
        'video': false,
        'vote_average': 8.5,
        'vote_count': 1000,
        'runtime': 120,
        'budget': 50000000,
        'revenue': 100000000,
      };
      
      // Act
      final movie = Movie.fromJson(jsonData);
      
      // Assert
      expect(movie.genreIds, hasLength(3));
      expect(movie.genreIds, contains('Acción'));
      expect(movie.genreIds, contains('Aventura'));
      expect(movie.genreIds, contains('Animación'));
      
      // Verify technical details are preserved
      expect(movie.runtime, equals(120));
      expect(movie.budget, equals(50000000));
      expect(movie.revenue, equals(100000000));
    });

    test('should handle string genre names directly', () {
      // Arrange
      final jsonData = {
        'id': 1,
        'adult': false,
        'backdrop_path': '/backdrop.jpg',
        'genre_ids': ['Acción', 'Aventura', 'Drama'], // Already in Spanish
        'original_language': 'en',
        'original_title': 'Test Movie',
        'overview': 'Test overview',
        'popularity': 100.0,
        'poster_path': '/poster.jpg',
        'release_date': '2024-01-01',
        'title': 'Test Movie',
        'video': false,
        'vote_average': 8.5,
        'vote_count': 1000,
      };
      
      // Act
      final movie = Movie.fromJson(jsonData);
      
      // Assert
      expect(movie.genreIds, hasLength(3));
      expect(movie.genreIds, contains('Acción'));
      expect(movie.genreIds, contains('Aventura'));
      expect(movie.genreIds, contains('Drama'));
    });

    test('should handle null and empty technical details gracefully', () {
      // Arrange
      final jsonData = {
        'id': 1,
        'adult': false,
        'backdrop_path': '/backdrop.jpg',
        'genre_ids': [28],
        'original_language': 'en',
        'original_title': 'Test Movie',
        'overview': 'Test overview',
        'popularity': 100.0,
        'poster_path': '/poster.jpg',
        'release_date': '2024-01-01',
        'title': 'Test Movie',
        'video': false,
        'vote_average': 8.5,
        'vote_count': 1000,
        // No runtime, budget, revenue provided
      };
      
      // Act
      final movie = Movie.fromJson(jsonData);
      
      // Assert
      expect(movie.runtime, isNull);
      expect(movie.budget, isNull);
      expect(movie.revenue, isNull);
      expect(movie.homepage, isNull);
      expect(movie.imdbId, isNull);
      expect(movie.status, isNull);
      expect(movie.tagline, isNull);
    });
  });
}