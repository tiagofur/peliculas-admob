import 'dart:async';

/// Niveles de logging
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Categorías de logging
enum LogCategory {
  general,
  system,
  migration,
  batch,
  api,
  mapping,
  performance,
  database,
  scheduler,
  error,
  analytics,
  notifications,
}

/// Entrada de log base
class LogEntry {
  LogEntry({
    required this.level,
    required this.category,
    required this.message,
    required this.timestamp,
    this.data,
  });

  final LogLevel level;
  final LogCategory category;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  Map<String, dynamic> toJson() => {
        'level': level.name,
        'category': category.name,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        if (data != null) 'data': data,
      };
}

/// Clase abstracta base para todos los loggers del sistema
/// Proporciona una interfaz común que permite usar logging sin necesidad
/// de instanciar un logger específico previamente
abstract class BaseLogger {
  /// Inicializar el logger (opcional, algunos loggers no necesitan inicialización)
  Future<void> initialize() async {}

  /// Log de información general
  Future<void> info(
    String message, {
    LogCategory category = LogCategory.general,
    Map<String, dynamic>? data,
  });

  /// Log de advertencias
  Future<void> warning(
    String message, {
    LogCategory category = LogCategory.general,
    Map<String, dynamic>? data,
  });

  /// Log de errores
  Future<void> error(
    String message, {
    LogCategory category = LogCategory.general,
    Map<String, dynamic>? data,
    StackTrace? stackTrace,
  });

  /// Log de debug
  Future<void> debug(
    String message, {
    LogCategory category = LogCategory.general,
    Map<String, dynamic>? data,
  });

  /// Log de inicio de migración
  Future<void> migrationStarted({
    required String migrationType,
    required int totalRecords,
    Map<String, dynamic>? additionalData,
  });

  /// Log de finalización de migración
  Future<void> migrationCompleted({
    required String migrationType,
    required int successCount,
    required int failureCount,
    required Duration duration,
    Map<String, dynamic>? additionalData,
  });

  /// Log de procesamiento de lote
  Future<void> batchProcessed({
    required String tableName,
    required int batchNumber,
    required int batchSize,
    required int successCount,
    required int failureCount,
    required Duration processingTime,
    List<String>? errors,
  });

  /// Log de llamada a API
  Future<void> apiCall({
    required String apiName,
    required String endpoint,
    required int statusCode,
    required Duration responseTime,
    Map<String, dynamic>? requestData,
    Map<String, dynamic>? responseData,
    String? error,
  });

  /// Log de rendimiento
  Future<void> performance({
    required String operation,
    required Duration duration,
    required int recordsProcessed,
    Map<String, dynamic>? metrics,
  });

  /// Obtener logs recientes (opcional, algunos loggers no almacenan logs)
  List<LogEntry> getRecentLogs({
    int limit = 100,
    LogLevel? minLevel,
    LogCategory? category,
  }) {
    return [];
  }

  /// Stream de logs en tiempo real (opcional)
  Stream<List<LogEntry>> get logsStream => Stream.empty();

  /// Limpiar recursos del logger
  Future<void> dispose() async {}
}