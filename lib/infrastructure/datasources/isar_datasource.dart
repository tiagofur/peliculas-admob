import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/datasources/local_storage_datasource.dart';
import '../../domain/entities/movie.dart';

class HiveDatasource extends LocalStorageDatasource {
  HiveDatasource() {
    _initHive();
  }

  Box<Movie>? _moviesBox;
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

      // Registrar adaptador si no está registrado
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(MovieAdapter());
      }

      _moviesBox = await Hive.openBox<Movie>('movies');
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error inicializando Hive: $e');
      }
      // En caso de error, intentar con un nombre de box diferente
      try {
        _moviesBox = await Hive.openBox<Movie>('movies_fallback');
        _isInitialized = true;
      } catch (e2) {
        if (kDebugMode) {
          LoggerFactory.error('Error inicializando Hive con fallback: $e2');
        }
        rethrow;
      }
    }
  }

  @override
  Future<bool> isMovieFavorite(int movieId) async {
    try {
      if (!_isInitialized) await _initHive();
      if (_moviesBox == null) return false;

      final movies = _moviesBox!.values.where((movie) => movie.id == movieId);
      return movies.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error checking if movie is favorite: $e');
      }
      return false;
    }
  }

  @override
  Future<void> toggleFavorite(Movie movie) async {
    try {
      if (!_isInitialized) await _initHive();
      if (_moviesBox == null) throw Exception('Movies box not available');

      final existingMovieKey = _moviesBox!.keys.cast<int>().firstWhere(
            (key) => _moviesBox!.get(key)?.id == movie.id,
            orElse: () => -1,
          );

      if (existingMovieKey != -1) {
        // Borrar
        await _moviesBox!.delete(existingMovieKey);
        return;
      }

      // Insertar
      await _moviesBox!.add(movie);
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error toggling favorite: $e');
      }
      rethrow;
    }
  }

  @override
  Future<List<Movie>> loadMovies({int limit = 10, offset = 0}) async {
    try {
      if (!_isInitialized) {
        LoggerFactory.info(
            '🔄 HiveDatasource no inicializado, inicializando...');
        await _initHive();
      }

      if (_moviesBox == null) {
        LoggerFactory.warning('❌ MoviesBox es null, retornando lista vacía');
        return [];
      }

      final allMovies = _moviesBox!.values.toList();
      LoggerFactory.info(
          '📊 HiveDatasource: Total películas en box: ${allMovies.length}');
      LoggerFactory.info(
          '📊 HiveDatasource: Solicitado limit=$limit, offset=$offset');

      final endIndex = (offset + limit).clamp(0, allMovies.length);

      if (offset >= allMovies.length) {
        LoggerFactory.info(
            '📊 HiveDatasource: Offset mayor que total, retornando vacío');
        return [];
      }

      final result = allMovies.sublist(offset, endIndex);
      LoggerFactory.info(
          '📊 HiveDatasource: Retornando ${result.length} películas');
      return result;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('❌ Error loading movies: $e');
      }
      return [];
    }
  }

  // Método para limpiar todos los datos
  Future<void> clearAll() async {
    try {
      if (!_isInitialized) await _initHive();
      if (_moviesBox != null) {
        await _moviesBox!.clear();
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error clearing all data: $e');
      }
    }
  }

  // Método para cerrar la base de datos
  Future<void> close() async {
    try {
      if (_moviesBox?.isOpen == true) {
        await _moviesBox!.close();
      }
      _isInitialized = false;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error closing database: $e');
      }
    }
  }
}
