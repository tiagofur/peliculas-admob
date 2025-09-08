import 'dart:math';

import '../../domain/entities/movie.dart';
import '../../domain/entities/watched_movie.dart';
import '../logging/logger_factory.dart';

/// Analizador avanzado de comportamiento del usuario
class UserBehaviorAnalyzer {
  UserBehaviorAnalyzer._();
  static UserBehaviorAnalyzer? _instance;
  static UserBehaviorAnalyzer get instance =>
      _instance ??= UserBehaviorAnalyzer._();

  final _logger = LoggerFactory.logger;

  /// Analiza patrones de visualización del usuario
  Future<ViewingPatterns> analyzeViewingPatterns(
      List<WatchedMovie> watchedMovies) async {
    try {
      final patterns = ViewingPatterns();

      if (watchedMovies.isEmpty) return patterns;

      // Análisis temporal
      patterns.temporalAnalysis = await _analyzeTemporalPatterns(watchedMovies);

      // Análisis de géneros
      patterns.genreAnalysis = await _analyzeGenrePatterns(watchedMovies);

      // Análisis de calidad
      patterns.qualityAnalysis = await _analyzeQualityPatterns(watchedMovies);

      // Análisis de duración
      patterns.sessionAnalysis = await _analyzeSessionPatterns(watchedMovies);

      // Análisis de diversidad
      patterns.diversityAnalysis =
          await _analyzeDiversityPatterns(watchedMovies);

      _logger.info('Análisis de patrones de visualización completado');
      return patterns;
    } catch (e) {
      _logger.error('Error analizando patrones: $e');
      return ViewingPatterns();
    }
  }

  /// Predice el próximo tipo de película que el usuario podría ver
  Future<MoviePrediction> predictNextMovie({
    required List<Movie> favoriteMovies,
    required List<WatchedMovie> watchedMovies,
  }) async {
    try {
      final prediction = MoviePrediction();

      // Análisis de secuencias
      final sequences = await _analyzeMovieSequences(watchedMovies);
      prediction.sequenceBasedPrediction = sequences;

      // Análisis de ciclos temporales
      final cycles = await _analyzeTemporalCycles(watchedMovies);
      prediction.temporalCyclePrediction = cycles;

      // Análisis de mood
      final mood = await _analyzeMoodPatterns(favoriteMovies, watchedMovies);
      prediction.moodBasedPrediction = mood;

      // Predicción híbrida
      prediction.hybridPrediction =
          await _generateHybridPrediction(sequences, cycles, mood);

      _logger.info('Predicción de próxima película generada');
      return prediction;
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
      final engagement = EngagementScore();

      // Frecuencia de uso
      engagement.frequency = await _calculateFrequencyScore(watchedMovies);

      // Diversidad de contenido
      engagement.diversity =
          await _calculateDiversityScore(favoriteMovies, watchedMovies);

      // Profundidad de interacción
      engagement.depth =
          await _calculateDepthScore(favoriteMovies, watchedMovies);

      // Consistencia temporal
      engagement.consistency = await _calculateConsistencyScore(watchedMovies);

      // Score total ponderado
      engagement.totalScore = (engagement.frequency * 0.3 +
              engagement.diversity * 0.25 +
              engagement.depth * 0.25 +
              engagement.consistency * 0.2)
          .clamp(0.0, 1.0);

      // Clasificación del usuario
      engagement.userType = _classifyUserType(engagement);

      _logger.info(
          'Score de engagement calculado: ${engagement.totalScore.toStringAsFixed(2)}');
      return engagement;
    } catch (e) {
      _logger.error('Error calculando engagement: $e');
      return EngagementScore();
    }
  }

  /// Detecta anomalías en el comportamiento del usuario
  Future<List<BehaviorAnomaly>> detectAnomalies(
      List<WatchedMovie> watchedMovies) async {
    try {
      final anomalies = <BehaviorAnomaly>[];

      // Detectar picos de actividad inusuales
      final activityAnomalies = await _detectActivityAnomalies(watchedMovies);
      anomalies.addAll(activityAnomalies);

      // Detectar cambios drásticos en preferencias
      final preferenceAnomalies =
          await _detectPreferenceAnomalies(watchedMovies);
      anomalies.addAll(preferenceAnomalies);

      // Detectar patrones de abandono
      final abandonmentAnomalies =
          await _detectAbandonmentPatterns(watchedMovies);
      anomalies.addAll(abandonmentAnomalies);

      _logger
          .info('Detectadas ${anomalies.length} anomalías de comportamiento');
      return anomalies;
    } catch (e) {
      _logger.error('Error detectando anomalías: $e');
      return [];
    }
  }

