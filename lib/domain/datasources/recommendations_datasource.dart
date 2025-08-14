import '../entities/movie.dart';
import '../entities/recommendation.dart';
import '../entities/watched_movie.dart';

abstract class RecommendationsDatasource {
  Future<List<Recommendation>> getRecommendationsBasedOnFavorites(List<Movie> favoriteMovies);
  Future<List<Recommendation>> getRecommendationsBasedOnWatched(List<WatchedMovie> watchedMovies);
  Future<List<Recommendation>> getRecommendationsByGenre(List<String> genres);
  Future<List<Recommendation>> getRecommendationsByMood(String mood);
  Future<List<Recommendation>> getTrendingRecommendations();
  Future<List<Recommendation>> getSimilarMovies(int movieId);
  Future<UserPreferences> analyzeUserPreferences(List<Movie> favoriteMovies, List<WatchedMovie> watchedMovies);
  Future<List<RecommendationCategory>> getDiscoveryCategories();
}