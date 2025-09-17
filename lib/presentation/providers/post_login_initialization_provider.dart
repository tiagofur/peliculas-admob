import 'package:flutter_riverpod/legacy.dart';

import '../../core/logging/logger_factory.dart';
import '../../core/services/post_login_initialization_service.dart';

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
  PostLoginInitializationNotifier(/* this._ref */)
      : super(const PostLoginInitializationState()) {
    _initializeService();
  }

  // final Ref _ref; // TODO: Fix legacy compatibility
  final PostLoginInitializationService _service =
      PostLoginInitializationService.instance;

  void _initializeService() {
    try {
      // _service.initialize(_ref); // TODO: Fix legacy compatibility

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
      // _service.forceInitialization(userId, _ref); // TODO: Fix legacy compatibility

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
// TODO: Fix legacy compatibility for StateNotifierProvider and Provider
// final postLoginInitializationProvider = StateNotifierProvider<
//     PostLoginInitializationNotifier, PostLoginInitializationState>((ref) {
//   return PostLoginInitializationNotifier(ref);
// });

/// Provider para verificar si el servicio está inicializado
// final isPostLoginInitializedProvider = Provider<bool>((ref) {
//   return ref.watch(postLoginInitializationProvider).isInitialized;
// });
