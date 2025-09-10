import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';

import '../logging/logger_factory.dart';

/// Servicio de configuración de red que detecta la calidad de conexión
/// y ajusta automáticamente los parámetros de sincronización
class NetworkConfigurationService {
  NetworkConfigurationService._() {
    _initialize();
  }
  static NetworkConfigurationService? _instance;
  static NetworkConfigurationService get instance {
    _instance ??= NetworkConfigurationService._();
    return _instance!;
  }

  // Conectividad y monitoreo
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Estado actual de la red
  NetworkQuality _currentQuality = NetworkQuality.unknown;
  ConnectivityResult _currentConnectivity = ConnectivityResult.none;
  NetworkMetrics _currentMetrics = NetworkMetrics.empty();

  // Configuraciones adaptativas
  final Map<NetworkQuality, NetworkConfig> _configurations = {};

  // Monitoreo de rendimiento
  final List<LatencyMeasurement> _latencyHistory = [];
  final List<BandwidthMeasurement> _bandwidthHistory = [];
  Timer? _performanceMonitorTimer;

  // Eventos de cambio de configuración
  final StreamController<NetworkConfigurationChange> _configChangeController =
      StreamController<NetworkConfigurationChange>.broadcast();

  // Estado del servicio
  bool _isInitialized = false;
  bool _isDisposed = false;

  // Constantes de configuración
  static const Duration _performanceCheckInterval = Duration(seconds: 30);
  static const int _maxLatencyHistory = 20;
  static const int _maxBandwidthHistory = 10;
  static const Duration _networkTestTimeout = Duration(seconds: 10);

  /// Stream de cambios de configuración de red
  Stream<NetworkConfigurationChange> get configurationChanges =>
      _configChangeController.stream;

  /// Calidad actual de la red
  NetworkQuality get currentQuality => _currentQuality;

  /// Tipo de conectividad actual
  ConnectivityResult get currentConnectivity => _currentConnectivity;

  /// Métricas actuales de red
  NetworkMetrics get currentMetrics => _currentMetrics;

  /// Configuración actual basada en la calidad de red
  NetworkConfig get currentConfiguration =>
      _configurations[_currentQuality] ?? NetworkConfig.defaultConfig();

  /// Indica si el servicio está inicializado
  bool get isInitialized => _isInitialized;

  // =============================================
  // INICIALIZACIÓN
  // =============================================

