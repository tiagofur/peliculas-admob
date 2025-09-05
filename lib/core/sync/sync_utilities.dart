import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Utilidades comunes para el sistema de sincronización
class SyncUtilities {
  static const _uuid = Uuid();
  static const String _deviceIdKey = 'sync_device_id';
  static String? _cachedDeviceId;

  // =============================================
  // GENERACIÓN DE IDs
  // =============================================

  /// Genera un nuevo UUID v4 para entidades
  static String generateUuid() {
    return _uuid.v4();
  }

  /// Genera un ID de dispositivo único y persistente
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      // Generar nuevo device ID único
      deviceId = '${_uuid.v4()}-${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_deviceIdKey, deviceId);
    }

    _cachedDeviceId = deviceId;
    return deviceId;
  }

  /// Resetea el device ID (útil para testing)
  static Future<void> resetDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceIdKey);
    _cachedDeviceId = null;
  }

  // =============================================
  // CHECKSUMS Y HASHING
  // =============================================

  /// Genera un checksum MD5 de un mapa de datos
  static String generateChecksum(Map<String, dynamic> data) {
    // Ordenar las claves para consistencia
    final sortedKeys = data.keys.toList()..sort();
    final sortedData = <String, dynamic>{};

    for (final key in sortedKeys) {
      // Excluir campos que no afectan el contenido
      if (!_excludedFieldsForChecksum.contains(key)) {
        sortedData[key] = data[key];
      }
    }

    final jsonString = json.encode(sortedData);
    final bytes = utf8.encode(jsonString);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Campos que se excluyen del cálculo de checksum
  static const _excludedFieldsForChecksum = {
    'id',
    'created_at',
    'last_modified_at',
    'sync_version',
    'device_id',
    'updated_at' // Para compatibilidad con esquemas antiguos
  };

  /// Compara dos mapas de datos por contenido
  static bool hasSameContent(
      Map<String, dynamic> data1, Map<String, dynamic> data2) {
    return generateChecksum(data1) == generateChecksum(data2);
  }

  // =============================================
  // TIMESTAMPS Y FECHAS
  // =============================================

  /// Obtiene el timestamp actual en UTC
  static DateTime utcNow() {
    return DateTime.now().toUtc();
  }

  /// Convierte un DateTime a formato ISO 8601 para Supabase
  static String dateTimeToIso(DateTime dateTime) {
    return dateTime.toUtc().toIso8601String();
  }

  /// Convierte un string ISO 8601 a DateTime
  static DateTime? dateTimeFromIso(String? isoString) {
    if (isoString == null) return null;
    return DateTime.parse(isoString).toUtc();
  }

  /// Verifica si un timestamp está dentro de una tolerancia
  static bool isWithinTolerance(DateTime timestamp1, DateTime timestamp2,
      {Duration tolerance = const Duration(seconds: 1)}) {
    final diff = timestamp1.difference(timestamp2).abs();
    return diff <= tolerance;
  }

  // =============================================
  // VALIDACIÓN DE DATOS
  // =============================================

  /// Valida que un UUID tenga formato correcto
  static bool isValidUuid(String? uuid) {
    if (uuid == null || uuid.isEmpty) return false;

    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    return uuidRegex.hasMatch(uuid);
  }

  /// Valida que un user_id sea válido (UUID o email)
  static bool isValidUserId(String? userId) {
    if (userId == null || userId.isEmpty) return false;

    // Puede ser UUID o email
    return isValidUuid(userId) || userId.contains('@');
  }

  /// Sanitiza datos JSON para evitar problemas de serialización
  static Map<String, dynamic> sanitizeJsonData(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value == null) {
        sanitized[key] = null;
      } else if (value is String) {
        sanitized[key] = value.trim();
      } else if (value is DateTime) {
        sanitized[key] = dateTimeToIso(value);
      } else if (value is Map<String, dynamic>) {
        sanitized[key] = sanitizeJsonData(value);
      } else if (value is List) {
        sanitized[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return sanitizeJsonData(item);
          }
          return item;
        }).toList();
      } else {
        sanitized[key] = value;
      }
    }

    return sanitized;
  }

  // =============================================
  // RETRY Y BACKOFF
  // =============================================

  /// Calcula el delay para retry con exponential backoff
  static Duration calculateBackoffDelay(int retryCount) {
    const baseDelay = Duration(seconds: 2);
    const maxDelay = Duration(minutes: 5);

    // 2^retryCount seconds con jitter
    final exponentialDelay = Duration(
        milliseconds: baseDelay.inMilliseconds * pow(2, retryCount).toInt());

    // Agregar jitter aleatorio (±25%)
    final random = Random();
    final jitter = exponentialDelay.inMilliseconds * 0.25;
    final jitteredDelay = Duration(
        milliseconds: exponentialDelay.inMilliseconds +
            (random.nextDouble() * jitter * 2 - jitter).toInt());

    // No exceder el máximo
    return jitteredDelay > maxDelay ? maxDelay : jitteredDelay;
  }

  /// Determina si un error es recuperable (se puede reintentar)
  static bool isRetryableError(dynamic error) {
    if (error == null) return false;

    final errorString = error.toString().toLowerCase();

    // Errores de red que se pueden reintentar
    final retryablePatterns = [
      'timeout',
      'connection refused',
      'network error',
      'socket exception',
      'temporarily unavailable',
      'service unavailable',
      'bad gateway',
      'gateway timeout',
    ];

    return retryablePatterns.any((pattern) => errorString.contains(pattern));
  }

  // =============================================
  // COMPARACIÓN Y CONFLICTOS
  // =============================================

  /// Compara dos versiones de sync para determinar precedencia
  static int compareSyncVersions(int version1, int version2) {
    return version1.compareTo(version2);
  }

  /// Compara dos timestamps para determinar cuál es más reciente
  static int compareTimestamps(DateTime timestamp1, DateTime timestamp2) {
    return timestamp1.compareTo(timestamp2);
  }

  /// Determina si una entidad local tiene precedencia sobre una remota
  static bool hasLocalPrecedence({
    required int localVersion,
    required int remoteVersion,
    required DateTime localTimestamp,
    required DateTime remoteTimestamp,
    required String localId,
    required String remoteId,
  }) {
    // 1. Comparar versiones de sync primero
    final versionComparison = compareSyncVersions(localVersion, remoteVersion);
    if (versionComparison != 0) {
      return versionComparison > 0;
    }

    // 2. Si las versiones son iguales, usar timestamp
    final timestampComparison =
        compareTimestamps(localTimestamp, remoteTimestamp);
    if (timestampComparison != 0) {
      return timestampComparison > 0;
    }

    // 3. Si todo es igual, usar ID como tie-breaker
    return localId.compareTo(remoteId) > 0;
  }

  // =============================================
  // BATCH OPERATIONS
  // =============================================

  /// Divide una lista en chunks del tamaño especificado
  static List<List<T>> chunkList<T>(List<T> list, int chunkSize) {
    if (chunkSize <= 0) throw ArgumentError('Chunk size must be positive');

    final chunks = <List<T>>[];
    for (int i = 0; i < list.length; i += chunkSize) {
      final end = i + chunkSize;
      chunks.add(list.sublist(i, end > list.length ? list.length : end));
    }
    return chunks;
  }

  /// Tamaño recomendado de batch para operaciones de sync
  static const int defaultBatchSize = 50;

  // =============================================
  // LOGGING Y DEBUG
  // =============================================

  /// Formatea información de entidad para logging
  static String formatEntityInfo(
    String entityType,
    String id,
    int syncVersion,
    DateTime lastModified,
  ) {
    return '$entityType(id: ${id.substring(0, 8)}..., '
        'v$syncVersion, modified: ${lastModified.toIso8601String()})';
  }

  /// Calcula estadísticas básicas de una operación de sync
  static Map<String, dynamic> calculateSyncStats({
    required int totalItems,
    required int successfulItems,
    required int failedItems,
    required Duration totalDuration,
  }) {
    final successRate = totalItems > 0 ? successfulItems / totalItems : 0.0;
    final avgTimePerItem =
        totalItems > 0 ? totalDuration.inMilliseconds / totalItems : 0.0;

    return {
      'total_items': totalItems,
      'successful_items': successfulItems,
      'failed_items': failedItems,
      'success_rate': successRate,
      'total_duration_ms': totalDuration.inMilliseconds,
      'avg_time_per_item_ms': avgTimePerItem,
    };
  }

  // =============================================
  // SERIALIZACIÓN JSON
  // =============================================

  /// Codifica un Map a JSON string
  static String encodeJson(Map<String, dynamic> data) {
    try {
      final sanitized = sanitizeJsonData(data);
      return json.encode(sanitized);
    } catch (e) {
      throw FormatException('Failed to encode JSON: $e');
    }
  }

  /// Decodifica un JSON string a Map
  static Map<String, dynamic> decodeJson(String jsonString) {
    try {
      final decoded = json.decode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else {
        throw const FormatException('JSON is not a Map<String, dynamic>');
      }
    } catch (e) {
      throw FormatException('Failed to decode JSON: $e');
    }
  }
}
