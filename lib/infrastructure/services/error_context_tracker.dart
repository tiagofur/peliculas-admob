import 'dart:convert';
import 'dart:io';

import '../../core/logging/logger_factory.dart';

/// Servicio para rastrear contexto de errores y patrones
class ErrorContextTracker {
  factory ErrorContextTracker() => _instance;
  ErrorContextTracker._internal();

  static final ErrorContextTracker _instance = ErrorContextTracker._internal();

  static ErrorContextTracker get instance => _instance;

  final Map<String, List<ErrorOccurrence>> _errorPatterns = {};
  final Map<String, int> _errorCounts = {};
  final Map<String, DateTime> _lastErrorTimes = {};

  /// Información del dispositivo/plataforma
  Map<String, dynamic>? _deviceInfo;
  bool _isInitialized = false;

  /// Inicializa el tracker con información del dispositivo
  Future<void> initialize() async {
    if (_isInitialized) return;

    _deviceInfo = await _collectDeviceInfo();
    _isInitialized = true;

    LoggerFactory.info('📊 ErrorContextTracker initialized with device info');
  }

  /// Recolecta información del dispositivo
  Future<Map<String, dynamic>> _collectDeviceInfo() async {
    try {
      return {
        'platform': Platform.operatingSystem,
        'platform_version': Platform.operatingSystemVersion,
        'dart_version': Platform.version,
        'is_debug': !const bool.fromEnvironment('dart.vm.product'),
        'locale': Platform.localeName,
        'number_of_processors': Platform.numberOfProcessors,
        'path_separator': Platform.pathSeparator,
        'executable_arguments': Platform.executableArguments.take(3).toList(),
        'environment_vars': {
          'FLUTTER_ROOT':
              Platform.environment['FLUTTER_ROOT']?.isNotEmpty == true
                  ? 'set'
                  : 'not_set',
          'PATH': Platform.environment['PATH']?.isNotEmpty == true
              ? 'set'
              : 'not_set',
        },
      };
    } catch (e) {
      LoggerFactory.warning('⚠️ Error collecting device info: $e');
      return {
        'platform': 'unknown',
        'error': 'failed_to_collect',
      };
    }
  }

  /// Registra un error con contexto completo
  String trackError({
    required String errorType,
    required String errorMessage,
    String? operation,
    String? tableName,
    Map<String, dynamic>? additionalContext,
  }) {
    if (!_isInitialized) {
      LoggerFactory.warning(
          '⚠️ ErrorContextTracker not initialized, initializing now');
      initialize();
    }

    final timestamp = DateTime.now();
    final correlationId = _generateCorrelationId(errorType, timestamp);

    final errorOccurrence = ErrorOccurrence(
      correlationId: correlationId,
      errorType: errorType,
      errorMessage: errorMessage,
      operation: operation,
      tableName: tableName,
      timestamp: timestamp,
      deviceInfo: _deviceInfo ?? {'platform': 'unknown'},
      additionalContext: additionalContext ?? {},
    );

    // Registrar en patrones de error
    final patternKey = _createPatternKey(errorType, operation, tableName);
    _errorPatterns.putIfAbsent(patternKey, () => []).add(errorOccurrence);

    // Actualizar contadores
    _errorCounts[patternKey] = (_errorCounts[patternKey] ?? 0) + 1;
    _lastErrorTimes[patternKey] = timestamp;

    // Limpiar patrones antiguos (mantener solo últimos 100 errores por patrón)
    if (_errorPatterns[patternKey]!.length > 100) {
      _errorPatterns[patternKey] =
          _errorPatterns[patternKey]!.skip(50).toList();
    }

    // Log del contexto de error
    _logErrorContext(errorOccurrence, patternKey);

    return correlationId;
  }

  /// Genera un ID de correlación único
  String _generateCorrelationId(String errorType, DateTime timestamp) {
    final typePrefix =
        errorType.toLowerCase().replaceAll('_', '').substring(0, 3);
    final timeStamp = timestamp.millisecondsSinceEpoch.toString().substring(8);
    return '${typePrefix}_$timeStamp';
  }

  /// Crea una clave para el patrón de error
  String _createPatternKey(
      String errorType, String? operation, String? tableName) {
    return '${errorType}_${operation ?? 'unknown'}_${tableName ?? 'none'}';
  }

