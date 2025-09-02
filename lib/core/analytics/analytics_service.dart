import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/base_logger.dart';
import '../logging/logger_factory.dart';

/// Tipos de eventos de analíticas
enum AnalyticsEventType {
  userEngagement,
  movieView,
  movieShare,
  listCreate,
  listShare,
  recommendationView,
  recommendationClick,
  searchQuery,
  filterApply,
  appLaunch,
  sessionStart,
  sessionEnd,
  error,
  performance,
  gamificationActivity,
  // Nuevos eventos requeridos
  onboarding,
  addWatchlist,
  rateMovie
}

/// Modelo de evento de analíticas
class AnalyticsEvent {
  AnalyticsEvent({
    required this.id,
    required this.type,
    required this.properties,
    required this.timestamp,
    required this.userId,
    required this.sessionId,
  });

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) => AnalyticsEvent(
        id: json['id'],
        type: AnalyticsEventType.values.firstWhere(
          (e) => e.name == json['type'],
        ),
        properties: Map<String, dynamic>.from(json['properties']),
        timestamp: DateTime.parse(json['timestamp']),
        userId: json['userId'],
        sessionId: json['sessionId'],
      );
  final String id;
  final AnalyticsEventType type;
  final Map<String, dynamic> properties;
  final DateTime timestamp;
  final String userId;
  final String sessionId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'properties': properties,
        'timestamp': timestamp.toIso8601String(),
        'userId': userId,
        'sessionId': sessionId,
      };
}

/// Métricas de usuario
class UserMetrics {
  const UserMetrics({
    required this.totalUsers,
    required this.activeUsers,
    required this.newUsers,
    required this.averageSessionDuration,
    required this.totalSessions,
    required this.deviceTypes,
    required this.platforms,
  });
  final int totalUsers;
  final int activeUsers;
  final int newUsers;
  final double averageSessionDuration;
  final int totalSessions;
  final Map<String, int> deviceTypes;
  final Map<String, int> platforms;
}

/// Métricas de contenido
class ContentMetrics {
  const ContentMetrics({
    required this.totalMoviesViewed,
    required this.totalListsCreated,
    required this.totalShares,
    required this.popularGenres,
    required this.topMovies,
    required this.averageRating,
    required this.totalRecommendations,
    required this.recommendationClickRate,
  });
  final int totalMoviesViewed;
  final int totalListsCreated;
  final int totalShares;
  final Map<String, int> popularGenres;
  final Map<String, int> topMovies;
  final double averageRating;
  final int totalRecommendations;
  final double recommendationClickRate;
}

/// Métricas de rendimiento
class PerformanceMetrics {
  const PerformanceMetrics({
    required this.averageLoadTime,
    required this.averageApiResponseTime,
    required this.totalErrors,
    required this.errorTypes,
    required this.memoryUsage,
    required this.cacheHitRate,
    required this.totalApiCalls,
  });
  final double averageLoadTime;
  final double averageApiResponseTime;
  final int totalErrors;
  final Map<String, int> errorTypes;
  final double memoryUsage;
  final double cacheHitRate;
  final int totalApiCalls;
}

/// Dashboard de métricas completo
class AnalyticsDashboard {
  const AnalyticsDashboard({
    required this.userMetrics,
    required this.contentMetrics,
    required this.performanceMetrics,
    required this.lastUpdated,
  });
  final UserMetrics userMetrics;
  final ContentMetrics contentMetrics;
  final PerformanceMetrics performanceMetrics;
  final DateTime lastUpdated;
}

/// Servicio principal de analíticas
class AnalyticsService {
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();
  static final AnalyticsService _instance = AnalyticsService._internal();

  final List<AnalyticsEvent> _events = [];
  final StreamController<AnalyticsEvent> _eventController =
      StreamController<AnalyticsEvent>.broadcast();
  final StreamController<AnalyticsDashboard> _dashboardController =
      StreamController<AnalyticsDashboard>.broadcast();

  Timer? _flushTimer;
  Timer? _metricsTimer;
  String? _currentSessionId;
  DateTime? _sessionStartTime;
  SharedPreferences? _prefs;

  // Streams públicos
  Stream<AnalyticsEvent> get eventStream => _eventController.stream;
  Stream<AnalyticsDashboard> get dashboardStream => _dashboardController.stream;

  /// Obtener lista de eventos para análisis y testing
  List<AnalyticsEvent> get events => List.unmodifiable(_events);

