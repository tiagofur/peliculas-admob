import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:url_launcher/url_launcher.dart';

import '../../config/router/app_router.dart';
import '../exceptions/app_exceptions.dart';
import '../logging/logger_factory.dart';

/// Información detallada del error para presentación al usuario
class UserFriendlyError {
  const UserFriendlyError({
    required this.title,
    required this.message,
    required this.actionable,
    this.retryCallback,
    this.primaryAction,
    this.secondaryAction,
    this.severity = ErrorSeverity.medium,
  });

  final String title;
  final String message;
  final bool actionable; // Si el usuario puede hacer algo para solucionarlo
  final VoidCallback? retryCallback;
  final ErrorAction? primaryAction;
  final ErrorAction? secondaryAction;
  final ErrorSeverity severity;
}

/// Acción que el usuario puede tomar para resolver un error
class ErrorAction {
  const ErrorAction({
    required this.label,
    required this.callback,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback callback;
  final bool isDestructive;
}

/// Severidad del error para determinar la presentación
enum ErrorSeverity {
  low, // Info/warning - no bloquea funcionalidad
  medium, // Error recuperable - funcionalidad limitada
  high, // Error crítico - funcionalidad principal afectada
  critical, // Error fatal - app no funcional
}

/// Contexto operacional donde ocurrió el error
enum OperationContext {
  authentication,
  dataLoading,
  dataSync,
  userAction,
  background,
  initialization,
  network,
  storage,
}

/// Servicio centralizado para manejo de errores con UX mejorada
class CentralizedErrorHandler {
  factory CentralizedErrorHandler() => _instance;
  CentralizedErrorHandler._internal();
  static final CentralizedErrorHandler _instance =
      CentralizedErrorHandler._internal();

  /// Procesa un error y devuelve información user-friendly
  Future<UserFriendlyError> processError(
    dynamic error,
    StackTrace? stackTrace, {
    OperationContext? context,
    Map<String, dynamic>? additionalData,
    VoidCallback? retryCallback,
  }) async {
    // Log del error original para debugging
    LoggerFactory.error(
        'Processing error in context: ${context?.name} - $error',
        stackTrace: stackTrace);

    // Report al sistema de error reporting
    await LoggerFactory.reportCriticalError(
      error,
      stackTrace,
      context: 'CentralizedErrorHandler.${context?.name ?? 'unknown'}',
      data: {
        'operation_context': context?.name ?? 'unknown',
        'user_friendly_processing': true,
        ...?additionalData,
      },
      fatal: false,
    );

    // Mapear error a información user-friendly
    return _mapErrorToUserFriendly(error, context, retryCallback);
  }

  /// Mapea errores específicos a mensajes user-friendly
  UserFriendlyError _mapErrorToUserFriendly(
    dynamic error,
    OperationContext? context,
    VoidCallback? retryCallback,
  ) {
    // Network Errors
    if (error is NetworkException || _isNetworkError(error)) {
      return _handleNetworkError(error, context, retryCallback);
    }

    // Authentication Timeout Errors (check before general auth errors)
    if (_isAuthTimeoutError(error)) {
      return _handleAuthTimeoutError(error, context, retryCallback);
    }

    // Authentication Errors
    if (error is AuthException || _isAuthError(error)) {
      return _handleAuthError(error, context, retryCallback);
    }

    // API Errors
    if (error is ApiException || _isApiError(error)) {
      return _handleApiError(error, context, retryCallback);
    }

    // Validation Errors
    if (error is ValidationException) {
      return _handleValidationError(error, context, retryCallback);
    }

    // Storage/Database Errors
    if (_isStorageError(error)) {
      return _handleStorageError(error, context, retryCallback);
    }

    // Gamification Errors
    if (error is GamificationException) {
      return _handleGamificationError(error, context, retryCallback);
    }

    // Supabase specific errors
    if (error is PostgrestException) {
      return _handleSupabaseError(error, context, retryCallback);
    }

    // Generic error fallback
    return _handleGenericError(error, context, retryCallback);
  }

  /// Maneja errores de red con diferentes contextos
  UserFriendlyError _handleNetworkError(
    dynamic error,
    OperationContext? context,
    VoidCallback? retryCallback,
  ) {
    if (error is NetworkException) {
      switch (error.code) {
        case 'NO_CONNECTION':
          return UserFriendlyError(
            title: '🌐 Sin conexión',
            message:
                'Parece que no tienes conexión a internet. Verifica tu red y vuelve a intentar.',
            actionable: true,
            retryCallback: retryCallback,
            primaryAction: retryCallback != null
                ? ErrorAction(
                    label: 'Reintentar',
                    callback: retryCallback,
                  )
                : null,
            severity: ErrorSeverity.high,
          );

        case 'TIMEOUT':
          return UserFriendlyError(
            title: '⏱️ Conexión lenta',
            message:
                'La operación está tardando más de lo normal. Tu conexión podría estar lenta.',
            actionable: true,
            retryCallback: retryCallback,
            primaryAction: retryCallback != null
                ? ErrorAction(
                    label: 'Reintentar',
                    callback: retryCallback,
                  )
                : null,
            severity: ErrorSeverity.medium,
          );
        default:
          return UserFriendlyError(
            title: '📶 Problema de conexión',
            message:
                'No pudimos conectarnos con nuestros servidores. Inténtalo de nuevo.',
            actionable: true,
            retryCallback: retryCallback,
            primaryAction: retryCallback != null
                ? ErrorAction(
                    label: 'Reintentar',
                    callback: retryCallback,
                  )
                : null,
            severity: ErrorSeverity.medium,
          );
      }
    }

    // Fallback for generic network errors
    return UserFriendlyError(
      title: '📶 Error de conexión',
      message:
          'Hubo un problema con la conexión. Por favor, verifica tu internet.',
      actionable: true,
      retryCallback: retryCallback,
      primaryAction: retryCallback != null
          ? ErrorAction(
              label: 'Reintentar',
              callback: retryCallback,
            )
          : null,
      severity: ErrorSeverity.medium,
    );
  }

  /// Maneja errores de autenticación
  UserFriendlyError _handleAuthError(
    dynamic error,
    OperationContext? context,
    VoidCallback? retryCallback,
  ) {
    if (error is AuthException) {
      switch (error.code) {
        case 'UNAUTHORIZED':
          return UserFriendlyError(
            title: '🔐 Sesión expirada',
            message:
                'Tu sesión ha expirado. Por favor, inicia sesión nuevamente.',
            actionable: true,
            severity: ErrorSeverity.high,
            primaryAction: ErrorAction(
              label: 'Iniciar sesión',
              callback: () => _navigateToLogin(),
            ),
          );

        case 'SESSION_EXPIRED':
          return UserFriendlyError(
            title: '⏰ Sesión expirada',
            message:
                'Tu sesión ha caducado por seguridad. Necesitas iniciar sesión de nuevo.',
            actionable: true,
            severity: ErrorSeverity.high,
            primaryAction: ErrorAction(
              label: 'Iniciar sesión',
              callback: () => _navigateToLogin(),
            ),
          );

        case 'INVALID_CREDENTIALS':
          return UserFriendlyError(
            title: '❌ Credenciales incorrectas',
            message: 'El email o contraseña que ingresaste no son correctos.',
            actionable: true,
            severity: ErrorSeverity.medium,
            primaryAction: retryCallback != null
                ? ErrorAction(
                    label: 'Intentar de nuevo',
                    callback: retryCallback,
                  )
                : null,
          );

        default:
          return UserFriendlyError(
            title: '🔒 Error de autenticación',
            message:
                'Hubo un problema con tu cuenta. Intenta iniciar sesión nuevamente.',
            actionable: true,
            severity: ErrorSeverity.high,
            primaryAction: ErrorAction(
              label: 'Iniciar sesión',
              callback: () => _navigateToLogin(),
            ),
          );
      }
    }

    return UserFriendlyError(
      title: '🔐 Problema de acceso',
      message:
          'No pudimos verificar tu identidad. Intenta iniciar sesión nuevamente.',
      actionable: true,
      severity: ErrorSeverity.high,
      primaryAction: ErrorAction(
        label: 'Iniciar sesión',
        callback: () => _navigateToLogin(),
      ),
    );
  }

  /// Maneja errores de API
  UserFriendlyError _handleApiError(
    dynamic error,
    OperationContext? context,
    VoidCallback? retryCallback,
  ) {
    if (error is ApiException) {
      switch (error.statusCode) {
        case 400:
          return UserFriendlyError(
            title: '❓ Solicitud incorrecta',
            message:
                'La información enviada no es válida. Verifica los datos e intenta nuevamente.',
            actionable: true,
            severity: ErrorSeverity.medium,
            retryCallback: retryCallback,
          );

        case 404:
          return const UserFriendlyError(
            title: '🔍 No encontrado',
            message: 'El contenido que buscas ya no está disponible.',
            actionable: false,
            severity: ErrorSeverity.low,
          );

        case 429:
          return UserFriendlyError(
            title: '🐌 Demasiadas solicitudes',
            message:
                'Has hecho muchas solicitudes muy rápido. Espera un momento e intenta de nuevo.',
            actionable: true,
            severity: ErrorSeverity.medium,
            primaryAction: ErrorAction(
              label: 'Esperar y reintentar',
              callback: () => _retryAfterDelay(retryCallback, 5),
            ),
          );

        case 500:
        case 502:
        case 503:
          return UserFriendlyError(
            title: '🛠️ Problema en el servidor',
            message:
                'Nuestros servidores están experimentando dificultades. Intenta más tarde.',
            actionable: true,
            severity: ErrorSeverity.high,
            retryCallback: retryCallback,
            primaryAction: retryCallback != null
                ? ErrorAction(
                    label: 'Reintentar',
                    callback: retryCallback,
                  )
                : null,
          );

        default:
          return UserFriendlyError(
            title: '🌐 Error del servicio',
            message:
                'Hubo un problema con el servicio. Intenta nuevamente en unos minutos.',
            actionable: true,
            severity: ErrorSeverity.medium,
            retryCallback: retryCallback,
          );
      }
    }

    return UserFriendlyError(
      title: '🌐 Error de servicio',
      message: 'No pudimos completar la operación. Inténtalo de nuevo.',
      actionable: true,
      severity: ErrorSeverity.medium,
      retryCallback: retryCallback,
    );
  }

  /// Maneja errores de validación
  UserFriendlyError _handleValidationError(
    ValidationException error,
    OperationContext? context,
    VoidCallback? retryCallback,
  ) {
    return UserFriendlyError(
      title: '📝 Datos incorrectos',
      message: error.message,
      actionable: true,
      severity: ErrorSeverity.low,
      retryCallback: retryCallback,
    );
  }

  /// Maneja errores de almacenamiento
  UserFriendlyError _handleStorageError(
    dynamic error,
    OperationContext? context,
    VoidCallback? retryCallback,
  ) {
    // Mensaje específico para Web
    if (kIsWeb) {
      return UserFriendlyError(
        title: '💾 Error de almacenamiento web',
        message: 'No pudimos guardar datos localmente. Esto puede ocurrir si:\n'
            '• Estás en modo incógnito/privado\n'
            '• El almacenamiento del navegador está lleno\n'
            '• Las cookies están bloqueadas\n\n'
            'Tu sesión se mantendrá activa igualmente.',
        actionable: true,
        severity: ErrorSeverity.low, // Bajamos severidad en Web
        retryCallback: retryCallback,
        primaryAction: retryCallback != null
            ? ErrorAction(
                label: 'Continuar',
                callback: retryCallback,
              )
            : null,
      );
    }

    // Mensaje para plataformas nativas
    return UserFriendlyError(
      title: '💾 Error de almacenamiento',
      message:
          'No pudimos guardar o leer los datos. Verifica que tengas espacio disponible.',
      actionable: true,
      severity: ErrorSeverity.medium,
      retryCallback: retryCallback,
      primaryAction: retryCallback != null
          ? ErrorAction(
              label: 'Reintentar',
              callback: retryCallback,
            )
          : null,
    );
  }

  /// Maneja errores de gamificación
  UserFriendlyError _handleGamificationError(
    GamificationException error,
    OperationContext? context,
    VoidCallback? retryCallback,
  ) {
    return const UserFriendlyError(
      title: '🎮 Error en logros',
      message:
          'Hubo un problema al actualizar tus logros. No te preocupes, los puntos se actualizarán pronto.',
      actionable: false,
      severity: ErrorSeverity.low,
    );
  }

  /// Maneja errores específicos de Supabase
  UserFriendlyError _handleSupabaseError(
    PostgrestException error,
    OperationContext? context,
    VoidCallback? retryCallback,
  ) {
    // Mapear códigos específicos de PostgreSQL
    switch (error.code) {
      case '23505': // unique_violation
        return const UserFriendlyError(
          title: '⚠️ Duplicado',
          message: 'Esta información ya existe. Intenta con datos diferentes.',
          actionable: true,
          severity: ErrorSeverity.medium,
        );

      case '23503': // foreign_key_violation
        return const UserFriendlyError(
          title: '🔗 Referencia inválida',
          message:
              'Los datos están relacionados con información que ya no existe.',
          actionable: false,
          severity: ErrorSeverity.medium,
        );

      case 'PGRST116': // JWT expired
        return UserFriendlyError(
          title: '🔐 Sesión expirada',
          message: 'Tu sesión ha caducado. Inicia sesión nuevamente.',
          actionable: true,
          severity: ErrorSeverity.high,
          primaryAction: ErrorAction(
            label: 'Iniciar sesión',
            callback: () => _navigateToLogin(),
          ),
        );

      default:
        return UserFriendlyError(
          title: '💾 Error de base de datos',
          message:
              'Hubo un problema al guardar los datos. Inténtalo nuevamente.',
          actionable: true,
          severity: ErrorSeverity.medium,
          retryCallback: retryCallback,
        );
    }
  }

  /// Maneja errores genéricos como fallback
  UserFriendlyError _handleGenericError(
    dynamic error,
    OperationContext? context,
    VoidCallback? retryCallback,
  ) {
    return UserFriendlyError(
      title: '❗ Algo salió mal',
      message:
          'Ocurrió un error inesperado. Nuestro equipo ha sido notificado.',
      actionable: true,
      severity: ErrorSeverity.medium,
      retryCallback: retryCallback,
      primaryAction: retryCallback != null
          ? ErrorAction(
              label: 'Reintentar',
              callback: retryCallback,
            )
          : null,
    );
  }

  // Helper methods para detectar tipos de error específicos de auth timeout

  /// Detecta errores específicos de timeout de autenticación
  bool _isAuthTimeoutError(dynamic error) {
    return error.runtimeType.toString().contains('AuthTimeout') ||
        error.runtimeType.toString().contains('AuthConnectivity') ||
        error.runtimeType.toString().contains('AuthRateLimit');
  }

  /// Maneja errores específicos de timeout y conectividad de auth
  UserFriendlyError _handleAuthTimeoutError(
    dynamic error,
    OperationContext? context,
    VoidCallback? retryCallback,
  ) {
    final errorStr = error.toString();

    if (errorStr.contains('AuthTimeout')) {
      return UserFriendlyError(
        title: '⏰ Operación demasiado lenta',
        message:
            'La operación de autenticación está tardando más de lo esperado. '
            'Verifica tu conexión a internet e intenta de nuevo.',
        actionable: true,
        severity: ErrorSeverity.medium,
        retryCallback: retryCallback,
        primaryAction: retryCallback != null
            ? ErrorAction(
                label: 'Reintentar',
                callback: retryCallback,
              )
            : null,
        secondaryAction: ErrorAction(
          label: 'Verificar conexión',
          callback: () => _showConnectivityHelp(),
        ),
      );
    }

    if (errorStr.contains('AuthConnectivity')) {
      return UserFriendlyError(
        title: '📶 Sin conexión',
        message: 'No se puede conectar al servidor. '
            'Verifica tu conexión a internet e intenta nuevamente.',
        actionable: true,
        severity: ErrorSeverity.high,
        retryCallback: retryCallback,
        primaryAction: retryCallback != null
            ? ErrorAction(
                label: 'Reintentar',
                callback: retryCallback,
              )
            : null,
        secondaryAction: ErrorAction(
          label: 'Configuración red',
          callback: () => _openNetworkSettings(),
        ),
      );
    }

    if (errorStr.contains('AuthRateLimit')) {
      return UserFriendlyError(
        title: '🚦 Demasiados intentos',
        message: 'Has realizado demasiados intentos de autenticación. '
            'Espera unos momentos antes de intentar de nuevo.',
        actionable: true,
        severity: ErrorSeverity.medium,
        primaryAction: ErrorAction(
          label: 'Intentar en 1 minuto',
          callback: () => _retryAfterDelay(retryCallback, 60),
        ),
        secondaryAction: ErrorAction(
          label: '¿Olvidaste tu contraseña?',
          callback: () => _navigateToPasswordReset(),
        ),
      );
    }

    // Fallback for any other auth timeout related errors
    return UserFriendlyError(
      title: '🔐 Problema de autenticación',
      message: 'Hubo un problema durante la autenticación. '
          'Por favor intenta de nuevo o contacta soporte si persiste.',
      actionable: true,
      severity: ErrorSeverity.medium,
      retryCallback: retryCallback,
      primaryAction: retryCallback != null
          ? ErrorAction(
              label: 'Reintentar',
              callback: retryCallback,
            )
          : null,
    );
  }

  // Helper methods para detectar tipos de error
  bool _isNetworkError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('socket') ||
        errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('timeout') ||
        error is SocketException ||
        error is HttpException;
  }

  bool _isAuthError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('auth') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('forbidden') ||
        errorStr.contains('jwt') ||
        errorStr.contains('session');
  }

