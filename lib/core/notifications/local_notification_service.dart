import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../core/logging/logger_factory.dart';
import 'notification_manager.dart';

class LocalNotificationService {
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();

  static LocalNotificationService get instance => _instance;

  FlutterLocalNotificationsPlugin? _flutterLocalNotificationsPlugin;
  bool _isInitialized = false;
  GlobalKey<NavigatorState>? _globalNavigatorKey;

  static const String _scheduledNotificationsKey = 'scheduled_notifications';
  static const String _notificationCounterKey = 'notification_counter';

  bool get isInitialized => _isInitialized;

  /// Establece la clave de navegación global para permitir navegación desde notificaciones
  void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _globalNavigatorKey = navigatorKey;
    if (kDebugMode) {
      LoggerFactory.info('🔑 Navigator key configurado para notificaciones');
    }
  }

  /// Inicializa el servicio de notificaciones locales
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Inicializar timezone
      tz.initializeTimeZones();

      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      // Configuración para Android
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      // Configuración para iOS
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      final plugin = _flutterLocalNotificationsPlugin;
      if (plugin != null) {
        await plugin.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: _onNotificationTapped,
        );
      }

      // Solicitar permisos en Android 13+
      if (Platform.isAndroid) {
        await _requestAndroidPermissions();
      }

      _isInitialized = true;

      if (kDebugMode) {
        LoggerFactory.info('✅ Local notification service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error(
            '❌ Error initializing local notification service: $e');
      }
      rethrow;
    }
  }

  /// Solicita permisos para Android 13+
  Future<void> _requestAndroidPermissions() async {
    if (!Platform.isAndroid) return;

    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              ?.resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
        await androidImplementation.requestExactAlarmsPermission();
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error requesting Android permissions: $e');
      }
    }
  }

  /// Maneja el tap en una notificación local
  void _onNotificationTapped(NotificationResponse notificationResponse) {
    if (kDebugMode) {
      LoggerFactory.info(
          'Local notification tapped: ${notificationResponse.payload}');
    }

    // Procesar el payload y navegar según corresponda
    if (notificationResponse.payload != null) {
      try {
        final payload = notificationResponse.payload;
        if (payload != null) {
          final data = jsonDecode(payload);
          _handleNotificationNavigation(data);
        }
      } catch (e) {
        if (kDebugMode) {
          LoggerFactory.error('Error parsing notification payload: $e');
        }
      }
    }
  }

  /// Maneja la navegación basada en el payload de la notificación
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    switch (type) {
      case 'movie_reminder':
        final movieId = data['movieId'] as String?;
        if (movieId != null) {
          if (kDebugMode) {
            LoggerFactory.info('Navigate to movie: $movieId');
          }
          _navigateToMovie(movieId);
        }
        break;
      case 'daily_recommendation':
        if (kDebugMode) {
          LoggerFactory.info('Navigate to daily recommendations');
        }
        _navigateToRecommendations();
        break;
      case 'list_reminder':
        final listId = data['listId'] as String?;
        if (listId != null) {
          if (kDebugMode) {
            LoggerFactory.info('Navigate to list: $listId');
          }
          _navigateToList(listId);
        }
        break;
      default:
        if (kDebugMode) {
          LoggerFactory.info('Unknown notification type: $type');
        }
        break;
    }
  }

  /// Navega a los detalles de una película específica
  void _navigateToMovie(String movieId) {
    // Necesitamos usar el contexto de navegación global
    final context = _globalNavigatorKey?.currentContext;
    if (context != null && context.mounted) {
      try {
        context.go('/movie/$movieId');
        if (kDebugMode) {
          LoggerFactory.info('✅ Navegando a película: $movieId');
        }
      } catch (e) {
        if (kDebugMode) {
          LoggerFactory.error('❌ Error navegando a película: $e');
        }
      }
    } else {
      if (kDebugMode) {
        LoggerFactory.warning('⚠️ No hay contexto de navegación disponible');
      }
    }
  }

  /// Navega a la pantalla principal con foco en recomendaciones
  void _navigateToRecommendations() {
    final context = _globalNavigatorKey?.currentContext;
    if (context != null && context.mounted) {
      try {
        // Navegar a la pantalla principal donde están las recomendaciones
        context.go('/');
        if (kDebugMode) {
          LoggerFactory.info('✅ Navegando a recomendaciones diarias');
        }
      } catch (e) {
        if (kDebugMode) {
          LoggerFactory.error('❌ Error navegando a recomendaciones: $e');
        }
      }
    } else {
      if (kDebugMode) {
        LoggerFactory.warning('⚠️ No hay contexto de navegación disponible');
      }
    }
  }

  /// Navega a una lista específica en Mi Biblioteca
  void _navigateToList(String listId) {
    final context = _globalNavigatorKey?.currentContext;
    if (context != null && context.mounted) {
      try {
        context.go('/my-library/lists/$listId');
        if (kDebugMode) {
          LoggerFactory.info('✅ Navegando a lista: $listId');
        }
      } catch (e) {
        if (kDebugMode) {
          LoggerFactory.error('❌ Error navegando a lista: $e');
        }
      }
    } else {
      if (kDebugMode) {
        LoggerFactory.warning('⚠️ No hay contexto de navegación disponible');
      }
    }
  }

  /// Muestra una notificación local inmediata
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotificationPriority priority = NotificationPriority.normal,
    String? largeIcon,
    String? bigPicture,
  }) async {
    if (!_isInitialized || _flutterLocalNotificationsPlugin == null) {
      if (kDebugMode) {
        LoggerFactory.error('Local notification service not initialized');
      }
      return;
    }

    try {
      final androidDetails = AndroidNotificationDetails(
        'peliculas_channel',
        'Peliculas Notifications',
        channelDescription: 'Notificaciones de la app Peliculas',
        importance: _getAndroidImportance(priority),
        priority: _getAndroidPriority(priority),
        showWhen: true,
        largeIcon: largeIcon != null ? FilePathAndroidBitmap(largeIcon) : null,
        styleInformation: bigPicture != null
            ? BigPictureStyleInformation(
                FilePathAndroidBitmap(bigPicture),
                contentTitle: title,
                summaryText: body,
              )
            : BigTextStyleInformation(body),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final plugin = _flutterLocalNotificationsPlugin;
      if (plugin != null) {
        await plugin.show(
          id,
          title,
          body,
          notificationDetails,
          payload: payload,
        );
      }

      if (kDebugMode) {
        LoggerFactory.info('Local notification shown: $title');
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error showing local notification: $e');
      }
    }
  }

  /// Programa una notificación local para una fecha específica
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    NotificationPriority priority = NotificationPriority.normal,
    String? largeIcon,
    String? bigPicture,
  }) async {
    if (!_isInitialized || _flutterLocalNotificationsPlugin == null) {
      if (kDebugMode) {
        LoggerFactory.error('Local notification service not initialized');
      }
      return;
    }

    try {
      final androidDetails = AndroidNotificationDetails(
        'peliculas_scheduled_channel',
        'Peliculas Scheduled Notifications',
        channelDescription: 'Notificaciones programadas de la app Peliculas',
        importance: _getAndroidImportance(priority),
        priority: _getAndroidPriority(priority),
        showWhen: true,
        largeIcon: largeIcon != null ? FilePathAndroidBitmap(largeIcon) : null,
        styleInformation: bigPicture != null
            ? BigPictureStyleInformation(
                FilePathAndroidBitmap(bigPicture),
                contentTitle: title,
                summaryText: body,
              )
            : BigTextStyleInformation(body),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final plugin = _flutterLocalNotificationsPlugin;
      if (plugin != null) {
        await plugin.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(scheduledDate, tz.local),
          notificationDetails,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }

      // Guardar la notificación programada
      await _saveScheduledNotification({
        'id': id,
        'title': title,
        'body': body,
        'scheduledDate': scheduledDate.toIso8601String(),
        'payload': payload,
        'priority': priority.toString(),
      });

      if (kDebugMode) {
        LoggerFactory.info('Local notification scheduled for: $scheduledDate');
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error scheduling local notification: $e');
      }
    }
  }

  /// Programa notificaciones recurrentes (diarias, semanales, etc.)
  Future<void> scheduleRepeatingNotification({
    required int id,
    required String title,
    required String body,
    required RepeatInterval repeatInterval,
    String? payload,
    NotificationPriority priority = NotificationPriority.normal,
  }) async {
    if (!_isInitialized || _flutterLocalNotificationsPlugin == null) {
      if (kDebugMode) {
        LoggerFactory.error('Local notification service not initialized');
      }
      return;
    }

    try {
      final androidDetails = AndroidNotificationDetails(
        'peliculas_repeating_channel',
        'Peliculas Repeating Notifications',
        channelDescription: 'Notificaciones recurrentes de la app Peliculas',
        importance: _getAndroidImportance(priority),
        priority: _getAndroidPriority(priority),
        showWhen: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final plugin = _flutterLocalNotificationsPlugin;
      if (plugin != null) {
        await plugin.periodicallyShow(
          id,
          title,
          body,
          repeatInterval,
          notificationDetails,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }

      if (kDebugMode) {
        LoggerFactory.info('Repeating notification scheduled: $repeatInterval');
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error scheduling repeating notification: $e');
      }
    }
  }

  /// Cancela una notificación específica
  Future<void> cancelNotification(int id) async {
    if (!_isInitialized || _flutterLocalNotificationsPlugin == null) return;

    try {
      final plugin = _flutterLocalNotificationsPlugin;
      if (plugin != null) {
        await plugin.cancel(id);
      }
      await _removeScheduledNotification(id);

      if (kDebugMode) {
        LoggerFactory.info('Notification cancelled: $id');
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error cancelling notification: $e');
      }
    }
  }

  /// Cancela todas las notificaciones
  Future<void> cancelAllNotifications() async {
    if (!_isInitialized || _flutterLocalNotificationsPlugin == null) return;

    try {
      final plugin = _flutterLocalNotificationsPlugin;
      if (plugin != null) {
        await plugin.cancelAll();
      }
      await _clearAllScheduledNotifications();

      if (kDebugMode) {
        LoggerFactory.info('All notifications cancelled');
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error cancelling all notifications: $e');
      }
    }
  }

  /// Obtiene las notificaciones pendientes
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_isInitialized || _flutterLocalNotificationsPlugin == null) {
      return [];
    }

    try {
      final plugin = _flutterLocalNotificationsPlugin;
      if (plugin != null) {
        return await plugin.pendingNotificationRequests();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error getting pending notifications: $e');
      }
      return [];
    }
  }

  /// Genera un ID único para notificaciones
  Future<int> generateNotificationId() async {
    final prefs = await SharedPreferences.getInstance();
    final counter = prefs.getInt(_notificationCounterKey) ?? 0;
    final newCounter = counter + 1;
    await prefs.setInt(_notificationCounterKey, newCounter);
    return newCounter;
  }

  /// Guarda información de una notificación programada
  Future<void> _saveScheduledNotification(
      Map<String, dynamic> notification) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scheduledNotifications =
          prefs.getStringList(_scheduledNotificationsKey) ?? [];
      scheduledNotifications.add(jsonEncode(notification));
      await prefs.setStringList(
          _scheduledNotificationsKey, scheduledNotifications);
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error saving scheduled notification: $e');
      }
    }
  }

  /// Remueve una notificación programada de la lista guardada
  Future<void> _removeScheduledNotification(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scheduledNotifications =
          prefs.getStringList(_scheduledNotificationsKey) ?? [];

      scheduledNotifications.removeWhere((notificationJson) {
        try {
          final notification = jsonDecode(notificationJson);
          return notification['id'] == id;
        } catch (e) {
          return false;
        }
      });

      await prefs.setStringList(
          _scheduledNotificationsKey, scheduledNotifications);
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error removing scheduled notification: $e');
      }
    }
  }

  /// Limpia todas las notificaciones programadas guardadas
  Future<void> _clearAllScheduledNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_scheduledNotificationsKey);
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error clearing scheduled notifications: $e');
      }
    }
  }

  /// Convierte NotificationPriority a Importance de Android
  Importance _getAndroidImportance(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Importance.low;
      case NotificationPriority.normal:
        return Importance.defaultImportance;
      case NotificationPriority.high:
        return Importance.high;
      case NotificationPriority.urgent:
        return Importance.max;
    }
  }

  /// Convierte NotificationPriority a Priority de Android
  Priority _getAndroidPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Priority.low;
      case NotificationPriority.normal:
        return Priority.defaultPriority;
      case NotificationPriority.high:
        return Priority.high;
      case NotificationPriority.urgent:
        return Priority.max;
    }
  }

  /// Limpia los recursos del servicio
  void dispose() {
    _flutterLocalNotificationsPlugin = null;
    _isInitialized = false;
  }
}
