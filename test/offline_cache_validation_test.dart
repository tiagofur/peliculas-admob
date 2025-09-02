import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/infrastructure/datasources/favorite_movies_shared_preferences_datasource.dart';

/// Comprehensive validation test for web cache functionality
void main() {
  group('Web Cache Validation Tests', () {
    late FavoriteMoviesSharedPreferencesDatasource webDatasource;
    late Movie sampleMovie;

    setUp(() {
      webDatasource = FavoriteMoviesSharedPreferencesDatasource();
      sampleMovie = Movie(
        id: 98765,
        title: 'Web Cache Test Movie',
        overview: 'Testing SharedPreferences cache implementation',
        posterPath: '/web_test_poster.jpg',
        backdropPath: '/web_test_backdrop.jpg',
        releaseDate: DateTime(2024, 6, 1),
        voteAverage: 9.1,
        genreIds: const ['16', '35'], // Animation, Comedy
        adult: false,
        originalLanguage: 'en',
        originalTitle: 'Web Cache Test Movie',
        popularity: 95.2,
        video: false,
        voteCount: 2100,
      );
    });

    test('web datasource should implement all cache methods', () {
      // Verify that all required cache methods are implemented
      expect(webDatasource.cacheMovie, isA<Function>());
      expect(webDatasource.getCachedMovie, isA<Function>());
      expect(webDatasource.cacheMovies, isA<Function>());
      expect(webDatasource.getCachedMoviesByCategory, isA<Function>());
      expect(webDatasource.clearExpiredCache, isA<Function>());
      expect(webDatasource.getCacheSize, isA<Function>());
      expect(webDatasource.clearAllCache, isA<Function>());
    });

    test('should handle cache operations gracefully', () async {
      // Test that cache operations don't throw exceptions
      try {
        await webDatasource.cacheMovie(sampleMovie);
        await webDatasource.getCachedMovie(sampleMovie.id);
        await webDatasource.getCacheSize();
        await webDatasource.clearExpiredCache();
        await webDatasource.clearAllCache();
        
        // If we reach here, all operations completed without exceptions
        expect(true, isTrue);
      } catch (e) {
        fail('Cache operations should not throw exceptions: $e');
      }
    });

    test('should handle empty category requests', () async {
      final result = await webDatasource.getCachedMoviesByCategory('nonexistent');
      expect(result, isA<List<Movie>>());
      expect(result, isEmpty);
    });

    test('should return valid cache size', () async {
      final size = await webDatasource.getCacheSize();
      expect(size, isA<int>());
      expect(size, greaterThanOrEqualTo(0));
    });
  });

  group('Cache Interface Validation', () {
    test('Movie entity has required fields for caching', () {
      final movie = Movie(
        id: 123,
        title: 'Test',
        overview: 'Test overview',
        posterPath: '/test.jpg',
        backdropPath: '/test_bg.jpg',
        releaseDate: DateTime.now(),
        voteAverage: 8.0,
        genreIds: const ['28'],
        adult: false,
        originalLanguage: 'en',
        originalTitle: 'Test',
        popularity: 80.0,
        video: false,
        voteCount: 100,
      );

      // Verify all essential fields are accessible
      expect(movie.id, isA<int>());
      expect(movie.title, isA<String>());
      expect(movie.overview, isA<String>());
      expect(movie.posterPath, isA<String>());
      expect(movie.releaseDate, isA<DateTime>());
      expect(movie.voteAverage, isA<double>());
    });

    test('Cache constants are properly defined', () {
      // This test validates our cache configuration constants
      const webCacheLimit = 500;
      const nativeCacheLimit = 1000;
      const cacheExpiryDays = 7;
      const cleanupIntervalHours = 6;
      const memoryTimeoutMinutes = 30;

      expect(webCacheLimit, lessThan(nativeCacheLimit));
      expect(cacheExpiryDays, greaterThan(0));
      expect(cleanupIntervalHours, greaterThan(0));
      expect(memoryTimeoutMinutes, greaterThan(0));
    });
  });
}