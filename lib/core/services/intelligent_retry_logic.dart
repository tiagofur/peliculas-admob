import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/sync_operation.dart';
import '../logging/logger_factory.dart';

/// Tipos de errores para diferentes estrategias de reintento
enum RetryErrorType {
  /// Errores de red (timeout, conexión perdida)
  network,

  /// Errores del servidor (5xx)
  server,

  /// Errores de autenticación (401, 403)
  authentication,

  /// Errores de cliente (4xx excepto auth)
  client,

  /// Errores de rate limiting (429)
  rateLimited,

  /// Errores de conflicto (409)
  conflict,

  /// Errores desconocidos
  unknown,
}

/// Configuración de reintentos para cada tipo de error
class RetryConfig {
  const RetryConfig({
    required this.maxRetries,
    required this.initialDelay,
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(minutes: 5),
    this.shouldRetry = true,
    this.fixedDelay,
  });
  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  final bool shouldRetry;
  final Duration? fixedDelay;

  /// Configuración para errores de red
  static const network = RetryConfig(
    maxRetries: 5,
    initialDelay: Duration(seconds: 1),
    backoffMultiplier: 2.0,
    maxDelay: Duration(minutes: 2),
  );

  /// Configuración para errores del servidor
  static const server = RetryConfig(
    maxRetries: 3,
    initialDelay: Duration(seconds: 2),
    backoffMultiplier: 2.0,
    maxDelay: Duration(minutes: 1),
  );

  /// Configuración para errores de autenticación
  static const authentication = RetryConfig(
    maxRetries: 1,
    initialDelay: Duration(seconds: 5),
    shouldRetry: false, // Requiere intervención manual
  );

  /// Configuración para errores de cliente
  static const client = RetryConfig(
    maxRetries: 0,
    initialDelay: Duration.zero,
    shouldRetry: false, // No reintentar errores de cliente
  );

  /// Configuración para rate limiting
  static const rateLimited = RetryConfig(
    maxRetries: 10,
    initialDelay: Duration(seconds: 30),
    backoffMultiplier: 1.5,
    maxDelay: Duration(minutes: 10),
  );

  /// Configuración para conflictos
  static const conflict = RetryConfig(
    maxRetries: 3,
    initialDelay: Duration(milliseconds: 500),
    backoffMultiplier: 1.5,
    maxDelay: Duration(seconds: 5),
  );

  /// Configuración para errores desconocidos
  static const unknown = RetryConfig(
    maxRetries: 2,
    initialDelay: Duration(seconds: 3),
    backoffMultiplier: 2.0,
    maxDelay: Duration(seconds: 30),
  );
}

/// Resultado de un intento de operación
class RetryAttemptResult {
  const RetryAttemptResult({
    required this.success,
    this.error,
    this.errorType,
    required this.processingTime,
    this.data,
  });
  final bool success;
  final String? error;
  final RetryErrorType? errorType;
  final Duration processingTime;
  final Map<String, dynamic>? data;

  @override
  String toString() {
    return 'RetryAttemptResult(success: $success, error: $error, type: $errorType, time: ${processingTime.inMilliseconds}ms)';
  }
}

/// Estadísticas de reintentos
class RetryStats {
  RetryStats({
    required this.totalAttempts,
    required this.successfulAttempts,
    required this.failedAttempts,
    required this.totalTime,
    required this.errorCounts,
  });
  final int totalAttempts;
  final int successfulAttempts;
  final int failedAttempts;
  final Duration totalTime;
  final Map<RetryErrorType, int> errorCounts;

  double get successRate =>
      totalAttempts > 0 ? successfulAttempts / totalAttempts : 0.0;

  @override
  String toString() {
    return 'RetryStats(attempts: $totalAttempts, success: $successfulAttempts, failed: $failedAttempts, rate: ${(successRate * 100).toStringAsFixed(1)}%, time: ${totalTime.inMilliseconds}ms)';
  }
}

/// Gestor de lógica de reintentos inteligente
class IntelligentRetryLogic {
  final Random _random = Random();

  // Estadísticas globales
  int _totalOperations = 0;
  int _successfulOperations = 0;
  int _failedOperations = 0;
  final Map<RetryErrorType, int> _globalErrorCounts = {};
  Duration _totalProcessingTime = Duration.zero;

