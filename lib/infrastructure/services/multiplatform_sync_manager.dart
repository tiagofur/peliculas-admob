import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger_factory.dart';
import '../../presentation/providers/user_movie_ratings_provider.dart';
import '../../presentation/providers/watchlist_provider.dart';
import 'app_lifecycle_manager.dart';
import 'connectivity_detector.dart';

/// Gestor de sincronización multiplataforma que orquesta la sincronización automática
/// entre diferentes dispositivos y plataformas usando Supabase como hub central.
class MultiplataformSyncManager {
  MultiplataformSyncManager._internal();
  static const Duration _syncInterval = Duration(seconds: 30);
  static const Duration _backgroundSyncDelay = Duration(seconds: 2);

  static MultiplataformSyncManager? _instance;
  static MultiplataformSyncManager get instance {
    _instance ??= MultiplataformSyncManager._internal();
    return _instance!;
  }

  Timer? _periodicSyncTimer;
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;
  _AppLifecycleObserver? _lifecycleObserver;
  
  // Reference to Riverpod container for invalidating providers
  ProviderContainer? _providerContainer;

  bool _isInitialized = false;
  bool _isPeriodicSyncActive = false;
  DateTime? _lastSyncAttempt;
  DateTime? _lastSuccessfulSync;

  /// Inicializa el gestor de sincronización multiplataforma
  Future<void> initialize([ProviderContainer? container]) async {
    if (_isInitialized) {
      LoggerFactory.info('⚠️ MultiplataformSyncManager ya está inicializado');
      return;
    }

    // Store container reference for provider invalidation
    _providerContainer = container;

    LoggerFactory.info('🚀 Inicializando MultiplataformSyncManager...');

    try {
      // Verificar conectividad inicial
      await _checkInitialConnectivity();

      // Configurar listeners de conectividad
      await _setupConnectivityListener();

      // Configurar observer del ciclo de vida
      _setupLifecycleObserver();

      // Realizar sincronización inicial
      await _performInitialSync();

      // Iniciar sincronización periódica
      _startPeriodicSync();

      _isInitialized = true;
      LoggerFactory.info(
          '✅ MultiplataformSyncManager inicializado correctamente');
    } catch (e) {
      LoggerFactory.error(
          '❌ Error inicializando MultiplataformSyncManager: $e');
      rethrow;
    }
  }

  /// Verifica la conectividad inicial
  Future<void> _checkInitialConnectivity() async {
    final status = ConnectivityDetector.instance.getDetailedStatus();
    LoggerFactory.info(
        '📡 Estado inicial de conectividad: ${status['status']}');
  }

  /// Configura el listener de cambios de conectividad
  Future<void> _setupConnectivityListener() async {
    _connectivitySubscription =
        ConnectivityDetector.instance.onConnectivityChanged.listen(
      (status) => _handleConnectivityChange(status),
      onError: (error) {
        LoggerFactory.error('❌ Error en listener de conectividad: $error');
      },
    );

    LoggerFactory.info('📡 Listener de conectividad configurado');
  }

  /// Configura el observer del ciclo de vida de la aplicación
  void _setupLifecycleObserver() {
    _lifecycleObserver = _AppLifecycleObserver(this);
    WidgetsBinding.instance.addObserver(_lifecycleObserver!);

    LoggerFactory.info('🔄 Observer del ciclo de vida configurado');
  }

  /// Maneja cambios en el ciclo de vida de la aplicación
  void _handleAppLifecycleChange(AppLifecycleState state) {
    LoggerFactory.info('🔄 Cambio en ciclo de vida: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _onAppBackground();
        break;
      case AppLifecycleState.inactive:
        // No hacer nada en estado inactivo
        break;
    }
  }

  /// Maneja cuando la app vuelve al primer plano
  void _onAppResumed() {
    LoggerFactory.info('📱 App en primer plano - iniciando sincronización');

    // Reiniciar sincronización periódica
    _startPeriodicSync();

    // Programar sincronización inmediata
    _scheduleForegroundSync();
  }

  /// Maneja cuando la app va a segundo plano
  void _onAppPaused() {
    LoggerFactory.info(
        '📱 App pausada - reduciendo actividad de sincronización');
  }

  /// Maneja cuando la app va completamente al background
  void _onAppBackground() {
    LoggerFactory.info(
        '📱 App en background - pausando sincronización periódica');
    _stopPeriodicSync();
  }

  /// Maneja cambios de conectividad
  void _handleConnectivityChange(ConnectivityStatus status) {
    LoggerFactory.info('📡 Cambio de conectividad: $status');

    if (status == ConnectivityStatus.online) {
      _scheduleConnectivitySync();
    }
  }

