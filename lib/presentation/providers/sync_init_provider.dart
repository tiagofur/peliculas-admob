import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger_factory.dart';
import '../../infrastructure/services/cross_platform_init_service.dart';
import '../../infrastructure/services/sync_service.dart';
import 'auth_provider.dart';

/// Provider para el servicio de inicialización multiplataforma
final crossPlatformInitProvider = Provider<CrossPlatformInitService>((ref) {
  return CrossPlatformInitService.instance;
});

/// Provider que escucha cambios de autenticación y maneja la sincronización
final authSyncListenerProvider = Provider<AuthSyncListener>((ref) {
  return AuthSyncListener(
    listenToAuthChanges: (void Function(AppState?, AppState) callback) {
      ref.listen<AppState>(appStateProvider, callback);
    },
    getSyncService: () => ref.read(syncServiceProvider),
  );
});

/// Clase que maneja la sincronización automática basada en el estado de autenticación
class AuthSyncListener {
  AuthSyncListener({
    required this.listenToAuthChanges,
    required this.getSyncService,
  }) {
    _initializeAuthListener();
  }

  final void Function(void Function(AppState?, AppState)) listenToAuthChanges;
  final SyncService Function() getSyncService;

  void _initializeAuthListener() {
    // Escuchar cambios en el estado de autenticación usando callback
    listenToAuthChanges((previous, next) async {
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
    });
  }

  /// Manejar cuando el usuario se autentica
  Future<void> _handleUserAuthenticated() async {
    try {
      LoggerFactory.info('🔐 Usuario autenticado - SYNC AUTOMÁTICO DESHABILITADO');

      // NO inicializar ningún servicio de sincronización automática para evitar bloqueos
      LoggerFactory.info('⚠️ Sincronización automática deshabilitada para evitar congelamiento');
      LoggerFactory.info('💡 El usuario puede sincronizar manualmente desde Settings');
      
    } catch (e) {
      LoggerFactory.error('❌ Error en configuración post-login: $e');
    }
  }

  /// Manejar cuando el usuario cierra sesión
  Future<void> _handleUserLoggedOut() async {
    try {
      LoggerFactory.info('🚪 Usuario cerró sesión - limpiando servicios...');

      // Obtener el servicio de sincronización usando callback
      final syncService = getSyncService();

      // Detener sincronización y limpiar recursos
      syncService.dispose();

      // Opcionalmente limpiar datos locales
      // final initService = _ref.read(crossPlatformInitProvider);
      // await initService.clearAllData();

      LoggerFactory.info('✅ Limpieza post-logout completada');
    } catch (e) {
      LoggerFactory.error('❌ Error en limpieza post-logout: $e');
    }
  }

  /// Forzar sincronización manual
  Future<void> forceSyncAll() async {
    try {
      final syncService = getSyncService();
      await syncService.forceSyncAllData();
    } catch (e) {
      LoggerFactory.error('❌ Error en sincronización manual: $e');
      rethrow;
    }
  }

  /// Obtener estado de sincronización
  Map<String, dynamic> getSyncStatus() {
    final syncService = getSyncService();
    return syncService.getSyncStatus();
  }

  /// Verificar salud de los servicios
  Future<Map<String, bool>> checkServicesHealth() async {
    try {
      final initService = CrossPlatformInitService.instance;
      return await initService.checkHealth();
    } catch (e) {
      LoggerFactory.error('Error verificando salud de servicios: $e');
      return {'general': false};
    }
  }
}
