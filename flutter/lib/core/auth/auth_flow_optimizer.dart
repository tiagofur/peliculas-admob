import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../infrastructure/services/auth_session_manager.dart';
import '../../infrastructure/services/token_refresh_service.dart';
import '../config/supabase_config.dart';
import '../logging/logger_factory.dart';

/// Estados del flujo de autenticación
enum AuthFlowState {
  initializing,
  recovering,
  authenticating,
  ready,
  error,
}

/// Eventos del flujo de autenticación
sealed class AuthFlowEvent {
  const AuthFlowEvent();
}

class FlowInitializingEvent extends AuthFlowEvent {
  const FlowInitializingEvent();
}

class FlowRecoveringEvent extends AuthFlowEvent {
  const FlowRecoveringEvent();
}

class FlowReadyEvent extends AuthFlowEvent {
  const FlowReadyEvent();
}

class FlowErrorEvent extends AuthFlowEvent {
  const FlowErrorEvent({required this.error, this.canRetry = true});
  final String error;
  final bool canRetry;
}

/// Optimizador de flujos de autenticación
class AuthFlowOptimizer {
  AuthFlowOptimizer._();

  static final AuthFlowOptimizer _instance = AuthFlowOptimizer._();
  static AuthFlowOptimizer get instance => _instance;

  final SupabaseClient _supabase = SupabaseConfig.client;
  final AuthSessionManager _sessionManager = AuthSessionManager.instance;
  final TokenRefreshService _tokenRefreshService = TokenRefreshService.instance;

  final StreamController<AuthFlowEvent> _eventController =
      StreamController<AuthFlowEvent>.broadcast();

  bool _isInitialized = false;
  bool _isOptimizing = false;
  AuthFlowState _currentState = AuthFlowState.initializing;
  Timer? _startupTimer;
  Completer<bool>? _startupCompleter;

  // Configuration
  static const Duration _startupTimeoutDuration = Duration(seconds: 30);
  static const Duration _sessionRecoveryTimeout = Duration(seconds: 10);
  static const int _maxStartupRetries = 3;

  int _startupRetryCount = 0;

  /// Stream de eventos del flujo
  Stream<AuthFlowEvent> get events => _eventController.stream;

  /// Estado actual del flujo
  AuthFlowState get currentState => _currentState;

  /// Indica si el optimizador está ejecutándose
  bool get isOptimizing => _isOptimizing;

  /// Inicializa el optimizador de flujos
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      LoggerFactory.info('🚀 Initializing AuthFlowOptimizer');

      // Listen to auth state changes for flow optimization
      _supabase.auth.onAuthStateChange.listen((data) {
        _handleAuthStateChange(data.event, data.session);
      });

