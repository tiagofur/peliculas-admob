import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/logging/logger_factory.dart';

/// Estados de conectividad
enum ConnectivityStatus {
  online,
  offline,
  unknown,
}

/// Detector de conectividad multiplataforma con verificaciones inteligentes
class ConnectivityDetector {
  ConnectivityDetector._();

  static final ConnectivityDetector _instance = ConnectivityDetector._();
  static ConnectivityDetector get instance => _instance;

  // Estado interno
  ConnectivityStatus _currentStatus = ConnectivityStatus.unknown;
  DateTime? _lastCheck;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Stream controller para notificar cambios
  final StreamController<ConnectivityStatus> _statusController =
      StreamController<ConnectivityStatus>.broadcast();

  // Configuración
  static const Duration _checkInterval = Duration(seconds: 30);
  static const Duration _timeoutDuration = Duration(seconds: 5);

  // ✅ FIXED: Usar endpoints alternativos que no causen CORS issues
  static const List<String> _testUrls = [
    'https://www.google.com/generate_204', // Google connectivity check endpoint
    'https://connectivitycheck.gstatic.com/generate_204', // Google alternative
    'https://www.cloudflare.com/cdn-cgi/trace', // Cloudflare endpoint
    'https://httpstat.us/200', // HTTP status testing service
  ];
  static const List<String> _testHosts = [
    'google.com',
    'cloudflare.com',
    'github.com',
    'stackoverflow.com',
  ];

  /// Stream de cambios de conectividad
  Stream<ConnectivityStatus> get onConnectivityChanged =>
      _statusController.stream;

  /// Estado actual de conectividad
  ConnectivityStatus get currentStatus => _currentStatus;

  /// Verifica si está online
  bool get isOnline => _currentStatus == ConnectivityStatus.online;

  /// Inicializa el detector de conectividad
  Future<void> initialize() async {
    LoggerFactory.info('🌐 Inicializando ConnectivityDetector...');

    try {
      // Verificación inicial
      await _performConnectivityCheck();

      // Configurar listeners según la plataforma
      if (kIsWeb) {
        _setupWebConnectivityListener();
      } else {
        _setupNativeConnectivityListener();
      }

      LoggerFactory.info('✅ ConnectivityDetector inicializado correctamente');
    } catch (e) {
      LoggerFactory.error('❌ Error inicializando ConnectivityDetector: $e');
      _updateStatus(ConnectivityStatus.unknown);
    }
  }

