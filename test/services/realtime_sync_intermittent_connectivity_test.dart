import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/infrastructure/services/connectivity_manager.dart';

// Implementación simple para pruebas
class TestConnectivityManager implements ConnectivityManager {
  final StreamController<ConnectionStatus> _controller =
      StreamController<ConnectionStatus>.broadcast();

  ConnectionStatus _currentStatus = ConnectionStatus.online;

  @override
  Stream<ConnectionStatus> get connectionStatus => _controller.stream;

  @override
  ConnectionStatus get currentStatus => _currentStatus;

  void updateStatus(ConnectionStatus status) {
    _currentStatus = status;
    _controller.add(status);
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }

  Future<bool> checkConnectivity() async {
    return _currentStatus == ConnectionStatus.online;
  }

  @override
  Future<void> initialize() async {
    // No-op para pruebas
  }

  @override
  bool get isManualOfflineMode => false;

  @override
  Future<void> enableOfflineMode() async {
    updateStatus(ConnectionStatus.offline);
  }

  @override
  Future<void> forceConnectionCheck() async {
    // No-op para pruebas
  }

  @override
  Map<String, dynamic> getStatistics() {
    return {
      'currentStatus': _currentStatus.toString(),
    };
  }

  @override
  Stream<BackgroundSyncEvent> get backgroundSyncEvents => const Stream.empty();

  @override
  Future<void> disableOfflineMode() async {
    updateStatus(ConnectionStatus.online);
  }
}

void main() {
  group('ConnectivityManager - Conectividad Intermitente', () {
    late TestConnectivityManager connectivityManager;

    setUp(() {
      connectivityManager = TestConnectivityManager();
    });

    tearDown(() {
      connectivityManager.dispose();
    });

    test('debe detectar pérdida de conexión', () async {
      // Arrange
      expect(connectivityManager.currentStatus, ConnectionStatus.online);

      // Act - Simular pérdida de conexión
      connectivityManager.updateStatus(ConnectionStatus.offline);
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(connectivityManager.currentStatus, ConnectionStatus.offline);
      final isConnected = await connectivityManager.checkConnectivity();
      expect(isConnected, isFalse);
    });

    test('debe detectar restauración de conexión', () async {
      // Arrange - Simular pérdida de conexión
      connectivityManager.updateStatus(ConnectionStatus.offline);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(connectivityManager.currentStatus, ConnectionStatus.offline);

      // Act - Restaurar conexión
      connectivityManager.updateStatus(ConnectionStatus.online);
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(connectivityManager.currentStatus, ConnectionStatus.online);
      final isConnected = await connectivityManager.checkConnectivity();
      expect(isConnected, isTrue);
    });

    test('debe manejar múltiples cambios de conectividad rápidos', () async {
      // Arrange
      expect(connectivityManager.currentStatus, ConnectionStatus.online);

      // Act - Simular cambios rápidos de conectividad
      for (int i = 0; i < 5; i++) {
        connectivityManager.updateStatus(ConnectionStatus.offline);
        await Future.delayed(const Duration(milliseconds: 50));

        connectivityManager.updateStatus(ConnectionStatus.online);
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Assert - Debe estar en estado estable (online)
      expect(connectivityManager.currentStatus, ConnectionStatus.online);
      final isConnected = await connectivityManager.checkConnectivity();
      expect(isConnected, isTrue);
    });

    test('debe verificar salud de conexión correctamente', () async {
      // Arrange & Act - Conexión saludable inicial
      final healthyResult = await connectivityManager.checkConnectivity();
      expect(healthyResult, isTrue);

      // Simular desconexión
      connectivityManager.updateStatus(ConnectionStatus.offline);
      await Future.delayed(const Duration(milliseconds: 100));

      // Act & Assert - Conexión no saludable
      final unhealthyResult = await connectivityManager.checkConnectivity();
      expect(unhealthyResult, isFalse);
    });

    test('debe manejar reconexión después de problemas', () async {
      // Arrange - Simular problema de conectividad
      connectivityManager.updateStatus(ConnectionStatus.offline);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(connectivityManager.currentStatus, ConnectionStatus.offline);

      // Act - Reconectar
      connectivityManager.updateStatus(ConnectionStatus.online);
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(connectivityManager.currentStatus, ConnectionStatus.online);
      final isConnected = await connectivityManager.checkConnectivity();
      expect(isConnected, isTrue);
    });

    test('debe manejar conexión limitada apropiadamente', () async {
      // Arrange
      expect(connectivityManager.currentStatus, ConnectionStatus.online);

      // Act - Simular conexión limitada
      connectivityManager.updateStatus(ConnectionStatus.limited);
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert - Conexión limitada no es considerada como conectada
      expect(connectivityManager.currentStatus, ConnectionStatus.limited);
      final isConnected = await connectivityManager.checkConnectivity();
      expect(isConnected, isFalse);
    });

    test('debe detectar cambios de estado de conexión via stream', () async {
      // Arrange
      final statusChanges = <ConnectionStatus>[];
      final subscription = connectivityManager.connectionStatus
          .listen((status) => statusChanges.add(status));

      // Act - Simular varios cambios de estado
      connectivityManager.updateStatus(ConnectionStatus.offline);
      await Future.delayed(const Duration(milliseconds: 50));

      connectivityManager.updateStatus(ConnectionStatus.limited);
      await Future.delayed(const Duration(milliseconds: 50));

      connectivityManager.updateStatus(ConnectionStatus.online);
      await Future.delayed(const Duration(milliseconds: 50));

      // Assert
      expect(statusChanges, contains(ConnectionStatus.offline));
      expect(statusChanges, contains(ConnectionStatus.limited));
      expect(statusChanges, contains(ConnectionStatus.online));

      await subscription.cancel();
    });
  });
}
