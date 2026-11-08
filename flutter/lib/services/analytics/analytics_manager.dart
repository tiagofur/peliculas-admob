import 'package:flutter/foundation.dart';
import 'advanced_analytics_service.dart';
import 'realtime_metrics_service.dart';

/// Servicio principal que coordina todos los analytics
///
/// Centraliza la gestión de analytics, métricas en tiempo real
/// y proporciona una API unificada para el resto de la aplicación.
class AnalyticsManager {
  AnalyticsManager._();
  static AnalyticsManager? _instance;

  static AnalyticsManager get instance {
    _instance ??= AnalyticsManager._();
    return _instance!;
  }

  late final AdvancedAnalyticsService _analytics;
  late final RealTimeMetricsService _metrics;

  bool _isInitialized = false;
  DateTime? _sessionStartTime;

  /// Inicializa todos los servicios de analytics
  Future<bool> initializeAnalytics() async {
    if (_isInitialized) return true;

    try {
      debugPrint('🚀 Iniciando AnalyticsManager...');

      _analytics = AdvancedAnalyticsService.instance;
      _metrics = RealTimeMetricsService.instance;
      _sessionStartTime = DateTime.now();

      // Inicializar servicios
      final analyticsOk = await _analytics.initialize();
      await _metrics.initialize();

      if (analyticsOk) {
        _isInitialized = true;

        // Registrar inicio de sesión
        await _logSessionStart();

        debugPrint('✅ AnalyticsManager inicializado correctamente');
        return true;
      } else {
        debugPrint(
            '⚠️ Analytics parcialmente inicializado (métricas locales activas)');
        _isInitialized = true; // Continuar con métricas locales
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error inicializando AnalyticsManager: $e');
      return false;
    }
  }

  /// Registra el inicio de sesión
  Future<void> _logSessionStart() async {
    await _analytics.logUserEngagement(
      action: 'session_start',
      additionalData: {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'platform': kIsWeb ? 'web' : 'mobile',
        'debug_mode': kDebugMode,
      },
    );

    _metrics.recordEvent('session_analytics_started', data: {
      'analytics_enabled': true,
      'metrics_enabled': true,
    });
  }

  // === NAVEGACIÓN Y PANTALLAS ===

  /// Registra navegación a una pantalla
  Future<void> logScreenView(
    String screenName, {
    String? previousScreen,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!_isInitialized) return;

    final startTime = DateTime.now();

    await _analytics.logScreenView(
      screenName: screenName,
      parameters: {
        'previous_screen': ?previousScreen,
        ...?additionalData,
      },
    );

    _metrics.recordEvent('screen_navigation', data: {
      'screen': screenName,
      'previous': previousScreen,
      'timestamp': startTime.millisecondsSinceEpoch,
    });
  }

  /// Registra tiempo de carga de pantalla
  Future<void> logScreenLoadTime(String screenName, Duration loadTime) async {
    if (!_isInitialized) return;

    await _analytics.logPerformanceMetric(
      metricName: 'screen_load_time',
      value: loadTime.inMilliseconds,
      unit: 'milliseconds',
      context: {'screen': screenName},
    );

    _metrics.recordMetric(
        'screen_load_time', loadTime.inMilliseconds.toDouble(),
        context: {'screen': screenName});
  }

  // === PELÍCULAS Y CONTENIDO ===

  /// Registra búsqueda de películas
  Future<void> logMovieSearch({
    required String searchTerm,
    int? resultCount,
    List<String>? filters,
    Duration? searchTime,
  }) async {
    if (!_isInitialized) return;

    await _analytics.logMovieSearch(
      searchTerm: searchTerm,
      resultCount: resultCount,
      filters: filters,
    );

    _metrics.recordEvent('movie_search_performed', data: {
      'term_length': searchTerm.length,
      'has_results': resultCount != null && resultCount > 0,
      'result_count': resultCount,
      if (searchTime != null) 'search_time_ms': searchTime.inMilliseconds,
    });

    if (searchTime != null) {
      _metrics.recordMetric(
          'search_response_time', searchTime.inMilliseconds.toDouble());
    }
  }

  /// Registra visualización de película
  Future<void> logMovieViewed({
    required int movieId,
    required String movieTitle,
    String? source,
    String? genre,
    double? imdbRating,
  }) async {
    if (!_isInitialized) return;

    await MovieAnalytics.movieViewed(
      movieId: movieId,
      movieTitle: movieTitle,
      source: source,
      genre: genre,
      rating: imdbRating,
    );

    _metrics.recordEvent('movie_detail_viewed', data: {
      'movie_id': movieId,
      'source': source,
      'has_genre': genre != null,
      'has_rating': imdbRating != null,
    });
  }

  /// Registra interacción con película (favorito, watchlist, etc.)
  Future<void> logMovieAction({
    required String action,
    required int movieId,
    required String movieTitle,
    bool? isAdding,
    double? rating,
  }) async {
    if (!_isInitialized) return;

    await _analytics.logMovieInteraction(
      action: action,
      movieId: movieId,
      movieTitle: movieTitle,
      rating: rating,
      additionalData: {
        'is_adding': ?isAdding,
      },
    );

    _metrics.recordEvent('movie_action', data: {
      'action': action,
      'movie_id': movieId,
      'is_adding': ?isAdding,
    });
  }

  // === SOCIAL Y COMPARTIR ===

  /// Registra compartir contenido
  Future<void> logShareAction({
    required String contentType,
    required String shareMethod,
    int? contentId,
    String? contentTitle,
  }) async {
    if (!_isInitialized) return;

    await _analytics.logSocialInteraction(
      action: 'share',
      contentType: contentType,
      contentId: contentId,
      shareMethod: shareMethod,
    );

    _metrics.recordEvent('content_shared', data: {
      'content_type': contentType,
      'share_method': shareMethod,
      'has_id': contentId != null,
    });
  }

  // === PERFORMANCE Y ERRORES ===

  /// Registra métrica de performance
  Future<void> logPerformanceMetric({
    required String metricName,
    required num value,
    String? unit,
    Map<String, dynamic>? context,
  }) async {
    if (!_isInitialized) return;

    await _analytics.logPerformanceMetric(
      metricName: metricName,
      value: value,
      unit: unit,
      context: context,
    );

    _metrics.recordMetric(metricName, value.toDouble(), context: context);
  }

  /// Registra error de aplicación
  Future<void> logError({
    required String errorType,
    required String errorMessage,
    String? stackTrace,
    String? screen,
    Map<String, dynamic>? context,
  }) async {
    if (!_isInitialized) return;

    await _analytics.logError(
      errorType: errorType,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      context: {
        'screen': ?screen,
        ...?context,
      },
    );

    _metrics.recordEvent('error_occurred', data: {
      'error_type': errorType,
      'has_stack_trace': stackTrace != null,
      'screen': screen,
    });
  }

  /// Registra error de red
  Future<void> logNetworkError({
    required String endpoint,
    required String errorMessage,
    int? statusCode,
    Duration? responseTime,
  }) async {
    if (!_isInitialized) return;

    await logError(
      errorType: 'network_error',
      errorMessage: errorMessage,
      context: {
        'endpoint': endpoint,
        'status_code': ?statusCode,
        if (responseTime != null)
          'response_time_ms': responseTime.inMilliseconds,
      },
    );

    _metrics.recordEvent('network_error', data: {
      'endpoint': endpoint,
      'status_code': statusCode,
    });
  }

  // === MONETIZACIÓN ===

  /// Registra interacción con anuncio
  Future<void> logAdInteraction({
    required String adType,
    required String action,
    String? context,
    double? rewardAmount,
  }) async {
    if (!_isInitialized) return;

    await _analytics.logAdInteraction(
      adType: adType,
      action: action,
      adContext: context,
      rewardAmount: rewardAmount,
    );

    _metrics.recordEvent('ad_interaction', data: {
      'ad_type': adType,
      'action': action,
      'has_reward': rewardAmount != null,
    });
  }

  // === USER ENGAGEMENT ===

  /// Registra uso de característica
  Future<void> logFeatureUsed({
    required String featureName,
    Map<String, dynamic>? parameters,
  }) async {
    if (!_isInitialized) return;

    await _analytics.logUserEngagement(
      action: 'feature_used',
      feature: featureName,
      additionalData: parameters,
    );

    _metrics.recordEvent('feature_used', data: {
      'feature': featureName,
      ...?parameters,
    });
  }

  /// Establece propiedades del usuario
  Future<void> setUserProperties({
    String? userId,
    String? userLevel,
    int? totalMoviesWatched,
    String? favoriteGenre,
    bool? isPremiumUser,
  }) async {
    if (!_isInitialized) return;

    await _analytics.setUserProperties(
      userId: userId,
      userLevel: userLevel,
      totalMoviesWatched: totalMoviesWatched,
      favoriteGenre: favoriteGenre,
      isPremiumUser: isPremiumUser,
    );

    _metrics.recordEvent('user_properties_updated', data: {
      'has_user_id': userId != null,
      'user_level': userLevel,
      'movies_watched': totalMoviesWatched,
    });
  }

  // === UTILIDADES Y REPORTES ===

  /// Obtiene resumen de métricas de la sesión actual
  Map<String, dynamic> getSessionSummary() {
    if (!_isInitialized) return {};

    final sessionDuration = _sessionStartTime != null
        ? DateTime.now().difference(_sessionStartTime!)
        : Duration.zero;

    final metricsSummary = _metrics.getMetricsSummary();

    return {
      'session_duration_minutes': sessionDuration.inMinutes,
      'analytics_enabled': true,
      'metrics_summary': metricsSummary.toJson(),
      'recent_events':
          _metrics.getRecentEvents(10).map((e) => e.toJson()).toList(),
    };
  }

  /// Exporta todas las métricas recolectadas
  Map<String, dynamic> exportAllMetrics() {
    if (!_isInitialized) return {};

    return {
      'export_timestamp': DateTime.now().toIso8601String(),
      'session_info': {
        'start_time': _sessionStartTime?.toIso8601String(),
        'duration_minutes': _sessionStartTime != null
            ? DateTime.now().difference(_sessionStartTime!).inMinutes
            : 0,
      },
      'realtime_metrics': _metrics.exportMetrics(),
      'analytics_status': {
        'initialized': _isInitialized,
        'platform': kIsWeb ? 'web' : 'mobile',
        'debug_mode': kDebugMode,
      },
    };
  }

  /// Resetea todas las métricas (solo en debug)
  Future<void> resetAllMetrics() async {
    if (!kDebugMode || !_isInitialized) return;

    _metrics.clearMetrics();
    await _analytics.resetAnalyticsData();

    debugPrint('🗑️ Todas las métricas han sido reseteadas');
  }

  /// Finaliza la sesión de analytics
  Future<void> endSession() async {
    if (!_isInitialized || _sessionStartTime == null) return;

    final sessionDuration = DateTime.now().difference(_sessionStartTime!);

    await _analytics.logUserEngagement(
      action: 'session_end',
      sessionDuration: sessionDuration.inSeconds,
      additionalData: {
        'total_events': _metrics.getRecentEvents().length,
        'metrics_collected': _metrics.getAllMetrics().length,
      },
    );

    _metrics.recordEvent('session_ended', data: {
      'duration_minutes': sessionDuration.inMinutes,
      'clean_exit': true,
    });

    debugPrint(
        '📊 Sesión de analytics finalizada: ${sessionDuration.inMinutes} minutos');
  }

  /// Verifica si los analytics están funcionando correctamente
  bool get isHealthy => _isInitialized;

  /// Obtiene estadísticas rápidas
  Map<String, dynamic> getQuickStats() {
    if (!_isInitialized) return {};

    return {
      'session_active': _sessionStartTime != null,
      'session_duration_minutes': _sessionStartTime != null
          ? DateTime.now().difference(_sessionStartTime!).inMinutes
          : 0,
      'total_events': _metrics.getRecentEvents().length,
      'metrics_tracked': _metrics.getAllMetrics().length,
      'error_rate': _metrics.getMetricsSummary().errorRate,
    };
  }
}
