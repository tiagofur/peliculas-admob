import '../../domain/entities/movie.dart';
import '../../domain/entities/recommendation.dart';
import '../../domain/entities/watched_movie.dart';
import '../logging/logger_factory.dart';
import 'ml_recommendation_service.dart';
import 'recommendation_engine.dart';

/// Servicio para manejar feedback y explicaciones de recomendaciones
class RecommendationFeedbackService {
  RecommendationFeedbackService._();
  static RecommendationFeedbackService? _instance;
  static RecommendationFeedbackService get instance =>
      _instance ??= RecommendationFeedbackService._();

  final _logger = LoggerFactory.logger;
  final _mlService = MLRecommendationService.instance;
  final _recommendationEngine = RecommendationEngine.instance;

  // Cache de explicaciones para evitar recálculos
  final Map<String, String> _explanationCache = {};

  // Historial de feedback para análisis
  final List<FeedbackEntry> _feedbackHistory = [];

  /// Genera una explicación detallada para una recomendación
  Future<RecommendationExplanation> generateExplanation({
    required Recommendation recommendation,
    required List<Movie> favoriteMovies,
    required List<WatchedMovie> watchedMovies,
    required int userId,
  }) async {
    try {
      final cacheKey =
          '${recommendation.movieId}_${userId}_${recommendation.type.toString()}';

      // Verificar cache
      if (_explanationCache.containsKey(cacheKey)) {
        return RecommendationExplanation(
          primaryReason: _explanationCache[cacheKey]!,
          confidence: recommendation.score,
          factors: [],
        );
      }

      _logger.info(
          'Generando explicación para recomendación ${recommendation.movieId}');

      // Analizar comportamiento del usuario
      final behaviorAnalysis = await _recommendationEngine.analyzeUserBehavior(
        favoriteMovies: favoriteMovies,
        watchedMovies: watchedMovies,
      );

      // Generar explicación basada en el tipo de recomendación
      final explanation = await _generateExplanationByType(
        recommendation: recommendation,
        favoriteMovies: favoriteMovies,
        watchedMovies: watchedMovies,
        behaviorAnalysis: behaviorAnalysis,
      );

      // Guardar en cache
      _explanationCache[cacheKey] = explanation.primaryReason;

      _logger.info('Explicación generada para ${recommendation.title}');
      return explanation;
    } catch (e) {
      _logger.error('Error generando explicación: $e');
      return RecommendationExplanation(
        primaryReason: 'Recomendada especialmente para ti',
        confidence: recommendation.score,
        factors: [],
      );
    }
  }

  /// Procesa feedback del usuario y actualiza el sistema
  Future<void> processFeedback({
    required int movieId,
    required String movieTitle,
    required FeedbackType feedbackType,
    required int userId,
    String? reason,
    Map<String, dynamic>? context,
  }) async {
    try {
      _logger.info('Procesando feedback para "$movieTitle": $feedbackType');

      // Crear entrada de feedback
      final feedbackEntry = FeedbackEntry(
        movieId: movieId,
        movieTitle: movieTitle,
        userId: userId,
        feedbackType: feedbackType,
        reason: reason,
        context: context ?? {},
        timestamp: DateTime.now(),
      );

      // Agregar al historial
      _feedbackHistory.add(feedbackEntry);

      // Procesar feedback en el servicio ML
      await _mlService.processFeedback(
        movieId: movieId,
        feedbackType: feedbackType,
        userId: userId,
        reason: reason,
      );

      // Analizar patrones de feedback
      await _analyzeFeedbackPatterns(userId);

      // Limpiar cache de explicaciones relacionadas
      _clearRelatedExplanationCache(movieId, userId);

      _logger.info('Feedback procesado exitosamente');
    } catch (e) {
      _logger.error('Error procesando feedback: $e');
    }
  }

