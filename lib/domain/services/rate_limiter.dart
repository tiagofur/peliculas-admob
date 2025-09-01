import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;

/// Sistema de rate limiting para controlar las llamadas a APIs
/// Implementa diferentes estrategias de limitación para TMDB y Trakt.tv
class RateLimiter {
  RateLimiter._({
    required this.serviceName,
    required this.maxRequests,
    required this.timeWindow,
    this.minInterval,
    required this.strategy,
  })  : _tokenCount = maxRequests,
        _lastTokenRefill = DateTime.now();
  static final Map<String, RateLimiter> _instances = {};

  /// Obtener instancia de rate limiter para un servicio específico
  static RateLimiter forService(
    String serviceName, {
    required int maxRequests,
    required Duration timeWindow,
    Duration? minInterval,
    RateLimitStrategy strategy = RateLimitStrategy.slidingWindow,
  }) {
    final key = '${serviceName}_${maxRequests}_${timeWindow.inMilliseconds}';
    return _instances.putIfAbsent(
        key,
        () => RateLimiter._(
              serviceName: serviceName,
              maxRequests: maxRequests,
              timeWindow: timeWindow,
              minInterval: minInterval,
              strategy: strategy,
            ));
  }

  /// Rate limiter para TMDB API (40 requests por 10 segundos)
  static RateLimiter get tmdb => forService(
        'TMDB',
        maxRequests: 40,
        timeWindow: Duration(seconds: 10),
        minInterval:
            Duration(milliseconds: 250), // 4 requests por segundo máximo
        strategy: RateLimitStrategy.slidingWindow,
      );

  /// Rate limiter para Trakt.tv API (1000 requests por 5 minutos)
  static RateLimiter get trakt => forService(
        'Trakt',
        maxRequests: 1000,
        timeWindow: Duration(minutes: 5),
        minInterval:
            Duration(milliseconds: 300), // ~3.3 requests por segundo máximo
        strategy: RateLimitStrategy.slidingWindow,
      );

  /// Rate limiter conservador para migración en segundo plano
  static RateLimiter get migration => forService(
        'Migration',
        maxRequests: 20,
        timeWindow: Duration(minutes: 1),
        minInterval: Duration(seconds: 2), // Muy conservador para segundo plano
        strategy: RateLimitStrategy.tokenBucket,
      );

  final String serviceName;
  final int maxRequests;
  final Duration timeWindow;
  final Duration? minInterval;
  final RateLimitStrategy strategy;

  // Estado interno
  final Queue<DateTime> _requestTimes = Queue<DateTime>();
  DateTime? _lastRequestTime;
  int _tokenCount;
  DateTime _lastTokenRefill;
  final List<Completer<void>> _waitingQueue = [];

  /// Ejecutar una función con rate limiting
  Future<T> execute<T>(
    Future<T> Function() operation, {
    String? operationName,
    int priority = 0,
  }) async {
    await _waitForPermission(priority: priority);

    final startTime = DateTime.now();

    try {
      final result = await operation();

      _recordSuccessfulRequest(startTime, operationName);
      return result;
    } catch (e) {
      _recordFailedRequest(startTime, operationName, e);
      rethrow;
    }
  }

  /// Verificar si se puede hacer una request ahora
  bool canMakeRequest() {
    final now = DateTime.now();

    switch (strategy) {
      case RateLimitStrategy.slidingWindow:
        return _canMakeRequestSlidingWindow(now);
      case RateLimitStrategy.tokenBucket:
        return _canMakeRequestTokenBucket(now);
      case RateLimitStrategy.fixedWindow:
        return _canMakeRequestFixedWindow(now);
    }
  }

  /// Obtener tiempo estimado hasta que se pueda hacer la próxima request
  Duration getWaitTime() {
    final now = DateTime.now();

    switch (strategy) {
      case RateLimitStrategy.slidingWindow:
        return _getWaitTimeSlidingWindow(now);
      case RateLimitStrategy.tokenBucket:
        return _getWaitTimeTokenBucket(now);
      case RateLimitStrategy.fixedWindow:
        return _getWaitTimeFixedWindow(now);
    }
  }

