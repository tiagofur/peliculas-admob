import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../logging/logger_factory.dart';
import 'sync_coordinator.dart';

/// Estados de conectividad
enum NetworkState {
  online('online'),
  offline('offline'),
  limited('limited'), // Conexión lenta o inestable
  unknown('unknown');

  const NetworkState(this.value);
  final String value;

  static NetworkState fromString(String value) {
    return NetworkState.values.firstWhere(
      (state) => state.value == value,
      orElse: () => NetworkState.unknown,
    );
  }
}

/// Tipos de conexión
enum ConnectionType {
  wifi('wifi'),
  mobile('mobile'),
  ethernet('ethernet'),
  none('none'),
  unknown('unknown');

  const ConnectionType(this.value);
  final String value;

  static ConnectionType fromConnectivityResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return ConnectionType.wifi;
      case ConnectivityResult.mobile:
        return ConnectionType.mobile;
      case ConnectivityResult.ethernet:
        return ConnectionType.ethernet;
      case ConnectivityResult.none:
        return ConnectionType.none;
      default:
        return ConnectionType.unknown;
    }
  }
}

/// Información detallada de la conexión de red
class NetworkInfo {
  const NetworkInfo({
    required this.state,
    required this.connectionType,
    required this.isConnected,
    this.lastOnlineAt,
    this.offlineDuration,
    this.latency,
    this.isMetered = false,
    this.signalStrength,
  });

  final NetworkState state;
  final ConnectionType connectionType;
  final bool isConnected;
  final DateTime? lastOnlineAt;
  final Duration? offlineDuration;
  final Duration? latency; // Ping time
  final bool isMetered; // Conexión con límite de datos
  final double? signalStrength; // 0.0 - 1.0

  bool get isOnline => state == NetworkState.online;
  bool get isOffline => state == NetworkState.offline;
  bool get isLimited => state == NetworkState.limited;

  bool get canSync => isOnline || isLimited;
  bool get shouldSyncLarge =>
      isOnline && connectionType == ConnectionType.wifi && !isMetered;

  @override
  String toString() {
    return 'NetworkInfo(state: ${state.value}, type: ${connectionType.value}, '
        'connected: $isConnected, latency: ${latency?.inMilliseconds}ms)';
  }
}

/// Evento de cambio de estado de red
class NetworkStateEvent {
  const NetworkStateEvent({
    required this.previousState,
    required this.currentState,
    required this.timestamp,
    required this.networkInfo,
  });

  final NetworkState previousState;
  final NetworkState currentState;
  final DateTime timestamp;
  final NetworkInfo networkInfo;

  bool get wentOnline =>
      previousState != NetworkState.online &&
      currentState == NetworkState.online;
  bool get wentOffline =>
      previousState != NetworkState.offline &&
      currentState == NetworkState.offline;
  bool get connectionImproved =>
      (previousState == NetworkState.limited &&
          currentState == NetworkState.online) ||
      (previousState == NetworkState.offline &&
          currentState != NetworkState.offline);
  bool get connectionDegraded => (previousState == NetworkState.online &&
      currentState != NetworkState.online);

  @override
  String toString() {
    return 'NetworkStateEvent(${previousState.value} → ${currentState.value})';
  }
}

/// Gestor de estado de conectividad y sincronización automática
class NetworkStateManager {
  NetworkStateManager({
    SyncCoordinator? syncCoordinator,
  }) : _syncCoordinator = syncCoordinator {
    _initialize();
  }

  final SyncCoordinator? _syncCoordinator;
  final Connectivity _connectivity = Connectivity();

  final StreamController<NetworkStateEvent> _stateController =
      StreamController<NetworkStateEvent>.broadcast();

  NetworkState _currentState = NetworkState.unknown;
  ConnectionType _currentConnectionType = ConnectionType.unknown;
  DateTime? _lastOnlineAt;
  DateTime? _lastStateChange;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _networkTestTimer;
  Timer? _autoSyncTimer;

  bool _isInitialized = false;
  bool _autoSyncEnabled = true;
  Duration _autoSyncInterval = const Duration(minutes: 15);

  /// Stream de eventos de cambio de estado
  Stream<NetworkStateEvent> get stateChanges => _stateController.stream;

  /// Estado actual de la red
  NetworkState get currentState => _currentState;

