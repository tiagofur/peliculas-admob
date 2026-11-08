import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/movie.dart';
import '../../domain/entities/person.dart';
import '../logging/base_logger.dart';
import '../logging/logger_factory.dart';
import 'local_notification_service.dart';
import 'notification_metrics.dart';
import 'notification_preferences.dart';

/// Tipos de notificaciones disponibles
enum NotificationType {
  newMovies,
  recommendations,
  listUpdates,
  favoriteActorNewMovie,
  trendingMovies,
  personalizedRecommendations,
  weeklyWatchlistReminder,
  movieReleaseNotification,
}

/// Prioridad de las notificaciones
enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

/// Configuración de una notificación
class NotificationConfig {
  const NotificationConfig({
    required this.type,
    required this.title,
    required this.body,
    this.data,
    this.priority = NotificationPriority.normal,
    this.scheduledTime,
    this.imageUrl,
    this.actionUrl,
    this.actions,
  });

  factory NotificationConfig.fromJson(Map<String, dynamic> json) =>
      NotificationConfig(
        type: NotificationType.values.firstWhere((e) => e.name == json['type']),
        title: json['title'],
        body: json['body'],
        data: json['data'],
        priority: NotificationPriority.values
            .firstWhere((e) => e.name == json['priority']),
        scheduledTime: json['scheduledTime'] != null
            ? DateTime.parse(json['scheduledTime'])
            : null,
        imageUrl: json['imageUrl'],
        actionUrl: json['actionUrl'],
        actions: json['actions']
            ?.map<NotificationAction>((a) => NotificationAction.fromJson(a))
            .toList(),
      );
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final NotificationPriority priority;
  final DateTime? scheduledTime;
  final String? imageUrl;
  final String? actionUrl;
  final List<NotificationAction>? actions;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'title': title,
        'body': body,
        'data': data,
        'priority': priority.name,
        'scheduledTime': scheduledTime?.toIso8601String(),
        'imageUrl': imageUrl,
        'actionUrl': actionUrl,
        'actions': actions?.map((a) => a.toJson()).toList(),
      };
}

/// Acción de notificación
class NotificationAction {
  const NotificationAction({
    required this.id,
    required this.title,
    this.icon,
    this.requiresUnlock = false,
  });

  factory NotificationAction.fromJson(Map<String, dynamic> json) =>
      NotificationAction(
        id: json['id'],
        title: json['title'],
        icon: json['icon'],
        requiresUnlock: json['requiresUnlock'] ?? false,
      );
  final String id;
  final String title;
  final String? icon;
  final bool requiresUnlock;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'icon': icon,
        'requiresUnlock': requiresUnlock,
      };
}

