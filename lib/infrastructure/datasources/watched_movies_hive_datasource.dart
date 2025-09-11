import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/datasources/watched_movies_datasource.dart';
import '../../domain/entities/entities.dart';

class WatchedMoviesHiveDatasource extends WatchedMoviesDatasource {
  WatchedMoviesHiveDatasource() {
    _initHive();
  }

  Box<WatchedMovie>? _watchedMoviesBox;
  bool _isInitialized = false;

  Future<void> _initHive() async {
    if (_isInitialized) return;

    try {
      // Inicializar Hive de manera compatible con Web
      if (kIsWeb) {
        // En Web, Hive usa IndexedDB automáticamente
        await Hive.initFlutter();
      } else {
        // En plataformas nativas, usar el directorio por defecto
        await Hive.initFlutter();
      }

      // Registrar adaptadores si no están registrados
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(MovieAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(WatchedMovieAdapter());
      }

      _watchedMoviesBox = await Hive.openBox<WatchedMovie>('watched_movies');
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error(
            'Error inicializando Hive para películas vistas: $e');
      }
      // En caso de error, intentar con un nombre de box diferente
      try {
        _watchedMoviesBox =
            await Hive.openBox<WatchedMovie>('watched_movies_fallback');
        _isInitialized = true;
      } catch (e2) {
        if (kDebugMode) {
          LoggerFactory.error(
              'Error inicializando Hive con fallback para películas vistas: $e2');
        }
        rethrow;
      }
    }
  }

  @override
  Future<void> markAsWatched(Movie movie) async {
    try {
      if (!_isInitialized) await _initHive();
      if (_watchedMoviesBox == null) {
        throw Exception('Watched movies box not available');
      }

      // Verificar si ya está marcada como vista
      final isAlreadyWatched = await isMovieWatched(movie.id);
      if (isAlreadyWatched) return;

      // Crear WatchedMovie con fecha actual
      final watchedMovie = WatchedMovie(
        movie: movie,
        watchedDate: DateTime.now(),
        lastModifiedAt: DateTime.now(),
      );

      await _watchedMoviesBox?.add(watchedMovie);
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error marking movie as watched: $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> removeFromWatched(int movieId) async {
    try {
      if (!_isInitialized) await _initHive();
      if (_watchedMoviesBox == null) return;

      final box = _watchedMoviesBox;
      if (box == null) return;

      final existingMovieKey = box.keys.toList().cast<int>().firstWhere(
            (key) => box.get(key)?.movie.id == movieId,
            orElse: () => -1,
          );

      if (existingMovieKey != -1) {
        await box.delete(existingMovieKey);
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error removing movie from watched: $e');
      }
    }
  }

  @override
  Future<bool> isMovieWatched(int movieId) async {
    try {
      if (!_isInitialized) await _initHive();
      if (_watchedMoviesBox == null) return false;

      final box = _watchedMoviesBox;
      if (box == null) return false;

      final watchedMovies = box.values
          .toList()
          .where((watchedMovie) => watchedMovie.movie.id == movieId);
      return watchedMovies.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error checking if movie is watched: $e');
      }
      return false;
    }
  }

  @override
  Future<List<WatchedMovie>> loadWatchedMovies(
      {int limit = 10, int offset = 0}) async {
    try {
      if (!_isInitialized) await _initHive();
      if (_watchedMoviesBox == null) return [];

      final box = _watchedMoviesBox;
      if (box == null) return [];

      final allWatchedMovies = box.values.toList();

      // Ordenar por fecha de visualización (más recientes primero)
      allWatchedMovies.sort((a, b) => b.watchedDate.compareTo(a.watchedDate));

      final endIndex = (offset + limit).clamp(0, allWatchedMovies.length);

      if (offset >= allWatchedMovies.length) return [];

      return allWatchedMovies.sublist(offset, endIndex);
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error loading watched movies: $e');
      }
      return [];
    }
  }

  // Método para limpiar todos los datos
  Future<void> clearAll() async {
    try {
      if (!_isInitialized) await _initHive();
      if (_watchedMoviesBox != null) {
        await _watchedMoviesBox?.clear();
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error clearing all watched movies: $e');
      }
    }
  }

  // Método para cerrar la base de datos
  Future<void> close() async {
    try {
      if (_watchedMoviesBox?.isOpen ?? false) {
        await _watchedMoviesBox?.close();
      }
      _isInitialized = false;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error closing watched movies database: $e');
      }
    }
  }
}
