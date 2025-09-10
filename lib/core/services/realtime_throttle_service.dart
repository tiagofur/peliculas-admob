import 'dart:async';

import 'package:flutter/foundation.dart';

import '../logging/safe_developer_log.dart';

/// Servicio para throttling y debouncing de eventos de tiempo real
class RealtimeThrottleService {
  factory RealtimeThrottleService() => _instance;
  RealtimeThrottleService._internal();

  static final RealtimeThrottleService _instance =
      RealtimeThrottleService._internal();

  final Map<String, Timer> _debounceTimers = {};
  final Map<String, DateTime> _lastThrottleTime = {};
  final Map<String, int> _eventCounts = {};

  // Configuraciones optimizadas y adaptativas
  static const Duration _defaultDebounceDelay = Duration(milliseconds: 300);
  static const Duration _defaultThrottleInterval = Duration(milliseconds: 1500);
  static const int _maxEventsPerInterval = 8;

  // Configuraciones por tipo de evento
  static const Map<String, Duration> _eventTypeDebounceDelays = {
    'insert': Duration(milliseconds: 200),
    'update': Duration(milliseconds: 300),
    'delete': Duration(milliseconds: 100),
    'batch': Duration(milliseconds: 500),
  };

  static const Map<String, int> _eventTypeMaxEvents = {
    'insert': 10,
    'update': 8,
    'delete': 5,
    'batch': 15,
  };

  // Configuraciones adaptativas basadas en carga
  final Map<String, int> _eventFrequency = {};
  final Map<String, DateTime> _lastEventTime = {};
  Timer? _adaptiveConfigTimer;

  /// Aplica debouncing a una función
  /// Retrasa la ejecución hasta que no haya más eventos por el tiempo especificado
  void debounce(
    String key,
    VoidCallback callback, {
    Duration delay = _defaultDebounceDelay,
  }) {
    // Cancelar timer anterior si existe
    _debounceTimers[key]?.cancel();

    // Crear nuevo timer
    _debounceTimers[key] = Timer(delay, () {
      callback();
      _debounceTimers.remove(key);
      SafeDeveloperLog.log('Debounced callback executed for key: $key',
          name: 'ThrottleService');
    });

    SafeDeveloperLog.log(
        'Debounce timer set for key: $key, delay: ${delay.inMilliseconds}ms',
        name: 'ThrottleService');
  }

  /// Aplica throttling a una función
  /// Limita la frecuencia de ejecución a un intervalo específico
  bool throttle(
    String key,
    VoidCallback callback, {
    Duration interval = _defaultThrottleInterval,
  }) {
    final now = DateTime.now();
    final lastTime = _lastThrottleTime[key];

    // Si es la primera vez o ha pasado el intervalo, ejecutar
    if (lastTime == null || now.difference(lastTime) >= interval) {
      _lastThrottleTime[key] = now;
      callback();
      SafeDeveloperLog.log('Throttled callback executed for key: $key',
          name: 'ThrottleService');
      return true;
    }

    SafeDeveloperLog.log('Throttled callback skipped for key: $key',
        name: 'ThrottleService');
    return false;
  }

  /// Aplica rate limiting basado en número de eventos por intervalo
  bool rateLimit(
    String key,
    VoidCallback callback, {
    Duration interval = _defaultThrottleInterval,
    int maxEvents = _maxEventsPerInterval,
  }) {
    final now = DateTime.now();
    final lastTime = _lastThrottleTime[key];

    // Resetear contador si ha pasado el intervalo
    if (lastTime == null || now.difference(lastTime) >= interval) {
      _eventCounts[key] = 0;
      _lastThrottleTime[key] = now;
    }

    final currentCount = _eventCounts[key] ?? 0;

    // Si no hemos excedido el límite, ejecutar
    if (currentCount < maxEvents) {
      _eventCounts[key] = currentCount + 1;
      callback();
      SafeDeveloperLog.log(
          'Rate limited callback executed for key: $key (${currentCount + 1}/$maxEvents)',
          name: 'ThrottleService');
      return true;
    }

    SafeDeveloperLog.log(
        'Rate limit exceeded for key: $key ($currentCount/$maxEvents)',
        name: 'ThrottleService');
    return false;
  }

  /// Combina debouncing y throttling con configuración adaptativa
  void smartThrottle(
    String key,
    VoidCallback callback, {
    Duration? debounceDelay,
    Duration? throttleInterval,
    int? maxEvents,
    String? eventType,
  }) {
    final throttleKey = '${key}_throttle';
    final debounceKey = '${key}_debounce';

    // Usar configuraciones adaptativas basadas en el tipo de evento
    final adaptiveDelay =
        debounceDelay ?? _getAdaptiveDebounceDelay(key, eventType);
    final adaptiveInterval =
        throttleInterval ?? _getAdaptiveThrottleInterval(key);
    final adaptiveMaxEvents =
        maxEvents ?? _getAdaptiveMaxEvents(key, eventType);

    // Registrar frecuencia de eventos para adaptación
    _updateEventFrequency(key);

    // Aplicar rate limiting primero
    final canExecute = rateLimit(
      throttleKey,
      () {}, // Callback vacío, solo verificamos si podemos ejecutar
      interval: adaptiveInterval,
      maxEvents: adaptiveMaxEvents,
    );

    if (canExecute) {
      // Si podemos ejecutar, aplicar debouncing
      debounce(
        debounceKey,
        callback,
        delay: adaptiveDelay,
      );
    } else {
      SafeDeveloperLog.log(
          'Smart throttle blocked execution for key: $key (adaptive: delay=${adaptiveDelay.inMilliseconds}ms, maxEvents=$adaptiveMaxEvents)',
          name: 'ThrottleService');
    }
  }

