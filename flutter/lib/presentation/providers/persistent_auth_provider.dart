import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/services/token_refresh_service.dart';
import 'auth_provider.dart';

// Provider para el servicio de refresco de tokens
final tokenRefreshServiceProvider = Provider<TokenRefreshService>((ref) {
  return TokenRefreshService.instance;
});

// Provider para el estado del token
final tokenStatusProvider =
    FutureProvider.autoDispose<TokenStatus>((ref) async {
  final tokenRefreshService = ref.watch(tokenRefreshServiceProvider);
  return await tokenRefreshService.getTokenStatus();
});

// Provider para eventos de refresco de tokens
final tokenRefreshEventsProvider =
    StreamProvider.autoDispose<TokenRefreshEvent>((ref) {
  final tokenRefreshService = ref.watch(tokenRefreshServiceProvider);
  return tokenRefreshService.events;
});

// Provider para verificar si el token necesita refresco
final tokenNeedsRefreshProvider = FutureProvider.autoDispose<bool>((ref) async {
  final tokenRefreshService = ref.watch(tokenRefreshServiceProvider);
  return await tokenRefreshService.isTokenNearExpiry();
});

// Notifier para operaciones manuales de refresco
class TokenRefreshNotifier extends AsyncNotifier<void> {
  TokenRefreshService get _tokenRefreshService =>
      ref.read(tokenRefreshServiceProvider);

  @override
  Future<void> build() async {
    // Inicialización del notifier
  }

  /// Fuerza un refresco manual del token
  Future<void> forceRefresh() async {
    state = const AsyncValue.loading();
    try {
      final success = await _tokenRefreshService.forceRefresh();
      if (success) {
        state = const AsyncValue.data(null);
      } else {
        state = AsyncValue.error(
            'No se pudo refrescar el token', StackTrace.current);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

// Provider para el notifier de refresco manual
final tokenRefreshNotifierProvider =
    AsyncNotifierProvider<TokenRefreshNotifier, void>(TokenRefreshNotifier.new);

// Provider combinado para información completa de autenticación persistente
final persistentAuthInfoProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final authRepository = ref.watch(authRepositoryProvider);
  final tokenStatus = await ref.watch(tokenStatusProvider.future);

  final sessionInfo = await authRepository.getSessionInfo();
  final hasPersistedSession = await authRepository.hasPersistedSession();

  return {
    'has_persisted_session': hasPersistedSession,
    'session_info': sessionInfo,
    'token_status': {
      'has_token': tokenStatus.hasToken,
      'is_valid': tokenStatus.isValid,
      'expires_at': tokenStatus.expiresAt?.toIso8601String(),
      'time_until_expiry_minutes': tokenStatus.timeUntilExpiry?.inMinutes,
      'needs_refresh': tokenStatus.needsRefresh,
      'is_refreshing': tokenStatus.isRefreshing,
      'is_healthy': tokenStatus.isHealthy,
      'error': tokenStatus.error,
    },
  };
});