  /// Genera insights personalizados para el usuario
  Future<List<UserInsight>> generatePersonalizedInsights({
    required List<Movie> favoriteMovies,
    required List<WatchedMovie> watchedMovies,
  }) async {
    try {
      final insights = <UserInsight>[];

      // Insight sobre géneros favoritos
      final genreInsight =
          await _generateGenreInsight(favoriteMovies, watchedMovies);
      if (genreInsight != null) insights.add(genreInsight);

      // Insight sobre patrones temporales
      final temporalInsight = await _generateTemporalInsight(watchedMovies);
      if (temporalInsight != null) insights.add(temporalInsight);

      // Insight sobre diversidad
      final diversityInsight =
          await _generateDiversityInsight(favoriteMovies, watchedMovies);
      if (diversityInsight != null) insights.add(diversityInsight);

      // Insight sobre calidad
      final qualityInsight =
          await _generateQualityInsight(favoriteMovies, watchedMovies);
      if (qualityInsight != null) insights.add(qualityInsight);

      // Insight sobre tendencias
      final trendInsight =
          await _generateTrendInsight(favoriteMovies, watchedMovies);
      if (trendInsight != null) insights.add(trendInsight);

      _logger.info('Generados ${insights.length} insights personalizados');
      return insights;
    } catch (e) {
      _logger.error('Error generando insights: $e');
      return [];
    }
  }

  // Métodos privados de análisis

  Future<TemporalAnalysis> _analyzeTemporalPatterns(
      List<WatchedMovie> watchedMovies) async {
    final analysis = TemporalAnalysis();

    final watchDates = watchedMovies.map((m) => m.watchedDate).toList()..sort();

    if (watchDates.isEmpty) return analysis;

    // Análisis de días de la semana
    final weekdayCount = <int, int>{};
    for (final date in watchDates) {
      weekdayCount[date.weekday] = (weekdayCount[date.weekday] ?? 0) + 1;
    }

    analysis.preferredWeekdays = weekdayCount.entries
        .where((e) => e.value > watchDates.length * 0.2)
        .map((e) => e.key)
        .toList();

    // Análisis de horas del día
    final hourCount = <int, int>{};
    for (final date in watchDates) {
      hourCount[date.hour] = (hourCount[date.hour] ?? 0) + 1;
    }

    analysis.preferredHours = hourCount.entries
        .where((e) => e.value > watchDates.length * 0.15)
        .map((e) => e.key)
        .toList();

    // Análisis de frecuencia
    if (watchDates.length > 1) {
      final intervals = <int>[];
      for (int i = 1; i < watchDates.length; i++) {
        intervals.add(watchDates[i].difference(watchDates[i - 1]).inDays);
      }

      analysis.averageInterval =
          intervals.reduce((a, b) => a + b) / intervals.length;
      analysis.watchingFrequency =
          7.0 / analysis.averageInterval; // películas por semana
    }

    return analysis;
  }

  Future<GenreAnalysis> _analyzeGenrePatterns(
      List<WatchedMovie> watchedMovies) async {
    final analysis = GenreAnalysis();

    final genreCount = <String, int>{};
    final genreRatings = <String, List<double>>{};

    for (final movie in watchedMovies) {
      for (final genreId in movie.genreIds) {
        genreCount[genreId] = (genreCount[genreId] ?? 0) + 1;
        genreRatings[genreId] = (genreRatings[genreId] ?? [])
          ..add(movie.voteAverage);
      }
    }

    // Géneros más vistos
    analysis.topGenres = genreCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Géneros mejor valorados
    final genreAvgRatings = <String, double>{};
    for (final entry in genreRatings.entries) {
      genreAvgRatings[entry.key] =
          entry.value.reduce((a, b) => a + b) / entry.value.length;
    }

    analysis.bestRatedGenres = genreAvgRatings.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Diversidad de géneros
    analysis.genreDiversity = genreCount.length / max(1, watchedMovies.length);

    return analysis;
  }

