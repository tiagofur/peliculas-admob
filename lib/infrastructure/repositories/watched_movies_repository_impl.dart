import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../domain/datasources/watched_movies_datasource.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/watched_movies_repository.dart';

class WatchedMoviesRepositoryImpl extends WatchedMoviesRepository {
  WatchedMoviesRepositoryImpl(this.datasource, this.ref);

  final WatchedMoviesDatasource datasource;
  final Ref ref;

  @override
  Future<void> markAsWatched(Movie movie) async {
    await datasource.markAsWatched(movie);

    // La sincronización se manejará automáticamente
  }

  @override
  Future<void> removeFromWatched(int movieId) async {
    await datasource.removeFromWatched(movieId);

    // La sincronización se manejará automáticamente
  }

  @override
  Future<bool> isMovieWatched(int movieId) {
    return datasource.isMovieWatched(movieId);
  }

  @override
  Future<List<WatchedMovie>> loadWatchedMovies(
      {int limit = 10, int offset = 0}) {
    return datasource.loadWatchedMovies(limit: limit, offset: offset);
  }
}
