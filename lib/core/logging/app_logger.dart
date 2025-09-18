import 'package:flutter/foundation.dart';

import 'safe_developer_log.dart';

/// Application logger for consistent logging across the app
class AppLogger {
  AppLogger._();
  static AppLogger? _instance;
  static AppLogger get instance => _instance ??= AppLogger._();

  /// Log levels
  static const int _debugLevel = 0;
  static const int _infoLevel = 1;
  static const int _warningLevel = 2;
  static const int _errorLevel = 3;

  /// Current log level (only logs at this level or higher will be shown)
  int _currentLogLevel = kDebugMode ? _debugLevel : _infoLevel;

  /// Set the minimum log level
  void setLogLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        _currentLogLevel = _debugLevel;
        break;
      case LogLevel.info:
        _currentLogLevel = _infoLevel;
        break;
      case LogLevel.warning:
        _currentLogLevel = _warningLevel;
        break;
      case LogLevel.error:
        _currentLogLevel = _errorLevel;
        break;
    }
  }

  /// Log debug message
  void debug(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    if (_currentLogLevel <= _debugLevel) {
      _log('DEBUG', message, tag: tag, error: error, stackTrace: stackTrace);
    }
  }

  /// Log info message
  void info(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    if (_currentLogLevel <= _infoLevel) {
      _log('INFO', message, tag: tag, error: error, stackTrace: stackTrace);
    }
  }

  /// Log warning message
  void warning(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    if (_currentLogLevel <= _warningLevel) {
      _log('WARNING', message, tag: tag, error: error, stackTrace: stackTrace);
    }
  }

  /// Log error message
  void error(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    if (_currentLogLevel <= _errorLevel) {
      _log('ERROR', message, tag: tag, error: error, stackTrace: stackTrace);
    }
  }

  /// Internal logging method
  void _log(
    String level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final tagPrefix = tag != null ? '[$tag] ' : '';
    final logMessage = '$timestamp [$level] $tagPrefix$message';

    if (kDebugMode) {
      SafeDeveloperLog.log(
        logMessage,
        name: tag ?? 'AppLogger',
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      // In release mode, you might want to send logs to a crash reporting service
      SafeDeveloperLog.log(
        logMessage,
        name: tag ?? 'AppLogger',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Log network request
  void logNetworkRequest(String method, String url,
      {Map<String, dynamic>? headers}) {
    debug('$method $url', tag: 'Network', error: headers);
  }

  /// Log network response
  void logNetworkResponse(int statusCode, String url, {dynamic body}) {
    if (statusCode >= 200 && statusCode < 300) {
      debug('Response $statusCode: $url', tag: 'Network');
    } else {
      warning('Response $statusCode: $url', tag: 'Network', error: body);
    }
  }

  /// Log user action
  void logUserAction(String action, {Map<String, dynamic>? parameters}) {
    info('User action: $action', tag: 'UserAction', error: parameters);
  }

  /// Log performance metric
  void logPerformance(String operation, Duration duration,
      {Map<String, dynamic>? metadata}) {
    info('Performance: $operation took ${duration.inMilliseconds}ms',
        tag: 'Performance', error: metadata);
  }

  /// Log app lifecycle event
  void logLifecycle(String event, {String? details}) {
    info('Lifecycle: $event${details != null ? ' - $details' : ''}',
        tag: 'Lifecycle');
  }

  // ========== MÉTODOS ESTÁTICOS PARA FACILITAR EL USO ==========
  
  /// Static debug method for easy access
  static void d(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    instance.debug(message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Static info method for easy access  
  static void i(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    instance.info(message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Static warning method for easy access
  static void w(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    instance.warning(message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Static error method for easy access
  static void e(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    instance.error(message, tag: tag, error: error, stackTrace: stackTrace);
  }

  // ========== MÉTODOS ESPECIALIZADOS PARA DIFERENTES COMPONENTES ==========

  /// Log para repositorios
  static void repo(String component, String message, [Object? data]) {
    d('🗃️ [$component] $message', tag: 'Repository', error: data);
  }

  /// Log para providers
  static void provider(String component, String message, [Object? data]) {
    d('⚡ [$component] $message', tag: 'Provider', error: data);
  }

  /// Log para servicios
  static void service(String component, String message, [Object? data]) {
    d('🔧 [$component] $message', tag: 'Service', error: data);
  }

  /// Log para sincronización
  static void sync(String component, String message, [Object? data]) {
    d('🔄 [$component] $message', tag: 'Sync', error: data);
  }

  /// Log para operaciones de red
  static void network(String message, [Object? data]) {
    d('🌐 $message', tag: 'Network', error: data);
  }

  /// Log para autenticación
  static void auth(String message, [Object? data]) {
    d('🔐 $message', tag: 'Auth', error: data);
  }

  /// Log para caché
  static void cache(String message, [Object? data]) {
    d('💾 $message', tag: 'Cache', error: data);
  }

  /// Log para UI
  static void ui(String component, String message, [Object? data]) {
    d('🎨 [$component] $message', tag: 'UI', error: data);
  }
}

/// Log levels enumeration
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Extension for easy logging
extension LoggerExtension on Object {
  void logDebug(String message, {Object? error, StackTrace? stackTrace}) {
    AppLogger.instance.debug(message,
        tag: runtimeType.toString(), error: error, stackTrace: stackTrace);
  }

  void logInfo(String message, {Object? error, StackTrace? stackTrace}) {
    AppLogger.instance.info(message,
        tag: runtimeType.toString(), error: error, stackTrace: stackTrace);
  }

  void logWarning(String message, {Object? error, StackTrace? stackTrace}) {
    AppLogger.instance.warning(message,
        tag: runtimeType.toString(), error: error, stackTrace: stackTrace);
  }

  void logError(String message, {Object? error, StackTrace? stackTrace}) {
    AppLogger.instance.error(message,
        tag: runtimeType.toString(), error: error, stackTrace: stackTrace);
  }
}
