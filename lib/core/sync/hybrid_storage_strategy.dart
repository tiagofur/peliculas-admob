import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/syncable_entity.dart';
import '../logging/logger_factory.dart';

/// Estrategia de almacenamiento local híbrido para el sistema de sincronización
///
/// Esta clase define cómo usar diferentes tecnologías de almacenamiento
/// según el tipo de datos y los requisitos de rendimiento:
///
/// - **SharedPreferences**: Configuración, metadatos de sync, device_id
/// - **Hive**: Entidades syncables, cache de datos, operaciones frecuentes
/// - **Isar**: Búsquedas complejas, relaciones, índices avanzados (futuro)
class HybridStorageStrategy {
  HybridStorageStrategy._();
  static HybridStorageStrategy? _instance;
  static HybridStorageStrategy get instance {
    _instance ??= HybridStorageStrategy._();
    return _instance!;
  }

  // =============================================
  // CONFIGURACIÓN DE ALMACENAMIENTO
  // =============================================

  /// Configuración de qué usar para cada tipo de dato
  static const Map<StorageType, StorageTechnology> _storageConfig = {
    StorageType.syncMetadata: StorageTechnology.sharedPreferences,
    StorageType.deviceInfo: StorageTechnology.sharedPreferences,
    StorageType.userPreferences: StorageTechnology.sharedPreferences,
    StorageType.syncableEntities: StorageTechnology.hive,
    StorageType.operationQueue: StorageTechnology.hive,
    StorageType.conflictResolution: StorageTechnology.hive,
    StorageType.searchIndex: StorageTechnology.isar, // Futuro
    StorageType.analytics: StorageTechnology.hive,
  };

  /// Obtiene la tecnología recomendada para un tipo de almacenamiento
  static StorageTechnology getTechnologyFor(StorageType type) {
    return _storageConfig[type] ?? StorageTechnology.hive;
  }

  // =============================================
  // SHARED PREFERENCES - METADATOS Y CONFIGURACIÓN
  // =============================================

