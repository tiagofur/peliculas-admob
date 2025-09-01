import '../../domain/datasources/watched_movies_datasource.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/watched_movies_repository.dart';

class WatchedMoviesRepositoryImpl extends WatchedMoviesRepository {
  WatchedMoviesRepositoryImpl(this.datasource);

  final WatchedMoviesDatasource datasource;

  @override
  Future<void> markAsWatched(Movie movie) {
    return datasource.markAsWatched(movie);
  }

  @override
  Future<void> removeFromWatched(int movieId) {
    return datasource.removeFromWatched(movieId);
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