  /// Inicializa el servicio de configuración de red
  Future<void> _initialize() async {
    if (_isInitialized || _isDisposed) return;

    try {
      // Configurar configuraciones por defecto
      _setupDefaultConfigurations();

      // Detectar conectividad inicial
      final connectivityResults = await _connectivity.checkConnectivity();
      _currentConnectivity = connectivityResults.isNotEmpty
          ? connectivityResults.first
          : ConnectivityResult.none;

      // Configurar listener de cambios de conectividad
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (results) => _onConnectivityChanged(
            results.isNotEmpty ? results.first : ConnectivityResult.none),
        onError: (error) {
          LoggerFactory.error('❌ Connectivity listener error: $error');
        },
      );

      // Realizar evaluación inicial de calidad
      await _evaluateNetworkQuality();

      // Iniciar monitoreo de rendimiento
      _startPerformanceMonitoring();

      _isInitialized = true;

      LoggerFactory.info('🌐 NetworkConfigurationService initialized');
      LoggerFactory.info(
          '📶 Initial network: ${_currentConnectivity.name}, quality: ${_currentQuality.name}');
    } catch (e) {
      LoggerFactory.error(
          '❌ Failed to initialize NetworkConfigurationService: $e');
      _isInitialized = true; // Continue even if initialization fails
    }
  }

  /// Configura las configuraciones por defecto para cada calidad de red
  void _setupDefaultConfigurations() {
    _configurations[NetworkQuality.excellent] = const NetworkConfig(
      syncInterval: Duration(seconds: 5),
      batchSize: 100,
      maxConcurrentOperations: 10,
      timeoutDuration: Duration(seconds: 30),
      retryAttempts: 3,
      retryDelay: Duration(seconds: 1),
      heartbeatInterval: Duration(seconds: 15),
      enableRealtime: true,
      enableBatching: true,
      compressionEnabled: false,
      prefetchEnabled: true,
      cacheSize: 1000,
      description: 'Excellent connection - Maximum performance',
    );

    _configurations[NetworkQuality.good] = const NetworkConfig(
      syncInterval: Duration(seconds: 10),
      batchSize: 50,
      maxConcurrentOperations: 6,
      timeoutDuration: Duration(seconds: 45),
      retryAttempts: 3,
      retryDelay: Duration(seconds: 2),
      heartbeatInterval: Duration(seconds: 30),
      enableRealtime: true,
      enableBatching: true,
      compressionEnabled: false,
      prefetchEnabled: true,
      cacheSize: 500,
      description: 'Good connection - Balanced performance',
    );

    _configurations[NetworkQuality.fair] = const NetworkConfig(
      syncInterval: Duration(seconds: 30),
      batchSize: 25,
      maxConcurrentOperations: 3,
      timeoutDuration: Duration(minutes: 1),
      retryAttempts: 4,
      retryDelay: Duration(seconds: 3),
      heartbeatInterval: Duration(minutes: 1),
      enableRealtime: true,
      enableBatching: true,
      compressionEnabled: true,
      prefetchEnabled: false,
      cacheSize: 250,
      description: 'Fair connection - Conservative approach',
    );

    _configurations[NetworkQuality.poor] = const NetworkConfig(
      syncInterval: Duration(minutes: 2),
      batchSize: 10,
      maxConcurrentOperations: 1,
      timeoutDuration: Duration(minutes: 2),
      retryAttempts: 5,
      retryDelay: Duration(seconds: 5),
      heartbeatInterval: Duration(minutes: 2),
      enableRealtime: false,
      enableBatching: true,
      compressionEnabled: true,
      prefetchEnabled: false,
      cacheSize: 100,
      description: 'Poor connection - Minimal operations',
    );

    _configurations[NetworkQuality.offline] = const NetworkConfig(
      syncInterval: Duration(minutes: 10),
      batchSize: 1,
      maxConcurrentOperations: 1,
      timeoutDuration: Duration(minutes: 5),
      retryAttempts: 10,
      retryDelay: Duration(seconds: 10),
      heartbeatInterval: Duration(minutes: 5),
      enableRealtime: false,
      enableBatching: false,
      compressionEnabled: true,
      prefetchEnabled: false,
      cacheSize: 50,
      description: 'Offline mode - Queue operations',
    );

    _configurations[NetworkQuality.unknown] = const NetworkConfig(
      syncInterval: Duration(seconds: 30),
      batchSize: 20,
      maxConcurrentOperations: 2,
      timeoutDuration: Duration(seconds: 60),
      retryAttempts: 3,
      retryDelay: Duration(seconds: 3),
      heartbeatInterval: Duration(seconds: 45),
      enableRealtime: true,
      enableBatching: true,
      compressionEnabled: false,
      prefetchEnabled: false,
      cacheSize: 200,
      description: 'Unknown connection - Safe defaults',
    );
  }

  // =============================================
  // MONITOREO DE CONECTIVIDAD
  // =============================================

  /// Maneja cambios en la conectividad
  Future<void> _onConnectivityChanged(ConnectivityResult result) async {
    if (_isDisposed) return;

    final previousConnectivity = _currentConnectivity;
    _currentConnectivity = result;

    LoggerFactory.info(
        '🔄 Connectivity changed: ${previousConnectivity.name} → ${result.name}');

    // Re-evaluar calidad de red
    await _evaluateNetworkQuality();
  }

  /// Evalúa la calidad actual de la red
  Future<void> _evaluateNetworkQuality() async {
    if (_isDisposed) return;

    try {
      final previousQuality = _currentQuality;

      // Determinar calidad base según tipo de conectividad
      NetworkQuality baseQuality =
          _getBaseQualityFromConnectivity(_currentConnectivity);

      // Si no hay conectividad, establecer como offline
      if (_currentConnectivity == ConnectivityResult.none) {
        _currentQuality = NetworkQuality.offline;
      } else {
        // Realizar pruebas de rendimiento para ajustar calidad
        final metrics = await _performNetworkTests();
        _currentMetrics = metrics;

        // Ajustar calidad basada en métricas reales
        _currentQuality = _calculateQualityFromMetrics(baseQuality, metrics);
      }

      // Emitir evento si la calidad cambió
      if (previousQuality != _currentQuality) {
        final change = NetworkConfigurationChange(
          previousQuality: previousQuality,
          newQuality: _currentQuality,
          previousConfig: _configurations[previousQuality]!,
          newConfig: _configurations[_currentQuality]!,
          timestamp: DateTime.now(),
          metrics: _currentMetrics,
        );

        _configChangeController.add(change);

        LoggerFactory.info(
            '📶 Network quality changed: ${previousQuality.name} → ${_currentQuality.name}');
        LoggerFactory.info(
            '⚙️ New configuration: ${currentConfiguration.description}');
      }
    } catch (e) {
      LoggerFactory.error('❌ Failed to evaluate network quality: $e');
      _currentQuality = NetworkQuality.unknown;
    }
  }

  /// Obtiene calidad base según el tipo de conectividad
  NetworkQuality _getBaseQualityFromConnectivity(
      ConnectivityResult connectivity) {
    switch (connectivity) {
      case ConnectivityResult.wifi:
        return NetworkQuality.good; // WiFi generalmente es bueno
      case ConnectivityResult.ethernet:
        return NetworkQuality.excellent; // Ethernet es excelente
      case ConnectivityResult.mobile:
        return NetworkQuality.fair; // Móvil es variable
      case ConnectivityResult.bluetooth:
        return NetworkQuality.poor; // Bluetooth es limitado
      case ConnectivityResult.vpn:
        return NetworkQuality.fair; // VPN puede ser variable
      case ConnectivityResult.other:
        return NetworkQuality.unknown;
      case ConnectivityResult.none:
        return NetworkQuality.offline;
    }
  }

  // =============================================
  // PRUEBAS DE RENDIMIENTO
  // =============================================

  /// Realiza pruebas de rendimiento de red
  Future<NetworkMetrics> _performNetworkTests() async {
    try {
      // Medir latencia
      final latency = await _measureLatency();

      // Estimar ancho de banda (simplificado)
      final bandwidth = await _estimateBandwidth();

      // Medir pérdida de paquetes (simplificado)
      final packetLoss = await _estimatePacketLoss();

      final metrics = NetworkMetrics(
        latency: latency,
        bandwidth: bandwidth,
        packetLoss: packetLoss,
        timestamp: DateTime.now(),
        connectivityType: _currentConnectivity,
      );

      // Guardar en historial
      _addLatencyMeasurement(latency);
      _addBandwidthMeasurement(bandwidth);

      return metrics;
    } catch (e) {
      LoggerFactory.warning('⚠️ Network tests failed: $e');
      return NetworkMetrics.empty();
    }
  }

  /// Mide la latencia de red
  Future<Duration> _measureLatency() async {
    try {
      final stopwatch = Stopwatch()..start();

      // Usar Google DNS para prueba de latencia
      final socket =
          await Socket.connect('8.8.8.8', 53, timeout: _networkTestTimeout);

      stopwatch.stop();
      await socket.close();

      return stopwatch.elapsed;
    } catch (e) {
      // Si falla, usar latencia por defecto alta
      return const Duration(milliseconds: 1000);
    }
  }

  /// Estima el ancho de banda (simplificado)
  Future<double> _estimateBandwidth() async {
    try {
      // Realizar una pequeña descarga para estimar velocidad
      final client = HttpClient();
      client.connectionTimeout = _networkTestTimeout;

      final stopwatch = Stopwatch()..start();

      final request =
          await client.getUrl(Uri.parse('https://httpbin.org/bytes/1024'));
      final response = await request.close();

      int totalBytes = 0;
      await for (final chunk in response) {
        totalBytes += chunk.length;
      }

      stopwatch.stop();
      client.close();

      // Calcular Mbps
      final seconds = stopwatch.elapsedMilliseconds / 1000.0;
      final mbps = (totalBytes * 8) / (seconds * 1000000);

      return mbps;
    } catch (e) {
      // Si falla, asumir ancho de banda bajo
      return 1.0; // 1 Mbps por defecto
    }
  }

  /// Estima la pérdida de paquetes (simplificado)
  Future<double> _estimatePacketLoss() async {
    try {
      int successfulPings = 0;
      const int totalPings = 5;

      for (int i = 0; i < totalPings; i++) {
        try {
          final socket = await Socket.connect('8.8.8.8', 53,
              timeout: const Duration(seconds: 2));
          await socket.close();
          successfulPings++;
        } catch (e) {
          // Ping falló
        }
      }

      final lossRate = (totalPings - successfulPings) / totalPings;
      return lossRate * 100; // Porcentaje
    } catch (e) {
      return 10.0; // 10% de pérdida por defecto
    }
  }

  /// Calcula la calidad basada en métricas reales
  NetworkQuality _calculateQualityFromMetrics(
      NetworkQuality baseQuality, NetworkMetrics metrics) {
    int qualityScore = baseQuality.index;

    // Ajustar según latencia
    if (metrics.latency.inMilliseconds < 50) {
      qualityScore = math.max(0, qualityScore - 1); // Mejorar
    } else if (metrics.latency.inMilliseconds > 500) {
      qualityScore = math.min(
          NetworkQuality.values.length - 2, qualityScore + 2); // Empeorar
    } else if (metrics.latency.inMilliseconds > 200) {
      qualityScore = math.min(NetworkQuality.values.length - 2,
          qualityScore + 1); // Empeorar un poco
    }

    // Ajustar según ancho de banda
    if (metrics.bandwidth > 10.0) {
      qualityScore = math.max(0, qualityScore - 1); // Mejorar
    } else if (metrics.bandwidth < 1.0) {
      qualityScore = math.min(
          NetworkQuality.values.length - 2, qualityScore + 1); // Empeorar
    }

    // Ajustar según pérdida de paquetes
    if (metrics.packetLoss > 5.0) {
      qualityScore = math.min(
          NetworkQuality.values.length - 2, qualityScore + 1); // Empeorar
    }

    // Asegurar que no sea offline a menos que no haya conectividad
    if (qualityScore >= NetworkQuality.offline.index &&
        _currentConnectivity != ConnectivityResult.none) {
      qualityScore = NetworkQuality.poor.index;
    }

    return NetworkQuality.values[qualityScore];
  }

  // =============================================
  // MONITOREO CONTINUO
  // =============================================

  /// Inicia el monitoreo continuo de rendimiento
  void _startPerformanceMonitoring() {
    _performanceMonitorTimer?.cancel();
    _performanceMonitorTimer = Timer.periodic(_performanceCheckInterval, (_) {
      if (!_isDisposed) {
        _evaluateNetworkQuality();
      }
    });
  }

  /// Agrega medición de latencia al historial
  void _addLatencyMeasurement(Duration latency) {
    _latencyHistory.add(LatencyMeasurement(
      latency: latency,
      timestamp: DateTime.now(),
    ));

    // Mantener solo las últimas mediciones
    while (_latencyHistory.length > _maxLatencyHistory) {
      _latencyHistory.removeAt(0);
    }
  }

  /// Agrega medición de ancho de banda al historial
  void _addBandwidthMeasurement(double bandwidth) {
    _bandwidthHistory.add(BandwidthMeasurement(
      bandwidth: bandwidth,
      timestamp: DateTime.now(),
    ));

    // Mantener solo las últimas mediciones
    while (_bandwidthHistory.length > _maxBandwidthHistory) {
      _bandwidthHistory.removeAt(0);
    }
  }

  // =============================================
  // API PÚBLICA
  // =============================================

  /// Obtiene configuración para una calidad específica
  NetworkConfig? getConfigurationForQuality(NetworkQuality quality) {
    return _configurations[quality];
  }

  /// Actualiza configuración para una calidad específica
  void updateConfiguration(NetworkQuality quality, NetworkConfig config) {
    _configurations[quality] = config;

    // Si es la calidad actual, emitir cambio
    if (quality == _currentQuality) {
      final change = NetworkConfigurationChange(
        previousQuality: _currentQuality,
        newQuality: _currentQuality,
        previousConfig: currentConfiguration,
        newConfig: config,
        timestamp: DateTime.now(),
        metrics: _currentMetrics,
      );

      _configChangeController.add(change);
    }
  }

  /// Fuerza una re-evaluación de la calidad de red
  Future<void> forceNetworkEvaluation() async {
    await _evaluateNetworkQuality();
  }

  /// Obtiene historial de latencia
  List<LatencyMeasurement> getLatencyHistory() {
    return List.from(_latencyHistory);
  }

  /// Obtiene historial de ancho de banda
  List<BandwidthMeasurement> getBandwidthHistory() {
    return List.from(_bandwidthHistory);
  }

  /// Obtiene estadísticas de red
  Map<String, dynamic> getNetworkStatistics() {
    final avgLatency = _latencyHistory.isNotEmpty
        ? _latencyHistory
                .map((m) => m.latency.inMilliseconds)
                .reduce((a, b) => a + b) /
            _latencyHistory.length
        : 0.0;

    final avgBandwidth = _bandwidthHistory.isNotEmpty
        ? _bandwidthHistory.map((m) => m.bandwidth).reduce((a, b) => a + b) /
            _bandwidthHistory.length
        : 0.0;

    return {
      'current_quality': _currentQuality.name,
      'current_connectivity': _currentConnectivity.name,
      'current_metrics': _currentMetrics.toMap(),
      'average_latency_ms': avgLatency,
      'average_bandwidth_mbps': avgBandwidth,
      'latency_measurements': _latencyHistory.length,
      'bandwidth_measurements': _bandwidthHistory.length,
      'is_initialized': _isInitialized,
    };
  }

  /// Obtiene configuración optimizada para operación específica
  NetworkConfig getOptimizedConfigForOperation(String operationType) {
    final baseConfig = currentConfiguration;

    // Ajustar configuración según tipo de operación
    switch (operationType.toLowerCase()) {
      case 'sync':
        return baseConfig.copyWith(
          batchSize: (baseConfig.batchSize * 1.5).round(),
          maxConcurrentOperations:
              math.max(1, baseConfig.maxConcurrentOperations - 1),
        );

      case 'upload':
        return baseConfig.copyWith(
          timeoutDuration:
              Duration(seconds: baseConfig.timeoutDuration.inSeconds * 2),
          retryAttempts: baseConfig.retryAttempts + 1,
        );

      case 'download':
        return baseConfig.copyWith(
          batchSize: math.max(1, baseConfig.batchSize ~/ 2),
          compressionEnabled: true,
        );

      case 'realtime':
        return baseConfig.copyWith(
          heartbeatInterval: Duration(
              seconds:
                  math.max(15, baseConfig.heartbeatInterval.inSeconds ~/ 2)),
          enableRealtime: _currentQuality.index <= NetworkQuality.fair.index,
        );

      default:
        return baseConfig;
    }
  }

  /// Libera recursos
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    // Cancelar subscripciones y timers
    await _connectivitySubscription?.cancel();
    _performanceMonitorTimer?.cancel();

    // Cerrar streams
    await _configChangeController.close();

    // Limpiar historiales
    _latencyHistory.clear();
    _bandwidthHistory.clear();

    LoggerFactory.info('🔒 NetworkConfigurationService disposed');
  }
}

