import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/logging/logger_factory.dart';

/// Estados de conexión
enum ConnectionStatus {
  online,
  offline,
  limited,
  manual,
}

/// Eventos de sincronización en background
class BackgroundSyncEvent {
  const BackgroundSyncEvent({
    required this.type,
    required this.data,
    required this.timestamp,
  });

  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
}

/// Manager para el estado de conectividad y reconexión automática
class ConnectivityManager {
  static const Duration _connectionCheckInterval = Duration(seconds: 30);
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const int _maxReconnectAttempts = 5;

  final Connectivity _connectivity = Connectivity();
  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();
  final StreamController<BackgroundSyncEvent> _backgroundSyncController =
      StreamController<BackgroundSyncEvent>.broadcast();

  ConnectionStatus _currentStatus = ConnectionStatus.offline;
  bool _isManualOfflineMode = false;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;
  Timer? _connectionCheckTimer;
  Timer? _reconnectTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Estado actual de conexión
  ConnectionStatus get currentStatus => _currentStatus;

  /// Stream de cambios de estado de conexión
  Stream<ConnectionStatus> get connectionStatus => _statusController.stream;

  /// Stream de eventos de sincronización en background
  Stream<BackgroundSyncEvent> get backgroundSyncEvents =>
      _backgroundSyncController.stream;

  /// Indica si está en modo offline manual
  bool get isManualOfflineMode => _isManualOfflineMode;

  /// Inicializa el manager de conectividad
  Future<void> initialize() async {
    if (_isDisposed) return;

    LoggerFactory.info('🌐 Initializing ConnectivityManager');

    // Verificar estado inicial
    await _checkInitialConnection();

    // Configurar listeners
    _setupConnectivityListener();
    _startConnectionMonitoring();

    LoggerFactory.info(
        '✅ ConnectivityManager initialized with status: ${_currentStatus.name}');
  }

  /// Verifica el estado inicial de conexión
  Future<void> _checkInitialConnection() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      final connectivityResult = connectivityResults.isNotEmpty
          ? connectivityResults.first
          : ConnectivityResult.none;
      final hasInternet = await _hasInternetConnection();

