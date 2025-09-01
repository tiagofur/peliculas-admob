import 'dart:math';

import '../../domain/entities/movie.dart';
import '../../domain/entities/recommendation.dart';
import '../../domain/entities/watched_movie.dart';
import '../logging/logger_factory.dart';

/// Motor de recomendaciones ML avanzado con múltiples algoritmos
class RecommendationEngine {
  RecommendationEngine._();
  static RecommendationEngine? _instance;
  static RecommendationEngine get instance =>
      _instance ??= RecommendationEngine._();

  final _logger = LoggerFactory.logger;
  final _random = Random();

  // Matrices para filtrado colaborativo
  final Map<int, Map<int, double>> _userMovieMatrix = {};
  final Map<int, Map<String, double>> _movieFeatureMatrix = {};
  final Map<int, List<double>> _userEmbeddings = {};
  final Map<int, List<double>> _movieEmbeddings = {};

  // Parámetros del modelo
  static const int _embeddingDimensions = 50;
  static const double _learningRate = 0.01;
  static const int _maxIterations = 100;
  static const double _regularization = 0.01;

  /// Inicializa el motor de recomendaciones con datos de usuario
  Future<void> initialize({
    required List<Movie> favoriteMovies,
    required List<WatchedMovie> watchedMovies,
    required int userId,
  }) async {
    try {
      _logger.info('Inicializando motor de recomendaciones ML');

      await _buildUserMovieMatrix(userId, favoriteMovies, watchedMovies);
      await _buildMovieFeatureMatrix(favoriteMovies +
          watchedMovies
              .map((w) => Movie(
                    id: w.id,
                    title: w.title,
                    overview: w.overview,
                    posterPath: w.posterPath,
                    backdropPath: w.backdropPath,
                    releaseDate: w.releaseDate,
                    genreIds: w.genreIds,
                    voteAverage: w.voteAverage,
                    voteCount: w.movie.voteCount,
                    popularity: w.movie.popularity,
                    adult: w.movie.adult,
                    originalLanguage: w.movie.originalLanguage,
                    originalTitle: w.movie.originalTitle,
                    video: w.movie.video,
                  ))
              .toList());

      await _trainCollaborativeFiltering();

      _logger.info('Motor de recomendaciones ML inicializado exitosamente');
    } catch (e) {
      _logger.error('Error inicializando motor ML: $e');
      rethrow;
    }
  }

  /// Genera recomendaciones híbridas combinando múltiples algoritmos
  Future<List<Recommendation>> generateHybridRecommendations({
    required int userId,
    required List<Movie> favoriteMovies,
    required List<WatchedMovie> watchedMovies,
    int limit = 20,
  }) async {
    try {
      final recommendations = <Recommendation>[];

      // 40% Filtrado colaborativo
      final collaborativeRecs = await _generateCollaborativeRecommendations(
        userId,
        limit: (limit * 0.4).round(),
      );
      recommendations.addAll(collaborativeRecs);

      // 35% Filtrado basado en contenido
      final contentRecs = await _generateContentBasedRecommendations(
        favoriteMovies,
        watchedMovies,
        limit: (limit * 0.35).round(),
      );
      recommendations.addAll(contentRecs);

      // 15% Análisis de tendencias
      final trendingRecs = await _generateTrendingRecommendations(
        limit: (limit * 0.15).round(),
      );
      recommendations.addAll(trendingRecs);

      // 10% Diversidad y exploración
      final explorationRecs = await _generateExplorationRecommendations(
        favoriteMovies,
        watchedMovies,
        limit: (limit * 0.1).round(),
      );
      recommendations.addAll(explorationRecs);

      // Reordenar por puntuación y eliminar duplicados
      final uniqueRecs = _removeDuplicatesAndRerank(recommendations);

      _logger.info('Generadas ${uniqueRecs.length} recomendaciones híbridas');
      return uniqueRecs.take(limit).toList();
    } catch (e) {
      _logger.error('Error generando recomendaciones híbridas: $e');
      return [];
    }
  }

