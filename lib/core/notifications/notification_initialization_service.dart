import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/logger_factory.dart';
import 'notification_manager.dart';
import 'notification_preferences.dart';
import 'notification_services_initializer.dart';

class NotificationInitializationService {
  factory NotificationInitializationService() => _instance;
  NotificationInitializationService._internal();
  static final NotificationInitializationService _instance =
      NotificationInitializationService._internal();

  static NotificationInitializationService get instance => _instance;

  bool _isInitialized = false;
  NotificationManager? _notificationManager;
  GlobalKey<NavigatorState>? _globalNavigatorKey;

  bool get isInitialized => _isInitialized;
  NotificationManager? get notificationManager => _notificationManager;
  
  /// Getter para acceder al cliente de Supabase
  SupabaseClient get _supabase => Supabase.instance.client;

  /// Establece la clave de navegación global para permitir navegación desde notificaciones
  void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _globalNavigatorKey = navigatorKey;
    if (kDebugMode) {
      LoggerFactory.info(
          '🔑 Navigator key configurado para notificaciones push');
    }
  }

  /// Inicializa todo el sistema de notificaciones
  Future<void> initialize() async {
    if (_isInitialized) {
      if (kDebugMode) {
        LoggerFactory.info('Notification system already initialized');
      }
      return;
    }

    try {
      if (kDebugMode) {
        LoggerFactory.info('🔔 Initializing notification system...');
      }

      // Inicializar el manager de notificaciones
      _notificationManager = NotificationManager.instance;
      final manager = _notificationManager;
      if (manager != null) {
        await manager.initialize();
      }

      // Configurar listeners de Firebase Messaging
      await _setupFirebaseMessagingListeners();

      // Configurar notificaciones locales
      await _setupLocalNotifications();

      // Cargar preferencias del usuario
      await _loadUserPreferences();

      _isInitialized = true;

      if (kDebugMode) {
        LoggerFactory.info('✅ Notification system initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('❌ Error initializing notification system: $e');
      }
      rethrow;
    }
  }

  /// Inicializa todo el sistema de notificaciones con Riverpod
  Future<void> initializeWithRiverpod(Ref ref) async {
    await initialize(); // Inicialización básica primero

    if (!_isInitialized) return;

    try {
      if (kDebugMode) {
        LoggerFactory.info(
            '🔔 Inicializando servicios específicos de notificaciones...');
      }

      // Inicializar servicios específicos conectados a repositorios
      await NotificationServicesInitializer.instance
          .initializeWithRepositories(ref: ref);

      if (kDebugMode) {
        LoggerFactory.info(
            '✅ Servicios específicos de notificaciones inicializados');
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('❌ Error inicializando servicios específicos: $e');
      }
      // No re-lanzar el error ya que la inicialización básica fue exitosa
    }
  }

  /// Configura los listeners de Firebase Messaging
  Future<void> _setupFirebaseMessagingListeners() async {
    if (kIsWeb) return; // Firebase Messaging no está disponible en web

    try {
      // Listener para mensajes cuando la app está en primer plano
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          LoggerFactory.info('Got a message whilst in the foreground!');
          LoggerFactory.info('Message data: ${message.data}');
        }

        if (message.notification != null) {
          if (kDebugMode) {
            LoggerFactory.info(
                'Message also contained a notification: ${message.notification}');
          }

          // Mostrar notificación local cuando la app está en primer plano
          _showForegroundNotification(message);
        }
      });

      // Listener para cuando el usuario toca una notificación y abre la app
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          LoggerFactory.info('A new onMessageOpenedApp event was published!');
        }

        _handleNotificationTap(message);
      });

      // Verificar si la app fue abierta desde una notificación
      RemoteMessage? initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        if (kDebugMode) {
          LoggerFactory.info(
              'App opened from notification: ${initialMessage.messageId}');
        }
        _handleNotificationTap(initialMessage);
      }

      // Obtener el token FCM
      String? token = await FirebaseMessaging.instance.getToken();
      if (kDebugMode) {
        LoggerFactory.info('FCM Token: $token');
      }

      // Listener para cambios en el token
      FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
        if (kDebugMode) {
          LoggerFactory.info('FCM Token refreshed: $token');
        }
        _sendTokenToServer(token);
      });
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error(
            'Error setting up Firebase Messaging listeners: $e');
      }
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      // Asumimos que el cliente de Supabase está disponible globalmente o via provider
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        LoggerFactory.info('No user logged in, cannot send FCM token.');
        return;
      }

      // Asumimos una tabla 'profiles' con una columna 'fcm_token'
      await _supabase
          .from('profiles')
          .update({'fcm_token': token}).eq('id', userId);

      LoggerFactory.info('FCM token sent to server successfully.');
    } catch (e) {
      LoggerFactory.error('Error sending FCM token to server: $e');
    }
  }

  /// Configura las notificaciones locales
  Future<void> _setupLocalNotifications() async {
    // Las notificaciones locales ya se configuran en NotificationManager
    // Este método puede usarse para configuraciones adicionales si es necesario
  }

  /// Carga las preferencias del usuario
  Future<void> _loadUserPreferences() async {
    try {
      final preferencesService = NotificationPreferencesService.instance;
      await preferencesService.loadPreferences();

      if (kDebugMode) {
        LoggerFactory.info('User notification preferences loaded');
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error loading user preferences: $e');
      }
    }
  }

  /// Muestra una notificación local cuando la app está en primer plano
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (_notificationManager == null) return;

    final notification = message.notification;
    if (notification == null) return;

    try {
      final manager = _notificationManager;
      if (manager != null) {
        await manager.showLocalNotification(
          id: message.hashCode,
          title: notification.title ?? 'Notificación',
          body: notification.body ?? '',
          payload: message.data.toString(),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error showing foreground notification: $e');
      }
    }
  }

  /// Maneja el tap en una notificación
  void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) {
      LoggerFactory.info('Notification tapped: ${message.data}');
    }

    final notificationType = message.data['type'];
    final actionUrl = message.data['actionUrl'];

    switch (notificationType) {
      case 'new_movie':
        // Navegar a la película específica
        final movieId = message.data['movieId'];
        if (movieId != null) {
          _navigateToMovie(movieId);
        }
        break;
      case 'recommendation':
        // Navegar a recomendaciones
        _navigateToRecommendations();
        break;
      case 'list_update':
        // Navegar a la lista específica
        final listId = message.data['listId'];
        if (listId != null) {
          _navigateToList(listId);
        }
        break;
      default:
        if (actionUrl != null) {
          if (kDebugMode) {
            LoggerFactory.info('Navigate to URL: $actionUrl');
          }
          // Para URLs personalizadas, podríamos implementar navegación personalizada
        }
        break;
    }
  }

  /// Navega a los detalles de una película específica
  void _navigateToMovie(String movieId) {
    final context = _globalNavigatorKey?.currentContext;
    if (context != null && context.mounted) {
      try {
        context.go('/movie/$movieId');
        if (kDebugMode) {
          LoggerFactory.info('✅ Navegando a película desde push: $movieId');
        }
      } catch (e) {
        if (kDebugMode) {
          LoggerFactory.error('❌ Error navegando a película desde push: $e');
        }
      }
    } else {
      if (kDebugMode) {
        LoggerFactory.warning(
            '⚠️ No hay contexto de navegación disponible para push');
      }
    }
  }

  /// Navega a la pantalla principal con foco en recomendaciones
  void _navigateToRecommendations() {
    final context = _globalNavigatorKey?.currentContext;
    if (context != null && context.mounted) {
      try {
        context.go('/');
        if (kDebugMode) {
          LoggerFactory.info('✅ Navegando a recomendaciones desde push');
        }
      } catch (e) {
        if (kDebugMode) {
          LoggerFactory.error(
              '❌ Error navegando a recomendaciones desde push: $e');
        }
      }
    } else {
      if (kDebugMode) {
        LoggerFactory.warning(
            '⚠️ No hay contexto de navegación disponible para push');
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
          LoggerFactory.info('✅ Navegando a lista desde push: $listId');
        }
      } catch (e) {
        if (kDebugMode) {
          LoggerFactory.error('❌ Error navegando a lista desde push: $e');
        }
      }
    } else {
      if (kDebugMode) {
        LoggerFactory.warning(
            '⚠️ No hay contexto de navegación disponible para push');
      }
    }
  }

  /// Obtiene el token FCM actual
  Future<String?> getFCMToken() async {
    if (kIsWeb) return null;

    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error getting FCM token: $e');
      }
      return null;
    }
  }

  /// Suscribe a un topic de Firebase
  Future<void> subscribeToTopic(String topic) async {
    if (kIsWeb) return;

    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      if (kDebugMode) {
        LoggerFactory.info('Subscribed to topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error subscribing to topic $topic: $e');
      }
    }
  }

  /// Se desuscribe de un topic de Firebase
  Future<void> unsubscribeFromTopic(String topic) async {
    if (kIsWeb) return;

    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        LoggerFactory.info('Unsubscribed from topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error unsubscribing from topic $topic: $e');
      }
    }
  }

  /// Limpia los recursos del servicio
  void dispose() {
    _notificationManager?.dispose();
    _notificationManager = null;
    _isInitialized = false;
  }
}
