import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/sync_performance_metrics.dart';
import '../../core/sync/conflict_resolution/strategies/conflict_strategy.dart';
import '../../core/sync/entity_sync_manager.dart';
import '../../core/sync/sync_coordinator.dart';
import '../../infrastructure/services/connectivity_manager.dart';
import '../../infrastructure/services/realtime_sync_manager.dart';
import '../widgets/sync/sync_history_viewer.dart';
import 'auth_provider.dart';

/// Frecuencia de sincronización
enum SyncFrequency {
  realtime('realtime'),
  every5Minutes('every_5_minutes'),
  every15Minutes('every_15_minutes'),
  every30Minutes('every_30_minutes'),
  hourly('hourly'),
  daily('daily'),
  manual('manual');

  const SyncFrequency(this.value);
  final String value;

  static SyncFrequency fromString(String value) {
    return SyncFrequency.values.firstWhere(
      (frequency) => frequency.value == value,
      orElse: () => SyncFrequency.every15Minutes,
    );
  }
}

/// Configuración de sincronización
class SyncSettings {
  const SyncSettings({
    this.autoSyncEnabled = true,
    this.offlineModeEnabled = false,
    this.syncFrequency = SyncFrequency.every15Minutes,
    this.conflictResolution = ConflictResolutionStrategy.lastWriteWins,
    this.backgroundSyncEnabled = true,
    this.wifiOnlySync = false,
  });

  factory SyncSettings.fromJson(Map<String, dynamic> json) {
    return SyncSettings(
      autoSyncEnabled: json['autoSyncEnabled'] as bool? ?? true,
      offlineModeEnabled: json['offlineModeEnabled'] as bool? ?? false,
      syncFrequency: SyncFrequency.fromString(
          json['syncFrequency'] as String? ?? 'every_15_minutes'),
      conflictResolution: ConflictResolutionStrategy.fromString(
          json['conflictResolution'] as String? ?? 'last_write_wins'),
      backgroundSyncEnabled: json['backgroundSyncEnabled'] as bool? ?? true,
      wifiOnlySync: json['wifiOnlySync'] as bool? ?? false,
    );
  }

  final bool autoSyncEnabled;
  final bool offlineModeEnabled;
  final SyncFrequency syncFrequency;
  final ConflictResolutionStrategy conflictResolution;
  final bool backgroundSyncEnabled;
  final bool wifiOnlySync;

  SyncSettings copyWith({
    bool? autoSyncEnabled,
    bool? offlineModeEnabled,
    SyncFrequency? syncFrequency,
    ConflictResolutionStrategy? conflictResolution,
    bool? backgroundSyncEnabled,
    bool? wifiOnlySync,
  }) {
    return SyncSettings(
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      offlineModeEnabled: offlineModeEnabled ?? this.offlineModeEnabled,
      syncFrequency: syncFrequency ?? this.syncFrequency,
      conflictResolution: conflictResolution ?? this.conflictResolution,
      backgroundSyncEnabled:
          backgroundSyncEnabled ?? this.backgroundSyncEnabled,
      wifiOnlySync: wifiOnlySync ?? this.wifiOnlySync,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'autoSyncEnabled': autoSyncEnabled,
      'offlineModeEnabled': offlineModeEnabled,
      'syncFrequency': syncFrequency.value,
      'conflictResolution': conflictResolution.value,
      'backgroundSyncEnabled': backgroundSyncEnabled,
      'wifiOnlySync': wifiOnlySync,
    };
  }
}

/// Sync Integration Provider
///
/// This provider coordinates all sync-related services and provides
/// a unified interface for the UI widgets to interact with the sync system.
class SyncIntegrationState {
  const SyncIntegrationState({
    required this.isInitialized,
    required this.isConnected,
    required this.globalSyncStatus,
    required this.performanceMetrics,
    required this.recentHistory,
    required this.currentSettings,
    this.lastError,
  });
  final bool isInitialized;
  final bool isConnected;
  final SyncStatus globalSyncStatus;
  final Map<String, dynamic> performanceMetrics;
  final List<SyncHistoryEntry> recentHistory;
  final SyncSettings currentSettings;
  final String? lastError;

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

class SyncIntegrationNotifier extends Notifier<SyncIntegrationState> {
  // Add StreamSubscription to track and dispose properly
  StreamSubscription<ConnectionStatus>? _connectivitySubscription;
  Timer? _metricsTimer;

