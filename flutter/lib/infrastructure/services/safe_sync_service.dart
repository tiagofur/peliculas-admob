import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/entities/sync_result.dart';
import 'sync_service.dart';

enum SyncState {
  idle,
  syncing,
  failed,
  circuitOpen, // Circuit breaker is open - too many failures
}

/// Servicio seguro de sincronización que implementa circuit breaker
/// para evitar bloqueos y cascadas de errores
class SafeSyncService {
  SafeSyncService(this._syncService);

  final SyncService _syncService;

  // Circuit breaker state
  SyncState _state = SyncState.idle;
  int _consecutiveFailures = 0;
  DateTime? _lastFailureTime;

  // Configuration
  static const int _maxFailures = 3;
  static const Duration _circuitOpenDuration = Duration(minutes: 5);
  static const Duration _maxSyncDuration = Duration(seconds: 45);

  /// Get current sync state
  SyncState get state => _state;

  /// Check if sync is currently running
  bool get isSyncing => _state == SyncState.syncing;

  /// Check if circuit breaker is open
  bool get isCircuitOpen => _state == SyncState.circuitOpen;

  /// Attempt to sync with circuit breaker protection
  Future<SyncResult> attemptSync() async {
    // Check if we can attempt sync
    if (!_canAttemptSync()) {
      final reason = _state == SyncState.syncing
          ? 'Ya hay una sincronización en progreso'
          : 'Circuit breaker abierto - demasiados fallos recientes';

      LoggerFactory.warning('🚫 Sync bloqueado: $reason');
      return _createFailureResult(reason);
    }

    _state = SyncState.syncing;
    LoggerFactory.info('🔄 Iniciando sincronización segura...');

    try {
      // Execute sync with strict timeout and isolation
      final result = await _executeWithIsolation();

      // Success - reset circuit breaker
      _resetCircuitBreaker();
      _state = SyncState.idle;

      LoggerFactory.info('✅ Sincronización segura completada exitosamente');
      return result;
    } catch (e) {
      _handleSyncFailure(e);
      _state = SyncState.failed;

      LoggerFactory.error('❌ Sincronización falló: $e');
      return _createFailureResult('Sync falló: $e');
    }
  }

  /// Execute sync in isolation with timeout
  Future<SyncResult> _executeWithIsolation() async {
    final completer = Completer<SyncResult>();

    // Create a timeout that will kill the sync if it hangs
    final timeoutTimer = Timer(_maxSyncDuration, () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException(
          'Sync timeout after ${_maxSyncDuration.inSeconds}s',
          _maxSyncDuration,
        ));
      }
    });

    try {
      // Execute sync with additional safeguards
      final syncFuture = _safeSyncExecution();

      syncFuture.then((result) {
        if (!completer.isCompleted) {
          timeoutTimer.cancel();
          completer.complete(result);
        }
      }).catchError((error) {
        if (!completer.isCompleted) {
          timeoutTimer.cancel();
          completer.completeError(error);
        }
      });

      return await completer.future;
    } catch (e) {
      timeoutTimer.cancel();
      rethrow;
    }
  }

  /// Safe sync execution with additional protections
  Future<SyncResult> _safeSyncExecution() async {
    try {
      // Initialize sync service if needed
      await _syncService.initialize();

      // Execute the actual sync with timeout
      return await _syncService
          .syncAllData()
          .timeout(const Duration(seconds: 30), onTimeout: () {
        throw TimeoutException(
            'Sync operation timeout', const Duration(seconds: 30));
      });
    } catch (e) {
      LoggerFactory.error('💥 Error en ejecución segura de sync: $e');
      rethrow;
    }
  }

  /// Check if we can attempt a sync operation
  bool _canAttemptSync() {
    // Don't allow sync if already syncing
    if (_state == SyncState.syncing) {
      return false;
    }

    // Check circuit breaker
    if (_state == SyncState.circuitOpen) {
      // Check if enough time has passed to retry
      if (_lastFailureTime != null) {
        final timeSinceLastFailure =
            DateTime.now().difference(_lastFailureTime!);
        if (timeSinceLastFailure < _circuitOpenDuration) {
          return false; // Still in circuit breaker timeout
        } else {
          // Reset to try again
          _state = SyncState.idle;
          LoggerFactory.info(
              '🔄 Circuit breaker reset - intentando nuevamente');
        }
      }
    }

    return true;
  }

  /// Handle sync failure and update circuit breaker state
  void _handleSyncFailure(dynamic error) {
    _consecutiveFailures++;
    _lastFailureTime = DateTime.now();

    LoggerFactory.warning('⚠️ Sync failure #$_consecutiveFailures: $error');

    // Open circuit breaker if too many failures
    if (_consecutiveFailures >= _maxFailures) {
      _state = SyncState.circuitOpen;
      LoggerFactory.error(
          '🔥 Circuit breaker ABIERTO - demasiados fallos consecutivos');
      LoggerFactory.info(
          '⏱️ Reintentará automáticamente en ${_circuitOpenDuration.inMinutes} minutos');
    }
  }

  /// Reset circuit breaker after successful operation
  void _resetCircuitBreaker() {
    if (_consecutiveFailures > 0) {
      LoggerFactory.info(
          '✅ Circuit breaker reset - fallos consecutivos: $_consecutiveFailures -> 0');
    }
    _consecutiveFailures = 0;
    _lastFailureTime = null;
  }

  /// Create a failure result
  SyncResult _createFailureResult(String reason) {
    return SyncResult.failure(
      itemsProcessed: 0,
      errors: [reason],
      duration: Duration.zero,
      message: 'Sync failed: $reason',
    );
  }

  /// Get detailed sync status
  Map<String, dynamic> getDetailedStatus() {
    return {
      'state': _state.toString().split('.').last,
      'consecutive_failures': _consecutiveFailures,
      'last_failure_time': _lastFailureTime?.toIso8601String(),
      'circuit_open_until':
          _state == SyncState.circuitOpen && _lastFailureTime != null
              ? _lastFailureTime!.add(_circuitOpenDuration).toIso8601String()
              : null,
      'can_sync': _canAttemptSync(),
    };
  }

  /// Force reset circuit breaker (for manual intervention)
  void forceResetCircuitBreaker() {
    LoggerFactory.info('🔧 Forzando reset de circuit breaker');
    _resetCircuitBreaker();
    _state = SyncState.idle;
  }

  /// Dispose resources
  void dispose() {
    _state = SyncState.idle;
    _consecutiveFailures = 0;
    _lastFailureTime = null;
  }
}

/// Provider for safe sync service
final safeSyncServiceProvider = Provider<SafeSyncService>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return SafeSyncService(syncService);
});
