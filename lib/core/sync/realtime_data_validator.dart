import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../logging/logger_factory.dart';

/// Validador de datos para eventos real-time
/// Proporciona validación de integridad, checksums y estructura de datos
class RealtimeDataValidator {
  RealtimeDataValidator._internal();
  static final RealtimeDataValidator _instance =
      RealtimeDataValidator._internal();
  static RealtimeDataValidator get instance => _instance;

  // Esquemas de validación por tabla
  final Map<String, TableSchema> _tableSchemas = {};

  // Cache de checksums para evitar recálculos
  final Map<String, String> _checksumCache = {};

  // Estadísticas de validación
  final Map<String, ValidationStats> _validationStats = {};

  /// Inicializa los esquemas de validación
  void initialize() {
    _initializeTableSchemas();
    LoggerFactory.info('✅ RealtimeDataValidator inicializado');
  }

  /// Valida un evento real-time completo
  ValidationResult validateRealtimeEvent({
    required String tableName,
    required Map<String, dynamic> eventData,
    required String eventType,
    Map<String, dynamic>? oldRecord,
    Map<String, dynamic>? newRecord,
  }) {
    final startTime = DateTime.now();

    try {
      // 1. Validar estructura básica del evento
      final structureResult = _validateEventStructure(eventData, eventType);
      if (!structureResult.isValid) {
        return _recordValidationResult(tableName, structureResult, startTime);
      }

      // 2. Validar esquema de la tabla
      final schemaResult =
          _validateTableSchema(tableName, newRecord ?? oldRecord ?? eventData);
      if (!schemaResult.isValid) {
        return _recordValidationResult(tableName, schemaResult, startTime);
      }

      // 3. Validar integridad de datos
      final integrityResult =
          _validateDataIntegrity(tableName, newRecord ?? eventData);
      if (!integrityResult.isValid) {
        return _recordValidationResult(tableName, integrityResult, startTime);
      }

      // 4. Validar checksum si está presente
      final checksumResult =
          _validateChecksum(tableName, newRecord ?? eventData);
      if (!checksumResult.isValid) {
        return _recordValidationResult(tableName, checksumResult, startTime);
      }

      // 5. Validaciones específicas por tipo de evento
      final eventTypeResult =
          _validateEventType(eventType, oldRecord, newRecord);
      if (!eventTypeResult.isValid) {
        return _recordValidationResult(tableName, eventTypeResult, startTime);
      }

      const successResult = ValidationResult(
        isValid: true,
        message: 'Evento validado correctamente',
        validationType: ValidationType.complete,
      );

      return _recordValidationResult(tableName, successResult, startTime);
    } catch (e) {
      final errorResult = ValidationResult(
        isValid: false,
        message: 'Error durante validación: $e',
        validationType: ValidationType.error,
        errorCode: 'VALIDATION_EXCEPTION',
      );

      return _recordValidationResult(tableName, errorResult, startTime);
    }
  }

  /// Genera checksum para un registro
  String generateChecksum(Map<String, dynamic> data) {
    // Crear una representación consistente de los datos
    final sortedData = _sortMapRecursively(data);
    final jsonString = jsonEncode(sortedData);

    // Generar hash SHA-256
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);

