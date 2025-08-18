import '../../domain/entities/sync_models.dart';
import '../../domain/repositories/syncable_repository.dart';
import 'conflict_resolver.dart';

class SyncResult {
  SyncResult({this.uploaded = 0, this.downloaded = 0, this.conflicted = 0});
  final int uploaded;
  final int downloaded;
  final int conflicted;

  @override
  String toString() {
    return 'SyncResult(uploaded: $uploaded, downloaded: $downloaded, conflicted: $conflicted)';
  }
}

class SyncManager<T extends SyncableEntity> {
  SyncManager(this.repository);
  final SyncableRepository<T> repository;

  Future<SyncResult> sync() async {
    print('🔄 SyncManager: Iniciando sincronización...');

    final localItems = await repository.getLocalData();
    final remoteItems = await repository.getRemoteData();

    print(
        '📊 SyncManager: Local: ${localItems.length}, Remote: ${remoteItems.length}');

    final toUpload = ConflictResolver.findLocalChanges(localItems, remoteItems);
    final toDownload =
        ConflictResolver.findRemoteChanges(localItems, remoteItems);

    print(
        '📊 SyncManager: Para subir: ${toUpload.length}, Para descargar: ${toDownload.length}');

    await _upload(toUpload);
    await _download(toDownload);

    final conflicts = ConflictResolver.detectConflicts(localItems, remoteItems);
    if (conflicts.isNotEmpty) {
      print(
          '⚠️ SyncManager: ${conflicts.length} conflictos detectados, resolviendo...');
      await repository.resolveConflicts(localItems, remoteItems);
      print('✅ SyncManager: Conflictos resueltos');
    }

    final result = SyncResult(
      uploaded: toUpload.length,
      downloaded: toDownload.length,
      conflicted: conflicts.length,
    );

    print('🎉 SyncManager: Sincronización completada - $result');
    return result;
  }

  Future<void> _upload(List<T> items) async {
    if (items.isNotEmpty) {
      print('⬆️ SyncManager: Subiendo ${items.length} elementos...');
      await repository.upload(items);
      print('✅ SyncManager: Upload completado');
    } else {
      print('⬆️ SyncManager: No hay elementos para subir');
    }
  }

  Future<void> _download(List<T> items) async {
    if (items.isNotEmpty) {
      print('⬇️ SyncManager: Descargando ${items.length} elementos...');
      await repository.download(items);
      print('✅ SyncManager: Download completado');
    } else {
      print('⬇️ SyncManager: No hay elementos para descargar');
    }
  }
}