  /// Tipo de conexión actual
  ConnectionType get currentConnectionType => _currentConnectionType;

  /// Información completa de la red
  NetworkInfo get currentNetworkInfo => NetworkInfo(
        state: _currentState,
        connectionType: _currentConnectionType,
        isConnected: _currentState != NetworkState.offline,
        lastOnlineAt: _lastOnlineAt,
        offlineDuration:
            _lastOnlineAt != null && _currentState == NetworkState.offline
                ? DateTime.now().difference(_lastOnlineAt!)
                : null,
      );

  /// Indica si la sincronización automática está habilitada
  bool get isAutoSyncEnabled => _autoSyncEnabled;

  /// Intervalo de sincronización automática
  Duration get autoSyncInterval => _autoSyncInterval;

  /// Inicialización del manager
  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      // Estado inicial
      final initialConnectivity = await _connectivity.checkConnectivity();
      final primaryConnection = initialConnectivity.isNotEmpty
          ? initialConnectivity.first
          : ConnectivityResult.none;
      _currentConnectionType =
          ConnectionType.fromConnectivityResult(primaryConnection);

      // Probar conexión real
      await _testNetworkState();

      // Escuchar cambios de conectividad
      _connectivitySubscription =
          _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

      // Timer periódico para verificar estado de red
      _networkTestTimer = Timer.periodic(
          const Duration(seconds: 30), (_) => _testNetworkState());

      // Configurar auto-sync
      if (_autoSyncEnabled) {
        _scheduleAutoSync();
      }

