import 'package:dio/dio.dart';

import '../../config/constants/environment.dart';
import '../../domain/datasources/movies_datasource.dart';
import '../../domain/entities/entities.dart';
import '../mappers/mappers.dart';
import '../models/models.dart';

class MoviedbDatasource extends MoviesDatasource {
  final dio = Dio(BaseOptions(
      baseUrl: 'https://api.themoviedb.org/3',
      queryParameters: {
        'api_key': Environment.theMovieDbKey,
        'language': 'es-MX'
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10)));

  List<Movie> _jsonToMovies(Map<String, dynamic> json) {
    final movieDBResponse = MovieDbResponse.fromJson(json);

    final List<Movie> movies = movieDBResponse.results
        .where((moviedb) => moviedb.posterPath != 'no-poster')
        .map((moviedb) => MovieMapper.movieDBToEntity(moviedb))
        .toList();

    return movies;
  }

  @override
  Future<List<Movie>> getNowPlaying({int page = 1}) async {
    try {
      final response =
          await dio.get('/movie/now_playing', queryParameters: {'page': page});
      return _jsonToMovies(response.data);
    } on DioException catch (e) {
      throw Exception('Error al obtener películas en cartelera: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al obtener películas en cartelera: $e');
    }
  }

  @override
  Future<List<Movie>> getPopular({int page = 1}) async {
    try {
      final response =
          await dio.get('/movie/popular', queryParameters: {'page': page});
      return _jsonToMovies(response.data);
    } on DioException catch (e) {
      throw Exception('Error al obtener películas populares: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al obtener películas populares: $e');
    }
  }

  @override
  Future<List<Movie>> getTopRated({int page = 1}) async {
    try {
      final response =
          await dio.get('/movie/top_rated', queryParameters: {'page': page});
      return _jsonToMovies(response.data);
    } on DioException catch (e) {
      throw Exception('Error al obtener películas mejor valoradas: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al obtener películas mejor valoradas: $e');
    }
  }

  @override
  Future<List<Movie>> getUpcoming({int page = 1}) async {
    try {
      final response =
          await dio.get('/movie/upcoming', queryParameters: {'page': page});
      return _jsonToMovies(response.data);
    } on DioException catch (e) {
      throw Exception('Error al obtener próximas películas: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al obtener próximas películas: $e');
    }
  }

  @override
  Future<Movie> getMovieById(String id) async {
    try {
      // Usar append_to_response para obtener datos adicionales en una sola llamada
      final response = await dio.get('/movie/$id', queryParameters: {
        'append_to_response': 'credits,videos,images,reviews,similar,keywords,watch/providers'
      });
      if (response.statusCode != 200) {
        throw Exception('Película con id: $id no encontrada');
      }
      final movieDetails = MovieDetails.fromJson(response.data);
      final Movie movie = MovieMapper.movieDetailsToEntity(movieDetails);
      return movie;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Película con id: $id no encontrada');
      }
      throw Exception('Error al obtener detalles de la película: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al obtener detalles de la película: $e');
    }
  }

  @override
  Future<List<Movie>> searchMovies(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final response =
          await dio.get('/search/movie', queryParameters: {'query': query});
      return _jsonToMovies(response.data);
    } on DioException catch (e) {
      throw Exception('Error al buscar películas: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al buscar películas: $e');
    }
  }

  @override
  Future<List<Movie>> getSimilarMovies(int movieId) async {
    try {
      final response = await dio.get('/movie/$movieId/similar');
      return _jsonToMovies(response.data);
    } on DioException catch (e) {
      throw Exception('Error al obtener películas similares: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al obtener películas similares: $e');
    }
  }

  @override
  Future<List<Video>> getYoutubeVideosById(int movieId) async {
    try {
      final response = await dio.get('/movie/$movieId/videos');
      final moviedbVideosReponse = MoviedbVideosResponse.fromJson(response.data);
      final videos = <Video>[];

      for (final moviedbVideo in moviedbVideosReponse.results) {
        if (moviedbVideo.site == 'YouTube') {
          final video = VideoMapper.moviedbVideoToEntity(moviedbVideo);
          videos.add(video);
        }
      }

      return videos;
    } on DioException catch (e) {
      throw Exception('Error al obtener videos de YouTube: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al obtener videos de YouTube: $e');
    }
  }
}