  /// Almacena metadatos de sincronización en SharedPreferences
  static Future<void> storeSyncMetadata(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefKey = 'sync_meta_$key';

      if (value is String) {
        await prefs.setString(prefKey, value);
      } else if (value is int) {
        await prefs.setInt(prefKey, value);
      } else if (value is double) {
        await prefs.setDouble(prefKey, value);
      } else if (value is bool) {
        await prefs.setBool(prefKey, value);
      } else if (value is List<String>) {
        await prefs.setStringList(prefKey, value);
      } else {
        await prefs.setString(prefKey, value.toString());
      }
    } catch (e) {
      LoggerFactory.error('Error storing sync metadata: $e');
      rethrow;
    }
  }

  /// Recupera metadatos de sincronización desde SharedPreferences
  static Future<T?> getSyncMetadata<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefKey = 'sync_meta_$key';

      final value = prefs.get(prefKey);
      return value as T?;
    } catch (e) {
      LoggerFactory.error('Error getting sync metadata: $e');
      return null;
    }
  }

  /// Almacena información del dispositivo
  static Future<void> storeDeviceInfo(
      String deviceId, Map<String, dynamic> info) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_id', deviceId);
      await prefs.setString('device_info', info.toString());
      await prefs.setInt(
          'last_sync_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      LoggerFactory.error('Error storing device info: $e');
      rethrow;
    }
  }

  /// Recupera información del dispositivo
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'device_id': prefs.getString('device_id'),
        'device_info': prefs.getString('device_info'),
        'last_sync_timestamp': prefs.getInt('last_sync_timestamp'),
      };
    } catch (e) {
      LoggerFactory.error('Error getting device info: $e');
      return {};
    }
  }

  // =============================================
  // HIVE - ENTIDADES SYNCABLES Y OPERACIONES
  // =============================================

  static Box<Map>? _syncableEntitiesBox;
  static Box<Map>? _operationQueueBox;
  static Box<Map>? _conflictResolutionBox;
  static bool _hiveInitialized = false;

  /// Inicializa Hive para almacenamiento de entidades syncables
  static Future<void> initializeHive() async {
    if (_hiveInitialized) return;

    try {
      await Hive.initFlutter();

      // Abrir boxes para diferentes tipos de datos
      _syncableEntitiesBox = await Hive.openBox<Map>('syncable_entities');
      _operationQueueBox = await Hive.openBox<Map>('operation_queue');
      _conflictResolutionBox = await Hive.openBox<Map>('conflict_resolution');

      _hiveInitialized = true;
      LoggerFactory.info('Hive initialized successfully for sync storage');
    } catch (e) {
      LoggerFactory.error('Error initializing Hive: $e');
      rethrow;
    }
  }

  /// Almacena una entidad syncable en Hive
  static Future<void> storeSyncableEntity(SyncableEntity entity) async {
    await initializeHive();

    try {
      final box = _syncableEntitiesBox!;
      final key = '${entity.entityType}_${entity.id}';
      await box.put(key, entity.toLocalStorage());

      LoggerFactory.debug('Stored syncable entity: $key');
    } catch (e) {
      LoggerFactory.error('Error storing syncable entity: $e');
      rethrow;
    }
  }

  /// Recupera una entidad syncable desde Hive
  static Future<Map<String, dynamic>?> getSyncableEntity(
      String entityType, String id) async {
    await initializeHive();

    try {
      final box = _syncableEntitiesBox!;
      final key = '${entityType}_$id';
      final data = box.get(key);

      return data?.cast<String, dynamic>();
    } catch (e) {
      LoggerFactory.error('Error getting syncable entity: $e');
      return null;
    }
  }

  /// Obtiene todas las entidades de un tipo específico
  static Future<List<Map<String, dynamic>>> getSyncableEntitiesByType(
      String entityType) async {
    await initializeHive();

    try {
      final box = _syncableEntitiesBox!;
      final entities = <Map<String, dynamic>>[];

      for (final key in box.keys) {
        if (key.toString().startsWith('${entityType}_')) {
          final data = box.get(key);
          if (data != null) {
            entities.add(data.cast<String, dynamic>());
          }
        }
      }

      return entities;
    } catch (e) {
      LoggerFactory.error('Error getting syncable entities by type: $e');
      return [];
    }
  }

  /// Elimina una entidad syncable
  static Future<void> deleteSyncableEntity(String entityType, String id) async {
    await initializeHive();

    try {
      final box = _syncableEntitiesBox!;
      final key = '${entityType}_$id';
      await box.delete(key);

      LoggerFactory.debug('Deleted syncable entity: $key');
    } catch (e) {
      LoggerFactory.error('Error deleting syncable entity: $e');
      rethrow;
    }
  }

  /// Almacena una operación en la cola de sincronización
  static Future<void> storeOperation(
      String operationId, Map<String, dynamic> operation) async {
    await initializeHive();

    try {
      final box = _operationQueueBox!;
      await box.put(operationId, operation);

      LoggerFactory.debug('Stored sync operation: $operationId');
    } catch (e) {
      LoggerFactory.error('Error storing sync operation: $e');
      rethrow;
    }
  }

  /// Recupera todas las operaciones pendientes
  static Future<Map<String, Map<String, dynamic>>>
      getPendingOperations() async {
    await initializeHive();

    try {
      final box = _operationQueueBox!;
      final operations = <String, Map<String, dynamic>>{};

      for (final key in box.keys) {
        final data = box.get(key);
        if (data != null) {
          operations[key.toString()] = data.cast<String, dynamic>();
        }
      }

      return operations;
    } catch (e) {
      LoggerFactory.error('Error getting pending operations: $e');
      return {};
    }
  }

  /// Elimina una operación de la cola
  static Future<void> removeOperation(String operationId) async {
    await initializeHive();

    try {
      final box = _operationQueueBox!;
      await box.delete(operationId);

      LoggerFactory.debug('Removed sync operation: $operationId');
    } catch (e) {
      LoggerFactory.error('Error removing sync operation: $e');
      rethrow;
    }
  }

  // =============================================
  // RESOLUCIÓN DE CONFLICTOS
  // =============================================

  /// Almacena información de conflicto
  static Future<void> storeConflict(
      String conflictId, Map<String, dynamic> conflictData) async {
    await initializeHive();

    try {
      final box = _conflictResolutionBox!;
      await box.put(conflictId, conflictData);

      LoggerFactory.debug('Stored conflict: $conflictId');
    } catch (e) {
      LoggerFactory.error('Error storing conflict: $e');
      rethrow;
    }
  }

  /// Recupera todos los conflictos pendientes
  static Future<Map<String, Map<String, dynamic>>> getPendingConflicts() async {
    await initializeHive();

    try {
      final box = _conflictResolutionBox!;
      final conflicts = <String, Map<String, dynamic>>{};

      for (final key in box.keys) {
        final data = box.get(key);
        if (data != null) {
          conflicts[key.toString()] = data.cast<String, dynamic>();
        }
      }

      return conflicts;
    } catch (e) {
      LoggerFactory.error('Error getting pending conflicts: $e');
      return {};
    }
  }

  /// Resuelve un conflicto (lo elimina del almacenamiento)
  static Future<void> resolveConflict(String conflictId) async {
    await initializeHive();

    try {
      final box = _conflictResolutionBox!;
      await box.delete(conflictId);

      LoggerFactory.debug('Resolved conflict: $conflictId');
    } catch (e) {
      LoggerFactory.error('Error resolving conflict: $e');
      rethrow;
    }
  }

  // =============================================
  // LIMPIEZA Y MANTENIMIENTO
  // =============================================

  /// Limpia datos expirados y optimiza el almacenamiento
  static Future<void> performMaintenance() async {
    try {
      LoggerFactory.info('Starting storage maintenance...');

      // Limpiar entidades marcadas como eliminadas hace más de 30 días
      await _cleanupDeletedEntities();

      // Limpiar operaciones completadas hace más de 7 días
      await _cleanupCompletedOperations();

      // Limpiar conflictos resueltos hace más de 7 días
      await _cleanupResolvedConflicts();

      LoggerFactory.info('Storage maintenance completed');
    } catch (e) {
      LoggerFactory.error('Error during storage maintenance: $e');
    }
  }

  static Future<void> _cleanupDeletedEntities() async {
    await initializeHive();

    final box = _syncableEntitiesBox!;
    final keysToDelete = <String>[];
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));

    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        final entity = data.cast<String, dynamic>();
        final isDeleted = entity['isDeleted'] as bool? ?? false;
        final lastModified =
            DateTime.tryParse(entity['lastModifiedAt'] as String? ?? '');

        if (isDeleted &&
            lastModified != null &&
            lastModified.isBefore(cutoffDate)) {
          keysToDelete.add(key.toString());
        }
      }
    }

    for (final key in keysToDelete) {
      await box.delete(key);
    }

    LoggerFactory.info('Cleaned up ${keysToDelete.length} deleted entities');
  }

  static Future<void> _cleanupCompletedOperations() async {
    await initializeHive();

    final box = _operationQueueBox!;
    final keysToDelete = <String>[];
    final cutoffDate = DateTime.now().subtract(const Duration(days: 7));

    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        final operation = data.cast<String, dynamic>();
        final status = operation['status'] as String? ?? '';
        final completedAt =
            DateTime.tryParse(operation['completedAt'] as String? ?? '');

        if (status == 'completed' &&
            completedAt != null &&
            completedAt.isBefore(cutoffDate)) {
          keysToDelete.add(key.toString());
        }
      }
    }

    for (final key in keysToDelete) {
      await box.delete(key);
    }

    LoggerFactory.info(
        'Cleaned up ${keysToDelete.length} completed operations');
  }

  static Future<void> _cleanupResolvedConflicts() async {
    await initializeHive();

    final box = _conflictResolutionBox!;
    final keysToDelete = <String>[];
    final cutoffDate = DateTime.now().subtract(const Duration(days: 7));

    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        final conflict = data.cast<String, dynamic>();
        final status = conflict['status'] as String? ?? '';
        final resolvedAt =
            DateTime.tryParse(conflict['resolvedAt'] as String? ?? '');

        if (status == 'resolved' &&
            resolvedAt != null &&
            resolvedAt.isBefore(cutoffDate)) {
          keysToDelete.add(key.toString());
        }
      }
    }

    for (final key in keysToDelete) {
      await box.delete(key);
    }

    LoggerFactory.info('Cleaned up ${keysToDelete.length} resolved conflicts');
  }

  /// Cierra todas las conexiones de almacenamiento
  static Future<void> close() async {
    try {
      await _syncableEntitiesBox?.close();
      await _operationQueueBox?.close();
      await _conflictResolutionBox?.close();

      _syncableEntitiesBox = null;
      _operationQueueBox = null;
      _conflictResolutionBox = null;
      _hiveInitialized = false;

      LoggerFactory.info('Hybrid storage closed successfully');
    } catch (e) {
      LoggerFactory.error('Error closing hybrid storage: $e');
    }
  }
}

// =============================================
// ENUMS Y TIPOS
// =============================================

/// Tipos de almacenamiento según el uso
enum StorageType {
  syncMetadata,
  deviceInfo,
  userPreferences,
  syncableEntities,
  operationQueue,
  conflictResolution,
  searchIndex,
  analytics,
}

/// Tecnologías de almacenamiento disponibles
enum StorageTechnology {
  sharedPreferences,
  hive,
  isar,
}

/// Configuración de almacenamiento para un tipo específico
class StorageConfiguration {
  const StorageConfiguration({
    required this.technology,
    this.expiry,
    this.maxSize,
    this.enableCompression = false,
    this.enableEncryption = false,
  });
  final StorageTechnology technology;
  final Duration? expiry;
  final int? maxSize;
  final bool enableCompression;
  final bool enableEncryption;
}
