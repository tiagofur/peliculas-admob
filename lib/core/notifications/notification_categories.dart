import 'dart:async';

import '../../domain/entities/movie.dart';
import '../../domain/entities/person.dart';
import '../logging/logger_factory.dart';
import 'notification_manager.dart';

/// Servicio para gestionar notificaciones de nuevas películas
class NewMovieNotificationService {
  NewMovieNotificationService._();
  static NewMovieNotificationService? _instance;
  static NewMovieNotificationService get instance =>
      _instance ??= NewMovieNotificationService._();

  final _logger = LoggerFactory.logger;
  final _notificationManager = NotificationManager.instance;
  final Set<int> _notifiedMovies = {};
  Timer? _checkTimer;

  /// Inicia el monitoreo de nuevas películas
  void startMonitoring() {
    _logger.info('Iniciando monitoreo de nuevas películas');

    // Verificar cada 6 horas
    _checkTimer = Timer.periodic(const Duration(hours: 6), (_) {
      _checkForNewMovies();
    });
  }

  /// Detiene el monitoreo
  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _logger.info('Monitoreo de nuevas películas detenido');
  }

  /// Verifica si hay nuevas películas
  Future<void> _checkForNewMovies() async {
    try {
      _logger.info('Verificando nuevas películas');

      // Aquí se implementaría la lógica para obtener nuevas películas
      // desde la API de TMDB o Trakt
      final newMovies = await _fetchNewMovies();

      for (final movie in newMovies) {
        if (!_notifiedMovies.contains(movie.id)) {
          await _notifyNewMovie(movie);
          _notifiedMovies.add(movie.id);
        }
      }
    } catch (e) {
      _logger.error('Error verificando nuevas películas: $e');
    }
  }

  /// Obtiene nuevas películas (placeholder)
  Future<List<Movie>> _fetchNewMovies() async {
    // Implementar lógica real para obtener nuevas películas
    return [];
  }

  /// Notifica sobre una nueva película
  Future<void> _notifyNewMovie(Movie movie) async {
    await _notificationManager.notifyNewMovie(movie);
    _logger.info('Notificación enviada para nueva película: ${movie.title}');
  }

  /// Notifica manualmente sobre una película
  Future<void> notifyMovie(Movie movie) async {
    await _notifyNewMovie(movie);
    _notifiedMovies.add(movie.id);
  }

  /// Limpia el historial de películas notificadas
  void clearNotifiedMovies() {
    _notifiedMovies.clear();
    _logger.info('Historial de películas notificadas limpiado');
  }
}

/// Servicio para gestionar notificaciones de recomendaciones
class RecommendationNotificationService {
  RecommendationNotificationService._();
  static RecommendationNotificationService? _instance;
  static RecommendationNotificationService get instance =>
      _instance ??= RecommendationNotificationService._();

  final _logger = LoggerFactory.logger;
  final _notificationManager = NotificationManager.instance;
  Timer? _recommendationTimer;
  DateTime? _lastRecommendationTime;

  /// Inicia el servicio de recomendaciones
  void startRecommendationService() {
    _logger.info('Iniciando servicio de recomendaciones');

    // Enviar recomendaciones cada 24 horas
    _recommendationTimer = Timer.periodic(const Duration(hours: 24), (_) {
      _generateAndSendRecommendations();
    });
  }

  /// Detiene el servicio de recomendaciones
  void stopRecommendationService() {
    _recommendationTimer?.cancel();
    _recommendationTimer = null;
    _logger.info('Servicio de recomendaciones detenido');
  }

  /// Genera y envía recomendaciones personalizadas
  Future<void> _generateAndSendRecommendations() async {
    try {
      // Verificar si ya se enviaron recomendaciones hoy
      if (_lastRecommendationTime != null &&
          _isSameDay(_lastRecommendationTime!, DateTime.now())) {
        return;
      }

      _logger.info('Generando recomendaciones personalizadas');

      final recommendations = await _generatePersonalizedRecommendations();

      if (recommendations.isNotEmpty) {
        await _notificationManager
            .notifyPersonalizedRecommendations(recommendations);
        _lastRecommendationTime = DateTime.now();
        _logger.info(
            'Recomendaciones enviadas: ${recommendations.length} películas');
      }
    } catch (e) {
      _logger.error('Error generando recomendaciones: $e');
    }
  }

