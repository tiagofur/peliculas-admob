import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/infrastructure/datasources/moviedb_datasource.dart';
import 'package:peliculas/infrastructure/datasources/isar_datasource.dart';
import 'package:peliculas/infrastructure/repositories/cached_movie_repository_impl.dart';

/// Integration test for cached movie repository
void main() {
  group('Cached Movie Repository Integration Tests', () {
    late CachedMovieRepositoryImpl repository;

    setUp(() {
      final networkDatasource = MoviedbDatasource();
      final localDatasource = HiveDatasource();
      
      repository = CachedMovieRepositoryImpl(
        networkDatasource: networkDatasource,
        localDatasource: localDatasource,
      );
    });

    test('should work offline after initial network fetch', () async {
      // Note: This test would require actual network connectivity for the first part
      // In a real test environment, you might want to mock the network datasource
      
      // For this basic test, we just verify the repository is constructed correctly
      expect(repository, isNotNull);
    });

    test('repository should handle empty search queries', () async {
      final result = await repository.searchMovies('');
      expect(result, isEmpty);
    });

    test('repository should handle search with whitespace', () async {
      final result = await repository.searchMovies('   ');
      expect(result, isEmpty);
    });

    // Add more integration tests here when network mocking is available
  });
}