  Future<QualityAnalysis> _analyzeQualityPatterns(
      List<WatchedMovie> watchedMovies) async {
    final analysis = QualityAnalysis();

    if (watchedMovies.isEmpty) return analysis;

    final ratings = watchedMovies.map((m) => m.voteAverage).toList();

    // Estadísticas básicas
    analysis.averageRating = ratings.reduce((a, b) => a + b) / ratings.length;
    analysis.minRating = ratings.reduce(min);
    analysis.maxRating = ratings.reduce(max);

    // Distribución de calidad
    final highQuality = ratings.where((r) => r >= 7.0).length;
    final mediumQuality = ratings.where((r) => r >= 5.0 && r < 7.0).length;
    final lowQuality = ratings.where((r) => r < 5.0).length;

    analysis.qualityDistribution = {
      'high': highQuality / ratings.length,
      'medium': mediumQuality / ratings.length,
      'low': lowQuality / ratings.length,
    };

    // Tendencia de calidad
    if (ratings.length > 5) {
      final recentRatings = ratings.skip(ratings.length - 5).toList();
      final oldRatings = ratings.take(5).toList();

      final recentAvg =
          recentRatings.reduce((a, b) => a + b) / recentRatings.length;
      final oldAvg = oldRatings.reduce((a, b) => a + b) / oldRatings.length;

      analysis.qualityTrend = recentAvg - oldAvg;
    }

    return analysis;
  }

  Future<SessionAnalysis> _analyzeSessionPatterns(
      List<WatchedMovie> watchedMovies) async {
    final analysis = SessionAnalysis();

    final watchDates = watchedMovies.map((m) => m.watchedDate).toList()..sort();

    if (watchDates.isEmpty) return analysis;

    // Detectar sesiones (películas vistas en el mismo día)
    final sessions = <List<DateTime>>[];
    List<DateTime> currentSession = [watchDates.first];

    for (int i = 1; i < watchDates.length; i++) {
      final current = watchDates[i];
      final previous = watchDates[i - 1];

      if (current.difference(previous).inHours <= 6) {
        currentSession.add(current);
      } else {
        sessions.add(List.from(currentSession));
        currentSession = [current];
      }
    }
    sessions.add(currentSession);

    // Análisis de sesiones
    analysis.totalSessions = sessions.length;
    analysis.averageMoviesPerSession = watchedMovies.length / sessions.length;

    final sessionLengths = sessions.map((s) => s.length).toList();
    analysis.maxMoviesInSession = sessionLengths.reduce(max);

    // Patrones de binge-watching
    final bingeSessions = sessions.where((s) => s.length >= 3).length;
    analysis.bingeWatchingFrequency = bingeSessions / sessions.length;

    return analysis;
  }

  Future<DiversityAnalysis> _analyzeDiversityPatterns(
      List<WatchedMovie> watchedMovies) async {
    final analysis = DiversityAnalysis();

    if (watchedMovies.isEmpty) return analysis;

    // Diversidad de géneros
    final allGenres = <int>{};
    for (final movie in watchedMovies) {
      allGenres.addAll(movie.genreIds
          .map((g) => int.tryParse(g) ?? 0)
          .where((g) => g > 0));
    }
    analysis.genreDiversity = allGenres.length / max(1, watchedMovies.length);

    // Diversidad de años
    final years = watchedMovies
        .map((m) => m.releaseDate.year)
        .toSet();
    analysis.yearDiversity = years.length / max(1, watchedMovies.length);

    // Diversidad de idiomas
    final languages =
        watchedMovies.map((m) => m.movie.originalLanguage).toSet();
    analysis.languageDiversity =
        languages.length / max(1, watchedMovies.length);

    // Score de diversidad total
    analysis.totalDiversityScore = (analysis.genreDiversity * 0.5 +
            analysis.yearDiversity * 0.3 +
            analysis.languageDiversity * 0.2)
        .clamp(0.0, 1.0);

    return analysis;
  }

