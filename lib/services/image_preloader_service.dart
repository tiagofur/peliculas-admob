import 'dart:async';

import 'package:logging/logging.dart';

import '../core/cache/image_cache_manager.dart';
import '../core/cache/network_aware_strategy.dart';
import '../domain/entities/movie.dart';

/// Servicio de precarga de imágenes en segundo plano
/// Optimiza la experiencia del usuario precargando imágenes populares
class ImagePreloaderService {
  factory ImagePreloaderService() => _instance;

  ImagePreloaderService._internal();
  static final ImagePreloaderService _instance =
      ImagePreloaderService._internal();

  final Logger _logger = Logger('ImagePreloaderService');
  final Set<String> _preloadedUrls = <String>{};
  final Set<String> _preloadingUrls = <String>{};
  Timer? _preloadTimer;
  bool _isPreloadingEnabled = true;
  int _maxConcurrentPreloads = 3;
  int _currentPreloads = 0;

  /// Configuración del servicio de precarga
  void configure({
    bool? enabled,
    int? maxConcurrentPreloads,
  }) {
    _isPreloadingEnabled = enabled ?? _isPreloadingEnabled;
    _maxConcurrentPreloads = maxConcurrentPreloads ?? _maxConcurrentPreloads;

    _logger.info(
        'ImagePreloader configured: enabled=$_isPreloadingEnabled, maxConcurrent=$_maxConcurrentPreloads');
  }

  /// Precarga una lista de películas populares con estrategia adaptativa
  Future<void> preloadPopularMovies(
    List<Movie> movies, {
    int priority = 1,
    Duration delay = const Duration(milliseconds: 500),
  }) async {
    if (!_isPreloadingEnabled || movies.isEmpty) return;

    // Verificar condiciones de red antes de precargar
    final networkStrategy = NetworkAwareStrategy.instance.getDownloadStrategy();
    if (!networkStrategy.enablePreloading) {
      _logger.info('Precarga deshabilitada por condiciones de red');
      return;
    }

    _logger.info('Starting adaptive preload for ${movies.length} popular movies');

    // Ordenar por popularidad (voteAverage * voteCount)
    final sortedMovies = List<Movie>.from(movies)
      ..sort((a, b) =>
          (b.voteAverage * b.voteCount).compareTo(a.voteAverage * a.voteCount));

    // Ajustar cantidad según estrategia de red
    final maxToPreload = (networkStrategy.preloadDistance * 2).clamp(5, 20);
    final moviesToPreload = sortedMovies.take(maxToPreload).toList();

    for (int i = 0; i < moviesToPreload.length; i++) {
      final movie = moviesToPreload[i];

      // Ajustar delay según condiciones de red
      final adaptiveDelay = Duration(
        milliseconds: (delay.inMilliseconds * (networkStrategy.retryDelay.inSeconds / 3)).round(),
      );

      if (i > 0) {
        await Future.delayed(adaptiveDelay);
      }

      await _preloadMovieImages(movie, priority: priority);
    }
  }

  /// Precarga imágenes de una película específica
  Future<void> _preloadMovieImages(Movie movie, {int priority = 1}) async {
    if (_currentPreloads >= _maxConcurrentPreloads) {
      _logger.fine('Max concurrent preloads reached, skipping ${movie.title}');
      return;
    }

    final urls = <String>[
      movie.posterPath,
      if (movie.backdropPath.isNotEmpty) movie.backdropPath,
    ];

    for (final url in urls) {
      if (_preloadedUrls.contains(url) || _preloadingUrls.contains(url)) {
        continue;
      }

      _preloadingUrls.add(url);
      _currentPreloads++;

      try {
        _logger.fine('Preloading image: $url');
        await ImageCacheManager.instance.getCachedImage(url);
        _preloadedUrls.add(url);
        _logger.fine('Successfully preloaded: $url');
      } catch (e) {
        _logger.warning('Failed to preload $url: $e');
      } finally {
        _preloadingUrls.remove(url);
        _currentPreloads--;
      }
    }
  }

