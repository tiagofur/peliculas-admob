import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/logging/logger_factory.dart';

/// Eventos de refresco de tokens
sealed class TokenRefreshEvent {
  const TokenRefreshEvent();
}

/// Usuario se autenticó
class UserSignedInEvent extends TokenRefreshEvent {
  const UserSignedInEvent({required this.userId});
  final String userId;
}

/// Usuario cerró sesión
class UserSignedOutEvent extends TokenRefreshEvent {
  const UserSignedOutEvent();
}

/// Inicio de refresco de token
class RefreshStartedEvent extends TokenRefreshEvent {
  const RefreshStartedEvent({required this.userId});
  final String userId;
}

/// Token refrescado exitosamente
class TokenRefreshedEvent extends TokenRefreshEvent {
  const TokenRefreshedEvent({required this.userId});
  final String userId;
}

/// Fallo en refresco de token
class RefreshFailedEvent extends TokenRefreshEvent {
  const RefreshFailedEvent({required this.error});
  final String error;
}

/// Sesión invalidada
class SessionInvalidatedEvent extends TokenRefreshEvent {
  const SessionInvalidatedEvent();
}

/// Estado del token
class TokenStatus {
  const TokenStatus({
    required this.hasToken,
    required this.needsRefresh,
    required this.isRefreshing,
    this.expiresAt,
    this.timeUntilExpiry,
    this.isHealthy = true,
    this.error,
  });

  final bool hasToken;
  final bool needsRefresh;
  final bool isRefreshing;
  final DateTime? expiresAt;
  final Duration? timeUntilExpiry;
  final bool isHealthy;
  final String? error;

  /// Indica si el token es válido (tiene token y está saludable)
  bool get isValid => hasToken && isHealthy;
}

/// Servicio de refresco de tokens
class TokenRefreshService {
  TokenRefreshService._();

  static final TokenRefreshService _instance = TokenRefreshService._();
  static TokenRefreshService get instance => _instance;

  final SupabaseClient _supabase = SupabaseConfig.client;
  final StreamController<TokenRefreshEvent> _eventController =
      StreamController<TokenRefreshEvent>.broadcast();

  bool _isInitialized = false;
  bool _isRefreshing = false;
  Timer? _refreshTimer;

  /// Stream de eventos de refresco
  Stream<TokenRefreshEvent> get events => _eventController.stream;

  /// Inicializa el servicio
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Escuchar cambios de autenticación
      _supabase.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        final session = data.session;

        switch (event) {
          case AuthChangeEvent.signedIn:
            if (session?.user != null) {
              _eventController.add(UserSignedInEvent(userId: session!.user.id));
            }
            break;
          case AuthChangeEvent.signedOut:
            _eventController.add(const UserSignedOutEvent());
            break;
          case AuthChangeEvent.tokenRefreshed:
            if (session?.user != null) {
              _eventController
                  .add(TokenRefreshedEvent(userId: session!.user.id));
            }
            break;
          default:
            break;
        }
      });

      _isInitialized = true;
      LoggerFactory.info('✅ TokenRefreshService initialized');
    } catch (e) {
      LoggerFactory.error('❌ Failed to initialize TokenRefreshService: $e');
      rethrow;
    }
  }

  /// Fuerza un refresco del token
  Future<bool> forceRefresh() async {
    if (_isRefreshing) {
      LoggerFactory.warning('⚠️ Token refresh already in progress');
      return false;
    }

    final session = _supabase.auth.currentSession;
    if (session == null) {
      LoggerFactory.warning('⚠️ No active session to refresh');
      return false;
    }

    _isRefreshing = true;
    _eventController.add(RefreshStartedEvent(userId: session.user.id));

    try {
      final response = await _supabase.auth.refreshSession();

      if (response.session != null) {
        _eventController
            .add(TokenRefreshedEvent(userId: response.session!.user.id));
        LoggerFactory.info('✅ Token refreshed successfully');
        return true;
      } else {
        _eventController
            .add(const RefreshFailedEvent(error: 'No session in response'));
        return false;
      }
    } catch (e) {
      _eventController.add(RefreshFailedEvent(error: e.toString()));
      LoggerFactory.error('❌ Token refresh failed: $e');
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Obtiene el estado actual del token
  Future<TokenStatus> getTokenStatus() async {
    final session = _supabase.auth.currentSession;

    if (session == null) {
      return const TokenStatus(
        hasToken: false,
        needsRefresh: false,
        isRefreshing: false,
        timeUntilExpiry: null,
        isHealthy: false,
        error: 'No active session',
      );
    }

    final expiresAt =
        DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
    final now = DateTime.now();
    final timeUntilExpiry = expiresAt.difference(now);

    // Necesita refresco si expira en menos de 5 minutos
    final needsRefresh = timeUntilExpiry.inMinutes < 5;
    final isHealthy = timeUntilExpiry.inMinutes > 0;

    return TokenStatus(
      hasToken: true,
      needsRefresh: needsRefresh,
      isRefreshing: _isRefreshing,
      expiresAt: expiresAt,
      timeUntilExpiry: timeUntilExpiry,
      isHealthy: isHealthy,
      error: isHealthy ? null : 'Token expired',
    );
  }

  /// Verifica si el token está cerca de expirar
  Future<bool> isTokenNearExpiry() async {
    final status = await getTokenStatus();
    return status.needsRefresh;
  }

  /// Limpia recursos
  void dispose() {
    _refreshTimer?.cancel();
    _eventController.close();
    _isInitialized = false;
    LoggerFactory.info('🧹 TokenRefreshService disposed');
  }
}