  /// Obtiene el delay de debounce adaptativo basado en el tipo de evento
  Duration _getAdaptiveDebounceDelay(String key, String? eventType) {
    if (eventType != null && _eventTypeDebounceDelays.containsKey(eventType)) {
      return _eventTypeDebounceDelays[eventType]!;
    }

    // Adaptación basada en frecuencia de eventos
    final frequency = _eventFrequency[key] ?? 0;
    if (frequency > 20) {
      return const Duration(
          milliseconds: 500); // Más delay para alta frecuencia
    } else if (frequency > 10) {
      return const Duration(milliseconds: 350);
    }

    return _defaultDebounceDelay;
  }

  /// Obtiene el intervalo de throttle adaptativo
  Duration _getAdaptiveThrottleInterval(String key) {
    final frequency = _eventFrequency[key] ?? 0;
    if (frequency > 30) {
      return const Duration(seconds: 3); // Más restrictivo para alta frecuencia
    } else if (frequency > 15) {
      return const Duration(seconds: 2);
    }

    return _defaultThrottleInterval;
  }

  /// Obtiene el máximo de eventos adaptativo
  int _getAdaptiveMaxEvents(String key, String? eventType) {
    if (eventType != null && _eventTypeMaxEvents.containsKey(eventType)) {
      return _eventTypeMaxEvents[eventType]!;
    }

    final frequency = _eventFrequency[key] ?? 0;
    if (frequency > 25) {
      return 12; // Permitir más eventos para alta frecuencia
    } else if (frequency < 5) {
      return 5; // Menos eventos para baja frecuencia
    }

    return _maxEventsPerInterval;
  }

  /// Actualiza la frecuencia de eventos para adaptación
  void _updateEventFrequency(String key) {
    final now = DateTime.now();
    final lastTime = _lastEventTime[key];

    if (lastTime == null || now.difference(lastTime).inMinutes >= 1) {
      // Resetear contador cada minuto
      _eventFrequency[key] = 1;
    } else {
      _eventFrequency[key] = (_eventFrequency[key] ?? 0) + 1;
    }

    _lastEventTime[key] = now;

    // Iniciar timer adaptativo si no existe
    _adaptiveConfigTimer ??= Timer.periodic(
      const Duration(minutes: 2),
      (_) => _cleanupAdaptiveData(),
    );
  }

  /// Limpia datos adaptativos antiguos
  void _cleanupAdaptiveData() {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    for (final entry in _lastEventTime.entries) {
      if (now.difference(entry.value).inMinutes > 5) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _eventFrequency.remove(key);
      _lastEventTime.remove(key);
    }

    SafeDeveloperLog.log(
        'Cleaned up ${keysToRemove.length} adaptive data entries',
        name: 'ThrottleService');
  }

  /// Cancela todos los timers de debouncing para una clave específica
  void cancelDebounce(String key) {
    _debounceTimers[key]?.cancel();
    _debounceTimers.remove(key);
    SafeDeveloperLog.log('Debounce cancelled for key: $key',
        name: 'ThrottleService');
  }

  /// Resetea el throttling para una clave específica
  void resetThrottle(String key) {
    _lastThrottleTime.remove(key);
    _eventCounts.remove(key);
    SafeDeveloperLog.log('Throttle reset for key: $key',
        name: 'ThrottleService');
  }

  /// Cancela todos los timers y resetea todos los contadores
  void reset() {
    // Cancelar todos los timers de debouncing
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }

    _debounceTimers.clear();
    _lastThrottleTime.clear();
    _eventCounts.clear();

    SafeDeveloperLog.log('All throttling and debouncing reset',
        name: 'ThrottleService');
  }

  /// Obtiene estadísticas del servicio incluyendo datos adaptativos
  Map<String, dynamic> getStats() {
    return {
      'activeDebounceTimers': _debounceTimers.length,
      'throttledKeys': _lastThrottleTime.length,
      'eventCounts': Map.from(_eventCounts),
      'eventFrequency': Map.from(_eventFrequency),
      'lastThrottleTimes': _lastThrottleTime.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
      'lastEventTimes': _lastEventTime.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
      'adaptiveConfigActive': _adaptiveConfigTimer?.isActive ?? false,
    };
  }

  /// Obtiene configuraciones adaptativas actuales para una clave
  Map<String, dynamic> getAdaptiveConfig(String key, {String? eventType}) {
    return {
      'debounceDelay': _getAdaptiveDebounceDelay(key, eventType).inMilliseconds,
      'throttleInterval': _getAdaptiveThrottleInterval(key).inMilliseconds,
      'maxEvents': _getAdaptiveMaxEvents(key, eventType),
      'eventFrequency': _eventFrequency[key] ?? 0,
      'lastEventTime': _lastEventTime[key]?.toIso8601String(),
    };
  }

  /// Libera recursos incluyendo timer adaptativo
  void dispose() {
    reset();
    _adaptiveConfigTimer?.cancel();
    _adaptiveConfigTimer = null;
    _eventFrequency.clear();
    _lastEventTime.clear();
  }
}
