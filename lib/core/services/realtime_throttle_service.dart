import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Servicio para throttling y debouncing de eventos de tiempo real
class RealtimeThrottleService {
  factory RealtimeThrottleService() => _instance;
  RealtimeThrottleService._internal();

  static final RealtimeThrottleService _instance =
      RealtimeThrottleService._internal();

  final Map<String, Timer> _debounceTimers = {};
  final Map<String, DateTime> _lastThrottleTime = {};
  final Map<String, int> _eventCounts = {};

  static const Duration _defaultDebounceDelay = Duration(milliseconds: 500);
  static const Duration _defaultThrottleInterval = Duration(seconds: 2);
  static const int _maxEventsPerInterval = 5;

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
      developer.log('Debounced callback executed for key: $key',
          name: 'ThrottleService');
    });

    developer.log(
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
      developer.log('Throttled callback executed for key: $key',
          name: 'ThrottleService');
      return true;
    }

    developer.log('Throttled callback skipped for key: $key',
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
      developer.log(
          'Rate limited callback executed for key: $key (${currentCount + 1}/$maxEvents)',
          name: 'ThrottleService');
      return true;
    }

    developer.log(
        'Rate limit exceeded for key: $key ($currentCount/$maxEvents)',
        name: 'ThrottleService');
    return false;
  }

  /// Combina debouncing y throttling para un control más sofisticado
  void smartThrottle(
    String key,
    VoidCallback callback, {
    Duration debounceDelay = _defaultDebounceDelay,
    Duration throttleInterval = _defaultThrottleInterval,
    int maxEvents = _maxEventsPerInterval,
  }) {
    final throttleKey = '${key}_throttle';
    final debounceKey = '${key}_debounce';

    // Aplicar rate limiting primero
    final canExecute = rateLimit(
      throttleKey,
      () {}, // Callback vacío, solo verificamos si podemos ejecutar
      interval: throttleInterval,
      maxEvents: maxEvents,
    );

    if (canExecute) {
      // Si podemos ejecutar, aplicar debouncing
      debounce(
        debounceKey,
        callback,
        delay: debounceDelay,
      );
    } else {
      developer.log('Smart throttle blocked execution for key: $key',
          name: 'ThrottleService');
    }
  }

  /// Cancela todos los timers de debouncing para una clave específica
  void cancelDebounce(String key) {
    _debounceTimers[key]?.cancel();
    _debounceTimers.remove(key);
    developer.log('Debounce cancelled for key: $key', name: 'ThrottleService');
  }

  /// Resetea el throttling para una clave específica
  void resetThrottle(String key) {
    _lastThrottleTime.remove(key);
    _eventCounts.remove(key);
    developer.log('Throttle reset for key: $key', name: 'ThrottleService');
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

    developer.log('All throttling and debouncing reset',
        name: 'ThrottleService');
  }

  /// Obtiene estadísticas del servicio
  Map<String, dynamic> getStats() {
    return {
      'activeDebounceTimers': _debounceTimers.length,
      'throttledKeys': _lastThrottleTime.length,
      'eventCounts': Map.from(_eventCounts),
      'lastThrottleTimes': _lastThrottleTime.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
    };
  }

  /// Libera recursos
  void dispose() {
    reset();
  }
}
