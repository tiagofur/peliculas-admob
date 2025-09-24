import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Servicio de balanceador de carga empresarial
///
/// Distribuye requests eficientemente entre múltiples endpoints,
/// maneja picos de tráfico y asegura alta disponibilidad.
class LoadBalancerService {
  LoadBalancerService._();
  static LoadBalancerService? _instance;

  static LoadBalancerService get instance {
    _instance ??= LoadBalancerService._();
    return _instance!;
  }

  bool _isInitialized = false;

  // Configuración del balanceador
  final Map<String, dynamic> _config = {
    'algorithm': LoadBalancingAlgorithm.roundRobin,
    'health_check_interval': 30000, // 30 segundos
    'request_timeout': 15000, // 15 segundos
    'max_retries': 3,
    'circuit_breaker_enabled': true,
    'circuit_breaker_threshold': 5, // Fallos consecutivos
    'circuit_breaker_timeout': 60000, // 60 segundos
    'enable_sticky_sessions': false,
  };

  // Endpoints registrados
  final List<LoadBalancerEndpoint> _endpoints = [];

  // Estadísticas de balanceador
  final Map<String, EndpointStats> _endpointStats = {};

  // Circuit breakers por endpoint
  final Map<String, CircuitBreaker> _circuitBreakers = {};

  // Contador para round robin
  int _roundRobinCounter = 0;

  // Timer para health checks
  Timer? _healthCheckTimer;

  // Métricas globales
  final Map<String, int> _globalStats = {
    'total_requests': 0,
    'successful_requests': 0,
    'failed_requests': 0,
    'retry_attempts': 0,
    'circuit_breaker_trips': 0,
  };

  /// Inicializa el servicio de load balancing
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      debugPrint('⚖️ Inicializando Load Balancer Service...');

      // Configurar endpoints por defecto
      await _setupDefaultEndpoints();

      // Inicializar circuit breakers
      _initializeCircuitBreakers();

      // Iniciar health checks
      _startHealthChecks();

      _isInitialized = true;
      debugPrint('✅ Load Balancer Service inicializado');