  /// Obtener estadísticas del rate limiter
  RateLimiterStats getStats() {
    final now = DateTime.now();
    final recentRequests = _requestTimes
        .where((time) => now.difference(time) <= timeWindow)
        .length;

    return RateLimiterStats(
      serviceName: serviceName,
      currentRequests: recentRequests,
      maxRequests: maxRequests,
      timeWindow: timeWindow,
      utilizationPercent: (recentRequests / maxRequests * 100).round(),
      waitingQueueSize: _waitingQueue.length,
      lastRequestTime: _lastRequestTime,
      canMakeRequest: canMakeRequest(),
      estimatedWaitTime: getWaitTime(),
      availableTokens:
          strategy == RateLimitStrategy.tokenBucket ? _tokenCount : null,
    );
  }

  /// Resetear el rate limiter
  void reset() {
    _requestTimes.clear();
    _lastRequestTime = null;
    _tokenCount = maxRequests;
    _lastTokenRefill = DateTime.now();

    // Completar todas las requests en espera
    for (final completer in _waitingQueue) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _waitingQueue.clear();

    developer.log('🔄 Rate limiter resetado: $serviceName');
  }

  /// Esperar permiso para hacer una request
  Future<void> _waitForPermission({int priority = 0}) async {
    while (!canMakeRequest()) {
      final waitTime = getWaitTime();

      if (waitTime.inMilliseconds > 0) {
        developer.log(
            '⏳ Rate limit alcanzado para $serviceName, esperando ${waitTime.inMilliseconds}ms');

        // Crear completer para esta request
        final completer = Completer<void>();
        _waitingQueue.add(completer);

        // Programar la liberación
        Timer(waitTime, () {
          if (!completer.isCompleted) {
            completer.complete();
          }
          _waitingQueue.remove(completer);
        });

        await completer.future;
      }

      // Verificar intervalo mínimo
      if (minInterval != null && _lastRequestTime != null) {
        final timeSinceLastRequest =
            DateTime.now().difference(_lastRequestTime!);
        if (timeSinceLastRequest < minInterval!) {
          final additionalWait = minInterval! - timeSinceLastRequest;
          await Future.delayed(additionalWait);
        }
      }
    }
  }

  /// Registrar request exitosa
  void _recordSuccessfulRequest(DateTime startTime, String? operationName) {
    final now = DateTime.now();
    _requestTimes.add(now);
    _lastRequestTime = now;

    // Limpiar requests antiguas
    _cleanOldRequests(now);

    // Consumir token si es token bucket
    if (strategy == RateLimitStrategy.tokenBucket) {
      _tokenCount = (_tokenCount - 1).clamp(0, maxRequests);
    }

    final duration = now.difference(startTime);
    developer.log(
        '✅ Request completada: $serviceName${operationName != null ? ' ($operationName)' : ''} - ${duration.inMilliseconds}ms');
  }

  /// Registrar request fallida
  void _recordFailedRequest(
      DateTime startTime, String? operationName, dynamic error) {
    final now = DateTime.now();
    _requestTimes.add(now);
    _lastRequestTime = now;

    // Limpiar requests antiguas
    _cleanOldRequests(now);

    // Consumir token si es token bucket (incluso en error)
    if (strategy == RateLimitStrategy.tokenBucket) {
      _tokenCount = (_tokenCount - 1).clamp(0, maxRequests);
    }

    final duration = now.difference(startTime);
    developer.log(
        '❌ Request fallida: $serviceName${operationName != null ? ' ($operationName)' : ''} - ${duration.inMilliseconds}ms - Error: $error');
  }

  /// Limpiar requests antiguas del historial
  void _cleanOldRequests(DateTime now) {
    while (_requestTimes.isNotEmpty &&
        now.difference(_requestTimes.first) > timeWindow) {
      _requestTimes.removeFirst();
    }
  }

  // Implementaciones de estrategias específicas

  bool _canMakeRequestSlidingWindow(DateTime now) {
    _cleanOldRequests(now);
    return _requestTimes.length < maxRequests;
  }

  bool _canMakeRequestTokenBucket(DateTime now) {
    _refillTokens(now);
    return _tokenCount > 0;
  }

  bool _canMakeRequestFixedWindow(DateTime now) {
    final windowStart = DateTime(now.year, now.month, now.day, now.hour,
        (now.minute ~/ (timeWindow.inMinutes)) * (timeWindow.inMinutes));

    final requestsInWindow =
        _requestTimes.where((time) => time.isAfter(windowStart)).length;

    return requestsInWindow < maxRequests;
  }

  Duration _getWaitTimeSlidingWindow(DateTime now) {
    _cleanOldRequests(now);

    if (_requestTimes.length < maxRequests) {
      return Duration.zero;
    }

    final oldestRequest = _requestTimes.first;
    final waitUntil = oldestRequest.add(timeWindow);

    return waitUntil.isAfter(now) ? waitUntil.difference(now) : Duration.zero;
  }

