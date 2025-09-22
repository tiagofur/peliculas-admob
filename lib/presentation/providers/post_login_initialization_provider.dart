import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/logging/logger_factory.dart';
import '../../core/services/post_login_initialization_service.dart';
import '../../core/sync/silent_favorites_sync_service.dart';
import 'custom_lists_providers.dart';
import 'storage/direct_custom_lists_provider.dart';
import 'storage/direct_favorites_provider.dart';
import 'storage/direct_watched_provider.dart';
import 'storage/direct_watchlist_provider.dart';
import 'storage/favorite_movies_provider.dart';

/// Estado del servicio de inicialización post-login
class PostLoginInitializationState {
  const PostLoginInitializationState({
    this.isInitialized = false,
    this.currentUserId,
    this.lastInitializationTime,
  });

  final bool isInitialized;
  final String? currentUserId;
  final DateTime? lastInitializationTime;

  PostLoginInitializationState copyWith({
    bool? isInitialized,
    String? currentUserId,
    DateTime? lastInitializationTime,
  }) {
    return PostLoginInitializationState(
      isInitialized: isInitialized ?? this.isInitialized,
      currentUserId: currentUserId ?? this.currentUserId,
      lastInitializationTime:
          lastInitializationTime ?? this.lastInitializationTime,
    );
  }

  @override
  String toString() {
    return 'PostLoginInitializationState(isInitialized: $isInitialized, userId: $currentUserId)';
  }
}

/// Notifier para el servicio de inicialización post-login
class PostLoginInitializationNotifier
    extends StateNotifier<PostLoginInitializationState> {
  PostLoginInitializationNotifier(this._ref)
      : super(const PostLoginInitializationState()) {
    _initializeService();
  }

  final Ref _ref;
  final PostLoginInitializationService _service =
      PostLoginInitializationService.instance;

  void _initializeService() {
    try {
      // Crear callbacks específicos sin pasar Ref directamente
      final callbacks = PostLoginInitializationCallbacks(
        enableFavoritesAutoRefresh: () {
          _ref.read(favoriteMoviesProvider.notifier).enableAutoRefresh();
        },
        initializeFavoritesProvider: () {
          _ref.read(directFavoriteMoviesProvider.notifier);
        },
        initializeWatchedProvider: () {
          _ref.read(directWatchedMoviesProvider.notifier);
        },
        initializeWatchlistProvider: () {
          _ref.read(directWatchlistMoviesProvider.notifier);
        },
        enableCustomListsAfterLogin: () {
          try {
            _ref.read(directCustomListsProvider.notifier).enableAfterLogin();
            LoggerFactory.info('✅ Custom lists after login enabled');
          } catch (e) {
            LoggerFactory.error(
                '❌ Error enabling custom lists after login: $e');
          }
        },
        initializeCustomListsAuth: (String userId) {
          try {
            _ref
                .read(customListsNotifierProvider.notifier)
                .initializeRealtimeSync();
            LoggerFactory.info(
                '✅ Custom lists auth initialized for user: $userId');
          } catch (e) {
            LoggerFactory.error(
                '❌ Error initializing custom lists auth for user $userId: $e');
          }
        },
        enableCustomListsNotifier: () {
          try {
            _ref.read(customListsNotifierProvider.notifier).enableAfterLogin();
            LoggerFactory.info('✅ Custom lists notifier enabled');
          } catch (e) {
            LoggerFactory.error('❌ Error enabling custom lists notifier: $e');
          }
        },
        getMigrationService: () async {
          try {
            return await _ref.read(listsMigrationServiceProvider.future);
          } catch (e) {
            LoggerFactory.error('❌ Error getting migration service: $e');
            return null;
          }
        },
        invalidateCustomLists: () {
          _ref.invalidate(directCustomListsProvider);
        },
        disableFavoritesAutoRefresh: () {
          _ref.read(favoriteMoviesProvider.notifier).disableAutoRefresh();
        },
        stopSilentSync: () {
          SilentFavoritesSyncService.instance.stopSync();
        },
        cleanupCustomListsAuth: () {
          try {
            LoggerFactory.info('✅ Custom lists auth cleanup completed');
          } catch (e) {
            LoggerFactory.error('❌ Error cleaning up custom lists auth: $e');
          }
        },
      );

      _service.initialize(callbacks);

      state = state.copyWith(
        isInitialized: true,
        lastInitializationTime: DateTime.now(),
      );

      LoggerFactory.info('✅ PostLoginInitializationProvider initialized');
    } catch (e) {
      LoggerFactory.error(
          '❌ Error initializing PostLoginInitializationProvider: $e');
    }
  }

  /// Fuerza la inicialización para un usuario específico
  void forceInitialization(String userId) {
    try {
      _service.forceInitialization(userId);

      state = state.copyWith(
        currentUserId: userId,
        lastInitializationTime: DateTime.now(),
      );

      LoggerFactory.info('✅ Forced initialization for user: $userId');
    } catch (e) {
      LoggerFactory.error('❌ Error in forced initialization: $e');
    }
  }

  @override
  void dispose() {
    try {
      _service.dispose();
      LoggerFactory.info('✅ PostLoginInitializationNotifier disposed');
    } catch (e) {
      LoggerFactory.error(
          '❌ Error disposing PostLoginInitializationNotifier: $e');
    }
    super.dispose();
  }
}

/// Provider para el servicio de inicialización post-login
// LEGACY COMPATIBILITY FIXED
final postLoginInitializationProvider = StateNotifierProvider<
    PostLoginInitializationNotifier, PostLoginInitializationState>((ref) {
  return PostLoginInitializationNotifier(ref);
});

/// Provider para verificar si el servicio está inicializado
final isPostLoginInitializedProvider = Provider<bool>((ref) {
  return ref.watch(postLoginInitializationProvider).isInitialized;
});
