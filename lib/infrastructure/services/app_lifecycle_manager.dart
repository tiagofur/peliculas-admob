import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/cache/image_cache_manager.dart';
import '../../core/logging/logger_factory.dart';

/// Estados del ciclo de vida de la aplicación
enum AppLifecycleStatus {
  /// La aplicación está en primer plano y respondiendo a la entrada del usuario
  resumed,

  /// La aplicación está en un estado inactivo y no está recibiendo entrada del usuario
  inactive,

  /// La aplicación está oculta y ejecutándose en segundo plano
  paused,

  /// La aplicación está suspendida y no está ejecutándose
  detached,

  /// La aplicación está oculta (específico para Web)
  hidden,
}

/// Callback para cambios en el ciclo de vida
typedef AppLifecycleCallback = void Function(AppLifecycleStatus status);

/// Gestor del ciclo de vida de la aplicación para optimizar sincronización
class AppLifecycleManager with WidgetsBindingObserver {
  AppLifecycleManager._();

  static final AppLifecycleManager _instance = AppLifecycleManager._();
  static AppLifecycleManager get instance => _instance;

  // Estado interno
  AppLifecycleStatus _currentStatus = AppLifecycleStatus.resumed;
  DateTime? _lastPausedTime;
  DateTime? _lastResumedTime;

  // Callbacks
  final List<AppLifecycleCallback> _callbacks = [];

  // Stream controller para notificar cambios
  final StreamController<AppLifecycleStatus> _statusController =
      StreamController<AppLifecycleStatus>.broadcast();

  // Configuración
  static const Duration _backgroundThreshold = Duration(minutes: 5);

  /// Stream de cambios en el ciclo de vida
  Stream<AppLifecycleStatus> get onLifecycleChanged => _statusController.stream;

  /// Estado actual del ciclo de vida
  AppLifecycleStatus get currentStatus => _currentStatus;

  /// Verifica si la app está en primer plano
  bool get isInForeground => _currentStatus == AppLifecycleStatus.resumed;

  /// Verifica si la app está en segundo plano
  bool get isInBackground =>
      _currentStatus == AppLifecycleStatus.paused ||
      _currentStatus == AppLifecycleStatus.detached ||
      _currentStatus == AppLifecycleStatus.hidden;

  /// Verifica si la app está inactiva
  bool get isInactive => _currentStatus == AppLifecycleStatus.inactive;

  /// Tiempo que la app ha estado en segundo plano
  Duration? get timeInBackground {
    if (_lastPausedTime == null || isInForeground) {
      return null;
    }
    return DateTime.now().difference(_lastPausedTime ?? DateTime.now());
  }

  /// Verifica si la app ha estado en segundo plano por mucho tiempo
  bool get hasBeenInBackgroundTooLong {
    final backgroundTime = timeInBackground;
    return backgroundTime != null && backgroundTime > _backgroundThreshold;
  }

  /// Inicializa el gestor del ciclo de vida
  void initialize() {
    LoggerFactory.info('🔄 Inicializando AppLifecycleManager...');

    try {
      // Registrar observer
      WidgetsBinding.instance.addObserver(this);

      // Estado inicial
      _currentStatus = AppLifecycleStatus.resumed;
      _lastResumedTime = DateTime.now();

      LoggerFactory.info('✅ AppLifecycleManager inicializado correctamente');
    } catch (e) {
      LoggerFactory.error('❌ Error inicializando AppLifecycleManager: $e');
    }
  }

  /// Registra un callback para cambios en el ciclo de vida
  void addCallback(AppLifecycleCallback callback) {
    _callbacks.add(callback);
    LoggerFactory.info('📝 Callback de ciclo de vida registrado');
  }

  /// Remueve un callback
  void removeCallback(AppLifecycleCallback callback) {
    _callbacks.remove(callback);
    LoggerFactory.info('🗑️ Callback de ciclo de vida removido');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final newStatus = _mapFlutterStateToCustomState(state);
    _handleLifecycleChange(newStatus);
  }

