import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/adapters/legacy_hive_adapters.dart';
import '../../domain/datasources/watched_movies_datasource.dart';
import '../../domain/entities/entities.dart';

class WatchedMoviesHiveDatasource extends WatchedMoviesDatasource {
  WatchedMoviesHiveDatasource() {
    _initHive();
  }

  Box<WatchedMovie>? _watchedMoviesBox;
  bool _isInitialized = false;
  Future<void>? _initFuture;

  /// Serialized init: concurrent callers (constructor + first use) share one.
  Future<void> _initHive() {
    _initFuture ??= _doInitHive();
    return _initFuture!;
  }

  Future<void> _doInitHive() async {
    if (_isInitialized) return;

    // initFlutter falla cuando Hive ya fue inicializado con otro path
    // (tests) o el provider de directorios no está disponible: no es fatal,
    // la apertura del box decide.
    try {
      await Hive.initFlutter();
    } catch (_) {
      // Continuar: Hive.init() externo (tests) ya deja un path utilizable.
    }

    // Registrar adaptadores si no están registrados
    ensureMovieAdaptersRegistered();
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(WatchedMovieAdapter());
    }

    try {
      _watchedMoviesBox = await Hive.openBox<WatchedMovie>('watched_movies');
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error(
            'Error abriendo box watched_movies: $e. Intentando reparar.');
      }
      // El box principal está ilegible (corrupto): eliminarlo y reabrirlo
      // en limpio en lugar de bifurcar a un box fallback que dividiría
      // silenciosamente los datos del usuario en dos stores. Los datos se
      // re-sincronizan desde Supabase.
      await Hive.deleteBoxFromDisk('watched_movies');
      _watchedMoviesBox = await Hive.openBox<WatchedMovie>('watched_movies');
      _isInitialized = true;
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
