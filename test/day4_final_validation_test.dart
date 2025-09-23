import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/infrastructure/mappers/movie_mapper.dart';

void main() {
  group('Day 4 - Final Validation Tests', () {
    test('should have complete Spanish genre mapping', () {
      // Arrange
      final testGenreIds = [
        28,
        12,
        16,
        35,
        80,
        99,
        18,
        10751,
        14,
        36,
        27,
        10402,
        9648,
        10749,
        878,
        10770,
        53,
        10752,
        37
      ];

      // Act
      final genreNames = MovieMapper.getGenreNames(testGenreIds);

      // Assert
      expect(genreNames, hasLength(19));
      expect(genreNames, contains('Acción'));
      expect(genreNames, contains('Aventura'));
      expect(genreNames, contains('Animación'));
      expect(genreNames, contains('Comedia'));
      expect(genreNames, contains('Crimen'));
      expect(genreNames, contains('Documental'));
      expect(genreNames, contains('Drama'));
      expect(genreNames, contains('Familiar'));
      expect(genreNames, contains('Fantasía'));
      expect(genreNames, contains('Historia'));
      expect(genreNames, contains('Terror'));
      expect(genreNames, contains('Musical'));
      expect(genreNames, contains('Misterio'));
      expect(genreNames, contains('Romance'));
      expect(genreNames, contains('Ciencia Ficción'));
      expect(genreNames, contains('Película de TV'));
      expect(genreNames, contains('Suspense'));
      expect(genreNames, contains('Guerra'));
      expect(genreNames, contains('Western'));
    });

    test('should handle pure int genre IDs', () {
      // Arrange
      final movieData = {
        'id': 1,
        'adult': false,
        'backdrop_path': '/test.jpg',
        'genre_ids': [28, 12, 16], // All integers
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
      final movie = Movie.fromJson(movieData);

      // Assert
      expect(movie.genreIds, hasLength(3));
      expect(movie.genreIds, contains('Acción'));
      expect(movie.genreIds, contains('Aventura'));
      expect(movie.genreIds, contains('Animación'));
    });

    test('should handle string genre names directly', () {
      // Arrange
      final movieData = {
        'id': 1,
        'adult': false,
        'backdrop_path': '/test.jpg',
        'genre_ids': ['Acción', 'Aventura', 'Drama'], // All strings
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
      final movie = Movie.fromJson(movieData);

      // Assert
      expect(movie.genreIds, hasLength(3));
      expect(movie.genreIds, contains('Acción'));
      expect(movie.genreIds, contains('Aventura'));
      expect(movie.genreIds, contains('Drama'));
    });

    test('should preserve movie technical details', () {
      // Arrange
      final movieData = {
        'id': 1,
        'adult': false,
        'backdrop_path': '/test.jpg',
        'genre_ids': [28, 12],
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
        'runtime': 150,
        'budget': 75000000,
        'revenue': 200000000,
        'homepage': 'https://example.com',
        'imdb_id': 'tt1234567',
        'status': 'Released',
        'tagline': 'An epic adventure',
      };

      // Act
      final movie = Movie.fromJson(movieData);

      // Assert
      expect(movie.runtime, equals(150));
      expect(movie.budget, equals(75000000));
      expect(movie.revenue, equals(200000000));
      expect(movie.homepage, equals('https://example.com'));
      expect(movie.imdbId, equals('tt1234567'));
      expect(movie.status, equals('Released'));
      expect(movie.tagline, equals('An epic adventure'));
    });

    test('should handle empty and null values gracefully', () {
      // Arrange
      final movieData = {
        'id': 1,
        'adult': false,
        'genre_ids': [], // Empty genres
        'original_language': 'en',
        'original_title': 'Test Movie',
        'overview': 'Test overview',
        'popularity': 100.0,
        'release_date': '2024-01-01',
        'title': 'Test Movie',
        'video': false,
        'vote_average': 8.5,
        'vote_count': 1000,
        // Missing optional fields
      };

      // Act
      final movie = Movie.fromJson(movieData);

      // Assert
      expect(movie.genreIds, isEmpty);
      expect(movie.backdropPath, equals(''));
      expect(movie.posterPath, equals(''));
      expect(movie.runtime, isNull);
      expect(movie.budget, isNull);
      expect(movie.revenue, isNull);
      expect(movie.homepage, isNull);
      expect(movie.imdbId, isNull);
      expect(movie.status, isNull);
      expect(movie.tagline, isNull);
    });

    test('should maintain genre mapping consistency', () {
      // Arrange
      final testIds = [28, 12, 16];

      // Act
      final names1 = MovieMapper.getGenreNames(testIds);
      final names2 = MovieMapper.getGenreNames(testIds);

      // Assert
      expect(names1, equals(names2));
      expect(names1, contains('Acción'));
      expect(names1, contains('Aventura'));
      expect(names1, contains('Animación'));
    });
  });
}
