import 'dart:async';

import '../../domain/entities/sync_result.dart';
import '../../domain/entities/syncable_entity.dart';
import '../logging/logger_factory.dart';
import 'entity_sync_manager.dart';

/// Implementación genérica del EntitySyncManager
/// Proporciona funcionalidad básica para cualquier tipo de entidad sincronizable
class GenericEntitySyncManager<T extends SyncableEntity>
    extends EntitySyncManager<T> {
  GenericEntitySyncManager({
    required super.entityType,
    required super.userId,
    super.syncQueue,
  });

  @override
  Future<List<T>> getLocalPendingSync({DateTime? since}) async {
    // Implementación básica - retorna lista vacía
    // Las subclases pueden sobrescribir este método para funcionalidad específica
    LoggerFactory.info(
        '📋 Getting local pending sync for $entityType (generic implementation)');
    return <T>[];
  }

  @override
  Future<List<T>> getRemoteChanges({DateTime? since}) async {
    // Implementación básica - retorna lista vacía
    // Las subclases pueden sobrescribir este método para funcionalidad específica
    LoggerFactory.info(
        '📥 Getting remote changes for $entityType (generic implementation)');
    return <T>[];
  }

  @override
  Future<SyncResult> uploadChanges(List<T> entities) async {
    // Implementación básica - simula éxito
    // Las subclases pueden sobrescribir este método para funcionalidad específica
    LoggerFactory.info(
        '📤 Uploading ${entities.length} changes for $entityType (generic implementation)');

    return SyncResult.success(
      itemsProcessed: entities.length,
      itemsSuccessful: entities.length,
      duration: const Duration(milliseconds: 100),
      message: 'Generic upload completed',
    );
  }

  @override
  Future<SyncResult> downloadChanges(List<T> entities) async {
    // Implementación básica - simula éxito
    // Las subclases pueden sobrescribir este método para funcionalidad específica
    LoggerFactory.info(
        '📥 Downloading ${entities.length} changes for $entityType (generic implementation)');

    return SyncResult.success(
      itemsProcessed: entities.length,
      itemsSuccessful: entities.length,
      duration: const Duration(milliseconds: 100),
      message: 'Generic download completed',
    );
  }

  @override
  Future<List<ConflictInfo<T>>> detectConflicts() async {
    // Implementación básica - no detecta conflictos
    // Las subclases pueden sobrescribir este método para funcionalidad específica
    LoggerFactory.info(
        '🔍 Detecting conflicts for $entityType (generic implementation)');
    return <ConflictInfo<T>>[];
  }

  @override
  Future<T> resolveConflict(ConflictInfo<T> conflict) async {
    // Implementación básica - usa estrategia remoteWins
    // Las subclases pueden sobrescribir este método para funcionalidad específica
    LoggerFactory.info(
        '⚖️ Resolving conflict for $entityType (generic implementation)');
    return conflict.remoteEntity;
  }

  @override
  Map<String, dynamic> serializeForLocal(T entity) {
    // Implementación básica - usa toJson si está disponible
    // Las subclases pueden sobrescribir este método para funcionalidad específica
    try {
      // Intenta usar el método toJson si existe
      return (entity as dynamic).toJson() as Map<String, dynamic>;
    } catch (e) {
      LoggerFactory.warning(
          '⚠️ Failed to serialize $entityType for local storage: $e');
      return <String, dynamic>{
        'id': entity.id,
        'userId': entity.userId,
        'createdAt': entity.createdAt.toIso8601String(),
        'lastModifiedAt': entity.lastModifiedAt.toIso8601String(),
        'isDeleted': entity.isDeleted,
        'syncVersion': entity.syncVersion,
        'deviceId': entity.deviceId,
        'entityType': entity.entityType,
      };
    }
  }

  @override
  T deserializeFromLocal(Map<String, dynamic> data) {
    // Implementación básica - lanza error
    // Las subclases DEBEN sobrescribir este método
    throw UnimplementedError(
      'deserializeFromLocal must be implemented for $entityType. '
      'Override this method in your specific sync manager implementation.',
    );
  }

  @override
  Map<String, dynamic> serializeForRemote(T entity) {
    // Implementación básica - usa serializeForLocal
    // Las subclases pueden sobrescribir este método para funcionalidad específica
    return serializeForLocal(entity);
  }

  @override
  T deserializeFromRemote(Map<String, dynamic> data) {
    // Implementación básica - usa deserializeFromLocal
    // Las subclases pueden sobrescribir este método para funcionalidad específica
    return deserializeFromLocal(data);
  }
}
