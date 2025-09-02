import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger_factory.dart';
import '../../infrastructure/services/connectivity_detector.dart';
import '../../infrastructure/services/sync_notification_service.dart';
import 'auth_provider.dart';
import 'sync_init_provider.dart';
import 'sync_status_provider.dart';

/// Provider para conectar el estado de sync con la infraestructura real
final syncIntegrationProvider = Provider<SyncIntegration>((ref) {
  return SyncIntegration(ref);
});

/// Clase que integra el estado de sincronización UI con los servicios reales
class SyncIntegration {
  SyncIntegration(this._ref) {
    _initialize();
  }

  final Ref _ref;
  Timer? _connectionCheckTimer;
  Timer? _syncCheckTimer;

  void _initialize() {
    // Inicializar servicio de notificaciones
    SyncNotificationService.instance.initialize();
    
    // Verificar conectividad cada 5 segundos
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkConnectivityStatus();
    });

    // Verificar estado de sync cada 10 segundos
    _syncCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkSyncHealth();
    });

    // Escuchar cambios de autenticación para activar sync
    _ref.listen<AppState>(appStateProvider, (previous, next) {
      _handleAuthChange(previous, next);
    });

    // Escuchar cambios de estado de sync para notificaciones
    _ref.listen<SyncState>(syncStatusProvider, (previous, next) {
      _handleSyncStateChange(previous, next);
    });
  }

  void _checkConnectivityStatus() {
    try {
      final isOnline = ConnectivityDetector.instance.isOnline;
      final syncNotifier = _ref.read(syncStatusProvider.notifier);
      
      if (!isOnline && _ref.read(syncStatusProvider).status != SyncStatus.offline) {
        syncNotifier.setOffline();
      } else if (isOnline && _ref.read(syncStatusProvider).status == SyncStatus.offline) {
        // Volver a estado normal cuando se recupere la conexión
        syncNotifier.setSyncSuccess();
      }
    } catch (e) {
      LoggerFactory.error('Error verificando conectividad: $e');
    }
  }

  void _checkSyncHealth() async {
    try {
      final appState = _ref.read(appStateProvider);
      if (!appState.isAuthenticated) return;

      final authSyncListener = _ref.read(authSyncListenerProvider);
      final healthStatus = await authSyncListener.checkServicesHealth();
      
      final syncNotifier = _ref.read(syncStatusProvider.notifier);
      final currentState = _ref.read(syncStatusProvider);
      
      // Solo actualizar si no estamos en medio de una sincronización
      if (currentState.status != SyncStatus.syncing) {
        final isHealthy = healthStatus.values.every((healthy) => healthy);
        
        if (!isHealthy && currentState.status != SyncStatus.error) {
          syncNotifier.setError('Problemas de conectividad');
        } else if (isHealthy && currentState.status == SyncStatus.error) {
          syncNotifier.setSyncSuccess();
        }
      }
    } catch (e) {
      LoggerFactory.error('Error verificando salud del sistema sync: $e');
    }
  }

  void _handleAuthChange(AppState? previous, AppState next) {
    final syncNotifier = _ref.read(syncStatusProvider.notifier);
    
    if (previous?.isAuthenticated != next.isAuthenticated) {
      if (next.isAuthenticated) {
        LoggerFactory.info('Usuario autenticado - activando indicadores de sync');
        // Mostrar notificación inicial
        SyncNotificationService.instance.showInitialSyncNotification();
        // Iniciar sincronización automática
        syncNotifier.startManualSync();
      } else {
        LoggerFactory.info('Usuario desautenticado - limpiando estado de sync');
        // Cancelar notificaciones
        SyncNotificationService.instance.cancelAllSyncNotifications();
        syncNotifier._updateStatus(SyncStatus.idle, '');
      }
    }
  }

  void _handleSyncStateChange(SyncState? previous, SyncState next) {
    // Solo mostrar notificaciones para cambios significativos
    if (previous?.status == next.status) return;

    switch (next.status) {
      case SyncStatus.success:
        if (previous?.status == SyncStatus.syncing) {
          // Sync completado exitosamente
          SyncNotificationService.instance.showSyncSuccessNotification(
            itemsSynced: 1, // Placeholder - se podría obtener del resultado real
            additionalInfo: next.message,
          );
        }
        break;
      case SyncStatus.error:
        if (previous?.status == SyncStatus.syncing) {
          // Error durante sync
          SyncNotificationService.instance.showSyncErrorNotification(
            errorMessage: next.errorMessage ?? 'Error desconocido',
            canRetry: true,
          );
        }
        break;
      case SyncStatus.syncing:
      case SyncStatus.offline:
      case SyncStatus.idle:
        // No mostrar notificaciones para estos estados
        break;
    }
  }

  /// Método para forzar verificación de estado
  void forceStatusCheck() {
    _checkConnectivityStatus();
    _checkSyncHealth();
  }

  /// Método para limpiar recursos
  void dispose() {
    _connectionCheckTimer?.cancel();
    _syncCheckTimer?.cancel();
  }
}

/// Provider para inicializar automáticamente la integración
final syncIntegrationInitProvider = Provider<void>((ref) {
  // Solo inicializar la integración sin hacer nada más
  ref.watch(syncIntegrationProvider);
  return;
});

// Extensión para acceder a métodos privados desde la integración
extension SyncStatusNotifierExtension on SyncStatusNotifier {
  void _updateStatus(SyncStatus status, String message, {double? progress}) {
    state = state.copyWith(
      status: status,
      message: message,
      progress: progress ?? (status == SyncStatus.success ? 1.0 : state.progress),
      lastSyncTime: status == SyncStatus.success ? DateTime.now() : state.lastSyncTime,
      errorMessage: status == SyncStatus.error ? message : null,
    );
  }
}