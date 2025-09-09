import '../../domain/entities/movie.dart';
import '../../domain/entities/recommendation.dart';
import '../../domain/entities/watched_movie.dart';
import '../../domain/repositories/recommendations_repository.dart';
import '../analytics/analytics_service.dart';
import '../logging/logger_factory.dart';
import 'recommendation_engine.dart';
import 'user_behavior_analyzer.dart';

/// Servicio ML que integra el motor de recomendaciones con los servicios existentes
class MLRecommendationService {
  MLRecommendationService._();
  static MLRecommendationService? _instance;
  static MLRecommendationService get instance =>
      _instance ??= MLRecommendationService._();

  final _logger = LoggerFactory.logger;
  final _recommendationEngine = RecommendationEngine.instance;
  final _behaviorAnalyzer = UserBehaviorAnalyzer.instance;
  final _analyticsService = AnalyticsService();

  RecommendationsRepository? _recommendationsRepository;
  bool _isInitialized = false;

  /// Inicializa el servicio ML con el repositorio de recomendaciones
  Future<void> initialize(RecommendationsRepository repository) async {
    try {
      _recommendationsRepository = repository;
      await _analyticsService.trackEvent(AnalyticsEventType.appLaunch, {});
      _logger.info('Servicio ML de recomendaciones inicializado');
      _isInitialized = true;
    } catch (e) {
      _logger.error('Error inicializando servicio ML: $e');
      await _analyticsService.trackEvent(AnalyticsEventType.error, {
        'error': e.toString(),
      });
      rethrow;
    }
  }

  /// Genera recomendaciones ML mejoradas para un usuario
  Future<List<Recommendation>> getMLEnhancedRecommendations({
    required int userId,
    required List<Movie> favoriteMovies,
    required List<WatchedMovie> watchedMovies,
    int limit = 20,
    String? mood,
  }) async {
    try {
      if (!_isInitialized || _recommendationsRepository == null) {
        _logger.warning(
            'Servicio ML no inicializado, usando recomendaciones básicas');
        return [];
      }

      _logger.info('Generando recomendaciones ML para usuario $userId');

      // Track analytics event
      await _analyticsService
          .trackEvent(AnalyticsEventType.recommendationView, {
        'user_id': userId.toString(),
        'favorite_count': favoriteMovies.length,
        'watched_count': watchedMovies.length,
        'limit': limit,
        'mood': mood ?? 'none',
      });

      // Inicializar motor de recomendaciones con datos del usuario
      await _recommendationEngine.initialize(
        favoriteMovies: favoriteMovies,
        watchedMovies: watchedMovies,
        userId: userId,
      );

      // Generar recomendaciones híbridas
      final mlRecommendations =
          await _recommendationEngine.generateHybridRecommendations(
        userId: userId,
        favoriteMovies: favoriteMovies,
        watchedMovies: watchedMovies,
        limit: limit,
      );

      // Enriquecer recomendaciones con datos reales de películas
      final enrichedRecommendations =
          await _enrichRecommendationsWithMovieData(mlRecommendations);

      // Aplicar filtros basados en mood si se especifica
      final filteredRecommendations = mood != null
          ? await _applyMoodFiltering(enrichedRecommendations, mood)
          : enrichedRecommendations;

      // Reordenar basado en análisis de comportamiento
      final behaviorAnalysis = await analyzeUserBehavior(
        favoriteMovies: favoriteMovies,
        watchedMovies: watchedMovies,
      );

      final reorderedRecommendations = await _reorderByBehaviorAnalysis(
          filteredRecommendations, behaviorAnalysis);

      await _analyticsService
          .trackEvent(AnalyticsEventType.recommendationView, {
        'user_id': userId.toString(),
        'recommendations_count': reorderedRecommendations.length,
        'final_count': reorderedRecommendations.take(limit).length,
      });

      _logger.info(
          'Generadas ${reorderedRecommendations.length} recomendaciones ML');
      return reorderedRecommendations.take(limit).toList();
    } catch (e) {
      _logger.error('Error generando recomendaciones ML: $e');
      await _analyticsService.trackEvent(AnalyticsEventType.error, {
        'user_id': userId.toString(),
        'error': e.toString(),
      });
      return [];
    }
  }

  /// Calcula similitud entre películas usando ML
  Future<double> calculateMovieSimilarity(Movie movie1, Movie movie2) async {
    try {
      return await _recommendationEngine.calculateMovieSimilarity(
          movie1, movie2);
    } catch (e) {
      _logger.error('Error calculando similitud ML: $e');
      return 0.0;
    }
  }