  Duration _getWaitTimeTokenBucket(DateTime now) {
    _refillTokens(now);

    if (_tokenCount > 0) {
      return Duration.zero;
    }

    // Calcular cuándo estará disponible el próximo token
    final tokensPerSecond = maxRequests / timeWindow.inSeconds;
    final secondsUntilNextToken = 1 / tokensPerSecond;

    return Duration(milliseconds: (secondsUntilNextToken * 1000).round());
  }

  Duration _getWaitTimeFixedWindow(DateTime now) {
    final windowStart = DateTime(now.year, now.month, now.day, now.hour,
        (now.minute ~/ (timeWindow.inMinutes)) * (timeWindow.inMinutes));

    final requestsInWindow =
        _requestTimes.where((time) => time.isAfter(windowStart)).length;

    if (requestsInWindow < maxRequests) {
      return Duration.zero;
    }

    final nextWindow = windowStart.add(timeWindow);
    return nextWindow.isAfter(now) ? nextWindow.difference(now) : Duration.zero;
  }

  void _refillTokens(DateTime now) {
    final timeSinceLastRefill = now.difference(_lastTokenRefill);
    final tokensToAdd =
        (timeSinceLastRefill.inSeconds * maxRequests / timeWindow.inSeconds)
            .floor();

    if (tokensToAdd > 0) {
      _tokenCount = (_tokenCount + tokensToAdd).clamp(0, maxRequests);
      _lastTokenRefill = now;
    }
  }
}

/// Estrategias de rate limiting
enum RateLimitStrategy {
  /// Ventana deslizante - más precisa pero usa más memoria
  slidingWindow,

  /// Token bucket - buena para ráfagas controladas
  tokenBucket,

  /// Ventana fija - más simple pero menos precisa
  fixedWindow,
}

/// Estadísticas del rate limiter
class RateLimiterStats {
  RateLimiterStats({
    required this.serviceName,
    required this.currentRequests,
    required this.maxRequests,
    required this.timeWindow,
    required this.utilizationPercent,
    required this.waitingQueueSize,
    required this.lastRequestTime,
    required this.canMakeRequest,
    required this.estimatedWaitTime,
    this.availableTokens,
  });
  final String serviceName;
  final int currentRequests;
  final int maxRequests;
  final Duration timeWindow;
  final int utilizationPercent;
  final int waitingQueueSize;
  final DateTime? lastRequestTime;
  final bool canMakeRequest;
  final Duration estimatedWaitTime;
  final int? availableTokens;

  Map<String, dynamic> toJson() => {
        'serviceName': serviceName,
        'currentRequests': currentRequests,
        'maxRequests': maxRequests,
        'timeWindowSeconds': timeWindow.inSeconds,
        'utilizationPercent': utilizationPercent,
        'waitingQueueSize': waitingQueueSize,
        'lastRequestTime': lastRequestTime?.toIso8601String(),
        'canMakeRequest': canMakeRequest,
        'estimatedWaitTimeMs': estimatedWaitTime.inMilliseconds,
        if (availableTokens != null) 'availableTokens': availableTokens,
      };
}

/// Utilidad para crear rate limiters con configuraciones predefinidas
class RateLimiterFactory {
  /// Rate limiter para desarrollo (más permisivo)
  static RateLimiter development(String serviceName) => RateLimiter.forService(
        '${serviceName}_dev',
        maxRequests: 100,
        timeWindow: Duration(minutes: 1),
        minInterval: Duration(milliseconds: 100),
        strategy: RateLimitStrategy.slidingWindow,
      );

  /// Rate limiter para producción (más restrictivo)
  static RateLimiter production(
    String serviceName, {
    required int maxRequests,
    required Duration timeWindow,
  }) =>
      RateLimiter.forService(
        '${serviceName}_prod',
        maxRequests: maxRequests,
        timeWindow: timeWindow,
        minInterval: Duration(milliseconds: 500),
        strategy: RateLimitStrategy.tokenBucket,
      );

  /// Rate limiter para testing (sin límites)
  static RateLimiter testing(String serviceName) => RateLimiter.forService(
        '${serviceName}_test',
        maxRequests: 10000,
        timeWindow: Duration(seconds: 1),
        strategy: RateLimitStrategy.slidingWindow,
      );
}
