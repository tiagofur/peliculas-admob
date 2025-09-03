import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../infrastructure/services/connectivity_detector.dart';
import '../logging/logger_factory.dart';

/// Estrategia de caché que se adapta a las condiciones de red
class NetworkAwareStrategy {
  NetworkAwareStrategy._();
  static NetworkAwareStrategy? _instance;
  static NetworkAwareStrategy get instance =>
      _instance ??= NetworkAwareStrategy._();

  final _logger = LoggerFactory.logger;

  // Estado de red actual
  NetworkCondition _currentCondition = NetworkCondition.unknown;
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;
  DateTime? _lastSpeedTest;
  double? _estimatedSpeedMbps;

  bool _isInitialized = false;

  /// Inicializa la estrategia de red
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.info('🌐 Inicializando estrategia de red adaptativa...');

      // Inicializar detector de conectividad si no está iniciado
      await ConnectivityDetector.instance.initialize();

      // Evaluar condición inicial de red
      await _evaluateNetworkCondition();

      // Suscribirse a cambios de conectividad
      _connectivitySubscription = ConnectivityDetector
          .instance.onConnectivityChanged
          .listen(_onConnectivityChanged);

      _isInitialized = true;
      _logger.info('✅ Estrategia de red inicializada: $_currentCondition');
    } catch (e) {
      _logger.error('❌ Error inicializando estrategia de red: $e');
      _currentCondition = NetworkCondition.poor;
      _isInitialized = true;
    }
  }

  /// Obtiene la configuración de descarga adaptada a la red
  DownloadStrategy getDownloadStrategy() {
    switch (_currentCondition) {
      case NetworkCondition.excellent:
        return const DownloadStrategy(
          concurrentDownloads: 5,
          downloadTimeout: Duration(seconds: 15),
          retryAttempts: 3,
          retryDelay: Duration(seconds: 1),
          enablePreloading: true,
          preloadDistance: 10, // precargar hasta 10 elementos ahead
          qualityPreference: ImageQuality.high,
          enableProgressiveLoading: false, // red rápida, cargar completo
        );

      case NetworkCondition.good:
        return const DownloadStrategy(
          concurrentDownloads: 3,
          downloadTimeout: Duration(seconds: 25),
          retryAttempts: 3,
          retryDelay: Duration(seconds: 2),
          enablePreloading: true,
          preloadDistance: 5,
          qualityPreference: ImageQuality.medium,
          enableProgressiveLoading: true,
        );

      case NetworkCondition.fair:
        return const DownloadStrategy(
          concurrentDownloads: 2,
          downloadTimeout: Duration(seconds: 40),
          retryAttempts: 2,
          retryDelay: Duration(seconds: 3),
          enablePreloading: false,
          preloadDistance: 0,
          qualityPreference: ImageQuality.low,
          enableProgressiveLoading: true,
        );

      case NetworkCondition.poor:
        return const DownloadStrategy(
          concurrentDownloads: 1,
          downloadTimeout: Duration(seconds: 60),
          retryAttempts: 1,
          retryDelay: Duration(seconds: 5),
          enablePreloading: false,
          preloadDistance: 0,
          qualityPreference: ImageQuality.thumbnail,
          enableProgressiveLoading: true,
        );

      case NetworkCondition.offline:
        return const DownloadStrategy(
          concurrentDownloads: 0,
          downloadTimeout: Duration(seconds: 1),
          retryAttempts: 0,
          retryDelay: Duration(seconds: 10),
          enablePreloading: false,
          preloadDistance: 0,
          qualityPreference: ImageQuality.cached,
          enableProgressiveLoading: false,
        );

      case NetworkCondition.unknown:
        return const DownloadStrategy(
          concurrentDownloads: 2,
          downloadTimeout: Duration(seconds: 30),
          retryAttempts: 2,
          retryDelay: Duration(seconds: 3),
          enablePreloading: false,
          preloadDistance: 0,
          qualityPreference: ImageQuality.medium,
          enableProgressiveLoading: true,
        );
    }
  }

  /// Evalúa la condición actual de la red
  Future<void> _evaluateNetworkCondition() async {
    try {
      final connectivityStatus = ConnectivityDetector.instance.currentStatus;

      if (connectivityStatus == ConnectivityStatus.offline) {
        _currentCondition = NetworkCondition.offline;
        return;
      }

      // Obtener tipo de conectividad
      final connectivityResults = await Connectivity().checkConnectivity();

      if (connectivityResults.contains(ConnectivityResult.none)) {
        _currentCondition = NetworkCondition.offline;
        return;
      }

      // Evaluar según tipo de conexión
      if (connectivityResults.contains(ConnectivityResult.wifi)) {
        await _evaluateWifiCondition();
      } else if (connectivityResults.contains(ConnectivityResult.mobile)) {
        await _evaluateMobileCondition();
      } else if (connectivityResults.contains(ConnectivityResult.ethernet)) {
        _currentCondition = NetworkCondition.excellent;
      } else {
        _currentCondition = NetworkCondition.unknown;
      }
    } catch (e) {
      _logger.warning('⚠️ Error evaluando condición de red: $e');
      _currentCondition = NetworkCondition.unknown;
    }
  }

  /// Evalúa la condición de WiFi
  Future<void> _evaluateWifiCondition() async {
    // Realizar test de velocidad simple si no se ha hecho recientemente
    if (_shouldPerformSpeedTest()) {
      await _performSimpleSpeedTest();
    }

    if (_estimatedSpeedMbps != null) {
      if (_estimatedSpeedMbps! >= 10.0) {
        _currentCondition = NetworkCondition.excellent;
      } else if (_estimatedSpeedMbps! >= 5.0) {
        _currentCondition = NetworkCondition.good;
      } else if (_estimatedSpeedMbps! >= 1.0) {
        _currentCondition = NetworkCondition.fair;
      } else {
        _currentCondition = NetworkCondition.poor;
      }
    } else {
      // Asumir buena calidad para WiFi sin test
      _currentCondition = NetworkCondition.good;
    }
  }

  /// Evalúa la condición de datos móviles
  Future<void> _evaluateMobileCondition() async {
    // Para datos móviles, ser más conservador
    if (_shouldPerformSpeedTest()) {
      await _performSimpleSpeedTest();
    }

    if (_estimatedSpeedMbps != null) {
      if (_estimatedSpeedMbps! >= 5.0) {
        _currentCondition = NetworkCondition.good;
      } else if (_estimatedSpeedMbps! >= 1.0) {
        _currentCondition = NetworkCondition.fair;
      } else {
        _currentCondition = NetworkCondition.poor;
      }
    } else {
      // Asumir calidad media para móvil sin test
      _currentCondition = NetworkCondition.fair;
    }
  }

  /// Determina si se debe realizar un test de velocidad
  bool _shouldPerformSpeedTest() {
    if (_lastSpeedTest == null) return true;

    final timeSinceLastTest = DateTime.now().difference(_lastSpeedTest!);
    return timeSinceLastTest > const Duration(minutes: 5);
  }

  /// Realiza un test simple de velocidad descargando una imagen pequeña
  Future<void> _performSimpleSpeedTest() async {
    try {
      _logger.debug('🏃 Realizando test de velocidad...');

      final stopwatch = Stopwatch()..start();

      // URL de una imagen pequeña conocida (puede ser configurada)
// 100KB
      const expectedBytes = 100000;

      final response = await ConnectivityDetector.instance.testConnection();
      stopwatch.stop();

      if (response) {
        final durationSeconds = stopwatch.elapsedMilliseconds / 1000.0;
        final speedMbps = (expectedBytes * 8) /
            (durationSeconds * 1000000); // Convert to Mbps

        _estimatedSpeedMbps = speedMbps;
        _lastSpeedTest = DateTime.now();

        _logger.debug(
            '📊 Velocidad estimada: ${speedMbps.toStringAsFixed(2)} Mbps');
      }
    } catch (e) {
      _logger.warning('⚠️ Error en test de velocidad: $e');
    }
  }

  /// Maneja cambios de conectividad
  void _onConnectivityChanged(ConnectivityStatus status) {
    _logger.info('📡 Cambio de conectividad detectado: $status');

    // Re-evaluar condición de red en el próximo tick
    Future.microtask(() async {
      await _evaluateNetworkCondition();
      _logger.info('🔄 Condición de red actualizada: $_currentCondition');
    });
  }

  /// Fuerza una re-evaluación de las condiciones de red
  Future<void> refreshNetworkCondition() async {
    _logger.info('🔄 Forzando re-evaluación de condiciones de red...');
    await _evaluateNetworkCondition();
  }

  /// Libera recursos
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _isInitialized = false;
    _logger.info('🧹 NetworkAwareStrategy disposed');
  }

  // Getters públicos
  NetworkCondition get currentCondition => _currentCondition;
  bool get isInitialized => _isInitialized;
  double? get estimatedSpeedMbps => _estimatedSpeedMbps;

  /// Obtiene información detallada del estado de red
  Map<String, dynamic> getNetworkStatus() {
    return {
      'condition': _currentCondition.toString(),
      'speedMbps': _estimatedSpeedMbps,
      'lastSpeedTest': _lastSpeedTest?.toIso8601String(),
      'isInitialized': _isInitialized,
    };
  }
}