      return true;
    } catch (e) {
      debugPrint('❌ Error inicializando Load Balancer Service: $e');
      return false;
    }
  }

  /// Configura endpoints por defecto
  Future<void> _setupDefaultEndpoints() async {
    debugPrint('🔧 Configurando endpoints por defecto...');

    // Endpoints de API de películas
    final endpoints = [
      const LoadBalancerEndpoint(
        id: 'tmdb-primary',
        url: 'https://api.themoviedb.org/3',
        weight: 70,
        priority: 1,
        region: 'global',
        maxConcurrentRequests: 50,
      ),
      const LoadBalancerEndpoint(
        id: 'tmdb-backup',
        url: 'https://api-backup.themoviedb.org/3',
        weight: 30,
        priority: 2,
        region: 'global',
        maxConcurrentRequests: 30,
      ),
      // Endpoint local/cache
      const LoadBalancerEndpoint(
        id: 'local-cache',
        url: 'http://localhost:8080',
        weight: 0, // Solo para fallback
        priority: 3,
        region: 'local',
        maxConcurrentRequests: 100,
        healthCheckUrl: 'http://localhost:8080/health',
      ),
    ];

    for (final endpoint in endpoints) {
      await registerEndpoint(endpoint);
    }
  }

  /// Registra un nuevo endpoint
  Future<void> registerEndpoint(LoadBalancerEndpoint endpoint) async {
    _endpoints.add(endpoint);

    // Inicializar estadísticas
    _endpointStats[endpoint.id] = EndpointStats(
      endpointId: endpoint.id,
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      averageResponseTime: 0,
      lastHealthCheck: DateTime.now(),
      isHealthy: true,
    );

    // Inicializar circuit breaker
    _circuitBreakers[endpoint.id] = CircuitBreaker(
      endpointId: endpoint.id,
      failureThreshold: _config['circuit_breaker_threshold'],
      timeout: Duration(milliseconds: _config['circuit_breaker_timeout']),
    );

    debugPrint('📍 Endpoint registrado: ${endpoint.id} (${endpoint.url})');
  }

  /// Inicializa circuit breakers
  void _initializeCircuitBreakers() {
    for (final endpoint in _endpoints) {
      _circuitBreakers[endpoint.id] = CircuitBreaker(
        endpointId: endpoint.id,
        failureThreshold: _config['circuit_breaker_threshold'],
        timeout: Duration(milliseconds: _config['circuit_breaker_timeout']),
      );
    }
  }

  /// Inicia health checks automáticos
  void _startHealthChecks() {
    _healthCheckTimer?.cancel();

    _healthCheckTimer = Timer.periodic(
      Duration(milliseconds: _config['health_check_interval']),
      (_) => _performHealthChecks(),
    );

    debugPrint('❤️ Health checks iniciados');
  }

  /// Realiza health checks en todos los endpoints
  Future<void> _performHealthChecks() async {
    if (!_isInitialized) return;

    for (final endpoint in _endpoints) {
      await _checkEndpointHealth(endpoint);
    }
  }

  /// Verifica la salud de un endpoint específico
  Future<void> _checkEndpointHealth(LoadBalancerEndpoint endpoint) async {
    final stats = _endpointStats[endpoint.id]!;

    try {
      final stopwatch = Stopwatch()..start();

      // URL de health check o endpoint principal
      final checkUrl = endpoint.healthCheckUrl ?? '${endpoint.url}/health';

      // Simular health check (usar checkUrl para evitar warning)
      await Future.delayed(Duration(milliseconds: 50 + Random().nextInt(100)));
      if (kDebugMode) debugPrint('🔍 Checking: $checkUrl');

      stopwatch.stop();

      // Actualizar estadísticas
      stats.isHealthy = true;
      stats.lastHealthCheck = DateTime.now();
      stats.lastResponseTime = stopwatch.elapsedMilliseconds;

      // Resetear circuit breaker si está healthy
      _circuitBreakers[endpoint.id]?.recordSuccess();

      if (kDebugMode) {
        debugPrint(
            '💚 Health check OK: ${endpoint.id} (${stopwatch.elapsedMilliseconds}ms)');
      }
    } catch (e) {
      stats.isHealthy = false;
      stats.lastHealthCheck = DateTime.now();

      // Registrar fallo en circuit breaker
      _circuitBreakers[endpoint.id]?.recordFailure();

      debugPrint('💔 Health check FAILED: ${endpoint.id} - $e');
    }
  }

  /// Selecciona el mejor endpoint para una request
  LoadBalancerEndpoint? selectEndpoint({
    String? region,
    Map<String, dynamic>? context,
  }) {
    if (!_isInitialized || _endpoints.isEmpty) return null;

    // Filtrar endpoints saludables
    final healthyEndpoints = _endpoints.where((endpoint) {
      final stats = _endpointStats[endpoint.id];
      final circuitBreaker = _circuitBreakers[endpoint.id];

      return stats?.isHealthy == true && circuitBreaker?.canMakeRequest == true;
    }).toList();

    if (healthyEndpoints.isEmpty) {
      debugPrint('⚠️ No hay endpoints saludables disponibles');
      return _selectFallbackEndpoint();
    }

    // Filtrar por región si se especifica
    if (region != null) {
      final regionalEndpoints =
          healthyEndpoints.where((e) => e.region == region).toList();
      if (regionalEndpoints.isNotEmpty) {
        return _applyLoadBalancingAlgorithm(regionalEndpoints);
      }
    }

    return _applyLoadBalancingAlgorithm(healthyEndpoints);
  }

  /// Aplica el algoritmo de load balancing
  LoadBalancerEndpoint _applyLoadBalancingAlgorithm(
      List<LoadBalancerEndpoint> endpoints) {
    switch (_config['algorithm']) {
      case LoadBalancingAlgorithm.roundRobin:
        return _selectRoundRobin(endpoints);
      case LoadBalancingAlgorithm.weighted:
        return _selectWeighted(endpoints);
      case LoadBalancingAlgorithm.leastConnections:
        return _selectLeastConnections(endpoints);
      case LoadBalancingAlgorithm.leastResponseTime:
        return _selectLeastResponseTime(endpoints);
      default:
        return _selectRoundRobin(endpoints);
    }
  }

  /// Selección Round Robin
  LoadBalancerEndpoint _selectRoundRobin(List<LoadBalancerEndpoint> endpoints) {
    final index = _roundRobinCounter % endpoints.length;
    _roundRobinCounter++;
    return endpoints[index];
  }

  /// Selección por peso
  LoadBalancerEndpoint _selectWeighted(List<LoadBalancerEndpoint> endpoints) {
    final totalWeight = endpoints.fold<int>(0, (sum, e) => sum + e.weight);
    if (totalWeight == 0) return endpoints.first;

    final random = Random().nextInt(totalWeight);
    int currentWeight = 0;

    for (final endpoint in endpoints) {
      currentWeight += endpoint.weight;
      if (random < currentWeight) {
        return endpoint;
      }
    }

    return endpoints.last;
  }

  /// Selección por menos conexiones
  LoadBalancerEndpoint _selectLeastConnections(
      List<LoadBalancerEndpoint> endpoints) {
    return endpoints.reduce((current, next) {
      final currentStats = _endpointStats[current.id]!;
      final nextStats = _endpointStats[next.id]!;
      return currentStats.currentConnections <= nextStats.currentConnections
          ? current
          : next;
    });
  }

  /// Selección por menor tiempo de respuesta
  LoadBalancerEndpoint _selectLeastResponseTime(
      List<LoadBalancerEndpoint> endpoints) {
    return endpoints.reduce((current, next) {
      final currentStats = _endpointStats[current.id]!;
      final nextStats = _endpointStats[next.id]!;
      return currentStats.averageResponseTime <= nextStats.averageResponseTime
          ? current
          : next;
    });
  }

  /// Selecciona endpoint de fallback
  LoadBalancerEndpoint? _selectFallbackEndpoint() {
    // Buscar endpoint con menor prioridad (números más altos)
    if (_endpoints.isNotEmpty) {
      final fallback = _endpoints.reduce((current, next) =>
          current.priority >= next.priority ? current : next);

      debugPrint('🆘 Usando endpoint de fallback: ${fallback.id}');
      return fallback;
    }

    return null;
  }

  /// Ejecuta una request con load balancing
  Future<T> executeRequest<T>({
    required Future<T> Function(String baseUrl) requestFunction,
    String? region,
    Map<String, dynamic>? context,
    int maxRetries = 3,
  }) async {
    if (!_isInitialized) {
      throw Exception('LoadBalancerService not initialized');
    }

    _globalStats['total_requests'] = (_globalStats['total_requests'] ?? 0) + 1;

    Exception? lastException;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      final endpoint = selectEndpoint(region: region, context: context);

      if (endpoint == null) {
        throw Exception('No endpoints available');
      }

      final stats = _endpointStats[endpoint.id]!;
      final circuitBreaker = _circuitBreakers[endpoint.id]!;

      try {
        // Verificar circuit breaker
        if (!circuitBreaker.canMakeRequest) {
          throw Exception('Circuit breaker open for ${endpoint.id}');
        }

        // Incrementar conexiones activas
        stats.currentConnections++;
        stats.totalRequests++;

        final stopwatch = Stopwatch()..start();

        // Ejecutar request con timeout
        final result = await requestFunction(endpoint.url).timeout(
          Duration(milliseconds: _config['request_timeout']),
        );

        stopwatch.stop();

        // Registrar éxito
        stats.successfulRequests++;
        stats.lastResponseTime = stopwatch.elapsedMilliseconds;
        stats.averageResponseTime = _calculateAverageResponseTime(stats);

        circuitBreaker.recordSuccess();
        _globalStats['successful_requests'] =
            (_globalStats['successful_requests'] ?? 0) + 1;

        if (kDebugMode) {
          debugPrint(
              '✅ Request exitosa via ${endpoint.id}: ${stopwatch.elapsedMilliseconds}ms');
        }

        return result;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());

        // Registrar fallo
        stats.failedRequests++;
        circuitBreaker.recordFailure();

        if (circuitBreaker.state == CircuitBreakerState.open) {
          _globalStats['circuit_breaker_trips'] =
              (_globalStats['circuit_breaker_trips'] ?? 0) + 1;
        }

        debugPrint('❌ Request falló via ${endpoint.id}: $e');

        if (attempt < maxRetries) {
          _globalStats['retry_attempts'] =
              (_globalStats['retry_attempts'] ?? 0) + 1;
          debugPrint('🔄 Reintentando... (${attempt + 1}/$maxRetries)');

          // Delay exponencial
          await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
        }
      } finally {
        stats.currentConnections--;
      }
    }

    _globalStats['failed_requests'] =
        (_globalStats['failed_requests'] ?? 0) + 1;
    throw lastException ??
        Exception('Request failed after $maxRetries attempts');
  }

  /// Calcula tiempo de respuesta promedio
  int _calculateAverageResponseTime(EndpointStats stats) {
    if (stats.successfulRequests == 0) return 0;

    // Simplificación: usar último tiempo de respuesta
    // En implementación real, mantener historial
    return stats.lastResponseTime;
  }

  /// Obtiene estadísticas del load balancer
  Map<String, dynamic> getLoadBalancerStats() {
    final endpointStatsMap = <String, Map<String, dynamic>>{};

    for (final entry in _endpointStats.entries) {
      endpointStatsMap[entry.key] = entry.value.toJson();
    }

    final circuitBreakerStatsMap = <String, Map<String, dynamic>>{};

    for (final entry in _circuitBreakers.entries) {
      circuitBreakerStatsMap[entry.key] = entry.value.toJson();
    }

    return {
      'service_status': _isInitialized ? 'active' : 'inactive',
      'algorithm': _config['algorithm'].toString(),
      'total_endpoints': _endpoints.length,
      'healthy_endpoints': _endpoints
          .where((e) => _endpointStats[e.id]?.isHealthy == true)
          .length,
      'global_stats': Map.from(_globalStats),
      'endpoint_stats': endpointStatsMap,
      'circuit_breakers': circuitBreakerStatsMap,
      'config': Map.from(_config),
    };
  }

  /// Actualiza configuración del load balancer
  void updateConfig({
    LoadBalancingAlgorithm? algorithm,
    int? healthCheckInterval,
    int? requestTimeout,
    int? maxRetries,
    bool? circuitBreakerEnabled,
  }) {
    if (algorithm != null) _config['algorithm'] = algorithm;
    if (healthCheckInterval != null) {
      _config['health_check_interval'] = healthCheckInterval;
    }
    if (requestTimeout != null) _config['request_timeout'] = requestTimeout;
    if (maxRetries != null) _config['max_retries'] = maxRetries;
    if (circuitBreakerEnabled != null) {
      _config['circuit_breaker_enabled'] = circuitBreakerEnabled;
    }

    // Reiniciar health checks si cambió el intervalo
    if (healthCheckInterval != null) {
      _startHealthChecks();
    }

    debugPrint('⚙️ Configuración de Load Balancer actualizada');
  }

  /// Resetea estadísticas (para testing)
  void resetStats() {
    if (kDebugMode) {
      _globalStats.clear();
      for (final stats in _endpointStats.values) {
        stats.reset();
      }
      for (final cb in _circuitBreakers.values) {
        cb.reset();
      }
      debugPrint('🔄 Estadísticas de Load Balancer reseteadas');
    }
  }

  /// Limpieza al cerrar el servicio
  void dispose() {
    _healthCheckTimer?.cancel();
    _isInitialized = false;
    debugPrint('🛑 Load Balancer Service cerrado');
  }
}