  /// Inicializar el servicio de analíticas
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _currentSessionId = _generateSessionId();
      _sessionStartTime = DateTime.now();

      // Cargar eventos almacenados
      await _loadStoredEvents();

      // Configurar timers
      _setupTimers();

      // Registrar inicio de sesión
      await trackEvent(
        AnalyticsEventType.sessionStart,
        {'sessionId': _currentSessionId},
      );

      LoggerFactory.info('AnalyticsService initialized successfully', category: LogCategory.analytics);
    } catch (e) {
      LoggerFactory.error('Error initializing AnalyticsService: $e', category: LogCategory.analytics);
    }
  }

  /// Configurar timers para flush automático y actualización de métricas
  void _setupTimers() {
    // Flush eventos cada 30 segundos
    _flushTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _flushEvents();
    });

    // Actualizar métricas cada 5 minutos
    _metricsTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _updateDashboard();
    });
  }

  /// Rastrear un evento
  Future<void> trackEvent(
    AnalyticsEventType type,
    Map<String, dynamic> properties, {
    String? userId,
  }) async {
    try {
      final event = AnalyticsEvent(
        id: _generateEventId(),
        type: type,
        properties: {
          ...properties,
          'platform': defaultTargetPlatform.name,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        timestamp: DateTime.now(),
        userId: userId ?? 'anonymous',
        sessionId: _currentSessionId ?? 'unknown',
      );

      _events.add(event);
      _eventController.add(event);

      // Almacenar evento localmente
      await _storeEvent(event);

      LoggerFactory.debug('Analytics event tracked: ${type.name}', category: LogCategory.analytics);
    } catch (e) {
      LoggerFactory.error('Error tracking analytics event: $e', category: LogCategory.analytics);
    }
  }

  /// Rastrear vista de película
  Future<void> trackMovieView(String movieId, String title) async {
    await trackEvent(AnalyticsEventType.movieView, {
      'movieId': movieId,
      'title': title,
      'viewTime': DateTime.now().toIso8601String(),
    });
  }

  /// Rastrear compartir película
  Future<void> trackMovieShare(String movieId, String platform) async {
    await trackEvent(AnalyticsEventType.movieShare, {
      'movieId': movieId,
      'platform': platform,
      'shareTime': DateTime.now().toIso8601String(),
    });
  }

  /// Rastrear creación de lista
  Future<void> trackListCreate(String listId, String name) async {
    await trackEvent(AnalyticsEventType.listCreate, {
      'listId': listId,
      'name': name,
      'createTime': DateTime.now().toIso8601String(),
    });
  }

  /// Rastrear recomendación vista
  Future<void> trackRecommendationView(
      String recommendationId, String type) async {
    await trackEvent(AnalyticsEventType.recommendationView, {
      'recommendationId': recommendationId,
      'type': type,
      'viewTime': DateTime.now().toIso8601String(),
    });
  }

  /// Rastrear clic en recomendación
  Future<void> trackRecommendationClick(
      String recommendationId, String movieId) async {
    await trackEvent(AnalyticsEventType.recommendationClick, {
      'recommendationId': recommendationId,
      'movieId': movieId,
      'clickTime': DateTime.now().toIso8601String(),
    });
  }

  /// Rastrear búsqueda
  Future<void> trackSearch(String query, int resultsCount) async {
    await trackEvent(AnalyticsEventType.searchQuery, {
      'query': query,
      'resultsCount': resultsCount,
      'searchTime': DateTime.now().toIso8601String(),
    });
  }

  /// Rastrear error
  Future<void> trackError(String error, String context) async {
    await trackEvent(AnalyticsEventType.error, {
      'error': error,
      'context': context,
      'errorTime': DateTime.now().toIso8601String(),
    });
  }

  /// Rastrear rendimiento
  Future<void> trackPerformance(String operation, double duration) async {
    await trackEvent(AnalyticsEventType.performance, {
      'operation': operation,
      'duration': duration,
      'performanceTime': DateTime.now().toIso8601String(),
    });
  }

  /// Obtener métricas de usuario
  Future<UserMetrics> getUserMetrics() async {
    final userEvents = _events
        .where((e) =>
            e.type == AnalyticsEventType.sessionStart ||
            e.type == AnalyticsEventType.appLaunch)
        .toList();

    final uniqueUsers = userEvents.map((e) => e.userId).toSet().length;
    final totalSessions = userEvents.length;
    final averageSessionDuration = _calculateAverageSessionDuration();

    return UserMetrics(
      totalUsers: uniqueUsers,
      activeUsers: _getActiveUsersCount(),
      newUsers: _getNewUsersCount(),
      averageSessionDuration: averageSessionDuration,
      totalSessions: totalSessions,
      deviceTypes: _getDeviceTypeDistribution(),
      platforms: _getPlatformDistribution(),
    );
  }

  /// Obtener métricas de contenido
  Future<ContentMetrics> getContentMetrics() async {
    final movieViews =
        _events.where((e) => e.type == AnalyticsEventType.movieView).length;
    final listsCreated =
        _events.where((e) => e.type == AnalyticsEventType.listCreate).length;
    final shares =
        _events.where((e) => e.type == AnalyticsEventType.movieShare).length;
    final recommendations = _events
        .where((e) => e.type == AnalyticsEventType.recommendationView)
        .length;
    final recommendationClicks = _events
        .where((e) => e.type == AnalyticsEventType.recommendationClick)
        .length;

    return ContentMetrics(
      totalMoviesViewed: movieViews,
      totalListsCreated: listsCreated,
      totalShares: shares,
      popularGenres: _getPopularGenres(),
      topMovies: _getTopMovies(),
      averageRating: _getAverageRating(),
      totalRecommendations: recommendations,
      recommendationClickRate:
          recommendations > 0 ? recommendationClicks / recommendations : 0.0,
    );
  }

  /// Obtener métricas de rendimiento
  Future<PerformanceMetrics> getPerformanceMetrics() async {
    final performanceEvents =
        _events.where((e) => e.type == AnalyticsEventType.performance).toList();
    final errorEvents =
        _events.where((e) => e.type == AnalyticsEventType.error).toList();

    return PerformanceMetrics(
      averageLoadTime: _calculateAverageLoadTime(performanceEvents),
      averageApiResponseTime:
          _calculateAverageApiResponseTime(performanceEvents),
      totalErrors: errorEvents.length,
      errorTypes: _getErrorTypes(errorEvents),
      memoryUsage: _getCurrentMemoryUsage(),
      cacheHitRate: _getCacheHitRate(),
      totalApiCalls: _getTotalApiCalls(),
    );
  }

  /// Obtener dashboard completo
  Future<AnalyticsDashboard> getDashboard() async {
    final userMetrics = await getUserMetrics();
    final contentMetrics = await getContentMetrics();
    final performanceMetrics = await getPerformanceMetrics();

    return AnalyticsDashboard(
      userMetrics: userMetrics,
      contentMetrics: contentMetrics,
      performanceMetrics: performanceMetrics,
      lastUpdated: DateTime.now(),
    );
  }

  /// Actualizar dashboard y notificar listeners
  Future<void> _updateDashboard() async {
    try {
      final dashboard = await getDashboard();
      _dashboardController.add(dashboard);
    } catch (e) {
      LoggerFactory.error('Error updating dashboard: $e', category: LogCategory.analytics);
    }
  }

  /// Métodos auxiliares para cálculos
  double _calculateAverageSessionDuration() {
    // Implementación simplificada
    return 300.0; // 5 minutos promedio
  }

  int _getActiveUsersCount() {
    final now = DateTime.now();
    final last24Hours = now.subtract(const Duration(hours: 24));
    return _events
        .where((e) => e.timestamp.isAfter(last24Hours))
        .map((e) => e.userId)
        .toSet()
        .length;
  }

  int _getNewUsersCount() {
    final now = DateTime.now();
    final last7Days = now.subtract(const Duration(days: 7));
    return _events
        .where((e) =>
            e.timestamp.isAfter(last7Days) &&
            e.type == AnalyticsEventType.appLaunch)
        .map((e) => e.userId)
        .toSet()
        .length;
  }

  Map<String, int> _getDeviceTypeDistribution() {
    final distribution = <String, int>{};
    for (final event in _events) {
      final deviceType = event.properties['deviceType'] ?? 'unknown';
      distribution[deviceType] = (distribution[deviceType] ?? 0) + 1;
    }
    return distribution;
  }

  Map<String, int> _getPlatformDistribution() {
    final distribution = <String, int>{};
    for (final event in _events) {
      final platform = event.properties['platform'] ?? 'unknown';
      distribution[platform] = (distribution[platform] ?? 0) + 1;
    }
    return distribution;
  }

  Map<String, int> _getPopularGenres() {
    // Implementación simplificada
    return {
      'Action': 150,
      'Comedy': 120,
      'Drama': 100,
      'Horror': 80,
      'Sci-Fi': 70,
    };
  }

  Map<String, int> _getTopMovies() {
    // Implementación simplificada
    return {
      'Movie 1': 50,
      'Movie 2': 45,
      'Movie 3': 40,
      'Movie 4': 35,
      'Movie 5': 30,
    };
  }

  double _getAverageRating() {
    return 4.2; // Implementación simplificada
  }

  double _calculateAverageLoadTime(List<AnalyticsEvent> events) {
    if (events.isEmpty) return 0.0;
    final loadTimes = events
        .where((e) => e.properties['operation'] == 'load')
        .map((e) => e.properties['duration'] as double? ?? 0.0)
        .toList();
    return loadTimes.isEmpty
        ? 0.0
        : loadTimes.reduce((a, b) => a + b) / loadTimes.length;
  }

  double _calculateAverageApiResponseTime(List<AnalyticsEvent> events) {
    if (events.isEmpty) return 0.0;
    final apiTimes = events
        .where((e) => e.properties['operation'] == 'api_call')
        .map((e) => e.properties['duration'] as double? ?? 0.0)
        .toList();
    return apiTimes.isEmpty
        ? 0.0
        : apiTimes.reduce((a, b) => a + b) / apiTimes.length;
  }

  Map<String, int> _getErrorTypes(List<AnalyticsEvent> events) {
    final errorTypes = <String, int>{};
    for (final event in events) {
      final errorType = event.properties['error'] ?? 'Unknown';
      errorTypes[errorType] = (errorTypes[errorType] ?? 0) + 1;
    }
    return errorTypes;
  }

  double _getCurrentMemoryUsage() {
    return 45.2; // MB - Implementación simplificada
  }

  double _getCacheHitRate() {
    return 0.85; // 85% - Implementación simplificada
  }

  int _getTotalApiCalls() {
    return _events.where((e) => e.properties['operation'] == 'api_call').length;
  }

  /// Almacenamiento local de eventos
  Future<void> _storeEvent(AnalyticsEvent event) async {
    try {
      final events = _prefs?.getStringList('analytics_events') ?? [];
      events.add(jsonEncode(event.toJson()));

      // Mantener solo los últimos 1000 eventos
      if (events.length > 1000) {
        events.removeRange(0, events.length - 1000);
      }

      await _prefs?.setStringList('analytics_events', events);
    } catch (e) {
      LoggerFactory.error('Error storing analytics event: $e', category: LogCategory.analytics);
    }
  }

  /// Cargar eventos almacenados
  Future<void> _loadStoredEvents() async {
    try {
      final events = _prefs?.getStringList('analytics_events') ?? [];
      for (final eventJson in events) {
        final event = AnalyticsEvent.fromJson(jsonDecode(eventJson));
        _events.add(event);
      }
      LoggerFactory.info('Loaded ${_events.length} stored analytics events', category: LogCategory.analytics);
    } catch (e) {
      LoggerFactory.error('Error loading stored analytics events: $e', category: LogCategory.analytics);
    }
  }

  /// Flush eventos (enviar a servidor remoto si es necesario)
  Future<void> _flushEvents() async {
    try {
      // Aquí se implementaría el envío a un servidor de analíticas
      LoggerFactory.debug('Flushing ${_events.length} analytics events', category: LogCategory.analytics);

      // Por ahora solo limpiamos eventos antiguos
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      _events.removeWhere((event) => event.timestamp.isBefore(cutoff));
    } catch (e) {
      LoggerFactory.error('Error flushing analytics events: $e', category: LogCategory.analytics);
    }
  }

  /// Generar ID único para eventos
  String _generateEventId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_events.length}';
  }

  /// Generar ID único para sesiones
  String _generateSessionId() {
    return 'session_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Finalizar sesión
  Future<void> endSession() async {
    if (_sessionStartTime != null) {
      final sessionDuration =
          DateTime.now().difference(_sessionStartTime!).inSeconds;
      await trackEvent(AnalyticsEventType.sessionEnd, {
        'sessionDuration': sessionDuration,
        'sessionId': _currentSessionId,
      });
    }
  }

  /// Limpiar recursos
  void dispose() {
    _flushTimer?.cancel();
    _metricsTimer?.cancel();
    _eventController.close();
    _dashboardController.close();
  }
}