      _updateConnectionStatus(connectivityResult, hasInternet);
    } catch (e) {
      LoggerFactory.error('❌ Error checking initial connection: $e');
      _setStatus(ConnectionStatus.offline);
    }
  }

  /// Configura el listener de cambios de conectividad
  void _setupConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) async {
        if (_isDisposed) return;

        final result =
            results.isNotEmpty ? results.first : ConnectivityResult.none;
        LoggerFactory.info('📡 Connectivity changed: ${result.name}');

        final hasInternet = await _hasInternetConnection();
        _updateConnectionStatus(result, hasInternet);
      },
      onError: (error) {
        LoggerFactory.error('❌ Connectivity listener error: $error');
      },
    );
  }

  /// Inicia el monitoreo periódico de conexión
  void _startConnectionMonitoring() {
    _connectionCheckTimer = Timer.periodic(_connectionCheckInterval, (_) async {
      if (_isDisposed || _isManualOfflineMode) return;

      await _performConnectionCheck();
    });
  }

  /// Realiza verificación de conexión
  Future<void> _performConnectionCheck() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      final connectivityResult = connectivityResults.isNotEmpty
          ? connectivityResults.first
          : ConnectivityResult.none;
      final hasInternet = await _hasInternetConnection();

      _updateConnectionStatus(connectivityResult, hasInternet);
    } catch (e) {
      LoggerFactory.error('❌ Connection check failed: $e');
    }
  }

  /// Actualiza el estado de conexión basado en conectividad e internet
  void _updateConnectionStatus(
      ConnectivityResult connectivityResult, bool hasInternet) {
    if (_isManualOfflineMode) {
      _setStatus(ConnectionStatus.manual);
      return;
    }

    ConnectionStatus newStatus;

    if (connectivityResult == ConnectivityResult.none) {
      newStatus = ConnectionStatus.offline;
    } else if (!hasInternet) {
      newStatus = ConnectionStatus.limited;
    } else {
      newStatus = ConnectionStatus.online;
      _resetReconnectAttempts();
    }

    _setStatus(newStatus);
  }

  /// Verifica si hay conexión real a internet
  Future<bool> _hasInternetConnection() async {
    try {
      // Verificar conexión con Supabase
      await Supabase.instance.client
          .from('_supabase_migrations')
          .select('version')
          .limit(1)
          .timeout(const Duration(seconds: 10));

      return true;
    } catch (e) {
      LoggerFactory.debug('🔍 Internet check failed: $e');
      return false;
    }
  }

  /// Establece el nuevo estado de conexión
  void _setStatus(ConnectionStatus newStatus) {
    if (_currentStatus == newStatus) return;

    final previousStatus = _currentStatus;
    _currentStatus = newStatus;

    LoggerFactory.info(
        '🔄 Connection status changed: ${previousStatus.name} → ${newStatus.name}');

    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }

    _handleStatusChange(previousStatus, newStatus);
  }

  /// Maneja cambios de estado de conexión
  void _handleStatusChange(
      ConnectionStatus previous, ConnectionStatus current) {
    switch (current) {
      case ConnectionStatus.online:
        _onConnectionRestored(previous);
        break;
      case ConnectionStatus.offline:
      case ConnectionStatus.limited:
        _onConnectionLost(previous);
        break;
      case ConnectionStatus.manual:
        _onManualModeEnabled();
        break;
    }
  }

  /// Maneja restauración de conexión
  void _onConnectionRestored(ConnectionStatus previousStatus) {
    _cancelReconnectTimer();

    if (previousStatus != ConnectionStatus.online) {
      _emitBackgroundSyncEvent('connection_restored', {
        'previous_status': previousStatus.name,
        'reconnect_attempts': _reconnectAttempts,
      });
    }
  }

  /// Maneja pérdida de conexión
  void _onConnectionLost(ConnectionStatus previousStatus) {
    if (previousStatus == ConnectionStatus.online) {
      _emitBackgroundSyncEvent('connection_lost', {
        'new_status': _currentStatus.name,
      });

      _scheduleReconnectAttempt();
    }
  }

  /// Maneja activación de modo manual
  void _onManualModeEnabled() {
    _cancelReconnectTimer();
    _emitBackgroundSyncEvent('manual_mode_enabled', {});
  }

  /// Programa intento de reconexión
  void _scheduleReconnectAttempt() {
    if (_reconnectAttempts >= _maxReconnectAttempts || _isManualOfflineMode) {
      return;
    }

    _reconnectAttempts++;
    final delay =
        Duration(seconds: _reconnectDelay.inSeconds * _reconnectAttempts);

    LoggerFactory.info(
        '🔄 Scheduling reconnect attempt $_reconnectAttempts in ${delay.inSeconds}s');

    _reconnectTimer = Timer(delay, () async {
      if (_isDisposed) return;

      LoggerFactory.info(
          '🔄 Attempting reconnection $_reconnectAttempts/$_maxReconnectAttempts');
      await _performConnectionCheck();
    });
  }

  /// Cancela el timer de reconexión
  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Resetea los intentos de reconexión
  void _resetReconnectAttempts() {
    _reconnectAttempts = 0;
    _cancelReconnectTimer();
  }

  /// Emite evento de sincronización en background
  void _emitBackgroundSyncEvent(String type, Map<String, dynamic> data) {
    if (!_backgroundSyncController.isClosed) {
      _backgroundSyncController.add(BackgroundSyncEvent(
        type: type,
        data: data,
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Habilita modo offline manual
  Future<void> enableOfflineMode() async {
    _isManualOfflineMode = true;
    _setStatus(ConnectionStatus.manual);
    LoggerFactory.info('📱 Manual offline mode enabled');
  }

  /// Deshabilita modo offline manual
  Future<void> disableOfflineMode() async {
    _isManualOfflineMode = false;
    await _performConnectionCheck();
    LoggerFactory.info('🌐 Manual offline mode disabled');
  }

  /// Fuerza verificación de conexión
  Future<void> forceConnectionCheck() async {
    LoggerFactory.info('🔍 Forcing connection check');
    await _performConnectionCheck();
  }

  /// Obtiene estadísticas del manager
  Map<String, dynamic> getStatistics() {
    return {
      'current_status': _currentStatus.name,
      'is_manual_offline': _isManualOfflineMode,
      'reconnect_attempts': _reconnectAttempts,
      'max_reconnect_attempts': _maxReconnectAttempts,
      'is_disposed': _isDisposed,
    };
  }

  /// Libera recursos
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    LoggerFactory.info('🔒 Disposing ConnectivityManager');

    _cancelReconnectTimer();
    _connectionCheckTimer?.cancel();
    await _connectivitySubscription?.cancel();

    await _statusController.close();
    await _backgroundSyncController.close();

    LoggerFactory.info('✅ ConnectivityManager disposed');
  }
}