  Future<Map<String, dynamic>> _analyzeMovieSequences(
      List<WatchedMovie> watchedMovies) async {
    final sequences = <String, dynamic>{};

    if (watchedMovies.length < 2) return sequences;

    // Analizar secuencias de géneros
    final genreSequences = <String>[];
    for (int i = 1; i < watchedMovies.length; i++) {
      final prevGenres = watchedMovies[i - 1].genreIds;
      final currGenres = watchedMovies[i].genreIds;

      for (final prevGenre in prevGenres) {
        for (final currGenre in currGenres) {
          genreSequences.add('$prevGenre->$currGenre');
        }
      }
    }

    // Encontrar secuencias más comunes
    final sequenceCount = <String, int>{};
    for (final seq in genreSequences) {
      sequenceCount[seq] = (sequenceCount[seq] ?? 0) + 1;
    }

    sequences['common_genre_sequences'] = sequenceCount.entries
        .where((e) => e.value > 1)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sequences;
  }

  Future<Map<String, dynamic>> _analyzeTemporalCycles(
      List<WatchedMovie> watchedMovies) async {
    final cycles = <String, dynamic>{};

    final watchDates = watchedMovies
        .where((m) => true) // All watchedDate values are non-null
        .map((m) => m.watchedDate)
        .toList()
      ..sort();

    if (watchDates.isEmpty) return cycles;

    // Análisis de ciclos semanales
    final weeklyPattern = <int, int>{};
    for (final date in watchDates) {
      weeklyPattern[date.weekday] = (weeklyPattern[date.weekday] ?? 0) + 1;
    }

    cycles['weekly_pattern'] = weeklyPattern;

    // Análisis de ciclos mensuales
    final monthlyPattern = <int, int>{};
    for (final date in watchDates) {
      monthlyPattern[date.month] = (monthlyPattern[date.month] ?? 0) + 1;
    }

    cycles['monthly_pattern'] = monthlyPattern;

    return cycles;
  }

  Future<Map<String, dynamic>> _analyzeMoodPatterns(
      List<Movie> favorites, List<WatchedMovie> watched) async {
    final moodPatterns = <String, dynamic>{};

    // Análisis simple de mood basado en géneros
    final moodGenres = {
      'happy': [35, 10751, 16], // Comedy, Family, Animation
      'sad': [18, 10749], // Drama, Romance
      'excited': [28, 12, 878], // Action, Adventure, Sci-Fi
      'relaxed': [99, 36], // Documentary, History
      'scared': [27, 53], // Horror, Thriller
    };

    final moodCounts = <String, int>{};

    // Analizar favoritos
    for (final movie in favorites) {
      for (final entry in moodGenres.entries) {
        if (movie.genreIds
            .any((id) => entry.value.contains(int.tryParse(id) ?? 0))) {
          moodCounts[entry.key] =
              (moodCounts[entry.key] ?? 0) + 2; // Peso doble
        }
      }
    }

    // Analizar películas vistas
    for (final movie in watched) {
      for (final entry in moodGenres.entries) {
        if (movie.genreIds
            .any((id) => entry.value.contains(int.tryParse(id) ?? 0))) {
          moodCounts[entry.key] = (moodCounts[entry.key] ?? 0) + 1;
        }
      }
    }

    moodPatterns['mood_preferences'] = moodCounts;

    // Determinar mood dominante
    if (moodCounts.isNotEmpty) {
      final dominantMood =
          moodCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
      moodPatterns['dominant_mood'] = dominantMood.key;
    }

    return moodPatterns;
  }