    return digest.toString();
  }

  /// Valida checksum de un registro
  bool validateChecksum(Map<String, dynamic> data, String expectedChecksum) {
    final actualChecksum = generateChecksum(data);
    return actualChecksum == expectedChecksum;
  }

  /// Añade checksum a un registro
  Map<String, dynamic> addChecksum(Map<String, dynamic> data) {
    final dataWithoutChecksum = Map<String, dynamic>.from(data);
    dataWithoutChecksum.remove('_checksum');

    final checksum = generateChecksum(dataWithoutChecksum);

    return {
      ...data,
      '_checksum': checksum,
    };
  }

  /// Obtiene estadísticas de validación
  Map<String, dynamic> getValidationStatistics() {
    return {
      'table_stats': _validationStats.map(
        (table, stats) => MapEntry(table, stats.toMap()),
      ),
      'total_validations': _validationStats.values
          .map((s) => s.totalValidations)
          .fold(0, (a, b) => a + b),
      'total_failures': _validationStats.values
          .map((s) => s.failedValidations)
          .fold(0, (a, b) => a + b),
      'overall_success_rate': _calculateOverallSuccessRate(),
      'cache_size': _checksumCache.length,
    };
  }

  /// Limpia cache de checksums
  void clearChecksumCache() {
    _checksumCache.clear();
    LoggerFactory.info('🧹 Cache de checksums limpiado');
  }

  // Métodos privados de validación

  ValidationResult _validateEventStructure(
      Map<String, dynamic> eventData, String eventType) {
    // Validar que el evento tenga los campos básicos requeridos
    final requiredFields = ['table', 'schema'];

    for (final field in requiredFields) {
      if (!eventData.containsKey(field)) {
        return ValidationResult(
          isValid: false,
          message: 'Campo requerido faltante: $field',
          validationType: ValidationType.structure,
          errorCode: 'MISSING_REQUIRED_FIELD',
        );
      }
    }

    // Validar tipo de evento
    final validEventTypes = ['INSERT', 'UPDATE', 'DELETE'];
    if (!validEventTypes.contains(eventType.toUpperCase())) {
      return ValidationResult(
        isValid: false,
        message: 'Tipo de evento inválido: $eventType',
        validationType: ValidationType.structure,
        errorCode: 'INVALID_EVENT_TYPE',
      );
    }

    return const ValidationResult(
      isValid: true,
      message: 'Estructura de evento válida',
      validationType: ValidationType.structure,
    );
  }

  ValidationResult _validateTableSchema(
      String tableName, Map<String, dynamic> data) {
    final schema = _tableSchemas[tableName];
    if (schema == null) {
      LoggerFactory.warning('⚠️ Esquema no encontrado para tabla: $tableName');
      return ValidationResult(
        isValid: true, // No fallar si no hay esquema definido
        message: 'Esquema no definido para $tableName',
        validationType: ValidationType.schema,
      );
    }

    // Validar campos requeridos
    for (final requiredField in schema.requiredFields) {
      if (!data.containsKey(requiredField)) {
        return ValidationResult(
          isValid: false,
          message: 'Campo requerido faltante: $requiredField',
          validationType: ValidationType.schema,
          errorCode: 'MISSING_REQUIRED_FIELD',
        );
      }
    }

    // Validar tipos de datos
    for (final entry in schema.fieldTypes.entries) {
      final fieldName = entry.key;
      final expectedType = entry.value;

      if (data.containsKey(fieldName)) {
        final actualValue = data[fieldName];
        if (!_isValidType(actualValue, expectedType)) {
          return ValidationResult(
            isValid: false,
            message:
                'Tipo de dato inválido para $fieldName: esperado $expectedType',
            validationType: ValidationType.schema,
            errorCode: 'INVALID_DATA_TYPE',
          );
        }
      }
    }

    return const ValidationResult(
      isValid: true,
      message: 'Esquema válido',
      validationType: ValidationType.schema,
    );
  }

  ValidationResult _validateDataIntegrity(
      String tableName, Map<String, dynamic> data) {
    // Validar IDs
    if (data.containsKey('id')) {
      final id = data['id'];
      if (id == null || id.toString().isEmpty) {
        return const ValidationResult(
          isValid: false,
          message: 'ID no puede estar vacío',
          validationType: ValidationType.integrity,
          errorCode: 'EMPTY_ID',
        );
      }
    }

    // Validar user_id para tablas de usuario
    if (tableName.startsWith('user_') && data.containsKey('user_id')) {
      final userId = data['user_id'];
      if (userId == null || userId.toString().isEmpty) {
        return const ValidationResult(
          isValid: false,
          message: 'user_id no puede estar vacío en tabla de usuario',
          validationType: ValidationType.integrity,
          errorCode: 'EMPTY_USER_ID',
        );
      }
    }

    // Validar timestamps
    final timestampFields = ['created_at', 'updated_at', 'last_modified_at'];
    for (final field in timestampFields) {
      if (data.containsKey(field)) {
        final timestamp = data[field];
        if (timestamp != null && !_isValidTimestamp(timestamp)) {
          return ValidationResult(
            isValid: false,
            message: 'Timestamp inválido para $field: $timestamp',
            validationType: ValidationType.integrity,
            errorCode: 'INVALID_TIMESTAMP',
          );
        }
      }
    }

    // Validar campos booleanos
    final booleanFields = ['is_deleted', 'is_default', 'is_public'];
    for (final field in booleanFields) {
      if (data.containsKey(field)) {
        final value = data[field];
        if (value != null && value is! bool) {
          return ValidationResult(
            isValid: false,
            message: 'Campo booleano inválido para $field: $value',
            validationType: ValidationType.integrity,
            errorCode: 'INVALID_BOOLEAN',
          );
        }
      }
    }

    return const ValidationResult(
      isValid: true,
      message: 'Integridad de datos válida',
      validationType: ValidationType.integrity,
    );
  }

  ValidationResult _validateChecksum(
      String tableName, Map<String, dynamic> data) {
    if (!data.containsKey('_checksum')) {
      // Checksum opcional, no fallar si no está presente
      return const ValidationResult(
        isValid: true,
        message: 'Sin checksum para validar',
        validationType: ValidationType.checksum,
      );
    }

    final expectedChecksum = data['_checksum'] as String;
    final dataWithoutChecksum = Map<String, dynamic>.from(data);
    dataWithoutChecksum.remove('_checksum');

    // Usar cache si está disponible
    final cacheKey = '${tableName}_${data['id']}';
    String actualChecksum;

    if (_checksumCache.containsKey(cacheKey)) {
      actualChecksum = _checksumCache[cacheKey]!;
    } else {
      actualChecksum = generateChecksum(dataWithoutChecksum);
      _checksumCache[cacheKey] = actualChecksum;
    }

    if (actualChecksum != expectedChecksum) {
      return ValidationResult(
        isValid: false,
        message:
            'Checksum inválido: esperado $expectedChecksum, actual $actualChecksum',
        validationType: ValidationType.checksum,
        errorCode: 'CHECKSUM_MISMATCH',
      );
    }

    return const ValidationResult(
      isValid: true,
      message: 'Checksum válido',
      validationType: ValidationType.checksum,
    );
  }

  ValidationResult _validateEventType(String eventType,
      Map<String, dynamic>? oldRecord, Map<String, dynamic>? newRecord) {
    switch (eventType.toUpperCase()) {
      case 'INSERT':
        if (newRecord == null) {
          return const ValidationResult(
            isValid: false,
            message: 'INSERT requiere newRecord',
            validationType: ValidationType.eventType,
            errorCode: 'MISSING_NEW_RECORD',
          );
        }
        break;

      case 'UPDATE':
        if (newRecord == null || oldRecord == null) {
          return const ValidationResult(
            isValid: false,
            message: 'UPDATE requiere oldRecord y newRecord',
            validationType: ValidationType.eventType,
            errorCode: 'MISSING_RECORDS',
          );
        }
        break;

      case 'DELETE':
        if (oldRecord == null) {
          return const ValidationResult(
            isValid: false,
            message: 'DELETE requiere oldRecord',
            validationType: ValidationType.eventType,
            errorCode: 'MISSING_OLD_RECORD',
          );
        }
        break;
    }

    return const ValidationResult(
      isValid: true,
      message: 'Tipo de evento válido',
      validationType: ValidationType.eventType,
    );
  }

  // Métodos de utilidad

  void _initializeTableSchemas() {
    // Esquema para user_favorites
    _tableSchemas['user_favorites'] = const TableSchema(
      requiredFields: ['id', 'user_id', 'movie_id'],
      fieldTypes: {
        'id': FieldType.string,
        'user_id': FieldType.string,
        'movie_id': FieldType.integer,
        'created_at': FieldType.timestamp,
        'updated_at': FieldType.timestamp,
        'is_deleted': FieldType.boolean,
        'sync_version': FieldType.integer,
        'device_id': FieldType.string,
      },
    );

    // Esquema para user_watched_movies
    _tableSchemas['user_watched'] = const TableSchema(
      requiredFields: ['id', 'user_id', 'movie_id'],
      fieldTypes: {
        'id': FieldType.string,
        'user_id': FieldType.string,
        'movie_id': FieldType.integer,
        'watched_at': FieldType.timestamp,
        'rating': FieldType.double,
        'created_at': FieldType.timestamp,
        'updated_at': FieldType.timestamp,
        'is_deleted': FieldType.boolean,
        'sync_version': FieldType.integer,
        'device_id': FieldType.string,
      },
    );

    // Esquema para user_lists
    _tableSchemas['user_lists'] = const TableSchema(
      requiredFields: ['id', 'user_id', 'name'],
      fieldTypes: {
        'id': FieldType.string,
        'user_id': FieldType.string,
        'name': FieldType.string,
        'description': FieldType.string,
        'emoji': FieldType.string,
        'color': FieldType.string,
        'is_default': FieldType.boolean,
        'is_public': FieldType.boolean,
        'created_at': FieldType.timestamp,
        'updated_at': FieldType.timestamp,
        'is_deleted': FieldType.boolean,
        'sync_version': FieldType.integer,
        'device_id': FieldType.string,
      },
    );

    // Esquema para user_list_items
    _tableSchemas['user_list_items'] = const TableSchema(
      requiredFields: ['id', 'list_id', 'movie_id'],
      fieldTypes: {
        'id': FieldType.string,
        'list_id': FieldType.string,
        'movie_id': FieldType.integer,
        'added_at': FieldType.timestamp,
        'notes': FieldType.string,
        'created_at': FieldType.timestamp,
        'updated_at': FieldType.timestamp,
        'is_deleted': FieldType.boolean,
        'sync_version': FieldType.integer,
        'device_id': FieldType.string,
      },
    );

    LoggerFactory.info(
        '📋 Esquemas de validación inicializados para ${_tableSchemas.length} tablas');
  }

  bool _isValidType(dynamic value, FieldType expectedType) {
    if (value == null) return true; // Null es válido para campos opcionales

    switch (expectedType) {
      case FieldType.string:
        return value is String;
      case FieldType.integer:
        return value is int || (value is String && int.tryParse(value) != null);
      case FieldType.double:
        return value is double ||
            value is int ||
            (value is String && double.tryParse(value) != null);
      case FieldType.boolean:
        return value is bool;
      case FieldType.timestamp:
        return _isValidTimestamp(value);
      case FieldType.json:
        return value is Map || value is List;
    }
  }

  bool _isValidTimestamp(dynamic value) {
    if (value is DateTime) return true;
    if (value is String) {
      try {
        DateTime.parse(value);
        return true;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  Map<String, dynamic> _sortMapRecursively(Map<String, dynamic> map) {
    final sortedMap = <String, dynamic>{};
    final sortedKeys = map.keys.toList()..sort();

    for (final key in sortedKeys) {
      final value = map[key];
      if (value is Map<String, dynamic>) {
        sortedMap[key] = _sortMapRecursively(value);
      } else if (value is List) {
        sortedMap[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _sortMapRecursively(item);
          }
          return item;
        }).toList();
      } else {
        sortedMap[key] = value;
      }
    }

    return sortedMap;
  }

  ValidationResult _recordValidationResult(
      String tableName, ValidationResult result, DateTime startTime) {
    final stats = _validationStats.putIfAbsent(
      tableName,
      () => ValidationStats(tableName: tableName),
    );

    final processingTime = DateTime.now().difference(startTime);
    stats.recordValidation(result.isValid, processingTime);

    if (!result.isValid) {
      LoggerFactory.warning(
          '❌ Validación fallida para $tableName: ${result.message} (${result.errorCode ?? 'N/A'})');
    } else {
      LoggerFactory.debug(
          '✅ Validación exitosa para $tableName: ${result.message}');
    }

    return result;
  }

  double _calculateOverallSuccessRate() {
    if (_validationStats.isEmpty) return 1.0;

    final totalValidations = _validationStats.values
        .map((s) => s.totalValidations)
        .fold(0, (a, b) => a + b);

    if (totalValidations == 0) return 1.0;

    final successfulValidations = _validationStats.values
        .map((s) => s.successfulValidations)
        .fold(0, (a, b) => a + b);

    return successfulValidations / totalValidations;
  }
}

