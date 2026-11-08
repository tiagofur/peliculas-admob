import 'package:flutter/foundation.dart';

/// Servicio de analytics avanzado (preparado para Firebase Analytics)
///
/// NOTA: Este servicio está preparado para integración con Firebase Analytics
/// Para activarlo completamente, agregar firebase_analytics a pubspec.yaml
/// y descomentar las importaciones y llamadas correspondientes.
class AdvancedAnalyticsService {
  AdvancedAnalyticsService._();
  static AdvancedAnalyticsService? _instance;

  static AdvancedAnalyticsService get instance {
    _instance ??= AdvancedAnalyticsService._();
    return _instance!;
  }

  bool _isInitialized = false;

  // Comentado para evitar dependencia directa por ahora
  // FirebaseAnalytics? _analytics;

  /// Inicializa el servicio de analytics
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      if (kIsWeb) {
        debugPrint('🌐 Analytics: Web mode - usando logging local');
      } else {
        // Descomentar cuando se agregue firebase_analytics
        // _analytics = FirebaseAnalytics.instance;
        debugPrint('📱 Analytics: Native mode - preparado para Firebase');
      }

      _isInitialized = true;
      debugPrint('✅ Analytics service inicializado');

      // Log de inicialización de la app
      await logAppStart();

      return true;
    } catch (e) {
      debugPrint('❌ Error inicializando Analytics: $e');
      return false;
    }
  }

  /// Registra el inicio de la aplicación
  Future<void> logAppStart() async {
    await _logEvent('app_start', parameters: {
      'platform': kIsWeb ? 'web' : 'mobile',
      'debug_mode': kDebugMode,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Registra navegación entre pantallas
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, dynamic>? parameters,
  }) async {
    await _logEvent('screen_view', parameters: {
      'screen_name': screenName,
      'screen_class': ?screenClass,
      ...?parameters,
    });
  }

  /// Registra búsquedas de películas
  Future<void> logMovieSearch({
    required String searchTerm,
    int? resultCount,
    List<String>? filters,
    String? searchType,
  }) async {
    await _logEvent('movie_search', parameters: {
      'search_term': searchTerm,
      'result_count': ?resultCount,
      if (filters != null) 'filters': filters.join(','),
      'search_type': ?searchType,
    });
  }

  /// Registra interacciones con películas
  Future<void> logMovieInteraction({
    required String action, // 'view', 'rate', 'favorite', 'watchlist'
    required int movieId,
    String? movieTitle,
    double? rating,
    Map<String, dynamic>? additionalData,
  }) async {
    await _logEvent('movie_interaction', parameters: {
      'action': action,
      'movie_id': movieId,
      'movie_title': ?movieTitle,
      'rating': ?rating,
      ...?additionalData,
    });
  }

  /// Registra uso de características sociales
  Future<void> logSocialInteraction({
    required String action, // 'share', 'review', 'comment'
    required String contentType, // 'movie', 'review', 'list'
    int? contentId,
    String? shareMethod, // 'twitter', 'facebook', 'whatsapp', etc.
  }) async {
    await _logEvent('social_interaction', parameters: {
      'action': action,
      'content_type': contentType,
      'content_id': ?contentId,
      'share_method': ?shareMethod,
    });
  }

  /// Registra interacciones con el sistema de recomendaciones
  Future<void> logRecommendationInteraction({
    required String action, // 'view', 'click', 'dismiss'
    required String
        recommendationType, // 'collaborative', 'content_based', 'trending'
    int? movieId,
    int? position, // Posición en la lista de recomendaciones
  }) async {
    await _logEvent('recommendation_interaction', parameters: {
      'action': action,
      'recommendation_type': recommendationType,
      'movie_id': ?movieId,
      'position': ?position,
    });
  }

  /// Registra eventos de monetización
  Future<void> logAdInteraction({
    required String adType, // 'banner', 'interstitial', 'rewarded'
    required String action, // 'show', 'click', 'close', 'reward_earned'
    String? adContext, // Contexto donde se mostró el anuncio
    double? rewardAmount,
  }) async {
    await _logEvent('ad_interaction', parameters: {
      'ad_type': adType,
      'action': action,
      'ad_context': ?adContext,
      'reward_amount': ?rewardAmount,
    });
  }

  /// Registra métricas de performance
  Future<void> logPerformanceMetric({
    required String metricName,
    required num value,
    String? unit,
    Map<String, dynamic>? context,
  }) async {
    await _logEvent('performance_metric', parameters: {
      'metric_name': metricName,
      'value': value,
      'unit': ?unit,
      ...?context,
    });
  }

  /// Registra errores no fatales
  Future<void> logError({
    required String errorType,
    required String errorMessage,
    String? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    await _logEvent('error_occurred', parameters: {
      'error_type': errorType,
      'error_message': errorMessage,
      if (stackTrace != null) 'has_stack_trace': true,
      ...?context,
    });
  }

  /// Registra eventos de usuario y engagement
  Future<void> logUserEngagement({
    required String
        action, // 'session_start', 'feature_used', 'milestone_reached'
    String? feature,
    int? sessionDuration,
    Map<String, dynamic>? additionalData,
  }) async {
    await _logEvent('user_engagement', parameters: {
      'action': action,
      'feature': ?feature,
      'session_duration': ?sessionDuration,
      ...?additionalData,
    });
  }

  /// Establece propiedades del usuario
  Future<void> setUserProperties({
    String? userId,
    String? userLevel, // 'newcomer', 'movie_fan', etc.
    int? totalMoviesWatched,
    String? favoriteGenre,
    bool? isPremiumUser,
  }) async {
    if (kDebugMode) {
      debugPrint('👤 Setting user properties: '
          'level=$userLevel, movies=$totalMoviesWatched, genre=$favoriteGenre');
    }

    // Descomentar cuando se integre Firebase Analytics
    // if (_analytics != null) {
    //   await _analytics!.setUserId(id: userId);
    //   await _analytics!.setUserProperty(name: 'user_level', value: userLevel);
    //   await _analytics!.setUserProperty(name: 'total_movies_watched', value: totalMoviesWatched?.toString());
    //   await _analytics!.setUserProperty(name: 'favorite_genre', value: favoriteGenre);
    //   await _analytics!.setUserProperty(name: 'is_premium', value: isPremiumUser?.toString());
    // }
  }

  /// Método interno para logging de eventos
  Future<void> _logEvent(String eventName,
      {Map<String, dynamic>? parameters}) async {
    if (!_isInitialized) return;

    try {
      if (kDebugMode) {
        debugPrint('📊 Analytics Event: $eventName');
        if (parameters != null) {
          debugPrint('   Parameters: $parameters');
        }
      }

      // Descomentar cuando se integre Firebase Analytics
      // if (_analytics != null && !kIsWeb) {
      //   await _analytics!.logEvent(
      //     name: eventName,
      //     parameters: parameters,
      //   );
      // }
    } catch (e) {
      debugPrint('❌ Error logging event $eventName: $e');
    }
  }

  /// Obtiene el ID de instalación para analytics
  Future<String?> getAppInstanceId() async {
    try {
      // Descomentar cuando se integre Firebase Analytics
      // if (_analytics != null) {
      //   return await _analytics!.appInstanceId;
      // }

      return 'demo_instance_id';
    } catch (e) {
      debugPrint('❌ Error getting app instance ID: $e');
      return null;
    }
  }

  /// Resetea datos de analytics (para testing)
  Future<void> resetAnalyticsData() async {
    if (kDebugMode) {
      debugPrint('🔄 Resetting analytics data (debug only)');

      // Descomentar cuando se integre Firebase Analytics
      // if (_analytics != null) {
      //   await _analytics!.resetAnalyticsData();
      // }
    }
  }
}

/// Helper para eventos de analytics específicos de la app
class MovieAnalytics {
  static final _analytics = AdvancedAnalyticsService.instance;

  /// Log cuando el usuario ve detalles de una película
  static Future<void> movieViewed({
    required int movieId,
    required String movieTitle,
    String? genre,
    double? rating,
    String? source, // 'search', 'recommendation', 'trending', etc.
  }) async {
    await _analytics.logMovieInteraction(
      action: 'view',
      movieId: movieId,
      movieTitle: movieTitle,
      additionalData: {
        'genre': ?genre,
        'imdb_rating': ?rating,
        'source': ?source,
      },
    );
  }

  /// Log cuando el usuario califica una película
  static Future<void> movieRated({
    required int movieId,
    required String movieTitle,
    required double userRating,
  }) async {
    await _analytics.logMovieInteraction(
      action: 'rate',
      movieId: movieId,
      movieTitle: movieTitle,
      rating: userRating,
    );
  }

  /// Log cuando el usuario agrega/quita de favoritos
  static Future<void> movieFavoriteToggled({
    required int movieId,
    required String movieTitle,
    required bool isAdding,
  }) async {
    await _analytics.logMovieInteraction(
      action: isAdding ? 'favorite_add' : 'favorite_remove',
      movieId: movieId,
      movieTitle: movieTitle,
    );
  }

  /// Log cuando el usuario agrega/quita de watchlist
  static Future<void> watchlistToggled({
    required int movieId,
    required String movieTitle,
    required bool isAdding,
  }) async {
    await _analytics.logMovieInteraction(
      action: isAdding ? 'watchlist_add' : 'watchlist_remove',
      movieId: movieId,
      movieTitle: movieTitle,
    );
  }
}

/// Helper para eventos de performance
class PerformanceAnalytics {
  static final _analytics = AdvancedAnalyticsService.instance;

  /// Log de tiempo de carga de pantalla
  static Future<void> screenLoadTime({
    required String screenName,
    required Duration loadTime,
  }) async {
    await _analytics.logPerformanceMetric(
      metricName: 'screen_load_time',
      value: loadTime.inMilliseconds,
      unit: 'milliseconds',
      context: {'screen': screenName},
    );
  }

  /// Log de uso de memoria
  static Future<void> memoryUsage({
    required double memoryMB,
    String? context,
  }) async {
    await _analytics.logPerformanceMetric(
      metricName: 'memory_usage',
      value: memoryMB,
      unit: 'megabytes',
      context: context != null ? {'context': context} : null,
    );
  }

  /// Log de tiempo de respuesta de API
  static Future<void> apiResponseTime({
    required String endpoint,
    required Duration responseTime,
    bool? success,
  }) async {
    await _analytics.logPerformanceMetric(
      metricName: 'api_response_time',
      value: responseTime.inMilliseconds,
      unit: 'milliseconds',
      context: {
        'endpoint': endpoint,
        'success': ?success,
      },
    );
  }
}