  /// Obtiene estadísticas de feedback para un usuario
  Future<FeedbackStats> getFeedbackStats(int userId) async {
    try {
      final userFeedback =
          _feedbackHistory.where((f) => f.userId == userId).toList();

      final stats = FeedbackStats(
        totalFeedback: userFeedback.length,
        positiveCount: userFeedback
            .where((f) => _isPositiveFeedback(f.feedbackType))
            .length,
        negativeCount: userFeedback
            .where((f) => _isNegativeFeedback(f.feedbackType))
            .length,
        neutralCount: userFeedback
            .where((f) => _isNeutralFeedback(f.feedbackType))
            .length,
        mostCommonReason: _getMostCommonReason(userFeedback),
        averageResponseTime: _calculateAverageResponseTime(userFeedback),
        feedbackTrends: _analyzeFeedbackTrends(userFeedback),
      );

      return stats;
    } catch (e) {
      _logger.error('Error obteniendo estadísticas de feedback: $e');
      return FeedbackStats.empty();
    }
  }

  /// Genera sugerencias de mejora basadas en feedback
  Future<List<ImprovementSuggestion>> generateImprovementSuggestions(
      int userId) async {
    try {
      final userFeedback =
          _feedbackHistory.where((f) => f.userId == userId).toList();
      final suggestions = <ImprovementSuggestion>[];

      // Analizar patrones negativos
      final negativeFeedback = userFeedback
          .where((f) => _isNegativeFeedback(f.feedbackType))
          .toList();

      if (negativeFeedback.isNotEmpty) {
        // Sugerir ajustes basados en razones comunes
        final commonReasons = _getCommonNegativeReasons(negativeFeedback);

        for (final reason in commonReasons.entries) {
          if (reason.value > 2) {
            // Más de 2 ocurrencias
            suggestions.add(ImprovementSuggestion(
              type: SuggestionType.adjustPreferences,
              title: 'Ajustar preferencias de ${reason.key}',
              description:
                  'Hemos notado que no te gustan las recomendaciones relacionadas con ${reason.key}. ¿Te gustaría ajustar tus preferencias?',
              priority: SuggestionPriority.high,
              actionData: {'preference': reason.key, 'action': 'decrease'},
            ));
          }
        }
      }

      // Sugerir diversificación si hay mucho feedback "ya visto"
      final alreadyWatchedCount = userFeedback
          .where((f) => f.feedbackType == FeedbackType.alreadyWatched)
          .length;
      if (alreadyWatchedCount > userFeedback.length * 0.3) {
        suggestions.add(ImprovementSuggestion(
          type: SuggestionType.diversifyRecommendations,
          title: 'Diversificar recomendaciones',
          description:
              'Parece que ya has visto muchas de nuestras recomendaciones. ¿Te gustaría explorar géneros nuevos?',
          priority: SuggestionPriority.medium,
          actionData: {'action': 'increase_diversity'},
        ));
      }

      // Sugerir actualización de perfil si hay poco engagement
      final engagementRate = _calculateEngagementRate(userFeedback);
      if (engagementRate < 0.3) {
        suggestions.add(ImprovementSuggestion(
          type: SuggestionType.updateProfile,
          title: 'Actualizar perfil',
          description:
              'Actualiza tu perfil con tus géneros y actores favoritos para obtener mejores recomendaciones.',
          priority: SuggestionPriority.medium,
          actionData: {'action': 'update_profile'},
        ));
      }

      _logger.info(
          'Generadas ${suggestions.length} sugerencias de mejora para usuario $userId');
      return suggestions;
    } catch (e) {
      _logger.error('Error generando sugerencias de mejora: $e');
      return [];
    }
  }

  /// Obtiene el historial de feedback de un usuario
  List<FeedbackEntry> getFeedbackHistory(int userId, {int? limit}) {
    final userFeedback = _feedbackHistory
        .where((f) => f.userId == userId)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return limit != null ? userFeedback.take(limit).toList() : userFeedback;
  }

  /// Limpia el historial de feedback antiguo
  void cleanOldFeedback({Duration? olderThan}) {
    final cutoffDate =
        DateTime.now().subtract(olderThan ?? const Duration(days: 90));
    _feedbackHistory.removeWhere((f) => f.timestamp.isBefore(cutoffDate));
    _logger.info('Limpiado feedback anterior a $cutoffDate');
  }

  /// Exporta datos de feedback para análisis
  Map<String, dynamic> exportFeedbackData(int userId) {
    final userFeedback =
        _feedbackHistory.where((f) => f.userId == userId).toList();

    return {
      'userId': userId,
      'totalFeedback': userFeedback.length,
      'exportDate': DateTime.now().toIso8601String(),
      'feedback': userFeedback.map((f) => f.toJson()).toList(),
      'stats': getFeedbackStats(userId),
    };
  }

