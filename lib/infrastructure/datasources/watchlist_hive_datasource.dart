import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/movie.dart';
import '../../domain/entities/watchlist_movie.dart';

class WatchlistHiveDatasource {
  static const String _boxName = 'watchlist_movies';
  static Box<WatchlistMovie>? _box;
  static const _uuid = Uuid();

  static Future<void> initialize() async {
    if (_box == null || !_box!.isOpen) {
      // Registrar adaptadores si no están registrados
      if (!Hive.isAdapterRegistered(100)) {
        Hive.registerAdapter(WatchlistPriorityAdapter());
      }
      if (!Hive.isAdapterRegistered(101)) {
        Hive.registerAdapter(WatchlistMovieAdapter());
      }
      
      _box = await Hive.openBox<WatchlistMovie>(_boxName);
    }
  }

  static Box<WatchlistMovie> get _watchlistBox {
    if (_box == null || !_box!.isOpen) {
      throw Exception('Watchlist Hive box is not initialized. Call initialize() first.');
    }
    return _box!;
  }

  Future<void> addToWatchlist(Movie movie, WatchlistPriority priority) async {
    await initialize();
    
    final now = DateTime.now();
    final watchlistMovie = WatchlistMovie(
      id: _uuid.v4(),
      movieId: movie.id,
      movieTitle: movie.title,
      moviePosterPath: movie.posterPath,
      movieBackdropPath: movie.backdropPath,
      movieOverview: movie.overview,
      movieReleaseDate: DateTime.tryParse(movie.releaseDate),
      movieVoteAverage: movie.voteAverage,
      priority: priority,
      addedAt: now,
      updatedAt: now,
    );
    
    // Usar movieId como key para facilitar búsqueda
    await _watchlistBox.put(movie.id, watchlistMovie);
  }

  Future<void> removeFromWatchlist(int movieId) async {
    await initialize();
    await _watchlistBox.delete(movieId);
  }

  Future<void> updateWatchlistPriority(int movieId, WatchlistPriority priority) async {
    await initialize();
    
    final existingMovie = _watchlistBox.get(movieId);
    if (existingMovie != null) {
      final updatedMovie = existingMovie.copyWith(
        priority: priority,
        updatedAt: DateTime.now(),
      );
      await _watchlistBox.put(movieId, updatedMovie);
    }
  }

  Future<bool> isMovieInWatchlist(int movieId) async {
    await initialize();
    return _watchlistBox.containsKey(movieId);
  }

  Future<List<WatchlistMovie>> loadWatchlistMovies({
    int limit = 10,
    int offset = 0,
    WatchlistPriority? priority,
  }) async {
    await initialize();
    
    var movies = _watchlistBox.values.toList();
    
    // Filtrar por prioridad si se especifica
    if (priority != null) {
      movies = movies.where((movie) => movie.priority == priority).toList();
    }
    
    // Ordenar por prioridad (alta primero) y luego por fecha agregada (más reciente primero)
    movies.sort((a, b) {
      // Primero ordenar por prioridad
      final priorityOrder = {'alta': 0, 'normal': 1, 'baja': 2};
      final aPriorityIndex = priorityOrder[a.priority.value] ?? 1;
      final bPriorityIndex = priorityOrder[b.priority.value] ?? 1;
      
      if (aPriorityIndex != bPriorityIndex) {
        return aPriorityIndex.compareTo(bPriorityIndex);
      }
      
      // Si tienen la misma prioridad, ordenar por fecha (más reciente primero)
      return b.addedAt.compareTo(a.addedAt);
    });
    
    // Aplicar paginación
    final startIndex = offset;
    final endIndex = (startIndex + limit).clamp(0, movies.length);
    
    if (startIndex >= movies.length) {
      return [];
    }
    
    return movies.sublist(startIndex, endIndex);
  }

  Future<WatchlistMovie?> getWatchlistMovie(int movieId) async {
    await initialize();
    return _watchlistBox.get(movieId);
  }

  Future<int> getWatchlistCount() async {
    await initialize();
    return _watchlistBox.length;
  }

  Future<List<WatchlistMovie>> getAllWatchlistMovies() async {
    await initialize();
    return _watchlistBox.values.toList();
  }

  Future<void> clear() async {
    await initialize();
    await _watchlistBox.clear();
  }
}