import '../../core/logging/logger_factory.dart';
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
    LoggerFactory.info('🔄 SyncManager: Iniciando sincronización...');

    final localItems = await repository.getLocalData();
    final remoteItems = await repository.getRemoteData();

    LoggerFactory.info(
        '📊 SyncManager: Local: ${localItems.length}, Remote: ${remoteItems.length}');

    final toUpload = ConflictResolver.findLocalChanges(localItems, remoteItems);
    final toDownload =
        ConflictResolver.findRemoteChanges(localItems, remoteItems);

    LoggerFactory.info(
        '📊 SyncManager: Para subir: ${toUpload.length}, Para descargar: ${toDownload.length}');

    await _upload(toUpload);
    await _download(toDownload);

    final conflicts = ConflictResolver.detectConflicts(localItems, remoteItems);
    if (conflicts.isNotEmpty) {
      LoggerFactory.warning(
          '⚠️ SyncManager: ${conflicts.length} conflictos detectados, resolviendo...');
      await repository.resolveConflicts(localItems, remoteItems);
      LoggerFactory.info('✅ SyncManager: Conflictos resueltos');
    }

    final result = SyncResult(
      uploaded: toUpload.length,
      downloaded: toDownload.length,
      conflicted: conflicts.length,
    );

    LoggerFactory.info('🎉 SyncManager: Sincronización completada - $result');
    return result;
  }

  Future<void> _upload(List<T> items) async {
    if (items.isNotEmpty) {
      LoggerFactory.info('⬆️ SyncManager: Subiendo ${items.length} elementos...');
      await repository.upload(items);
      LoggerFactory.info('✅ SyncManager: Upload completado');
    } else {
      LoggerFactory.info('⬆️ SyncManager: No hay elementos para subir');
    }
  }

  Future<void> _download(List<T> items) async {
    if (items.isNotEmpty) {
      LoggerFactory.info('⬇️ SyncManager: Descargando ${items.length} elementos...');
      await repository.download(items);
      LoggerFactory.info('✅ SyncManager: Download completado');
    } else {
      LoggerFactory.info('⬇️ SyncManager: No hay elementos para descargar');
    }
  }
}