  Future<Map<String, dynamic>> _generateHybridPrediction(
    Map<String, dynamic> sequences,
    Map<String, dynamic> cycles,
    Map<String, dynamic> mood,
  ) async {
    final prediction = <String, dynamic>{};

    // Combinar predicciones de diferentes fuentes
    final predictions = <String>[];

    // Predicción basada en secuencias
    if (sequences.containsKey('common_genre_sequences')) {
      final commonSeqs = sequences['common_genre_sequences'] as List;
      if (commonSeqs.isNotEmpty) {
        predictions.add('sequence_based');
      }
    }

    // Predicción basada en ciclos temporales
    final now = DateTime.now();
    if (cycles.containsKey('weekly_pattern')) {
      final weeklyPattern = cycles['weekly_pattern'] as Map<int, int>;
      final todayCount = weeklyPattern[now.weekday] ?? 0;
      if (todayCount > 0) {
        predictions.add('temporal_cycle');
      }
    }

    // Predicción basada en mood
    if (mood.containsKey('dominant_mood')) {
      predictions.add('mood_based');
    }

    prediction['prediction_sources'] = predictions;
    prediction['confidence'] = predictions.length / 3.0; // Normalizar

    return prediction;
  }

  // Métodos de cálculo de scores

  Future<double> _calculateFrequencyScore(
      List<WatchedMovie> watchedMovies) async {
    if (watchedMovies.isEmpty) return 0.0;

    final watchDates = watchedMovies
        .where((m) => true) // All watchedDate values are non-null
        .map((m) => m.watchedDate)
        .toList()
      ..sort();

    if (watchDates.length < 2) return 0.5;

    final daysSinceFirst = DateTime.now().difference(watchDates.first).inDays;
    final moviesPerDay = watchedMovies.length / max(1, daysSinceFirst);

    // Normalizar: 1 película por día = score 1.0
    return (moviesPerDay * 7)
        .clamp(0.0, 1.0); // Convertir a películas por semana
  }

  Future<double> _calculateDiversityScore(
      List<Movie> favorites, List<WatchedMovie> watched) async {
    final allGenres = <int>{};

    for (final movie in favorites) {
      allGenres.addAll(
          movie.genreIds.map((g) => int.tryParse(g) ?? 0).where((g) => g > 0));
    }
    for (final movie in watched) {
      allGenres.addAll(movie.genreIds
          .map((g) => int.tryParse(g) ?? 0)
          .where((g) => g > 0));
    }

    final totalMovies = favorites.length + watched.length;
    if (totalMovies == 0) return 0.0;

    return (allGenres.length / totalMovies).clamp(0.0, 1.0);
  }

  Future<double> _calculateDepthScore(
      List<Movie> favorites, List<WatchedMovie> watched) async {
    // Profundidad basada en número de favoritos vs total visto
    final totalMovies = favorites.length + watched.length;
    if (totalMovies == 0) return 0.0;

    final favoriteRatio = favorites.length / totalMovies;

    // Bonus por diversidad de géneros en favoritos
    final favoriteGenres = <int>{};
    for (final movie in favorites) {
      favoriteGenres.addAll(
          movie.genreIds.map((g) => int.tryParse(g) ?? 0).where((g) => g > 0));
    }

    final genreDiversityBonus =
        favoriteGenres.length / max(1, favorites.length) * 0.3;

    return (favoriteRatio + genreDiversityBonus).clamp(0.0, 1.0);
  }

  Future<double> _calculateConsistencyScore(
      List<WatchedMovie> watchedMovies) async {
    final watchDates = watchedMovies
        .where((m) => true) // All watchedDate values are non-null
        .map((m) => m.watchedDate)
        .toList()
      ..sort();

    if (watchDates.length < 3) return 0.5;

    // Calcular varianza en intervalos entre visualizaciones
    final intervals = <int>[];
    for (int i = 1; i < watchDates.length; i++) {
      intervals.add(watchDates[i].difference(watchDates[i - 1]).inDays);
    }

    final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
    final variance =
        intervals.map((i) => pow(i - avgInterval, 2)).reduce((a, b) => a + b) /
            intervals.length;

    // Menor varianza = mayor consistencia
    return (1.0 / (1.0 + variance / 100)).clamp(0.0, 1.0);
  }

  UserType _classifyUserType(EngagementScore engagement) {
    if (engagement.totalScore >= 0.8) {
      return UserType.powerUser;
    } else if (engagement.totalScore >= 0.6) {
      return UserType.regularUser;
    } else if (engagement.totalScore >= 0.4) {
      return UserType.casualUser;
    } else {
      return UserType.newUser;
    }
  }

  // Métodos de detección de anomalías