// Clases de soporte

class ValidationResult {
  const ValidationResult({
    required this.isValid,
    required this.message,
    required this.validationType,
    this.errorCode,
  });

  final bool isValid;
  final String message;
  final ValidationType validationType;
  final String? errorCode;
}

class TableSchema {
  const TableSchema({
    required this.requiredFields,
    required this.fieldTypes,
  });

  final List<String> requiredFields;
  final Map<String, FieldType> fieldTypes;
}

class ValidationStats {
  ValidationStats({required this.tableName});

  final String tableName;
  int totalValidations = 0;
  int successfulValidations = 0;
  int failedValidations = 0;
  Duration totalProcessingTime = Duration.zero;

  void recordValidation(bool success, Duration processingTime) {
    totalValidations++;
    if (success) {
      successfulValidations++;
    } else {
      failedValidations++;
    }
    totalProcessingTime += processingTime;
  }

  double get successRate =>
      totalValidations > 0 ? successfulValidations / totalValidations : 1.0;

  Duration get averageProcessingTime => totalValidations > 0
      ? Duration(
          microseconds: totalProcessingTime.inMicroseconds ~/ totalValidations)
      : Duration.zero;

  Map<String, dynamic> toMap() {
    return {
      'table_name': tableName,
      'total_validations': totalValidations,
      'successful_validations': successfulValidations,
      'failed_validations': failedValidations,
      'success_rate': successRate,
      'average_processing_time_ms': averageProcessingTime.inMilliseconds,
      'total_processing_time_ms': totalProcessingTime.inMilliseconds,
    };
  }
}

enum ValidationType {
  structure,
  schema,
  integrity,
  checksum,
  eventType,
  complete,
  error,
}

enum FieldType {
  string,
  integer,
  double,
  boolean,
  timestamp,
  json,
}
