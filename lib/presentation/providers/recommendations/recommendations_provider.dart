import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/ml/ml_recommendation_service.dart';
import '../../../core/ml/recommendation_engine.dart';
import '../../../core/ml/user_behavior_analyzer.dart';
import '../../../domain/entities/movie.dart';
import '../../../domain/entities/recommendation.dart';
import '../../../domain/entities/syncable_watched_movie.dart';
import '../../../domain/repositories/recommendations_repository.dart';
import '../../../infrastructure/datasources/recommendations_moviedb_datasource.dart';
import '../../../infrastructure/repositories/recommendations_repository_impl.dart';
import '../storage/direct_favorites_provider.dart';
import '../storage/direct_watched_provider.dart';
import '../watched_movies_provider.dart';

// Provider del repositorio de recomendaciones
final recommendationsRepositoryProvider =
    Provider<RecommendationsRepository>((ref) {
  final datasource = RecommendationsMoviedbDatasource();
  return RecommendationsRepositoryImpl(datasource);
});

// Provider para inicialización del servicio ML
final mlRecommendationServiceProvider =
    Provider<MLRecommendationService>((ref) {
  final repository = ref.watch(recommendationsRepositoryProvider);
  final service = MLRecommendationService.instance;

  // Inicializar el servicio ML con el repositorio
  service.initialize(repository);

  return service;
});

