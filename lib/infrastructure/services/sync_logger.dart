import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Niveles de logging para sincronización
enum SyncLogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

/// Tipos de operaciones de sincronización
enum SyncOperationType {
  upload,
  download,
  conflict,
  retry,
  complete,
  error,
  system,
  alert,
}

/// Entrada de log de sincronización
class SyncLogEntry {
  final DateTime timestamp;
  final SyncLogLevel level;
  final SyncOperationType operation;
  final String repository;
  final String message;
  final Map<String, dynamic>? metadata;
  final String? error;
  final StackTrace? stackTrace;
  final Duration? duration;

  const SyncLogEntry({
    required this.timestamp,
    required this.level,
    required this.operation,
    required this.repository,
    required this.message,
    this.metadata,
    this.error,
    this.stackTrace,
    this.duration,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.name,
    'operation': operation.name,
    'repository': repository,
    'message': message,
    'metadata': metadata,
    'error': error,
    'duration_ms': duration?.inMilliseconds,
  };

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[${timestamp.toIso8601String()}] ');
    buffer.write('${level.name.toUpperCase()} ');
    buffer.write('[$repository] ');
    buffer.write('${operation.name.toUpperCase()}: ');
    buffer.write(message);
    
    if (duration != null) {
      buffer.write(' (${duration!.inMilliseconds}ms)');
    }
    
    if (error != null) {
      buffer.write(' - Error: $error');
    }
    
    return buffer.toString();
  }
}

/// Logger especializado para operaciones de sincronización
class SyncLogger {
  static final SyncLogger _instance = SyncLogger._internal();
  factory SyncLogger() => _instance;
  SyncLogger._internal();

  final List<SyncLogEntry> _logs = [];
  final int _maxLogs = 1000; // Mantener últimos 1000 logs
  
  SyncLogLevel _minLevel = kDebugMode ? SyncLogLevel.debug : SyncLogLevel.info;

  /// Configurar nivel mínimo de logging
  void setMinLevel(SyncLogLevel level) {
    _minLevel = level;
  }

  /// Log de debug
  void debug(String repository, SyncOperationType operation, String message, {
    Map<String, dynamic>? metadata,
    Duration? duration,
  }) {
    _log(SyncLogLevel.debug, repository, operation, message, 
         metadata: metadata, duration: duration);
  }

  /// Log de información
  void info(String repository, SyncOperationType operation, String message, {
    Map<String, dynamic>? metadata,
    Duration? duration,
  }) {
    _log(SyncLogLevel.info, repository, operation, message, 
         metadata: metadata, duration: duration);
  }

  /// Log de advertencia
  void warning(String repository, SyncOperationType operation, String message, {
    Map<String, dynamic>? metadata,
    Duration? duration,
  }) {
    _log(SyncLogLevel.warning, repository, operation, message, 
         metadata: metadata, duration: duration);
  }