  /// Genera recomendaciones personalizadas basadas en el historial del usuario
  Future<List<Movie>> _generatePersonalizedRecommendations() async {
    // Implementar lógica de recomendaciones basada en:
    // - Películas favoritas del usuario
    // - Géneros preferidos
    // - Actores favoritos
    // - Historial de visualización
    // - Tendencias actuales

    return [];
  }

  /// Envía recomendaciones inmediatamente
  Future<void> sendImmediateRecommendations(List<Movie> movies) async {
    if (movies.isNotEmpty) {
      await _notificationManager.notifyPersonalizedRecommendations(movies);
      _lastRecommendationTime = DateTime.now();
      _logger.info(
          'Recomendaciones inmediatas enviadas: ${movies.length} películas');
    }
  }

  /// Programa recomendaciones para un momento específico
  Future<void> scheduleRecommendations(
      List<Movie> movies, DateTime scheduledTime) async {
    if (movies.isEmpty) return;

    final movie = movies.first;
    await _notificationManager.scheduleIntelligentNotification(
      NotificationConfig(
        type: NotificationType.personalizedRecommendations,
        title: 'Recomendaciones programadas',
        body:
            'Te recomendamos "${movie.title}" y ${movies.length - 1} películas más',
        data: {'recommendedMovies': movies.map((m) => m.id).toList()},
        imageUrl: movie.posterPath,
        actionUrl: '/recommendations',
        priority: NotificationPriority.high,
        scheduledTime: scheduledTime,
      ),
    );

    _logger.info('Recomendaciones programadas para: $scheduledTime');
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}

/// Servicio para gestionar notificaciones de actualizaciones de listas
class ListUpdateNotificationService {
  ListUpdateNotificationService._();
  static ListUpdateNotificationService? _instance;
  static ListUpdateNotificationService get instance =>
      _instance ??= ListUpdateNotificationService._();

  final _logger = LoggerFactory.logger;
  final _notificationManager = NotificationManager.instance;
  final Map<String, int> _listItemCounts = {};

  /// Monitorea cambios en una lista específica
  void monitorList(String listName, int currentItemCount) {
    final previousCount = _listItemCounts[listName] ?? currentItemCount;

    if (currentItemCount > previousCount) {
      final newItemsCount = currentItemCount - previousCount;
      _notifyListUpdate(listName, newItemsCount);
    }

    _listItemCounts[listName] = currentItemCount;
  }

  /// Notifica sobre actualizaciones en una lista
  Future<void> _notifyListUpdate(String listName, int newItemsCount) async {
    await _notificationManager.notifyListUpdate(listName, newItemsCount);
    _logger.info(
        'Notificación de actualización de lista enviada: $listName (+$newItemsCount)');
  }

  /// Notifica manualmente sobre una actualización de lista
  Future<void> notifyListUpdate(String listName, int newItemsCount,
      {String? customMessage}) async {
    if (customMessage != null) {
      await _notificationManager.scheduleIntelligentNotification(
        NotificationConfig(
          type: NotificationType.listUpdates,
          title: 'Lista actualizada',
          body: customMessage,
          data: {'listName': listName, 'newItemsCount': newItemsCount},
          actionUrl: '/lists',
        ),
      );
    } else {
      await _notifyListUpdate(listName, newItemsCount);
    }
  }

  /// Limpia el monitoreo de todas las listas
  void clearAllListMonitoring() {
    _listItemCounts.clear();
    _logger.info('Monitoreo de listas limpiado');
  }
}

/// Servicio para gestionar notificaciones de actores favoritos
class FavoriteActorNotificationService {
  FavoriteActorNotificationService._();
  static FavoriteActorNotificationService? _instance;
  static FavoriteActorNotificationService get instance =>
      _instance ??= FavoriteActorNotificationService._();

