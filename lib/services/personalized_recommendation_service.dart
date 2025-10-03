import 'dart:math';

import '../core/logging/logger_factory.dart';
import '../domain/entities/movie.dart';
import '../domain/entities/syncable_movie_rating.dart';
import '../domain/repositories/movie_ratings_repository.dart';
import '../domain/repositories/movies_repository.dart';
import '../domain/repositories/watchlist_repository.dart';

/// Servicio de recomendaciones personalizadas usando múltiples algoritmos
class PersonalizedRecommendationService {
  PersonalizedRecommendationService._();

  static final PersonalizedRecommendationService _instance =
      PersonalizedRecommendationService._();
  static PersonalizedRecommendationService get instance => _instance;

  /// Obtiene recomendaciones personalizadas para un usuario
  Future<List<Movie>> getPersonalizedRecommendations({
    required String userId,
    required MoviesRepository moviesRepository,
    required MovieRatingsRepository ratingsRepository,
    required WatchlistRepository watchlistRepository,
    int limit = 20,
  }) async {
    try {
      LoggerFactory.info(
          '🎯 Generating personalized recommendations for user $userId');

      // Obtener datos del usuario
      final userRatings = await ratingsRepository.getUserRatings(limit: 100);
      final userWatchlist = await watchlistRepository.getWatchlistMovies();

      if (userRatings.isEmpty && userWatchlist.isEmpty) {
        LoggerFactory.info('📊 No user data found, returning popular movies');
        return await moviesRepository.getPopular(page: 1);
      }

      // Generar recomendaciones usando múltiples estrategias
      final recommendations = <Movie>[];

      // 1. Basado en géneros favoritos (40%)
      final genreRecommendations = await _getGenreBasedRecommendations(
        userRatings: userRatings,
        moviesRepository: moviesRepository,
        limit: (limit * 0.4).round(),
      );
      recommendations.addAll(genreRecommendations);

      // 2. Basado en calificaciones similares (30%) - Filtrado colaborativo simulado
      final collaborativeRecommendations =
          await _getCollaborativeRecommendations(
        userRatings: userRatings,
        ratingsRepository: ratingsRepository,
        moviesRepository: moviesRepository,
        limit: (limit * 0.3).round(),
      );
      recommendations.addAll(collaborativeRecommendations);

      // 3. Basado en popularidad y tendencias (20%)
      final trendingRecommendations = await _getTrendingRecommendations(
        userRatings: userRatings,
        moviesRepository: moviesRepository,
        limit: (limit * 0.2).round(),
      );
      recommendations.addAll(trendingRecommendations);

      // 4. Películas similares a las mejor calificadas (10%)
      final similarRecommendations = await _getSimilarMoviesRecommendations(
        userRatings: userRatings,
        moviesRepository: moviesRepository,
        limit: (limit * 0.1).round(),
      );
      recommendations.addAll(similarRecommendations);

      // Eliminar duplicados y películas ya vistas/calificadas
      final uniqueRecommendations = _removeDuplicatesAndSeen(
        recommendations,
        userRatings,
        userWatchlist,
      );

      // Ordenar por score de recomendación
      final scoredRecommendations = await _scoreRecommendations(
        uniqueRecommendations,
        userRatings,
      );

      final finalRecommendations = scoredRecommendations.take(limit).toList();

      LoggerFactory.info(
          '✅ Generated ${finalRecommendations.length} personalized recommendations');
      return finalRecommendations;
    } catch (e) {
      LoggerFactory.error('❌ Failed to generate recommendations: $e');
      // Fallback a películas populares
      return await moviesRepository.getPopular(page: 1);
    }
  }

  /// Obtiene recomendaciones "Porque viste X"
  Future<List<Movie>> getBecauseYouWatchedRecommendations({
    required Movie watchedMovie,
    required String userId,
    required MoviesRepository moviesRepository,
    int limit = 10,
  }) async {
    try {
      LoggerFactory.info(
          '🎬 Getting "Because you watched ${watchedMovie.title}" recommendations');

      // Obtener películas similares
      final similarMovies =
          await moviesRepository.getSimilarMovies(watchedMovie.id);

      // Filtrar y limitar resultados
      final filteredSimilar = similarMovies
          .where((movie) => movie.id != watchedMovie.id)
          .take(limit)
          .toList();

      LoggerFactory.info(
          '✅ Found ${filteredSimilar.length} "because you watched" recommendations');
      return filteredSimilar;
    } catch (e) {
      LoggerFactory.error(
          '❌ Failed to get "because you watched" recommendations: $e');
      return [];
    }
  }

