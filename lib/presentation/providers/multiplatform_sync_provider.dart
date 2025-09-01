import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger_factory.dart';
import '../../infrastructure/services/multiplatform_sync_manager.dart';

/// Provider para el MultiplataformSyncManager
final multiplataformSyncManagerProvider =
    Provider<MultiplataformSyncManager>((ref) {
  return MultiplataformSyncManager.instance;
});

/// Provider para inicializar automáticamente el sistema de sincronización
final syncInitializationProvider = FutureProvider<void>((ref) async {
  LoggerFactory.info(
      '🚀 Inicializando sistema de sincronización automática...');

  try {
    final syncManager = ref.read(multiplataformSyncManagerProvider);

    // Inicializar el gestor de sincronización
    await syncManager.initialize();

    LoggerFactory.info(
        '✅ Sistema de sincronización automática inicializado correctamente');
  } catch (e) {
    LoggerFactory.error(
        '❌ Error inicializando sistema de sincronización automática: $e');
    rethrow;
  }
});

/// Provider para el estado del sistema de sincronización
final syncSystemStatusProvider = Provider<Map<String, dynamic>>((ref) {
  final syncManager = ref.watch(multiplataformSyncManagerProvider);
  return syncManager.getManagerStatus();
});

/// Provider para verificar si el sistema necesita sincronización
final needsSyncProvider = Provider<bool>((ref) {
  final syncManager = ref.watch(multiplataformSyncManagerProvider);
  return syncManager.needsSync();
});

/// Provider para forzar sincronización manual
final forceSyncProvider = Provider<Future<void> Function()>((ref) {
  final syncManager = ref.watch(multiplataformSyncManagerProvider);
  return () => syncManager.forceSync();
});
