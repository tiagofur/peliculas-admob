import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/logging/logger_factory.dart';
import '../../core/services/intelligent_retry_logic.dart';
import '../../domain/entities/sync_operation.dart';
import 'auth_session_manager.dart';

/// Servicio para manejar el refresco automático de tokens de autenticación
class TokenRefreshService {
  TokenRefreshService._();
  static TokenRefreshService? _instance;
  static TokenRefreshService get instance =>
      _instance ??= TokenRefreshService._();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final AuthSessionManager _sessionManager = AuthSessionManager.instance;
  final IntelligentRetryLogic _retryLogic = IntelligentRetryLogic();

  // Configuración
  static const Duration _checkInterval = Duration(minutes: 2);
  static const Duration _refreshThreshold =
      Duration(minutes: 10); // Refrescar 10 min antes de expirar
  static const Duration _maxTokenAge =
      Duration(hours: 23); // JWT típicamente expira en 24h

  Timer? _refreshTimer;
  bool _isRefreshing = false;
  bool _isInitialized = false;
  StreamSubscription<AuthState>? _authSubscription;

  // Stream controllers para notificaciones
  final StreamController<TokenRefreshEvent> _eventController =
      StreamController<TokenRefreshEvent>.broadcast();

  /// Stream de eventos de refresco de tokens
  Stream<TokenRefreshEvent> get events => _eventController.stream;

  /// Inicializa el servicio de refresco automático
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Escuchar cambios de autenticación
      _authSubscription =
          _supabase.auth.onAuthStateChange.listen(_onAuthStateChange);

      // Iniciar monitoreo si hay usuario autenticado
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null) {
        await _startTokenMonitoring();
      }

      _isInitialized = true;

      if (kDebugMode) {
        LoggerFactory.info('✅ TokenRefreshService inicializado correctamente');
      }
    } catch (e) {
      LoggerFactory.error('❌ Error inicializando TokenRefreshService: $e');
      rethrow;
    }
  }

  /// Maneja cambios en el estado de autenticación
  void _onAuthStateChange(AuthState data) {
    final user = data.session?.user;

    if (user != null && data.event == AuthChangeEvent.signedIn) {
      // Usuario se autentica, iniciar monitoreo
      _startTokenMonitoring();
      _eventController.add(TokenRefreshEvent.userSignedIn(user.id));
    } else if (user == null && data.event == AuthChangeEvent.signedOut) {
      // Usuario sale, detener monitoreo
      _stopTokenMonitoring();
      _eventController.add(TokenRefreshEvent.userSignedOut());
    } else if (data.event == AuthChangeEvent.tokenRefreshed) {
      // Token refrescado exitosamente
      final session = data.session;
      if (session != null) {
        _sessionManager.persistSession(session);
        _eventController.add(TokenRefreshEvent.tokenRefreshed(session.user.id));
      }
    }
  }

  /// Inicia el monitoreo automático de tokens
  Future<void> _startTokenMonitoring() async {
    if (_refreshTimer != null) return;

    _refreshTimer = Timer.periodic(_checkInterval, (timer) async {
      await _checkAndRefreshToken();
    });

    // Verificar inmediatamente al iniciar
    await _checkAndRefreshToken();

    if (kDebugMode) {
      LoggerFactory.info('🔄 Monitoreo automático de tokens iniciado');
    }
  }

  /// Detiene el monitoreo automático
  void _stopTokenMonitoring() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _isRefreshing = false;

    if (kDebugMode) {
      LoggerFactory.info('⏹️ Monitoreo automático de tokens detenido');
    }
  }

  /// Verifica si el token necesita ser refrescado y lo refresca si es necesario
  Future<void> _checkAndRefreshToken() async {
    if (_isRefreshing) return;

    try {
      final session = _supabase.auth.currentSession;
      if (session == null) return;

      final needsRefresh = _shouldRefreshToken(session);

      if (needsRefresh) {
        await _performTokenRefresh(session);
      }
    } catch (e) {
      LoggerFactory.error('❌ Error verificando/refrescando token: $e');
      _eventController.add(TokenRefreshEvent.refreshFailed(e.toString()));
    }
  }

  /// Determina si el token necesita ser refrescado
  bool _shouldRefreshToken(Session session) {
    final now = DateTime.now();

    // Verificar si el token expira pronto
    if (session.expiresAt != null) {
      final expiresAt =
          DateTime.fromMillisecondsSinceEpoch((session.expiresAt ?? 0) * 1000);
      final timeUntilExpiry = expiresAt.difference(now);

      if (timeUntilExpiry <= _refreshThreshold) {
        if (kDebugMode) {
          LoggerFactory.info(
              '🔄 Token expira en ${timeUntilExpiry.inMinutes} minutos, refrescando');
        }
        return true;
      }
    }

    // Verificar edad máxima del token (por seguridad)
    final tokenIssueTime =
        DateTime.fromMillisecondsSinceEpoch((session.expiresAt ?? 0) * 1000)
            .subtract(const Duration(hours: 24)); // Asumir duración estándar

    if (now.difference(tokenIssueTime) >= _maxTokenAge) {
      if (kDebugMode) {
        LoggerFactory.info(
            '⏰ Token demasiado antiguo, refrescando por seguridad');
      }
      return true;
    }

    return false;
  }

  /// Realiza el refresco del token con lógica de retry
  Future<void> _performTokenRefresh(Session session) async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    _eventController.add(TokenRefreshEvent.refreshStarted(session.user.id));

    try {
      final result = await _retryLogic.executeWithRetry(
        SyncOperation(
          id: 'token_refresh_${DateTime.now().millisecondsSinceEpoch}',
          type: SyncOperationType.tokenRefresh,
          data: {'userId': session.user.id},
          createdAt: DateTime.now(),
          maxRetries: 3,
        ),
        () async {
          final response =
              await _supabase.auth.refreshSession(session.refreshToken);

          if (response.session == null) {
            throw Exception('Token refresh devolvió sesión nula');
          }

          // Persistir nueva sesión
          if (response.session != null) {
            await _sessionManager.persistSession(response.session!);
          }

          if (kDebugMode) {
            LoggerFactory.info('✅ Token refrescado exitosamente');
          }

          return response.session ?? (throw Exception('Session is null after refresh'));
        },
      );

      if (!result.success) {
        throw Exception('Token refresh failed: ${result.error}');
      }
    } catch (e) {
      LoggerFactory.error(
          '❌ Error refrescando token después de reintentos: $e');
      _eventController.add(TokenRefreshEvent.refreshFailed(e.toString()));

      // Si el refresh falla completamente, limpiar sesión y forzar re-login
      await _handleRefreshFailure();
    } finally {
      _isRefreshing = false;
    }
  }

  /// Maneja fallos críticos en el refresco de tokens
  Future<void> _handleRefreshFailure() async {
    try {
      // Limpiar sesión local
      await _sessionManager.clearSession();

      // Cerrar sesión en Supabase
      await _supabase.auth.signOut();

      _eventController.add(TokenRefreshEvent.sessionInvalidated());

      if (kDebugMode) {
        LoggerFactory.warning('⚠️ Sesión invalidada debido a fallo en refresh');
      }
    } catch (e) {
      LoggerFactory.error('❌ Error manejando fallo de refresh: $e');
    }
  }

  /// Fuerza un refresco inmediato del token
  Future<bool> forceRefresh() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) return false;

      await _performTokenRefresh(session);
      return true;
    } catch (e) {
      LoggerFactory.error('❌ Error en refresco forzado: $e');
      return false;
    }
  }

  /// Verifica si un token está próximo a expirar
  Future<bool> isTokenNearExpiry() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) return false;

      return _shouldRefreshToken(session);
    } catch (e) {
      LoggerFactory.error('❌ Error verificando expiración de token: $e');
      return false;
    }
  }

  /// Obtiene información sobre el estado del token
  Future<TokenStatus> getTokenStatus() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        return TokenStatus.noToken();
      }

      final now = DateTime.now();
      final expiresAt = session.expiresAt != null
          ? DateTime.fromMillisecondsSinceEpoch((session.expiresAt ?? 0) * 1000)
          : null;

      return TokenStatus(
        hasToken: true,
        isValid: await _sessionManager.validateCurrentSession(),
        expiresAt: expiresAt,
        timeUntilExpiry: expiresAt?.difference(now),
        needsRefresh: _shouldRefreshToken(session),
        isRefreshing: _isRefreshing,
      );
    } catch (e) {
      LoggerFactory.error('❌ Error obteniendo estado de token: $e');
      return TokenStatus.error(e.toString());
    }
  }

  /// Libera recursos del servicio
  void dispose() {
    _stopTokenMonitoring();
    _authSubscription?.cancel();
    _eventController.close();
    _isInitialized = false;
  }
}