/// Preferencias de notificaciones del usuario
class NotificationPreferences {
  const NotificationPreferences({
    this.enabled = true,
    this.typeEnabled = const {},
    this.quietHoursStart,
    this.quietHoursEnd,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.maxDailyNotifications = 10,
    this.favoriteGenres = const [],
    this.favoriteActors = const [],
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    final typeEnabledMap = <NotificationType, bool>{};
    if (json['typeEnabled'] != null) {
      (json['typeEnabled'] as Map<String, dynamic>).forEach((key, value) {
        final type = NotificationType.values.firstWhere((e) => e.name == key);
        typeEnabledMap[type] = value;
      });
    }

    TimeOfDay? parseTimeOfDay(String? timeString) {
      if (timeString == null) return null;
      final parts = timeString.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    return NotificationPreferences(
      enabled: json['enabled'] ?? true,
      typeEnabled: typeEnabledMap,
      quietHoursStart: parseTimeOfDay(json['quietHoursStart']),
      quietHoursEnd: parseTimeOfDay(json['quietHoursEnd']),
      soundEnabled: json['soundEnabled'] ?? true,
      vibrationEnabled: json['vibrationEnabled'] ?? true,
      maxDailyNotifications: json['maxDailyNotifications'] ?? 10,
      favoriteGenres: List<String>.from(json['favoriteGenres'] ?? []),
      favoriteActors: List<String>.from(json['favoriteActors'] ?? []),
    );
  }
  final bool enabled;
  final Map<NotificationType, bool> typeEnabled;
  final TimeOfDay? quietHoursStart;
  final TimeOfDay? quietHoursEnd;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final int maxDailyNotifications;
  final List<String> favoriteGenres;
  final List<String> favoriteActors;

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'typeEnabled': typeEnabled.map((k, v) => MapEntry(k.name, v)),
        'quietHoursStart': quietHoursStart != null
            ? '${quietHoursStart?.hour}:${quietHoursStart?.minute}'
            : null,
        'quietHoursEnd': quietHoursEnd != null
            ? '${quietHoursEnd?.hour}:${quietHoursEnd?.minute}'
            : null,
        'soundEnabled': soundEnabled,
        'vibrationEnabled': vibrationEnabled,
        'maxDailyNotifications': maxDailyNotifications,
        'favoriteGenres': favoriteGenres,
        'favoriteActors': favoriteActors,
      };

  NotificationPreferences copyWith({
    bool? enabled,
    Map<NotificationType, bool>? typeEnabled,
    TimeOfDay? quietHoursStart,
    TimeOfDay? quietHoursEnd,
    bool? soundEnabled,
    bool? vibrationEnabled,
    int? maxDailyNotifications,
    List<String>? favoriteGenres,
    List<String>? favoriteActors,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      typeEnabled: typeEnabled ?? this.typeEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      maxDailyNotifications:
          maxDailyNotifications ?? this.maxDailyNotifications,
      favoriteGenres: favoriteGenres ?? this.favoriteGenres,
      favoriteActors: favoriteActors ?? this.favoriteActors,
    );
  }
}

/// Gestor inteligente de notificaciones
class NotificationManager {
  /// Constructor público para compatibilidad
  NotificationManager();
  NotificationManager._();

  static NotificationManager? _instance;
  static NotificationManager get instance =>
      _instance ??= NotificationManager._();

  // Logger para debugging
  void _log(String message) {
    LoggerFactory.debug(message, category: LogCategory.notifications);
  }

  final fln.FlutterLocalNotificationsPlugin _localNotifications =
      fln.FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _firebaseMessaging;
  SharedPreferences? _prefs;
  LocalNotificationService? _localNotificationService;
  NotificationMetricsService? _metricsService;

  NotificationPreferences _preferences = const NotificationPreferences();
  final Map<String, Timer> _scheduledNotifications = {};
  int _dailyNotificationCount = 0;
  DateTime _lastResetDate = DateTime.now();

  /// Inicializa el sistema de notificaciones
  Future<void> initialize() async {
    try {
      _log('Inicializando sistema de notificaciones');

      // Inicializar SharedPreferences
      _prefs = await SharedPreferences.getInstance();
      await _loadPreferences();

      // Inicializar servicio de métricas
      _metricsService = NotificationMetricsService.instance;
      if (_metricsService != null) {
        await _metricsService?.initialize();
      }

      // Inicializar servicio de notificaciones locales
      _localNotificationService = LocalNotificationService.instance;
      if (_localNotificationService != null) {
        await _localNotificationService?.initialize();
      }

      // Inicializar notificaciones locales
      await _initializeLocalNotifications();

      // Inicializar Firebase Messaging si está disponible
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await _initializeFirebaseMessaging();
      }

      // Resetear contador diario si es necesario
      _resetDailyCountIfNeeded();

      _log('Sistema de notificaciones inicializado correctamente');
    } catch (e) {
      _log('Error inicializando notificaciones: $e');
    }
  }

  /// Obtiene el servicio de preferencias
  NotificationPreferencesService get preferencesService =>
      NotificationPreferencesService.instance;

