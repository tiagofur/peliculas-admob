import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/services/cross_platform_init_service.dart';
import '../../infrastructure/services/sync_service.dart';
import 'auth_provider.dart';

/// Provider para el servicio de inicialización multiplataforma
final crossPlatformInitProvider = Provider<CrossPlatformInitService>((ref) {
  return CrossPlatformInitService.instance;
});

/// Provider que escucha cambios de autenticación y maneja la sincronización
final authSyncListenerProvider = Provider<AuthSyncListener>((ref) {
  return AuthSyncListener(ref);
});

/// Clase que maneja la sincronización automática basada en el estado de autenticación
class AuthSyncListener {
  AuthSyncListener(this._ref) {
    _listenToAuthChanges();
  }
  final Ref _ref;

  void _listenToAuthChanges() {
    // Escuchar cambios en el estado de autenticación
    _ref.listen<AppState>(
      appStateProvider,
      (previous, next) async {
        // Si el usuario acaba de autenticarse
        if (previous?.isAuthenticated == false &&
            next.isAuthenticated == true) {
          await _handleUserAuthenticated();
        }

        // Si el usuario acaba de cerrar sesión
        if (previous?.isAuthenticated == true &&
            next.isAuthenticated == false) {
          await _handleUserLoggedOut();
        }
      },
    );
  }

  /// Manejar cuando el usuario se autentica
  Future<void> _handleUserAuthenticated() async {
    try {
      print('🔐 Usuario autenticado - iniciando sincronización...');

      // Obtener el servicio de sincronización
      final syncService = _ref.read(syncServiceProvider);

      // Iniciar sincronización automática
      await syncService.onUserAuthenticated();

      print('✅ Sincronización post-login completada');
    } catch (e) {
      print('❌ Error en sincronización post-login: $e');
    }
  }

  /// Manejar cuando el usuario cierra sesión
  Future<void> _handleUserLoggedOut() async {
    try {
      print('🚪 Usuario cerró sesión - limpiando servicios...');

      // Obtener el servicio de sincronización
      final syncService = _ref.read(syncServiceProvider);

      // Detener sincronización y limpiar recursos
      syncService.dispose();

      // Opcionalmente limpiar datos locales
      // final initService = _ref.read(crossPlatformInitProvider);
      // await initService.clearAllData();

      print('✅ Limpieza post-logout completada');
    } catch (e) {
      print('❌ Error en limpieza post-logout: $e');
    }
  }

  /// Forzar sincronización manual
  Future<void> forceSyncAll() async {
    try {
      final syncService = _ref.read(syncServiceProvider);
      await syncService.forceSyncAllData();
    } catch (e) {
      print('❌ Error en sincronización manual: $e');
      rethrow;
    }
  }

  /// Obtener estado de sincronización
  Map<String, dynamic> getSyncStatus() {
    final syncService = _ref.read(syncServiceProvider);
    return syncService.getSyncStatus();
  }

  /// Verificar salud de los servicios
  Future<Map<String, bool>> checkServicesHealth() async {
    final initService = _ref.read(crossPlatformInitProvider);
    return await initService.checkHealth();
  }
}