  /// Configura el listener para Web
  void _setupWebConnectivityListener() {
    LoggerFactory.info('🌐 Configurando detector de conectividad para Web');

    // En Web, usar connectivity_plus con verificaciones adicionales
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        _handleConnectivityChange(results);
      },
      onError: (error) {
        LoggerFactory.error('❌ Error en listener de conectividad Web: $error');
        _performConnectivityCheck();
      },
    );

    // Verificación periódica adicional para Web
    Timer.periodic(_checkInterval, (_) {
      _performPeriodicCheck();
    });
  }

  /// Configura el listener para plataformas nativas
  void _setupNativeConnectivityListener() {
    LoggerFactory.info('📱 Configurando detector de conectividad nativo');

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        _handleConnectivityChange(results);
      },
      onError: (error) {
        LoggerFactory.error(
            '❌ Error en listener de conectividad nativo: $error');
        _performConnectivityCheck();
      },
    );
  }

  /// Maneja cambios de conectividad
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    LoggerFactory.info('📡 Cambio de conectividad detectado: $results');

    if (results.contains(ConnectivityResult.none)) {
      _updateStatus(ConnectivityStatus.offline);
    } else {
      // Verificar conectividad real con una prueba de red
      _performConnectivityCheck();
    }
  }

  /// Realiza una verificación de conectividad
  Future<void> _performConnectivityCheck() async {
    _lastCheck = DateTime.now();

    try {
      final isConnected = await _testInternetConnection();
      _updateStatus(
          isConnected ? ConnectivityStatus.online : ConnectivityStatus.offline);
    } catch (e) {
      LoggerFactory.error('❌ Error verificando conectividad: $e');
      _updateStatus(ConnectivityStatus.unknown);
    }
  }

  /// Verificación periódica (solo para Web)
  Future<void> _performPeriodicCheck() async {
    if (_currentStatus == ConnectivityStatus.unknown ||
        (_lastCheck != null &&
            DateTime.now().difference(_lastCheck ?? DateTime.now()) >
                _checkInterval)) {
      await _performConnectivityCheck();
    }
  }

  /// Prueba la conexión a internet real
  Future<bool> _testInternetConnection() async {
    try {
      if (kIsWeb) {
        return await _testWebConnection();
      } else {
        return await _testNativeConnection();
      }
    } catch (e) {
      LoggerFactory.error('❌ Error en prueba de conexión: $e');
      return false;
    }
  }

  /// Prueba de conexión para Web
  Future<bool> _testWebConnection() async {
    // 🔧 FIXED: En Web, evitar peticiones externas que causan CORS
    // En su lugar, asumir conectividad basada en el estado de Connectivity+
    try {
      LoggerFactory.info('🌐 [WEB] Verificando conectividad básica...');

      // Verificar estado básico de conectividad
      final connectivityResult = await Connectivity().checkConnectivity();
      LoggerFactory.info('🌐 [WEB] Estado conectividad: $connectivityResult');

      // Si no hay conectividad de red, retornar false
      if (connectivityResult.contains(ConnectivityResult.none)) {
        LoggerFactory.info('❌ [WEB] Sin conectividad de red');
        return false;
      }

      // En Web, si hay conectividad reportada, asumir que funciona
      // Las peticiones a APIs específicas (Supabase, etc.) manejarán sus propios errores
      LoggerFactory.info(
          '✅ [WEB] Conectividad disponible (sin prueba externa)');
      return true;
    } catch (e) {
      LoggerFactory.warning(
          '⚠️ [WEB] Error verificando conectividad básica: $e');

      // Fallback final: asumir conectividad en Web
      // Esto permite que la app funcione y que las APIs manejen sus propios errores
      LoggerFactory.info(
          '🌐 [WEB] Fallback: asumiendo conectividad disponible');
      return true;
    }
  }

  /// Prueba de conexión para plataformas nativas
  Future<bool> _testNativeConnection() async {
    // ✅ FIXED: Usar múltiples hosts para Socket connections
    for (final host in _testHosts) {
      try {
        LoggerFactory.info('📱 Probando conexión Socket a: $host');

        final socket = await Socket.connect(
          host,
          80,
          timeout: _timeoutDuration,
        );

        socket.destroy();
        LoggerFactory.info('✅ Conexión Socket exitosa a: $host');
        return true;
      } catch (e) {
        LoggerFactory.info('⚠️ Socket falló para $host: $e');
        continue; // Probar siguiente host
      }
    }

    // Fallback a HTTP requests si Socket connections fallan
    for (final url in _testUrls) {
      try {
        LoggerFactory.info('📱 Fallback HTTP para: $url');

        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Cache-Control': 'no-cache',
            'User-Agent': 'PeliculasApp/1.0',
          },
        ).timeout(_timeoutDuration);

        if (response.statusCode == 200 || response.statusCode == 204) {
          LoggerFactory.info('✅ Conexión HTTP exitosa via: $url');
          return true;
        }
      } catch (httpError) {
        LoggerFactory.info('⚠️ HTTP falló para $url: $httpError');
        continue; // Probar siguiente URL
      }
    }

    LoggerFactory.warning(
        '❌ Todas las pruebas de conectividad nativa fallaron');
    return false;
  }

  /// Actualiza el estado de conectividad
  void _updateStatus(ConnectivityStatus newStatus) {
    if (_currentStatus != newStatus) {
      final oldStatus = _currentStatus;
      _currentStatus = newStatus;

      LoggerFactory.info(
          '📡 Estado de conectividad cambió: $oldStatus → $newStatus');

      _statusController.add(newStatus);
    }
  }

  /// Fuerza una verificación manual de conectividad
  Future<ConnectivityStatus> checkConnectivity() async {
    LoggerFactory.info('🔄 Verificación manual de conectividad solicitada');

    await _performConnectivityCheck();
    return _currentStatus;
  }

  /// Prueba la conexión a internet de forma pública
  Future<bool> testConnection() async {
    LoggerFactory.info('🔄 Prueba de conexión solicitada');
    return await _testInternetConnection();
  }

  /// Obtiene información detallada del estado
  Map<String, dynamic> getDetailedStatus() {
    return {
      'current_status': _currentStatus.toString(),
      'is_online': isOnline,
      'last_check': _lastCheck?.toIso8601String(),
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
    };
  }

  /// Limpia recursos
  void dispose() {
    LoggerFactory.info('🧹 Limpiando ConnectivityDetector...');

    _connectivitySubscription?.cancel();
    _statusController.close();

    LoggerFactory.info('✅ ConnectivityDetector limpiado');
  }
}

/// Extensión para facilitar el uso
extension ConnectivityStatusExtension on ConnectivityStatus {
  /// Verifica si el estado indica conectividad
  bool get isConnected => this == ConnectivityStatus.online;

  /// Verifica si el estado es desconocido
  bool get isUnknown => this == ConnectivityStatus.unknown;

  /// Verifica si el estado indica desconexión
  bool get isDisconnected => this == ConnectivityStatus.offline;
}