/// Eventos del servicio de refresco de tokens
sealed class TokenRefreshEvent {
  const TokenRefreshEvent();

  factory TokenRefreshEvent.userSignedIn(String userId) = UserSignedInEvent;
  factory TokenRefreshEvent.userSignedOut() = UserSignedOutEvent;
  factory TokenRefreshEvent.refreshStarted(String userId) = RefreshStartedEvent;
  factory TokenRefreshEvent.tokenRefreshed(String userId) = TokenRefreshedEvent;
  factory TokenRefreshEvent.refreshFailed(String error) = RefreshFailedEvent;
  factory TokenRefreshEvent.sessionInvalidated() = SessionInvalidatedEvent;
}

class UserSignedInEvent extends TokenRefreshEvent {
  const UserSignedInEvent(this.userId);
  final String userId;
}

class UserSignedOutEvent extends TokenRefreshEvent {
  const UserSignedOutEvent();
}

class RefreshStartedEvent extends TokenRefreshEvent {
  const RefreshStartedEvent(this.userId);
  final String userId;
}

class TokenRefreshedEvent extends TokenRefreshEvent {
  const TokenRefreshedEvent(this.userId);
  final String userId;
}

class RefreshFailedEvent extends TokenRefreshEvent {
  const RefreshFailedEvent(this.error);
  final String error;
}

class SessionInvalidatedEvent extends TokenRefreshEvent {
  const SessionInvalidatedEvent();
}

/// Estado del token de autenticación
class TokenStatus {
  const TokenStatus({
    required this.hasToken,
    required this.isValid,
    this.expiresAt,
    this.timeUntilExpiry,
    this.needsRefresh = false,
    this.isRefreshing = false,
    this.error,
  });

  factory TokenStatus.noToken() => const TokenStatus(
        hasToken: false,
        isValid: false,
      );

  factory TokenStatus.error(String error) => TokenStatus(
        hasToken: false,
        isValid: false,
        error: error,
      );

  final bool hasToken;
  final bool isValid;
  final DateTime? expiresAt;
  final Duration? timeUntilExpiry;
  final bool needsRefresh;
  final bool isRefreshing;
  final String? error;

  bool get isHealthy => hasToken && isValid && !needsRefresh && error == null;
}
