import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../core/error_handling/centralized_error_handler.dart';
import '../../core/logging/logger_factory.dart';

/// Mixin para agregar manejo centralizado de errores a StateNotifiers
mixin ErrorHandlingMixin<T> on StateNotifier<T> {
  final CentralizedErrorHandler _errorHandler = CentralizedErrorHandler();

  /// Procesa un error y devuelve información user-friendly
  Future<UserFriendlyError> processError(
    dynamic error,
    StackTrace? stackTrace, {
    OperationContext? context,
    VoidCallback? retryCallback,
  }) async {
    return await _errorHandler.processError(
      error,
      stackTrace,
      context: context ?? _getDefaultContext(),
      additionalData: {
        'state_notifier': runtimeType.toString(),
        'current_state': state.toString(),
      },
      retryCallback: retryCallback,
    );
  }

  /// Ejecuta una operación con manejo automático de errores
  Future<R> executeWithErrorHandling<R>(
    Future<R> Function() operation, {
    String? operationName,
    OperationContext? context,
    R? fallbackValue,
    bool logErrors = true,
    bool rethrowOnError = true,
  }) async {
    try {
      if (logErrors) {
        LoggerFactory.info(
            '🔄 [${runtimeType.toString()}] Starting operation: ${operationName ?? 'unnamed'}');
      }

      final result = await operation();

      if (logErrors) {
        LoggerFactory.info(
            '✅ [${runtimeType.toString()}] Operation completed: ${operationName ?? 'unnamed'}');
      }

      return result;
    } catch (error, stackTrace) {
      if (logErrors) {
        LoggerFactory.error(
            '❌ [${runtimeType.toString()}] Operation failed: ${operationName ?? 'unnamed'} - $error',
            stackTrace: stackTrace);
      }

      // Procesar el error para obtener información user-friendly
      await _errorHandler.processError(
        error,
        stackTrace,
        context: context ?? _getDefaultContext(),
        additionalData: {
          'state_notifier': runtimeType.toString(),
          'operation_name': operationName ?? 'unnamed',
          'current_state': state.toString(),
        },
      );

      if (fallbackValue != null) {
        return fallbackValue;
      }

      if (rethrowOnError) {
        rethrow;
      }

      rethrow;
    }
  }

  /// Ejecuta una operación async que actualiza el estado con manejo de errores
  Future<void> safeUpdateState<R>(
    Future<R> Function() operation, {
    required void Function(R result) onSuccess,
    void Function(UserFriendlyError error)? onError,
    String? operationName,
    OperationContext? context,
  }) async {
    try {
      final result = await executeWithErrorHandling(
        operation,
        operationName: operationName,
        context: context,
        logErrors: true,
        rethrowOnError: true,
      );

      onSuccess(result);
    } catch (error, stackTrace) {
      final userError = await processError(
        error,
        stackTrace,
        context: context,
      );

      if (onError != null) {
        onError(userError);
      } else {
        // Si no hay handler específico, log del error
        LoggerFactory.warning(
            '⚠️ [${runtimeType.toString()}] Unhandled user error: ${userError.title}');
      }
    }
  }

  /// Obtiene el contexto por defecto basado en el tipo de StateNotifier
  OperationContext _getDefaultContext() {
    final typeName = runtimeType.toString().toLowerCase();

    if (typeName.contains('auth')) {
      return OperationContext.authentication;
    } else if (typeName.contains('sync')) {
      return OperationContext.dataSync;
    } else if (typeName.contains('movie') ||
        typeName.contains('list') ||
        typeName.contains('favorite') ||
        typeName.contains('watch')) {
      return OperationContext.dataLoading;
    } else if (typeName.contains('storage') || typeName.contains('cache')) {
      return OperationContext.storage;
    } else if (typeName.contains('network') || typeName.contains('api')) {
      return OperationContext.network;
    }

    return OperationContext.userAction;
  }

  /// Crea un handler específico para este StateNotifier
  ErrorHandler createContextualHandler([OperationContext? context]) {
    return _errorHandler.forContext(context ?? _getDefaultContext());
  }
}

/// Estados comunes para StateNotifiers con manejo de errores
abstract class AsyncState<T> {
  const AsyncState();
}