  @override
  SyncIntegrationState build() {
    // Get dependencies from providers
    final user = ref.watch(currentUserProvider);
    final userId = user?.id;

    if (userId == null) {
      return const SyncIntegrationState(
        isInitialized: false,
        isConnected: false,
        globalSyncStatus: SyncStatus.idle,
        performanceMetrics: <String, dynamic>{},
        recentHistory: <SyncHistoryEntry>[],
        currentSettings: SyncSettings(),
        lastError: 'User not authenticated',
      );
    }

    // Set up disposal callback
    ref.onDispose(() {
      _connectivitySubscription?.cancel();
      _metricsTimer?.cancel();
      try {
        _realtimeSyncManager.dispose();
        _connectivityManager.dispose();
        _syncCoordinator.dispose();
      } catch (e) {
        // Ignore errors in dispose
      }
    });

    _initialize();
    return const SyncIntegrationState(
      isInitialized: false,
      isConnected: false,
      globalSyncStatus: SyncStatus.idle,
      performanceMetrics: <String, dynamic>{},
      recentHistory: <SyncHistoryEntry>[],
      currentSettings: SyncSettings(),
      lastError: null,
    );
  }

  // Get dependencies via providers
  RealtimeSyncManager get _realtimeSyncManager {
    final user = ref.read(currentUserProvider);
    return ref.read(realtimeSyncManagerProvider(user?.id ?? 'anonymous'));
  }

  ConnectivityManager get _connectivityManager =>
      ref.read(connectivityManagerProvider);

  SyncCoordinator get _syncCoordinator {
    final user = ref.read(currentUserProvider);
    return ref.read(syncCoordinatorProvider(user?.id ?? 'anonymous'));
  }

  SyncPerformanceMetrics get _performanceMetrics =>
      ref.read(syncPerformanceMetricsProvider);

  Future<void> _initialize() async {
    try {
      // Initialize all sync services
      await _realtimeSyncManager.initialize();
      await _connectivityManager.initialize();
      // SyncCoordinator initializes automatically in constructor

      // Set up listeners
      _setupListeners();

      state = state.copyWith(
        isInitialized: true,
        isConnected:
            _connectivityManager.currentStatus == ConnectionStatus.online,
      );
    } catch (e) {
      state = state.copyWith(
        lastError: 'Failed to initialize sync services: $e',
      );
    }
  }

  void _setupListeners() {
    // Listen to connectivity changes
    _connectivitySubscription =
        _connectivityManager.connectionStatus.listen((status) {
      final isConnected = status == ConnectionStatus.online;
      state = state.copyWith(
        isConnected: isConnected,
        globalSyncStatus: isConnected ? SyncStatus.idle : SyncStatus.offline,
      );
    });

    // Update performance metrics periodically
    _metricsTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      // Remove mounted check - disposal is handled by ref.onDispose()
      try {
        state = state.copyWith(
          performanceMetrics: _performanceMetrics.getSnapshot().toJson(),
        );
      } catch (e) {
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
      await _realtimeSyncManager.startListening();
    } else {
      await _realtimeSyncManager.stopListening();
    }
  }

  Future<void> toggleOfflineMode(bool enabled) async {
    final newSettings =
        state.currentSettings.copyWith(offlineModeEnabled: enabled);
    state = state.copyWith(currentSettings: newSettings);

    if (enabled) {
      await _syncCoordinator.enableOfflineMode();
      state = state.copyWith(globalSyncStatus: SyncStatus.offline);
    } else {
      await _syncCoordinator.disableOfflineMode();
      state = state.copyWith(globalSyncStatus: SyncStatus.idle);
    }
  }

  Future<void> updateSyncFrequency(SyncFrequency frequency) async {
    final newSettings =
        state.currentSettings.copyWith(syncFrequency: frequency);
    state = state.copyWith(currentSettings: newSettings);
    // Note: RealtimeSyncManager doesn't have updateSyncFrequency method
    // This would need to be implemented if frequency control is needed
  }

  Future<void> updateConflictResolutionStrategy(
      ConflictResolutionStrategy strategy) async {
    final newSettings =
        state.currentSettings.copyWith(conflictResolution: strategy);
    state = state.copyWith(currentSettings: newSettings);
    // Convert to ConflictStrategy enum that SyncCoordinator expects
    final syncStrategy = _convertToConflictStrategy(strategy);
    _syncCoordinator.setConflictStrategy('default', syncStrategy);
  }

  ConflictStrategy _convertToConflictStrategy(
      ConflictResolutionStrategy strategy) {
    switch (strategy) {
      case ConflictResolutionStrategy.lastWriteWins:
        return ConflictStrategy.remoteWins;
      case ConflictResolutionStrategy.userChoice:
        return ConflictStrategy.userChoice;
      case ConflictResolutionStrategy.merge:
        return ConflictStrategy.merge;
      case ConflictResolutionStrategy.serverWins:
        return ConflictStrategy.remoteWins;
      default:
        return ConflictStrategy.localWins;
    }
  }