  /// Calcula similitud entre películas usando múltiples métricas
  Future<double> calculateMovieSimilarity(Movie movie1, Movie movie2) async {
    try {
      double similarity = 0.0;

      // Similitud de géneros (40%)
      final genreSimilarity = _calculateGenreSimilarity(
          movie1.genreIds.map((g) => int.tryParse(g) ?? 0).toList(),
          movie2.genreIds.map((g) => int.tryParse(g) ?? 0).toList());
      similarity += genreSimilarity * 0.4;

      // Similitud de embeddings (30%)
      if (_movieEmbeddings.containsKey(movie1.id) &&
          _movieEmbeddings.containsKey(movie2.id)) {
        final embeddingSimilarity = _calculateCosineSimilarity(
          _movieEmbeddings[movie1.id]!,
          _movieEmbeddings[movie2.id]!,
        );
        similarity += embeddingSimilarity * 0.3;
      }

      // Similitud de popularidad (15%)
      final popularitySimilarity = _calculatePopularitySimilarity(
        movie1.popularity,
        movie2.popularity,
      );
      similarity += popularitySimilarity * 0.15;

      // Similitud de rating (15%)
      final ratingSimilarity = _calculateRatingSimilarity(
        movie1.voteAverage,
        movie2.voteAverage,
      );
      similarity += ratingSimilarity * 0.15;

      return similarity.clamp(0.0, 1.0);
    } catch (e) {
      _logger.error('Error calculando similitud: $e');
      return 0.0;
    }
  }

  /// Analiza el comportamiento del usuario y actualiza preferencias
  Future<UserBehaviorAnalysis> analyzeUserBehavior({
    required List<Movie> favoriteMovies,
    required List<WatchedMovie> watchedMovies,
  }) async {
    try {
      final analysis = UserBehaviorAnalysis();

      // Análisis de géneros preferidos
      analysis.genrePreferences =
          _analyzeGenrePreferences(favoriteMovies, watchedMovies);

      // Análisis temporal
      analysis.temporalPatterns = _analyzeTemporalPatterns(watchedMovies);

      // Análisis de diversidad
      analysis.diversityScore =
          _calculateDiversityScore(favoriteMovies, watchedMovies);

      // Análisis de tendencias
      analysis.trendFollowing =
          _analyzeTrendFollowing(favoriteMovies, watchedMovies);

      // Predicción de preferencias futuras
      analysis.predictedPreferences = await _predictFuturePreferences(analysis);

      _logger.info('Análisis de comportamiento completado');
      return analysis;
    } catch (e) {
      _logger.error('Error analizando comportamiento: $e');
      return UserBehaviorAnalysis();
    }
  }

  /// Explica por qué se recomendó una película específica
  String explainRecommendation(
    Recommendation recommendation, {
    required List<Movie> favoriteMovies,
    required List<WatchedMovie> watchedMovies,
  }) {
    try {
      final explanations = <String>[];

      switch (recommendation.type) {
        case RecommendationType.basedOnFavorites:
          final similarMovies =
              _findSimilarFavorites(recommendation.movieId, favoriteMovies);
          if (similarMovies.isNotEmpty) {
            explanations.add('Porque te gustó "${similarMovies.first.title}"');
          }
          break;

        case RecommendationType.basedOnGenre:
          final genres = recommendation.tags
              .where((tag) => tag.startsWith('genre:'))
              .toList();
          if (genres.isNotEmpty) {
            final genre = genres.first.replaceFirst('genre:', '');
            explanations.add('Porque disfrutas películas de $genre');
          }
          break;

        case RecommendationType.trending:
          explanations.add('Película popular que está en tendencia');
          break;

        case RecommendationType.forYou:
          explanations
              .add('Seleccionada especialmente para ti basada en tu historial');
          break;

        default:
          explanations.add('Recomendada por nuestro algoritmo inteligente');
      }

      // Agregar información adicional
      if (recommendation.score > 0.8) {
        explanations.add(
            'Alta compatibilidad (${(recommendation.score * 100).toInt()}%)');
      }

      return explanations.join(' • ');
    } catch (e) {
      _logger.error('Error explicando recomendación: $e');
      return 'Recomendada para ti';
    }
  }

  // Métodos privados para algoritmos específicos