class AsyncStateLoading<T> extends AsyncState<T> {
  const AsyncStateLoading();
}

class AsyncStateData<T> extends AsyncState<T> {
  const AsyncStateData(this.data);
  final T data;
}

class AsyncStateError<T> extends AsyncState<T> {
  const AsyncStateError(this.error, [this.canRetry = true]);
  final UserFriendlyError error;
  final bool canRetry;
}

/// Mixin para StateNotifiers que usan AsyncState con error handling
mixin AsyncStateErrorHandling<T> on StateNotifier<AsyncState<T>> {
  final CentralizedErrorHandler _errorHandler = CentralizedErrorHandler();

  /// Carga datos con manejo automático de estados y errores
  Future<void> loadData<R>(
    Future<R> Function() operation, {
    required T Function(R result) onSuccess,
    String? operationName,
    OperationContext? context,
    VoidCallback? retryCallback,
  }) async {
    state = const AsyncStateLoading();

    try {
      LoggerFactory.info(
          '🔄 [${runtimeType.toString()}] Loading data: ${operationName ?? 'unnamed'}');

      final result = await operation();
      final data = onSuccess(result);

      state = AsyncStateData(data);

      LoggerFactory.info(
          '✅ [${runtimeType.toString()}] Data loaded successfully: ${operationName ?? 'unnamed'}');
    } catch (error, stackTrace) {
      LoggerFactory.error(
          '❌ [${runtimeType.toString()}] Failed to load data: ${operationName ?? 'unnamed'} - $error',
          stackTrace: stackTrace);

      // Procesar error para obtener información user-friendly
      final userError = await _errorHandler.processError(
        error,
        stackTrace,
        context: context ?? _getDefaultContext(),
        additionalData: {
          'state_notifier': runtimeType.toString(),
          'operation_name': operationName ?? 'unnamed',
        },
        retryCallback: retryCallback ??
            () => loadData(
                  operation,
                  onSuccess: onSuccess,
                  operationName: operationName,
                  context: context,
                ),
      );

      state = AsyncStateError(userError);
    }
  }

  /// Recarga los datos si el estado actual es de error
  void retryIfError() {
    if (state is AsyncStateError<T>) {
      final errorState = state as AsyncStateError<T>;
      if (errorState.canRetry && errorState.error.retryCallback != null) {
        errorState.error.retryCallback!();
      }
    }
  }

  /// Obtiene el contexto por defecto basado en el tipo
  OperationContext _getDefaultContext() {
    final typeName = runtimeType.toString().toLowerCase();

    if (typeName.contains('auth')) {
      return OperationContext.authentication;
    } else if (typeName.contains('sync')) {
      return OperationContext.dataSync;
    } else if (typeName.contains('movie') ||
        typeName.contains('list') ||
        typeName.contains('favorite') ||
        typeName.contains('watch')) {
      return OperationContext.dataLoading;
    }

    return OperationContext.userAction;
  }
}

/// Extension para AsyncState en los widgets
extension AsyncStateExt<T> on AsyncState<T> {
  /// Ejecuta diferentes builders basados en el estado
  Widget when<R>({
    required Widget Function() loading,
    required Widget Function(T data) data,
    required Widget Function(UserFriendlyError error) error,
  }) {
    if (this is AsyncStateLoading<T>) {
      return loading();
    } else if (this is AsyncStateData<T>) {
      return data((this as AsyncStateData<T>).data);
    } else if (this is AsyncStateError<T>) {
      return error((this as AsyncStateError<T>).error);
    }
    return loading(); // Fallback
  }

  /// Verifica si el estado es de loading
  bool get isLoading => this is AsyncStateLoading<T>;

  /// Verifica si el estado tiene datos
  bool get hasData => this is AsyncStateData<T>;

  /// Verifica si el estado es de error
  bool get hasError => this is AsyncStateError<T>;

  /// Obtiene los datos si existen
  T? get dataOrNull => hasData ? (this as AsyncStateData<T>).data : null;

  /// Obtiene el error si existe
  UserFriendlyError? get errorOrNull =>
      hasError ? (this as AsyncStateError<T>).error : null;
}