  bool _isApiError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('http') ||
        errorStr.contains('api') ||
        errorStr.contains('status code');
  }

  bool _isStorageError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('file') ||
        errorStr.contains('storage') ||
        errorStr.contains('permission') ||
        errorStr.contains('space') ||
        errorStr.contains('disk');
  }

  // Helper methods para acciones
  void _navigateToLogin() {
    final context = globalNavigatorKey.currentContext;
    if (context != null) {
      context.go('/login');
    }
    LoggerFactory.info('Redirecting to login due to auth error');
  }

  void _retryAfterDelay(VoidCallback? callback, int seconds) {
    if (callback != null) {
      Future.delayed(Duration(seconds: seconds), callback);
    }
  }

  void _showConnectivityHelp() {
    final context = globalNavigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Problemas de Conectividad'),
          content: const Text(
            'Verifica tu conexión a internet:\n\n'
            '• Comprueba que el WiFi esté conectado\n'
            '• Intenta con datos móviles\n'
            '• Reinicia tu router si usas WiFi\n'
            '• Verifica que no haya restricciones de firewall',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openNetworkSettings();
              },
              child: const Text('Configurar Red'),
            ),
          ],
        ),
      );
    }
    LoggerFactory.info('Showing connectivity help to user');
  }

  void _openNetworkSettings() {
    try {
      if (Platform.isAndroid) {
        launchUrl(Uri.parse('package:com.android.settings'));
      } else if (Platform.isIOS) {
        launchUrl(Uri.parse('App-prefs:root=WIFI'));
      } else {
        // Para web/desktop, mostrar instrucciones
        final context = globalNavigatorKey.currentContext;
        if (context != null) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Configuración de Red'),
              content: const Text(
                'Accede a la configuración de red de tu sistema:\n\n'
                'Windows: Configuración > Red e Internet\n'
                'macOS: Preferencias del Sistema > Red\n'
                'Linux: Configuración de Red del sistema',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      LoggerFactory.error('Could not open network settings: $e');
    }
    LoggerFactory.info('Opening network settings');
  }

  void _navigateToPasswordReset() {
    final context = globalNavigatorKey.currentContext;
    if (context != null) {
      // Por ahora navegar a login donde debería estar la opción de reset
      context.go('/login');
      // Alternativamente podríamos crear una ruta específica /reset-password
    }
    LoggerFactory.info('Navigating to password reset');
  }

  /// Crea un error handler contextual para operaciones específicas
  ErrorHandler forContext(OperationContext context) {
    return ErrorHandler._(this, context);
  }
}

/// Wrapper contextual para manejar errores de una operación específica
class ErrorHandler {
  ErrorHandler._(this._handler, this._context);

  final CentralizedErrorHandler _handler;
  final OperationContext _context;

  /// Procesa un error con el contexto específico
  Future<UserFriendlyError> handle(
    dynamic error,
    StackTrace? stackTrace, {
    Map<String, dynamic>? additionalData,
    VoidCallback? retryCallback,
  }) async {
    return await _handler.processError(
      error,
      stackTrace,
      context: _context,
      additionalData: additionalData,
      retryCallback: retryCallback,
    );
  }

  /// Ejecuta una operación con manejo automático de errores
  Future<T> wrapOperation<T>(
    Future<T> Function() operation, {
    VoidCallback? onError,
    T? fallbackValue,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      final userError = await handle(error, stackTrace);

      // Log del error procesado
      LoggerFactory.info(
          'Error handled for context ${_context.name}: ${userError.title}');

      onError?.call();

      if (fallbackValue != null) {
        return fallbackValue;
      }

      rethrow;
    }
  }
}