  // Métodos privados

  Future<RecommendationExplanation> _generateExplanationByType({
    required Recommendation recommendation,
    required List<Movie> favoriteMovies,
    required List<WatchedMovie> watchedMovies,
    required UserBehaviorAnalysis behaviorAnalysis,
  }) async {
    final factors = <ExplanationFactor>[];
    String primaryReason;

    switch (recommendation.type) {
      case RecommendationType.basedOnFavorites:
        primaryReason = await _explainBasedOnFavorites(
            recommendation, favoriteMovies, factors);
        break;
      case RecommendationType.trending:
        primaryReason = _explainTrending(recommendation, factors);
        break;
      case RecommendationType.forYou:
        primaryReason =
            await _explainForYou(recommendation, behaviorAnalysis, factors);
        break;
      case RecommendationType.mood:
        primaryReason = _explainMood(recommendation, factors);
        break;
      case RecommendationType.basedOnWatched:
        primaryReason = await _explainBasedOnWatched(
            recommendation, watchedMovies, factors);
        break;
      case RecommendationType.newReleases:
        primaryReason = _explainNewReleases(recommendation, factors);
        break;
      case RecommendationType.topRated:
        primaryReason = _explainTopRated(recommendation, factors);
        break;
      case RecommendationType.similar:
        primaryReason = _explainSimilar(recommendation, factors);
        break;
      case RecommendationType.director:
        primaryReason = _explainDirector(recommendation, factors);
        break;
      case RecommendationType.actor:
        primaryReason = _explainActor(recommendation, factors);
        break;
      case RecommendationType.genre:
        primaryReason = _explainGenre(recommendation, factors);
        break;
      default:
        primaryReason = 'Recomendada especialmente para ti';
    }

    return RecommendationExplanation(
      primaryReason: primaryReason,
      confidence: recommendation.score,
      factors: factors,
    );
  }

  Future<String> _explainBasedOnFavorites(Recommendation rec,
      List<Movie> favorites, List<ExplanationFactor> factors) async {
    if (favorites.isEmpty) return 'Recomendada para ti';

    // Encontrar similitudes con favoritas
    final similarFavorite = favorites.first; // Simplificado
    factors.add(ExplanationFactor(
      type: FactorType.similarity,
      description: 'Similar a "${similarFavorite.title}"',
      weight: 0.8,
    ));

    return 'Te recomendamos "${rec.title}" porque es similar a "${similarFavorite.title}", una de tus películas favoritas';
  }

  String _explainTrending(Recommendation rec, List<ExplanationFactor> factors) {
    factors.add(ExplanationFactor(
      type: FactorType.popularity,
      description: 'Muy popular actualmente',
      weight: 0.7,
    ));

    return '"${rec.title}" está siendo muy popular entre usuarios con gustos similares a los tuyos';
  }

  Future<String> _explainForYou(Recommendation rec,
      UserBehaviorAnalysis analysis, List<ExplanationFactor> factors) async {
    factors.add(ExplanationFactor(
      type: FactorType.genrePreference,
      description: 'Coincide con tus géneros favoritos',
      weight: 0.9,
    ));

    return '"${rec.title}" es perfecta para ti basándose en tu historial de visualización y preferencias';
  }

  String _explainMood(Recommendation rec, List<ExplanationFactor> factors) {
    factors.add(ExplanationFactor(
      type: FactorType.mood,
      description: 'Perfecta para tu estado de ánimo actual',
      weight: 0.8,
    ));

    return '"${rec.title}" es ideal para tu estado de ánimo actual';
  }

  Future<String> _explainBasedOnWatched(Recommendation rec,
      List<WatchedMovie> watched, List<ExplanationFactor> factors) async {
    if (watched.isEmpty) return 'Recomendada para ti';

    factors.add(ExplanationFactor(
      type: FactorType.watchHistory,
      description: 'Basada en películas que has visto recientemente',
      weight: 0.7,
    ));

    return 'Como disfrutaste viendo películas similares, creemos que "${rec.title}" te gustará';
  }