  Future<List<BehaviorAnomaly>> _detectActivityAnomalies(
      List<WatchedMovie> watchedMovies) async {
    final anomalies = <BehaviorAnomaly>[];

    final watchDates = watchedMovies
        .where((m) => true) // All watchedDate values are non-null
        .map((m) => m.watchedDate)
        .toList()
      ..sort();

    if (watchDates.length < 5) return anomalies;

    // Detectar picos de actividad
    final dailyCounts = <String, int>{};
    for (final date in watchDates) {
      final dayKey = '${date.year}-${date.month}-${date.day}';
      dailyCounts[dayKey] = (dailyCounts[dayKey] ?? 0) + 1;
    }

    final avgDaily =
        dailyCounts.values.reduce((a, b) => a + b) / dailyCounts.length;

    for (final entry in dailyCounts.entries) {
      if (entry.value > avgDaily * 3) {
        // 3x el promedio
        anomalies.add(BehaviorAnomaly(
          type: AnomalyType.unusualActivity,
          description:
              'Pico de actividad inusual: ${entry.value} películas en un día',
          severity: entry.value > avgDaily * 5
              ? AnomalySeverity.high
              : AnomalySeverity.medium,
          detectedAt: DateTime.now(),
        ));
      }
    }

    return anomalies;
  }

  Future<List<BehaviorAnomaly>> _detectPreferenceAnomalies(
      List<WatchedMovie> watchedMovies) async {
    final anomalies = <BehaviorAnomaly>[];

    if (watchedMovies.length < 10) return anomalies;

    // Dividir en dos mitades para comparar
    final firstHalf = watchedMovies.take(watchedMovies.length ~/ 2).toList();
    final secondHalf = watchedMovies.skip(watchedMovies.length ~/ 2).toList();

    // Analizar cambios en géneros
    final firstGenres = <int, int>{};
    final secondGenres = <int, int>{};

    for (final movie in firstHalf) {
      for (final genreStr in movie.genreIds) {
        final genre = int.tryParse(genreStr) ?? 0;
        if (genre > 0) {
          firstGenres[genre] = (firstGenres[genre] ?? 0) + 1;
        }
      }
    }

    for (final movie in secondHalf) {
      for (final genreStr in movie.genreIds) {
        final genre = int.tryParse(genreStr) ?? 0;
        if (genre > 0) {
          secondGenres[genre] = (secondGenres[genre] ?? 0) + 1;
        }
      }
    }

    // Detectar cambios drásticos
    for (final genre in firstGenres.keys) {
      final firstRatio = firstGenres[genre]! / firstHalf.length;
      final secondRatio = (secondGenres[genre] ?? 0) / secondHalf.length;

      if ((firstRatio - secondRatio).abs() > 0.3) {
        anomalies.add(BehaviorAnomaly(
          type: AnomalyType.preferenceShift,
          description: 'Cambio drástico en preferencia de género $genre',
          severity: AnomalySeverity.medium,
          detectedAt: DateTime.now(),
        ));
      }
    }

    return anomalies;
  }

  Future<List<BehaviorAnomaly>> _detectAbandonmentPatterns(
      List<WatchedMovie> watchedMovies) async {
    final anomalies = <BehaviorAnomaly>[];

    final watchDates = watchedMovies
        .where((m) => true) // All watchedDate values are non-null
        .map((m) => m.watchedDate)
        .toList()
      ..sort();

    if (watchDates.isEmpty) return anomalies;

    // Detectar períodos largos sin actividad
    final now = DateTime.now();
    final daysSinceLastWatch = now.difference(watchDates.last).inDays;

    if (daysSinceLastWatch > 30) {
      anomalies.add(BehaviorAnomaly(
        type: AnomalyType.inactivity,
        description: 'Usuario inactivo por $daysSinceLastWatch días',
        severity: daysSinceLastWatch > 60
            ? AnomalySeverity.high
            : AnomalySeverity.medium,
        detectedAt: DateTime.now(),
      ));
    }

    return anomalies;
  }

  // Métodos de generación de insights