      _isInitialized = true;
      LoggerFactory.info('✅ AuthFlowOptimizer initialized');
    } catch (e) {
      LoggerFactory.error('❌ Failed to initialize AuthFlowOptimizer: $e');
      rethrow;
    }
  }

  /// Optimiza el flujo de inicio de la aplicación
  Future<bool> optimizeStartupFlow() async {
    if (_isOptimizing) {
      LoggerFactory.warning('⚠️ Startup optimization already in progress');
      return await (_startupCompleter?.future ?? Future.value(false));
    }

    _isOptimizing = true;
    _startupCompleter = Completer<bool>();
    _currentState = AuthFlowState.initializing;
    _eventController.add(const FlowInitializingEvent());

    LoggerFactory.info('🔧 Starting startup flow optimization');

    // Set timeout for startup process
    _startupTimer = Timer(_startupTimeoutDuration, () {
      if (!_startupCompleter!.isCompleted) {
        _handleStartupFailure('Startup timeout exceeded');
      }
    });

    try {
      // Step 1: Initialize core services concurrently
      final futures = [
        _sessionManager.initialize(),
        _tokenRefreshService.initialize(),
      ];

      await Future.wait(futures).timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            throw TimeoutException('Service initialization timeout'),
      );

      // Step 2: Attempt session recovery with timeout
      final recoverySuccess = await _attemptSessionRecovery();

      if (recoverySuccess) {
        _completeStartup(true);
      } else {
        // No session to recover - ready for new authentication
        _completeStartup(false);
      }

      return _startupCompleter!.future;
    } catch (e) {
      _handleStartupFailure(e.toString());
      return false;
    }
  }

  /// Optimiza el flujo de login
  Future<bool> optimizeLoginFlow({
    required String email,
    required String password,
  }) async {
    LoggerFactory.info('🔑 Optimizing login flow for: $email');
    _currentState = AuthFlowState.authenticating;

    try {
      // Pre-validate inputs
      if (!_isValidEmail(email) || password.length < 6) {
        throw Exception('Invalid credentials format');
      }

      // Perform optimized login
      final response = await _supabase.auth
          .signInWithPassword(
            email: email,
            password: password,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Login timeout'),
          );

      if (response.user != null) {
        LoggerFactory.info('✅ Login flow optimized successfully');
        _currentState = AuthFlowState.ready;
        _eventController.add(const FlowReadyEvent());
        return true;
      }

      throw Exception('Login failed: No user in response');
    } catch (e) {
      final errorMessage = 'Login optimization failed: $e';
      LoggerFactory.error('❌ $errorMessage');
      _currentState = AuthFlowState.error;
      _eventController.add(FlowErrorEvent(error: errorMessage));
      return false;
    }
  }

  /// Optimiza el flujo de logout
  Future<bool> optimizeLogoutFlow() async {
    LoggerFactory.info('👋 Optimizing logout flow');

    try {
      // Concurrent cleanup operations
      final futures = [
        _supabase.auth.signOut(),
        _sessionManager.clearSession(),
      ];

      await Future.wait(futures, eagerError: false).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          LoggerFactory.warning('⚠️ Logout timeout, forcing cleanup');
          return <void>[];
        },
      );

      LoggerFactory.info('✅ Logout flow optimized successfully');
      _currentState = AuthFlowState.ready;
      return true;
    } catch (e) {
      LoggerFactory.error('❌ Logout optimization failed: $e');
      // Even if logout fails, consider it successful to prevent stuck states
      return true;
    }
  }

  /// Intenta recuperar la sesión con timeout optimizado
  Future<bool> _attemptSessionRecovery() async {
    _currentState = AuthFlowState.recovering;
    _eventController.add(const FlowRecoveringEvent());

    try {
      LoggerFactory.info('🔄 Attempting optimized session recovery');

      final hasPersistedSession = await _sessionManager
          .hasPersistedSession()
          .timeout(_sessionRecoveryTimeout);

      if (!hasPersistedSession) {
        LoggerFactory.info('ℹ️ No persisted session found');
        return false;
      }

      final recoverySuccess = await _sessionManager
          .recoverSession()
          .timeout(_sessionRecoveryTimeout);

      if (recoverySuccess) {
        // Validate recovered session
        final isValid = await _sessionManager
            .validateCurrentSession()
            .timeout(const Duration(seconds: 3));

        if (isValid) {
          LoggerFactory.info('✅ Session recovery optimized successfully');
          return true;
        } else {
          LoggerFactory.warning('⚠️ Recovered session is invalid');
          return false;
        }
      }

      LoggerFactory.info('ℹ️ Session recovery not needed');
      return false;
    } catch (e) {
      LoggerFactory.error('❌ Session recovery failed: $e');
      return false;
    }
  }

  /// Maneja cambios de estado de autenticación
  void _handleAuthStateChange(AuthChangeEvent event, Session? session) {
    switch (event) {
      case AuthChangeEvent.signedIn:
        if (session?.user != null) {
          _currentState = AuthFlowState.ready;
          _eventController.add(const FlowReadyEvent());
        }
        break;
      case AuthChangeEvent.signedOut:
        _currentState = AuthFlowState.initializing;
        break;
      case AuthChangeEvent.tokenRefreshed:
        // Keep current state, just log the refresh
        LoggerFactory.debug('🔄 Token refreshed during flow optimization');
        break;
      default:
        break;
    }
  }

  /// Completa el proceso de startup
  void _completeStartup(bool sessionRecovered) {
    _startupTimer?.cancel();
    _isOptimizing = false;
    _currentState = AuthFlowState.ready;
    _startupRetryCount = 0;

    final message = sessionRecovered
        ? 'Startup completed with session recovery'
        : 'Startup completed, ready for authentication';

    LoggerFactory.info('✅ $message');
    _eventController.add(const FlowReadyEvent());

    if (!_startupCompleter!.isCompleted) {
      _startupCompleter!.complete(sessionRecovered);
    }
  }

  /// Maneja fallos en el startup con retry logic
  void _handleStartupFailure(String error) {
    _startupTimer?.cancel();

    _startupRetryCount++;
    final errorMessage = 'Startup attempt $_startupRetryCount failed: $error';

    LoggerFactory.error('❌ $errorMessage');

    if (_startupRetryCount < _maxStartupRetries) {
      LoggerFactory.info('🔄 Retrying startup optimization...');
      _isOptimizing = false;

      // Schedule retry
      Timer(const Duration(seconds: 2), () {
        optimizeStartupFlow();
      });
    } else {
      _isOptimizing = false;
      _currentState = AuthFlowState.error;

      const finalError =
          'Startup failed permanently after $_maxStartupRetries attempts';
      LoggerFactory.error('💥 $finalError');

      _eventController
          .add(const FlowErrorEvent(error: finalError, canRetry: false));

      if (!_startupCompleter!.isCompleted) {
        _startupCompleter!.complete(false);
      }
    }
  }

  /// Valida formato de email
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Limpia recursos
  void dispose() {
    _startupTimer?.cancel();
    _eventController.close();
    _isInitialized = false;
    LoggerFactory.info('🧹 AuthFlowOptimizer disposed');
  }
}
