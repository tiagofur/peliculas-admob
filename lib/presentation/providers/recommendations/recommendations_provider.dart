import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/recommendation.dart';
import '../../../domain/repositories/recommendations_repository.dart';
import '../../../infrastructure/datasources/recommendations_moviedb_datasource.dart';
import '../../../infrastructure/repositories/recommendations_repository_impl.dart';
import '../storage/favorite_movies_provider.dart';
import '../watched_movies_provider.dart';

// Provider del repositorio de recomendaciones
final recommendationsRepositoryProvider = Provider<RecommendationsRepository>((ref) {
  final datasource = RecommendationsMoviedbDatasource();
  return RecommendationsRepositoryImpl(datasource);
});

// Provider para recomendaciones personalizadas
final personalizedRecommendationsProvider = FutureProvider<List<Recommendation>>((ref) async {
  final repository = ref.watch(recommendationsRepositoryProvider);
  final favoriteMovies = ref.watch(favoriteMoviesProvider);
  final watchedMoviesState = ref.watch(watchedMoviesProvider);
  
  // Si el usuario tiene favoritos o películas vistas, usar recomendaciones inteligentes
  if (favoriteMovies.isNotEmpty || watchedMoviesState.movies.isNotEmpty) {
    final datasource = RecommendationsMoviedbDatasource();
    
    final recommendations = <Recommendation>[];
    
    // Recomendaciones basadas en favoritos
    if (favoriteMovies.isNotEmpty) {
      final favoritesRecs = await datasource.getRecommendationsBasedOnFavorites(
        favoriteMovies.values.toList()
      );
      recommendations.addAll(favoritesRecs.take(10));
    }
    
    // Recomendaciones basadas en películas vistas
    if (watchedMoviesState.movies.isNotEmpty) {
      final watchedRecs = await datasource.getRecommendationsBasedOnWatched(
        watchedMoviesState.movies
      );
      recommendations.addAll(watchedRecs.take(8));
    }
    
    // Agregar algunas recomendaciones trending
    final trending = await datasource.getTrendingRecommendations();
    recommendations.addAll(trending.take(5));
    
    // Eliminar duplicados y ordenar por score
    final uniqueRecommendations = <int, Recommendation>{};
    for (final rec in recommendations) {
      if (!uniqueRecommendations.containsKey(rec.movieId)) {
        uniqueRecommendations[rec.movieId] = rec;
      }
    }
    
    final result = uniqueRecommendations.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    
    return result.take(20).toList();
  }
  
  // Si no hay datos del usuario, usar recomendaciones generales
  return await repository.getPersonalizedRecommendations();
});

// Provider para recomendaciones por categoría
final recommendationsByCategoryProvider = FutureProvider.family<List<Recommendation>, String>((ref, categoryId) async {
  final repository = ref.watch(recommendationsRepositoryProvider);
  return await repository.getRecommendationsByCategory(categoryId);
});

// Provider para recomendaciones por estado de ánimo
final recommendationsByMoodProvider = FutureProvider.family<List<Recommendation>, String>((ref, mood) async {
  final repository = ref.watch(recommendationsRepositoryProvider);
  return await repository.getRecommendationsByMood(mood);
});

// Provider para películas similares
final similarMoviesProvider = FutureProvider.family<List<Recommendation>, int>((ref, movieId) async {
  final repository = ref.watch(recommendationsRepositoryProvider);
  return await repository.getSimilarMovies(movieId);
});

// Provider para categorías de descubrimiento
final discoveryCategoriesProvider = FutureProvider<List<RecommendationCategory>>((ref) async {
  final repository = ref.watch(recommendationsRepositoryProvider);
  return await repository.getDiscoveryCategories();
});

// Provider para preferencias del usuario
final userPreferencesProvider = FutureProvider<UserPreferences>((ref) async {
  final repository = ref.watch(recommendationsRepositoryProvider);
  final favoriteMovies = ref.watch(favoriteMoviesProvider);
  final watchedMoviesState = ref.watch(watchedMoviesProvider);
  
  if (favoriteMovies.isNotEmpty || watchedMoviesState.movies.isNotEmpty) {
    final datasource = RecommendationsMoviedbDatasource();
    return await datasource.analyzeUserPreferences(
      favoriteMovies.values.toList(),
      watchedMoviesState.movies,
    );
  }
  
  return await repository.getUserPreferences();
});

// Provider para estadísticas básicas del usuario (para recomendaciones)
final basicUserStatsProvider = Provider<BasicUserStats>((ref) {
  final favoriteMovies = ref.watch(favoriteMoviesProvider);
  final watchedMoviesState = ref.watch(watchedMoviesProvider);
  
  return BasicUserStats(
    totalFavorites: favoriteMovies.length,
    totalWatched: watchedMoviesState.movies.length,
    totalMovies: favoriteMovies.length + watchedMoviesState.movies.length,
    averageRating: _calculateAverageRating(favoriteMovies.values.toList()),
    topGenres: _getTopGenres(favoriteMovies.values.toList()),
    watchingStreak: _calculateWatchingStreak(watchedMoviesState.movies),
  );
});

class BasicUserStats {
  BasicUserStats({
    required this.totalFavorites,
    required this.totalWatched,
    required this.totalMovies,
    required this.averageRating,
    required this.topGenres,
    required this.watchingStreak,
  });

  final int totalFavorites;
  final int totalWatched;
  final int totalMovies;
  final double averageRating;
  final List<String> topGenres;
  final int watchingStreak;
}

double _calculateAverageRating(List<dynamic> movies) {
  if (movies.isEmpty) return 0.0;
  
  double total = 0.0;
  for (final movie in movies) {
    if (movie.voteAverage != null) {
      total += movie.voteAverage;
    }
  }
  
  return total / movies.length;
}

List<String> _getTopGenres(List<dynamic> movies) {
  final genreCount = <String, int>{};
  
  for (final movie in movies) {
    if (movie.genreIds != null) {
      for (final genre in movie.genreIds) {
        genreCount[genre] = (genreCount[genre] ?? 0) + 1;
      }
    }
  }
  
  final sortedGenres = genreCount.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  
  return sortedGenres.take(3).map((e) => _getGenreName(e.key)).toList();
}

int _calculateWatchingStreak(List<dynamic> watchedMovies) {
  if (watchedMovies.isEmpty) return 0;
  
  // Calcular racha basada en fechas de películas vistas
  // Por simplicidad, retornamos el número de películas vistas en los últimos 7 días
  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));
  
  int streak = 0;
  for (final movie in watchedMovies) {
    if (movie.watchedAt != null && movie.watchedAt.isAfter(weekAgo)) {
      streak++;
    }
  }
  
  return streak;
}

String _getGenreName(String genreId) {
  final genres = {
    '28': 'Acción',
    '12': 'Aventura',
    '16': 'Animación',
    '35': 'Comedia',
    '80': 'Crimen',
    '99': 'Documental',
    '18': 'Drama',
    '10751': 'Familiar',
    '14': 'Fantasía',
    '36': 'Historia',
    '27': 'Terror',
    '10402': 'Música',
    '9648': 'Misterio',
    '10749': 'Romance',
    '878': 'Ciencia ficción',
    '10770': 'Película de TV',
    '53': 'Suspenso',
    '10752': 'Guerra',
    '37': 'Western',
  };
  return genres[genreId] ?? 'Desconocido';
}