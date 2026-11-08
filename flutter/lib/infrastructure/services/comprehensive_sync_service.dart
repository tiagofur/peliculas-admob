import 'dart:async';

import '../../core/logging/logger_factory.dart';
import '../../core/sync/entity_sync_manager.dart';
import '../../core/sync/favorites_sync_manager.dart';
import '../../core/sync/watchlist_sync_manager.dart';
import '../../domain/entities/sync_result.dart';
import '../repositories/hybrid_favorites_repository.dart';
import '../repositories/hybrid_watchlist_repository.dart';
import 'connectivity_detector.dart';

/// Servicio integral de sincronización que coordina todas las entidades
class ComprehensiveSyncService {
  ComprehensiveSyncService({
    required this.userId,
    required this.favoritesRepository,
    required this.watchlistRepository,
  }) {
    _initialize();
  }

  final String userId;
  final HybridFavoritesRepository favoritesRepository;
  final HybridWatchlistRepository watchlistRepository;

  // Sync managers
  late final FavoritesSyncManager _favoritesSyncManager;
  late final WatchlistSyncManager _watchlistSyncManager;

  // State management
  bool _isInitialized = false;
  bool _isSyncing = false;
  Timer? _periodicSyncTimer;
  DateTime? _lastFullSync;
  DateTime? _lastIncrementalSync;

  // Stream controllers for sync events
  final StreamController<SyncProgressEvent> _syncProgressController =
      StreamController<SyncProgressEvent>.broadcast();
  final StreamController<ComprehensiveSyncResult> _syncResultController =
      StreamController<ComprehensiveSyncResult>.broadcast();

  /// Stream de progreso de sincronización
  Stream<SyncProgressEvent> get syncProgress => _syncProgressController.stream;

  /// Stream de resultados de sincronización
  Stream<ComprehensiveSyncResult> get syncResults =>
      _syncResultController.stream;

  /// Indica si el servicio está sincronizando
  bool get isSyncing => _isSyncing;

  /// Indica si el servicio está inicializado
  bool get isInitialized => _isInitialized;

  /// Inicializa el servicio de sincronización
  void _initialize() {
    try {
      _favoritesSyncManager = FavoritesSyncManager(userId: userId);
      _watchlistSyncManager = WatchlistSyncManager(userId: userId);

      // Escuchar eventos de progreso de los sync managers
      _favoritesSyncManager.syncProgress.listen(
        (event) => _syncProgressController.add(event),
      );
      _watchlistSyncManager.syncProgress.listen(
        (event) => _syncProgressController.add(event),
      );

      _isInitialized = true;
      LoggerFactory.info(
          '✅ ComprehensiveSyncService initialized for user: $userId');

      // Inicializar sincronización periódica
      _startPeriodicSync();
    } catch (e) {
      LoggerFactory.error(
          '❌ Failed to initialize ComprehensiveSyncService: $e');
      _isInitialized = false;
    }
  }

  /// Inicia la sincronización periódica
  void _startPeriodicSync() {
    // Sincronización cada 5 minutos cuando hay conectividad
    _periodicSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _performPeriodicSync(),
    );