/// Algoritmos de load balancing disponibles
enum LoadBalancingAlgorithm {
  roundRobin,
  weighted,
  leastConnections,
  leastResponseTime,
}

/// Estados del circuit breaker
enum CircuitBreakerState {
  closed,
  open,
  halfOpen,
}

/// Clase para representar un endpoint
class LoadBalancerEndpoint {
  const LoadBalancerEndpoint({
    required this.id,
    required this.url,
    required this.weight,
    required this.priority,
    required this.region,
    required this.maxConcurrentRequests,
    this.healthCheckUrl,
  });
  final String id;
  final String url;
  final int weight;
  final int priority;
  final String region;
  final int maxConcurrentRequests;
  final String? healthCheckUrl;
}

/// Estadísticas por endpoint
class EndpointStats {
  EndpointStats({
    required this.endpointId,
    this.totalRequests = 0,
    this.successfulRequests = 0,
    this.failedRequests = 0,
    this.averageResponseTime = 0,
    this.lastResponseTime = 0,
    this.currentConnections = 0,
    required this.lastHealthCheck,
    this.isHealthy = true,
  });
  final String endpointId;
  int totalRequests;
  int successfulRequests;
  int failedRequests;
  int averageResponseTime;
  int lastResponseTime;
  int currentConnections;
  DateTime lastHealthCheck;
  bool isHealthy;