  Future<UserInsight?> _generateGenreInsight(
      List<Movie> favorites, List<WatchedMovie> watched) async {
    final genreCount = <int, int>{};

    for (final movie in favorites) {
      for (final genre in movie.genreIds) {
        final genreId = int.tryParse(genre) ?? 0;
        if (genreId > 0) {
          genreCount[genreId] = (genreCount[genreId] ?? 0) + 2; // Peso doble
        }
      }
    }

    for (final movie in watched) {
      for (final genre in movie.genreIds) {
        final genreId = int.tryParse(genre) ?? 0;
        if (genreId > 0) {
          genreCount[genreId] = (genreCount[genreId] ?? 0) + 1;
        }
      }
    }

    if (genreCount.isEmpty) return null;

    final topGenre =
        genreCount.entries.reduce((a, b) => a.value > b.value ? a : b);
    final totalMovies = favorites.length + watched.length;
    final percentage = (topGenre.value / totalMovies * 100).round();

    return UserInsight(
      type: InsightType.genrePreference,
      title: 'Tu género favorito',
      description:
          'El $percentage% de tus películas son del género ${topGenre.key}',
      actionable: true,
      recommendation:
          'Explora más películas de este género o prueba géneros similares',
    );
  }

  Future<UserInsight?> _generateTemporalInsight(
      List<WatchedMovie> watched) async {
    final watchDates = watched
        .where((m) => true) // All watchedDate values are non-null
        .map((m) => m.watchedDate)
        .toList();

    if (watchDates.isEmpty) return null;

    final hourCount = <int, int>{};
    for (final date in watchDates) {
      hourCount[date.hour] = (hourCount[date.hour] ?? 0) + 1;
    }

    final peakHour =
        hourCount.entries.reduce((a, b) => a.value > b.value ? a : b);

    String timeDescription;
    if (peakHour.key >= 6 && peakHour.key < 12) {
      timeDescription = 'mañana';
    } else if (peakHour.key >= 12 && peakHour.key < 18) {
      timeDescription = 'tarde';
    } else {
      timeDescription = 'noche';
    }

    return UserInsight(
      type: InsightType.temporalPattern,
      title: 'Tu horario preferido',
      description:
          'Prefieres ver películas por la $timeDescription (${peakHour.key}:00)',
      actionable: false,
      recommendation:
          'Considera configurar recordatorios en tu horario preferido',
    );
  }

  Future<UserInsight?> _generateDiversityInsight(
      List<Movie> favorites, List<WatchedMovie> watched) async {
    final allGenres = <int>{};

    for (final movie in favorites) {
      allGenres.addAll(
          movie.genreIds.map((g) => int.tryParse(g) ?? 0).where((g) => g > 0));
    }
    for (final movie in watched) {
      allGenres.addAll(movie.genreIds
          .map((g) => int.tryParse(g) ?? 0)
          .where((g) => g > 0));
    }

    final totalMovies = favorites.length + watched.length;
    if (totalMovies == 0) return null;

    final diversityScore = allGenres.length / totalMovies;

    String diversityLevel;
    String recommendation;

    if (diversityScore > 0.7) {
      diversityLevel = 'muy diverso';
      recommendation =
          'Sigue explorando nuevos géneros para mantener tu diversidad';
    } else if (diversityScore > 0.4) {
      diversityLevel = 'moderadamente diverso';
      recommendation =
          'Prueba algunos géneros nuevos para ampliar tus horizontes';
    } else {
      diversityLevel = 'poco diverso';
      recommendation = 'Considera explorar géneros completamente nuevos';
    }

    return UserInsight(
      type: InsightType.diversity,
      title: 'Diversidad de contenido',
      description: 'Tu gusto cinematográfico es $diversityLevel',
      actionable: true,
      recommendation: recommendation,
    );
  }

  Future<UserInsight?> _generateQualityInsight(
      List<Movie> favorites, List<WatchedMovie> watched) async {
    final allRatings = <double>[];

    for (final movie in favorites) {
      allRatings.add(movie.voteAverage);
    }
    for (final movie in watched) {
      allRatings.add(movie.voteAverage);
    }

    if (allRatings.isEmpty) return null;

    final avgRating = allRatings.reduce((a, b) => a + b) / allRatings.length;

    String qualityLevel;
    if (avgRating >= 7.5) {
      qualityLevel = 'excelente';
    } else if (avgRating >= 6.5) {
      qualityLevel = 'buena';
    } else {
      qualityLevel = 'variada';
    }

    return UserInsight(
      type: InsightType.qualityPreference,
      title: 'Estándar de calidad',
      description:
          'Prefieres películas de calidad $qualityLevel (${avgRating.toStringAsFixed(1)}/10)',
      actionable: false,
      recommendation: 'Continúa siguiendo tus estándares de calidad',
    );
  }