  Future<void> clearLocalData() async {
    try {
      await _syncCoordinator.reset();
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

      final result = await _syncCoordinator.performFullSync();

      state = state.copyWith(
        globalSyncStatus: result.success ? SyncStatus.synced : SyncStatus.error,
        lastError: result.success
            ? null
            : (result.errors.isNotEmpty ? result.errors.first : null),
      );
    } catch (e) {
      state = state.copyWith(
        globalSyncStatus: SyncStatus.error,
        lastError: e.toString(),
      );
    }
  }

  /// Notifica cuando un conflicto ha sido resuelto
  void onConflictResolved(
      String entityId, ConflictResolutionStrategy strategy) {
    // Actualizar el estado para reflejar que el conflicto fue resuelto
    final updatedHistory = List<SyncHistoryEntry>.from(state.recentHistory);
    updatedHistory.insert(
        0,
        SyncHistoryEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          type: SyncOperationType.conflictResolution,
          status: SyncOperationStatus.success,
          entityType: 'Entity',
          entityId: entityId,
          description:
              'Conflicto resuelto - Estrategia: ${_getStrategyName(strategy)}',
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
      case ConflictResolutionStrategy.lastWriteWins:
        return 'Última escritura gana';
      case ConflictResolutionStrategy.userChoice:
        return 'Selección manual';
      case ConflictResolutionStrategy.merge:
        return 'Fusión';
      case ConflictResolutionStrategy.serverWins:
        return 'Servidor gana';
      case ConflictResolutionStrategy.clientWins:
        return 'Cliente gana';
      case ConflictResolutionStrategy.custom:
        return 'Personalizada';
      case ConflictResolutionStrategy.autoMerge:
        return 'Fusión automática';
      case ConflictResolutionStrategy.priorityBased:
        return 'Basada en prioridad';
      case ConflictResolutionStrategy.versionBased:
        return 'Basada en versión';
      case ConflictResolutionStrategy.fieldSpecific:
        return 'Específica por campo';
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

  // Disposal is handled in build() method via ref.onDispose()
}

// Provider definitions
final syncIntegrationProvider =
    NotifierProvider<SyncIntegrationNotifier, SyncIntegrationState>(() {
  return SyncIntegrationNotifier();
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

// Real providers for production
final realtimeSyncManagerProvider =
    Provider.family<RealtimeSyncManager, String>((ref, userId) {
  final syncCoordinator = ref.watch(syncCoordinatorProvider(userId));
  final connectivityManager = ref.watch(connectivityManagerProvider);
  return RealtimeSyncManager(
    userId: userId,
    syncCoordinator: syncCoordinator,
    connectivityManager: connectivityManager,
  );
});

final connectivityManagerProvider = Provider<ConnectivityManager>((ref) {
  return ConnectivityManager();
});

final syncCoordinatorProvider =
    Provider.family<SyncCoordinator, String>((ref, userId) {
  return SyncCoordinator(userId: userId);
});

final syncPerformanceMetricsProvider = Provider<SyncPerformanceMetrics>((ref) {
  return SyncPerformanceMetrics.instance;
});

/// Notifier deshabilitado para cuando no hay usuario autenticado
class DisabledSyncIntegrationNotifier extends Notifier<SyncIntegrationState> {
  @override
  SyncIntegrationState build() {
    // Return disabled state immediately
    return const SyncIntegrationState(
      isInitialized: false,
      isConnected: false,
      globalSyncStatus: SyncStatus.offline,
      currentSettings: SyncSettings(
        autoSyncEnabled: false,
        offlineModeEnabled: false,
        syncFrequency: SyncFrequency.manual,
        conflictResolution: ConflictResolutionStrategy.userChoice,
        backgroundSyncEnabled: false,
        wifiOnlySync: false,
      ),
      recentHistory: [],
      performanceMetrics: {},
      lastError: 'Usuario no autenticado - Sync deshabilitado',
    );
  }

  // Disabled methods - no-op implementations
  Future<void> triggerManualSync() async {}
  Future<void> enableAutoSync() async {}
  Future<void> disableAutoSync() async {}
  Future<void> updateSettings(SyncSettings settings) async {}
  Future<void> resolveConflict(
      String conflictId, ConflictResolutionStrategy strategy) async {}
  void clearError() {}
}