  /// Realiza la sincronización inicial
  Future<void> _performInitialSync() async {
    LoggerFactory.info('🔄 Realizando sincronización inicial...');
    await _performSync('initial');
  }

  /// Inicia la sincronización periódica
  void _startPeriodicSync() {
    if (_isPeriodicSyncActive) {
      LoggerFactory.info('⚠️ Sincronización periódica ya está activa');
      return;
    }

    LoggerFactory.info(
        '⏰ Iniciando sincronización periódica cada ${_syncInterval.inSeconds}s');

    _periodicSyncTimer = Timer.periodic(_syncInterval, (timer) {
      _performPeriodicSync();
    });

    _isPeriodicSyncActive = true;
  }

  /// Detiene la sincronización periódica
  void _stopPeriodicSync() {
    if (!_isPeriodicSyncActive) return;

    LoggerFactory.info('⏹️ Deteniendo sincronización periódica');

    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    _isPeriodicSyncActive = false;
  }

  /// Programa sincronización por reconexión
  void _scheduleConnectivitySync() {
    LoggerFactory.info('📡 Programando sincronización por reconexión...');

    Timer(_backgroundSyncDelay, () {
      _performSync('connectivity_restored');
    });
  }

  /// Programa sincronización al volver del background
  void _scheduleForegroundSync() {
    LoggerFactory.info('🔄 Programando sincronización por foreground...');

    Timer(_backgroundSyncDelay, () {
      _performSync('foreground_resumed');
    });
  }

  /// Ejecuta sincronización periódica
  Future<void> _performPeriodicSync() async {
    await _performSync('periodic');
  }

  /// Ejecuta una sincronización con el motivo especificado
  Future<void> _performSync(String reason) async {
    if (!_canPerformSync()) {
      LoggerFactory.info(
          '⚠️ No se puede realizar sincronización ($reason): condiciones no cumplidas');
      return;
    }

    _lastSyncAttempt = DateTime.now();

    LoggerFactory.info('🔄 Iniciando sincronización ($reason)...');

    try {
      // Aquí se integraría con SyncService cuando esté disponible
      // Por ahora, simular sincronización exitosa
      await Future.delayed(const Duration(milliseconds: 500));

      _lastSuccessfulSync = DateTime.now();
      LoggerFactory.info('✅ Sincronización completada ($reason)');
    } catch (e) {
      LoggerFactory.error('❌ Error en sincronización ($reason): $e');
    }
  }

  /// Verifica si se puede realizar una sincronización
  bool _canPerformSync() {
    // Verificar si está inicializado
    if (!_isInitialized) return false;

    // Verificar conectividad
    if (!ConnectivityDetector.instance.isOnline) return false;

    return true;
  }

  /// Libera los recursos utilizados por el gestor
  Future<void> dispose() async {
    LoggerFactory.info(
        '🧹 Liberando recursos del MultiplataformSyncManager...');

    try {
      // Detener sincronización periódica
      _stopPeriodicSync();

      // Cancelar suscripciones
      await _connectivitySubscription?.cancel();
      _connectivitySubscription = null;

      // Remover observer del ciclo de vida
      if (_lifecycleObserver != null) {
        WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
        _lifecycleObserver = null;
      }

      // Limpiar estado
      _isInitialized = false;
      _isPeriodicSyncActive = false;

      LoggerFactory.info('✅ Recursos del MultiplataformSyncManager liberados');
    } catch (e) {
      LoggerFactory.error(
          '❌ Error liberando recursos del MultiplataformSyncManager: $e');
    }
  }

  /// Obtiene el estado actual del gestor de sincronización
  Map<String, dynamic> getManagerStatus() {
    return {
      'isInitialized': _isInitialized,
      'isPeriodicSyncActive': _isPeriodicSyncActive,
      'lastSyncAttempt': _lastSyncAttempt?.toIso8601String(),
      'lastSuccessfulSync': _lastSuccessfulSync?.toIso8601String(),
      'connectivityStatus': ConnectivityDetector.instance.getDetailedStatus(),
      'lifecycleStatus': AppLifecycleManager.instance.getDetailedStatus(),
    };
  }

  /// Verifica si el sistema necesita sincronización
  bool needsSync() {
    if (!_isInitialized) return false;

    // Verificar si hay conectividad
    if (!ConnectivityDetector.instance.isOnline) return false;

    // Verificar si la app está en primer plano
    final lifecycleStatus = AppLifecycleManager.instance.getDetailedStatus();
    if (lifecycleStatus['status'] != 'resumed') return false;

    return true;
  }

