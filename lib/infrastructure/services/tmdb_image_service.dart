import 'package:dio/dio.dart';

import '../../config/constants/environment.dart';
import '../../core/logging/logger_factory.dart';

class TmdbImageService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p';

  final Dio _dio = Dio();

  // Tamaños de imagen disponibles en TMDB
  static const String posterW154 = 'w154';
  static const String posterW185 = 'w185';
  static const String posterW342 = 'w342';
  static const String posterW500 = 'w500';
  static const String posterW780 = 'w780';
  static const String posterOriginal = 'original';

  static const String backdropW300 = 'w300';
  static const String backdropW780 = 'w780';
  static const String backdropW1280 = 'w1280';
  static const String backdropOriginal = 'original';

  /// Obtener URL del poster usando TMDB ID
  Future<String?> getPosterUrl(int? tmdbId, {String size = posterW500}) async {
    if (tmdbId == null) return null;

    try {
      final response = await _dio.get(
        '$_baseUrl/movie/$tmdbId',
        queryParameters: {
          'api_key': Environment.theMovieDbKey,
        },
      );

      if (response.statusCode == 200) {
        final posterPath = response.data['poster_path'];
        if (posterPath != null) {
          return '$_imageBaseUrl/$size$posterPath';
        }
      }
    } catch (e) {
      LoggerFactory.error('Error fetching poster for TMDB ID $tmdbId: $e');
    }

    return null;
  }

  /// Obtener URL del backdrop usando TMDB ID
  Future<String?> getBackdropUrl(int? tmdbId,
      {String size = backdropW780}) async {
    if (tmdbId == null) return null;

    try {
      final response = await _dio.get(
        '$_baseUrl/movie/$tmdbId',
        queryParameters: {
          'api_key': Environment.theMovieDbKey,
        },
      );

      if (response.statusCode == 200) {
        final backdropPath = response.data['backdrop_path'];
        if (backdropPath != null) {
          return '$_imageBaseUrl/$size$backdropPath';
        }
      }
    } catch (e) {
      LoggerFactory.error('Error fetching backdrop for TMDB ID $tmdbId: $e');
    }

    return null;
  }

  /// Obtener tanto poster como backdrop en una sola llamada
  Future<MovieImages> getMovieImages(int? tmdbId) async {
    if (tmdbId == null) {
      return const MovieImages(posterUrl: null, backdropUrl: null);
    }

    try {
      final response = await _dio.get(
        '$_baseUrl/movie/$tmdbId',
        queryParameters: {
          'api_key': Environment.theMovieDbKey,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final posterPath = data['poster_path'];
        final backdropPath = data['backdrop_path'];

        return MovieImages(
          posterUrl: posterPath != null
              ? '$_imageBaseUrl/$posterW500$posterPath'
              : null,
          backdropUrl: backdropPath != null
              ? '$_imageBaseUrl/$backdropW780$backdropPath'
              : null,
        );
      }
    } catch (e) {
      LoggerFactory.error('Error fetching images for TMDB ID $tmdbId: $e');
    }

    return const MovieImages(posterUrl: null, backdropUrl: null);
  }

  /// Cache simple para evitar peticiones repetidas
  final Map<int, MovieImages> _imageCache = {};

  Future<MovieImages> getMovieImagesWithCache(int? tmdbId) async {
    if (tmdbId == null) {
      return const MovieImages(posterUrl: null, backdropUrl: null);
    }

    if (_imageCache.containsKey(tmdbId)) {
      return _imageCache[tmdbId]!;
    }

    final images = await getMovieImages(tmdbId);
    _imageCache[tmdbId] = images;
    return images;
  }
}

class MovieImages {
  const MovieImages({
    required this.posterUrl,
    required this.backdropUrl,
  });

  final String? posterUrl;
  final String? backdropUrl;
}
