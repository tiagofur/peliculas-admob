import '../entities/movie.dart';
import '../entities/recommendation.dart';

abstract class RecommendationsRepository {
  Future<List<Recommendation>> getPersonalizedRecommendations();
  Future<List<Recommendation>> getRecommendationsByCategory(String categoryId);
  Future<List<Recommendation>> getRecommendationsByMood(String mood);
  Future<List<Recommendation>> getSimilarMovies(int movieId);
  Future<UserPreferences> getUserPreferences();
  Future<void> updateUserPreferences();
  Future<List<RecommendationCategory>> getDiscoveryCategories();
  Future<List<Movie>> getMoviesForDiscovery(String categoryId);
}
