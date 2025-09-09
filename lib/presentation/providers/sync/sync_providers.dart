import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/entity_sync_manager.dart';
import '../../../domain/entities/syncable_entity.dart';
import '../../../domain/entities/sync_result.dart';

final entitySyncManagerProvider =
    Provider<EntitySyncManager<SyncableEntity>>((ref) {
  // This is a mock implementation. Replace with your actual implementation.
  return MockEntitySyncManager();
});

class MockEntitySyncManager extends EntitySyncManager<SyncableEntity> {
  MockEntitySyncManager() : super(entityType: 'mock', userId: 'mock');

  @override
  Future<List<SyncableEntity>> getLocalPendingSync({DateTime? since}) {
    throw UnimplementedError();
  }

  @override
  Future<List<SyncableEntity>> getRemoteChanges({DateTime? since}) {
    throw UnimplementedError();
  }

  @override
  Future<SyncResult> uploadChanges(List<SyncableEntity> entities) {
    throw UnimplementedError();
  }

  @override
  Future<SyncResult> downloadChanges(List<SyncableEntity> entities) {
    throw UnimplementedError();
  }

  @override
  Future<List<ConflictInfo<SyncableEntity>>> detectConflicts() {
    throw UnimplementedError();
  }

  @override
  Future<SyncableEntity> resolveConflict(
      ConflictInfo<SyncableEntity> conflict) {
    throw UnimplementedError();
  }

  @override
  Map<String, dynamic> serializeForLocal(SyncableEntity entity) {
    throw UnimplementedError();
  }

  @override
  SyncableEntity deserializeFromLocal(Map<String, dynamic> data) {
    throw UnimplementedError();
  }

  @override
  Map<String, dynamic> serializeForRemote(SyncableEntity entity) {
    throw UnimplementedError();
  }

  @override
  SyncableEntity deserializeFromRemote(Map<String, dynamic> data) {
    throw UnimplementedError();
  }

  Future<List<ConflictInfo<SyncableEntity>>> getConflictHistory() async {
    return [];
  }
}
