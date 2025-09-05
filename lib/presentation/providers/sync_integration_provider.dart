import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/sync/sync_settings_widget.dart';
import '../widgets/sync/sync_history_viewer.dart';

/// Sync Integration Provider
///
/// This provider coordinates all sync-related services and provides
/// a unified interface for the UI widgets to interact with the sync system.
class SyncIntegrationState {
  final bool isInitialized;
  final bool isConnected;
  final SyncStatus globalSyncStatus;
  final Map<String, dynamic> performanceMetrics;
  final List<SyncHistoryEntry> recentHistory;
  final SyncSettings currentSettings;
  final String? lastError;

  const SyncIntegrationState({
    required this.isInitialized,
    required this.isConnected,
    required this.globalSyncStatus,
    required this.performanceMetrics,
    required this.recentHistory,
    required this.currentSettings,
    this.lastError,
  });

  // Getter for UI compatibility
  List<SyncHistoryEntry> get syncHistory => recentHistory;

  SyncIntegrationState copyWith({
    bool? isInitialized,
    bool? isConnected,
    SyncStatus? globalSyncStatus,
    Map<String, dynamic>? performanceMetrics,
    List<SyncHistoryEntry>? recentHistory,
    SyncSettings? currentSettings,
    String? lastError,
  }) {
    return SyncIntegrationState(
      isInitialized: isInitialized ?? this.isInitialized,
      isConnected: isConnected ?? this.isConnected,
      globalSyncStatus: globalSyncStatus ?? this.globalSyncStatus,
      performanceMetrics: performanceMetrics ?? this.performanceMetrics,
      recentHistory: recentHistory ?? this.recentHistory,
      currentSettings: currentSettings ?? this.currentSettings,
      lastError: lastError ?? this.lastError,
    );
  }
}

enum SyncStatus {
  idle,
  syncing,
  synced,
  error,
  conflicts,
  offline,
}

class SyncIntegrationNotifier extends StateNotifier<SyncIntegrationState> {
  final MockRealtimeSyncManager _realtimeSyncManager;
  final MockConnectivityManager _connectivityManager;
  final MockSyncCoordinator _syncCoordinator;
  final MockSyncPerformanceMetrics _performanceMetrics;

  SyncIntegrationNotifier(
    this._realtimeSyncManager,
    this._connectivityManager,
    this._syncCoordinator,
    this._performanceMetrics,
  ) : super(
          const SyncIntegrationState(
            isInitialized: false,
            isConnected: false,
            globalSyncStatus: SyncStatus.idle,
            performanceMetrics: <String, dynamic>{},
            recentHistory: <SyncHistoryEntry>[],
            currentSettings: SyncSettings(),
            lastError: null,
          ),
        ) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Initialize all sync services
      await _realtimeSyncManager.initialize();
      await _connectivityManager.initialize();
      await _syncCoordinator.initialize();

      // Set up listeners
      _setupListeners();

