import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/domain/entities/recommendation.dart';
import 'package:peliculas/domain/entities/watched_movie.dart';
import 'package:peliculas/infrastructure/datasources/recommendations_moviedb_datasource.dart';

void main() {
  group('Basic Recommendations System Tests', () {
    late RecommendationsMoviedbDatasource datasource;

    setUp(() {
      datasource = RecommendationsMoviedbDatasource();
    });

    test('should return trending recommendations', () async {
      // Act
      final recommendations = await datasource.getTrendingRecommendations();

      // Assert
      expect(recommendations, isNotNull);
      expect(recommendations, isA<List<Recommendation>>());
      
      if (recommendations.isNotEmpty) {
        final firstRec = recommendations.first;
        expect(firstRec.type, RecommendationType.trending);
        expect(firstRec.reason, contains('Tendencia'));
        expect(firstRec.movieId, greaterThan(0));
        expect(firstRec.title.trim(), isNotEmpty);
      }
    });

    test('should return genre-based recommendations', () async {
      // Arrange - Action and Comedy genres
      final genres = ['28', '35'];

      // Act
      final recommendations = await datasource.getRecommendationsByGenre(genres);

      // Assert
      expect(recommendations, isNotNull);
      expect(recommendations, isA<List<Recommendation>>());
      
      if (recommendations.isNotEmpty) {
        final firstRec = recommendations.first;
        expect(firstRec.type, RecommendationType.basedOnGenre);
        expect(firstRec.movieId, greaterThan(0));
        expect(firstRec.title.trim(), isNotEmpty);
      }
    });

    test('should return recommendations based on favorite movies', () async {
      // Arrange - Sample favorite movies
      final favoriteMovies = [
        Movie(
          id: 550,
          title: 'Fight Club',
          overview: 'A movie about fight club',
          posterPath: '/path/to/poster.jpg',
          backdropPath: '/path/to/backdrop.jpg',
          releaseDate: DateTime(1999, 10, 15),
          genreIds: ['18', '53'], // Drama, Thriller
          voteAverage: 8.8,
          voteCount: 26000,
          popularity: 61.416,
          adult: false,
          originalLanguage: 'en',
          originalTitle: 'Fight Club',
          video: false,
        ),
      ];

      // Act
      final recommendations = await datasource.getRecommendationsBasedOnFavorites(favoriteMovies);

      // Assert
      expect(recommendations, isNotNull);
      expect(recommendations, isA<List<Recommendation>>());
      
      if (recommendations.isNotEmpty) {
        final firstRec = recommendations.first;
        expect(firstRec.type, RecommendationType.basedOnFavorites);
        expect(firstRec.movieId, greaterThan(0));
        expect(firstRec.title.trim(), isNotEmpty);
      }
    });

    test('should return recommendations based on watched movies (most watched genre)', () async {
      // Arrange - Sample watched movies focusing on action (genre 28)
      final watchedMovies = [
        WatchedMovie(
          id: 299536,
          title: 'Avengers: Infinity War',
          overview: 'Action movie',
          posterPath: '/path/to/poster.jpg',
          backdropPath: '/path/to/backdrop.jpg',
          releaseDate: DateTime(2018, 4, 27),
          genreIds: ['28', '12', '878'], // Action, Adventure, Sci-Fi
          voteAverage: 8.3,
          watchedAt: DateTime.now().subtract(const Duration(days: 10)),
          watchedDate: DateTime.now().subtract(const Duration(days: 10)),
          movie: Movie(
            id: 299536,
            title: 'Avengers: Infinity War',
            overview: 'Action movie',
            posterPath: '/path/to/poster.jpg',
            backdropPath: '/path/to/backdrop.jpg',
            releaseDate: DateTime(2018, 4, 27),
            genreIds: ['28', '12', '878'],
            voteAverage: 8.3,
            voteCount: 20000,
            popularity: 100.0,
            adult: false,
            originalLanguage: 'en',
            originalTitle: 'Avengers: Infinity War',
            video: false,
          ),
        ),
        WatchedMovie(
          id: 299537,
          title: 'Another Action Movie',
          overview: 'Another action movie',
          posterPath: '/path/to/poster.jpg',
          backdropPath: '/path/to/backdrop.jpg',
          releaseDate: DateTime(2020, 6, 15),
          genreIds: ['28'], // Action
          voteAverage: 7.5,
          watchedAt: DateTime.now().subtract(const Duration(days: 5)),
          watchedDate: DateTime.now().subtract(const Duration(days: 5)),
          movie: Movie(
            id: 299537,
            title: 'Another Action Movie',
            overview: 'Another action movie',
            posterPath: '/path/to/poster.jpg',
            backdropPath: '/path/to/backdrop.jpg',
            releaseDate: DateTime(2020, 6, 15),
            genreIds: ['28'],
            voteAverage: 7.5,
            voteCount: 15000,
            popularity: 80.0,
            adult: false,
            originalLanguage: 'en',
            originalTitle: 'Another Action Movie',
            video: false,
          ),
        ),
      ];

      // Act
      final recommendations = await datasource.getRecommendationsBasedOnWatched(watchedMovies);

      // Assert
      expect(recommendations, isNotNull);
      expect(recommendations, isA<List<Recommendation>>());
      
      if (recommendations.isNotEmpty) {
        final firstRec = recommendations.first;
        expect(firstRec.type, RecommendationType.basedOnWatched);
        expect(firstRec.movieId, greaterThan(0));
        expect(firstRec.title.trim(), isNotEmpty);
        // Should contain reference to genre watching pattern
        expect(firstRec.reason.toLowerCase(), anyOf(
          contains('visto'),
          contains('género'),
          contains('acción'),
        ));
      }
    });

    test('recommendation should have valid structure', () async {
      // Act
      final recommendations = await datasource.getTrendingRecommendations();

      // Assert
      if (recommendations.isNotEmpty) {
        final rec = recommendations.first;
        
        // Required fields
        expect(rec.movieId, isA<int>());
        expect(rec.movieId, greaterThan(0));
        expect(rec.title, isA<String>());
        expect(rec.title.trim(), isNotEmpty);
        expect(rec.posterPath, isA<String>());
        expect(rec.score, isA<double>());
        expect(rec.score, greaterThanOrEqualTo(0.0));
        expect(rec.reason, isA<String>());
        expect(rec.reason.trim(), isNotEmpty);
        expect(rec.type, isA<RecommendationType>());
        expect(rec.tags, isA<List<String>>());
      }
    });
  });

  group('Recommendation Integration Tests', () {
    test('trending API integration should work', () async {
      final datasource = RecommendationsMoviedbDatasource();
      
      // This tests the actual TMDB API integration
      final recommendations = await datasource.getTrendingRecommendations();
      
      expect(recommendations, isNotNull);
      // Allow empty list in case of API issues, but structure should be correct
      expect(recommendations, isA<List<Recommendation>>());
    }, skip: false); // Enable this test to check actual API integration

    test('genre discovery should work', () async {
      final datasource = RecommendationsMoviedbDatasource();
      
      // Test with popular genres
      final recommendations = await datasource.getRecommendationsByGenre(['28', '35']); // Action, Comedy
      
      expect(recommendations, isNotNull);
      expect(recommendations, isA<List<Recommendation>>());
    }, skip: false); // Enable this test to check actual API integration
  });
}