  /// Ejecuta una operación con lógica de reintentos inteligente
  Future<RetryAttemptResult> executeWithRetry<T>(
    SyncOperation operation,
    Future<T> Function() operationFunction,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      _totalOperations++;

      final result = await _executeWithRetryInternal(
        operation,
        operationFunction,
      );

      if (result.success) {
        _successfulOperations++;
      } else {
        _failedOperations++;
        if (result.errorType != null) {
          _globalErrorCounts[result.errorType!] =
              (_globalErrorCounts[result.errorType!] ?? 0) + 1;
        }
      }

      return result;
    } finally {
      stopwatch.stop();
      _totalProcessingTime += stopwatch.elapsed;
    }
  }

  /// Implementación interna de la lógica de reintentos
  Future<RetryAttemptResult> _executeWithRetryInternal<T>(
    SyncOperation operation,
    Future<T> Function() operationFunction,
  ) async {
    final stopwatch = Stopwatch()..start();

    int attemptCount = 0;
    RetryErrorType? lastErrorType;
    String? lastError;

    while (true) {
      attemptCount++;

      try {
        LoggerFactory.debug(
            'Intento $attemptCount para operación ${operation.id}');

        final result = await operationFunction();

        stopwatch.stop();

        LoggerFactory.info(
            'Operación ${operation.id} exitosa en intento $attemptCount');

        return RetryAttemptResult(
          success: true,
          processingTime: stopwatch.elapsed,
          data: result is Map<String, dynamic> ? result : null,
        );
      } catch (e, stackTrace) {
        final errorType = _classifyError(e);
        lastErrorType = errorType;
        lastError = e.toString();

        LoggerFactory.warning(
            'Intento $attemptCount falló para operación ${operation.id}: $e (tipo: $errorType)');

        final config = _getRetryConfig(errorType);

        // Verificar si debemos reintentar
        if (!config.shouldRetry || attemptCount >= config.maxRetries) {
          stopwatch.stop();

          LoggerFactory.error(
              'Operación ${operation.id} falló definitivamente después de $attemptCount intentos',
              data: e != null ? {'error': e} : null,
              stackTrace: stackTrace);

          return RetryAttemptResult(
            success: false,
            error: lastError,
            errorType: lastErrorType,
            processingTime: stopwatch.elapsed,
          );
        }

        // Calcular delay para el siguiente intento
        final delay = _calculateDelay(config, attemptCount);

        LoggerFactory.debug(
            'Esperando ${delay.inMilliseconds}ms antes del siguiente intento para operación ${operation.id}');

        await Future.delayed(delay);
      }
    }
  }

  /// Clasifica el tipo de error para determinar la estrategia de reintento
  RetryErrorType _classifyError(dynamic error) {
    if (error is PostgrestException) {
      final code = error.code;
      final message = error.message.toLowerCase();

      // Errores de autenticación
      if (code == '401' ||
          code == '403' ||
          message.contains('unauthorized') ||
          message.contains('forbidden')) {
        return RetryErrorType.authentication;
      }

      // Rate limiting
      if (code == '429' ||
          message.contains('rate limit') ||
          message.contains('too many requests')) {
        return RetryErrorType.rateLimited;
      }

      // Conflictos
      if (code == '409' ||
          message.contains('conflict') ||
          message.contains('duplicate')) {
        return RetryErrorType.conflict;
      }

      // Errores del servidor (5xx)
      if (code?.startsWith('5') == true ||
          message.contains('internal server error')) {
        return RetryErrorType.server;
      }

      // Errores de cliente (4xx)
      if (code?.startsWith('4') == true) {
        return RetryErrorType.client;
      }
    }

    if (error is SocketException ||
        error is TimeoutException ||
        error.toString().toLowerCase().contains('network') ||
        error.toString().toLowerCase().contains('connection') ||
        error.toString().toLowerCase().contains('timeout')) {
      return RetryErrorType.network;
    }

    return RetryErrorType.unknown;
  }

  /// Obtiene la configuración de reintentos para un tipo de error
  RetryConfig _getRetryConfig(RetryErrorType errorType) {
    switch (errorType) {
      case RetryErrorType.network:
        return RetryConfig.network;
      case RetryErrorType.server:
        return RetryConfig.server;
      case RetryErrorType.authentication:
        return RetryConfig.authentication;
      case RetryErrorType.client:
        return RetryConfig.client;
      case RetryErrorType.rateLimited:
        return RetryConfig.rateLimited;
      case RetryErrorType.conflict:
        return RetryConfig.conflict;
      case RetryErrorType.unknown:
        return RetryConfig.unknown;
    }
  }

  /// Calcula el delay para el siguiente intento usando backoff exponencial con jitter
  Duration _calculateDelay(RetryConfig config, int attemptNumber) {
    if (config.fixedDelay != null) {
      return config.fixedDelay!;
    }

    // Backoff exponencial
    final baseDelay = config.initialDelay.inMilliseconds;
    final exponentialDelay =
        baseDelay * pow(config.backoffMultiplier, attemptNumber - 1);

    // Aplicar jitter (±25% de variación aleatoria)
    final jitterRange = exponentialDelay * 0.25;
    final jitter = (_random.nextDouble() - 0.5) * 2 * jitterRange;
    final finalDelay = (exponentialDelay + jitter)
        .clamp(0, config.maxDelay.inMilliseconds.toDouble());

    return Duration(milliseconds: finalDelay.round());
  }

  /// Determina si una operación debe ser reintentada basándose en su historial
  bool shouldRetryOperation(SyncOperation operation) {
    // No reintentar si ya se alcanzó el máximo de reintentos
    if (operation.retryCount >= operation.maxRetries) {
      return false;
    }

    // No reintentar operaciones muy antiguas (más de 24 horas)
    final age = DateTime.now().difference(operation.createdAt);
    if (age.inHours > 24) {
      return false;
    }

    // No reintentar si la última actualización fue muy reciente (menos de 1 minuto)
    final timeSinceLastUpdate = DateTime.now()
        .difference(operation.lastAttemptAt ?? operation.createdAt);
    if (timeSinceLastUpdate.inMinutes < 1) {
      return false;
    }

    return true;
  }

  /// Actualiza una operación después de un intento fallido
  SyncOperation updateOperationAfterFailure(
    SyncOperation operation,
    String error,
    RetryErrorType errorType,
  ) {
    final now = DateTime.now();

    return operation.copyWith(
      status: SyncOperationStatus.failed,
      retryCount: operation.retryCount + 1,
      errorMessage: error,
      lastAttemptAt: now,
      data: {
        ...operation.data,
        'lastErrorType': errorType.name,
        'lastFailureAt': now.toIso8601String(),
      },
    );
  }

  /// Actualiza una operación después de un intento exitoso
  SyncOperation updateOperationAfterSuccess(
    SyncOperation operation,
    Map<String, dynamic>? resultData,
  ) {
    final now = DateTime.now();

    return operation.copyWith(
      status: SyncOperationStatus.completed,
      errorMessage: null,
      lastAttemptAt: now,
      data: {
        ...operation.data,
        if (resultData != null) ...resultData,
        'completedAt': now.toIso8601String(),
      },
    );
  }

  /// Obtiene estadísticas globales de reintentos
  RetryStats getGlobalStats() {
    return RetryStats(
      totalAttempts: _totalOperations,
      successfulAttempts: _successfulOperations,
      failedAttempts: _failedOperations,
      totalTime: _totalProcessingTime,
      errorCounts: Map.from(_globalErrorCounts),
    );
  }

  /// Reinicia las estadísticas globales
  void resetStats() {
    _totalOperations = 0;
    _successfulOperations = 0;
    _failedOperations = 0;
    _globalErrorCounts.clear();
    _totalProcessingTime = Duration.zero;

    LoggerFactory.info('Estadísticas de reintentos reiniciadas');
  }

  /// Obtiene recomendaciones basadas en las estadísticas
  List<String> getRecommendations() {
    final stats = getGlobalStats();
    final recommendations = <String>[];

    if (stats.successRate < 0.8) {
      recommendations.add(
          'Tasa de éxito baja (${(stats.successRate * 100).toStringAsFixed(1)}%). Considerar revisar la conectividad o configuración.');
    }

    final networkErrors = stats.errorCounts[RetryErrorType.network] ?? 0;
    if (networkErrors > stats.totalAttempts * 0.3) {
      recommendations.add(
          'Alto número de errores de red. Verificar conectividad a internet.');
    }

    final authErrors = stats.errorCounts[RetryErrorType.authentication] ?? 0;
    if (authErrors > 0) {
      recommendations.add(
          'Errores de autenticación detectados. Verificar tokens y permisos.');
    }

    final rateLimitErrors = stats.errorCounts[RetryErrorType.rateLimited] ?? 0;
    if (rateLimitErrors > stats.totalAttempts * 0.1) {
      recommendations.add(
          'Rate limiting frecuente. Considerar reducir la frecuencia de operaciones.');
    }

    if (recommendations.isEmpty) {
      recommendations.add('Sistema funcionando correctamente.');
    }

    return recommendations;
  }
}