  String _explainNewReleases(
      Recommendation rec, List<ExplanationFactor> factors) {
    factors.add(ExplanationFactor(
      type: FactorType.freshness,
      description: 'Estreno reciente',
      weight: 0.6,
    ));

    return '"${rec.title}" es un estreno reciente que coincide con tus gustos';
  }

  String _explainTopRated(Recommendation rec, List<ExplanationFactor> factors) {
    factors.add(ExplanationFactor(
      type: FactorType.quality,
      description: 'Altamente calificada por la crítica',
      weight: 0.8,
    ));

    return '"${rec.title}" tiene excelentes calificaciones y coincide con tus preferencias de calidad';
  }

  String _explainSimilar(Recommendation rec, List<ExplanationFactor> factors) {
    factors.add(ExplanationFactor(
      type: FactorType.similarity,
      description: 'Similar a películas que te han gustado',
      weight: 0.9,
    ));

    return '"${rec.title}" es muy similar a otras películas que has disfrutado';
  }

  String _explainDirector(Recommendation rec, List<ExplanationFactor> factors) {
    factors.add(ExplanationFactor(
      type: FactorType.director,
      description: 'De un director que te gusta',
      weight: 0.7,
    ));

    return '"${rec.title}" es de un director cuyas películas has disfrutado anteriormente';
  }

  String _explainActor(Recommendation rec, List<ExplanationFactor> factors) {
    factors.add(ExplanationFactor(
      type: FactorType.actor,
      description: 'Protagonizada por actores que te gustan',
      weight: 0.6,
    ));

    return '"${rec.title}" está protagonizada por actores que has seguido';
  }

  String _explainGenre(Recommendation rec, List<ExplanationFactor> factors) {
    factors.add(ExplanationFactor(
      type: FactorType.genrePreference,
      description: 'Del género que más disfrutas',
      weight: 0.8,
    ));

    return '"${rec.title}" pertenece a uno de tus géneros favoritos';
  }

