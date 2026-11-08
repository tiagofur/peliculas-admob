import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../logging/logger_factory.dart';
import '../notifications/notification_initialization_service.dart';
import 'navigation_error_boundary.dart';

/// Enhanced notification service que maneja navegación segura desde notificaciones
/// Previene crashes y proporciona recovery graceful
class EnhancedNotificationService {
  factory EnhancedNotificationService() => _instance;
  EnhancedNotificationService._internal();
  static final EnhancedNotificationService _instance =
      EnhancedNotificationService._internal();

  static EnhancedNotificationService get instance => _instance;

  bool _isInitialized = false;
  GlobalKey<NavigatorState>? _globalNavigatorKey;

  // Queue para navegaciones pendientes cuando no hay contexto disponible
  final List<_PendingNavigation> _pendingNavigations = [];

  // Timeout para navegaciones pendientes (5 segundos)
  static const Duration _navigationTimeout = Duration(seconds: 5);

  bool get isInitialized => _isInitialized;

  /// Inicializar el servicio mejorado de notificaciones
  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    if (_isInitialized) return;

    try {
      LoggerFactory.info('🚀 Inicializando Enhanced Notification Service...');

      _globalNavigatorKey = navigatorKey;

      // Inicializar el servicio base
      await NotificationInitializationService.instance.initialize();

      // Configurar listeners mejorados para Firebase Messaging
      await _setupEnhancedFirebaseListeners();

      _isInitialized = true;
      LoggerFactory.info('✅ Enhanced Notification Service inicializado');
    } catch (e) {
      LoggerFactory.error(
          '❌ Error inicializando Enhanced Notification Service: $e');
      rethrow;
    }
  }

  /// Configurar listeners mejorados de Firebase Messaging
  Future<void> _setupEnhancedFirebaseListeners() async {
    if (kIsWeb) return;

    try {
      // Listener para mensajes en primer plano con manejo seguro
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        LoggerFactory.info(
            '📱 Mensaje recibido en primer plano: ${message.messageId}');
        _handleForegroundMessage(message);
      });

      // Listener mejorado para cuando el usuario toca una notificación
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        LoggerFactory.info(
            '👆 Usuario tocó notificación: ${message.messageId}');
        _handleNotificationTapSafely(message);
      });

      // Verificar mensaje inicial con manejo seguro
      RemoteMessage? initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        LoggerFactory.info(
            '🚀 App abierta desde notificación: ${initialMessage.messageId}');
        _handleInitialMessageSafely(initialMessage);
      }
    } catch (e) {
      LoggerFactory.error('❌ Error configurando listeners de Firebase: $e');
    }
  }

  /// Manejar mensaje en primer plano
  void _handleForegroundMessage(RemoteMessage message) {
    try {
      // Mostrar notificación local si está disponible
      final notificationService = NotificationInitializationService.instance;
      if (notificationService.isInitialized) {
        // El servicio base ya maneja esto
      }

      LoggerFactory.debug('✅ Mensaje en primer plano manejado correctamente');
    } catch (e) {
      LoggerFactory.error('❌ Error manejando mensaje en primer plano: $e');
    }
  }

  /// Manejar tap en notificación de forma segura
  void _handleNotificationTapSafely(RemoteMessage message) {
    try {
      final navigation = _extractNavigationFromMessage(message);
      if (navigation != null) {
        _executeNavigationSafely(navigation, source: 'notification_tap');
      }
    } catch (e) {
      LoggerFactory.error('❌ Error manejando tap en notificación: $e');
    }
  }

  /// Manejar mensaje inicial de forma segura
  void _handleInitialMessageSafely(RemoteMessage message) {
    try {
      final navigation = _extractNavigationFromMessage(message);
      if (navigation != null) {
        // Para mensajes iniciales, podemos necesitar esperar a que la app esté lista
        _executeNavigationSafely(
          navigation,
          source: 'initial_message',
          delay: const Duration(milliseconds: 1000), // Esperar 1 segundo
        );
      }
    } catch (e) {
      LoggerFactory.error('❌ Error manejando mensaje inicial: $e');
    }
  }

  /// Extraer información de navegación desde el mensaje
  _NavigationInfo? _extractNavigationFromMessage(RemoteMessage message) {
    try {
      final data = message.data;
      final type = data['type'];

      if (type == null) {
        LoggerFactory.warning('⚠️ Mensaje sin tipo de navegación');
        return null;
      }

      switch (type) {
        case 'new_movie':
          final movieId = data['movieId'];
          if (movieId != null) {
            return _NavigationInfo(
              route: '/movie/$movieId',
              type: 'movie',
              payload: {'movieId': movieId},
            );
          }
          break;

        case 'recommendation':
          return const _NavigationInfo(
            route: '/',
            type: 'recommendations',
            payload: {'focus': 'recommendations'},
          );

        case 'list_update':
          final listId = data['listId'];
          if (listId != null) {
            return _NavigationInfo(
              route: '/my-library/lists/$listId',
              type: 'list',
              payload: {'listId': listId},
            );
          }
          break;

        case 'custom_url':
          final actionUrl = data['actionUrl'];
          if (actionUrl != null && SafeNavigation.isValidRoute(actionUrl)) {
            return _NavigationInfo(
              route: SafeNavigation.sanitizeRoute(actionUrl),
              type: 'custom',
              payload: data,
            );
          }
          break;
      }

      LoggerFactory.warning('⚠️ Tipo de navegación no reconocido: $type');
      return null;
    } catch (e) {
      LoggerFactory.error('❌ Error extrayendo navegación del mensaje: $e');
      return null;
    }
  }

  /// Ejecutar navegación de forma segura con retry y fallback
  void _executeNavigationSafely(
    _NavigationInfo navigation, {
    required String source,
    Duration? delay,
  }) {
    // Si hay delay, esperar antes de navegar
    if (delay != null) {
      Future.delayed(delay, () => _performNavigation(navigation, source));
    } else {
      _performNavigation(navigation, source);
    }
  }

  /// Realizar la navegación actual
  void _performNavigation(_NavigationInfo navigation, String source) {
    try {
      final context = _globalNavigatorKey?.currentContext;

      if (context == null || !context.mounted) {
        LoggerFactory.warning(
            '⚠️ No hay contexto disponible, agregando a cola');
        _addToPendingQueue(navigation, source);
        return;
      }

      // Validar la ruta antes de navegar
      if (!SafeNavigation.isValidRoute(navigation.route)) {
        LoggerFactory.error('❌ Ruta inválida: ${navigation.route}');
        _navigateToFallback(context);
        return;
      }

      // Realizar navegación segura
      SafeNavigation.safeGo(context, navigation.route);

      LoggerFactory.info(
          '✅ Navegación exitosa desde $source: ${navigation.route}');

      // Limpiar navegaciones pendientes del mismo tipo
      _clearPendingNavigationsOfType(navigation.type);
    } catch (e) {
      LoggerFactory.error('❌ Error en navegación desde $source: $e');

      // Intentar navegación de fallback
      final context = _globalNavigatorKey?.currentContext;
      if (context != null && context.mounted) {
        _navigateToFallback(context);
      }
    }
  }

  /// Agregar navegación a la cola de pendientes
  void _addToPendingQueue(_NavigationInfo navigation, String source) {
    final pendingNav = _PendingNavigation(
      navigation: navigation,
      source: source,
      timestamp: DateTime.now(),
    );

    _pendingNavigations.add(pendingNav);
    LoggerFactory.info('📝 Navegación agregada a cola: ${navigation.route}');

    // Configurar timeout para limpiar navegaciones viejas
    _scheduleCleanup();

    // Intentar procesar la cola después de un breve delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _processPendingNavigations();
    });
  }

  /// Procesar navegaciones pendientes
  void _processPendingNavigations() {
    if (_pendingNavigations.isEmpty) return;

    final context = _globalNavigatorKey?.currentContext;
    if (context == null || !context.mounted) {
      LoggerFactory.debug(
          '🔄 Contexto aún no disponible para navegaciones pendientes');
      return;
    }

    LoggerFactory.info(
        '🔄 Procesando ${_pendingNavigations.length} navegaciones pendientes');

    // Procesar solo la más reciente para evitar navegaciones múltiples
    final mostRecent = _pendingNavigations.last;
    _performNavigation(mostRecent.navigation, '${mostRecent.source}_pending');

    // Limpiar todas las navegaciones pendientes
    _pendingNavigations.clear();
  }

  /// Limpiar navegaciones pendientes del mismo tipo
  void _clearPendingNavigationsOfType(String type) {
    _pendingNavigations.removeWhere((nav) => nav.navigation.type == type);
  }

  /// Programar limpieza de navegaciones expiradas
  void _scheduleCleanup() {
    Future.delayed(_navigationTimeout, () {
      final now = DateTime.now();
      _pendingNavigations.removeWhere((nav) {
        final isExpired = now.difference(nav.timestamp) > _navigationTimeout;
        if (isExpired) {
          LoggerFactory.info(
              '🗑️ Navegación expirada eliminada: ${nav.navigation.route}');
        }
        return isExpired;
      });
    });
  }

  /// Navegar a fallback cuando falla la navegación principal
  void _navigateToFallback(BuildContext context) {
    try {
      SafeNavigation.safeGo(context, '/');
      LoggerFactory.info('🏠 Navegación de fallback al home exitosa');
    } catch (e) {
      LoggerFactory.error('❌ Navegación de fallback también falló: $e');
    }
  }

  /// Método público para manejar deep links externos
  void handleDeepLink(String url) {
    try {
      final sanitizedUrl = SafeNavigation.sanitizeRoute(url);

      if (!SafeNavigation.isValidRoute(sanitizedUrl)) {
        LoggerFactory.error('❌ Deep link inválido: $url');
        return;
      }

      final navigation = _NavigationInfo(
        route: sanitizedUrl,
        type: 'deep_link',
        payload: {'original_url': url},
      );

      _executeNavigationSafely(navigation, source: 'deep_link');
    } catch (e) {
      LoggerFactory.error('❌ Error manejando deep link: $url, error: $e');
    }
  }

  /// Obtener estadísticas del servicio
  Map<String, dynamic> getStats() {
    return {
      'is_initialized': _isInitialized,
      'has_navigator_key': _globalNavigatorKey != null,
      'pending_navigations': _pendingNavigations.length,
      'pending_details': _pendingNavigations
          .map((nav) => {
                'route': nav.navigation.route,
                'type': nav.navigation.type,
                'source': nav.source,
                'age_seconds':
                    DateTime.now().difference(nav.timestamp).inSeconds,
              })
          .toList(),
    };
  }

  /// Limpiar recursos
  void dispose() {
    _pendingNavigations.clear();
    _globalNavigatorKey = null;
    _isInitialized = false;
    LoggerFactory.info('🧹 Enhanced Notification Service disposed');
  }
}

/// Información de navegación extraída de notificaciones
class _NavigationInfo {
  const _NavigationInfo({
    required this.route,
    required this.type,
    required this.payload,
  });

  final String route;
  final String type;
  final Map<String, dynamic> payload;
}

/// Navegación pendiente en cola
class _PendingNavigation {
  const _PendingNavigation({
    required this.navigation,
    required this.source,
    required this.timestamp,
  });

  final _NavigationInfo navigation;
  final String source;
  final DateTime timestamp;
}