  /// Registra el contexto del error en logs
  void _logErrorContext(ErrorOccurrence occurrence, String patternKey) {
    final frequency = _errorCounts[patternKey] ?? 1;
    final isRecurring = frequency > 1;

    final contextLog = {
      'correlation_id': occurrence.correlationId,
      'error_type': occurrence.errorType,
      'operation': occurrence.operation ?? 'unknown',
      'table_name': occurrence.tableName ?? 'none',
      'frequency': frequency,
      'is_recurring': isRecurring,
      'device_platform': occurrence.deviceInfo['platform'],
      'timestamp': occurrence.timestamp.toIso8601String(),
    };

    if (occurrence.additionalContext.isNotEmpty) {
      contextLog['additional_context'] = occurrence.additionalContext;
    }

    final logMessage =
        '📊 ERROR_CONTEXT [${occurrence.correlationId}]: ${occurrence.errorType}\n'
        '   🔄 Pattern: $patternKey (frequency: $frequency)\n'
        '   📱 Device: ${occurrence.deviceInfo['platform']} ${occurrence.deviceInfo['platform_version']}\n'
        '   ⚙️ Operation: ${occurrence.operation ?? 'unknown'}\n'
        '   🗃️ Table: ${occurrence.tableName ?? 'none'}\n'
        '   ${isRecurring ? '🔁 RECURRING ERROR' : '🆕 NEW ERROR'}';

    if (isRecurring && frequency > 5) {
      LoggerFactory.error(logMessage);
    } else {
      LoggerFactory.info(logMessage);
    }
  }

  /// Obtiene estadísticas de errores
  Map<String, dynamic> getErrorStatistics() {
    final now = DateTime.now();
    final last24Hours = now.subtract(const Duration(hours: 24));
    final lastHour = now.subtract(const Duration(hours: 1));

    int totalErrors = 0;
    int errorsLast24h = 0;
    int errorsLastHour = 0;
    final Map<String, int> errorTypeBreakdown = {};

    for (final entry in _errorPatterns.entries) {
      final occurrences = entry.value;

      totalErrors += occurrences.length;

      for (final occurrence in occurrences) {
        if (occurrence.timestamp.isAfter(last24Hours)) {
          errorsLast24h++;
        }
        if (occurrence.timestamp.isAfter(lastHour)) {
          errorsLastHour++;
        }

        errorTypeBreakdown[occurrence.errorType] =
            (errorTypeBreakdown[occurrence.errorType] ?? 0) + 1;
      }
    }

    return {
      'total_errors': totalErrors,
      'errors_last_24h': errorsLast24h,
      'errors_last_hour': errorsLastHour,
      'unique_patterns': _errorPatterns.length,
      'error_type_breakdown': errorTypeBreakdown,
      'most_frequent_patterns': _getMostFrequentPatterns(5),
      'device_info': _deviceInfo ?? {'platform': 'unknown'},
      'tracking_since': _errorPatterns.values
          .expand((list) => list)
          .map((e) => e.timestamp)
          .fold<DateTime?>(
              null,
              (earliest, current) =>
                  earliest == null || current.isBefore(earliest)
                      ? current
                      : earliest)
          ?.toIso8601String(),
    };
  }

  /// Obtiene los patrones de error más frecuentes
  List<Map<String, dynamic>> _getMostFrequentPatterns(int limit) {
    final sortedPatterns = _errorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedPatterns
        .take(limit)
        .map((entry) => {
              'pattern': entry.key,
              'count': entry.value,
              'last_occurrence': _lastErrorTimes[entry.key]?.toIso8601String(),
            })
        .toList();
  }

  /// Obtiene errores por correlación ID
  ErrorOccurrence? getErrorByCorrelationId(String correlationId) {
    for (final occurrences in _errorPatterns.values) {
      for (final occurrence in occurrences) {
        if (occurrence.correlationId == correlationId) {
          return occurrence;
        }
      }
    }
    return null;
  }

  /// Limpia errores antiguos (más de 7 días)
  void cleanupOldErrors() {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
    int removedCount = 0;

    _errorPatterns.forEach((pattern, occurrences) {
      final filteredOccurrences = occurrences
          .where((occurrence) => occurrence.timestamp.isAfter(cutoffDate))
          .toList();

      removedCount += occurrences.length - filteredOccurrences.length;
      _errorPatterns[pattern] = filteredOccurrences;
    });

    // Remover patrones vacíos
    _errorPatterns.removeWhere((pattern, occurrences) => occurrences.isEmpty);

    if (removedCount > 0) {
      LoggerFactory.info('🧹 Cleaned up $removedCount old error occurrences');
    }
  }

  /// Exporta estadísticas de errores como JSON
  String exportErrorStatistics() {
    final stats = getErrorStatistics();
    return const JsonEncoder.withIndent('  ').convert(stats);
  }
}

/// Representa una ocurrencia de error con contexto completo
class ErrorOccurrence {
  const ErrorOccurrence({
    required this.correlationId,
    required this.errorType,
    required this.errorMessage,
    this.operation,
    this.tableName,
    required this.timestamp,
    required this.deviceInfo,
    required this.additionalContext,
  });

  final String correlationId;
  final String errorType;
  final String errorMessage;
  final String? operation;
  final String? tableName;
  final DateTime timestamp;
  final Map<String, dynamic> deviceInfo;
  final Map<String, dynamic> additionalContext;

  Map<String, dynamic> toJson() => {
        'correlation_id': correlationId,
        'error_type': errorType,
        'error_message': errorMessage,
        'operation': operation,
        'table_name': tableName,
        'timestamp': timestamp.toIso8601String(),
        'device_info': deviceInfo,
        'additional_context': additionalContext,
      };
}