  /// Log de error
  void error(String repository, SyncOperationType operation, String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
    Duration? duration,
  }) {
    _log(SyncLogLevel.error, repository, operation, message,
         error: error?.toString(), stackTrace: stackTrace,
         metadata: metadata, duration: duration);
  }

  /// Log crítico
  void critical(String repository, SyncOperationType operation, String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
    Duration? duration,
  }) {
    _log(SyncLogLevel.critical, repository, operation, message,
         error: error?.toString(), stackTrace: stackTrace,
         metadata: metadata, duration: duration);
  }

  /// Método interno de logging
  void _log(SyncLogLevel level, String repository, SyncOperationType operation, 
           String message, {
    String? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
    Duration? duration,
  }) {
    if (level.index < _minLevel.index) return;

    final entry = SyncLogEntry(
      timestamp: DateTime.now(),
      level: level,
      operation: operation,
      repository: repository,
      message: message,
      metadata: metadata,
      error: error,
      stackTrace: stackTrace,
      duration: duration,
    );

    _logs.add(entry);
    
    // Mantener solo los últimos N logs
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }

    // Output a consola en desarrollo
    if (kDebugMode) {
      developer.log(
        entry.toString(),
        name: 'SyncLogger',
        level: _getDeveloperLogLevel(level),
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Convertir nivel de sync a nivel de developer log
  int _getDeveloperLogLevel(SyncLogLevel level) {
    switch (level) {
      case SyncLogLevel.debug:
        return 500;
      case SyncLogLevel.info:
        return 800;
      case SyncLogLevel.warning:
        return 900;
      case SyncLogLevel.error:
        return 1000;
      case SyncLogLevel.critical:
        return 1200;
    }
  }

  /// Obtener logs filtrados
  List<SyncLogEntry> getLogs({
    SyncLogLevel? minLevel,
    String? repository,
    SyncOperationType? operation,
    DateTime? since,
    int? limit,
  }) {
    var filtered = _logs.where((log) {
      if (minLevel != null && log.level.index < minLevel.index) return false;
      if (repository != null && log.repository != repository) return false;
      if (operation != null && log.operation != operation) return false;
      if (since != null && log.timestamp.isBefore(since)) return false;
      return true;
    }).toList();

    // Ordenar por timestamp descendente (más recientes primero)
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (limit != null && filtered.length > limit) {
      filtered = filtered.take(limit).toList();
    }

    return filtered;
  }

  /// Obtener estadísticas de logs
  Map<String, dynamic> getStats({
    DateTime? since,
    String? repository,
  }) {
    final logs = getLogs(since: since, repository: repository);
    
    final stats = <String, dynamic>{
      'total_logs': logs.length,
      'by_level': <String, int>{},
      'by_operation': <String, int>{},
      'by_repository': <String, int>{},
      'errors': logs.where((l) => l.level == SyncLogLevel.error || 
                                 l.level == SyncLogLevel.critical).length,
      'avg_duration_ms': 0.0,
    };

    // Contar por nivel
    for (final level in SyncLogLevel.values) {
      stats['by_level'][level.name] = logs.where((l) => l.level == level).length;
    }

    // Contar por operación
    for (final operation in SyncOperationType.values) {
      stats['by_operation'][operation.name] = 
          logs.where((l) => l.operation == operation).length;
    }

    // Contar por repositorio
    final repositories = logs.map((l) => l.repository).toSet();
    for (final repo in repositories) {
      stats['by_repository'][repo] = logs.where((l) => l.repository == repo).length;
    }

    // Calcular duración promedio
    final logsWithDuration = logs.where((l) => l.duration != null).toList();
    if (logsWithDuration.isNotEmpty) {
      final totalMs = logsWithDuration
          .map((l) => l.duration!.inMilliseconds)
          .reduce((a, b) => a + b);
      stats['avg_duration_ms'] = totalMs / logsWithDuration.length;
    }

    return stats;
  }

  /// Limpiar logs antiguos
  void clearOldLogs({DateTime? before}) {
    before ??= DateTime.now().subtract(const Duration(days: 7));
    _logs.removeWhere((log) => log.timestamp.isBefore(before!));
  }

  /// Exportar logs como JSON
  List<Map<String, dynamic>> exportLogs({
    DateTime? since,
    String? repository,
    int? limit,
  }) {
    return getLogs(since: since, repository: repository, limit: limit)
        .map((log) => log.toJson())
        .toList();
  }

  /// Limpiar todos los logs
  void clear() {
    _logs.clear();
  }
}

/// Extension para facilitar el logging en repositorios
extension SyncLoggerExtension on Object {
  SyncLogger get syncLogger => SyncLogger();
  
  String get _repositoryName => runtimeType.toString();

  void logSyncDebug(SyncOperationType operation, String message, {
    Map<String, dynamic>? metadata,
    Duration? duration,
  }) {
    syncLogger.debug(_repositoryName, operation, message, 
                    metadata: metadata, duration: duration);
  }

  void logSyncInfo(SyncOperationType operation, String message, {
    Map<String, dynamic>? metadata,
    Duration? duration,
  }) {
    syncLogger.info(_repositoryName, operation, message, 
                   metadata: metadata, duration: duration);
  }

  void logSyncWarning(SyncOperationType operation, String message, {
    Map<String, dynamic>? metadata,
    Duration? duration,
  }) {
    syncLogger.warning(_repositoryName, operation, message, 
                      metadata: metadata, duration: duration);
  }

  void logSyncError(SyncOperationType operation, String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
    Duration? duration,
  }) {
    syncLogger.error(_repositoryName, operation, message,
                    error: error, stackTrace: stackTrace,
                    metadata: metadata, duration: duration);
  }

  void logSyncCritical(SyncOperationType operation, String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
    Duration? duration,
  }) {
    syncLogger.critical(_repositoryName, operation, message,
                       error: error, stackTrace: stackTrace,
                       metadata: metadata, duration: duration);
  }
}