// =============================================
// CLASES DE SOPORTE
// =============================================

/// Calidad de la conexión de red
enum NetworkQuality {
  excellent,
  good,
  fair,
  poor,
  offline,
  unknown,
}

/// Configuración de red adaptativa
class NetworkConfig {
  const NetworkConfig({
    required this.syncInterval,
    required this.batchSize,
    required this.maxConcurrentOperations,
    required this.timeoutDuration,
    required this.retryAttempts,
    required this.retryDelay,
    required this.heartbeatInterval,
    required this.enableRealtime,
    required this.enableBatching,
    required this.compressionEnabled,
    required this.prefetchEnabled,
    required this.cacheSize,
    required this.description,
  });

  /// Configuración por defecto
  factory NetworkConfig.defaultConfig() {
    return const NetworkConfig(
      syncInterval: Duration(seconds: 30),
      batchSize: 20,
      maxConcurrentOperations: 3,
      timeoutDuration: Duration(seconds: 60),
      retryAttempts: 3,
      retryDelay: Duration(seconds: 3),
      heartbeatInterval: Duration(seconds: 45),
      enableRealtime: true,
      enableBatching: true,
      compressionEnabled: false,
      prefetchEnabled: false,
      cacheSize: 200,
      description: 'Default configuration',
    );
  }

