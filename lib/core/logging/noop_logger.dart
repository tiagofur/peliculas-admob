import 'dart:async';

import 'base_logger.dart';

/// Logger que no realiza ninguna operación (No-Operation Logger)
/// Se usa como implementación por defecto cuando no se ha configurado
/// un logger específico, permitiendo que el código funcione sin errores
/// incluso sin inicialización previa del sistema de logging
class NoOpLogger extends BaseLogger {
  NoOpLogger._();

  /// Singleton instance
  static NoOpLogger? _instance;
  static NoOpLogger get instance => _instance ??= NoOpLogger._();

  @override
  Future<void> initialize() async {
    // No hace nada - no requiere inicialización
  }

  @override
  Future<void> info(
    String message, {
    LogCategory category = LogCategory.general,
    Map<String, dynamic>? data,
  }) async {
    // No hace nada - silenciosamente ignora el log
  }

  @override
  Future<void> warning(
    String message, {
    LogCategory category = LogCategory.general,
    Map<String, dynamic>? data,
  }) async {
    // No hace nada - silenciosamente ignora el log
  }

  @override
  Future<void> error(
    String message, {
    LogCategory category = LogCategory.general,
    Map<String, dynamic>? data,
    StackTrace? stackTrace,
  }) async {
    // No hace nada - silenciosamente ignora el log
  }

  @override
  Future<void> debug(
    String message, {
    LogCategory category = LogCategory.general,
    Map<String, dynamic>? data,
  }) async {
    // No hace nada - silenciosamente ignora el log
  }

  @override
  Future<void> migrationStarted({
    required String migrationType,
    required int totalRecords,
    Map<String, dynamic>? additionalData,
  }) async {
    // No hace nada - silenciosamente ignora el log
  }

  @override
  Future<void> migrationCompleted({
    required String migrationType,
    required int successCount,
    required int failureCount,
    required Duration duration,
    Map<String, dynamic>? additionalData,
  }) async {
    // No hace nada - silenciosamente ignora el log
  }

  @override
  Future<void> batchProcessed({
    required String tableName,
    required int batchNumber,
    required int batchSize,
    required int successCount,
    required int failureCount,
    required Duration processingTime,
    List<String>? errors,
  }) async {
    // No hace nada - silenciosamente ignora el log
  }

  @override
  Future<void> apiCall({
    required String apiName,
    required String endpoint,
    required int statusCode,
    required Duration responseTime,
    Map<String, dynamic>? requestData,
    Map<String, dynamic>? responseData,
    String? error,
  }) async {
    // No hace nada - silenciosamente ignora el log
  }

  @override
  Future<void> performance({
    required String operation,
    required Duration duration,
    required int recordsProcessed,
    Map<String, dynamic>? metrics,
  }) async {
    // No hace nada - silenciosamente ignora el log
  }

  @override
  List<LogEntry> getRecentLogs({
    int limit = 100,
    LogLevel? minLevel,
    LogCategory? category,
  }) {
    // Retorna lista vacía - no almacena logs
    return [];
  }

  @override
  Stream<List<LogEntry>> get logsStream => const Stream.empty();

  @override
  Future<void> dispose() async {
    // No hace nada - no hay recursos que limpiar
  }
}
