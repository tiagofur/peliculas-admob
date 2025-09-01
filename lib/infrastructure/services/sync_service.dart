import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/entities/sync_result.dart';
import '../../domain/repositories/syncable_repository.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/hybrid_repositories_provider.dart';
// Imports de repositorios específicos removidos - se usan a través de providers

/// Servicio de sincronización mejorado entre datos locales y Supabase
class SyncService {
  SyncService({
    required List<SyncableRepository<dynamic>> repositories,
    required this.getCurrentUser,
    required this.getConnectivityStatus,
  }) : _repositories = repositories;
  
  final List<SyncableRepository<dynamic>> _repositories;
  final User? Function() getCurrentUser;
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

    try {
      LoggerFactory.info('📤 Ejecutando sincronización completa...');
      final result = await syncAllData();
      LoggerFactory.info(
          '✅ Sincronización completada: ${result.repositoryResults}');

      _startPeriodicSync();
    } catch (e) {
      LoggerFactory.error('❌ Error en sincronización post-login: $e');
      _scheduleRetry('onUserAuthenticated');
    }
  }

  /// Sincronización completa de todos los repositorios
  Future<SyncResult> syncAllData() async {
    if (!_isAuthenticated()) {
      return SyncResult(
        repositoryResults: {
          for (var item in _repositories.map((r) => r.runtimeType.toString()))
            item: false
        },
        timestamp: DateTime.now(),
        duration: Duration.zero,
        errors: ['Usuario no autenticado'],
      );
    }

    if (!await _isOnline()) {
      return SyncResult(
        repositoryResults: {
          for (var item in _repositories.map((r) => r.runtimeType.toString()))
            item: false
        },
        timestamp: DateTime.now(),
        duration: Duration.zero,
        errors: ['Sin conexión a internet'],
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
        _logSyncError(repoName, e);
        _scheduleRetry(repoName);
      }
    });

    await Future.wait(syncTasks);

    final duration = DateTime.now().difference(startTime);
    final result = SyncResult(
      repositoryResults: results,
      timestamp: startTime,
      duration: duration,
      errors: errors,
    );

    LoggerFactory.info('Sincronización completada: $result');
    return result;
  }

  /// Sincroniza solo los favoritos
  Future<SyncResult> syncFavorites() async {
    if (!_isAuthenticated() || !await _isOnline()) {
      LoggerFactory.info('⏸️ Sincronización de favoritos omitida: usuario no autenticado o sin conexión');
      return SyncResult(
        repositoryResults: {'HybridFavoritesRepository': false},
        timestamp: DateTime.now(),
        duration: Duration.zero,
        errors: ['Usuario no autenticado o sin conexión'],
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
      
      return SyncResult(
        repositoryResults: {'HybridFavoritesRepository': true},
        timestamp: startTime,
        duration: DateTime.now().difference(startTime),
        errors: [],
      );
    } catch (e) {
      _logSyncError('HybridFavoritesRepository', e);
      return SyncResult(
        repositoryResults: {'HybridFavoritesRepository': false},
        timestamp: startTime,
        duration: DateTime.now().difference(startTime),
        errors: ['Error sincronizando favoritos: $e'],
      );
    }
  }

  /// Sincroniza solo las películas vistas
  Future<SyncResult> syncWatchedMovies() async {
    if (!_isAuthenticated() || !await _isOnline()) {
      LoggerFactory.info('⏸️ Sincronización de películas vistas omitida: usuario no autenticado o sin conexión');
      return SyncResult(
        repositoryResults: {'HybridWatchedRepository': false},
        timestamp: DateTime.now(),
        duration: Duration.zero,
        errors: ['Usuario no autenticado o sin conexión'],
      );
    }

    final startTime = DateTime.now();
    final watchedRepo = _repositories.firstWhere(
      (repo) => repo.runtimeType.toString().contains('Watched'),
      orElse: () => throw Exception('Repositorio de películas vistas no encontrado'),
    );

    try {
      LoggerFactory.info('🔄 Sincronizando películas vistas...');
      await watchedRepo.syncWithSupabase();
      LoggerFactory.info('✅ Películas vistas sincronizadas');
      
      return SyncResult(
        repositoryResults: {'HybridWatchedRepository': true},
        timestamp: startTime,
        duration: DateTime.now().difference(startTime),
        errors: [],
      );
    } catch (e) {
      _logSyncError('HybridWatchedRepository', e);
      return SyncResult(
        repositoryResults: {'HybridWatchedRepository': false},
        timestamp: startTime,
        duration: DateTime.now().difference(startTime),
        errors: ['Error sincronizando películas vistas: $e'],
      );
    }
  }

  /// Sincroniza solo las listas personalizadas
  Future<SyncResult> syncCustomLists() async {
    if (!_isAuthenticated() || !await _isOnline()) {
      LoggerFactory.info('⏸️ Sincronización de listas personalizadas omitida: usuario no autenticado o sin conexión');
      return SyncResult(
        repositoryResults: {'HybridCustomListsRepository': false},
        timestamp: DateTime.now(),
        duration: Duration.zero,
        errors: ['Usuario no autenticado o sin conexión'],
      );
    }

    final startTime = DateTime.now();
    final customListsRepo = _repositories.firstWhere(
      (repo) => repo.runtimeType.toString().contains('CustomLists'),
      orElse: () => throw Exception('Repositorio de listas personalizadas no encontrado'),
    );

    try {
      LoggerFactory.info('🔄 Sincronizando listas personalizadas...');
      await customListsRepo.syncWithSupabase();
      LoggerFactory.info('✅ Listas personalizadas sincronizadas');
      
      return SyncResult(
        repositoryResults: {'HybridCustomListsRepository': true},
        timestamp: startTime,
        duration: DateTime.now().difference(startTime),
        errors: [],
      );
    } catch (e) {
      _logSyncError('HybridCustomListsRepository', e);
      return SyncResult(
        repositoryResults: {'HybridCustomListsRepository': false},
        timestamp: startTime,
        duration: DateTime.now().difference(startTime),
        errors: ['Error sincronizando listas personalizadas: $e'],
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
          return SyncResult(
            repositoryResults: {
              for (var item
                  in _repositories.map((r) => r.runtimeType.toString()))
                item: false
            },
            timestamp: DateTime.now(),
            duration: Duration.zero,
            errors: ['Error en sincronización periódica: $e'],
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
            return SyncResult(
              repositoryResults: {
                for (var item
                    in _repositories.map((r) => r.runtimeType.toString()))
                  item: false
              },
              timestamp: DateTime.now(),
              duration: Duration.zero,
              errors: ['Error en reintento de $operation: $e'],
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

    LoggerFactory.info('SyncService disposed');
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
    final totalAttempts = _retryAttempts.values.fold(0, (sum, count) => sum + count);
    final successfulRepos = _repositories.length - _retryAttempts.length;
    return {
      'total_syncs': totalAttempts + successfulRepos,
      'successful_syncs': successfulRepos,
      'failed_syncs': _retryAttempts.length,
      'success_rate': _repositories.isNotEmpty ? (successfulRepos / _repositories.length * 100).toStringAsFixed(1) : '0.0',
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
        // Para Web, asumir que hay conexión a menos que se pueda verificar lo contrario
        // TODO: Implementar una verificación más robusta para Web si es necesario
        return true;
      }

      final connectivityResults = await Connectivity().checkConnectivity();
      return !connectivityResults.contains(ConnectivityResult.none);
    } catch (e) {
      LoggerFactory.error('Error verificando conectividad: $e');
      // En caso de error, asumir que hay conexión para no bloquear funcionalidad
      return true;
    }
  }

  /// Registra errores de sincronización
  void _logSyncError(String repository, dynamic error) {
    final errorMessage = '$repository: $error';
    _syncErrors.add(errorMessage);

    // Mantener solo los últimos 50 errores
    if (_syncErrors.length > 50) {
      _syncErrors.removeAt(0);
    }

    // Logging diferenciado para Web y plataformas nativas
    if (kIsWeb) {
      // En Web, usar LoggerFactory para mejor consistencia
      if (kDebugMode) {
        LoggerFactory.error('🔄 Error de sincronización (Web): $errorMessage');
      }
    } else {
      LoggerFactory.error('Error de sincronización registrado: $errorMessage');
    }
  }
}

// Provider para el servicio de sincronización
final syncServiceProvider = Provider<SyncService>((ref) {
  final repositories = <SyncableRepository<dynamic>>[
    ref.watch(hybridFavoritesRepositoryProvider),
    ref.watch(hybridWatchedRepositoryProvider),
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
