import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logging/logger_factory.dart';
import '../../core/sync/silent_favorites_sync_service.dart';
import 'storage/favorite_movies_provider.dart';

/// Estado de la sincronización silenciosa
class SilentSyncState {
  const SilentSyncState({
    this.isActive = false,
    this.currentMessage,
    this.progress,
    this.currentType,
    this.lastUpdate,
  });

  final bool isActive;
  final String? currentMessage;
  final double? progress;
  final SyncProgressType? currentType;
  final DateTime? lastUpdate;

  SilentSyncState copyWith({
    bool? isActive,
    String? currentMessage,
    double? progress,
    SyncProgressType? currentType,
    DateTime? lastUpdate,
  }) {
    return SilentSyncState(
      isActive: isActive ?? this.isActive,
      currentMessage: currentMessage ?? this.currentMessage,
      progress: progress ?? this.progress,
      currentType: currentType ?? this.currentType,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }

  @override
  String toString() {
    return 'SilentSyncState(isActive: $isActive, message: $currentMessage, progress: $progress)';
  }
}

/// Notifier para la sincronización silenciosa
class SilentSyncNotifier extends StateNotifier<SilentSyncState> {
  SilentSyncNotifier(this._ref) : super(const SilentSyncState()) {
    _initializeService();
  }

  final Ref _ref;
  final SilentFavoritesSyncService _syncService =
      SilentFavoritesSyncService.instance;
  StreamSubscription<SyncProgressUpdate>? _progressSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  void _initializeService() {
    // Escuchar progreso de sincronización
    _progressSubscription =
        _syncService.syncProgress.listen(_handleSyncProgress);

    // Escuchar cambios de autenticación
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      _onAuthStateChange,
    );

    // Si ya hay un usuario autenticado, iniciar sync
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId != null) {
      _startSilentSyncDelayed(currentUserId);
    }
  }

  /// Maneja cambios en el estado de autenticación
  void _onAuthStateChange(dynamic data) {
    try {
      // Access dynamic properties safely
      final session = (data as dynamic).session;
      String? userId;
      if (session != null) {
        final user = session.user;
        if (user != null) {
          userId = user.id as String?;
        }
      }
      _handleAuthChange(userId);
    } catch (e) {
      LoggerFactory.error('❌ Error handling auth state change: $e');
      _handleAuthChange(null);
    }
  }

  /// Maneja el progreso de sincronización
  void _handleSyncProgress(SyncProgressUpdate update) {
    state = state.copyWith(
      isActive: update.type != SyncProgressType.completed &&
          update.type != SyncProgressType.stopped &&
          update.type != SyncProgressType.error,
      currentMessage: update.message,
      progress: update.progress,
      currentType: update.type,
      lastUpdate: update.timestamp,
    );

    // Si se sincronizó un favorito, actualizar el provider
    if (update.type == SyncProgressType.itemSynced &&
        update.syncedMovie != null) {
      _refreshFavoritesProvider();
    }

    // Si la sincronización se completó, refrescar completamente
    if (update.type == SyncProgressType.completed) {
      _refreshFavoritesProvider();
    }
  }

  /// Maneja cambios de autenticación
  void _handleAuthChange(String? userId) {
    if (userId != null) {
      LoggerFactory.info(
          '🔐 User authenticated, starting silent sync: $userId');
      _startSilentSyncDelayed(userId);
    } else {
      LoggerFactory.info('🔐 User logged out, stopping silent sync');
      _syncService.stopSync();
    }
  }

  /// Inicia sincronización con un pequeño retraso para evitar bloquear login
  void _startSilentSyncDelayed(String userId) {
    Timer(const Duration(milliseconds: 2000), () {
      if (!_syncService.isSyncing) {
        _syncService.startSilentSync(userId);
      }
    });
  }

  /// Refresca el provider de favoritos para actualizar la UI
  void _refreshFavoritesProvider() {
    try {
      _ref.read(favoriteMoviesProvider.notifier).refreshFavorites();
    } catch (e) {
      LoggerFactory.error('❌ Error refreshing favorites provider: $e');
    }
  }

  /// Inicia sincronización manual
  Future<void> startManualSync() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null && !_syncService.isSyncing) {
      await _syncService.startSilentSync(userId);
    }
  }

  /// Detiene la sincronización actual
  void stopSync() {
    _syncService.stopSync();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}

/// Provider de la sincronización silenciosa
final silentSyncProvider =
    StateNotifierProvider<SilentSyncNotifier, SilentSyncState>((ref) {
  return SilentSyncNotifier(ref);
});

/// Provider para verificar si hay sincronización activa
final isSyncActiveProvider = Provider<bool>((ref) {
  return ref.watch(silentSyncProvider).isActive;
});

/// Provider para obtener el progreso actual
final syncProgressProvider = Provider<double?>((ref) {
  return ref.watch(silentSyncProvider).progress;
});

/// Provider para obtener el mensaje actual
final syncMessageProvider = Provider<String?>((ref) {
  return ref.watch(silentSyncProvider).currentMessage;
});
