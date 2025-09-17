import '../error_reporting/error_reporting_service.dart';
import 'base_logger.dart';
import 'noop_logger.dart';

/// Utility function to clean null values from data maps to prevent
/// "Cannot send Null" errors in Flutter debugger
Map<String, dynamic>? _cleanDataMap(Map<String, dynamic>? data) {
  if (data == null) return null;

  final cleanData = <String, dynamic>{};
  for (final entry in data.entries) {
    if (entry.value != null) {
      cleanData[entry.key] = entry.value;
    }
  }

  return cleanData.isEmpty ? null : cleanData;
}

/// Factory para gestionar instancias de logger con fallback automático
/// Permite usar logging sin necesidad de configuración previa,
/// proporcionando automáticamente un NoOpLogger cuando no hay logger configurado
class LoggerFactory {
  static BaseLogger? _currentLogger;
  static bool _isInitialized = false;

  /// Obtener el logger actual o NoOpLogger si no hay ninguno configurado
  /// Este método garantiza que siempre se puede usar logging sin errores
  static BaseLogger get logger {
    if (_currentLogger != null) {
      return _currentLogger!;
    }

    // Si no hay logger configurado, usar NoOpLogger por defecto
    return NoOpLogger.instance;
  }

  /// Configurar un logger específico
  /// Una vez configurado, todos los logs usarán este logger
  static Future<void> setLogger(BaseLogger logger) async {
    _currentLogger = logger;
    _isInitialized = true;

    // Inicializar el logger si es necesario
    await logger.initialize();
  }

  /// Verificar si hay un logger configurado (diferente de NoOpLogger)
  static bool get hasConfiguredLogger => _currentLogger != null;

  /// Verificar si el sistema está inicializado
  static bool get isInitialized => _isInitialized;

  /// Obtener una instancia de logger con un nombre específico
  /// Retorna el logger actual configurado o NoOpLogger si no hay ninguno
  static BaseLogger getLogger(String name) {
    if (_currentLogger != null) {
      return _currentLogger!;
    }
    // Si no hay logger configurado, usar NoOpLogger por defecto
    return NoOpLogger.instance;
  }

  /// Resetear el logger al estado por defecto (NoOpLogger)
  static Future<void> reset() async {
    if (_currentLogger != null) {
      await _currentLogger?.dispose();
      _currentLogger = null;
    }
    _isInitialized = false;
  }

  /// Métodos de conveniencia para logging directo
  /// Estos métodos permiten usar logging sin instanciar explícitamente un logger

  static Future<void> info(
    String message, {
    LogCategory category = LogCategory.general,
    Map<String, dynamic>? data,
  }) async {
    await logger.info(message, category: category, data: _cleanDataMap(data));
  }

  static Future<void> warning(
    String message, {
    LogCategory category = LogCategory.general,
    Map<String, dynamic>? data,
  }) async {
    await logger.warning(message,
        category: category, data: _cleanDataMap(data));
  }

  static Future<void> error(
    String message, {
    LogCategory category = LogCategory.general,
    Map<String, dynamic>? data,
    StackTrace? stackTrace,
  }) async {
    final cleanData = _cleanDataMap(data);
    await logger.error(message,
        category: category, data: cleanData, stackTrace: stackTrace);

    // Also report to error reporting service if it's a significant error
    if (category == LogCategory.error || stackTrace != null) {
      await ErrorReportingService.instance.reportError(
        message,
        stackTrace,
        reason: 'Logger error: ${category.name}',
        data: cleanData,
        fatal: false,
      );
    }
  }

  static Future<void> debug(
    String message, {
    LogCategory category = LogCategory.general,
    Map<String, dynamic>? data,
  }) async {
    await logger.debug(message, category: category, data: _cleanDataMap(data));
  }

  /// Report a critical error that should be tracked in crash reporting
  static Future<void> reportCriticalError(
    dynamic error,
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? data,
    bool fatal = false,
  }) async {
    final message =
        'Critical error${context != null ? ' in $context' : ''}: ${error ?? 'null'}';
    final cleanData = _cleanDataMap(data);

    // Log locally
    await logger.error(
      message,
      category: LogCategory.error,
      data: cleanData,
      stackTrace: stackTrace,
    );

    // Report to error reporting service
    await ErrorReportingService.instance.reportError(
      error,
      stackTrace,
      reason: message,
      data: cleanData,
      fatal: fatal,
    );
  }

  /// Set user context for error reporting
  static Future<void> setUserContext(String userId) async {
    await ErrorReportingService.instance.setUserId(userId);
  }

  /// Set custom context for error reporting
  static Future<void> setCustomContext(String key, dynamic value) async {
    await ErrorReportingService.instance.setCustomKey(key, value);
  }

  /// Log batch processing results
  static Future<void> batchProcessed({
    required String tableName,
    required int batchNumber,
    required int batchSize,
    required int successCount,
    required int failureCount,
    required Duration processingTime,
    List<String>? errors,
  }) async {
    await logger.batchProcessed(
      tableName: tableName,
      batchNumber: batchNumber,
      batchSize: batchSize,
      successCount: successCount,
      failureCount: failureCount,
      processingTime: processingTime,
      errors: errors,
    );
  }

  static Future<void> apiCall({
    required String apiName,
    required String endpoint,
    required int statusCode,
    required Duration responseTime,
    Map<String, dynamic>? requestData,
    Map<String, dynamic>? responseData,
    String? error,
  }) async {
    await logger.apiCall(
      apiName: apiName,
      endpoint: endpoint,
      statusCode: statusCode,
      responseTime: responseTime,
      requestData: _cleanDataMap(requestData),
      responseData: _cleanDataMap(responseData),
      error: error,
    );
  }

  static Future<void> performance({
    required String operation,
    required Duration duration,
    required int recordsProcessed,
    Map<String, dynamic>? metrics,
  }) async {
    await logger.performance(
      operation: operation,
      duration: duration,
      recordsProcessed: recordsProcessed,
      metrics: _cleanDataMap(metrics),
    );
  }
}