  final Duration syncInterval;
  final int batchSize;
  final int maxConcurrentOperations;
  final Duration timeoutDuration;
  final int retryAttempts;
  final Duration retryDelay;
  final Duration heartbeatInterval;
  final bool enableRealtime;
  final bool enableBatching;
  final bool compressionEnabled;
  final bool prefetchEnabled;
  final int cacheSize;
  final String description;

  /// Crea una copia con valores modificados
  NetworkConfig copyWith({
    Duration? syncInterval,
    int? batchSize,
    int? maxConcurrentOperations,
    Duration? timeoutDuration,
    int? retryAttempts,
    Duration? retryDelay,
    Duration? heartbeatInterval,
    bool? enableRealtime,
    bool? enableBatching,
    bool? compressionEnabled,
    bool? prefetchEnabled,
    int? cacheSize,
    String? description,
  }) {
    return NetworkConfig(
      syncInterval: syncInterval ?? this.syncInterval,
      batchSize: batchSize ?? this.batchSize,
      maxConcurrentOperations:
          maxConcurrentOperations ?? this.maxConcurrentOperations,
      timeoutDuration: timeoutDuration ?? this.timeoutDuration,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      retryDelay: retryDelay ?? this.retryDelay,
      heartbeatInterval: heartbeatInterval ?? this.heartbeatInterval,
      enableRealtime: enableRealtime ?? this.enableRealtime,
      enableBatching: enableBatching ?? this.enableBatching,
      compressionEnabled: compressionEnabled ?? this.compressionEnabled,
      prefetchEnabled: prefetchEnabled ?? this.prefetchEnabled,
      cacheSize: cacheSize ?? this.cacheSize,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sync_interval_seconds': syncInterval.inSeconds,
      'batch_size': batchSize,
      'max_concurrent_operations': maxConcurrentOperations,
      'timeout_duration_seconds': timeoutDuration.inSeconds,
      'retry_attempts': retryAttempts,
      'retry_delay_seconds': retryDelay.inSeconds,
      'heartbeat_interval_seconds': heartbeatInterval.inSeconds,
      'enable_realtime': enableRealtime,
      'enable_batching': enableBatching,
      'compression_enabled': compressionEnabled,
      'prefetch_enabled': prefetchEnabled,
      'cache_size': cacheSize,
      'description': description,
    };
  }
}

