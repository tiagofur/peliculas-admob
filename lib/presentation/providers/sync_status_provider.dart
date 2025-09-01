import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger_factory.dart';
import '../../infrastructure/services/sync_service.dart';
import 'auth_provider.dart';
import 'sync_init_provider.dart';

/// Estados de sincronización
enum SyncStatus {
  idle,       // Sin sincronización activa
  syncing,    // Sincronizando datos
  success,    // Sincronización exitosa
  error,      // Error en sincronización
  offline,    // Sin conexión
}

/// Modelo para el estado de sincronización
class SyncState {
  const SyncState({
    this.status = SyncStatus.idle,
    this.message = '',
    this.progress = 0.0,
    this.lastSyncTime,
    this.errorMessage,
  });

  final SyncStatus status;
  final String message;
  final double progress;
  final DateTime? lastSyncTime;
  final String? errorMessage;

  SyncState copyWith({
    SyncStatus? status,
    String? message,
    double? progress,
    DateTime? lastSyncTime,
    String? errorMessage,
  }) {
    return SyncState(
      status: status ?? this.status,
      message: message ?? this.message,
      progress: progress ?? this.progress,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: errorMessage,
    );
  }

  bool get isActive => status == SyncStatus.syncing;
  bool get hasError => status == SyncStatus.error;
  bool get isSuccess => status == SyncStatus.success;
  bool get isOffline => status == SyncStatus.offline;
}

/// Provider del servicio de sincronización existente
/// Este provider accede al sync service a través del AuthSyncListener
final syncServiceAccessProvider = Provider<Map<String, dynamic>?>((ref) {
  try {
    // Intentar obtener el estado del sync desde el AuthSyncListener
    final authSyncListener = ref.read(authSyncListenerProvider);
    return authSyncListener.getSyncStatus();
  } catch (e) {
    // Si hay error, retornar null para indicar que no está disponible
    return null;
  }
});

/// Notifier para el estado de sincronización
class SyncStatusNotifier extends StateNotifier<SyncState> {
  SyncStatusNotifier(this._ref) : super(const SyncState()) {
    _initializeListeners();
  }

  final Ref _ref;
  Timer? _statusCheckTimer;
  Timer? _messageDisplayTimer;

  void _initializeListeners() {
    // Escuchar cambios de autenticación para actualizar estado
    _ref.listen<AppState>(appStateProvider, (previous, next) {
      if (previous?.isAuthenticated != next.isAuthenticated) {
        if (next.isAuthenticated) {
          _updateStatus(SyncStatus.syncing, 'Iniciando sincronización...');
        } else {
          _updateStatus(SyncStatus.idle, '');
        }
      }
    });

    // Iniciar verificación periódica del estado
    _startStatusChecking();
  }

