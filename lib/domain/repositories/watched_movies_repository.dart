import '../entities/entities.dart';

abstract class WatchedMoviesRepository {
  Future<void> markAsWatched(Movie movie);

  Future<void> removeFromWatched(int movieId);

  Future<bool> isMovieWatched(int movieId);

  Future<List<WatchedMovie>> loadWatchedMovies(
      {int limit = 10, int offset = 0});
}