// Provider para recomendaciones personalizadas con ML
final personalizedRecommendationsProvider =
    FutureProvider<List<Recommendation>>((ref) async {
  final repository = ref.watch(recommendationsRepositoryProvider);
  final mlService = ref.watch(mlRecommendationServiceProvider);
  final favoriteMovies = ref.watch(directFavoriteMoviesProvider);
  final watchedMoviesState = ref.watch(watchedMoviesProvider);

  // Si el usuario tiene favoritos o películas vistas, usar ML
  if (favoriteMovies.isNotEmpty || watchedMoviesState.movies.isNotEmpty) {
    try {
      // Generar recomendaciones ML mejoradas
      final favoriteMoviesList =
          favoriteMovies.values.map((syncable) => syncable.movie).toList();
      final mlRecommendations = await mlService.getMLEnhancedRecommendations(
        userId: 1, // En implementación real, obtener del contexto de usuario
        favoriteMovies: favoriteMoviesList,
        watchedMovies: watchedMoviesState.movies
            .map((movie) => movie.toWatchedMovie())
            .toList(),
        limit: 20,
      );

      if (mlRecommendations.isNotEmpty) {
        return mlRecommendations;
      }
    } catch (e) {
      // Fallback a recomendaciones tradicionales si ML falla
      // Error logged internally by ML service
    }

    // Fallback: usar recomendaciones tradicionales
    final datasource = RecommendationsMoviedbDatasource();
    final recommendations = <Recommendation>[];

    if (favoriteMovies.isNotEmpty) {
      final favoriteMoviesList =
          favoriteMovies.values.map((syncable) => syncable.movie).toList();
      final favoritesRecs = await datasource
          .getRecommendationsBasedOnFavorites(favoriteMoviesList);
      recommendations.addAll(favoritesRecs.take(10));
    }

    if (watchedMoviesState.movies.isNotEmpty) {
      final watchedRecs = await datasource.getRecommendationsBasedOnWatched(
          watchedMoviesState.movies
              .map((movie) => movie.toWatchedMovie())
              .toList());
      recommendations.addAll(watchedRecs.take(8));
    }

    final trending = await datasource.getTrendingRecommendations();
    recommendations.addAll(trending.take(5));

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
final recommendationsByCategoryProvider =
    FutureProvider.family<List<Recommendation>, String>(
        (ref, categoryId) async {
  final repository = ref.watch(recommendationsRepositoryProvider);
  return await repository.getRecommendationsByCategory(categoryId);
});

// Provider para recomendaciones por estado de ánimo
final recommendationsByMoodProvider =
    FutureProvider.family<List<Recommendation>, String>((ref, mood) async {
  final repository = ref.watch(recommendationsRepositoryProvider);
  return await repository.getRecommendationsByMood(mood);
});

// Provider para análisis de comportamiento del usuario con ML
final userBehaviorAnalysisProvider =
    FutureProvider<UserBehaviorAnalysis>((ref) async {
  final mlService = ref.watch(mlRecommendationServiceProvider);
  final favoriteMovies = ref.watch(directFavoriteMoviesProvider);
  final watchedMoviesState = ref.watch(watchedMoviesProvider);

  final favoriteMoviesList =
      favoriteMovies.values.map((syncable) => syncable.movie).toList();
  return await mlService.analyzeUserBehavior(
    favoriteMovies: favoriteMoviesList,
    watchedMovies: watchedMoviesState.movies
        .map((movie) => movie.toWatchedMovie())
        .toList(),
  );
});

// Provider para recomendaciones similares con ML
final similarMoviesProvider =
    FutureProvider.family<List<Recommendation>, int>((ref, movieId) async {
  final mlService = ref.watch(mlRecommendationServiceProvider);

  // Get movie data first
  final favoriteMovies = ref.watch(directFavoriteMoviesProvider);
  final watchedMoviesState = ref.watch(watchedMoviesProvider);

  // Find a target movie from favorites or watched movies
  Movie? targetMovie;
  if (favoriteMovies.containsKey(movieId)) {
    targetMovie = favoriteMovies[movieId]?.movie;
  } else {
    // Try to find in watched movies and convert to Movie
    SyncableWatchedMovie? syncableWatchedMovie;
    try {
      syncableWatchedMovie = watchedMoviesState.movies.firstWhere(
        (movie) => movie.movieId == movieId,
      );
    } catch (e) {
      syncableWatchedMovie = null;
    }

    if (syncableWatchedMovie != null) {
      targetMovie = syncableWatchedMovie.toMovie();
    } else {
      targetMovie = Movie(
        id: movieId,
        title: 'Unknown Movie',
        overview: '',
        posterPath: '',
        backdropPath: '',
        releaseDate: DateTime.now(),
        genreIds: [],
        voteAverage: 0.0,
        voteCount: 0,
        popularity: 0.0,
        adult: false,
        originalLanguage: '',
        originalTitle: '',
        video: false,
      );
    }
  }

  final favoriteMoviesList =
      favoriteMovies.values.map((syncable) => syncable.movie).toList();
  return await mlService.findSimilarMovies(
    targetMovie: targetMovie!,
    favoriteMovies: favoriteMoviesList,
    watchedMovies: watchedMoviesState.movies
        .map((movie) => movie.toWatchedMovie())
        .toList(),
    limit: 10,
  );
});

// Provider para explicaciones de recomendaciones
final recommendationExplanationProvider =
    FutureProvider.family<String, Recommendation>((ref, recommendation) async {
  final favoriteMovies = ref.watch(directFavoriteMoviesProvider);
  final watchedMoviesState = ref.watch(watchedMoviesProvider);
  final mlService = ref.watch(mlRecommendationServiceProvider);

  final favoriteMoviesList =
      favoriteMovies.values.map((syncable) => syncable.movie).toList();
  return mlService.explainRecommendation(
    recommendation,
    favoriteMovies: favoriteMoviesList,
    watchedMovies: watchedMoviesState.movies
        .map((movie) => movie.toWatchedMovie())
        .toList(),
  );
});

// Provider para insights personalizados
final personalizedInsightsProvider =
    FutureProvider<List<UserInsight>>((ref) async {
  final mlService = ref.watch(mlRecommendationServiceProvider);
  final favoriteMovies = ref.watch(directFavoriteMoviesProvider);
  final watchedMoviesState = ref.watch(watchedMoviesProvider);

  final favoriteMoviesList =
      favoriteMovies.values.map((syncable) => syncable.movie).toList();
  return await mlService.generatePersonalizedInsights(
    favoriteMovies: favoriteMoviesList,
    watchedMovies: watchedMoviesState.movies
        .map((movie) => movie.toWatchedMovie())
        .toList(),
  );
});

// Provider para predicción de próxima película
final nextMoviePredictionProvider =
    FutureProvider<List<Recommendation>>((ref) async {
  final mlService = ref.watch(mlRecommendationServiceProvider);
  final favoriteMovies = ref.watch(directFavoriteMoviesProvider);
  final watchedMoviesState = ref.watch(watchedMoviesProvider);

  final favoriteMoviesList =
      favoriteMovies.values.map((syncable) => syncable.movie).toList();
  final prediction = await mlService.predictNextMovie(
    favoriteMovies: favoriteMoviesList,
    watchedMovies: watchedMoviesState.movies
        .map((movie) => movie.toWatchedMovie())
        .toList(),
  );

  // Convert MoviePrediction to List<Recommendation>
  // MoviePrediction contains Map<String, dynamic> predictions, not direct properties
  final hybridPrediction = prediction.hybridPrediction;

  return [
    Recommendation(
      movieId: (hybridPrediction['movieId'] as int?) ?? 0,
      title: (hybridPrediction['title'] as String?) ?? 'Predicted Movie',
      posterPath: (hybridPrediction['posterPath'] as String?) ?? '',
      score: (hybridPrediction['confidence'] as double?) ?? 0.0,
      reason: (hybridPrediction['reason'] as String?) ??
          'Predicted based on your preferences',
      type: RecommendationType.trending,
      tags: ['prediction', 'ml'],
    )
  ];
});

// Provider para puntuación de engagement
final engagementScoreProvider = FutureProvider<double>((ref) async {
  final mlService = ref.watch(mlRecommendationServiceProvider);
  final favoriteMovies = ref.watch(directFavoriteMoviesProvider);
  final watchedMoviesState = ref.watch(watchedMoviesProvider);

  final favoriteMoviesList =
      favoriteMovies.values.map((syncable) => syncable.movie).toList();
  final engagementScore = await mlService.calculateEngagementScore(
    favoriteMovies: favoriteMoviesList,
    watchedMovies: watchedMoviesState.movies
        .map((movie) => movie.toWatchedMovie())
        .toList(),
  );

  return engagementScore.totalScore;
});

// Provider para categorías de descubrimiento
final discoveryCategoriesProvider =
    FutureProvider<List<RecommendationCategory>>((ref) async {
  final repository = ref.watch(recommendationsRepositoryProvider);
  return await repository.getDiscoveryCategories();
});

// Provider para preferencias del usuario
final userPreferencesProvider = FutureProvider<UserPreferences>((ref) async {
  final repository = ref.watch(recommendationsRepositoryProvider);
  final favoriteMovies = ref.watch(directFavoriteMoviesProvider);
  final watchedMoviesState = ref.watch(watchedMoviesProvider);

  if (favoriteMovies.isNotEmpty || watchedMoviesState.movies.isNotEmpty) {
    final datasource = RecommendationsMoviedbDatasource();
    final favoriteMoviesList =
        favoriteMovies.values.map((syncable) => syncable.movie).toList();
    return await datasource.analyzeUserPreferences(
      favoriteMoviesList,
      watchedMoviesState.movies.map((movie) => movie.toWatchedMovie()).toList(),
    );
  }

  return await repository.getUserPreferences();
});

// Provider para estadísticas básicas del usuario (mantenido para compatibilidad)
final recommendationsUserStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final favoriteMovies = ref.watch(directFavoriteMoviesProvider);
  final watchedMoviesState = ref.watch(watchedMoviesProvider);
  final directWatchedMovies = ref.watch(directWatchedMoviesProvider);

  final resolvedWatchedCount = directWatchedMovies.isNotEmpty
      ? directWatchedMovies.length
      : watchedMoviesState.movies.length;

  // Debug logs para diagnosticar el problema
  AppLogger.provider('RecommendationsUserStatsProvider',
      '📊 RecommendationsUserStatsProvider:');
  AppLogger.provider('RecommendationsUserStatsProvider',
      '   📋 Favoritas: ${favoriteMovies.length}');
  AppLogger.provider('RecommendationsUserStatsProvider',
      '   👀 Vistas (directas): ${directWatchedMovies.length}');
  AppLogger.provider('RecommendationsUserStatsProvider',
      '   👀 Vistas (híbridas): ${watchedMoviesState.movies.length}');
  AppLogger.provider('RecommendationsUserStatsProvider',
      '   📂 Estado de carga: ${watchedMoviesState.isLoading}');
  AppLogger.provider('RecommendationsUserStatsProvider',
      '   📄 Página actual: ${watchedMoviesState.currentPage}');
  AppLogger.provider('RecommendationsUserStatsProvider',
      '   🔚 Última página: ${watchedMoviesState.isLastPage}');

  final favoriteMoviesList =
      favoriteMovies.values.map((syncable) => syncable.movie).toList();
  final stats = {
    'totalFavorites': favoriteMovies.length,
    'totalWatched': resolvedWatchedCount,
    'favoriteGenres': _getMostCommonGenres(favoriteMoviesList),
    'averageRating': _getAverageRating(favoriteMoviesList),
  };

  AppLogger.provider(
      'RecommendationsUserStatsProvider', '📊 Estadísticas finales: $stats');
  return stats;
});

// Provider para estadísticas básicas del usuario (para recomendaciones)
final basicUserStatsProvider = Provider<BasicUserStats>((ref) {
  final favoriteMovies = ref.watch(directFavoriteMoviesProvider);
  final watchedMoviesState = ref.watch(watchedMoviesProvider);
  final directWatchedMovies = ref.watch(directWatchedMoviesProvider);

  final resolvedWatchedCount = directWatchedMovies.isNotEmpty
      ? directWatchedMovies.length
      : watchedMoviesState.movies.length;

  final favoriteMoviesList =
      favoriteMovies.values.map((syncable) => syncable.movie).toList();

  return BasicUserStats(
    totalFavorites: favoriteMovies.length,
    totalWatched: resolvedWatchedCount,
    totalMovies: favoriteMovies.length + resolvedWatchedCount,
    averageRating: _calculateAverageRating(favoriteMoviesList),
    topGenres: _getTopGenres(favoriteMoviesList, 3)
        .map((id) => _getGenreName(id))
        .toList(),
    watchingStreak: watchedMoviesState.movies.isNotEmpty
        ? _calculateWatchingStreak(watchedMoviesState.movies)
        : 0,
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

Map<String, int> _getMostCommonGenres(List<Movie> movies) {
  final genreCount = <String, int>{};

  for (final movie in movies) {
    for (final genreIdStr in movie.genreIds) {
      final genreId = int.tryParse(genreIdStr) ?? 0;
      if (genreId > 0) {
        final genreName = _getGenreName(genreId);
        genreCount[genreName] = (genreCount[genreName] ?? 0) + 1;
      }
    }
  }

  return genreCount;
}

double _getAverageRating(List<Movie> movies) {
  if (movies.isEmpty) return 0.0;

  final totalRating =
      movies.fold<double>(0.0, (sum, movie) => sum + movie.voteAverage);
  return totalRating / movies.length;
}

double _calculateAverageRating(List<Movie> movies) {
  if (movies.isEmpty) return 0.0;

  double total = 0.0;
  for (final movie in movies) {
    total += movie.voteAverage;
  }

  return total / movies.length;
}

List<int> _getTopGenres(List<Movie> movies, int limit) {
  final genreCount = <int, int>{};

  for (final movie in movies) {
    for (final genreIdStr in movie.genreIds) {
      final genreId = int.tryParse(genreIdStr) ?? 0;
      if (genreId > 0) {
        genreCount[genreId] = (genreCount[genreId] ?? 0) + 1;
      }
    }
  }

  final sortedGenres = genreCount.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sortedGenres.take(limit).map((e) => e.key).toList();
}

int _calculateWatchingStreak(List<SyncableWatchedMovie> watchedMovies) {
  if (watchedMovies.isEmpty) return 0;

  // Calcular racha basada en fechas de películas vistas
  // Por simplicidad, retornamos el número de películas vistas en los últimos 7 días
  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));

  int streak = 0;
  for (final movie in watchedMovies) {
    if (movie.watchedDate.isAfter(weekAgo)) {
      streak++;
    }
  }

  return streak;
}

String _getGenreName(int genreId) {
  // Mapeo básico de géneros - en implementación real usar API
  const genreMap = {
    28: 'Acción',
    12: 'Aventura',
    16: 'Animación',
    35: 'Comedia',
    80: 'Crimen',
    99: 'Documental',
    18: 'Drama',
    10751: 'Familiar',
    14: 'Fantasía',
    36: 'Historia',
    27: 'Terror',
    10402: 'Música',
    9648: 'Misterio',
    10749: 'Romance',
    878: 'Ciencia Ficción',
    10770: 'Película de TV',
    53: 'Thriller',
    10752: 'Guerra',
    37: 'Western',
  };

  return genreMap[genreId] ?? 'Desconocido';
}
