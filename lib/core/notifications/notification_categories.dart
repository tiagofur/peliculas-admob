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

/// Servicio para recordatorios semanales de watchlist
class WeeklyWatchlistReminderService {
  WeeklyWatchlistReminderService._();
  static WeeklyWatchlistReminderService? _instance;
  static WeeklyWatchlistReminderService get instance =>
      _instance ??= WeeklyWatchlistReminderService._();

  final _logger = LoggerFactory.logger;
  final _notificationManager = NotificationManager.instance;
  Timer? _weeklyTimer;
  DateTime? _lastReminderSent;

  /// Inicia el servicio de recordatorios semanales
  void startWeeklyReminders() {
    _logger.info('Iniciando servicio de recordatorios semanales de watchlist');

    // Programar para enviar cada domingo a las 10:00 AM
    _scheduleWeeklyReminder();
  }

  /// Detiene el servicio de recordatorios semanales
  void stopWeeklyReminders() {
    _weeklyTimer?.cancel();
    _weeklyTimer = null;
    _logger.info('Servicio de recordatorios semanales detenido');
  }

  /// Programa el próximo recordatorio semanal
  void _scheduleWeeklyReminder() {
    final now = DateTime.now();
    
    // Calcular el próximo domingo a las 10:00 AM
    int daysUntilSunday = (DateTime.sunday - now.weekday) % 7;
    if (daysUntilSunday == 0 && now.hour >= 10) {
      daysUntilSunday = 7; // Si es domingo después de las 10 AM, programa para el próximo domingo
    }
    
    final nextSunday = DateTime(
      now.year,
      now.month,
      now.day + daysUntilSunday,
      10, // 10:00 AM
      0,
    );

    final duration = nextSunday.difference(now);
    
    _weeklyTimer = Timer(duration, () {
      _sendWeeklyWatchlistReminder();
      _scheduleWeeklyReminder(); // Programar el siguiente
    });

    _logger.info('Próximo recordatorio semanal programado para: $nextSunday');
  }

  /// Envía el recordatorio semanal de watchlist
  Future<void> _sendWeeklyWatchlistReminder() async {
    try {
      _logger.info('Enviando recordatorio semanal de watchlist');

      final watchlistMovies = await _getWatchlistMovies();
      
      if (watchlistMovies.isEmpty) {
        _logger.info('No hay películas en watchlist para recordatorio semanal');
        return;
      }

      // Dividir por prioridades
      final highPriorityMovies = watchlistMovies.where((m) => m.priority.value == 'alta').toList();
      final normalPriorityMovies = watchlistMovies.where((m) => m.priority.value == 'normal').toList();
      final lowPriorityMovies = watchlistMovies.where((m) => m.priority.value == 'baja').toList();

      String title = '📺 Recordatorio semanal';
      String body;
      
      if (highPriorityMovies.isNotEmpty) {
        body = 'Tienes ${highPriorityMovies.length} películas de alta prioridad pendientes en tu lista.';
        if (highPriorityMovies.length == 1) {
          body = 'No olvides ver "${highPriorityMovies.first.movieTitle}" que tienes en alta prioridad.';
        }
      } else if (normalPriorityMovies.isNotEmpty) {
        body = 'Tienes ${normalPriorityMovies.length} películas pendientes en tu watchlist.';
        if (normalPriorityMovies.length == 1) {
          body = 'No olvides ver "${normalPriorityMovies.first.movieTitle}" que tienes en tu lista.';
        }
      } else {
        body = 'Tienes ${lowPriorityMovies.length} películas pendientes en tu watchlist.';
      }

      await _notificationManager.scheduleIntelligentNotification(
        NotificationConfig(
          type: NotificationType.weeklyWatchlistReminder,
          title: title,
          body: body,
          data: {
            'totalMovies': watchlistMovies.length.toString(),
            'highPriorityCount': highPriorityMovies.length.toString(),
            'normalPriorityCount': normalPriorityMovies.length.toString(),
            'lowPriorityCount': lowPriorityMovies.length.toString(),
          },
          actionUrl: '/watchlist',
          priority: NotificationPriority.normal,
          actions: [
            const NotificationAction(
              id: 'view_watchlist',
              title: 'Ver mi lista',
            ),
            const NotificationAction(
              id: 'dismiss',
              title: 'Recordar después',
            ),
          ],
        ),
      );

      _lastReminderSent = DateTime.now();
      _logger.info('Recordatorio semanal enviado: ${watchlistMovies.length} películas');
    } catch (e) {
      _logger.error('Error enviando recordatorio semanal: $e');
    }
  }