    LoggerFactory.info('🔄 Periodic sync started (every 5 minutes)');
  }

  /// Detiene la sincronización periódica
  void _stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    LoggerFactory.info('⏸️ Periodic sync stopped');
  }

  /// Realiza sincronización periódica si hay conectividad
  Future<void> _performPeriodicSync() async {
    if (_isSyncing) {
      LoggerFactory.debug('⏭️ Skipping periodic sync - already syncing');
      return;
    }

    final hasConnectivity =
        await ConnectivityDetector.instance.testConnection();
    if (!hasConnectivity) {
      LoggerFactory.debug('⏭️ Skipping periodic sync - no connectivity');
      return;
    }

    LoggerFactory.info('⏰ Starting periodic sync');
    await performIncrementalSync();
  }

  /// Realiza sincronización completa de todas las entidades
  Future<ComprehensiveSyncResult> performFullSync() async {
    if (!_isInitialized) {
      throw StateError('ComprehensiveSyncService not initialized');
    }

    if (_isSyncing) {
      LoggerFactory.warning('⚠️ Sync already in progress, skipping');
      return ComprehensiveSyncResult.alreadyInProgress();
    }

    _isSyncing = true;
    final startTime = DateTime.now();

    try {
      LoggerFactory.info('🔄 Starting comprehensive full sync');

      // Verificar conectividad
      final hasConnectivity =
          await ConnectivityDetector.instance.testConnection();
      if (!hasConnectivity) {
        LoggerFactory.warning(
            '📶 No connectivity - sync will be queued for later');
        return ComprehensiveSyncResult.noConnectivity();
      }

      // Sincronizar favoritos
      final favoritesResult = await _favoritesSyncManager.performFullSync();

      // Sincronizar watchlist
      final watchlistResult = await _watchlistSyncManager.performFullSync();

      // Crear resultado combinado
      final result = ComprehensiveSyncResult.fromResults(
        favoritesResult: favoritesResult,
        watchlistResult: watchlistResult,
        duration: DateTime.now().difference(startTime),
        syncType: SyncType.full,
      );

      // Actualizar timestamp de última sincronización completa
      if (result.success) {
        _lastFullSync = DateTime.now();
      }

      _syncResultController.add(result);

      if (result.success) {
        LoggerFactory.info('✅ Comprehensive full sync completed successfully');
      } else {
        LoggerFactory.warning(
            '⚠️ Comprehensive full sync completed with errors');
      }

      return result;
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ Comprehensive full sync failed: $e',
          stackTrace: stackTrace);
      final result = ComprehensiveSyncResult.error(
        error: e.toString(),
        duration: DateTime.now().difference(startTime),
        syncType: SyncType.full,
      );
      _syncResultController.add(result);
      return result;
    } finally {
      _isSyncing = false;
    }
  }

  /// Realiza sincronización incremental (solo cambios recientes)
  Future<ComprehensiveSyncResult> performIncrementalSync() async {
    if (!_isInitialized) {
      throw StateError('ComprehensiveSyncService not initialized');
    }

    if (_isSyncing) {
      LoggerFactory.debug('⏭️ Incremental sync skipped - already syncing');
      return ComprehensiveSyncResult.alreadyInProgress();
    }

    _isSyncing = true;
    final startTime = DateTime.now();

    try {
      LoggerFactory.info('🔄 Starting comprehensive incremental sync');

      // Verificar conectividad
      final hasConnectivity =
          await ConnectivityDetector.instance.testConnection();
      if (!hasConnectivity) {
        LoggerFactory.debug('📶 No connectivity - incremental sync skipped');
        return ComprehensiveSyncResult.noConnectivity();
      }

      // Sincronizar favoritos incrementalmente
      final favoritesResult =
          await _favoritesSyncManager.performIncrementalSync();

      // Sincronizar watchlist incrementalmente
      final watchlistResult =
          await _watchlistSyncManager.performIncrementalSync();

      // Crear resultado combinado
      final result = ComprehensiveSyncResult.fromResults(
        favoritesResult: favoritesResult,
        watchlistResult: watchlistResult,
        duration: DateTime.now().difference(startTime),
        syncType: SyncType.incremental,
      );

      // Actualizar timestamp de última sincronización incremental
      if (result.success) {
        _lastIncrementalSync = DateTime.now();
      }

      _syncResultController.add(result);

      if (result.success) {
        LoggerFactory.debug('✅ Comprehensive incremental sync completed');
      } else {
        LoggerFactory.warning(
            '⚠️ Comprehensive incremental sync completed with errors');
      }

      return result;
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ Comprehensive incremental sync failed: $e',
          stackTrace: stackTrace);
      final result = ComprehensiveSyncResult.error(
        error: e.toString(),
        duration: DateTime.now().difference(startTime),
        syncType: SyncType.incremental,
      );
      _syncResultController.add(result);
      return result;
    } finally {
      _isSyncing = false;
    }
  }

  /// Fuerza la sincronización de operaciones pendientes en cola
  Future<ComprehensiveSyncResult> forceQueueSync() async {
    if (!_isInitialized) {
      throw StateError('ComprehensiveSyncService not initialized');
    }

    final startTime = DateTime.now();

    try {
      LoggerFactory.info('🔄 Starting queue sync');

      // Verificar conectividad
      final hasConnectivity =
          await ConnectivityDetector.instance.testConnection();
      if (!hasConnectivity) {
        LoggerFactory.warning(
            '📶 No connectivity - queue sync will retry later');
        return ComprehensiveSyncResult.noConnectivity();
      }

      // Procesar colas de favoritos
      final favoritesResult =
          await _favoritesSyncManager.processQueuedOperations();

      // Procesar colas de watchlist
      final watchlistResult =
          await _watchlistSyncManager.processQueuedOperations();

      // Crear resultado combinado
      final result = ComprehensiveSyncResult.fromResults(
        favoritesResult: favoritesResult,
        watchlistResult: watchlistResult,
        duration: DateTime.now().difference(startTime),
        syncType: SyncType.queue,
      );

      _syncResultController.add(result);
      LoggerFactory.info('✅ Queue sync completed');
      return result;
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ Queue sync failed: $e', stackTrace: stackTrace);
      final result = ComprehensiveSyncResult.error(
        error: e.toString(),
        duration: DateTime.now().difference(startTime),
        syncType: SyncType.queue,
      );
      _syncResultController.add(result);
      return result;
    }
  }

  /// Obtiene estadísticas de sincronización de todas las entidades
  Future<ComprehensiveSyncStats> getSyncStatistics() async {
    if (!_isInitialized) {
      throw StateError('ComprehensiveSyncService not initialized');
    }

    final favoritesStats = await _favoritesSyncManager.getSyncStatistics();
    final watchlistStats = await _watchlistSyncManager.getSyncStatistics();

    return ComprehensiveSyncStats(
      favorites: favoritesStats,
      watchlist: watchlistStats,
      lastFullSync: _lastFullSync ?? DateTime.fromMillisecondsSinceEpoch(0),
      lastIncrementalSync:
          _lastIncrementalSync ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// Reinicia el servicio de sincronización
  Future<void> reset() async {
    LoggerFactory.info('🔄 Resetting ComprehensiveSyncService');

    _stopPeriodicSync();
    _isSyncing = false;

    await _favoritesSyncManager.dispose();
    await _watchlistSyncManager.dispose();

    _initialize();
  }

  /// Limpia recursos del servicio
  Future<void> dispose() async {
    LoggerFactory.info('🧹 Disposing ComprehensiveSyncService');

    _stopPeriodicSync();

    await _syncProgressController.close();
    await _syncResultController.close();

    if (_isInitialized) {
      await _favoritesSyncManager.dispose();
      await _watchlistSyncManager.dispose();
    }

    _isInitialized = false;
  }
}

/// Resultado de sincronización comprensiva
class ComprehensiveSyncResult {
  const ComprehensiveSyncResult({
    required this.success,
    required this.syncType,
    required this.favoritesResult,
    required this.watchlistResult,
    required this.duration,
    this.error,
  });

  /// Crea resultado desde resultados individuales
  factory ComprehensiveSyncResult.fromResults({
    required SyncResult favoritesResult,
    required SyncResult watchlistResult,
    required Duration duration,
    required SyncType syncType,
  }) {
    return ComprehensiveSyncResult(
      success: favoritesResult.success && watchlistResult.success,
      syncType: syncType,
      favoritesResult: favoritesResult,
      watchlistResult: watchlistResult,
      duration: duration,
    );
  }

  /// Crea resultado de error
  factory ComprehensiveSyncResult.error({
    required String error,
    required Duration duration,
    required SyncType syncType,
  }) {
    return ComprehensiveSyncResult(
      success: false,
      syncType: syncType,
      favoritesResult: SyncResult.failure(
        itemsProcessed: 0,
        errors: [error],
        duration: duration,
      ),
      watchlistResult: SyncResult.failure(
        itemsProcessed: 0,
        errors: [error],
        duration: duration,
      ),
      duration: duration,
      error: error,
    );
  }

  /// Crea resultado de ya en progreso
  factory ComprehensiveSyncResult.alreadyInProgress() {
    final errorResult = SyncResult.failure(
      itemsProcessed: 0,
      errors: ['Sync already in progress'],
      duration: Duration.zero,
    );

    return ComprehensiveSyncResult(
      success: false,
      syncType: SyncType.none,
      favoritesResult: errorResult,
      watchlistResult: errorResult,
      duration: Duration.zero,
      error: 'Sync already in progress',
    );
  }

  /// Crea resultado de sin conectividad
  factory ComprehensiveSyncResult.noConnectivity() {
    final noConnResult = SyncResult.failure(
      itemsProcessed: 0,
      errors: ['No internet connectivity'],
      duration: Duration.zero,
    );

    return ComprehensiveSyncResult(
      success: false,
      syncType: SyncType.none,
      favoritesResult: noConnResult,
      watchlistResult: noConnResult,
      duration: Duration.zero,
      error: 'No internet connectivity',
    );
  }

  final bool success;
  final SyncType syncType;
  final SyncResult favoritesResult;
  final SyncResult watchlistResult;
  final Duration duration;
  final String? error;

  int get totalItemsProcessed =>
      favoritesResult.itemsProcessed + watchlistResult.itemsProcessed;

  int get totalItemsSuccessful =>
      favoritesResult.itemsSuccessful + watchlistResult.itemsSuccessful;

  int get totalItemsFailed =>
      favoritesResult.itemsFailed + watchlistResult.itemsFailed;

  List<String> get allErrors =>
      [...favoritesResult.errors, ...watchlistResult.errors];

  @override
  String toString() {
    return 'ComprehensiveSyncResult('
        'success: $success, '
        'type: ${syncType.name}, '
        'totalProcessed: $totalItemsProcessed, '
        'totalSuccessful: $totalItemsSuccessful, '
        'totalFailed: $totalItemsFailed, '
        'duration: ${duration.inMilliseconds}ms'
        ')';
  }
}

/// Estadísticas comprensivas de sincronización
class ComprehensiveSyncStats {
  const ComprehensiveSyncStats({
    required this.favorites,
    required this.watchlist,
    required this.lastFullSync,
    required this.lastIncrementalSync,
  });

  final dynamic favorites; // SyncStats
  final dynamic watchlist; // SyncStats
  final DateTime lastFullSync;
  final DateTime lastIncrementalSync;
}

/// Tipos de sincronización
enum SyncType {
  none,
  full,
  incremental,
  queue,
}
