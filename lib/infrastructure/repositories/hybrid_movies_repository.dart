import '../../core/logging/logger_factory.dart';
import '../../domain/datasources/movies_datasource.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/video.dart';
import '../../domain/repositories/movies_repository.dart';
import '../mappers/trakt_mapper.dart';
import '../services/trakt_api_service.dart';

/// Repositorio híbrido que prioriza Trakt.tv con fallback a TMDB
class HybridMoviesRepository implements MoviesRepository {
  HybridMoviesRepository({
    required TraktApiService traktApiService,
    required MoviesDatasource tmdbDatasource,
  })  : _traktApiService = traktApiService,
        _tmdbDatasource = tmdbDatasource;
  final TraktApiService _traktApiService;
  final MoviesDatasource _tmdbDatasource;
  final Map<String, List<Movie>> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Duration _cacheTimeout = const Duration(minutes: 30);

  /// Verifica si el cache es válido para una clave específica
  bool _isCacheValid(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheTimeout;
  }

  /// Guarda datos en cache con timestamp
  void _saveToCache(String key, List<Movie> data) {
    _cache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
  }

  /// Obtiene datos del cache si es válido
  List<Movie>? _getFromCache(String key) {
    if (_isCacheValid(key)) {
      return _cache[key];
    }
    return null;
  }

  /// Método principal para obtener películas con sistema de prioridades
  Future<List<Movie>> _getMoviesWithFallback(
    String cacheKey,
    Future<List<Movie>> Function() traktCall,
    Future<List<Movie>> Function() tmdbCall,
  ) async {
    // 1. Verificar cache
    final cachedData = _getFromCache(cacheKey);
    if (cachedData != null) {
      return cachedData;
    }

    try {
      // 2. Intentar con Trakt (prioridad alta)
      LoggerFactory.info('🎬 Intentando obtener datos de Trakt...');
      final traktMovies = await traktCall();

      if (traktMovies.isNotEmpty) {
        LoggerFactory.info(
            '✅ Datos obtenidos de Trakt: ${traktMovies.length} películas');
        _saveToCache(cacheKey, traktMovies);
        return traktMovies;
      }
    } catch (e) {
      LoggerFactory.warning('⚠️ Error en Trakt, usando fallback a TMDB: $e');
    }

    try {
      // 3. Fallback a TMDB
      LoggerFactory.info('🔄 Fallback: obteniendo datos de TMDB...');
      final tmdbMovies = await tmdbCall();

      if (tmdbMovies.isNotEmpty) {
        LoggerFactory.info(
            '✅ Datos obtenidos de TMDB: ${tmdbMovies.length} películas');
        _saveToCache(cacheKey, tmdbMovies);
        return tmdbMovies;
      }
    } catch (e) {
      LoggerFactory.error('❌ Error también en TMDB: $e');
      throw Exception('Error en ambas fuentes de datos: Trakt y TMDB');
    }

    return [];
  }

  @override
  Future<List<Movie>> getNowPlaying({int page = 1}) async {
    return _getMoviesWithFallback(
      'now_playing_$page',
      () async {
        // Trakt: usar trending como "now playing"
        final traktMovies = await _traktApiService.getTrendingMovies(
          page: page,
          limit: 20,
        );
        return await TraktMovieMapper.toEntityList(traktMovies);
      },
      () => _tmdbDatasource.getNowPlaying(page: page),
    );
  }

  @override
  Future<List<Movie>> getPopular({int page = 1}) async {
    return _getMoviesWithFallback(
      'popular_$page',
      () async {
        final traktMovies = await _traktApiService.getPopularMovies(
          page: page,
          limit: 20,
        );
        return await TraktMovieMapper.toEntityList(traktMovies);
      },
      () => _tmdbDatasource.getPopular(page: page),
    );
  }

