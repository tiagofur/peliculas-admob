import '../../domain/repositories/syncable_repository.dart';
import '../../domain/entities/sync_models.dart';
import 'conflict_resolver.dart';

class SyncResult {
  final int uploaded;
  final int downloaded;
  final int conflicted;

  SyncResult({this.uploaded = 0, this.downloaded = 0, this.conflicted = 0});

  @override
  String toString() {
    return 'SyncResult(uploaded: $uploaded, downloaded: $downloaded, conflicted: $conflicted)';
  }
}

class SyncManager<T extends SyncableEntity> {
  final SyncableRepository<T> repository;

  SyncManager(this.repository);

  Future<SyncResult> sync() async {
    final localItems = await repository.getLocalData();
    final remoteItems = await repository.getRemoteData();

    final toUpload = ConflictResolver.findLocalChanges(localItems, remoteItems);
    final toDownload = ConflictResolver.findRemoteChanges(localItems, remoteItems);

    await _upload(toUpload);
    await _download(toDownload);

    final conflicts = ConflictResolver.detectConflicts(localItems, remoteItems);
    if (conflicts.isNotEmpty) {
      await repository.resolveConflicts(localItems, remoteItems);
    }

    return SyncResult(
      uploaded: toUpload.length,
      downloaded: toDownload.length,
      conflicted: conflicts.length,
    );
  }

  Future<void> _upload(List<T> items) async {
    // This should be implemented in the repository
  }

  Future<void> _download(List<T> items) async {
    // This should be implemented in the repository
  }
}
