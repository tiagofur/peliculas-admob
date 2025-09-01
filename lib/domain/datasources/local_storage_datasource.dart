import '../entities/movie.dart';
import '../entities/watchlist_movie.dart';

abstract class LocalStorageDatasource {
  Future<void> toggleFavorite(Movie movie);

  Future<bool> isMovieFavorite(int movieId);

  Future<List<Movie>> loadMovies({int limit = 10, offset = 0});

  // Watchlist methods
  Future<void> addToWatchlist(Movie movie, WatchlistPriority priority);
  
  Future<void> removeFromWatchlist(int movieId);
  
  Future<void> updateWatchlistPriority(int movieId, WatchlistPriority priority);
  
  Future<bool> isMovieInWatchlist(int movieId);
  
  Future<List<WatchlistMovie>> loadWatchlistMovies({
    int limit = 10, 
    int offset = 0,
    WatchlistPriority? priority,
  });
  
  Future<WatchlistMovie?> getWatchlistMovie(int movieId);
  
  Future<int> getWatchlistCount();
}
