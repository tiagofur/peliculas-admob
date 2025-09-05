import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logging/logger_factory.dart';
import '../../core/logging/safe_developer_log.dart';
import '../../domain/entities/sync_result.dart';
import '../../domain/entities/user.dart' as app_user;
import '../../domain/repositories/syncable_repository.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/hybrid_repositories_provider.dart';
import 'connectivity_detector.dart';
import 'error_context_tracker.dart';
// Imports de repositorios específicos removidos - se usan a través de providers

/// Servicio de sincronización mejorado entre datos locales y Supabase
class SyncService {
  SyncService({
    required List<SyncableRepository<dynamic>> repositories,
    required this.getCurrentUser,
    required this.getConnectivityStatus,
  }) : _repositories = repositories;

  final List<SyncableRepository<dynamic>> _repositories;
  final app_user.User? Function() getCurrentUser;
  final ConnectivityStatus Function() getConnectivityStatus;
  Timer? _syncTimer;
  Timer? _retryTimer;
  final List<String> _syncErrors = [];
  final Map<String, int> _retryAttempts = {};

  // Configuración de reintentos
  static const int _maxRetryAttempts = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 30);
  static const Duration _syncInterval = Duration(minutes: 5);

  /// Sincronización automática después del login
  Future<void> onUserAuthenticated() async {
    LoggerFactory.info(
        'Usuario autenticado - iniciando sincronización automática');

    final user = getCurrentUser();
    if (user != null) {
      LoggerFactory.info(
          '🔄 Iniciando sincronización para usuario: ${user.email}');
    } else {
      LoggerFactory.warning('❌ No hay usuario autenticado disponible');
      return;
    }

    // Inicializar sincronización periódica inmediatamente
    _startPeriodicSync();

    // Ejecutar primera sincronización en background sin esperar
    LoggerFactory.info(
        '📤 Programando sincronización inicial en background...');

    // Fire and forget - no bloquear el hilo principal
    Future.microtask(() async {
      try {
        final result = await syncAllData();
        LoggerFactory.info(
            '✅ Sincronización inicial completada: ${result.success ? 'exitosa' : 'con errores'}');
      } catch (e) {
        LoggerFactory.error('❌ Error en sincronización inicial: $e');
        _scheduleRetry('onUserAuthenticated');
      }
    });

    LoggerFactory.info(
        '✅ Sincronización configurada (continuará en background)');
  }

  /// Sincronización completa de todos los repositorios
  Future<SyncResult> syncAllData() async {
    if (!_isAuthenticated()) {
      return SyncResult.failure(
        itemsProcessed: 0,
        errors: ['Usuario no autenticado'],
        duration: Duration.zero,
      );
    }

    if (!await _isOnline()) {
      return SyncResult.failure(
        itemsProcessed: 0,
        errors: ['Sin conexión a internet'],
        duration: Duration.zero,
      );
    }

    final startTime = DateTime.now();
    final results = <String, bool>{};
    final errors = <String>[];

    LoggerFactory.info(
        'Iniciando sincronización completa de ${_repositories.length} repositorios');

    // Sincronizar todos los repositorios en paralelo para mejor rendimiento
    final syncTasks = _repositories.map((repo) async {
      final repoName = repo.runtimeType.toString();

      try {
        LoggerFactory.info('Sincronizando $repoName...');
        await repo.syncWithSupabase();
        results[repoName] = true;

        // Resetear contador de reintentos en caso de éxito
        _retryAttempts.remove(repoName);

        LoggerFactory.info('$repoName sincronizado exitosamente');
      } catch (e) {
        results[repoName] = false;
        final error = 'Error en $repoName: $e';
        errors.add(error);

        LoggerFactory.error(error);
        _logSyncError(repoName, e, operation: 'syncAllData');
        _scheduleRetry(repoName);
      }
    });

    await Future.wait(syncTasks);

    final duration = DateTime.now().difference(startTime);
    final hasErrors = errors.isNotEmpty;
    final result = hasErrors
        ? SyncResult.failure(
            itemsProcessed: _repositories.length,
            errors: errors,
            duration: duration,
          )
        : SyncResult.success(
            itemsProcessed: _repositories.length,
            duration: duration,
            message: 'Todos los repositorios sincronizados exitosamente',
          );

    LoggerFactory.info('Sincronización completada: $result');
    return result;
  }

  /// Sincroniza solo los favoritos
  Future<SyncResult> syncFavorites() async {
    if (!_isAuthenticated() || !await _isOnline()) {
      LoggerFactory.info(
          '⏸️ Sincronización de favoritos omitida: usuario no autenticado o sin conexión');
      return SyncResult.failure(
        itemsProcessed: 0,
        errors: ['Usuario no autenticado o sin conexión'],
        duration: Duration.zero,
      );
    }

    final startTime = DateTime.now();
    final favoritesRepo = _repositories.firstWhere(
      (repo) => repo.runtimeType.toString().contains('Favorites'),
      orElse: () => throw Exception('Repositorio de favoritos no encontrado'),
    );

    try {
      LoggerFactory.info('🔄 Sincronizando favoritos...');
      await favoritesRepo.syncWithSupabase();
      LoggerFactory.info('✅ Favoritos sincronizados');

      return SyncResult.success(
        itemsProcessed: 1,
        duration: DateTime.now().difference(startTime),
        message: 'Favoritos sincronizados exitosamente',
      );
    } catch (e) {
      _logSyncError('HybridFavoritesRepository', e, operation: 'syncFavorites');
      return SyncResult.failure(
        itemsProcessed: 1,
        errors: ['Error sincronizando favoritos: $e'],
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  /// Sincroniza solo las películas vistas
  Future<SyncResult> syncWatchedMovies() async {
    if (!_isAuthenticated() || !await _isOnline()) {
      LoggerFactory.info(
          '⏸️ Sincronización de películas vistas omitida: usuario no autenticado o sin conexión');
      return SyncResult.failure(
        itemsProcessed: 0,
        errors: ['Usuario no autenticado o sin conexión'],
        duration: Duration.zero,
      );
    }

    final startTime = DateTime.now();
    final watchedRepo = _repositories.firstWhere(
      (repo) => repo.runtimeType.toString().contains('Watched'),
      orElse: () =>
          throw Exception('Repositorio de películas vistas no encontrado'),
    );

    try {
      LoggerFactory.info('🔄 Sincronizando películas vistas...');
      await watchedRepo.syncWithSupabase();
      LoggerFactory.info('✅ Películas vistas sincronizadas');

      return SyncResult.success(
        itemsProcessed: 1,
        duration: DateTime.now().difference(startTime),
        message: 'Películas vistas sincronizadas exitosamente',
      );
    } catch (e) {
      _logSyncError('HybridWatchedRepository', e,
          operation: 'syncWatchedMovies');
      return SyncResult.failure(
        itemsProcessed: 1,
        errors: ['Error sincronizando películas vistas: $e'],
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  /// Sincroniza solo las listas personalizadas
  Future<SyncResult> syncCustomLists() async {
    if (!_isAuthenticated() || !await _isOnline()) {
      LoggerFactory.info(
          '⏸️ Sincronización de listas personalizadas omitida: usuario no autenticado o sin conexión');
      return SyncResult.failure(
        itemsProcessed: 0,
        errors: ['Usuario no autenticado o sin conexión'],
        duration: Duration.zero,
      );
    }

    final startTime = DateTime.now();
    final customListsRepo = _repositories.firstWhere(
      (repo) => repo.runtimeType.toString().contains('CustomLists'),
      orElse: () =>
          throw Exception('Repositorio de listas personalizadas no encontrado'),
    );

    try {
      LoggerFactory.info('🔄 Sincronizando listas personalizadas...');
      await customListsRepo.syncWithSupabase();
      LoggerFactory.info('✅ Listas personalizadas sincronizadas');

      return SyncResult.success(
        itemsProcessed: 1,
        duration: DateTime.now().difference(startTime),
        message: 'Listas personalizadas sincronizadas exitosamente',
      );
    } catch (e) {
      _logSyncError('HybridCustomListsRepository', e,
          operation: 'syncCustomLists');
      return SyncResult.failure(
        itemsProcessed: 1,
        errors: ['Error sincronizando listas personalizadas: $e'],
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  /// Inicia la sincronización periódica
  void _startPeriodicSync() {
    _stopPeriodicSync(); // Detener cualquier timer existente

    LoggerFactory.info(
        'Iniciando sincronización periódica cada ${_syncInterval.inMinutes} minutos');

    _syncTimer = Timer.periodic(_syncInterval, (_) async {
      if (await _isOnline() && _isAuthenticated()) {
        LoggerFactory.info('Ejecutando sincronización periódica');
        syncAllData().catchError((e) {
          LoggerFactory.error('Error en sincronización periódica: $e');
          return SyncResult.failure(
            itemsProcessed: _repositories.length,
            errors: ['Error en sincronización periódica: $e'],
            duration: Duration.zero,
          );
        });
      }
    });
  }

  /// Detiene la sincronización periódica
  void _stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Programa un reintento con backoff exponencial
  void _scheduleRetry(String operation) {
    final attempts = _retryAttempts[operation] ?? 0;

    if (attempts >= _maxRetryAttempts) {
      LoggerFactory.warning('Máximo de reintentos alcanzado para $operation');
      return;
    }

    _retryAttempts[operation] = attempts + 1;

    // Backoff exponencial: 30s, 60s, 120s
    final delay = Duration(
      seconds: _baseRetryDelay.inSeconds * (1 << attempts),
    );

    LoggerFactory.info(
        'Programando reintento #${attempts + 1} para $operation en ${delay.inSeconds}s');

    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () async {
      if (_isAuthenticated()) {
        final isOnline = await _isOnline();
        if (isOnline) {
          LoggerFactory.info(
              'Ejecutando reintento #${attempts + 1} para $operation');
          syncAllData().catchError((e) {
            LoggerFactory.error('Error en reintento de $operation: $e');
            return SyncResult.failure(
              itemsProcessed: _repositories.length,
              errors: ['Error en reintento de $operation: $e'],
              duration: Duration.zero,
            );
          });
        }
      }
    });
  }

  /// Detiene todos los timers y limpia recursos
  void dispose() {
    _stopPeriodicSync();
    _retryTimer?.cancel();
    _retryTimer = null;
    _syncErrors.clear();
    _retryAttempts.clear();

    // Limpiar errores antiguos antes de cerrar
    ErrorContextTracker.instance.cleanupOldErrors();

    LoggerFactory.info('SyncService disposed');
  }

  /// Programa limpieza periódica de errores antiguos
  void _scheduleErrorCleanup() {
    Timer.periodic(const Duration(hours: 6), (timer) {
      ErrorContextTracker.instance.cleanupOldErrors();
    });
  }

  // Variables para tracking de estado
  DateTime? _lastSyncTime;
  final bool _isSyncing = false;
  bool _isInitialized = false;
  ConnectivityDetector? _connectivityService;

  /// Inicializa el servicio de sincronización
  Future<void> initialize() async {
    if (_isInitialized) {
      LoggerFactory.info('SyncService already initialized');
      return;
    }

    try {
      LoggerFactory.info('🔄 Initializing SyncService...');

      // Inicializar el tracker de contexto de errores
      await ErrorContextTracker.instance.initialize();

      // Inicializar conectividad
      _connectivityService = ConnectivityDetector.instance;
      await _connectivityService!.initialize();

      // Configurar listeners de conectividad
      _connectivityService!.onConnectivityChanged.listen((status) {
        final isConnected = status == ConnectivityStatus.online;
        if (isConnected && !_isSyncing) {
          LoggerFactory.info('📶 Connectivity restored, triggering sync');
          syncAllData();
        }
      });

      // Programar limpieza periódica de errores
      _scheduleErrorCleanup();

      _isInitialized = true;
      LoggerFactory.info('✅ SyncService initialized successfully');
    } catch (e) {
      LoggerFactory.error('❌ Failed to initialize SyncService: $e');
      rethrow;
    }
  }

  /// Sincronización manual forzada
  Future<SyncResult> forceSyncAllData() async {
    LoggerFactory.info('Forzando sincronización manual');

    // Limpiar errores y reintentos previos
    _syncErrors.clear();
    _retryAttempts.clear();

    return await syncAllData();
  }

  /// Obtiene el estado actual de sincronización
  Map<String, dynamic> getSyncStatus() {
    return {
      'is_periodic_sync_active': _syncTimer?.isActive ?? false,
      'retry_attempts': Map.from(_retryAttempts),
      'recent_errors': List.from(_syncErrors.take(10)),
      'repositories_count': _repositories.length,
    };
  }

  /// Obtiene estadísticas detalladas de errores y diagnósticos
  Map<String, dynamic> getErrorDiagnostics() {
    final errorStats = ErrorContextTracker.instance.getErrorStatistics();

    return {
      'sync_service_status': getSyncStatus(),
      'error_statistics': errorStats,
      'recent_error_patterns': errorStats['most_frequent_patterns'],
      'error_tracking_health': {
        'total_tracked_errors': errorStats['total_errors'],
        'errors_last_hour': errorStats['errors_last_hour'],
        'unique_error_patterns': errorStats['unique_patterns'],
      },
      'sync_performance': {
        'average_sync_duration': _calculateAverageSyncDuration(),
        'success_rate': _calculateSyncSuccessRate(),
        'last_successful_sync': _lastSyncTime?.toIso8601String(),
        'pending_retries': _retryAttempts.length,
      },
    };
  }

  /// Calcula la duración promedio de sincronización
  double _calculateAverageSyncDuration() {
    // Implementación simplificada - en una implementación real
    // se mantendría un historial de duraciones
    return 2.5; // segundos promedio
  }

  /// Calcula la tasa de éxito de sincronización
  double _calculateSyncSuccessRate() {
    if (_repositories.isEmpty) return 0.0;
    final errorCount = _syncErrors.length;
    final totalSyncs = _repositories.length;
    return (((totalSyncs - errorCount) / totalSyncs) * 100).clamp(0.0, 100.0);
  }

  /// Exporta diagnósticos completos como JSON
  String exportDiagnostics() {
    getErrorDiagnostics();
    return ErrorContextTracker.instance.exportErrorStatistics();
  }

  /// Obtiene información detallada del estado de sincronización
  Map<String, dynamic> getDetailedSyncStatus() {
    return {
      'current_state': _syncTimer?.isActive ?? false ? 'active' : 'inactive',
      'is_syncing': _syncTimer?.isActive ?? false,
      'is_authenticated': _isAuthenticated(),
      'last_sync': DateTime.now().toIso8601String(),
      'periodic_sync_active': _syncTimer?.isActive ?? false,
      'retry_count': _retryAttempts.values.fold(0, (sum, count) => sum + count),
      'repositories_count': _repositories.length,
    };
  }

  /// Obtiene estadísticas de sincronización
  Map<String, dynamic> getSyncStatistics() {
    final totalAttempts =
        _retryAttempts.values.fold(0, (sum, count) => sum + count);
    final successfulRepos = _repositories.length - _retryAttempts.length;
    return {
      'total_syncs': totalAttempts + successfulRepos,
      'successful_syncs': successfulRepos,
      'failed_syncs': _retryAttempts.length,
      'success_rate': _repositories.isNotEmpty
          ? (successfulRepos / _repositories.length * 100).toStringAsFixed(1)
          : '0.0',
    };
  }

  /// Verifica si necesita sincronización
  bool needsSync() {
    if (!_isAuthenticated()) {
      return false;
    }

    // Si hay errores de sincronización pendientes
    if (_retryAttempts.isNotEmpty) {
      return true;
    }

    // Si la sincronización periódica no está activa
    return !(_syncTimer?.isActive ?? false);
  }

  /// Reinicia las estadísticas de sincronización
  void resetSyncStatistics() {
    _syncErrors.clear();
    _retryAttempts.clear();
    LoggerFactory.info('📊 Estadísticas de sincronización reiniciadas');
  }

  // Métodos auxiliares privados

  /// Verifica si el usuario está autenticado
  bool _isAuthenticated() {
    final user = getCurrentUser();
    return user != null;
  }

  /// Verifica conectividad a internet
  Future<bool> _isOnline() async {
    try {
      // En Web, usar una verificación diferente porque connectivity_plus
      // puede no funcionar correctamente en todos los navegadores
      if (kIsWeb) {
        // Verificación simplificada para Web usando ping a Supabase
        try {
          final supabase = Supabase.instance.client;
          await supabase.from('user_favorites').select('id').limit(1);
          return true; // Si no lanza excepción, hay conexión
        } catch (e) {
          // Si falla la verificación, asumir sin conexión
          LoggerFactory.warning('Verificación de conectividad Web falló: $e');
          return false;
        }
      }

      final connectivityResults = await Connectivity().checkConnectivity();
      return !connectivityResults.contains(ConnectivityResult.none);
    } catch (e) {
      LoggerFactory.error('Error verificando conectividad: $e');
      // En caso de error, asumir que hay conexión para no bloquear funcionalidad
      return true;
    }
  }

  /// Registra errores de sincronización con información detallada y estructurada
  void _logSyncError(String repository, dynamic error,
      {String? operation, String? correlationId}) {
    final timestamp = DateTime.now();
    final retryCount = _retryAttempts[repository] ?? 0;
    final errorType = _categorizeError(error);
    final severity = _getErrorSeverity(errorType);
    const platform = kIsWeb ? 'Web' : 'Native';

    // Contexto adicional para el tracker
    final additionalContext = {
      'repository': repository,
      'retry_count': retryCount,
      'platform': platform,
      'is_authenticated': _isAuthenticated(),
      'connectivity_status': getConnectivityStatus().toString(),
      'error_type': errorType,
      'severity': severity,
      'recovery_suggestion': _getRecoverySuggestion(errorType),
    };

    // Registrar en el tracker de contexto de errores
    final trackingCorrelationId = ErrorContextTracker.instance.trackError(
      errorType: 'sync_error',
      errorMessage: error.toString(),
      operation: operation ?? 'sync',
      additionalContext: additionalContext,
    );

    final corrId = correlationId ?? trackingCorrelationId;

    final structuredMessage =
        'SYNC_ERROR: $errorType in $repository [$corrId] - ${error.toString()}';
    _syncErrors.add(structuredMessage);

    // Mantener solo los últimos 50 errores
    if (_syncErrors.length > 50) {
      _syncErrors.removeAt(0);
    }

    // Logging estructurado con contexto completo
    final logMessage = '🔄 [$severity] $structuredMessage\n'
        '   📊 Context: retry=$retryCount, platform=$platform, auth=${_isAuthenticated()}\n'
        '   💡 Suggestion: ${additionalContext['recovery_suggestion']}';

    if (severity == 'CRITICAL' || severity == 'HIGH') {
      LoggerFactory.error(logMessage);
    } else {
      LoggerFactory.warning(logMessage);
    }

    // Log detallado para debugging using safe logging
    final errorDetails = {
      'correlation_id': corrId,
      'error_type': errorType,
      'severity': severity,
      'operation': operation ?? 'sync',
      'timestamp': timestamp.toIso8601String(),
      ...additionalContext,
    };
    SafeDeveloperLog.log(
      'Sync Error Details',
      name: 'SyncService',
      error: errorDetails,
    );

    // Registrar patrones de error para análisis
    _trackErrorPattern(repository, errorType, timestamp);
  }

  /// Categoriza el tipo de error para mejor diagnóstico
  String _categorizeError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('timeout') ||
        errorStr.contains('unreachable')) {
      return 'NETWORK_ERROR';
    }

    if (errorStr.contains('auth') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('forbidden') ||
        errorStr.contains('token')) {
      return 'AUTH_ERROR';
    }

    if (errorStr.contains('constraint') ||
        errorStr.contains('duplicate') ||
        errorStr.contains('foreign key') ||
        errorStr.contains('unique')) {
      return 'DATA_INTEGRITY_ERROR';
    }

    if (errorStr.contains('json') ||
        errorStr.contains('parse') ||
        errorStr.contains('format') ||
        errorStr.contains('decode')) {
      return 'DATA_FORMAT_ERROR';
    }

    if (errorStr.contains('permission') || errorStr.contains('access denied')) {
      return 'PERMISSION_ERROR';
    }

    if (errorStr.contains('conflict') || errorStr.contains('version')) {
      return 'CONFLICT_ERROR';
    }

    return 'UNKNOWN_ERROR';
  }

  /// Determina la severidad del error
  String _getErrorSeverity(String errorType) {
    switch (errorType) {
      case 'AUTH_ERROR':
      case 'PERMISSION_ERROR':
        return 'CRITICAL';
      case 'DATA_INTEGRITY_ERROR':
      case 'CONFLICT_ERROR':
        return 'HIGH';
      case 'NETWORK_ERROR':
      case 'DATA_FORMAT_ERROR':
        return 'MEDIUM';
      default:
        return 'LOW';
    }
  }

  /// Proporciona sugerencias de recuperación basadas en el tipo de error
  String _getRecoverySuggestion(String errorType) {
    switch (errorType) {
      case 'NETWORK_ERROR':
        return 'Verificar conexión a internet y reintentar';
      case 'AUTH_ERROR':
        return 'Verificar autenticación del usuario y renovar tokens';
      case 'PERMISSION_ERROR':
        return 'Verificar permisos de usuario en Supabase';
      case 'DATA_INTEGRITY_ERROR':
        return 'Revisar integridad de datos y resolver conflictos';
      case 'DATA_FORMAT_ERROR':
        return 'Verificar formato de datos y esquemas';
      case 'CONFLICT_ERROR':
        return 'Resolver conflictos de versión de datos';
      default:
        return 'Revisar logs detallados y contactar soporte técnico';
    }
  }

  /// Rastrea patrones de error para análisis
  void _trackErrorPattern(
      String repository, String errorType, DateTime timestamp) {
    // Implementación básica - podría expandirse con almacenamiento persistente
    final pattern = '${repository}_$errorType';
    LoggerFactory.info(
        '📈 Error pattern tracked: $pattern at ${timestamp.toIso8601String()}');
  }
}

// Provider para el servicio de sincronización
final syncServiceProvider = Provider<SyncService>((ref) {
  final repositories = <SyncableRepository<dynamic>>[
    ref.watch(hybridFavoritesRepositoryProvider),
    ref.watch(hybridWatchedRepositoryProvider),
    ref.watch(hybridWatchlistRepositoryProvider),
    ref.watch(hybridCustomListsRepositoryProvider),
  ];

  return SyncService(
    repositories: repositories,
    getCurrentUser: () => ref.read(currentUserProvider),
    getConnectivityStatus: () {
      // Return default online status - can be enhanced with connectivity provider
      return ConnectivityStatus.online;
    },
  );
});

// Provider para el estado de sincronización
final syncStateProvider =
    StateNotifierProvider<SyncStateNotifier, AsyncValue<SyncResult?>>((ref) {
  return SyncStateNotifier(ref);
});

// Notifier para manejar el estado de sincronización
class SyncStateNotifier extends StateNotifier<AsyncValue<SyncResult?>> {
  SyncStateNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  /// Ejecutar sincronización completa
  Future<void> syncAll() async {
    state = const AsyncValue.loading();

    try {
      final syncService = _ref.read(syncServiceProvider);
      final result = await syncService.syncAllData();

      state = AsyncValue.data(result);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Ejecutar sincronización forzada
  Future<void> forceSyncAll() async {
    state = const AsyncValue.loading();

    try {
      final syncService = _ref.read(syncServiceProvider);
      final result = await syncService.forceSyncAllData();

      state = AsyncValue.data(result);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Obtener estado de sincronización
  Map<String, dynamic> getSyncStatus() {
    final syncService = _ref.read(syncServiceProvider);
    return syncService.getSyncStatus();
  }

  /// Limpiar estado de sincronización
  void clearState() {
    state = const AsyncValue.data(null);
  }
}