  final _logger = LoggerFactory.logger;
  final _notificationManager = NotificationManager.instance;
  final Map<int, Set<int>> _actorMovieNotifications = {};
  Timer? _checkTimer;

  /// Inicia el monitoreo de actores favoritos
  void startMonitoring(List<Person> favoriteActors) {
    _logger.info(
        'Iniciando monitoreo de actores favoritos: ${favoriteActors.length}');

    // Verificar cada 12 horas
    _checkTimer = Timer.periodic(const Duration(hours: 12), (_) {
      _checkForNewMoviesFromFavoriteActors(favoriteActors);
    });
  }

  /// Detiene el monitoreo
  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _logger.info('Monitoreo de actores favoritos detenido');
  }

  /// Verifica nuevas películas de actores favoritos
  Future<void> _checkForNewMoviesFromFavoriteActors(
      List<Person> favoriteActors) async {
    try {
      for (final actor in favoriteActors) {
        final newMovies = await _fetchNewMoviesForActor(actor);

        for (final movie in newMovies) {
          final actorId = actor.id ?? 0;
          final actorNotifications =
              _actorMovieNotifications[actorId] ?? <int>{};

          if (!actorNotifications.contains(movie.id)) {
            await _notificationManager.notifyFavoriteActorNewMovie(
                actor, movie);
            actorNotifications.add(movie.id);
            _actorMovieNotifications[actorId] = actorNotifications;

            _logger.info(
                'Notificación enviada: nueva película de ${actor.name} - ${movie.title}');
          }
        }
      }
    } catch (e) {
      _logger
          .error('Error verificando nuevas películas de actores favoritos: $e');
    }
  }

  /// Obtiene nuevas películas para un actor específico
  Future<List<Movie>> _fetchNewMoviesForActor(Person actor) async {
    // Implementar lógica para obtener nuevas películas del actor
    // desde la API de TMDB
    return [];
  }

  /// Notifica manualmente sobre una nueva película de un actor favorito
  Future<void> notifyFavoriteActorMovie(Person actor, Movie movie) async {
    await _notificationManager.notifyFavoriteActorNewMovie(actor, movie);

    final actorId = actor.id ?? 0;
    final actorNotifications = _actorMovieNotifications[actorId] ?? <int>{};
    actorNotifications.add(movie.id);
    _actorMovieNotifications[actorId] = actorNotifications;

    _logger.info('Notificación manual enviada: ${actor.name} - ${movie.title}');
  }

  /// Limpia el historial de notificaciones
  void clearNotificationHistory() {
    _actorMovieNotifications.clear();
    _logger.info('Historial de notificaciones de actores favoritos limpiado');
  }
}

/// Servicio para gestionar notificaciones de películas populares
class TrendingMoviesNotificationService {
  TrendingMoviesNotificationService._();
  static TrendingMoviesNotificationService? _instance;
  static TrendingMoviesNotificationService get instance =>
      _instance ??= TrendingMoviesNotificationService._();

  final _logger = LoggerFactory.logger;
  final _notificationManager = NotificationManager.instance;
  final Set<int> _notifiedTrendingMovies = {};
  Timer? _trendingTimer;

  /// Inicia el monitoreo de películas populares
  void startTrendingMonitoring() {
    _logger.info('Iniciando monitoreo de películas populares');

    // Verificar tendencias cada 8 horas
    _trendingTimer = Timer.periodic(const Duration(hours: 8), (_) {
      _checkTrendingMovies();
    });
  }

  /// Detiene el monitoreo de tendencias
  void stopTrendingMonitoring() {
    _trendingTimer?.cancel();
    _trendingTimer = null;
    _logger.info('Monitoreo de películas populares detenido');
  }

