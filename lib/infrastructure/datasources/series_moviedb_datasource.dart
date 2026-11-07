import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/constants/environment.dart';
import '../../core/logging/logger_factory.dart';
import '../../domain/datasources/series_datasource.dart';
import '../../domain/entities/entities.dart';
import '../mappers/serie_mapper.dart';
import '../models/moviedb/serie_moviedb.dart';
import '../models/moviedb/serie_response.dart';

class SeriesMoviedbDatasource extends SeriesDatasource {
  final dio = Dio(BaseOptions(
      baseUrl: 'https://api.themoviedb.org/3',
      queryParameters: {
        'api_key': Environment.theMovieDbKey,
        'language': 'es-MX'
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: kIsWeb ? null : const Duration(seconds: 10)));

  List<Serie> _jsonToSeries(Map<String, dynamic> json) {
    final response = SerieDbResponse.fromJson(json);
    final List<Serie> series = response.results
        .where((tv) => tv.posterPath != 'no-poster' && tv.posterPath.isNotEmpty)
        .map((tv) => SerieMapper.serieDBToEntity(tv))
        .toList();
    return series;
  }

  Future<List<Serie>> _getList(String path, String label, {int page = 1}) async {
    LoggerFactory.info('🌐 API Call: $label - página $page');
    try {
      final response =
          await dio.get(path, queryParameters: {'page': page});
      return _jsonToSeries(response.data);
    } on DioException catch (e) {
      LoggerFactory.error('❌ DioException en $label: ${e.message}');
      throw Exception('Error al obtener series ($label): ${e.message}');
    } catch (e) {
      LoggerFactory.error('❌ Exception en $label: $e');
      throw Exception('Error inesperado al obtener series ($label): $e');
    }
  }

  @override
  Future<List<Serie>> getPopular({int page = 1}) =>
      _getList('/tv/popular', 'getPopularSeries', page: page);

  @override
  Future<List<Serie>> getTopRated({int page = 1}) =>
      _getList('/tv/top_rated', 'getTopRatedSeries', page: page);

  @override
  Future<List<Serie>> getOnTheAir({int page = 1}) =>
      _getList('/tv/on_the_air', 'getOnTheAirSeries', page: page);

  @override
  Future<List<Serie>> getAiringToday({int page = 1}) =>
      _getList('/tv/airing_today', 'getAiringTodaySeries', page: page);

  @override
  Future<Serie> getSerieById(String id) async {
    try {
      final response = await dio.get('/tv/$id', queryParameters: {
        'append_to_response':
            'credits,videos,images,reviews,similar,keywords,content_ratings,watch/providers'
      });
      if (response.statusCode != 200) {
        throw Exception('Serie con id: $id no encontrada');
      }
      return SerieMapper.serieDetailsToEntity(
          Map<String, dynamic>.from(response.data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Serie con id: $id no encontrada');
      }
      throw Exception('Error al obtener detalles de la serie: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al obtener detalles de la serie: $e');
    }
  }

  @override
  Future<List<Temporada>> getSeasons(int serieId) async {
    final serie = await getSerieById(serieId.toString());
    final seasons = <Temporada>[];
    for (var n = 1; n <= serie.numberOfSeasons; n++) {
      try {
        seasons.add(await getSeason(serieId, n));
      } catch (_) {
        // Temporada no disponible: se omite sin romper el resto.
      }
    }
    return seasons;
  }

  @override
  Future<Temporada> getSeason(int serieId, int seasonNumber) async {
    try {
      final response = await dio.get('/tv/$serieId/season/$seasonNumber');
      return SerieMapper.seasonToEntity(
          serieId, Map<String, dynamic>.from(response.data));
    } on DioException catch (e) {
      throw Exception('Error al obtener temporada: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al obtener temporada: $e');
    }
  }

  @override
  Future<List<Episodio>> getEpisodes(int serieId, int seasonNumber) async {
    try {
      final response = await dio.get('/tv/$serieId/season/$seasonNumber');
      final data = Map<String, dynamic>.from(response.data);
      final episodes = (data['episodes'] as List?) ?? [];
      return episodes
          .map((e) => SerieMapper.episodeToEntity(
              serieId, seasonNumber, Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw Exception('Error al obtener episodios: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al obtener episodios: $e');
    }
  }

  @override
  Future<List<Serie>> searchSeries(String query) async {
    if (query.isEmpty) return [];
    try {
      final response =
          await dio.get('/search/tv', queryParameters: {'query': query});
      return _jsonToSeries(response.data);
    } on DioException catch (e) {
      throw Exception('Error al buscar series: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al buscar series: $e');
    }
  }

  @override
  Future<List<Serie>> getSimilarSeries(int serieId) async {
    try {
      final response = await dio.get('/tv/$serieId/similar');
      return _jsonToSeries(response.data);
    } on DioException catch (e) {
      throw Exception('Error al obtener series similares: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado al obtener series similares: $e');
    }
  }

  List<Serie> seriesFromTraktJson(List<Map<String, dynamic>> items) {
    return items
        .map((e) => SerieMovieDB.fromJson(e))
        .where((tv) => tv.posterPath.isNotEmpty)
        .map((tv) => SerieMapper.serieDBToEntity(tv))
        .toList();
  }
}