  void _startStatusChecking() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkSyncStatus();
    });
  }

  void _checkSyncStatus() {
    try {
      final appState = _ref.read(appStateProvider);
      
      // Si no está autenticado, estado idle
      if (!appState.isAuthenticated) {
        if (state.status != SyncStatus.idle) {
          state = state.copyWith(
            status: SyncStatus.idle,
            message: '',
            progress: 0.0,
          );
        }
        return;
      }

      // Obtener estado de la sincronización desde el sync service
      // Como no podemos acceder directamente al SyncService aquí,
      // usaremos una aproximación basada en el estado de la app
      _updateSyncStatusFromSystemState();
      
    } catch (e) {
      LoggerFactory.error('Error verificando estado de sincronización: $e');
      if (!state.hasError) {
        _updateStatus(SyncStatus.error, 'Error verificando sincronización');
      }
    }
  }

  void _checkSyncStatus() {
    try {
      final appState = _ref.read(appStateProvider);
      
      // Si no está autenticado, estado idle
      if (!appState.isAuthenticated) {
        if (state.status != SyncStatus.idle) {
          state = state.copyWith(
            status: SyncStatus.idle,
            message: '',
            progress: 0.0,
          );
        }
        return;
      }

      // Obtener estado de la sincronización desde el sistema existente
      final syncServiceStatus = _ref.read(syncServiceAccessProvider);
      _updateSyncStatusFromServiceData(syncServiceStatus);
      
    } catch (e) {
      LoggerFactory.error('Error verificando estado de sincronización: $e');
      if (!state.hasError) {
        _updateStatus(SyncStatus.error, 'Error verificando sincronización');
      }
    }
  }

  void _updateSyncStatusFromServiceData(Map<String, dynamic>? serviceStatus) {
    final appState = _ref.read(appStateProvider);
    
    if (!appState.isAuthenticated) {
      return;
    }

    if (serviceStatus == null) {
      // Si no hay información del servicio, asumir estado idle para usuarios autenticados
      if (state.status != SyncStatus.success && state.status != SyncStatus.error) {
        _updateStatus(SyncStatus.success, 'Datos disponibles');
      }
      return;
    }

    // Interpretar el estado del servicio de sincronización
    final isPeriodicSyncActive = serviceStatus['is_periodic_sync_active'] as bool? ?? false;
    final recentErrors = serviceStatus['recent_errors'] as List? ?? [];
    final retryAttempts = serviceStatus['retry_attempts'] as Map? ?? {};

    if (recentErrors.isNotEmpty) {
      if (state.status != SyncStatus.error) {
        _updateStatus(SyncStatus.error, 'Error en sincronización');
      }
    } else if (isPeriodicSyncActive) {
      if (state.status == SyncStatus.idle || state.status == SyncStatus.error) {
        _updateStatus(SyncStatus.success, 'Datos sincronizados');
      }
    } else {
      // Sin sync activo, pero usuario autenticado - estado neutral
      if (state.status == SyncStatus.idle || state.status == SyncStatus.error) {
        _updateStatus(SyncStatus.success, 'Listo para sincronizar');
      }
    }
  }

  /// Actualizar estado de sincronización manualmente
  void _updateStatus(SyncStatus status, String message, {double? progress}) {
    state = state.copyWith(
      status: status,
      message: message,
      progress: progress ?? (status == SyncStatus.success ? 1.0 : state.progress),
      lastSyncTime: status == SyncStatus.success ? DateTime.now() : state.lastSyncTime,
      errorMessage: status == SyncStatus.error ? message : null,
    );

    // Auto-limpiar mensajes después de un tiempo
    if (status == SyncStatus.success || status == SyncStatus.error) {
      _scheduleMessageClear();
    }
  }

  void _scheduleMessageClear() {
    _messageDisplayTimer?.cancel();
    _messageDisplayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (state.status == SyncStatus.success || state.status == SyncStatus.error)) {
        state = state.copyWith(
          status: SyncStatus.idle,
          message: '',
          progress: 0.0,
        );
      }
    });
  }

  /// Método público para iniciar sincronización manual
  void startManualSync() {
    final appState = _ref.read(appStateProvider);
    if (!appState.isAuthenticated) {
      LoggerFactory.warning('Intento de sincronización sin usuario autenticado');
      return;
    }

    _updateStatus(SyncStatus.syncing, 'Iniciando sincronización...', progress: 0.1);
    
    // Intentar ejecutar sincronización real a través del AuthSyncListener
    _triggerActualSync();
  }

  Future<void> _triggerActualSync() async {
    try {
      final authSyncListener = _ref.read(authSyncListenerProvider);
      
      // Simular progreso inicial
      _updateProgressSteps();
      
      // Ejecutar sincronización real
      await authSyncListener.forceSyncAll();
      
      // Éxito
      _updateStatus(SyncStatus.success, 'Sincronización completada');
      
    } catch (e) {
      LoggerFactory.error('Error en sincronización manual: $e');
      _updateStatus(SyncStatus.error, 'Error: ${e.toString()}');
    }
  }

  void _updateProgressSteps() {
    // Simular progreso durante la sincronización
    Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!mounted || state.status != SyncStatus.syncing) {
        timer.cancel();
        return;
      }
      
      final currentProgress = state.progress + 0.15;
      if (currentProgress >= 0.9) {
        timer.cancel();
        // El progreso final se manejará cuando termine la sincronización real
        state = state.copyWith(progress: 0.9);
      } else {
        state = state.copyWith(progress: currentProgress);
      }
    });
  }

  /// Método público para indicar error de sincronización
  void setError(String errorMessage) {
    _updateStatus(SyncStatus.error, errorMessage);
  }

  /// Método público para indicar modo offline
  void setOffline() {
    _updateStatus(SyncStatus.offline, 'Sin conexión a internet');
  }

  /// Método público para forzar estado de éxito
  void setSyncSuccess() {
    _updateStatus(SyncStatus.success, 'Datos actualizados');
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _messageDisplayTimer?.cancel();
    super.dispose();
  }
}

/// Provider del estado de sincronización
final syncStatusProvider = StateNotifierProvider<SyncStatusNotifier, SyncState>((ref) {
  return SyncStatusNotifier(ref);
});

/// Provider para verificar si hay sincronización activa
final isSyncingProvider = Provider<bool>((ref) {
  final syncState = ref.watch(syncStatusProvider);
  return syncState.isActive;
});

/// Provider para obtener el último tiempo de sincronización
final lastSyncTimeProvider = Provider<DateTime?>((ref) {
  final syncState = ref.watch(syncStatusProvider);
  return syncState.lastSyncTime;
});

/// Provider para verificar si hay errores de sincronización
final hasSyncErrorProvider = Provider<bool>((ref) {
  final syncState = ref.watch(syncStatusProvider);
  return syncState.hasError;
});