  Future<void> _buildUserMovieMatrix(
      int userId, List<Movie> favorites, List<WatchedMovie> watched) async {
    _userMovieMatrix[userId] = {};

    // Películas favoritas tienen rating alto
    for (final movie in favorites) {
      _userMovieMatrix[userId]![movie.id] = 5.0;
    }

    // Películas vistas tienen rating basado en su puntuación
    for (final movie in watched) {
      _userMovieMatrix[userId]![movie.id] = (movie.voteAverage) / 2.0;
    }
  }

  Future<void> _buildMovieFeatureMatrix(List<Movie> movies) async {
    for (final movie in movies) {
      _movieFeatureMatrix[movie.id] = {
        'popularity': movie.popularity / 1000.0, // Normalizar
        'vote_average': movie.voteAverage / 10.0,
        'vote_count': (movie.voteCount / 10000.0).clamp(0.0, 1.0),
        'release_year': (movie.releaseDate.year - 1900) / 100.0,
      };

      // Agregar características de género
      for (int i = 0; i < movie.genreIds.length && i < 5; i++) {
        _movieFeatureMatrix[movie.id]!['genre_${movie.genreIds[i]}'] = 1.0;
      }
    }
  }

  Future<void> _trainCollaborativeFiltering() async {
    // Inicializar embeddings aleatorios
    for (final userId in _userMovieMatrix.keys) {
      _userEmbeddings[userId] = List.generate(
        _embeddingDimensions,
        (_) => _random.nextGaussian() * 0.1,
      );
    }

    for (final movieId in _movieFeatureMatrix.keys) {
      _movieEmbeddings[movieId] = List.generate(
        _embeddingDimensions,
        (_) => _random.nextGaussian() * 0.1,
      );
    }

    // Entrenamiento con descenso de gradiente
    for (int iteration = 0; iteration < _maxIterations; iteration++) {
      double totalError = 0.0;
      int samples = 0;

      for (final userId in _userMovieMatrix.keys) {
        for (final entry in _userMovieMatrix[userId]!.entries) {
          final movieId = entry.key;
          final rating = entry.value;

          if (_userEmbeddings.containsKey(userId) &&
              _movieEmbeddings.containsKey(movieId)) {
            final predicted = _dotProduct(
                _userEmbeddings[userId]!, _movieEmbeddings[movieId]!);
            final error = rating - predicted;
            totalError += error * error;
            samples++;

            // Actualizar embeddings
            _updateEmbeddings(userId, movieId, error);
          }
        }
      }

      final rmse = sqrt(totalError / samples);
      if (iteration % 20 == 0) {
        _logger.info('Iteración $iteration, RMSE: ${rmse.toStringAsFixed(4)}');
      }

      if (rmse < 0.01) break; // Convergencia
    }
  }

  Future<List<Recommendation>> _generateCollaborativeRecommendations(int userId,
      {required int limit}) async {
    final recommendations = <Recommendation>[];

    if (!_userEmbeddings.containsKey(userId)) return recommendations;

    final userEmbedding = _userEmbeddings[userId]!;
    final scores = <int, double>{};

    // Calcular puntuaciones para todas las películas
    for (final movieId in _movieEmbeddings.keys) {
      if (!_userMovieMatrix[userId]!.containsKey(movieId)) {
        scores[movieId] =
            _dotProduct(userEmbedding, _movieEmbeddings[movieId]!);
      }
    }

    // Ordenar por puntuación y tomar las mejores
    final sortedMovies = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedMovies.take(limit)) {
      recommendations.add(Recommendation(
        movieId: entry.key,
        title: 'Película ${entry.key}', // Se actualizará con datos reales
        posterPath: '',
        score: entry.value.clamp(0.0, 1.0),
        reason: 'Recomendada por filtrado colaborativo',
        type: RecommendationType.forYou,
        tags: ['collaborative_filtering'],
      ));
    }