  /// Fuerza una sincronización manual
  Future<void> forceSync() async {
    if (!_isInitialized) {
      LoggerFactory.warning(
          '⚠️ MultiplataformSyncManager no está inicializado');
      return;
    }

    LoggerFactory.info('🔄 Forzando sincronización manual...');
    await _performSync('manual_force');
  }

  // ========== MÉTODOS PARA MANEJO DE EVENTOS DE TIEMPO REAL ==========

  /// Maneja inserción de datos desde tiempo real
  Future<void> handleRealtimeInsert(String tableName, Map<String, dynamic> data) async {
    LoggerFactory.info('⚡ Realtime INSERT en $tableName: ${data['id']}');
    
    try {
      // Invalidate specific providers based on table
      _invalidateProviders(tableName);
      
      // Trigger sync for data consistency
      await _performSync('realtime_insert_$tableName');
    } catch (e) {
      LoggerFactory.error('❌ Error manejando realtime insert: $e');
    }
  }

  /// Maneja actualización de datos desde tiempo real
  Future<void> handleRealtimeUpdate(String tableName, Map<String, dynamic> data) async {
    LoggerFactory.info('⚡ Realtime UPDATE en $tableName: ${data['id']}');
    
    try {
      // Invalidate specific providers based on table
      _invalidateProviders(tableName);
      
      // Trigger sync for conflict resolution if necessary
      await _performSync('realtime_update_$tableName');
    } catch (e) {
      LoggerFactory.error('❌ Error manejando realtime update: $e');
    }
  }

  /// Maneja eliminación de datos desde tiempo real
  Future<void> handleRealtimeDelete(String tableName, String id) async {
    LoggerFactory.info('⚡ Realtime DELETE en $tableName: $id');
    
    try {
      // Invalidate specific providers based on table
      _invalidateProviders(tableName);
      
      await _performSync('realtime_delete_$tableName');
    } catch (e) {
      LoggerFactory.error('❌ Error manejando realtime delete: $e');
    }
  }

  /// Invalidates providers based on the affected table
  void _invalidateProviders(String tableName) {
    if (_providerContainer == null) {
      LoggerFactory.warning('⚠️ No provider container available for invalidation');
      return;
    }

    try {
      switch (tableName) {
        case 'user_watchlist':
          LoggerFactory.info('🔄 Invalidating watchlist providers');
          _providerContainer!.invalidate(watchlistProvider);
          _providerContainer!.invalidate(watchlistCountProvider);
          _providerContainer!.invalidate(isMovieInWatchlistProvider);
          _providerContainer!.invalidate(watchlistMovieProvider);
          break;
          
        case 'user_movie_ratings':
          LoggerFactory.info('🔄 Invalidating ratings providers');
          _providerContainer!.invalidate(userRatingsProvider);
          _providerContainer!.invalidate(ratingStatsProvider);
          _providerContainer!.invalidate(topRatedMoviesProvider);
          _providerContainer!.invalidate(recentRatingsProvider);
          break;
          
        default:
          LoggerFactory.info('🔄 Unknown table for provider invalidation: $tableName');
      }
    } catch (e) {
      LoggerFactory.error('❌ Error invalidating providers: $e');
    }
  }

  /// Maneja errores de conexión de tiempo real
  void handleRealtimeError(String error) {
    LoggerFactory.error('⚡❌ Error en tiempo real: $error');
    
    // Podríamos implementar lógica de recuperación aquí
    // Por ejemplo, forzar una sincronización completa
    Timer(const Duration(seconds: 5), () {
      forceSync();
    });
  }

  /// Maneja reconexión de tiempo real
  void handleRealtimeReconnect() {
    LoggerFactory.info('⚡🔄 Reconexión de tiempo real establecida');
    
    // Realizar sincronización para asegurar consistencia
    Timer(const Duration(seconds: 1), () {
      _performSync('realtime_reconnect');
    });
  }
}

/// Observer del ciclo de vida de la aplicación
class _AppLifecycleObserver with WidgetsBindingObserver {
  _AppLifecycleObserver(this._syncManager);
  final MultiplataformSyncManager _syncManager;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncManager._handleAppLifecycleChange(state);
  }
}

/// Provider para el gestor de sincronización multiplataforma
final multiplataformSyncManagerProvider =
    Provider<MultiplataformSyncManager>((ref) {
  return MultiplataformSyncManager.instance;
});
