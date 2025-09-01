import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/domain/entities/watchlist_movie.dart';
import 'package:peliculas/infrastructure/datasources/watchlist_hive_datasource.dart';

void main() {
  group('Watchlist Functionality Tests', () {
    late WatchlistHiveDatasource datasource;
    late Movie testMovie;

    setUpAll(() async {
      // Initialize Hive in memory for testing
      // In a real test, you'd use Hive.init() with a test directory
    });

    setUp(() {
      datasource = WatchlistHiveDatasource();
      testMovie = Movie(
        id: 123,
        adult: false,
        backdropPath: '/backdrop.jpg',
        genreIds: ['Action', 'Adventure'],
        originalLanguage: 'en',
        originalTitle: 'Test Movie',
        overview: 'A test movie for watchlist functionality',
        popularity: 8.5,
        posterPath: '/poster.jpg',
        releaseDate: DateTime(2023, 6, 15),
        title: 'Test Movie',
        video: false,
        voteAverage: 7.5,
        voteCount: 1000,
      );
    });

    test('should add movie to watchlist with correct priority', () async {
      // Act
      await datasource.addToWatchlist(testMovie, WatchlistPriority.alta);

      // Assert
      final isInWatchlist = await datasource.isMovieInWatchlist(testMovie.id);
      expect(isInWatchlist, true);

      final watchlistMovie = await datasource.getWatchlistMovie(testMovie.id);
      expect(watchlistMovie, isNotNull);
      expect(watchlistMovie!.movieId, testMovie.id);
      expect(watchlistMovie.movieTitle, testMovie.title);
      expect(watchlistMovie.priority, WatchlistPriority.alta);
    });

    test('should remove movie from watchlist', () async {
      // Arrange
      await datasource.addToWatchlist(testMovie, WatchlistPriority.normal);

      // Act
      await datasource.removeFromWatchlist(testMovie.id);

      // Assert
      final isInWatchlist = await datasource.isMovieInWatchlist(testMovie.id);
      expect(isInWatchlist, false);

      final watchlistMovie = await datasource.getWatchlistMovie(testMovie.id);
      expect(watchlistMovie, isNull);
    });

    test('should update movie priority in watchlist', () async {
      // Arrange
      await datasource.addToWatchlist(testMovie, WatchlistPriority.normal);

      // Act
      await datasource.updateWatchlistPriority(testMovie.id, WatchlistPriority.alta);

      // Assert
      final watchlistMovie = await datasource.getWatchlistMovie(testMovie.id);
      expect(watchlistMovie, isNotNull);
      expect(watchlistMovie!.priority, WatchlistPriority.alta);
    });

    test('should load watchlist movies with correct ordering', () async {
      // Arrange - Add movies with different priorities
      final movie1 = testMovie.copyWith(id: 1, title: 'Movie 1');
      final movie2 = testMovie.copyWith(id: 2, title: 'Movie 2');
      final movie3 = testMovie.copyWith(id: 3, title: 'Movie 3');

      await datasource.addToWatchlist(movie1, WatchlistPriority.baja);
      await datasource.addToWatchlist(movie2, WatchlistPriority.alta);
      await datasource.addToWatchlist(movie3, WatchlistPriority.normal);

      // Act
      final watchlistMovies = await datasource.loadWatchlistMovies();

      // Assert
      expect(watchlistMovies.length, 3);
      // Should be ordered by priority: alta, normal, baja
      expect(watchlistMovies[0].priority, WatchlistPriority.alta);
      expect(watchlistMovies[1].priority, WatchlistPriority.normal);
      expect(watchlistMovies[2].priority, WatchlistPriority.baja);
    });

    test('should filter watchlist by priority', () async {
      // Arrange - Add movies with different priorities
      final movie1 = testMovie.copyWith(id: 1, title: 'Movie 1');
      final movie2 = testMovie.copyWith(id: 2, title: 'Movie 2');
      final movie3 = testMovie.copyWith(id: 3, title: 'Movie 3');

      await datasource.addToWatchlist(movie1, WatchlistPriority.alta);
      await datasource.addToWatchlist(movie2, WatchlistPriority.normal);
      await datasource.addToWatchlist(movie3, WatchlistPriority.alta);

      // Act
      final highPriorityMovies = await datasource.loadWatchlistMovies(
        priority: WatchlistPriority.alta,
      );

      // Assert
      expect(highPriorityMovies.length, 2);
      expect(highPriorityMovies.every((movie) => movie.priority == WatchlistPriority.alta), true);
    });

    test('should return correct watchlist count', () async {
      // Arrange
      expect(await datasource.getWatchlistCount(), 0);

      // Act - Add movies
      await datasource.addToWatchlist(testMovie, WatchlistPriority.normal);
      await datasource.addToWatchlist(
        testMovie.copyWith(id: 456, title: 'Another Movie'), 
        WatchlistPriority.alta,
      );

      // Assert
      expect(await datasource.getWatchlistCount(), 2);
    });

    test('WatchlistPriority enum should have correct values', () {
      expect(WatchlistPriority.alta.value, 'alta');
      expect(WatchlistPriority.normal.value, 'normal');
      expect(WatchlistPriority.baja.value, 'baja');

      expect(WatchlistPriority.alta.displayName, 'Alta');
      expect(WatchlistPriority.normal.displayName, 'Normal');
      expect(WatchlistPriority.baja.displayName, 'Baja');
    });

    test('WatchlistPriority.fromString should parse correctly', () {
      expect(WatchlistPriority.fromString('alta'), WatchlistPriority.alta);
      expect(WatchlistPriority.fromString('normal'), WatchlistPriority.normal);
      expect(WatchlistPriority.fromString('baja'), WatchlistPriority.baja);
      expect(WatchlistPriority.fromString('ALTA'), WatchlistPriority.alta);
      expect(WatchlistPriority.fromString('invalid'), WatchlistPriority.normal);
    });

    tearDown(() async {
      // Clean up
      await datasource.clear();
    });
  });
}