  /// Obtiene las películas de la watchlist
  Future<List<dynamic>> _getWatchlistMovies() async {
    // TODO: Implementar con el repositorio real de watchlist
    // Por ahora retorna lista vacía como placeholder
    return [];
  }

  /// Envía recordatorio manual para testing
  Future<void> sendManualReminder() async {
    await _sendWeeklyWatchlistReminder();
  }

  /// Obtiene la fecha del último recordatorio enviado
  DateTime? get lastReminderSent => _lastReminderSent;
}

/// Servicio para notificaciones de estrenos de películas
class MovieReleaseNotificationService {
  MovieReleaseNotificationService._();
  static MovieReleaseNotificationService? _instance;
  static MovieReleaseNotificationService get instance =>
      _instance ??= MovieReleaseNotificationService._();

  final _logger = LoggerFactory.logger;
  final _notificationManager = NotificationManager.instance;
  final Set<int> _notifiedReleases = {};
  Timer? _releaseCheckTimer;

  /// Inicia el monitoreo de estrenos
  void startReleaseMonitoring() {
    _logger.info('Iniciando monitoreo de estrenos de películas');

    // Verificar estrenos diariamente a las 9:00 AM
    _scheduleReleaseCheck();
  }

  /// Detiene el monitoreo de estrenos
  void stopReleaseMonitoring() {
    _releaseCheckTimer?.cancel();
    _releaseCheckTimer = null;
    _logger.info('Monitoreo de estrenos detenido');
  }

  /// Programa la próxima verificación de estrenos
  void _scheduleReleaseCheck() {
    final now = DateTime.now();
    
    // Programar para las 9:00 AM del próximo día si ya pasó la hora
    DateTime nextCheck = DateTime(now.year, now.month, now.day, 9, 0);
    if (nextCheck.isBefore(now)) {
      nextCheck = nextCheck.add(const Duration(days: 1));
    }

    final duration = nextCheck.difference(now);
    
    _releaseCheckTimer = Timer(duration, () {
      _checkMovieReleases();
      _scheduleReleaseCheck(); // Programar el siguiente
    });

    _logger.info('Próxima verificación de estrenos programada para: $nextCheck');
  }

  /// Verifica estrenos de películas en watchlist y seguidas
  Future<void> _checkMovieReleases() async {
    try {
      _logger.info('Verificando estrenos de películas');

      final today = DateTime.now();
      final releasesToday = await _getMoviesReleasingToday(today);

      for (final movie in releasesToday) {
        if (!_notifiedReleases.contains(movie.id)) {
          await _notifyMovieRelease(movie);
          _notifiedReleases.add(movie.id);
        }
      }

      // También verificar próximos estrenos (en los próximos 7 días)
      final upcomingReleases = await _getUpcomingMovieReleases(today);
      for (final movie in upcomingReleases) {
        final releaseKey = movie.id * 1000 + movie.releaseDate.day; // Clave única por día
        if (!_notifiedReleases.contains(releaseKey)) {
          await _notifyUpcomingRelease(movie);
          _notifiedReleases.add(releaseKey);
        }
      }

      // Limpiar notificaciones antiguas (mantener solo las últimas 100)
      if (_notifiedReleases.length > 100) {
        final toRemove = _notifiedReleases.length - 100;
        final oldReleases = _notifiedReleases.take(toRemove).toList();
        for (final releaseId in oldReleases) {
          _notifiedReleases.remove(releaseId);
        }
      }
    } catch (e) {
      _logger.error('Error verificando estrenos: $e');
    }
  }

  /// Obtiene películas que se estrenan hoy
  Future<List<Movie>> _getMoviesReleasingToday(DateTime date) async {
    // TODO: Implementar lógica para obtener películas de watchlist que se estrenan hoy
    // Debe consultar tanto watchlist como películas seguidas por género/actor favorito
    return [];
  }

