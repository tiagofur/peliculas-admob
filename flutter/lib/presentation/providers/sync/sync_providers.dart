import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/entity_sync_manager.dart';
import '../../../domain/entities/syncable_entity.dart';
import '../../../domain/entities/sync_result.dart';

final entitySyncManagerProvider =
    Provider<EntitySyncManager<SyncableEntity>>((ref) {
  // This is a mock implementation. Replace with your actual implementation.
  return MockEntitySyncManager();
});

class MockSyncableEntity extends SyncableEntity {
  MockSyncableEntity({
    required this.id,
    required this.lastModifiedAt,
    required this.syncVersion,
    this.userId = 'mock_user',
    this.isDeleted = false,
    this.deviceId,
  }) : createdAt = DateTime.now();

  @override
  final String id;

  @override
  final String userId;

  @override
  final DateTime createdAt;

  @override
  final DateTime lastModifiedAt;

  @override
  final bool isDeleted;

  @override
  final int syncVersion;

  @override
  final String? deviceId;

  @override
  String get entityType => 'mock';

  @override
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'last_modified_at': lastModifiedAt.toIso8601String(),
      'is_deleted': isDeleted,
      'sync_version': syncVersion,
      'device_id': deviceId,
    };
  }

  @override
  SyncableEntity copyWith({
    DateTime? lastModifiedAt,
    int? syncVersion,
    String? deviceId,
    bool? isDeleted,
  }) {
    return MockSyncableEntity(
      id: id,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      syncVersion: syncVersion ?? this.syncVersion,
      userId: userId,
      isDeleted: isDeleted ?? this.isDeleted,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}

class MockEntitySyncManager extends EntitySyncManager<SyncableEntity> {
  MockEntitySyncManager() : super(entityType: 'mock', userId: 'mock');

  // Simulación de almacenamiento local
  final List<SyncableEntity> _localEntities = [];
  final List<SyncableEntity> _remoteEntities = [];

  @override
  Future<List<SyncableEntity>> getLocalPendingSync({DateTime? since}) async {
    // Implementación más realista: filtrar entidades locales pendientes
    await Future.delayed(const Duration(milliseconds: 100)); // Simular latencia

    if (since == null) {
      return List.from(_localEntities);
    }

    return _localEntities
        .where((entity) => entity.lastModifiedAt.isAfter(since))
        .toList();
  }

  @override
  Future<List<SyncableEntity>> getRemoteChanges({DateTime? since}) async {
    // Implementación más realista: simular cambios remotos
    await Future.delayed(
        const Duration(milliseconds: 200)); // Simular latencia de red

    // Generar algunos cambios remotos simulados
    if (_remoteEntities.isEmpty) {
      _remoteEntities.addAll([
        MockSyncableEntity(
          id: 'remote_1',
          lastModifiedAt: DateTime.now().subtract(const Duration(minutes: 5)),
          syncVersion: 1,
        ),
        MockSyncableEntity(
          id: 'remote_2',
          lastModifiedAt: DateTime.now().subtract(const Duration(minutes: 2)),
          syncVersion: 1,
        ),
      ]);
    }

    if (since == null) {
      return List.from(_remoteEntities);
    }

    return _remoteEntities
        .where((entity) => entity.lastModifiedAt.isAfter(since))
        .toList();
  }

  @override
  Future<SyncResult> uploadChanges(List<SyncableEntity> entities) async {
    // Implementación más realista: simular subida con posibles errores
    await Future.delayed(
        const Duration(milliseconds: 300)); // Simular latencia de red

    var successCount = 0;
    var errorCount = 0;

    for (final entity in entities) {
      try {
        // Simular 90% de éxito
        if (entity.id.hashCode % 10 != 0) {
          // Simular subida exitosa
          _remoteEntities.removeWhere((e) => e.id == entity.id);
          _remoteEntities.add(entity);
          successCount++;
        } else {
          // Simular error
          errorCount++;
        }
      } catch (e) {
        errorCount++;
      }
    }

    if (errorCount > 0) {
      return SyncResult.failure(
        itemsProcessed: successCount,
        errors: ['Error subiendo $errorCount de ${entities.length} entidades'],
        message: 'Error subiendo $errorCount de ${entities.length} entidades',
      );
    }

    return SyncResult.success(
      itemsProcessed: successCount,
      message: 'Subidas $successCount entidades exitosamente',
    );
  }

  @override
  Future<SyncResult> downloadChanges(List<SyncableEntity> entities) async {
    // Implementación más realista: simular descarga con procesamiento
    await Future.delayed(const Duration(milliseconds: 250)); // Simular latencia

    var processedCount = 0;

    for (final entity in entities) {
      try {
        // Simular procesamiento de entidad remota
        _localEntities.removeWhere((e) => e.id == entity.id);
        _localEntities.add(entity);
        processedCount++;
      } catch (e) {
        // Continuar con la siguiente entidad en caso de error
        continue;
      }
    }

    return SyncResult.success(
      itemsProcessed: processedCount,
      message: 'Descargadas $processedCount entidades',
    );
  }

  @override
  Future<List<ConflictInfo<SyncableEntity>>> detectConflicts() async {
    // Implementación más realista: detectar conflictos reales
    await Future.delayed(const Duration(milliseconds: 150));

    final conflicts = <ConflictInfo<SyncableEntity>>[];

    // Buscar entidades que existen tanto local como remotamente con diferentes versiones
    for (final localEntity in _localEntities) {
      final remoteEntity =
          _remoteEntities.where((e) => e.id == localEntity.id).firstOrNull;

      if (remoteEntity != null &&
          localEntity.syncVersion != remoteEntity.syncVersion) {
        conflicts.add(ConflictInfo(
          localEntity: localEntity,
          remoteEntity: remoteEntity,
          conflictType: ConflictType.concurrentModification,
          detectedAt: DateTime.now(),
        ));
      }
    }

    return conflicts;
  }

  @override
  Future<SyncableEntity> resolveConflict(
      ConflictInfo<SyncableEntity> conflict) async {
    // Implementación más realista: resolver conflictos basado en timestamp
    await Future.delayed(const Duration(milliseconds: 50));

    final local = conflict.localEntity;
    final remote = conflict.remoteEntity;

    // Resolver basado en la fecha de modificación más reciente
    if (local.lastModifiedAt.isAfter(remote.lastModifiedAt)) {
      return local.copyWith(syncVersion: remote.syncVersion + 1);
    } else {
      return remote.copyWith(syncVersion: remote.syncVersion + 1);
    }
  }

  @override
  Map<String, dynamic> serializeForLocal(SyncableEntity entity) {
    // Implementación mock: serialización básica
    return {
      'id': entity.id,
      'entityType': entityType,
      'lastModified': entity.lastModifiedAt.toIso8601String(),
      'syncVersion': entity.syncVersion,
    };
  }

  @override
  SyncableEntity deserializeFromLocal(Map<String, dynamic> data) {
    // Implementación mock: deserialización básica
    // Nota: Esta es una implementación simplificada
    // En producción, esto debería crear la entidad específica correcta
    return MockSyncableEntity(
      id: data['id'] ?? '',
      lastModifiedAt: data['lastModified'] != null
          ? DateTime.parse(data['lastModified'])
          : DateTime.now(),
      syncVersion: data['syncVersion'] ?? 1,
    );
  }

  @override
  Map<String, dynamic> serializeForRemote(SyncableEntity entity) {
    // Implementación mock: usa la misma serialización que local
    return serializeForLocal(entity);
  }

  @override
  SyncableEntity deserializeFromRemote(Map<String, dynamic> data) {
    // Implementación mock: usa la misma deserialización que local
    return deserializeFromLocal(data);
  }

  @override
  Future<void> deleteEntity(String entityId) async {
    // Implementación mock: eliminar de almacenamiento local y remoto
    await Future.delayed(const Duration(milliseconds: 100));

    _localEntities.removeWhere((e) => e.id == entityId);
    _remoteEntities.removeWhere((e) => e.id == entityId);
  }

  @override
  Future<Map<String, dynamic>?> getRemoteEntity(String entityId) async {
    // Implementación mock: buscar entidad en almacenamiento remoto simulado
    await Future.delayed(const Duration(milliseconds: 150));

    try {
      final entity = _remoteEntities.firstWhere((e) => e.id == entityId);
      return serializeForRemote(entity);
    } catch (e) {
      return null; // Entidad no encontrada
    }
  }

  @override
  Future<SyncableEntity> mergeEntities(
    SyncableEntity localEntity,
    SyncableEntity remoteEntity,
  ) async {
    // Implementación mock: fusionar entidades basado en timestamp
    await Future.delayed(const Duration(milliseconds: 50));

    // Usar la entidad con la fecha de modificación más reciente
    // pero incrementar la versión de sincronización
    final newerEntity =
        localEntity.lastModifiedAt.isAfter(remoteEntity.lastModifiedAt)
            ? localEntity
            : remoteEntity;

    final maxVersion = [localEntity.syncVersion, remoteEntity.syncVersion]
        .reduce((a, b) => a > b ? a : b);

    return newerEntity.copyWith(
      syncVersion: maxVersion + 1,
      lastModifiedAt: DateTime.now(),
    );
  }

  Future<List<ConflictInfo<SyncableEntity>>> getConflictHistory() async {
    return [];
  }
}
