import 'dart:async';

import '../error_handling/centralized_error_handler.dart';
import '../logging/logger_factory.dart';

/// Maneja timeouts específicos para operaciones de autenticación
class AuthTimeoutHandler {
  AuthTimeoutHandler._();
  static final AuthTimeoutHandler _instance = AuthTimeoutHandler._();
  static AuthTimeoutHandler get instance => _instance;

  // Configuración de timeouts específicos para auth
  static const Duration _loginTimeout = Duration(seconds: 30);
  static const Duration _signupTimeout = Duration(seconds: 45);
  static const Duration _resetPasswordTimeout = Duration(seconds: 20);
  static const Duration _tokenRefreshTimeout = Duration(seconds: 15);
  static const Duration _logoutTimeout = Duration(seconds: 10);

  /// Ejecuta una operación de login con timeout específico
  Future<T> executeLogin<T>(Future<T> Function() operation) async {
    return await _executeWithAuthTimeout(
      operation,
      timeout: _loginTimeout,
      operationName: 'Login',
      context: OperationContext.authentication,
    );
  }

  /// Ejecuta una operación de signup con timeout específico
  Future<T> executeSignup<T>(Future<T> Function() operation) async {
    return await _executeWithAuthTimeout(
      operation,
      timeout: _signupTimeout,
      operationName: 'Signup',
      context: OperationContext.authentication,
    );
  }

  /// Ejecuta una operación de reset password con timeout específico
  Future<T> executeResetPassword<T>(Future<T> Function() operation) async {
    return await _executeWithAuthTimeout(
      operation,
      timeout: _resetPasswordTimeout,
      operationName: 'Reset Password',
      context: OperationContext.authentication,
    );
  }

  /// Ejecuta una operación de refresh token con timeout específico
  Future<T> executeTokenRefresh<T>(Future<T> Function() operation) async {
    return await _executeWithAuthTimeout(
      operation,
      timeout: _tokenRefreshTimeout,
      operationName: 'Token Refresh',
      context: OperationContext.authentication,
    );
  }

  /// Ejecuta una operación de logout con timeout específico
  Future<T> executeLogout<T>(Future<T> Function() operation) async {
    return await _executeWithAuthTimeout(
      operation,
      timeout: _logoutTimeout,
      operationName: 'Logout',
      context: OperationContext.authentication,
    );
  }

  /// Método genérico que ejecuta operaciones auth con timeout y error handling
  Future<T> _executeWithAuthTimeout<T>(
    Future<T> Function() operation, {
    required Duration timeout,
    required String operationName,
    required OperationContext context,
  }) async {
    try {
      LoggerFactory.info(
          '🔐 Iniciando $operationName (timeout: ${timeout.inSeconds}s)');

      final result = await operation().timeout(timeout);

      LoggerFactory.info('✅ $operationName completado exitosamente');
      return result;
    } on TimeoutException catch (e) {
      final timeoutError = AuthTimeoutException(
        operationName: operationName,
        timeoutDuration: timeout,
        originalError: e,
      );

      LoggerFactory.error(
          '⏰ Timeout en $operationName después de ${timeout.inSeconds}s');

      // Procesar error a través del sistema centralizado
      final processedError = await CentralizedErrorHandler().processError(
        timeoutError,
        null,
        context: context,
      );

      throw processedError;
    } catch (e) {
      LoggerFactory.error('❌ Error en $operationName: $e');

      // Procesar cualquier otro error a través del sistema centralizado
      final processedError = await CentralizedErrorHandler().processError(
        e,
        null,
        context: context,
      );

      throw processedError;
    }
  }
}

/// Excepción específica para timeouts de autenticación
class AuthTimeoutException implements Exception {
  const AuthTimeoutException({
    required this.operationName,
    required this.timeoutDuration,
    this.originalError,
  });

  final String operationName;
  final Duration timeoutDuration;
  final Exception? originalError;

  @override
  String toString() {
    return 'AuthTimeoutException: $operationName timeout after ${timeoutDuration.inSeconds}s';
  }
}

/// Excepción para problemas específicos de conectividad en auth
class AuthConnectivityException implements Exception {
  const AuthConnectivityException({
    required this.operationName,
    this.originalError,
  });

  final String operationName;
  final Exception? originalError;

  @override
  String toString() {
    return 'AuthConnectivityException: No network connection for $operationName';
  }
}

/// Excepción para límites de velocidad (rate limiting)
class AuthRateLimitException implements Exception {
  const AuthRateLimitException({
    required this.operationName,
    this.retryAfter,
    this.originalError,
  });

  final String operationName;
  final Duration? retryAfter;
  final Exception? originalError;

  @override
  String toString() {
    final retryMessage =
        retryAfter != null ? ' (retry after ${retryAfter!.inSeconds}s)' : '';
    return 'AuthRateLimitException: Rate limit exceeded for $operationName$retryMessage';
  }
}