  Future<UserInsight?> _generateTrendInsight(
      List<Movie> favorites, List<WatchedMovie> watched) async {
    final allMovies = favorites +
        watched
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
            .toList();

    if (allMovies.isEmpty) return null;

    final avgPopularity =
        allMovies.map((m) => m.popularity).reduce((a, b) => a + b) /
            allMovies.length;

    String trendLevel;
    if (avgPopularity > 500) {
      trendLevel = 'muy popular';
    } else if (avgPopularity > 200) {
      trendLevel = 'moderadamente popular';
    } else {
      trendLevel = 'de nicho';
    }

    return UserInsight(
      type: InsightType.trendFollowing,
      title: 'Seguimiento de tendencias',
      description: 'Prefieres contenido $trendLevel',
      actionable: true,
      recommendation: trendLevel == 'de nicho'
          ? 'Considera explorar algunas películas populares'
          : 'Prueba algunas joyas ocultas menos conocidas',
    );
  }
}

// Clases de datos para análisis

class ViewingPatterns {
  TemporalAnalysis temporalAnalysis = TemporalAnalysis();
  GenreAnalysis genreAnalysis = GenreAnalysis();
  QualityAnalysis qualityAnalysis = QualityAnalysis();
  SessionAnalysis sessionAnalysis = SessionAnalysis();
  DiversityAnalysis diversityAnalysis = DiversityAnalysis();
}

class TemporalAnalysis {
  List<int> preferredWeekdays = [];
  List<int> preferredHours = [];
  double averageInterval = 0.0;
  double watchingFrequency = 0.0;
}

class GenreAnalysis {
  List<MapEntry<String, int>> topGenres = [];
  List<MapEntry<String, double>> bestRatedGenres = [];
  double genreDiversity = 0.0;
}

class QualityAnalysis {
  double averageRating = 0.0;
  double minRating = 0.0;
  double maxRating = 0.0;
  Map<String, double> qualityDistribution = {};
  double qualityTrend = 0.0;
}

class SessionAnalysis {
  int totalSessions = 0;
  double averageMoviesPerSession = 0.0;
  int maxMoviesInSession = 0;
  double bingeWatchingFrequency = 0.0;
}

class DiversityAnalysis {
  double genreDiversity = 0.0;
  double yearDiversity = 0.0;
  double languageDiversity = 0.0;
  double totalDiversityScore = 0.0;
}

class MoviePrediction {
  Map<String, dynamic> sequenceBasedPrediction = {};
  Map<String, dynamic> temporalCyclePrediction = {};
  Map<String, dynamic> moodBasedPrediction = {};
  Map<String, dynamic> hybridPrediction = {};
}

class EngagementScore {
  double frequency = 0.0;
  double diversity = 0.0;
  double depth = 0.0;
  double consistency = 0.0;
  double totalScore = 0.0;
  UserType userType = UserType.newUser;
}

enum UserType {
  newUser,
  casualUser,
  regularUser,
  powerUser,
}

class BehaviorAnomaly {
  BehaviorAnomaly({
    required this.type,
    required this.description,
    required this.severity,
    required this.detectedAt,
  });
  final AnomalyType type;
  final String description;
  final AnomalySeverity severity;
  final DateTime detectedAt;
}

enum AnomalyType {
  unusualActivity,
  preferenceShift,
  inactivity,
}

enum AnomalySeverity {
  low,
  medium,
  high,
}

class UserInsight {
  UserInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.actionable,
    required this.recommendation,
  });
  final InsightType type;
  final String title;
  final String description;
  final bool actionable;
  final String recommendation;
}

enum InsightType {
  genrePreference,
  temporalPattern,
  diversity,
  qualityPreference,
  trendFollowing,
}