  /// Verifica películas que están siendo tendencia
  Future<void> _checkTrendingMovies() async {
    try {
      _logger.info('Verificando películas populares');

      final trendingMovies = await _fetchTrendingMovies();

      for (final movie in trendingMovies.take(3)) {
        // Solo las top 3
        if (!_notifiedTrendingMovies.contains(movie.id)) {
          await _notifyTrendingMovie(movie);
          _notifiedTrendingMovies.add(movie.id);
        }
      }

      // Limpiar notificaciones antiguas (mantener solo las últimas 50)
      if (_notifiedTrendingMovies.length > 50) {
        final toRemove = _notifiedTrendingMovies.length - 50;
        final oldMovies = _notifiedTrendingMovies.take(toRemove).toList();
        for (final movieId in oldMovies) {
          _notifiedTrendingMovies.remove(movieId);
        }
      }
    } catch (e) {
      _logger.error('Error verificando películas populares: $e');
    }
  }

  /// Obtiene películas que están siendo tendencia
  Future<List<Movie>> _fetchTrendingMovies() async {
    // Implementar lógica para obtener películas populares
    // desde la API de TMDB o Trakt
    return [];
  }

  /// Notifica sobre una película popular
  Future<void> _notifyTrendingMovie(Movie movie) async {
    await _notificationManager.scheduleIntelligentNotification(
      NotificationConfig(
        type: NotificationType.trendingMovies,
        title: '🔥 Película popular',
        body: '"${movie.title}" está siendo muy popular. ¡No te la pierdas!',
        data: {'movieId': movie.id.toString()},
        imageUrl: movie.posterPath,
        actionUrl: '/movie/${movie.id}',
        priority: NotificationPriority.normal,
        actions: [
          const NotificationAction(
            id: 'view',
            title: 'Ver detalles',
          ),
          const NotificationAction(
            id: 'add_watchlist',
            title: 'Agregar a lista',
          ),
        ],
      ),
    );

    _logger.info('Notificación de película popular enviada: ${movie.title}');
  }

  /// Limpia el historial de películas populares notificadas
  void clearTrendingHistory() {
    _notifiedTrendingMovies.clear();
    _logger.info('Historial de películas populares limpiado');
  }
}

/// Coordinador central para todos los servicios de notificaciones
class NotificationCategoriesCoordinator {
  NotificationCategoriesCoordinator._();
  static NotificationCategoriesCoordinator? _instance;
  static NotificationCategoriesCoordinator get instance =>
      _instance ??= NotificationCategoriesCoordinator._();

  final _logger = LoggerFactory.logger;

  // Servicios de categorías
  final newMovieService = NewMovieNotificationService.instance;
  final recommendationService = RecommendationNotificationService.instance;
  final listUpdateService = ListUpdateNotificationService.instance;
  final favoriteActorService = FavoriteActorNotificationService.instance;
  final trendingMoviesService = TrendingMoviesNotificationService.instance;

  /// Inicia todos los servicios de notificaciones
  Future<void> startAllServices({List<Person>? favoriteActors}) async {
    _logger.info('Iniciando todos los servicios de notificaciones');

    newMovieService.startMonitoring();
    recommendationService.startRecommendationService();
    trendingMoviesService.startTrendingMonitoring();

    if (favoriteActors != null && favoriteActors.isNotEmpty) {
      favoriteActorService.startMonitoring(favoriteActors);
    }

    _logger.info('Todos los servicios de notificaciones iniciados');
  }

  /// Detiene todos los servicios de notificaciones
  void stopAllServices() {
    _logger.info('Deteniendo todos los servicios de notificaciones');

    newMovieService.stopMonitoring();
    recommendationService.stopRecommendationService();
    favoriteActorService.stopMonitoring();
    trendingMoviesService.stopTrendingMonitoring();

    _logger.info('Todos los servicios de notificaciones detenidos');
  }

  /// Limpia todos los historiales de notificaciones
  void clearAllHistories() {
    _logger.info('Limpiando todos los historiales de notificaciones');

    newMovieService.clearNotifiedMovies();
    listUpdateService.clearAllListMonitoring();
    favoriteActorService.clearNotificationHistory();
    trendingMoviesService.clearTrendingHistory();

    _logger.info('Todos los historiales de notificaciones limpiados');
  }
}