  /// Inicializa las notificaciones locales
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        fln.AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = fln.DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = fln.InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Solicitar permisos en Android 13+
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              fln.AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  /// Inicializa Firebase Cloud Messaging
  Future<void> _initializeFirebaseMessaging() async {
    try {
      _firebaseMessaging = FirebaseMessaging.instance;

      // Solicitar permisos
      final messaging = _firebaseMessaging;
      if (messaging == null) return;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        _log('Permisos de notificaciones push concedidos');

        // Registrar la instancia con FCM (v17+). El FID llega por
        // onRegistered y es el identificador de envío directo.
        await messaging.register();
        messaging.onRegistered.listen((fid) {
          _log('FCM registrado. Installation ID (FID): $fid');
        });

        // Configurar handlers
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
        FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

        // Manejar notificación que abrió la app
        final initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageOpenedApp(initialMessage);
        }
      } else {
        _log('Permisos de notificaciones push denegados');
      }
    } catch (e) {
      _log('Error inicializando Firebase Messaging: $e');
    }
  }

  /// Maneja mensajes en primer plano
  void _handleForegroundMessage(RemoteMessage message) {
    _log('Mensaje recibido en primer plano: ${message.messageId}');

    // Mostrar notificación local
    final notification = message.notification;
    if (notification != null) {
      _showLocalNotification(
        NotificationConfig(
          type: _getNotificationTypeFromData(message.data),
          title: notification.title ?? 'Nueva notificación',
          body: notification.body ?? '',
          data: message.data,
          imageUrl: notification.android?.imageUrl,
        ),
      );
    }
  }

  /// Maneja cuando se toca una notificación que abre la app
  void _handleMessageOpenedApp(RemoteMessage message) {
    _log('App abierta desde notificación: ${message.messageId}');
    _handleNotificationAction(message.data);
  }

  /// Handler para mensajes en segundo plano
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    LoggerFactory.debug(
        'Mensaje recibido en segundo plano: ${message.messageId}',
        category: LogCategory.notifications);
  }

  /// Maneja cuando se toca una notificación local
  void _onNotificationTapped(fln.NotificationResponse response) {
    _log('Notificación local tocada: ${response.id}');

    final payload = response.payload;
    if (payload != null) {
      final data = jsonDecode(payload);
      _handleNotificationAction(data);
    }
  }

  /// Maneja las acciones de las notificaciones
  void _handleNotificationAction(Map<String, dynamic> data) {
    final actionUrl = data['actionUrl'] as String?;
    if (actionUrl != null) {
      // Navegar a la URL especificada
      _log('Navegando a: $actionUrl');
      // Aquí se implementaría la navegación usando el router de la app
    }
  }

  /// Programa una notificación inteligente
  Future<void> scheduleIntelligentNotification(
      NotificationConfig config) async {
    if (!_shouldShowNotification(config)) {
      _log('Notificación filtrada: ${config.type.name}');
      return;
    }

    try {
      // Verificar preferencias del usuario
      if (!await preferencesService.canSendNotification(config.type)) {
        _log(
            'Notificación omitida por preferencias del usuario: ${config.type}');
        return;
      }

      // Aplicar horario inteligente si no se especifica uno
      final scheduledTime =
          config.scheduledTime ?? await _calculateOptimalTime(config.type);

      final updatedConfig = NotificationConfig(
        type: config.type,
        title: config.title,
        body: config.body,
        data: config.data,
        imageUrl: config.imageUrl,
        actionUrl: config.actionUrl,
        priority: config.priority,
        scheduledTime: scheduledTime,
        actions: config.actions,
      );

      if (updatedConfig.scheduledTime != null) {
        await _scheduleNotification(updatedConfig);
      } else {
        await _showImmediateNotification(updatedConfig);
      }

      await preferencesService.incrementDailyCount();

      _log('Notificación inteligente programada: ${config.title}');
    } catch (e) {
      _log('Error programando notificación inteligente: $e');
    }
  }

  /// Verifica si se debe mostrar una notificación
  bool _shouldShowNotification(NotificationConfig config) {
    // Verificar si las notificaciones están habilitadas
    if (!_preferences.enabled) return false;

    // Verificar si el tipo específico está habilitado
    if (_preferences.typeEnabled[config.type] == false) return false;

    // Verificar límite diario
    if (_dailyNotificationCount >= _preferences.maxDailyNotifications) {
      return false;
    }

    // Verificar horas de silencio
    if (_isInQuietHours()) return false;

    return true;
  }

  /// Verifica si estamos en horas de silencio
  bool _isInQuietHours() {
    if (_preferences.quietHoursStart == null ||
        _preferences.quietHoursEnd == null) {
      return false;
    }

    final now = TimeOfDay.now();
    final start = _preferences.quietHoursStart;
    final end = _preferences.quietHoursEnd;
    if (start == null || end == null) return false;

    // Convertir a minutos para comparación más fácil
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes <= endMinutes) {
      // Mismo día
      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    } else {
      // Cruza medianoche
      return nowMinutes >= startMinutes || nowMinutes <= endMinutes;
    }
  }

  /// Programa una notificación para más tarde
  Future<void> _scheduleNotification(NotificationConfig config) async {
    final scheduledTime = config.scheduledTime;
    if (scheduledTime == null) {
      await _showImmediateNotification(config);
      return;
    }
    final delay = scheduledTime.difference(DateTime.now());

    if (delay.isNegative) {
      _log('Tiempo de programación en el pasado, mostrando inmediatamente');
      await _showImmediateNotification(config);
      return;
    }

    final timerId =
        '${config.type.name}_${DateTime.now().millisecondsSinceEpoch}';

    _scheduledNotifications[timerId] = Timer(delay, () async {
      await _showImmediateNotification(config);
      _scheduledNotifications.remove(timerId);
    });

    _log('Notificación programada para: $scheduledTime');
  }

  /// Muestra una notificación inmediatamente
  Future<void> _showImmediateNotification(NotificationConfig config) async {
    if (!_shouldShowNotification(config)) return;

    final notificationId = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      // Registrar métrica de envío
      await _metricsService?.recordNotificationSent(
        notificationId: notificationId,
        type: config.type,
        scheduledFor: config.scheduledTime ?? DateTime.now(),
      );

      // Usar el servicio de notificaciones locales si está disponible
      if (_localNotificationService != null &&
          (_localNotificationService?.isInitialized ?? false)) {
        final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await _localNotificationService?.showNotification(
          id: id,
          title: config.title,
          body: config.body,
          payload: jsonEncode({
            'notificationId': notificationId,
            'type': config.type.name,
            'data': config.data,
            'actionUrl': config.actionUrl,
          }),
          priority: config.priority,
          largeIcon: config.imageUrl,
        );
      } else {
        await _showLocalNotification(config, notificationId: notificationId);
      }

      // Registrar entrega exitosa
      await _metricsService?.recordNotificationDelivered(
        notificationId: notificationId,
      );

      _incrementDailyCount();
    } catch (e) {
      // Registrar fallo
      await _metricsService?.recordNotificationFailed(
        notificationId: notificationId,
        reason: e.toString(),
      );
      rethrow;
    }
  }

  /// Muestra una notificación local
  Future<void> _showLocalNotification(NotificationConfig config,
      {String? notificationId}) async {
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final androidDetails = fln.AndroidNotificationDetails(
      config.type.name,
      _getChannelName(config.type),
      channelDescription: _getChannelDescription(config.type),
      importance: _getImportance(config.priority),
      priority: _getPriority(config.priority),
      enableVibration: _preferences.vibrationEnabled,
      playSound: _preferences.soundEnabled,
      // largeIcon: config.imageUrl != null ? config.imageUrl : null, // Comentado temporalmente
      actions: config.actions
          ?.map((action) => fln.AndroidNotificationAction(
                action.id,
                action.title,
                icon: action.icon != null
                    ? fln.DrawableResourceAndroidBitmap(action.icon!)
                    : null,
                contextual: true,
              ))
          .toList(),
    );

    const iosDetails = fln.DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = fln.NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      'notificationId':
          notificationId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'type': config.type.name,
      'data': config.data,
      'actionUrl': config.actionUrl,
    });

    await _localNotifications.show(
      id: id,
      title: config.title,
      body: config.body,
      notificationDetails: details,
      payload: payload,
    );

    _log('Notificación local mostrada: ${config.title}');
  }

  /// Obtiene el nombre del canal para un tipo de notificación
  String _getChannelName(NotificationType type) {
    switch (type) {
      case NotificationType.newMovies:
        return 'Nuevas Películas';
      case NotificationType.recommendations:
        return 'Recomendaciones';
      case NotificationType.listUpdates:
        return 'Actualizaciones de Listas';
      case NotificationType.favoriteActorNewMovie:
        return 'Actores Favoritos';
      case NotificationType.trendingMovies:
        return 'Películas Populares';
      case NotificationType.personalizedRecommendations:
        return 'Recomendaciones Personalizadas';
      case NotificationType.weeklyWatchlistReminder:
        return 'Recordatorios de Lista';
      case NotificationType.movieReleaseNotification:
        return 'Estrenos de Películas';
    }
  }

  /// Obtiene la descripción del canal para un tipo de notificación
  String _getChannelDescription(NotificationType type) {
    switch (type) {
      case NotificationType.newMovies:
        return 'Notificaciones sobre nuevas películas disponibles';
      case NotificationType.recommendations:
        return 'Recomendaciones de películas basadas en tus gustos';
      case NotificationType.listUpdates:
        return 'Actualizaciones en tus listas de películas';
      case NotificationType.favoriteActorNewMovie:
        return 'Nuevas películas de tus actores favoritos';
      case NotificationType.trendingMovies:
        return 'Películas que están siendo populares';
      case NotificationType.personalizedRecommendations:
        return 'Recomendaciones personalizadas especialmente para ti';
      case NotificationType.weeklyWatchlistReminder:
        return 'Recordatorios semanales de películas en tu lista pendiente';
      case NotificationType.movieReleaseNotification:
        return 'Notificaciones de estrenos de películas que sigues';
    }
  }

  /// Convierte la prioridad a importancia de Android
  fln.Importance _getImportance(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return fln.Importance.low;
      case NotificationPriority.normal:
        return fln.Importance.defaultImportance;
      case NotificationPriority.high:
        return fln.Importance.high;
      case NotificationPriority.urgent:
        return fln.Importance.max;
    }
  }

  /// Convierte la prioridad a prioridad de Android
  fln.Priority _getPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return fln.Priority.low;
      case NotificationPriority.normal:
        return fln.Priority.defaultPriority;
      case NotificationPriority.high:
        return fln.Priority.high;
      case NotificationPriority.urgent:
        return fln.Priority.max;
    }
  }

  /// Obtiene el tipo de notificación desde los datos
  NotificationType _getNotificationTypeFromData(Map<String, dynamic> data) {
    final typeString = data['type'] as String?;
    if (typeString != null) {
      try {
        return NotificationType.values.firstWhere((e) => e.name == typeString);
      } catch (e) {
        _log('Tipo de notificación desconocido: $typeString');
      }
    }
    return NotificationType.recommendations;
  }

  /// Incrementa el contador diario de notificaciones
  void _incrementDailyCount() {
    _resetDailyCountIfNeeded();
    _dailyNotificationCount++;
    _prefs?.setInt('daily_notification_count', _dailyNotificationCount);
    _prefs?.setString('last_reset_date', _lastResetDate.toIso8601String());
  }

  /// Resetea el contador diario si es un nuevo día
  void _resetDailyCountIfNeeded() {
    final today = DateTime.now();
    if (!_isSameDay(_lastResetDate, today)) {
      _dailyNotificationCount = 0;
      _lastResetDate = today;
      _prefs?.setInt('daily_notification_count', 0);
      _prefs?.setString('last_reset_date', today.toIso8601String());
    }
  }

  /// Verifica si dos fechas son del mismo día
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Carga las preferencias del usuario
  Future<void> _loadPreferences() async {
    final prefsJson = _prefs?.getString('notification_preferences');
    if (prefsJson != null) {
      try {
        final prefsMap = jsonDecode(prefsJson) as Map<String, dynamic>;
        _preferences = NotificationPreferences.fromJson(prefsMap);
      } catch (e) {
        _log('Error cargando preferencias de notificaciones: $e');
      }
    }

    // Cargar contador diario
    _dailyNotificationCount = _prefs?.getInt('daily_notification_count') ?? 0;
    final lastResetString = _prefs?.getString('last_reset_date');
    if (lastResetString != null) {
      _lastResetDate = DateTime.parse(lastResetString);
    }
  }

  /// Guarda las preferencias del usuario
  Future<void> savePreferences(NotificationPreferences preferences) async {
    _preferences = preferences;
    final prefsJson = jsonEncode(preferences.toJson());
    await _prefs?.setString('notification_preferences', prefsJson);
    _log('Preferencias de notificaciones guardadas');
  }

  /// Obtiene las preferencias actuales
  NotificationPreferences get preferences => _preferences;

  /// Cancela todas las notificaciones programadas
  void cancelAllScheduledNotifications() {
    for (final timer in _scheduledNotifications.values) {
      timer.cancel();
    }
    _scheduledNotifications.clear();
    _log('Todas las notificaciones programadas canceladas');
  }

  /// Cancela todas las notificaciones locales
  Future<void> cancelAllLocalNotifications() async {
    await _localNotifications.cancelAll();
    _log('Todas las notificaciones locales canceladas');
  }

  /// Suscribe a un tópico de FCM
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging?.subscribeToTopic(topic);
    _log('Suscrito al tópico: $topic');
  }

  /// Se desuscribe de un tópico de FCM
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging?.unsubscribeFromTopic(topic);
    _log('Desuscrito del tópico: $topic');
  }

  /// Calcula el momento óptimo para enviar una notificación
  Future<DateTime> _calculateOptimalTime(NotificationType type) async {
    final now = DateTime.now();
    final preferences = await preferencesService.loadPreferences();

    // Si hay un horario configurado, respetarlo
    if (preferences.schedule.enabled) {
      final startTime = preferences.schedule.startTime;

      // Si estamos dentro del horario permitido, enviar ahora
      if (preferences.schedule.isWithinSchedule(now)) {
        return now;
      }

      // Si no, programar para el próximo horario permitido
      var nextAllowedTime = DateTime(
          now.year, now.month, now.day, startTime.hour, startTime.minute);

      // Si ya pasó la hora de hoy, programar para mañana
      if (nextAllowedTime.isBefore(now)) {
        nextAllowedTime = nextAllowedTime.add(const Duration(days: 1));
      }

      return nextAllowedTime;
    }

    // Horarios por defecto según el tipo
    switch (type) {
      case NotificationType.newMovies:
        // Enviar nuevas películas por la tarde
        return DateTime(now.year, now.month, now.day, 18, 0);
      case NotificationType.personalizedRecommendations:
        // Enviar recomendaciones por la noche
        return DateTime(now.year, now.month, now.day, 20, 0);
      case NotificationType.recommendations:
        // Enviar recomendaciones generales por la tarde
        return DateTime(now.year, now.month, now.day, 19, 0);
      case NotificationType.listUpdates:
        // Enviar actualizaciones de lista inmediatamente
        return now;
      case NotificationType.favoriteActorNewMovie:
        // Enviar noticias de actores favoritos por la mañana
        return DateTime(now.year, now.month, now.day, 10, 0);
      case NotificationType.trendingMovies:
        // Enviar películas populares los fines de semana
        final daysUntilSaturday = (6 - now.weekday) % 7;
        return DateTime(
            now.year, now.month, now.day + daysUntilSaturday, 12, 0);
      case NotificationType.weeklyWatchlistReminder:
        // Los recordatorios semanales se manejan en su propio servicio
        // Programar para el próximo domingo a las 10:00 AM
        int daysUntilSunday = (DateTime.sunday - now.weekday) % 7;
        if (daysUntilSunday == 0 && now.hour >= 10) {
          daysUntilSunday = 7;
        }
        return DateTime(now.year, now.month, now.day + daysUntilSunday, 10, 0);
      case NotificationType.movieReleaseNotification:
        // Notificaciones de estreno se envían inmediatamente cuando se detectan
        return now;
    }
  }

  /// Muestra una notificación local pública (para uso externo)
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotificationPriority priority = NotificationPriority.normal,
  }) async {
    final config = NotificationConfig(
      type: NotificationType.recommendations,
      title: title,
      body: body,
      data: payload != null ? {'payload': payload} : null,
      priority: priority,
    );

    await _showLocalNotification(config);
  }

  /// Acceso al servicio de métricas
  NotificationMetricsService? get metricsService => _metricsService;

  /// Limpia recursos
  void dispose() {
    cancelAllScheduledNotifications();
    _localNotificationService?.dispose();
    _metricsService?.dispose();
    _localNotificationService = null;
    _metricsService = null;
    _instance = null;
  }
}

