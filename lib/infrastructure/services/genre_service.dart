import 'package:dio/dio.dart';

import '../../config/constants/environment.dart';
import '../../core/logging/logger_factory.dart';

/// Servicio para obtener y cachear los géneros de películas desde TMDB
class GenreService {
  GenreService._();

  static GenreService? _instance;
  static GenreService get instance {
    _instance ??= GenreService._();
    return _instance!;
  }

  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.themoviedb.org/3',
    queryParameters: {
      'api_key': Environment.theMovieDbKey,
      'language': 'es-MX'
    },
  ));

  // Cache de géneros en memoria
  Map<int, String>? _genresCache;
  DateTime? _cacheTimestamp;
  static const _cacheDuration = Duration(hours: 24);

  /// Obtiene todos los géneros de películas desde TMDB
  /// Los cachea en memoria para evitar llamadas repetidas
  Future<Map<int, String>> getGenres() async {
    // Verificar si el cache es válido
    if (_genresCache != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      LoggerFactory.debug('🎬 Géneros obtenidos desde cache');
      return _genresCache!;
    }

    try {
      LoggerFactory.info('🎬 Obteniendo géneros desde TMDB API...');
      final response = await dio.get('/genre/movie/list');

      final genres = response.data['genres'] as List;
      final genresMap = <int, String>{};

      for (final genre in genres) {
        genresMap[genre['id'] as int] = genre['name'] as String;
      }

      _genresCache = genresMap;
      _cacheTimestamp = DateTime.now();

      LoggerFactory.info('✅ ${genresMap.length} géneros obtenidos y cacheados');
      LoggerFactory.debug('Géneros: ${genresMap.values.join(', ')}');

      return genresMap;
    } catch (e, stackTrace) {
      LoggerFactory.error(
          '❌ Error obteniendo géneros de TMDB: $e\n$stackTrace');

      // Fallback a géneros hardcoded si falla la API
      return _getFallbackGenres();
    }
  }

  /// Obtiene el nombre de un género por su ID
  Future<String> getGenreName(int genreId) async {
    final genres = await getGenres();
    return genres[genreId] ?? 'Desconocido';
  }

  /// Obtiene los nombres de múltiples géneros por sus IDs
  Future<List<String>> getGenreNames(List<int> genreIds) async {
    final genres = await getGenres();
    return genreIds.map((id) => genres[id] ?? 'Desconocido').toList();
  }

  /// Invalida el cache forzando una recarga en la próxima petición
  void invalidateCache() {
    _genresCache = null;
    _cacheTimestamp = null;
    LoggerFactory.info('🔄 Cache de géneros invalidado');
  }

  /// Géneros de fallback en caso de que falle la API
  /// Estos son los géneros oficiales de TMDB actualizados a 2025
  Map<int, String> _getFallbackGenres() {
    LoggerFactory.warning('⚠️ Usando géneros de fallback');
    return {
      28: 'Acción',
      12: 'Aventura',
      16: 'Animación',
      35: 'Comedia',
      80: 'Crimen',
      99: 'Documental',
      18: 'Drama',
      10751: 'Familiar',
      14: 'Fantasía',
      36: 'Historia',
      27: 'Terror',
      10402: 'Música',
      9648: 'Misterio',
      10749: 'Romance',
      878: 'Ciencia ficción',
      10770: 'Película de TV',
      53: 'Suspense',
      10752: 'Guerra',
      37: 'Western',
    };
  }

  /// Precarga los géneros al inicializar la app
  Future<void> preloadGenres() async {
    await getGenres();
  }
}