  @override
  Future<List<Movie>> getUpcoming({int page = 1}) async {
    return _getMoviesWithFallback(
      'upcoming_$page',
      () async {
        // Trakt: filtrar películas populares por fecha futura
        final traktMovies = await _traktApiService.getPopularMovies(
          page: page,
          limit: 20,
        );

        final now = DateTime.now();
        final upcomingMovies = traktMovies.where((movie) {
          return movie.released != null && movie.released!.isAfter(now);
        }).toList();

        return await TraktMovieMapper.toEntityList(upcomingMovies);
      },
      () => _tmdbDatasource.getUpcoming(page: page),
    );
  }

  @override
  Future<List<Movie>> getTopRated({int page = 1}) async {
    return _getMoviesWithFallback(
      'top_rated_$page',
      () async {
        final traktMovies = await _traktApiService.getPopularMovies(
          page: page,
          limit: 20,
        );

        // Ordenar por rating
        traktMovies.sort((a, b) {
          final aRating = a.rating ?? 0.0;
          final bRating = b.rating ?? 0.0;
          return bRating.compareTo(aRating);
        });

        return await TraktMovieMapper.toEntityList(traktMovies);
      },
      () => _tmdbDatasource.getTopRated(page: page),
    );
  }

  @override
  Future<Movie> getMovieById(String id) async {
    final cacheKey = 'movie_$id';

    // Verificar cache para película individual
    final cachedMovies = _getFromCache(cacheKey);
    if (cachedMovies != null && cachedMovies.isNotEmpty) {
      return cachedMovies.first;
    }

    try {
      // 1. Intentar con Trakt primero
      LoggerFactory.info('🎬 Obteniendo película $id de Trakt...');
      final traktMovie = await _traktApiService.getMovieDetails(id);
      final movie = await TraktMovieMapper.toEntity(traktMovie);

      // Guardar en cache
      _saveToCache(cacheKey, [movie]);
      return movie;
    } catch (e) {
      LoggerFactory.warning('⚠️ Error obteniendo película de Trakt: $e');

      try {
        // 2. Fallback a TMDB
        LoggerFactory.info('🔄 Fallback: obteniendo película $id de TMDB...');
        final movie = await _tmdbDatasource.getMovieById(id);

        // Guardar en cache
        _saveToCache(cacheKey, [movie]);
        return movie;
      } catch (tmdbError) {
        LoggerFactory.error('❌ Error también en TMDB: $tmdbError');
        throw Exception('Película no encontrada en ninguna fuente: $id');
      }
    }
  }

  @override
  Future<List<Movie>> searchMovies(String query) async {
    if (query.trim().isEmpty) return [];

    return _getMoviesWithFallback(
      'search_${query.hashCode}',
      () async {
        final traktMovies = await _traktApiService.searchMovies(
          query,
          limit: 20,
        );
        return await TraktMovieMapper.toEntityList(traktMovies);
      },
      () => _tmdbDatasource.searchMovies(query),
    );
  }

  @override
  Future<List<Movie>> getSimilarMovies(int movieId) async {
    return _getMoviesWithFallback(
      'similar_$movieId',
      () async {
        final traktMovies = await _traktApiService.getMovieRecommendations(
          movieId.toString(),
          limit: 20,
        );
        return await TraktMovieMapper.toEntityList(traktMovies);
      },
      () => _tmdbDatasource.getSimilarMovies(movieId),
    );
  }

  @override
  Future<List<Video>> getYoutubeVideosById(int movieId) async {
    try {
      // Trakt no tiene videos, usar TMDB directamente
      return await _tmdbDatasource.getYoutubeVideosById(movieId);
    } catch (e) {
      LoggerFactory.warning('⚠️ Error obteniendo videos: $e');
      return [];
    }
  }

  /// Limpia el cache del repositorio
  void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  /// Obtiene estadísticas del repositorio híbrido
  Map<String, dynamic> getStats() {
    return {
      'cache_entries': _cache.length,
      'cache_timeout_minutes': _cacheTimeout.inMinutes,
    };
  }
}