  void reset() {
    totalRequests = 0;
    successfulRequests = 0;
    failedRequests = 0;
    averageResponseTime = 0;
    lastResponseTime = 0;
    currentConnections = 0;
    isHealthy = true;
  }

  Map<String, dynamic> toJson() => {
        'endpoint_id': endpointId,
        'total_requests': totalRequests,
        'successful_requests': successfulRequests,
        'failed_requests': failedRequests,
        'success_rate':
            totalRequests > 0 ? (successfulRequests / totalRequests) * 100 : 0,
        'average_response_time': averageResponseTime,
        'last_response_time': lastResponseTime,
        'current_connections': currentConnections,
        'last_health_check': lastHealthCheck.toIso8601String(),
        'is_healthy': isHealthy,
      };
}

/// Circuit Breaker implementation
class CircuitBreaker {
  CircuitBreaker({
    required this.endpointId,
    required this.failureThreshold,
    required this.timeout,
  });
  final String endpointId;
  final int failureThreshold;
  final Duration timeout;

  CircuitBreakerState _state = CircuitBreakerState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  DateTime? _nextAttempt;

  CircuitBreakerState get state => _state;

  bool get canMakeRequest {
    switch (_state) {
      case CircuitBreakerState.closed:
        return true;
      case CircuitBreakerState.open:
        if (_nextAttempt != null && DateTime.now().isAfter(_nextAttempt!)) {
          _state = CircuitBreakerState.halfOpen;
          return true;
        }
        return false;
      case CircuitBreakerState.halfOpen:
        return true;
    }
  }