      _isInitialized = true;
      LoggerFactory.info(
          '✅ NetworkStateManager initialized: ${currentNetworkInfo.toString()}');
    } catch (e) {
      LoggerFactory.error('❌ Failed to initialize NetworkStateManager: $e');
      _isInitialized = true; // Continue even if initialization fails
    }
  }

  /// Maneja cambios de conectividad del sistema
  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final primaryResult =
        results.isNotEmpty ? results.first : ConnectivityResult.none;
    final newConnectionType =
        ConnectionType.fromConnectivityResult(primaryResult);

    if (newConnectionType != _currentConnectionType) {
      LoggerFactory.info(
          '📶 Connectivity changed: ${_currentConnectionType.value} → ${newConnectionType.value}');
      _currentConnectionType = newConnectionType;

      // Re-evaluar estado de red
      await _testNetworkState();
    }
  }

  /// Prueba el estado real de la conexión
  Future<void> _testNetworkState() async {
    final previousState = _currentState;
    NetworkState newState;

    try {
      if (_currentConnectionType == ConnectionType.none) {
        newState = NetworkState.offline;
      } else {
        // Probar conectividad real con ping
        final isReachable = await _testInternetConnectivity();

        if (isReachable) {
          // Evaluar calidad de conexión
          final latency = await _measureLatency();

          if (latency != null && latency.inMilliseconds > 5000) {
            newState = NetworkState.limited; // Conexión muy lenta
          } else {
            newState = NetworkState.online;
          }
        } else {
          newState = NetworkState.offline;
        }
      }
    } catch (e) {
      LoggerFactory.warning('⚠️ Network test failed: $e');
      newState = NetworkState.unknown;
    }

    if (newState != _currentState) {
      await _updateNetworkState(previousState, newState);
    }
  }

  /// Prueba conectividad a internet
  Future<bool> _testInternetConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 10),
      );
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      LoggerFactory.debug('Internet connectivity test failed: $e');
      return false;
    }
  }

  /// Mide latencia de red
  Future<Duration?> _measureLatency() async {
    try {
      final stopwatch = Stopwatch()..start();

      await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 5),
      );

      stopwatch.stop();
      return stopwatch.elapsed;
    } catch (e) {
      LoggerFactory.debug('Latency measurement failed: $e');
      return null;
    }
  }

  /// Actualiza el estado de red y emite eventos
  Future<void> _updateNetworkState(
      NetworkState previousState, NetworkState newState) async {
    _currentState = newState;
    _lastStateChange = DateTime.now();

    if (newState == NetworkState.online) {
      _lastOnlineAt = _lastStateChange;
    }

    final event = NetworkStateEvent(
      previousState: previousState,
      currentState: newState,
      timestamp: _lastStateChange!,
      networkInfo: currentNetworkInfo,
    );

    _stateController.add(event);

    LoggerFactory.info('📶 Network state changed: ${event.toString()}');

    // Reaccionar a cambios de estado
    await _handleStateChange(event);
  }

  /// Maneja cambios de estado de red
  Future<void> _handleStateChange(NetworkStateEvent event) async {
    // Cuando volvemos online, sincronizar pendientes
    if (event.wentOnline && _syncCoordinator != null) {
      LoggerFactory.info('🔄 Network restored, triggering sync');

      // Esperar un poco para que la conexión se estabilice
      await Future.delayed(const Duration(seconds: 2));

      try {
        await _syncCoordinator!.performFullSync();
      } catch (e) {
        LoggerFactory.error('❌ Auto-sync after reconnection failed: $e');
      }
    }

    // Cancelar auto-sync si vamos offline
    if (event.wentOffline) {
      LoggerFactory.info('📵 Network lost, pausing auto-sync');
      _cancelAutoSync();
    } else if (event.wentOnline) {
      // Reanudar auto-sync cuando volvamos online
      if (_autoSyncEnabled) {
        _scheduleAutoSync();
      }
    }
  }

  /// Programa sincronización automática
  void _scheduleAutoSync() {
    _cancelAutoSync();

    if (!_autoSyncEnabled ||
        _syncCoordinator == null ||
        !currentNetworkInfo.canSync) {
      return;
    }

    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (timer) async {
      if (currentNetworkInfo.canSync) {
        LoggerFactory.info('⏰ Auto-sync triggered');

        try {
          await _syncCoordinator!.performFullSync();
        } catch (e) {
          LoggerFactory.error('❌ Auto-sync failed: $e');
        }
      } else {
        LoggerFactory.debug('⏸️ Auto-sync skipped - network not suitable');
      }
    });

    LoggerFactory.info(
        '⏰ Auto-sync scheduled every ${_autoSyncInterval.inMinutes} minutes');
  }

  /// Cancela sincronización automática
  void _cancelAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// Configura sincronización automática
  void configureAutoSync({
    required bool enabled,
    Duration? interval,
  }) {
    _autoSyncEnabled = enabled;

    if (interval != null) {
      _autoSyncInterval = interval;
    }

    if (enabled && currentNetworkInfo.canSync) {
      _scheduleAutoSync();
    } else {
      _cancelAutoSync();
    }

    LoggerFactory.info(
        '⚙️ Auto-sync configured: enabled=$enabled, interval=${_autoSyncInterval.inMinutes}min');
  }

  /// Fuerza una verificación de estado de red
  Future<NetworkInfo> forceNetworkCheck() async {
    await _testNetworkState();
    return currentNetworkInfo;
  }

  /// Ejecuta sincronización manual si la red lo permite
  Future<bool> trySyncNow() async {
    if (_syncCoordinator == null) return false;

    if (!currentNetworkInfo.canSync) {
      LoggerFactory.warning(
          '⚠️ Cannot sync - network not suitable: ${currentNetworkInfo.toString()}');
      return false;
    }

    try {
      LoggerFactory.info('🔄 Manual sync requested');
      await _syncCoordinator!.performFullSync();
      return true;
    } catch (e) {
      LoggerFactory.error('❌ Manual sync failed: $e');
      return false;
    }
  }

  /// Indica si se debe sincronizar automáticamente ahora
  bool shouldAutoSync() {
    return _autoSyncEnabled &&
        currentNetworkInfo.canSync &&
        _syncCoordinator != null;
  }

  /// Obtiene estadísticas de red
  Map<String, dynamic> getNetworkStatistics() {
    return {
      'current_state': _currentState.value,
      'connection_type': _currentConnectionType.value,
      'is_connected': currentNetworkInfo.isConnected,
      'can_sync': currentNetworkInfo.canSync,
      'should_sync_large': currentNetworkInfo.shouldSyncLarge,
      'auto_sync_enabled': _autoSyncEnabled,
      'auto_sync_interval_minutes': _autoSyncInterval.inMinutes,
      'last_online_at': _lastOnlineAt?.toIso8601String(),
      'last_state_change': _lastStateChange?.toIso8601String(),
    };
  }

  /// Libera recursos
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _networkTestTimer?.cancel();
    _cancelAutoSync();

    await _stateController.close();

    LoggerFactory.info('🔒 NetworkStateManager disposed');
  }
}
