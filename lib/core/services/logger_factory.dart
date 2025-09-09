import '../logging/app_logger.dart';

/// Logger factory for creating and managing loggers throughout the app
class LoggerFactory {
  static final AppLogger _logger = AppLogger.instance;

  /// Log info message
  static void info(String message, {String? tag}) {
    _logger.info(message, tag: tag);
  }

  /// Log warning message
  static void warning(String message, {String? tag}) {
    _logger.warning(message, tag: tag);
  }

  /// Log error message
  static void error(String message,
      {Object? error, StackTrace? stackTrace, String? tag}) {
    _logger.error(message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Log debug message
  static void debug(String message, {String? tag}) {
    _logger.debug(message, tag: tag);
  }
}
