import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/datasources/watched_movies_datasource.dart';
import '../../domain/entities/entities.dart';

class WatchedMoviesHiveDatasource extends WatchedMoviesDatasource {
  WatchedMoviesHiveDatasource() {
    _initHive();
  }
  
  Box<WatchedMovie>? _watchedMoviesBox;

  Future<void> _initHive() async {
    final dir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(dir.path);
    
    // Registrar adaptadores si no están registrados
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MovieAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(WatchedMovieAdapter());
    }
    
    _watchedMoviesBox = await Hive.openBox<WatchedMovie>('watched_movies');
  }

  @override
  Future<void> markAsWatched(Movie movie) async {
    if (_watchedMoviesBox == null) await _initHive();
    
    // Verificar si ya está marcada como vista
    final isAlreadyWatched = await isMovieWatched(movie.id);
    if (isAlreadyWatched) return;
    
    // Crear WatchedMovie con fecha actual
    final watchedMovie = WatchedMovie(
      movie: movie,
      watchedDate: DateTime.now(),
    );
    
    await _watchedMoviesBox!.add(watchedMovie);
  }

  @override
  Future<void> removeFromWatched(int movieId) async {
    if (_watchedMoviesBox == null) await _initHive();
    
    final existingMovieKey = _watchedMoviesBox!.keys.cast<int>().firstWhere(
      (key) => _watchedMoviesBox!.get(key)?.movie.id == movieId,
      orElse: () => -1,
    );

    if (existingMovieKey != -1) {
      await _watchedMoviesBox!.delete(existingMovieKey);
    }
  }

  @override
  Future<bool> isMovieWatched(int movieId) async {
    if (_watchedMoviesBox == null) await _initHive();
    
    final watchedMovies = _watchedMoviesBox!.values.where(
      (watchedMovie) => watchedMovie.movie.id == movieId
    );
    return watchedMovies.isNotEmpty;
  }

  @override
  Future<List<WatchedMovie>> loadWatchedMovies({int limit = 10, int offset = 0}) async {
    if (_watchedMoviesBox == null) await _initHive();
    
    final allWatchedMovies = _watchedMoviesBox!.values.toList();
    
    // Ordenar por fecha de visualización (más recientes primero)
    allWatchedMovies.sort((a, b) => b.watchedDate.compareTo(a.watchedDate));
    
    final endIndex = (offset + limit).clamp(0, allWatchedMovies.length);
    
    if (offset >= allWatchedMovies.length) return [];
    
    return allWatchedMovies.sublist(offset, endIndex);
  }
}