/// Métricas de rendimiento de red
class NetworkMetrics {
  const NetworkMetrics({
    required this.latency,
    required this.bandwidth,
    required this.packetLoss,
    required this.timestamp,
    required this.connectivityType,
  });

  /// Métricas vacías
  factory NetworkMetrics.empty() {
    return NetworkMetrics(
      latency: const Duration(milliseconds: 1000),
      bandwidth: 1.0,
      packetLoss: 10.0,
      timestamp: DateTime.now(),
      connectivityType: ConnectivityResult.none,
    );
  }

  final Duration latency;
  final double bandwidth; // Mbps
  final double packetLoss; // Porcentaje
  final DateTime timestamp;
  final ConnectivityResult connectivityType;

  Map<String, dynamic> toMap() {
    return {
      'latency_ms': latency.inMilliseconds,
      'bandwidth_mbps': bandwidth,
      'packet_loss_percent': packetLoss,
      'timestamp': timestamp.toIso8601String(),
      'connectivity_type': connectivityType.name,
    };
  }
}

/// Cambio de configuración de red
class NetworkConfigurationChange {
  const NetworkConfigurationChange({
    required this.previousQuality,
    required this.newQuality,
    required this.previousConfig,
    required this.newConfig,
    required this.timestamp,
    required this.metrics,
  });

  final NetworkQuality previousQuality;
  final NetworkQuality newQuality;
  final NetworkConfig previousConfig;
  final NetworkConfig newConfig;
  final DateTime timestamp;
  final NetworkMetrics metrics;

  bool get isImprovement => newQuality.index < previousQuality.index;
  bool get isDegradation => newQuality.index > previousQuality.index;
  bool get isSignificantChange =>
      (newQuality.index - previousQuality.index).abs() > 1;

  @override
  String toString() {
    return 'NetworkConfigurationChange(${previousQuality.name} → ${newQuality.name})';
  }
}

/// Medición de latencia
class LatencyMeasurement {
  const LatencyMeasurement({
    required this.latency,
    required this.timestamp,
  });

  final Duration latency;
  final DateTime timestamp;
}

/// Medición de ancho de banda
class BandwidthMeasurement {
  const BandwidthMeasurement({
    required this.bandwidth,
    required this.timestamp,
  });

  final double bandwidth;
  final DateTime timestamp;
}