  /// Obtiene recomendaciones basadas en tendencias actuales
  Future<List<Movie>> getTrendingNowRecommendations({
    required MoviesRepository moviesRepository,
    int limit = 15,
  }) async {
    try {
      LoggerFactory.info('📈 Getting trending now recommendations');

      // Combinar diferentes fuentes de tendencias
      final popular = await moviesRepository.getPopular(page: 1);
      final nowPlaying = await moviesRepository.getNowPlaying(page: 1);
      final upcoming = await moviesRepository.getUpcoming(page: 1);

      // Mezclar y deduplicar
      final trending = <Movie>[];
      trending.addAll(popular.take(5));
      trending.addAll(nowPlaying.take(5));
      trending.addAll(upcoming.take(5));

      // Eliminar duplicados
      final uniqueTrending = <Movie>[];
      final seenIds = <int>{};

      for (final movie in trending) {
        if (!seenIds.contains(movie.id)) {
          uniqueTrending.add(movie);
          seenIds.add(movie.id);
        }
      }

      final result = uniqueTrending.take(limit).toList();
      LoggerFactory.info('✅ Found ${result.length} trending recommendations');
      return result;
    } catch (e) {
      LoggerFactory.error('❌ Failed to get trending recommendations: $e');
      return [];
    }
  }

  /// Recomendaciones basadas en géneros favoritos del usuario
  Future<List<Movie>> _getGenreBasedRecommendations({
    required List<SyncableMovieRating> userRatings,
    required MoviesRepository moviesRepository,
    required int limit,
  }) async {
    LoggerFactory.info('🎭 Generating genre-based recommendations');

    // Analizar géneros favoritos del usuario
    final genrePreferences = _analyzeGenrePreferences(userRatings);
    if (genrePreferences.isEmpty) {
      return await moviesRepository.getPopular(page: 1);
    }

    // Obtener películas populares y filtrar por géneros preferidos
    final allMovies = <Movie>[];

    // Obtener de múltiples páginas para tener más variedad
    for (int page = 1; page <= 3; page++) {
      final popularMovies = await moviesRepository.getPopular(page: page);
      allMovies.addAll(popularMovies);
    }

    // Filtrar por géneros favoritos
    final genreBasedMovies = allMovies.where((movie) {
      return movie.genreIds.any((genreId) {
        return genrePreferences.containsKey(genreId) &&
            genrePreferences[genreId]! > 3.5;
      });
    }).toList();

    // Ordenar por popularidad y score de género
    genreBasedMovies.sort((a, b) {
      final aGenreScore = _calculateGenreScore(a, genrePreferences);
      final bGenreScore = _calculateGenreScore(b, genrePreferences);

      if (aGenreScore != bGenreScore) {
        return bGenreScore.compareTo(aGenreScore);
      }
      return b.popularity.compareTo(a.popularity);
    });

    return genreBasedMovies.take(limit).toList();
  }

  /// Recomendaciones basadas en filtrado colaborativo (simulado)
  Future<List<Movie>> _getCollaborativeRecommendations({
    required List<SyncableMovieRating> userRatings,
    required MovieRatingsRepository ratingsRepository,
    required MoviesRepository moviesRepository,
    required int limit,
  }) async {
    LoggerFactory.info('👥 Generating collaborative filtering recommendations');

    // En un sistema real, aquí buscaríamos usuarios similares
    // Por ahora, simulamos con películas mejor calificadas por el usuario
    final highRatedMovies = userRatings
        .where((rating) => rating.rating >= 4.0)
        .map((rating) => rating.movieId)
        .toList();

    if (highRatedMovies.isEmpty) {
      return await moviesRepository.getTopRated(page: 1);
    }

    // Obtener películas similares a las mejor calificadas
    final similarMovies = <Movie>[];

    for (final movieId in highRatedMovies.take(3)) {
      try {
        final similar = await moviesRepository.getSimilarMovies(movieId);
        similarMovies.addAll(similar);
      } catch (e) {
        // Continuar si una película falla
        continue;
      }
    }

    // Eliminar duplicados y ordenar por popularidad
    final uniqueSimilar = <Movie>[];
    final seenIds = <int>{};

    for (final movie in similarMovies) {
      if (!seenIds.contains(movie.id)) {
        uniqueSimilar.add(movie);
        seenIds.add(movie.id);
      }
    }

    uniqueSimilar.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
    return uniqueSimilar.take(limit).toList();
  }

