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
  static const Duration _timeoutDuration = Duration(seconds: 10);
  static const String _testUrl = 'https://www.google.com';

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
            DateTime.now().difference(_lastCheck ?? DateTime.now()) > _checkInterval)) {
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
    try {
      // En Web, usar fetch API a través de http package
      final response = await http.get(
        Uri.parse(_testUrl),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(_timeoutDuration);

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      LoggerFactory.info('🌐 Prueba de conexión Web falló: $e');
      return false;
    }
  }

  /// Prueba de conexión para plataformas nativas
  Future<bool> _testNativeConnection() async {
    try {
      // Usar Socket para una verificación más rápida
      final socket = await Socket.connect(
        'google.com',
        80,
        timeout: _timeoutDuration,
      );

      socket.destroy();
      return true;
    } catch (e) {
      LoggerFactory.info('📱 Prueba de conexión nativa falló: $e');

      // Fallback a HTTP request
      try {
        final response = await http.get(
          Uri.parse(_testUrl),
          headers: {'Cache-Control': 'no-cache'},
        ).timeout(_timeoutDuration);

        return response.statusCode >= 200 && response.statusCode < 300;
      } catch (httpError) {
        LoggerFactory.info('📱 Fallback HTTP también falló: $httpError');
        return false;
      }
    }
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