/// Condiciones de red posibles
enum NetworkCondition {
  excellent, // >10 Mbps, WiFi/Ethernet estable
  good, // 5-10 Mbps, WiFi bueno o 4G/5G
  fair, // 1-5 Mbps, WiFi lento o 3G/4G
  poor, // <1 Mbps, conexión muy lenta
  offline, // Sin conexión
  unknown, // No se ha podido determinar
}

/// Estrategia de descarga adaptada a la red
class DownloadStrategy {
  const DownloadStrategy({
    required this.concurrentDownloads,
    required this.downloadTimeout,
    required this.retryAttempts,
    required this.retryDelay,
    required this.enablePreloading,
    required this.preloadDistance,
    required this.qualityPreference,
    required this.enableProgressiveLoading,
  });

  final int concurrentDownloads;
  final Duration downloadTimeout;
  final int retryAttempts;
  final Duration retryDelay;
  final bool enablePreloading;
  final int preloadDistance; // número de elementos a precargar
  final ImageQuality qualityPreference;
  final bool enableProgressiveLoading;

  @override
  String toString() {
    return 'DownloadStrategy(concurrent: $concurrentDownloads, '
        'timeout: ${downloadTimeout.inSeconds}s, quality: $qualityPreference, '
        'preload: $enablePreloading)';
  }
}

/// Calidades de imagen disponibles
enum ImageQuality {
  thumbnail, // Muy pequeña, para conexiones pobres
  low, // Baja calidad, rápida descarga
  medium, // Calidad media, balance
  high, // Alta calidad, mejor experiencia
  cached, // Solo usar caché, no descargar
}