/// Extensión para crear notificaciones específicas
extension NotificationManagerExtensions on NotificationManager {
  /// Notifica sobre una nueva película
  Future<void> notifyNewMovie(Movie movie) async {
    await scheduleIntelligentNotification(
      NotificationConfig(
        type: NotificationType.newMovies,
        title: '🎬 Nueva película disponible',
        body: '"${movie.title}" ya está disponible. ¡No te la pierdas!',
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
  }

  /// Notifica recomendaciones personalizadas
  Future<void> notifyPersonalizedRecommendations(List<Movie> movies) async {
    if (movies.isEmpty) return;

    final movie = movies.first;
    final additionalCount = movies.length - 1;

    await scheduleIntelligentNotification(
      NotificationConfig(
        type: NotificationType.personalizedRecommendations,
        title: '✨ Recomendaciones para ti',
        body: additionalCount > 0
            ? 'Te recomendamos "${movie.title}" y $additionalCount películas más'
            : 'Te recomendamos "${movie.title}"',
        data: {
          'recommendedMovies': movies.map((m) => m.id.toString()).toList(),
        },
        imageUrl: movie.posterPath,
        actionUrl: '/recommendations',
        priority: NotificationPriority.high,
        actions: [
          const NotificationAction(
            id: 'view_all',
            title: 'Ver todas',
          ),
          const NotificationAction(
            id: 'dismiss',
            title: 'Descartar',
          ),
        ],
      ),
    );
  }

  /// Notifica sobre actualizaciones en listas
  Future<void> notifyListUpdate(String listName, int newItemsCount) async {
    await scheduleIntelligentNotification(
      NotificationConfig(
        type: NotificationType.listUpdates,
        title: '📋 Lista actualizada',
        body: 'Se han agregado $newItemsCount nuevos elementos a "$listName"',
        data: {
          'listName': listName,
          'newItemsCount': newItemsCount.toString(),
        },
        actionUrl: '/lists',
        priority: NotificationPriority.normal,
        actions: [
          const NotificationAction(
            id: 'view_list',
            title: 'Ver lista',
          ),
        ],
      ),
    );
  }

  /// Notifica sobre nueva película de actor favorito
  Future<void> notifyFavoriteActorNewMovie(Person actor, Movie movie) async {
    await scheduleIntelligentNotification(
      NotificationConfig(
        type: NotificationType.favoriteActorNewMovie,
        title: '⭐ ${actor.name} en nueva película',
        body:
            '"${movie.title}" protagonizada por ${actor.name} ya está disponible',
        data: {
          'actorId': actor.name, // Using name as identifier
          'movieId': movie.id.toString(),
        },
        imageUrl: movie.posterPath,
        actionUrl: '/movie/${movie.id}',
        priority: NotificationPriority.high,
        actions: [
          const NotificationAction(
            id: 'view_movie',
            title: 'Ver película',
          ),
          const NotificationAction(
            id: 'view_actor',
            title: 'Ver actor',
          ),
        ],
      ),
    );
  }
}