  /// Mapea el estado de Flutter a nuestro estado personalizado
  AppLifecycleStatus _mapFlutterStateToCustomState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        return AppLifecycleStatus.resumed;
      case AppLifecycleState.inactive:
        return AppLifecycleStatus.inactive;
      case AppLifecycleState.paused:
        return AppLifecycleStatus.paused;
      case AppLifecycleState.detached:
        return AppLifecycleStatus.detached;
      case AppLifecycleState.hidden:
        return AppLifecycleStatus.hidden;
    }
  }

  /// Maneja cambios en el ciclo de vida
  void _handleLifecycleChange(AppLifecycleStatus newStatus) {
    if (_currentStatus == newStatus) {
      return;
    }

    final oldStatus = _currentStatus;
    _currentStatus = newStatus;

    // Actualizar timestamps
    _updateTimestamps(newStatus);

    LoggerFactory.info(
        '🔄 Ciclo de vida cambió: ${oldStatus.name} → ${newStatus.name}');

    // Notificar callbacks
    for (final callback in _callbacks) {
      try {
        callback(newStatus);
      } catch (e) {
        LoggerFactory.error('❌ Error en callback de ciclo de vida: $e');
      }
    }

    // Notificar stream
    _statusController.add(newStatus);

    // Logging adicional para casos específicos
    _logSpecialCases(oldStatus, newStatus);
  }

  /// Actualiza timestamps según el nuevo estado
  void _updateTimestamps(AppLifecycleStatus newStatus) {
    switch (newStatus) {
      case AppLifecycleStatus.resumed:
        _lastResumedTime = DateTime.now();
        if (_lastPausedTime != null) {
          final backgroundDuration =
              DateTime.now().difference(_lastPausedTime ?? DateTime.now());
          LoggerFactory.info(
              '⏱️ App estuvo en segundo plano por: ${backgroundDuration.inMinutes} minutos');

          // MEMORY LEAK FIX: Limpiar cache si estuvo mucho tiempo en segundo plano
          if (backgroundDuration > _backgroundThreshold) {
            _cleanupCacheAfterLongBackground();
          }
        }
        break;
      case AppLifecycleStatus.paused:
      case AppLifecycleStatus.detached:
      case AppLifecycleStatus.hidden:
        _lastPausedTime = DateTime.now();
        break;
      case AppLifecycleStatus.inactive:
        // No actualizar timestamps para estado inactivo
        break;
    }
  }

  /// Logging para casos especiales
  void _logSpecialCases(
      AppLifecycleStatus oldStatus, AppLifecycleStatus newStatus) {
    // App volvió del segundo plano
    if (_wasInBackground(oldStatus) &&
        newStatus == AppLifecycleStatus.resumed) {
      LoggerFactory.info(
          '🔄 App volvió del segundo plano - puede necesitar sincronización');
    }

    // App fue a segundo plano
    if (oldStatus == AppLifecycleStatus.resumed &&
        _isGoingToBackground(newStatus)) {
      LoggerFactory.info(
          '⏸️ App fue a segundo plano - pausando operaciones intensivas');
    }

    // App estuvo mucho tiempo en segundo plano
    if (newStatus == AppLifecycleStatus.resumed && hasBeenInBackgroundTooLong) {
      LoggerFactory.info(
          '⚠️ App estuvo mucho tiempo en segundo plano - sincronización completa recomendada');
    }
  }

  /// Verifica si el estado anterior era de segundo plano
  bool _wasInBackground(AppLifecycleStatus status) {
    return status == AppLifecycleStatus.paused ||
        status == AppLifecycleStatus.detached ||
        status == AppLifecycleStatus.hidden;
  }

  /// Verifica si el nuevo estado es de segundo plano
  bool _isGoingToBackground(AppLifecycleStatus status) {
    return status == AppLifecycleStatus.paused ||
        status == AppLifecycleStatus.detached ||
        status == AppLifecycleStatus.hidden;
  }

  /// Obtiene información detallada del estado
  Map<String, dynamic> getDetailedStatus() {
    return {
      'current_status': _currentStatus.name,
      'is_in_foreground': isInForeground,
      'is_in_background': isInBackground,
      'is_inactive': isInactive,
      'last_paused_time': _lastPausedTime?.toIso8601String(),
      'last_resumed_time': _lastResumedTime?.toIso8601String(),
      'time_in_background_minutes': timeInBackground?.inMinutes,
      'has_been_in_background_too_long': hasBeenInBackgroundTooLong,
      'callbacks_count': _callbacks.length,
      'platform': kIsWeb ? 'web' : 'native',
    };
  }

  /// Simula un cambio de estado (útil para testing)
  void simulateLifecycleChange(AppLifecycleStatus status) {
    if (kDebugMode) {
      LoggerFactory.info(
          '🧪 Simulando cambio de ciclo de vida a: ${status.name}');
      _handleLifecycleChange(status);
    }
  }

  /// Limpia recursos
  void dispose() {
    LoggerFactory.info('🧹 Limpiando AppLifecycleManager...');

    WidgetsBinding.instance.removeObserver(this);
    _callbacks.clear();
    _statusController.close();

    // MEMORY LEAK FIX: Limpiar Image Cache Manager
    _cleanupImageCache();

    LoggerFactory.info('✅ AppLifecycleManager limpiado');
  }

  /// Limpia el cache de imágenes para prevenir memory leaks
  void _cleanupImageCache() {
    try {
      // La limpieza se hace de forma asíncrona para no bloquear el dispose
      Future(() async {
        try {
          await ImageCacheManager.instance.dispose();
          LoggerFactory.info('✅ ImageCacheManager limpiado correctamente');
        } catch (e) {
          LoggerFactory.warning('⚠️ No se pudo limpiar ImageCacheManager: $e');
        }
      });
    } catch (e) {
      LoggerFactory.warning(
          '⚠️ Error configurando limpieza de imagen cache: $e');
    }
  }

  /// Limpia el cache después de mucho tiempo en segundo plano
  void _cleanupCacheAfterLongBackground() {
    LoggerFactory.info(
        '🧹 App estuvo mucho tiempo en segundo plano - limpiando cache...');

    Future(() async {
      try {
        // Limpiar cache expirado (no todo el cache, solo lo expirado)
        await ImageCacheManager.instance.cleanExpiredCache();
        LoggerFactory.info(
            '✅ Cache expirado limpiado después de segundo plano prolongado');
      } catch (e) {
        LoggerFactory.warning('⚠️ Error limpiando cache expirado: $e');
      }
    });
  }
}

/// Extensión para facilitar el uso
extension AppLifecycleStatusExtension on AppLifecycleStatus {
  /// Verifica si el estado indica que la app está activa
  bool get isActive => this == AppLifecycleStatus.resumed;

  /// Verifica si el estado indica que la app está en segundo plano
  bool get isBackground =>
      this == AppLifecycleStatus.paused ||
      this == AppLifecycleStatus.detached ||
      this == AppLifecycleStatus.hidden;

  /// Verifica si el estado indica que la app está inactiva
  bool get isInactiveState => this == AppLifecycleStatus.inactive;
}
