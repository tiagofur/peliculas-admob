import '../../domain/datasources/recommendations_datasource.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/recommendation.dart';

import '../../domain/repositories/recommendations_repository.dart';

class RecommendationsRepositoryImpl extends RecommendationsRepository {
  RecommendationsRepositoryImpl(this.datasource);

  final RecommendationsDatasource datasource;

  @override
  Future<List<Recommendation>> getPersonalizedRecommendations() async {
    // Esta función combinará diferentes tipos de recomendaciones
    final allRecommendations = <Recommendation>[];
    
    try {
      // Obtener recomendaciones trending como base
      final trending = await datasource.getTrendingRecommendations();
      allRecommendations.addAll(trending.take(5));
      
      // Agregar recomendaciones por estado de ánimo aleatorio
      final moods = ['happy', 'excited', 'romantic'];
      final randomMood = moods[DateTime.now().millisecond % moods.length];
      final moodRecommendations = await datasource.getRecommendationsByMood(randomMood);
      allRecommendations.addAll(moodRecommendations.take(3));
      
    } catch (e) {
      // En caso de error, devolver lista vacía
      return [];
    }
    
    // Ordenar por score y eliminar duplicados
    final uniqueRecommendations = <int, Recommendation>{};
    for (final rec in allRecommendations) {
      if (!uniqueRecommendations.containsKey(rec.movieId)) {
        uniqueRecommendations[rec.movieId] = rec;
      }
    }
    
    final result = uniqueRecommendations.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    
    return result.take(20).toList();
  }

  @override
  Future<List<Recommendation>> getRecommendationsByCategory(String categoryId) async {
    try {
      switch (categoryId) {
        case 'romantic_night':
          return await datasource.getRecommendationsByMood('romantic');
        case 'weekend_fun':
          return await datasource.getRecommendationsByGenre(['35', '28']); // Comedy, Action
        case 'feel_good':
          return await datasource.getRecommendationsByMood('happy');
        case 'mind_bending':
          return await datasource.getRecommendationsByGenre(['878', '53']); // Sci-Fi, Thriller
        case 'hidden_gems':
        case 'classic_forgotten':
          // Para estas categorías, usaremos discover con filtros específicos
          return await _getSpecialCategoryMovies(categoryId);
        default:
          return await datasource.getTrendingRecommendations();
      }
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Recommendation>> getRecommendationsByMood(String mood) async {
    try {
      return await datasource.getRecommendationsByMood(mood);
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Recommendation>> getSimilarMovies(int movieId) async {
    try {
      return await datasource.getSimilarMovies(movieId);
    } catch (e) {
      return [];
    }
  }

  @override
  Future<UserPreferences> getUserPreferences() async {
    // Por ahora retornamos preferencias por defecto
    // En una implementación completa, esto se obtendría del almacenamiento local
    return UserPreferences(
      favoriteGenres: ['28', '35', '18'], // Action, Comedy, Drama
      favoriteActors: [],
      favoriteDirectors: [],
      averageRatingPreference: 7.0,
      preferredLanguages: ['es', 'en'],
      genreCount: {},
      genreRating: {},
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Future<void> updateUserPreferences() async {
    // Implementación futura para actualizar preferencias basadas en actividad del usuario
  }

  @override
  Future<List<RecommendationCategory>> getDiscoveryCategories() async {
    try {
      return await datasource.getDiscoveryCategories();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Movie>> getMoviesForDiscovery(String categoryId) async {
    // Esta función convertiría las recomendaciones en objetos Movie
    // Por simplicidad, retornamos lista vacía por ahora
    return [];
  }

  Future<List<Recommendation>> _getSpecialCategoryMovies(String categoryId) async {
    // Implementación específica para categorías especiales
    switch (categoryId) {
      case 'hidden_gems':
        return await datasource.getRecommendationsByGenre(['18', '878']); // Drama, Sci-Fi
      case 'classic_forgotten':
        return await datasource.getRecommendationsByGenre(['18', '36']); // Drama, History
      default:
        return [];
    }
  }
}