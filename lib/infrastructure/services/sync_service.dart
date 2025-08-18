import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../domain/entities/sync_result.dart';
import '../../domain/repositories/syncable_repository.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/hybrid_repositories_provider.dart';
// Imports de repositorios específicos removidos - se usan a través de providers

/// Servicio de sincronización mejorado entre datos locales y Supabase
class SyncService {
  final List<SyncableRepository<dynamic>> _repositories;
  final Ref _ref;
  Timer? _syncTimer;
  Timer? _retryTimer;
  final List<String> _syncErrors = [];
  final Map<String, int> _retryAttempts = {};
  
  // Configuración de reintentos
  static const int _maxRetryAttempts = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 30);
  static const Duration _syncInterval = Duration(minutes: 5);
  
  SyncService({
    required List<SyncableRepository<dynamic>> repositories,
    required Ref ref,
  }) : _repositories = repositories,
       _ref = ref;

  /// Sincronización automática después del login
  Future<void> onUserAuthenticated() async {
    developer.log('Usuario autenticado - iniciando sincronización automática');
    
    try {
      await syncAllData();
      _startPeriodicSync();
    } catch (e) {
      developer.log('Error en sincronización post-login: $e');
      _scheduleRetry('onUserAuthenticated');
    }
  }
  
  /// Sincronización completa de todos los repositorios
  Future<SyncResult> syncAllData() async {
    if (!_isAuthenticated()) {
      return SyncResult(
        repositoryResults: Map.fromIterable(
          _repositories.map((r) => r.runtimeType.toString()),
          key: (item) => item,
          value: (item) => false,
        ),
        timestamp: DateTime.now(),
        duration: Duration.zero,
        errors: ['Usuario no autenticado'],
      );
    }
    
    if (!await _isOnline()) {
      return SyncResult(
        repositoryResults: Map.fromIterable(
          _repositories.map((r) => r.runtimeType.toString()),
          key: (item) => item,
          value: (item) => false,
        ),
        timestamp: DateTime.now(),
        duration: Duration.zero,
        errors: ['Sin conexión a internet'],
      );
    }
    
    final startTime = DateTime.now();
    final results = <String, bool>{};
    final errors = <String>[];
    
    developer.log('Iniciando sincronización completa de ${_repositories.length} repositorios');
    
    for (final repo in _repositories) {
      final repoName = repo.runtimeType.toString();
      
      try {
        developer.log('Sincronizando $repoName...');
        await repo.syncWithSupabase();
        results[repoName] = true;
        
        // Resetear contador de reintentos en caso de éxito
        _retryAttempts.remove(repoName);
        
        developer.log('$repoName sincronizado exitosamente');
      } catch (e) {
        results[repoName] = false;
        final error = 'Error en $repoName: $e';
        errors.add(error);
        
        developer.log(error);
        _logSyncError(repoName, e);
        _scheduleRetry(repoName);
      }
    }
    
    final duration = DateTime.now().difference(startTime);
    final result = SyncResult(
      repositoryResults: results,
      timestamp: startTime,
      duration: duration,
      errors: errors,
    );
    
    developer.log('Sincronización completada: $result');
    return result;
  }

  /// Inicia la sincronización periódica
  void _startPeriodicSync() {
    _stopPeriodicSync(); // Detener cualquier timer existente
    
    developer.log('Iniciando sincronización periódica cada ${_syncInterval.inMinutes} minutos');
    
    _syncTimer = Timer.periodic(_syncInterval, (_) async {
      if (await _isOnline() && _isAuthenticated()) {
        developer.log('Ejecutando sincronización periódica');
        syncAllData().catchError((e) {
          developer.log('Error en sincronización periódica: $e');
          return SyncResult(
            repositoryResults: Map.fromIterable(
              _repositories.map((r) => r.runtimeType.toString()),
              key: (item) => item,
              value: (item) => false,
            ),
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
      developer.log('Máximo de reintentos alcanzado para $operation');
      return;
    }
    
    _retryAttempts[operation] = attempts + 1;
    
    // Backoff exponencial: 30s, 60s, 120s
    final delay = Duration(
      seconds: _baseRetryDelay.inSeconds * (1 << attempts),
    );
    
    developer.log('Programando reintento #${attempts + 1} para $operation en ${delay.inSeconds}s');
    
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () async {
      if (_isAuthenticated()) {
        final isOnline = await _isOnline();
        if (isOnline) {
            developer.log('Ejecutando reintento #${attempts + 1} para $operation');
            syncAllData().catchError((e) {
              developer.log('Error en reintento de $operation: $e');
              return SyncResult(
                repositoryResults: Map.fromIterable(
                  _repositories.map((r) => r.runtimeType.toString()),
                  key: (item) => item,
                  value: (item) => false,
                ),
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
    
    developer.log('SyncService disposed');
  }
  
  /// Sincronización manual forzada
  Future<SyncResult> forceSyncAllData() async {
    developer.log('Forzando sincronización manual');
    
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
  
  // Métodos auxiliares privados
  
  /// Verifica si el usuario está autenticado
  bool _isAuthenticated() {
    final appState = _ref.read(appStateProvider);
    return appState.isAuthenticated;
  }
  
  /// Verifica conectividad a internet
  Future<bool> _isOnline() async {
    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      return !connectivityResults.contains(ConnectivityResult.none);
    } catch (e) {
      developer.log('Error verificando conectividad: $e');
      return false;
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
    
    developer.log('Error de sincronización registrado: $errorMessage');
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
    ref: ref,
  );
});

// Provider para el estado de sincronización
final syncStateProvider = StateNotifierProvider<SyncStateNotifier, AsyncValue<SyncResult?>>((ref) {
  return SyncStateNotifier(ref);
});

// Notifier para manejar el estado de sincronización
class SyncStateNotifier extends StateNotifier<AsyncValue<SyncResult?>> {
  final Ref _ref;
  
  SyncStateNotifier(this._ref) : super(const AsyncValue.data(null));
  
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