  /// Precarga inteligente basada en el comportamiento del usuario
  void preloadBasedOnUserBehavior({
    required List<Movie> recentlyViewed,
    required List<Movie> favorites,
    required List<Movie> trending,
  }) {
    if (!_isPreloadingEnabled) return;

    _logger.info('Starting intelligent preload based on user behavior');

    // Cancelar timer anterior si existe
    _preloadTimer?.cancel();

    // Programar precarga escalonada
    _preloadTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        // Prioridad 1: Películas relacionadas con las vistas recientemente
        if (recentlyViewed.isNotEmpty) {
          await preloadPopularMovies(
            recentlyViewed.take(3).toList(),
            priority: 1,
            delay: const Duration(milliseconds: 300),
          );
        }

        // Prioridad 2: Favoritos del usuario
        if (favorites.isNotEmpty) {
          await preloadPopularMovies(
            favorites.take(5).toList(),
            priority: 2,
            delay: const Duration(milliseconds: 400),
          );
        }

        // Prioridad 3: Películas trending
        if (trending.isNotEmpty) {
          await preloadPopularMovies(
            trending.take(8).toList(),
            priority: 3,
            delay: const Duration(milliseconds: 500),
          );
        }

        // Detener después de una ronda completa
        timer.cancel();
        _logger.info('Intelligent preload completed');
      } catch (e) {
        _logger.severe('Error in intelligent preload: $e');
        timer.cancel();
      }
    });
  }

  /// Precarga imágenes de una lista específica (ej: slideshow)
  Future<void> preloadListImages(
    List<String> imageUrls, {
    int maxImages = 5,
    Duration delay = const Duration(milliseconds: 200),
  }) async {
    if (!_isPreloadingEnabled || imageUrls.isEmpty) return;

    _logger.info('Preloading ${imageUrls.length} list images');

    final urlsToPreload = imageUrls.take(maxImages).toList();

    for (int i = 0; i < urlsToPreload.length; i++) {
      final url = urlsToPreload[i];

      if (_preloadedUrls.contains(url) || _preloadingUrls.contains(url)) {
        continue;
      }

      if (i > 0) {
        await Future.delayed(delay);
      }

      if (_currentPreloads >= _maxConcurrentPreloads) {
        _logger.fine('Max concurrent preloads reached, stopping list preload');
        break;
      }

      _preloadingUrls.add(url);
      _currentPreloads++;

      try {
        await ImageCacheManager.instance.getCachedImage(url);
        _preloadedUrls.add(url);
        _logger.fine('Preloaded list image: $url');
      } catch (e) {
        _logger.warning('Failed to preload list image $url: $e');
      } finally {
        _preloadingUrls.remove(url);
        _currentPreloads--;
      }
    }
  }

  /// Limpia las URLs precargadas (útil para liberar memoria)
  void clearPreloadedUrls() {
    _preloadedUrls.clear();
    _logger.info('Cleared preloaded URLs cache');
  }

  /// Detiene todas las operaciones de precarga
  void stopPreloading() {
    _preloadTimer?.cancel();
    _preloadTimer = null;
    _logger.info('Stopped all preloading operations');
  }

  /// Obtiene estadísticas del servicio de precarga
  Map<String, dynamic> getStats() {
    return {
      'preloadedCount': _preloadedUrls.length,
      'currentlyPreloading': _preloadingUrls.length,
      'currentPreloads': _currentPreloads,
      'maxConcurrentPreloads': _maxConcurrentPreloads,
      'isEnabled': _isPreloadingEnabled,
    };
  }

  /// Libera recursos del servicio
  void dispose() {
    stopPreloading();
    clearPreloadedUrls();
    _preloadingUrls.clear();
    _logger.info('ImagePreloaderService disposed');
  }
}