    return recommendations;
  }

  Future<List<Recommendation>> _generateContentBasedRecommendations(
      List<Movie> favorites, List<WatchedMovie> watched,
      {required int limit}) async {
    final recommendations = <Recommendation>[];
    final allMovies = favorites +
        watched
            .map((w) => Movie(
                  id: w.id,
                  title: w.title,
                  overview: w.overview,
                  posterPath: w.posterPath,
                  backdropPath: w.backdropPath,
                  releaseDate: w.releaseDate,
                  genreIds: (w.genreIds)
                      .map((g) => int.tryParse(g) ?? 0)
                      .where((g) => g > 0)
                      .map((g) => g.toString())
                      .toList(),
                  voteAverage: w.voteAverage,
                  voteCount: w.movie.voteCount,
                  popularity: w.movie.popularity,
                  adult: false,
                  originalLanguage: w.movie.originalLanguage,
                  originalTitle: w.movie.originalTitle,
                  video: false,
                ))
            .toList();

    // Crear perfil de usuario basado en contenido
    final userProfile = _createContentProfile(allMovies);

    // Generar recomendaciones basadas en similitud de contenido
    final candidateMovies = _movieFeatureMatrix.keys
        .where((movieId) => !allMovies.any((m) => m.id == movieId))
        .toList();

    final scores = <int, double>{};
    for (final movieId in candidateMovies) {
      scores[movieId] = _calculateContentSimilarity(
          userProfile, _movieFeatureMatrix[movieId]!);
    }

    final sortedMovies = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedMovies.take(limit)) {
      recommendations.add(Recommendation(
        movieId: entry.key,
        title: 'Película ${entry.key}',
        posterPath: '',
        score: entry.value,
        reason: 'Basada en tus preferencias de contenido',
        type: RecommendationType.basedOnGenre,
        tags: ['content_based'],
      ));
    }

    return recommendations;
  }

  Future<List<Recommendation>> _generateTrendingRecommendations(
      {required int limit}) async {
    final recommendations = <Recommendation>[];

    // Simular películas trending (en implementación real, vendría de API)
    final trendingMovies = _movieFeatureMatrix.entries
        .where((entry) => entry.value['popularity']! > 0.5)
        .toList()
      ..sort(
          (a, b) => b.value['popularity']!.compareTo(a.value['popularity']!));

    for (final entry in trendingMovies.take(limit)) {
      recommendations.add(Recommendation(
        movieId: entry.key,
        title: 'Película ${entry.key}',
        posterPath: '',
        score: entry.value['popularity']!,
        reason: 'Película popular en tendencia',
        type: RecommendationType.trending,
        tags: ['trending'],
      ));
    }

    return recommendations;
  }

  Future<List<Recommendation>> _generateExplorationRecommendations(
      List<Movie> favorites, List<WatchedMovie> watched,
      {required int limit}) async {
    final recommendations = <Recommendation>[];

    // Encontrar géneros poco explorados
    final userGenres = <int>{};
    for (final movie in favorites) {
      userGenres.addAll(
          movie.genreIds.map((g) => int.tryParse(g) ?? 0).where((g) => g > 0));
    }
    for (final movie in watched) {
      userGenres.addAll(
          movie.genreIds.map((g) => int.tryParse(g) ?? 0).where((g) => g > 0));
    }

    // Buscar películas de géneros diferentes
    final explorationCandidates = _movieFeatureMatrix.entries.where((entry) {
      final movieId = entry.key;
      return !favorites.any((m) => m.id == movieId) &&
          !watched.any((m) => m.id == movieId);
    }).toList();

    // Seleccionar aleatoriamente para diversidad
    explorationCandidates.shuffle(_random);

    for (final entry in explorationCandidates.take(limit)) {
      recommendations.add(Recommendation(
        movieId: entry.key,
        title: 'Película ${entry.key}',
        posterPath: '',
        score:
            0.6 + _random.nextDouble() * 0.3, // Score aleatorio pero razonable
        reason: 'Descubre algo nuevo',
        type: RecommendationType.forYou,
        tags: ['exploration', 'diversity'],
      ));
    }

    return recommendations;
  }

  // Métodos de utilidad

  double _dotProduct(List<double> a, List<double> b) {
    double sum = 0.0;
    for (int i = 0; i < a.length && i < b.length; i++) {
      sum += a[i] * b[i];
    }
    return sum;
  }

  double _calculateCosineSimilarity(List<double> a, List<double> b) {
    final dotProduct = _dotProduct(a, b);
    final normA = sqrt(a.map((x) => x * x).reduce((a, b) => a + b));
    final normB = sqrt(b.map((x) => x * x).reduce((a, b) => a + b));

    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (normA * normB);
  }

  double _calculateGenreSimilarity(List<int> genres1, List<int> genres2) {
    if (genres1.isEmpty || genres2.isEmpty) return 0.0;

    final set1 = genres1.toSet();
    final set2 = genres2.toSet();
    final intersection = set1.intersection(set2).length;
    final union = set1.union(set2).length;

    return intersection / union; // Jaccard similarity
  }

  double _calculatePopularitySimilarity(double pop1, double pop2) {
    final diff = (pop1 - pop2).abs();
    final maxPop = max(pop1, pop2);
    if (maxPop == 0) return 1.0;
    return 1.0 - (diff / maxPop);
  }

  double _calculateRatingSimilarity(double rating1, double rating2) {
    final diff = (rating1 - rating2).abs();
    return 1.0 - (diff / 10.0); // Ratings están en escala 0-10
  }

  void _updateEmbeddings(int userId, int movieId, double error) {
    final userEmb = _userEmbeddings[userId]!;
    final movieEmb = _movieEmbeddings[movieId]!;

    for (int i = 0; i < _embeddingDimensions; i++) {
      final userFeature = userEmb[i];
      final movieFeature = movieEmb[i];

      userEmb[i] += _learningRate *
          (error * movieFeature - _regularization * userFeature);
      movieEmb[i] += _learningRate *
          (error * userFeature - _regularization * movieFeature);
    }
  }

  Map<String, double> _createContentProfile(List<Movie> movies) {
    final profile = <String, double>{};

    for (final movie in movies) {
      final features = _movieFeatureMatrix[movie.id];
      if (features != null) {
        for (final entry in features.entries) {
          profile[entry.key] = (profile[entry.key] ?? 0.0) + entry.value;
        }
      }
    }

    // Normalizar por número de películas
    final movieCount = movies.length.toDouble();
    for (final key in profile.keys) {
      profile[key] = profile[key]! / movieCount;
    }

    return profile;
  }

  double _calculateContentSimilarity(
      Map<String, double> profile1, Map<String, double> profile2) {
    double similarity = 0.0;
    int commonFeatures = 0;

    for (final key in profile1.keys) {
      if (profile2.containsKey(key)) {
        similarity += profile1[key]! * profile2[key]!;
        commonFeatures++;
      }
    }

    return commonFeatures > 0 ? similarity / commonFeatures : 0.0;
  }

  List<Recommendation> _removeDuplicatesAndRerank(
      List<Recommendation> recommendations) {
    final seen = <int>{};
    final unique = <Recommendation>[];

    // Ordenar por score descendente
    recommendations.sort((a, b) => b.score.compareTo(a.score));

    for (final rec in recommendations) {
      if (!seen.contains(rec.movieId)) {
        seen.add(rec.movieId);
        unique.add(rec);
      }
    }

    return unique;
  }

  Map<String, double> _analyzeGenrePreferences(
      List<Movie> favorites, List<WatchedMovie> watched) {
    final genreCount = <String, int>{};
    final genreRating = <String, double>{};

    // Analizar favoritos (peso mayor)
    for (final movie in favorites) {
      for (final genreId in movie.genreIds) {
        final genreKey = 'genre_$genreId';
        genreCount[genreKey] = (genreCount[genreKey] ?? 0) + 2; // Peso doble
        genreRating[genreKey] =
            (genreRating[genreKey] ?? 0.0) + movie.voteAverage * 2;
      }
    }

    // Analizar películas vistas
    for (final movie in watched) {
      for (final genreId in movie.movie.genreIds ?? []) {
        final genreKey = 'genre_$genreId';
        genreCount[genreKey] = (genreCount[genreKey] ?? 0) + 1;
        genreRating[genreKey] =
            (genreRating[genreKey] ?? 0.0) + (movie.movie.voteAverage ?? 5.0);
      }
    }

    // Calcular preferencias normalizadas
    final preferences = <String, double>{};
    for (final genre in genreCount.keys) {
      final count = genreCount[genre]!;
      final avgRating = genreRating[genre]! / count;
      preferences[genre] = (count * avgRating) / 100.0; // Normalizar
    }

    return preferences;
  }

  Map<String, dynamic> _analyzeTemporalPatterns(List<WatchedMovie> watched) {
    final patterns = <String, dynamic>{};

    if (watched.isEmpty) return patterns;

    // Analizar frecuencia de visualización
    final watchDates = watched
        .where((m) => m.watchedDate != null)
        .map((m) => m.watchedDate)
        .toList()
      ..sort();

    if (watchDates.isNotEmpty) {
      final daysBetween = <int>[];
      for (int i = 1; i < watchDates.length; i++) {
        daysBetween.add(watchDates[i].difference(watchDates[i - 1]).inDays);
      }

      if (daysBetween.isNotEmpty) {
        patterns['average_days_between_movies'] =
            daysBetween.reduce((a, b) => a + b) / daysBetween.length;
        patterns['watching_consistency'] = 1.0 /
            (daysBetween.map((d) => d * d).reduce((a, b) => a + b) /
                daysBetween.length);
      }
    }

    return patterns;
  }

  double _calculateDiversityScore(
      List<Movie> favorites, List<WatchedMovie> watched) {
    final allGenres = <int>{};

    for (final movie in favorites) {
      allGenres.addAll(
          movie.genreIds.map((g) => int.tryParse(g) ?? 0).where((g) => g > 0));
    }
    for (final movie in watched) {
      allGenres.addAll((movie.genreIds ?? [])
          .map((g) => int.tryParse(g) ?? 0)
          .where((g) => g > 0));
    }

    final totalMovies = favorites.length + watched.length;
    if (totalMovies == 0) return 0.0;

    // Diversidad basada en número de géneros únicos vs total de películas
    return (allGenres.length / totalMovies).clamp(0.0, 1.0);
  }

  double _analyzeTrendFollowing(
      List<Movie> favorites, List<WatchedMovie> watched) {
    // Analizar qué tan bien sigue el usuario las tendencias
    // Basado en popularidad promedio de las películas

    double totalPopularity = 0.0;
    int count = 0;

    for (final movie in favorites) {
      totalPopularity += movie.popularity;
      count++;
    }

    for (final movie in watched) {
      totalPopularity += movie.movie.popularity ?? 0.0;
      count++;
    }

    if (count == 0) return 0.0;

    final avgPopularity = totalPopularity / count;
    return (avgPopularity / 1000.0).clamp(0.0, 1.0); // Normalizar
  }

  Future<Map<String, double>> _predictFuturePreferences(
      UserBehaviorAnalysis analysis) async {
    final predictions = <String, double>{};

    // Predicciones simples basadas en tendencias actuales
    for (final entry in analysis.genrePreferences.entries) {
      // Proyectar preferencias futuras con un factor de crecimiento
      final currentPref = entry.value;
      final growthFactor = 1.0 + (analysis.diversityScore * 0.1);
      predictions[entry.key] = (currentPref * growthFactor).clamp(0.0, 1.0);
    }

    return predictions;
  }

  List<Movie> _findSimilarFavorites(int movieId, List<Movie> favorites) {
    // Encontrar películas favoritas similares a la recomendada
    final similar = <Movie>[];

    if (!_movieEmbeddings.containsKey(movieId)) return similar;

    final targetEmbedding = _movieEmbeddings[movieId]!;

    for (final movie in favorites) {
      if (_movieEmbeddings.containsKey(movie.id)) {
        final similarity = _calculateCosineSimilarity(
            targetEmbedding, _movieEmbeddings[movie.id]!);
        if (similarity > 0.7) {
          similar.add(movie);
        }
      }
    }

    return similar;
  }
}

/// Clase para análisis de comportamiento del usuario
class UserBehaviorAnalysis {
  Map<String, double> genrePreferences = {};
  Map<String, dynamic> temporalPatterns = {};
  double diversityScore = 0.0;
  double trendFollowing = 0.0;
  Map<String, double> predictedPreferences = {};
}

/// Extensión para generar números aleatorios gaussianos
extension RandomGaussian on Random {
  double nextGaussian() {
    double u1 = nextDouble();
    double u2 = nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  }
}
