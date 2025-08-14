import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/datasources/local_storage_datasource.dart';
import '../../domain/entities/movie.dart';

class HiveDatasource extends LocalStorageDatasource {
  HiveDatasource() {
    _initHive();
  }
  
  Box<Movie>? _moviesBox;

  Future<void> _initHive() async {
    final dir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(dir.path);
    
    // Registrar adaptador si no está registrado
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MovieAdapter());
    }
    
    _moviesBox = await Hive.openBox<Movie>('movies');
  }

  @override
  Future<bool> isMovieFavorite(int movieId) async {
    if (_moviesBox == null) await _initHive();
    
    final movies = _moviesBox!.values.where((movie) => movie.id == movieId);
    return movies.isNotEmpty;
  }

  @override
  Future<void> toggleFavorite(Movie movie) async {
    if (_moviesBox == null) await _initHive();
    
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
  }

  @override
  Future<List<Movie>> loadMovies({int limit = 10, offset = 0}) async {
    if (_moviesBox == null) await _initHive();
    
    final allMovies = _moviesBox!.values.toList();
    final endIndex = (offset + limit).clamp(0, allMovies.length);
    
    if (offset >= allMovies.length) return [];
    
    return allMovies.sublist(offset, endIndex);
  }
}