  Future<void> _analyzeFeedbackPatterns(int userId) async {
    final userFeedback =
        _feedbackHistory.where((f) => f.userId == userId).toList();

    if (userFeedback.length < 5) return; // Necesitamos suficientes datos

    // Analizar patrones temporales
    final recentFeedback = userFeedback
        .where((f) => f.timestamp
            .isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .toList();

    // Detectar cambios en preferencias
    final negativeRate = recentFeedback
            .where((f) => _isNegativeFeedback(f.feedbackType))
            .length /
        recentFeedback.length;

    if (negativeRate > 0.6) {
      _logger.warning(
          'Usuario $userId tiene alta tasa de feedback negativo reciente: ${(negativeRate * 100).toStringAsFixed(1)}%');
    }
  }

  void _clearRelatedExplanationCache(int movieId, int userId) {
    _explanationCache
        .removeWhere((key, value) => key.contains('${movieId}_$userId'));
  }

  bool _isPositiveFeedback(FeedbackType type) {
    return [
      FeedbackType.like,
      FeedbackType.addedToWatchlist,
      FeedbackType.shared
    ].contains(type);
  }

  bool _isNegativeFeedback(FeedbackType type) {
    return [FeedbackType.dislike, FeedbackType.notInterested].contains(type);
  }

  bool _isNeutralFeedback(FeedbackType type) {
    return type == FeedbackType.alreadyWatched;
  }

  String? _getMostCommonReason(List<FeedbackEntry> feedback) {
    if (feedback.isEmpty) return null;

    final reasonCounts = <String, int>{};
    for (final entry in feedback) {
      if (entry.reason != null) {
        reasonCounts[entry.reason!] = (reasonCounts[entry.reason!] ?? 0) + 1;
      }
    }

    if (reasonCounts.isEmpty) return null;

    return reasonCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  Duration _calculateAverageResponseTime(List<FeedbackEntry> feedback) {
    // En implementación real, esto calcularía el tiempo entre mostrar recomendación y recibir feedback
    return const Duration(minutes: 5); // Simulado
  }

  Map<String, double> _analyzeFeedbackTrends(List<FeedbackEntry> feedback) {
    final trends = <String, double>{};

    if (feedback.length < 10) return trends;

    // Analizar tendencias de los últimos 30 días vs anteriores
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final recent = feedback.where((f) => f.timestamp.isAfter(cutoff)).toList();
    final older = feedback.where((f) => f.timestamp.isBefore(cutoff)).toList();

    if (recent.isNotEmpty && older.isNotEmpty) {
      final recentPositiveRate =
          recent.where((f) => _isPositiveFeedback(f.feedbackType)).length /
              recent.length;
      final olderPositiveRate =
          older.where((f) => _isPositiveFeedback(f.feedbackType)).length /
              older.length;

      trends['satisfaction_trend'] = recentPositiveRate - olderPositiveRate;
    }

    return trends;
  }

  Map<String, int> _getCommonNegativeReasons(
      List<FeedbackEntry> negativeFeedback) {
    final reasons = <String, int>{};

    for (final entry in negativeFeedback) {
      if (entry.reason != null) {
        reasons[entry.reason!] = (reasons[entry.reason!] ?? 0) + 1;
      }
    }

    return reasons;
  }

  double _calculateEngagementRate(List<FeedbackEntry> feedback) {
    if (feedback.isEmpty) return 0.0;

    final engagedFeedback = feedback
        .where((f) => f.feedbackType != FeedbackType.alreadyWatched)
        .length;

    return engagedFeedback / feedback.length;
  }
}

/// Entrada de feedback del usuario
class FeedbackEntry {
  FeedbackEntry({
    required this.movieId,
    required this.movieTitle,
    required this.userId,
    required this.feedbackType,
    this.reason,
    required this.context,
    required this.timestamp,
  });
  final int movieId;
  final String movieTitle;
  final int userId;
  final FeedbackType feedbackType;
  final String? reason;
  final Map<String, dynamic> context;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'movieId': movieId,
        'movieTitle': movieTitle,
        'userId': userId,
        'feedbackType': feedbackType.toString(),
        'reason': reason,
        'context': context,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Explicación de una recomendación
class RecommendationExplanation {
  RecommendationExplanation({
    required this.primaryReason,
    required this.confidence,
    required this.factors,
  });
  final String primaryReason;
  final double confidence;
  final List<ExplanationFactor> factors;
}

/// Factor que contribuye a una explicación
class ExplanationFactor {
  ExplanationFactor({
    required this.type,
    required this.description,
    required this.weight,
  });
  final FactorType type;
  final String description;
  final double weight;
}

/// Tipos de factores de explicación
enum FactorType {
  similarity,
  genrePreference,
  popularity,
  mood,
  watchHistory,
  freshness,
  quality,
  director,
  actor,
}

/// Estadísticas de feedback
class FeedbackStats {
  FeedbackStats({
    required this.totalFeedback,
    required this.positiveCount,
    required this.negativeCount,
    required this.neutralCount,
    this.mostCommonReason,
    required this.averageResponseTime,
    required this.feedbackTrends,
  });

  factory FeedbackStats.empty() => FeedbackStats(
        totalFeedback: 0,
        positiveCount: 0,
        negativeCount: 0,
        neutralCount: 0,
        averageResponseTime: Duration.zero,
        feedbackTrends: {},
      );
  final int totalFeedback;
  final int positiveCount;
  final int negativeCount;
  final int neutralCount;
  final String? mostCommonReason;
  final Duration averageResponseTime;
  final Map<String, double> feedbackTrends;

  double get positiveRate =>
      totalFeedback > 0 ? positiveCount / totalFeedback : 0.0;
  double get negativeRate =>
      totalFeedback > 0 ? negativeCount / totalFeedback : 0.0;
  double get neutralRate =>
      totalFeedback > 0 ? neutralCount / totalFeedback : 0.0;
}

/// Sugerencia de mejora
class ImprovementSuggestion {
  ImprovementSuggestion({
    required this.type,
    required this.title,
    required this.description,
    required this.priority,
    required this.actionData,
  });
  final SuggestionType type;
  final String title;
  final String description;
  final SuggestionPriority priority;
  final Map<String, dynamic> actionData;
}

/// Tipos de sugerencias
enum SuggestionType {
  adjustPreferences,
  diversifyRecommendations,
  updateProfile,
  exploreNewGenres,
  improveRatings,
}

/// Prioridad de sugerencias
enum SuggestionPriority {
  low,
  medium,
  high,
}
