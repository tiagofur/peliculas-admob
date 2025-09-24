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
  Timer? _backgroundRefreshTimer;

  // Exponential backoff configuration
  int _retryAttempt = 0;
  static const int _maxRetries = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 2);
  static const Duration _maxRetryDelay = Duration(minutes: 1);

  // Background refresh configuration
  static const Duration _backgroundRefreshInterval = Duration(minutes: 30);
  static const int _refreshThresholdMinutes = 5; // Refresh when < 5 min left

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
              _startBackgroundRefresh();
              _retryAttempt = 0; // Reset retry counter on successful auth
            }
            break;
          case AuthChangeEvent.signedOut:
            _eventController.add(const UserSignedOutEvent());
            _stopBackgroundRefresh();
            _retryAttempt = 0; // Reset retry counter on signout
            break;
          case AuthChangeEvent.tokenRefreshed:
            if (session?.user != null) {
              _eventController
                  .add(TokenRefreshedEvent(userId: session!.user.id));
              _retryAttempt = 0; // Reset retry counter on successful refresh
            }
            break;
          default:
            break;
        }
      });

      // Start background refresh if user is already authenticated
      if (_supabase.auth.currentSession != null) {
        _startBackgroundRefresh();
      }

      _isInitialized = true;
      LoggerFactory.info('✅ TokenRefreshService initialized');
    } catch (e) {
      LoggerFactory.error('❌ Failed to initialize TokenRefreshService: $e');
      rethrow;
    }
  }

  /// Fuerza un refresco del token con exponential backoff
  Future<bool> forceRefresh([bool isRetry = false]) async {
    if (_isRefreshing) {
      LoggerFactory.warning('⚠️ Token refresh already in progress');
      return false;
    }

    final session = _supabase.auth.currentSession;
    if (session == null) {
      LoggerFactory.warning('⚠️ No active session to refresh');
      return false;
    }

    if (!isRetry) {
      _retryAttempt = 0; // Reset retry counter for new refresh attempts
    }

    _isRefreshing = true;
    _eventController.add(RefreshStartedEvent(userId: session.user.id));

    try {
      final response = await _supabase.auth.refreshSession();

      if (response.session != null) {
        _eventController
            .add(TokenRefreshedEvent(userId: response.session!.user.id));
        LoggerFactory.info('✅ Token refreshed successfully');
        _retryAttempt = 0; // Reset on success
        return true;
      } else {
        throw Exception('No session in response');
      }
    } catch (e) {
      _retryAttempt++;
      final errorMessage = e.toString();

      LoggerFactory.error(
          '❌ Token refresh failed (attempt $_retryAttempt/$_maxRetries): $errorMessage');

      // Try retry with exponential backoff
      if (_retryAttempt < _maxRetries) {
        final retryDelay = _calculateRetryDelay();
        LoggerFactory.info(
            '🔄 Retrying token refresh in ${retryDelay.inSeconds}s...');

        _eventController.add(RefreshFailedEvent(
            error:
                'Retry $_retryAttempt/$_maxRetries in ${retryDelay.inSeconds}s'));

        // Schedule retry
        Timer(retryDelay, () async {
          _isRefreshing = false; // Reset flag for retry
          await forceRefresh(true); // Mark as retry
        });

        return false;
      } else {
        // Max retries exceeded
        _eventController.add(RefreshFailedEvent(error: errorMessage));
        _eventController.add(const SessionInvalidatedEvent());
        LoggerFactory.error(
            '💥 Token refresh failed permanently after $_maxRetries attempts');
        return false;
      }
    } finally {
      if (_retryAttempt >= _maxRetries || _retryAttempt == 0) {
        _isRefreshing = false;
      }
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

    // Necesita refresco si expira en menos del threshold configurado
    final needsRefresh = timeUntilExpiry.inMinutes < _refreshThresholdMinutes;
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

  /// Inicia el refresh automático en segundo plano
  void _startBackgroundRefresh() {
    _stopBackgroundRefresh(); // Stop existing timer first

    _backgroundRefreshTimer =
        Timer.periodic(_backgroundRefreshInterval, (_) async {
      try {
        final status = await getTokenStatus();
        if (status.needsRefresh && !_isRefreshing) {
          LoggerFactory.info('🔄 Background token refresh triggered');
          await forceRefresh();
        }
      } catch (e) {
        LoggerFactory.error('❌ Background token refresh check failed: $e');
      }
    });

    LoggerFactory.info(
        '✅ Background token refresh started (interval: ${_backgroundRefreshInterval.inMinutes}min)');
  }

  /// Detiene el refresh automático en segundo plano
  void _stopBackgroundRefresh() {
    _backgroundRefreshTimer?.cancel();
    _backgroundRefreshTimer = null;
    LoggerFactory.info('🛑 Background token refresh stopped');
  }

  /// Calcula el delay para retry con exponential backoff
  Duration _calculateRetryDelay() {
    final exponentialDelay = Duration(
      milliseconds:
          (_baseRetryDelay.inMilliseconds * (1 << (_retryAttempt - 1))).clamp(
        _baseRetryDelay.inMilliseconds,
        _maxRetryDelay.inMilliseconds,
      ),
    );

    // Add jitter (±25% random variation)
    final jitterFactor = 0.75 + (0.5 * (DateTime.now().millisecond / 1000));
    final jitteredDelay = Duration(
      milliseconds: (exponentialDelay.inMilliseconds * jitterFactor).round(),
    );

    return jitteredDelay;
  }

  /// Limpia recursos
  void dispose() {
    _refreshTimer?.cancel();
    _stopBackgroundRefresh();
    _eventController.close();
    _isInitialized = false;
    LoggerFactory.info('🧹 TokenRefreshService disposed');
  }
}