  /// Encuentra películas similares usando algoritmos ML
  Future<List<Recommendation>> findSimilarMovies({
    required Movie targetMovie,
    required List<Movie> favoriteMovies,
    required List<WatchedMovie> watchedMovies,
    int limit = 10,
  }) async {
    try {
      final similarMovies = <Recommendation>[];

      // Obtener todas las películas candidatas (simulado - en implementación real vendría de API)
      final candidateMovies = await _getCandidateMovies();

      // Calcular similitudes
      final similarities = <Movie, double>{};
      for (final candidate in candidateMovies) {
        if (candidate.id != targetMovie.id) {
          final similarity =
              await calculateMovieSimilarity(targetMovie, candidate);
          similarities[candidate] = similarity;
        }
      }

      // Ordenar por similitud y crear recomendaciones
      final sortedSimilarities = similarities.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in sortedSimilarities.take(limit)) {
        final movie = entry.key;
        final similarity = entry.value;

        similarMovies.add(Recommendation(
          movieId: movie.id,
          title: movie.title,
          posterPath: movie.posterPath,
          score: similarity,
          reason: 'Similar a "${targetMovie.title}"',
          type: RecommendationType.basedOnFavorites,
          tags: ['ml_similarity', 'similar_to_${targetMovie.id}'],
        ));
      }

      _logger.info(
          'Encontradas ${similarMovies.length} películas similares a "${targetMovie.title}"');
      return similarMovies;
    } catch (e) {
      _logger.error('Error encontrando películas similares: $e');
      return [];
    }
  }

  /// Genera recomendaciones basadas en mood usando ML
  Future<List<Recommendation>> getMoodBasedRecommendations({
    required String mood,
    required List<Movie> favoriteMovies,
    required List<WatchedMovie> watchedMovies,
    int limit = 15,
  }) async {
    try {
      _logger.info('Generando recomendaciones basadas en mood: $mood');

      // Analizar patrones de mood del usuario
      final behaviorAnalysis = await analyzeUserBehavior(
        favoriteMovies: favoriteMovies,
        watchedMovies: watchedMovies,
      );

      // Mapear mood a géneros y características
      final moodCharacteristics = _getMoodCharacteristics(mood);

      // Obtener candidatos basados en mood
      final candidateMovies = await _getCandidateMoviesByMood(mood);

      // Filtrar y puntuar basado en preferencias del usuario
      final scoredRecommendations = <Recommendation>[];

      for (final movie in candidateMovies) {
        final moodScore = _calculateMoodScore(movie, moodCharacteristics);
        final personalScore = await _calculatePersonalizedScore(
            movie, favoriteMovies, watchedMovies, behaviorAnalysis);

        final combinedScore =
            (moodScore * 0.6 + personalScore * 0.4).clamp(0.0, 1.0);

        if (combinedScore > 0.3) {
          // Umbral mínimo
          scoredRecommendations.add(Recommendation(
            movieId: movie.id,
            title: movie.title,
            posterPath: movie.posterPath,
            score: combinedScore,
            reason: 'Perfecta para tu mood $mood',
            type: RecommendationType.mood,
            tags: ['mood_$mood', 'ml_personalized'],
          ));
        }
      }

      // Ordenar por puntuación
      scoredRecommendations.sort((a, b) => b.score.compareTo(a.score));

      _logger.info(
          'Generadas ${scoredRecommendations.length} recomendaciones para mood $mood');
      return scoredRecommendations.take(limit).toList();
    } catch (e) {
      _logger.error('Error generando recomendaciones por mood: $e');
      return [];
    }
  }

  /// Analiza el comportamiento del usuario y genera insights
  Future<UserBehaviorAnalysis> analyzeUserBehavior({
    required List<Movie> favoriteMovies,
    required List<WatchedMovie> watchedMovies,
  }) async {
    try {
      // Use the behavior analyzer to analyze viewing patterns
      final viewingPatterns = await _behaviorAnalyzer.analyzeViewingPatterns(
        watchedMovies,
      );

      // Create a UserBehaviorAnalysis with the analyzed data
      final analysis = UserBehaviorAnalysis();
      analysis.genrePreferences =
          viewingPatterns.genreAnalysis.topGenres.asMap().map(
                (index, entry) =>
                    MapEntry(entry.key.toString(), entry.value.toDouble()),
              );
      analysis.diversityScore =
          viewingPatterns.diversityAnalysis.totalDiversityScore;

      return analysis;
    } catch (e) {
      _logger.error('Error analizando comportamiento: $e');
      final analysis = UserBehaviorAnalysis();
      analysis.genrePreferences = {};
      analysis.diversityScore = 0.5;
      return analysis;
    }
  }

  /// Genera insights personalizados para el usuario
  Future<List<UserInsight>> generatePersonalizedInsights({
    required List<Movie> favoriteMovies,
    required List<WatchedMovie> watchedMovies,
  }) async {
    try {
      return await _behaviorAnalyzer.generatePersonalizedInsights(
        favoriteMovies: favoriteMovies,
        watchedMovies: watchedMovies,
      );
    } catch (e) {
      _logger.error('Error generando insights: $e');
      return [];
    }
  }

  /// Predice la próxima película que el usuario podría ver
  Future<MoviePrediction> predictNextMovie({
    required List<Movie> favoriteMovies,
    required List<WatchedMovie> watchedMovies,
  }) async {
    try {
      return await _behaviorAnalyzer.predictNextMovie(
        favoriteMovies: favoriteMovies,
        watchedMovies: watchedMovies,
      );
    } catch (e) {
      _logger.error('Error prediciendo próxima película: $e');
      return MoviePrediction();
    }
  }

  /// Calcula el score de engagement del usuario
  Future<EngagementScore> calculateEngagementScore({
    required List<Movie> favoriteMovies,
    required List<WatchedMovie> watchedMovies,
  }) async {
    try {
      return await _behaviorAnalyzer.calculateEngagementScore(
        favoriteMovies: favoriteMovies,
        watchedMovies: watchedMovies,
      );
    } catch (e) {
      _logger.error('Error calculando engagement: $e');
      return EngagementScore();
    }
  }

  /// Explica por qué se recomendó una película específica
  String explainRecommendation(
    Recommendation recommendation, {
    required List<Movie> favoriteMovies,
    required List<WatchedMovie> watchedMovies,
  }) {
    try {
      return _recommendationEngine.explainRecommendation(
        recommendation,
        favoriteMovies: favoriteMovies,
        watchedMovies: watchedMovies,
      );
    } catch (e) {
      _logger.error('Error explicando recomendación: $e');
      return 'Recomendada para ti';
    }
  }

  /// Procesa feedback del usuario para mejorar recomendaciones
  Future<void> processFeedback({
    required int movieId,
    required FeedbackType feedbackType,
    required int userId,
    String? reason,
  }) async {
    try {
      _logger.info('Procesando feedback para película $movieId: $feedbackType');

      // En una implementación real, esto actualizaría los modelos ML
      // Por ahora, solo registramos el feedback

      final feedbackData = {
        'movieId': movieId,
        'userId': userId,
        'feedbackType': feedbackType.toString(),
        'reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Aquí se podría enviar a un servicio de analytics o base de datos
      _logger.info('Feedback registrado: $feedbackData');

      // Simular actualización de preferencias
      await _updateUserPreferencesBasedOnFeedback(
          userId, movieId, feedbackType);
    } catch (e) {
      _logger.error('Error procesando feedback: $e');
    }
  }

  /// Detecta anomalías en el comportamiento del usuario
  Future<List<BehaviorAnomaly>> detectBehaviorAnomalies(
      List<WatchedMovie> watchedMovies) async {
    try {
      return await _behaviorAnalyzer.detectAnomalies(watchedMovies);
    } catch (e) {
      _logger.error('Error detectando anomalías: $e');
      return [];
    }
  }

  // Métodos privados de utilidad

  Future<List<Recommendation>> _enrichRecommendationsWithMovieData(
      List<Recommendation> recommendations) async {
    // En una implementación real, esto obtendría datos completos de películas desde la API
    // Por ahora, simulamos el enriquecimiento

    final enriched = <Recommendation>[];

    for (final rec in recommendations) {
      // Simular obtención de datos de película
      final movieData = await _getMovieData(rec.movieId);

      if (movieData != null) {
        enriched.add(Recommendation(
          movieId: rec.movieId,
          title: movieData['title'] ?? rec.title,
          posterPath: movieData['poster_path'] ?? rec.posterPath,
          score: rec.score,
          reason: rec.reason,
          type: rec.type,
          tags: rec.tags,
        ));
      } else {
        enriched.add(rec);
      }
    }

    return enriched;
  }

  Future<List<Recommendation>> _applyMoodFiltering(
      List<Recommendation> recommendations, String mood) async {
    return recommendations.where((rec) {
      // Filtrar por tags relacionados con el mood
      return rec.tags.any((tag) => tag.contains(mood.toLowerCase())) ||
          rec.reason.toLowerCase().contains(mood.toLowerCase());
    }).toList();
  }

  Future<List<Recommendation>> _reorderByBehaviorAnalysis(
    List<Recommendation> recommendations,
    UserBehaviorAnalysis behaviorAnalysis,
  ) async {
    // Reordenar basado en preferencias de género del usuario
    final reordered = List<Recommendation>.from(recommendations);

    reordered.sort((a, b) {
      // Calcular score basado en preferencias de género
      double scoreA =
          _calculateGenrePreferenceScore(a, behaviorAnalysis.genrePreferences);
      double scoreB =
          _calculateGenrePreferenceScore(b, behaviorAnalysis.genrePreferences);

      // Combinar con score original
      scoreA = (a.score * 0.7 + scoreA * 0.3);
      scoreB = (b.score * 0.7 + scoreB * 0.3);

      return scoreB.compareTo(scoreA);
    });

    return reordered;
  }

  double _calculateGenrePreferenceScore(
      Recommendation rec, Map<String, double> genrePreferences) {
    double score = 0.0;

    for (final tag in rec.tags) {
      if (tag.startsWith('genre_')) {
        final preference = genrePreferences[tag] ?? 0.0;
        score += preference;
      }
    }

    return score.clamp(0.0, 1.0);
  }

  Future<List<Movie>> _getCandidateMovies() async {
    // En implementación real, esto obtendría películas de la API
    // Por ahora, retornamos una lista simulada
    return [];
  }

  Future<List<Movie>> _getCandidateMoviesByMood(String mood) async {
    // En implementación real, esto filtrarían películas por mood desde la API
    return [];
  }

  Map<String, dynamic> _getMoodCharacteristics(String mood) {
    final moodMap = {
      'happy': {
        'genres': [35, 10751, 16], // Comedy, Family, Animation
        'min_rating': 6.0,
        'energy_level': 'high',
      },
      'sad': {
        'genres': [18, 10749], // Drama, Romance
        'min_rating': 7.0,
        'energy_level': 'low',
      },
      'excited': {
        'genres': [28, 12, 878], // Action, Adventure, Sci-Fi
        'min_rating': 6.5,
        'energy_level': 'high',
      },
      'relaxed': {
        'genres': [99, 36, 10402], // Documentary, History, Music
        'min_rating': 6.0,
        'energy_level': 'low',
      },
      'scared': {
        'genres': [27, 53], // Horror, Thriller
        'min_rating': 5.5,
        'energy_level': 'high',
      },
    };

    return moodMap[mood.toLowerCase()] ?? moodMap['happy']!;
  }

  double _calculateMoodScore(
      Movie movie, Map<String, dynamic> moodCharacteristics) {
    double score = 0.0;

    // Score basado en géneros
    final moodGenres = List<int>.from(moodCharacteristics['genres'] ?? []);
    final genreMatch =
        movie.genreIds.any((id) => moodGenres.contains(int.tryParse(id) ?? 0));
    if (genreMatch) score += 0.6;

    // Score basado en rating mínimo
    final minRating = moodCharacteristics['min_rating'] ?? 5.0;
    if (movie.voteAverage >= minRating) score += 0.3;

    // Score basado en popularidad (para energy level)
    final energyLevel = moodCharacteristics['energy_level'] ?? 'medium';
    if (energyLevel == 'high' && movie.popularity > 300) {
      score += 0.1;
    } else if (energyLevel == 'low' && movie.popularity < 200) {
      score += 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  Future<double> _calculatePersonalizedScore(
    Movie movie,
    List<Movie> favoriteMovies,
    List<WatchedMovie> watchedMovies,
    UserBehaviorAnalysis behaviorAnalysis,
  ) async {
    double score = 0.0;

    // Score basado en géneros preferidos
    for (final genreId in movie.genreIds) {
      final genreKey = 'genre_$genreId';
      final preference = behaviorAnalysis.genrePreferences[genreKey] ?? 0.0;
      score += preference;
    }

    // Normalizar por número de géneros
    if (movie.genreIds.isNotEmpty) {
      score /= movie.genreIds.length;
    }

    // Bonus por diversidad si el usuario es diverso
    if (behaviorAnalysis.diversityScore > 0.6) {
      final isNewGenre = !favoriteMovies.any((fav) => fav.genreIds.any(
          (favId) => movie.genreIds.any((movieId) =>
              (int.tryParse(favId) ?? 0) == (int.tryParse(movieId) ?? 0))));
      if (isNewGenre) score += 0.2;
    }

    return score.clamp(0.0, 1.0);
  }

  Future<Map<String, dynamic>?> _getMovieData(int movieId) async {
    // En implementación real, esto haría una llamada a la API
    // Por ahora, simulamos datos
    return {
      'title': 'Película $movieId',
      'poster_path': '/poster_$movieId.jpg',
    };
  }

  Future<void> _updateUserPreferencesBasedOnFeedback(
    int userId,
    int movieId,
    FeedbackType feedbackType,
  ) async {
    // En implementación real, esto actualizaría las preferencias del usuario
    // basándose en el feedback positivo o negativo

    _logger.info(
        'Actualizando preferencias del usuario $userId basado en feedback $feedbackType para película $movieId');

    // Simular actualización de preferencias
    // Esto podría incluir:
    // - Aumentar/disminuir peso de géneros
    // - Ajustar preferencias de actores/directores
    // - Modificar umbrales de calidad
    // - Actualizar patrones temporales
  }
}

/// Tipos de feedback que puede dar el usuario
enum FeedbackType {
  like,
  dislike,
  notInterested,
  alreadyWatched,
  addedToWatchlist,
  shared,
}