  /// Recomendaciones basadas en tendencias
  Future<List<Movie>> _getTrendingRecommendations({
    required List<SyncableMovieRating> userRatings,
    required MoviesRepository moviesRepository,
    required int limit,
  }) async {
    LoggerFactory.info('📊 Generating trending recommendations');

    // Combinar películas populares y mejor calificadas
    final popular = await moviesRepository.getPopular(page: 1);
    final topRated = await moviesRepository.getTopRated(page: 1);

    // Mezclar ambas listas
    final trending = <Movie>[];
    for (int i = 0; i < max(popular.length, topRated.length); i++) {
      if (i < popular.length) trending.add(popular[i]);
      if (i < topRated.length) trending.add(topRated[i]);
    }

    // Eliminar duplicados
    final uniqueTrending = <Movie>[];
    final seenIds = <int>{};

    for (final movie in trending) {
      if (!seenIds.contains(movie.id)) {
        uniqueTrending.add(movie);
        seenIds.add(movie.id);
      }
    }

    return uniqueTrending.take(limit).toList();
  }

  /// Recomendaciones basadas en películas similares
  Future<List<Movie>> _getSimilarMoviesRecommendations({
    required List<SyncableMovieRating> userRatings,
    required MoviesRepository moviesRepository,
    required int limit,
  }) async {
    LoggerFactory.info('🎯 Generating similar movies recommendations');

    // Obtener las películas mejor calificadas del usuario
    final bestRatedMovies = userRatings
        .where((rating) => rating.rating >= 4.5)
        .toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));

    if (bestRatedMovies.isEmpty) {
      return [];
    }

    final similarMovies = <Movie>[];

    // Obtener similares para las mejores calificaciones
    for (final rating in bestRatedMovies.take(2)) {
      try {
        final similar = await moviesRepository.getSimilarMovies(rating.movieId);
        similarMovies.addAll(similar);
      } catch (e) {
        continue;
      }
    }

    // Eliminar duplicados
    final uniqueSimilar = <Movie>[];
    final seenIds = <int>{};

    for (final movie in similarMovies) {
      if (!seenIds.contains(movie.id)) {
        uniqueSimilar.add(movie);
        seenIds.add(movie.id);
      }
    }

    return uniqueSimilar.take(limit).toList();
  }

  /// Analiza las preferencias de género del usuario
  Map<int, double> _analyzeGenrePreferences(List<SyncableMovieRating> ratings) {
    final genreScores = <int, List<double>>{};

    // Agrupar calificaciones por género
    for (final rating in ratings) {
      // Nota: En un sistema real, necesitaríamos los géneros de cada película
      // Por ahora, simulamos algunos géneros comunes
      final movieGenres = _getMovieGenres(rating.movieId);

      for (final genreId in movieGenres) {
        genreScores.putIfAbsent(genreId, () => []);
        genreScores[genreId]!.add(rating.rating);
      }
    }

    // Calcular promedio por género
    final genrePreferences = <int, double>{};
    genreScores.forEach((genreId, scores) {
      final average = scores.reduce((a, b) => a + b) / scores.length;
      genrePreferences[genreId] = average;
    });

    return genrePreferences;
  }

  /// Calcula el score de una película basado en preferencias de género
  double _calculateGenreScore(Movie movie, Map<int, double> genrePreferences) {
    double totalScore = 0.0;
    int genreCount = 0;

    for (final genreId in movie.genreIds) {
      if (genrePreferences.containsKey(genreId)) {
        totalScore += genrePreferences[genreId]!;
        genreCount++;
      }
    }

    return genreCount > 0 ? totalScore / genreCount : 0.0;
  }

  /// Simula géneros de una película (en un sistema real, esto vendría de la DB)
  List<int> _getMovieGenres(int movieId) {
    // Simulación básica basada en el ID
    final random = Random(movieId);
    final allGenres = [
      28,
      12,
      16,
      35,
      80,
      99,
      18,
      10751,
      14,
      36,
      27,
      10402,
      9648,
      10749,
      878,
      53,
      10752,
      37
    ];

    final genreCount = 1 + random.nextInt(3); // 1-3 géneros
    final genres = <int>[];

    for (int i = 0; i < genreCount; i++) {
      final genre = allGenres[random.nextInt(allGenres.length)];
      if (!genres.contains(genre)) {
        genres.add(genre);
      }
    }

    return genres;
  }

  /// Elimina duplicados y películas ya vistas
  List<Movie> _removeDuplicatesAndSeen(
    List<Movie> recommendations,
    List<SyncableMovieRating> userRatings,
    List<Movie> userWatchlist,
  ) {
    final seenMovieIds = <int>{};

    // Agregar películas calificadas
    seenMovieIds.addAll(userRatings.map((rating) => rating.movieId));

    // Agregar películas en watchlist
    seenMovieIds.addAll(userWatchlist.map((movie) => movie.id));

    // Filtrar duplicados y películas vistas
    final unique = <Movie>[];
    final processedIds = <int>{};

    for (final movie in recommendations) {
      if (!processedIds.contains(movie.id) &&
          !seenMovieIds.contains(movie.id)) {
        unique.add(movie);
        processedIds.add(movie.id);
      }
    }

    return unique;
  }

  /// Calcula scores de recomendación y ordena
  Future<List<Movie>> _scoreRecommendations(
    List<Movie> movies,
    List<SyncableMovieRating> userRatings,
  ) async {
    // Analizar preferencias del usuario
    final genrePreferences = _analyzeGenrePreferences(userRatings);

    // Calcular score para cada película
    final scoredMovies = movies.map((movie) {
      double score = 0.0;

      // Factor de género (40%)
      final genreScore = _calculateGenreScore(movie, genrePreferences);
      score += genreScore * 0.4;

      // Factor de calificación pública (30%)
      score += (movie.voteAverage / 10.0) * 0.3;

      // Factor de popularidad (20%)
      score += (movie.popularity / 1000.0).clamp(0.0, 1.0) * 0.2;

      // Factor de recencia (10%)
      final yearsSinceRelease = DateTime.now().year - movie.releaseDate.year;
      final recencyScore =
          (1.0 / (1.0 + yearsSinceRelease * 0.1)).clamp(0.0, 1.0);
      score += recencyScore * 0.1;

      return _ScoredMovie(movie, score);
    }).toList();

    // Ordenar por score descendente
    scoredMovies.sort((a, b) => b.score.compareTo(a.score));

    return scoredMovies.map((scored) => scored.movie).toList();
  }

  /// Obtiene estadísticas de recomendaciones para análisis
  Future<RecommendationStats> getRecommendationStats({
    required String userId,
    required MovieRatingsRepository ratingsRepository,
    required WatchlistRepository watchlistRepository,
  }) async {
    try {
      final userRatings = await ratingsRepository.getUserRatings(limit: 100);
      final userWatchlist = await watchlistRepository.getWatchlistMovies();
      final genrePreferences = _analyzeGenrePreferences(userRatings);

      return RecommendationStats(
        totalRatings: userRatings.length,
        totalWatchlistItems: userWatchlist.length,
        favoriteGenres: genrePreferences.entries
            .where((entry) => entry.value >= 4.0)
            .map((entry) => entry.key)
            .toList(),
        averageRating: userRatings.isNotEmpty
            ? userRatings.map((r) => r.rating).reduce((a, b) => a + b) /
                userRatings.length
            : 0.0,
        recommendationAccuracy: _calculateRecommendationAccuracy(userRatings),
      );
    } catch (e) {
      LoggerFactory.error('❌ Failed to get recommendation stats: $e');
      return RecommendationStats.empty();
    }
  }

  /// Calcula la precisión de las recomendaciones (simulado)
  double _calculateRecommendationAccuracy(
      List<SyncableMovieRating> userRatings) {
    if (userRatings.isEmpty) return 0.0;

    // Simulación: las recomendaciones son más precisas cuantas más calificaciones tenga el usuario
    final ratingCount = userRatings.length;
    if (ratingCount < 5) return 0.3;
    if (ratingCount < 15) return 0.5;
    if (ratingCount < 50) return 0.7;
    return 0.85;
  }
}