      state = state.copyWith(
        isInitialized: true,
        isConnected: _connectivityManager.isConnected,
      );
    } catch (e) {
      state = state.copyWith(
        lastError: 'Failed to initialize sync services: $e',
      );
    }
  }

  void _setupListeners() {
    // Listen to connectivity changes
    _connectivityManager.connectionStream.listen((isConnected) {
      state = state.copyWith(
        isConnected: isConnected,
        globalSyncStatus: isConnected ? SyncStatus.idle : SyncStatus.offline,
      );
    });

    // Update performance metrics periodically
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        state = state.copyWith(
          performanceMetrics: _performanceMetrics.metrics,
        );
      } else {
        timer.cancel();
      }
    });
  }


  // Public methods for UI interaction
  Future<void> triggerManualSync() async {
    try {
      state = state.copyWith(globalSyncStatus: SyncStatus.syncing);
      await _syncCoordinator.performFullSync();
      state = state.copyWith(globalSyncStatus: SyncStatus.synced);
    } catch (e) {
      state = state.copyWith(
        globalSyncStatus: SyncStatus.error,
        lastError: 'Manual sync failed: $e',
      );
    }
  }

  Future<void> toggleAutoSync(bool enabled) async {
    final newSettings =
        state.currentSettings.copyWith(autoSyncEnabled: enabled);
    state = state.copyWith(currentSettings: newSettings);

    if (enabled) {
      await _realtimeSyncManager.startAutoSync();
    } else {
      await _realtimeSyncManager.stopAutoSync();
    }
  }

  Future<void> toggleOfflineMode(bool enabled) async {
    final newSettings =
        state.currentSettings.copyWith(offlineModeEnabled: enabled);
    state = state.copyWith(currentSettings: newSettings);

    if (enabled) {
      await _realtimeSyncManager.enableOfflineMode();
      state = state.copyWith(globalSyncStatus: SyncStatus.offline);
    } else {
      await _realtimeSyncManager.disableOfflineMode();
      state = state.copyWith(globalSyncStatus: SyncStatus.idle);
    }
  }

  Future<void> updateSyncFrequency(SyncFrequency frequency) async {
    final newSettings =
        state.currentSettings.copyWith(syncFrequency: frequency);
    state = state.copyWith(currentSettings: newSettings);
    await _realtimeSyncManager.updateSyncFrequency(frequency);
  }

  Future<void> updateConflictResolutionStrategy(
      ConflictResolutionStrategy strategy) async {
    final newSettings =
        state.currentSettings.copyWith(conflictResolution: strategy);
    state = state.copyWith(currentSettings: newSettings);
    await _syncCoordinator.updateConflictResolutionStrategy(strategy);
  }

  Future<void> clearLocalData() async {
    try {
      await _syncCoordinator.clearLocalData();
      state = state.copyWith(
        globalSyncStatus: SyncStatus.idle,
        recentHistory: [],
      );
    } catch (e) {
      state = state.copyWith(
        lastError: 'Failed to clear local data: $e',
      );
    }
  }

  /// Fuerza una resincronización completa
  Future<void> forceFullResync() async {
    try {
      state = state.copyWith(
        globalSyncStatus: SyncStatus.syncing,
        lastError: null,
      );

      await _syncCoordinator.forceFullResync();
      
      state = state.copyWith(
        globalSyncStatus: SyncStatus.synced,
      );
    } catch (e) {
      state = state.copyWith(
        globalSyncStatus: SyncStatus.error,
        lastError: e.toString(),
      );
    }
  }

  /// Notifica cuando un conflicto ha sido resuelto
  void onConflictResolved(String entityId, ConflictResolutionStrategy strategy) {
    // Actualizar el estado para reflejar que el conflicto fue resuelto
    final updatedHistory = List<SyncHistoryEntry>.from(state.recentHistory);
    updatedHistory.insert(0, SyncHistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      type: SyncOperationType.conflictResolution,
      status: SyncOperationStatus.success,
      entityType: 'Entity',
      entityId: entityId,
      description: 'Conflicto resuelto - Estrategia: ${_getStrategyName(strategy)}',
    ));

    // Mantener solo los últimos 50 registros
    if (updatedHistory.length > 50) {
      updatedHistory.removeRange(50, updatedHistory.length);
    }

    state = state.copyWith(
      recentHistory: updatedHistory,
      globalSyncStatus: SyncStatus.synced,
    );
  }

  String _getStrategyName(ConflictResolutionStrategy strategy) {
    switch (strategy) {
      case ConflictResolutionStrategy.keepLocal:
        return 'Versión local';
      case ConflictResolutionStrategy.keepRemote:
        return 'Versión remota';
      case ConflictResolutionStrategy.mergeAutomatic:
        return 'Fusión automática';
      case ConflictResolutionStrategy.askUser:
        return 'Selección manual';
    }
  }

  void clearError() {
    state = state.copyWith(lastError: null);
  }

  // Getters for specific UI needs
  bool get canSync => state.isInitialized && state.isConnected;
  bool get hasError => state.lastError != null;
  bool get isOffline =>
      !state.isConnected || state.globalSyncStatus == SyncStatus.offline;
  bool get isSyncing => state.globalSyncStatus == SyncStatus.syncing;
  bool get hasConflicts => state.globalSyncStatus == SyncStatus.conflicts;
  List<SyncHistoryEntry> get syncHistory => state.recentHistory;
}

// Provider definitions
final syncIntegrationProvider =
    StateNotifierProvider<SyncIntegrationNotifier, SyncIntegrationState>((ref) {
  // Get dependencies from other providers
  final realtimeSyncManager = ref.watch(realtimeSyncManagerProvider);
  final connectivityManager = ref.watch(connectivityManagerProvider);
  final syncCoordinator = ref.watch(syncCoordinatorProvider);
  final performanceMetrics = ref.watch(syncPerformanceMetricsProvider);

  return SyncIntegrationNotifier(
    realtimeSyncManager,
    connectivityManager,
    syncCoordinator,
    performanceMetrics,
  );
});

// Convenience providers for specific UI needs
final globalSyncStatusProvider = Provider<SyncStatus>((ref) {
  return ref.watch(syncIntegrationProvider).globalSyncStatus;
});

final syncConnectivityProvider = Provider<bool>((ref) {
  return ref.watch(syncIntegrationProvider).isConnected;
});

final syncErrorProvider = Provider<String?>((ref) {
  return ref.watch(syncIntegrationProvider).lastError;
});

final syncPerformanceProvider = Provider<Map<String, dynamic>>((ref) {
  return ref.watch(syncIntegrationProvider).performanceMetrics;
});

// Mock providers for development (replace with actual implementations)
final realtimeSyncManagerProvider = Provider<MockRealtimeSyncManager>((ref) {
  return MockRealtimeSyncManager();
});

final connectivityManagerProvider = Provider<MockConnectivityManager>((ref) {
  return MockConnectivityManager();
});

final syncCoordinatorProvider = Provider<MockSyncCoordinator>((ref) {
  return MockSyncCoordinator();
});

final syncPerformanceMetricsProvider = Provider<MockSyncPerformanceMetrics>((ref) {
  return MockSyncPerformanceMetrics();
});

// Mock implementations
class MockRealtimeSyncManager {
  Future<void> initialize() async {}
  Future<void> startAutoSync() async {}
  Future<void> stopAutoSync() async {}
  Future<void> enableOfflineMode() async {}
  Future<void> disableOfflineMode() async {}
  Future<void> updateSyncFrequency(SyncFrequency frequency) async {}
}

class MockConnectivityManager {
  Stream<bool> get connectionStream => Stream.value(true);
  bool get isConnected => true;
  Future<void> initialize() async {}
}

class MockSyncCoordinator {
  Future<void> initialize() async {}
  Future<void> performFullSync() async {}
  Future<void> clearLocalData() async {}
  Future<void> forceFullResync() async {}
  Future<void> updateConflictResolutionStrategy(ConflictResolutionStrategy strategy) async {}
}

class MockSyncPerformanceMetrics {
  Map<String, dynamic> get metrics => {
    'syncTime': 1200,
    'itemsProcessed': 150,
    'errorRate': 0.02,
  };
}