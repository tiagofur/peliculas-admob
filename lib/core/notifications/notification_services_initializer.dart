import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/datasources/watchlist_hive_datasource.dart';
import '../../infrastructure/repositories/hybrid_watchlist_repository.dart';
import '../../presentation/providers/hybrid_repositories_provider.dart';
import '../logging/logger_factory.dart';
import 'notification_categories.dart';
import 'notification_manager.dart';

/// Servicio de inicialización de notificaciones para conectar con repositorios
class NotificationServicesInitializer {
  static NotificationServicesInitializer? _instance;
  static NotificationServicesInitializer get instance =>
      _instance ??= NotificationServicesInitializer._();

  NotificationServicesInitializer._();

  final _logger = LoggerFactory.logger;
  bool _initialized = false;

  /// Inicializa todos los servicios de notificaciones y los conecta con los repositorios
  Future<void> initializeWithRepositories({
    required Ref ref,
  }) async {
    if (_initialized) {
      _logger.info('Servicios de notificaciones ya inicializados');
      return;
    }

    try {
      _logger.info('Inicializando servicios de notificaciones con repositorios');

      // 1. Inicializar el NotificationManager principal
      await NotificationManager.instance.initialize();

      // 2. Obtener el repositorio de watchlist desde el provider
      final watchlistRepository = ref.read(watchlistRepositoryProvider) as HybridWatchlistRepository;
      
      // 3. Crear datasource de watchlist para los servicios de notificaciones
      final watchlistDatasource = WatchlistHiveDatasource();
      
      // 4. Configurar servicios de notificaciones con los datasources
      WeeklyWatchlistReminderService.instance.setWatchlistDatasource(watchlistDatasource);
      MovieReleaseNotificationService.instance.setWatchlistDatasource(watchlistDatasource);
      
      // 5. Iniciar todos los servicios de categorías
      await NotificationCategoriesCoordinator.instance.startAllServices();

      _initialized = true;
      _logger.info('Servicios de notificaciones inicializados correctamente');
    } catch (e) {
      _logger.error('Error inicializando servicios de notificaciones: $e');
      rethrow;
    }
  }

  /// Inicializa servicios sin Riverpod (para testing o uso standalone)
  Future<void> initializeStandalone() async {
    if (_initialized) {
      _logger.info('Servicios de notificaciones ya inicializados');
      return;
    }

    try {
      _logger.info('Inicializando servicios de notificaciones standalone');

      // 1. Inicializar el NotificationManager principal
      await NotificationManager.instance.initialize();

      // 2. Crear datasource de watchlist para los servicios de notificaciones
      final watchlistDatasource = WatchlistHiveDatasource();
      
      // 3. Configurar servicios de notificaciones con los datasources
      WeeklyWatchlistReminderService.instance.setWatchlistDatasource(watchlistDatasource);
      MovieReleaseNotificationService.instance.setWatchlistDatasource(watchlistDatasource);
      
      // 4. Iniciar todos los servicios de categorías
      await NotificationCategoriesCoordinator.instance.startAllServices();

      _initialized = true;
      _logger.info('Servicios de notificaciones standalone inicializados correctamente');
    } catch (e) {
      _logger.error('Error inicializando servicios de notificaciones standalone: $e');
      rethrow;
    }
  }

  /// Detiene todos los servicios de notificaciones
  void stopAllServices() {
    _logger.info('Deteniendo todos los servicios de notificaciones');
    
    NotificationCategoriesCoordinator.instance.stopAllServices();
    
    _initialized = false;
    _logger.info('Servicios de notificaciones detenidos');
  }

  /// Reinicia todos los servicios de notificaciones
  Future<void> restartServices({Ref? ref}) async {
    _logger.info('Reiniciando servicios de notificaciones');
    
    stopAllServices();
    
    if (ref != null) {
      await initializeWithRepositories(ref: ref);
    } else {
      await initializeStandalone();
    }
  }

  /// Obtiene un reporte de estado de todos los servicios
  Map<String, dynamic> getServicesStatus() {
    final coordinator = NotificationCategoriesCoordinator.instance;
    final notificationManager = NotificationManager.instance;
    final metricsService = notificationManager.metricsService;

    return {
      'initialized': _initialized,
      'notificationManagerInitialized': notificationManager != null,
      'metricsServiceInitialized': metricsService != null,
      'weeklyReminderServiceActive': coordinator.weeklyWatchlistReminderService.lastReminderSent != null,
      'releaseServiceActive': true, // MovieReleaseNotificationService está siempre activo una vez iniciado
      'healthReport': metricsService?.getHealthReport(),
      'lastMetricsUpdate': DateTime.now().toIso8601String(),
    };
  }

  /// Envía un recordatorio de watchlist manual (para testing)
  Future<void> sendTestWatchlistReminder() async {
    if (!_initialized) {
      throw StateError('Servicios de notificaciones no inicializados');
    }
    
    _logger.info('Enviando recordatorio de watchlist de prueba');
    await WeeklyWatchlistReminderService.instance.sendManualReminder();
  }

  /// Verifica si hay estrenos próximos manualmente (para testing)
  Future<void> checkTestReleases() async {
    if (!_initialized) {
      throw StateError('Servicios de notificaciones no inicializados');
    }
    
    _logger.info('Verificando estrenos de prueba');
    // El servicio se ejecuta automáticamente, pero podríamos exponer un método público si fuera necesario
  }

  /// Obtiene métricas de entrega de las últimas 24 horas
  Map<String, dynamic>? getLast24HoursMetrics() {
    final metricsService = NotificationManager.instance.metricsService;
    return metricsService?.last24HoursStats.toJson();
  }

  /// Verifica si el sistema de notificaciones está saludable
  bool get isHealthy {
    if (!_initialized) return false;
    
    final metricsService = NotificationManager.instance.metricsService;
    if (metricsService == null) return false;
    
    return metricsService.isDeliveryRateHealthy && metricsService.isLatencyHealthy;
  }

  /// Verifica si hay notificaciones habilitadas
  bool get hasNotificationsEnabled {
    // Esto requeriría acceso a las preferencias del usuario
    // Por ahora retorna true como placeholder
    return true;
  }
}