  /// Obtiene próximos estrenos (próximos 7 días)
  Future<List<Movie>> _getUpcomingMovieReleases(DateTime startDate) async {
    // TODO: Implementar lógica para obtener próximos estrenos de interés
    return [];
  }

  /// Notifica sobre un estreno de hoy
  Future<void> _notifyMovieRelease(Movie movie) async {
    await _notificationManager.scheduleIntelligentNotification(
      NotificationConfig(
        type: NotificationType.movieReleaseNotification,
        title: '🎬 ¡Ya disponible!',
        body: '"${movie.title}" se estrenó hoy. ¡Ve a verla!',
        data: {
          'movieId': movie.id.toString(),
          'releaseType': 'today',
        },
        imageUrl: movie.posterPath,
        actionUrl: '/movie/${movie.id}',
        priority: NotificationPriority.high,
        actions: [
          const NotificationAction(
            id: 'view_movie',
            title: 'Ver detalles',
          ),
          const NotificationAction(
            id: 'find_tickets',
            title: 'Buscar entradas',
          ),
        ],
      ),
    );

    _logger.info('Notificación de estreno enviada: ${movie.title}');
  }

  /// Notifica sobre un próximo estreno
  Future<void> _notifyUpcomingRelease(Movie movie) async {
    final daysUntilRelease = movie.releaseDate.difference(DateTime.now()).inDays;
    
    await _notificationManager.scheduleIntelligentNotification(
      NotificationConfig(
        type: NotificationType.movieReleaseNotification,
        title: '🗓️ Próximo estreno',
        body: '"${movie.title}" se estrena en $daysUntilRelease días.',
        data: {
          'movieId': movie.id.toString(),
          'releaseType': 'upcoming',
          'daysUntilRelease': daysUntilRelease.toString(),
        },
        imageUrl: movie.posterPath,
        actionUrl: '/movie/${movie.id}',
        priority: NotificationPriority.normal,
        actions: [
          const NotificationAction(
            id: 'view_movie',
            title: 'Ver detalles',
          ),
          const NotificationAction(
            id: 'add_calendar',
            title: 'Agregar al calendario',
          ),
        ],
      ),
    );

    _logger.info('Notificación de próximo estreno enviada: ${movie.title} (${daysUntilRelease} días)');
  }

  /// Notifica manualmente sobre un estreno (para testing)
  Future<void> notifyReleaseManually(Movie movie, {bool isToday = true}) async {
    if (isToday) {
      await _notifyMovieRelease(movie);
    } else {
      await _notifyUpcomingRelease(movie);
    }
  }

  /// Limpia el historial de notificaciones de estrenos
  void clearReleaseHistory() {
    _notifiedReleases.clear();
    _logger.info('Historial de notificaciones de estrenos limpiado');
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
  final weeklyWatchlistReminderService = WeeklyWatchlistReminderService.instance;
  final movieReleaseService = MovieReleaseNotificationService.instance;

  /// Inicia todos los servicios de notificaciones
  Future<void> startAllServices({List<Person>? favoriteActors}) async {
    _logger.info('Iniciando todos los servicios de notificaciones');

    newMovieService.startMonitoring();
    recommendationService.startRecommendationService();
    trendingMoviesService.startTrendingMonitoring();
    weeklyWatchlistReminderService.startWeeklyReminders();
    movieReleaseService.startReleaseMonitoring();

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
    weeklyWatchlistReminderService.stopWeeklyReminders();
    movieReleaseService.stopReleaseMonitoring();

    _logger.info('Todos los servicios de notificaciones detenidos');
  }

  /// Limpia todos los historiales de notificaciones
  void clearAllHistories() {
    _logger.info('Limpiando todos los historiales de notificaciones');

    newMovieService.clearNotifiedMovies();
    listUpdateService.clearAllListMonitoring();
    favoriteActorService.clearNotificationHistory();
    trendingMoviesService.clearTrendingHistory();
    movieReleaseService.clearReleaseHistory();

    _logger.info('Todos los historiales de notificaciones limpiados');
  }
}
