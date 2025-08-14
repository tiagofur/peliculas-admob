import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entities.dart';
import 'custom_lists_provider.dart';
import 'storage/favorite_movies_provider.dart';
import 'watched_movies_provider.dart';

// Provider para estadísticas del usuario
final userStatsProvider = FutureProvider<UserStats>((ref) async {
  final favoriteMoviesMap = ref.watch(favoriteMoviesProvider);
  final favoriteMovies = favoriteMoviesMap.values.toList();
  final watchedMoviesState = ref.watch(watchedMoviesProvider);
  final customLists = ref.watch(customListsProvider);
  final defaultLists = ref.watch(defaultListsProvider);

  return UserStats.fromMovies(
    favoriteMovies: favoriteMovies,
    watchedMovies: watchedMoviesState.movies,
    customLists: customLists,
    defaultLists: defaultLists,
  );
});

// Provider para análisis de géneros
final genreAnalysisProvider = FutureProvider<GenreAnalysis>((ref) async {
  final favoriteMoviesMap = ref.watch(favoriteMoviesProvider);
  final favoriteMovies = favoriteMoviesMap.values.toList();
  final watchedMoviesState = ref.watch(watchedMoviesProvider);

  return GenreAnalysis.fromMovies(
    favoriteMovies: favoriteMovies,
    watchedMovies: watchedMoviesState.movies,
  );
});

// Provider para análisis temporal
final temporalAnalysisProvider = FutureProvider<TemporalAnalysis>((ref) async {
  final favoriteMoviesMap = ref.watch(favoriteMoviesProvider);
  final favoriteMovies = favoriteMoviesMap.values.toList();
  final watchedMoviesState = ref.watch(watchedMoviesProvider);

  return TemporalAnalysis.fromMovies(
    favoriteMovies: favoriteMovies,
    watchedMovies: watchedMoviesState.movies,
  );
});

// Provider para análisis de calificaciones
final ratingAnalysisProvider = FutureProvider<RatingAnalysis>((ref) async {
  final favoriteMoviesMap = ref.watch(favoriteMoviesProvider);
  final favoriteMovies = favoriteMoviesMap.values.toList();
  final watchedMoviesState = ref.watch(watchedMoviesProvider);

  return RatingAnalysis.fromMovies(
    favoriteMovies: favoriteMovies,
    watchedMovies: watchedMoviesState.movies,
  );
});

// Provider para patrones de actividad
final activityPatternsProvider = FutureProvider<ActivityPatterns>((ref) async {
  final watchedMoviesState = ref.watch(watchedMoviesProvider);

  return ActivityPatterns.fromWatchedMovies(watchedMoviesState.movies);
});

// Provider para recomendaciones basadas en estadísticas
final statsBasedRecommendationsProvider =
    FutureProvider<List<String>>((ref) async {
  final genreAnalysis = await ref.watch(genreAnalysisProvider.future);
  final temporalAnalysis = await ref.watch(temporalAnalysisProvider.future);
  final ratingAnalysis = await ref.watch(ratingAnalysisProvider.future);

  return _generateRecommendations(
    genreAnalysis: genreAnalysis,
    temporalAnalysis: temporalAnalysis,
    ratingAnalysis: ratingAnalysis,
  );
});

// UserStats class moved to domain/entities/user_stats.dart

// UserStats factory and methods moved to domain/entities/user_stats.dart

// GenreAnalysis class moved to domain/entities/genre_analysis.dart

// TemporalAnalysis class moved to domain/entities/temporal_analysis.dart

// RatingAnalysis class moved to domain/entities/rating_analysis.dart

// ActivityPatterns class moved to domain/entities/activity_patterns.dart

List<String> _generateRecommendations({
  required GenreAnalysis genreAnalysis,
  required TemporalAnalysis temporalAnalysis,
  required RatingAnalysis ratingAnalysis,
}) {
  final recommendations = <String>[];

  if (genreAnalysis.topFavoriteGenres.isNotEmpty) {
    recommendations.add(
        'Explora más películas de ${genreAnalysis.topFavoriteGenres.first}');
  }

  if (genreAnalysis.underexploredGenres.isNotEmpty) {
    recommendations
        .add('Prueba el género ${genreAnalysis.underexploredGenres.first}');
  }

  if (temporalAnalysis.preferredEra != 'N/A') {
    recommendations
        .add('Busca más clásicos de los ${temporalAnalysis.preferredEra}');
  }

  return recommendations;
}
