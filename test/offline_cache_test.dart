import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/infrastructure/datasources/isar_datasource.dart';

/// Test for offline cache functionality
void main() {
  group('Offline Cache Tests', () {
    late HiveDatasource datasource;
    late Movie testMovie;

    setUp(() {
      datasource = HiveDatasource();
      testMovie = Movie(
        id: 12345,
        title: 'Test Movie for Cache',
        overview: 'A movie created for testing offline cache functionality',
        posterPath: '/test_poster.jpg',
        backdropPath: '/test_backdrop.jpg',
        releaseDate: DateTime(2024, 1, 15),
        voteAverage: 8.5,
        genreIds: const ['28', '12'], // Action, Adventure
        adult: false,
        originalLanguage: 'en',
        originalTitle: 'Test Movie for Cache',
        popularity: 85.7,
        video: false,
        voteCount: 1250,
      );
    });

    test('should cache and retrieve a movie', () async {
      // Cache the movie
      final cacheResult = await datasource.cacheMovie(testMovie);
      expect(cacheResult, isTrue);

      // Retrieve the cached movie
      final cachedMovie = await datasource.getCachedMovie(testMovie.id);
      expect(cachedMovie, isNotNull);
      expect(cachedMovie!.id, equals(testMovie.id));
      expect(cachedMovie.title, equals(testMovie.title));
      expect(cachedMovie.overview, equals(testMovie.overview));
    });

    test('should cache multiple movies by category', () async {
      final testMovies = [
        testMovie,
        Movie(
          id: 12346,
          title: 'Second Test Movie',
          overview: 'Another movie for testing',
          posterPath: '/test_poster2.jpg',
          backdropPath: '/test_backdrop2.jpg',
          releaseDate: DateTime(2024, 2, 20),
          voteAverage: 7.8,
          genreIds: const ['35', '18'], // Comedy, Drama
          adult: false,
          originalLanguage: 'en',
          originalTitle: 'Second Test Movie',
          popularity: 72.3,
          video: false,
          voteCount: 890,
        ),
      ];

      const category = 'test_category';

      // Cache movies by category
      await datasource.cacheMovies(testMovies, category);

      // Retrieve cached movies by category
      final cachedMovies = await datasource.getCachedMoviesByCategory(category);
      expect(cachedMovies.length, equals(testMovies.length));
      expect(cachedMovies.first.id, equals(testMovies.first.id));
      expect(cachedMovies.last.id, equals(testMovies.last.id));
    });

    test('should handle cache size management', () async {
      // Get initial cache size
      final initialSize = await datasource.getCacheSize();

      // Cache the test movie
      await datasource.cacheMovie(testMovie);

      // Check that cache size increased
      final newSize = await datasource.getCacheSize();
      expect(newSize, equals(initialSize + 1));
    });

    test('should clear expired cache', () async {
      // Cache a movie
      await datasource.cacheMovie(testMovie);
      
      // Verify it's cached
      final cachedMovie = await datasource.getCachedMovie(testMovie.id);
      expect(cachedMovie, isNotNull);

      // Clear expired cache (this won't remove our movie since it's fresh)
      await datasource.clearExpiredCache();

      // Movie should still be there
      final stillCachedMovie = await datasource.getCachedMovie(testMovie.id);
      expect(stillCachedMovie, isNotNull);
    });

    test('should clear all cache', () async {
      // Cache the test movie
      await datasource.cacheMovie(testMovie);
      
      // Verify it's cached
      final initialSize = await datasource.getCacheSize();
      expect(initialSize, greaterThan(0));

      // Clear all cache
      await datasource.clearAllCache();

      // Cache should be empty
      final finalSize = await datasource.getCacheSize();
      expect(finalSize, equals(0));

      // Movie should not be retrievable
      final cachedMovie = await datasource.getCachedMovie(testMovie.id);
      expect(cachedMovie, isNull);
    });

    test('should return null for non-existent cached movie', () async {
      const nonExistentId = 99999;
      
      final cachedMovie = await datasource.getCachedMovie(nonExistentId);
      expect(cachedMovie, isNull);
    });

    test('should return empty list for non-existent category', () async {
      const nonExistentCategory = 'non_existent_category';
      
      final cachedMovies = await datasource.getCachedMoviesByCategory(nonExistentCategory);
      expect(cachedMovies, isEmpty);
    });
  });
}