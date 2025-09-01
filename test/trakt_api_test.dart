import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/logging/logger_factory.dart';
import 'package:peliculas/infrastructure/services/trakt_api_service.dart';

void main() {
  group('Trakt API Service Tests', () {
    late TraktApiService traktService;

    setUpAll(() async {
      // Cargar variables de entorno para testing
      TestWidgetsFlutterBinding.ensureInitialized();
      await dotenv.load(fileName: '.env');
      traktService = TraktApiService();
    });

    test('should fetch popular movies from Trakt', () async {
      // Arrange & Act
      final movies = await traktService.getPopularMovies(limit: 5);

      // Assert
      expect(movies, isNotEmpty);
      expect(movies.length, lessThanOrEqualTo(5));
      expect(movies.first.title, isNotEmpty);
      expect(movies.first.year, greaterThan(1900));
      expect(movies.first.ids.trakt, greaterThan(0));

      LoggerFactory.info('✅ Películas populares obtenidas: ${movies.length}');
      LoggerFactory.info(
          'Primera película: ${movies.first.title} (${movies.first.year})');
    });

    test('should fetch trending movies from Trakt', () async {
      // Arrange & Act
      final movies = await traktService.getTrendingMovies(limit: 5);

      // Assert
      expect(movies, isNotEmpty);
      expect(movies.length, lessThanOrEqualTo(5));
      expect(movies.first.title, isNotEmpty);

      LoggerFactory.info('✅ Películas trending obtenidas: ${movies.length}');
      LoggerFactory.info(
          'Primera película trending: ${movies.first.title} (${movies.first.year})');
    });

    test('should search movies in Trakt', () async {
      // Arrange & Act
      final movies = await traktService.searchMovies('The Matrix', limit: 3);

      // Assert
      expect(movies, isNotEmpty);
      expect(
          movies.any((movie) => movie.title.toLowerCase().contains('matrix')),
          isTrue);

      LoggerFactory.info(
          '✅ Búsqueda "The Matrix" exitosa: ${movies.length} resultados');
      LoggerFactory.info(
          'Primer resultado: ${movies.first.title} (${movies.first.year})');
    });

    test('should get movie details from Trakt', () async {
      // Arrange - Primero obtener una película popular para usar su ID
      final popularMovies = await traktService.getPopularMovies(limit: 1);
      expect(popularMovies, isNotEmpty);

      final movieId = popularMovies.first.ids.trakt.toString();

      // Act
      final movie = await traktService.getMovieDetails(movieId);

      // Assert
      expect(movie.title, isNotEmpty);
      expect(movie.ids.trakt, equals(popularMovies.first.ids.trakt));
      expect(movie.overview, isNotNull);

      LoggerFactory.info('✅ Detalles de película obtenidos: ${movie.title}');
      LoggerFactory.info('Overview: ${movie.overview?.substring(0, 100)}...');
    });

    test('should get movie genres from Trakt', () async {
      // Arrange & Act
      final genres = await traktService.getMovieGenres();

      // Assert
      expect(genres, isNotEmpty);
      expect(genres, contains('Action'));
      expect(genres, contains('Drama'));
      expect(genres, contains('Comedy'));

      LoggerFactory.info('✅ Géneros de películas obtenidos: ${genres.length}');
      LoggerFactory.info('Géneros: ${genres.take(5).join(', ')}...');
    });
  });
}