/// Película con score de recomendación
class _ScoredMovie {
  _ScoredMovie(this.movie, this.score);
  final Movie movie;
  final double score;
}

/// Estadísticas de recomendaciones del usuario
class RecommendationStats {
  const RecommendationStats({
    required this.totalRatings,
    required this.totalWatchlistItems,
    required this.favoriteGenres,
    required this.averageRating,
    required this.recommendationAccuracy,
  });

  factory RecommendationStats.empty() {
    return const RecommendationStats(
      totalRatings: 0,
      totalWatchlistItems: 0,
      favoriteGenres: [],
      averageRating: 0.0,
      recommendationAccuracy: 0.0,
    );
  }
  final int totalRatings;
  final int totalWatchlistItems;
  final List<int> favoriteGenres;
  final double averageRating;
  final double recommendationAccuracy;

  /// Indica si el usuario tiene suficientes datos para recomendaciones precisas
  bool get hasEnoughDataForRecommendations =>
      totalRatings >= 5 || totalWatchlistItems >= 10;

  /// Nivel de personalización basado en los datos disponibles
  String get personalizationLevel {
    if (totalRatings == 0 && totalWatchlistItems == 0) return 'Sin datos';
    if (totalRatings < 5) return 'Básico';
    if (totalRatings < 15) return 'Intermedio';
    if (totalRatings < 50) return 'Avanzado';
    return 'Experto';
  }
}