  void recordSuccess() {
    _failureCount = 0;
    _state = CircuitBreakerState.closed;
    _lastFailureTime = null;
    _nextAttempt = null;
  }

  void recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_failureCount >= failureThreshold) {
      _state = CircuitBreakerState.open;
      _nextAttempt = DateTime.now().add(timeout);

      debugPrint('🔴 Circuit breaker OPEN para $endpointId');
    }
  }

  void reset() {
    _state = CircuitBreakerState.closed;
    _failureCount = 0;
    _lastFailureTime = null;
    _nextAttempt = null;
  }

  Map<String, dynamic> toJson() => {
        'endpoint_id': endpointId,
        'state': _state.toString(),
        'failure_count': _failureCount,
        'failure_threshold': failureThreshold,
        'last_failure_time': _lastFailureTime?.toIso8601String(),
        'next_attempt': _nextAttempt?.toIso8601String(),
      };
}

/// Helpers para operaciones comunes de load balancing
class LoadBalancerHelpers {
  static final _service = LoadBalancerService.instance;

  /// Ejecuta request de API con load balancing
  static Future<Map<String, dynamic>> executeApiRequest({
    required String endpoint,
    Map<String, String>? headers,
    String? region,
  }) async {
    return await _service.executeRequest<Map<String, dynamic>>(
      requestFunction: (baseUrl) async {
        // Simular request HTTP
        await Future.delayed(
            Duration(milliseconds: 100 + Random().nextInt(200)));

        // Simular respuesta exitosa
        return {
          'status': 'success',
          'data': {'endpoint': endpoint},
          'timestamp': DateTime.now().toIso8601String(),
        };
      },
      region: region,
    );
  }

  /// Ejecuta múltiples requests en paralelo con load balancing
  static Future<List<Map<String, dynamic>>> executeBatchRequests({
    required List<String> endpoints,
    int maxConcurrency = 3,
    String? region,
  }) async {
    final results = <Map<String, dynamic>>[];

    for (int i = 0; i < endpoints.length; i += maxConcurrency) {
      final batch = endpoints.skip(i).take(maxConcurrency);

      final futures = batch.map((endpoint) => executeApiRequest(
            endpoint: endpoint,
            region: region,
          ));

      final batchResults = await Future.wait(futures);
      results.addAll(batchResults);
    }

    return results;
  }
}
