import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entities.dart';
import 'custom_lists_provider.dart';
import 'storage/favorite_movies_provider.dart';
import 'watched_movies_provider.dart';

// Provider combinado para datos de estadísticas (optimización de performance)
// Usa .autoDispose para liberar recursos cuando no se usa
final userStatsDataProvider = Provider.autoDispose<({
  List<Movie> favoriteMovies,
  List<WatchedMovie> watchedMovies,
  List<CustomList> customLists,
  List<CustomList> defaultLists,
})>((ref) {
  final favoriteMoviesMap = ref.watch(favoriteMoviesProvider);
  final favoriteMovies = favoriteMoviesMap.values.toList();
  final watchedMoviesState = ref.watch(watchedMoviesProvider);
  final customLists = ref.watch(customListsProvider);
  final defaultLists = ref.watch(defaultListsProvider);

  return (
    favoriteMovies: favoriteMovies,
    watchedMovies: watchedMoviesState.movies,
    customLists: customLists,
    defaultLists: defaultLists,
  );
});

// Provider para estadísticas del usuario (optimizado con caché)
final userStatsProvider = FutureProvider.autoDispose<UserStats>((ref) async {
  final data = ref.watch(userStatsDataProvider);

  // Mantener el provider activo por 5 minutos para evitar recálculos frecuentes
  ref.keepAlive();
  
  // Programar limpieza automática después de 5 minutos de inactividad
  final timer = Timer(const Duration(minutes: 5), () {
    ref.invalidateSelf();
  });
  
  ref.onDispose(() {
    timer.cancel();
  });

  return UserStats.fromMovies(
    favoriteMovies: data.favoriteMovies,
    watchedMovies: data.watchedMovies,
    customLists: data.customLists,
    defaultLists: data.defaultLists,
  );
});

// Provider para análisis de géneros (optimizado con caché)
final genreAnalysisProvider = FutureProvider.autoDispose<GenreAnalysis>((ref) async {
  final data = ref.watch(userStatsDataProvider);

  // Mantener activo por tiempo limitado
  ref.keepAlive();
  final timer = Timer(const Duration(minutes: 3), () {
    ref.invalidateSelf();
  });
  ref.onDispose(() => timer.cancel());

  return GenreAnalysis.fromMovies(
    favoriteMovies: data.favoriteMovies,
    watchedMovies: data.watchedMovies,
  );
});

// Provider para análisis temporal (optimizado con caché)
final temporalAnalysisProvider = FutureProvider.autoDispose<TemporalAnalysis>((ref) async {
  final data = ref.watch(userStatsDataProvider);

  ref.keepAlive();
  final timer = Timer(const Duration(minutes: 3), () {
    ref.invalidateSelf();
  });
  ref.onDispose(() => timer.cancel());

  return TemporalAnalysis.fromMovies(
    favoriteMovies: data.favoriteMovies,
    watchedMovies: data.watchedMovies,
  );
});

// Provider para análisis de calificaciones (optimizado con caché)
final ratingAnalysisProvider = FutureProvider.autoDispose<RatingAnalysis>((ref) async {
  final data = ref.watch(userStatsDataProvider);

  ref.keepAlive();
  final timer = Timer(const Duration(minutes: 3), () {
    ref.invalidateSelf();
  });
  ref.onDispose(() => timer.cancel());

  return RatingAnalysis.fromMovies(
    favoriteMovies: data.favoriteMovies,
    watchedMovies: data.watchedMovies,
  );
});

// Provider para patrones de actividad (optimizado con caché)
final activityPatternsProvider = FutureProvider.autoDispose<ActivityPatterns>((ref) async {
  final data = ref.watch(userStatsDataProvider);

  ref.keepAlive();
  final timer = Timer(const Duration(minutes: 3), () {
    ref.invalidateSelf();
  });
  ref.onDispose(() => timer.cancel());

  return ActivityPatterns.fromWatchedMovies(data.watchedMovies);
});

// Provider para recomendaciones basadas en estadísticas (optimizado)
final statsBasedRecommendationsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  // Usar select para evitar reconstrucción innecesaria
  final genreAnalysis = await ref.watch(genreAnalysisProvider.future);
  final temporalAnalysis = await ref.watch(temporalAnalysisProvider.future);
  final ratingAnalysis = await ref.watch(ratingAnalysisProvider.future);

  ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), () {
    ref.invalidateSelf();
  });
  ref.onDispose(() => timer.cancel());

  return _generateRecommendations(
    genreAnalysis: genreAnalysis,
    temporalAnalysis: temporalAnalysis,
    ratingAnalysis: ratingAnalysis,
  );
});

// Provider ligero para casos donde solo se necesitan estadísticas básicas
final basicUserStatsProvider = Provider.autoDispose<BasicUserStats>((ref) {
  final data = ref.watch(userStatsDataProvider);
  
  return BasicUserStats(
    totalFavorites: data.favoriteMovies.length,
    totalWatched: data.watchedMovies.length,
    totalCustomLists: data.customLists.length,
    totalDefaultLists: data.defaultLists.length,
  );
});

// Clase para estadísticas básicas sin cálculos pesados
class BasicUserStats {
  const BasicUserStats({
    required this.totalFavorites,
    required this.totalWatched,
    required this.totalCustomLists,
    required this.totalDefaultLists,
  });

  final int totalFavorites;
  final int totalWatched;
  final int totalCustomLists;
  final int totalDefaultLists;
  
  int get totalMoviesInteractedWith => totalFavorites + totalWatched;
  int get totalLists => totalCustomLists + totalDefaultLists;
}

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
