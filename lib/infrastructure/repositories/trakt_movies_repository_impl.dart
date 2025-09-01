import '../../domain/entities/entities.dart';
import '../../domain/repositories/movies_repository.dart';
import '../mappers/trakt_mapper.dart';
import '../services/trakt_api_service.dart';

class TraktMoviesRepositoryImpl implements MoviesRepository {
  TraktMoviesRepositoryImpl(this._traktApiService);
  final TraktApiService _traktApiService;

  @override
  Future<List<Movie>> getNowPlaying({int page = 1}) async {
    // Trakt no tiene exactamente "now playing", usaremos trending
    final traktMovies =
        await _traktApiService.getTrendingMovies(page: page, limit: 20);
    return await TraktMovieMapper.toEntityList(traktMovies);
  }

  @override
  Future<List<Movie>> getPopular({int page = 1}) async {
    final traktMovies =
        await _traktApiService.getPopularMovies(page: page, limit: 20);
    return await TraktMovieMapper.toEntityList(traktMovies);
  }

  @override
  Future<List<Movie>> getUpcoming({int page = 1}) async {
    // Trakt no tiene "upcoming" exactamente, usaremos popular como fallback
    // En una implementación real, podrías filtrar por fecha de lanzamiento
    final traktMovies =
        await _traktApiService.getPopularMovies(page: page, limit: 20);

    // Filtrar películas con fecha de lanzamiento futura
    final now = DateTime.now();
    final upcomingMovies = traktMovies.where((movie) {
      return movie.released != null && movie.released!.isAfter(now);
    }).toList();

    return await TraktMovieMapper.toEntityList(upcomingMovies);
  }

  @override
  Future<List<Movie>> getTopRated({int page = 1}) async {
    // Trakt no tiene top rated específicamente, usaremos popular ordenado por rating
    final traktMovies =
        await _traktApiService.getPopularMovies(page: page, limit: 20);

    // Ordenar por rating (si está disponible)
    traktMovies.sort((a, b) {
      final aRating = a.rating ?? 0.0;
      final bRating = b.rating ?? 0.0;
      return bRating.compareTo(aRating);
    });

    return await TraktMovieMapper.toEntityList(traktMovies);
  }

  @override
  Future<Movie> getMovieById(String id) async {
    final traktMovie = await _traktApiService.getMovieDetails(id);
    return await TraktMovieMapper.toEntity(traktMovie);
  }

  @override
  Future<List<Movie>> searchMovies(String query) async {
    final traktMovies = await _traktApiService.searchMovies(query, limit: 20);
    return await TraktMovieMapper.toEntityList(traktMovies);
  }

  @override
  Future<List<Movie>> getSimilarMovies(int movieId) async {
    final traktMovies = await _traktApiService
        .getMovieRecommendations(movieId.toString(), limit: 20);
    return await TraktMovieMapper.toEntityList(traktMovies);
  }

  @override
  Future<List<Video>> getYoutubeVideosById(int movieId) async {
    // Trakt no proporciona videos directamente
    // Podrías implementar una llamada a TMDB usando el tmdb_id del movie
    // o devolver una lista vacía por ahora

    // Por ahora devolvemos lista vacía
    return [];

    // Implementación futura con TMDB:
    // final movie = await getMovieById(movieId.toString());
    // if (movie.tmdbId != null) {
    //   return await _tmdbApiService.getMovieVideos(movie.tmdbId!);
    // }
    // return [];
  }
}
