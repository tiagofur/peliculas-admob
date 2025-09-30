import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging/logger_factory.dart';
import '../core/services/post_login_initialization_service.dart';
import '../presentation/providers/auto_default_lists_provider.dart';
import '../presentation/providers/storage/favorite_movies_provider.dart';
import '../presentation/providers/sync_integration_provider.dart';
import 'data_migration_service.dart';

/// Servicio que coordina todas las tareas críticas después de una autenticación exitosa
class PostLoginService {
  PostLoginService(this.ref);

  final Ref ref;
  bool _isRunning = false;

  /// Ejecuta todas las inicializaciones post-login de manera segura y ordenada
  Future<void> handlePostLogin(String userId) async {
    if (_isRunning) {
      LoggerFactory.info(
        '⏳ PostLoginService ya está ejecutándose, se omite la inicialización duplicada',
      );
      return;
    }

    _isRunning = true;

    try {
      LoggerFactory.info(
          '🚀 PostLoginService: inicializando para usuario $userId');

      await _ensureDefaultLists();
      await _migrateLocalData(userId);
      await _initializeSync();
      await _refreshFavorites();
      await _initializeDirectProviders(userId);

      LoggerFactory.info('✅ PostLoginService completado para usuario $userId');
    } catch (e, stack) {
      LoggerFactory.error(
          '❌ PostLoginService falló durante la inicialización: $e');
      LoggerFactory.error('Stack: $stack');
    } finally {
      _isRunning = false;
    }
  }

  /// Limpia los servicios y caches cuando el usuario cierra sesión
  Future<void> handlePostLogout() async {
    try {
      LoggerFactory.info('🧹 PostLoginService: limpiando recursos post-logout');

      await ref.read(syncIntegrationProvider.notifier).clearLocalData();
      ref.invalidate(favoriteMoviesProvider);
    } catch (e, stack) {
      LoggerFactory.error('❌ Error limpiando recursos post-logout: $e');
      LoggerFactory.error('Stack: $stack');
    }
  }

  Future<void> _ensureDefaultLists() async {
    try {
      LoggerFactory.info('📋 Verificando listas predeterminadas');
      await ref.read(autoDefaultListsProvider).ensureDefaultListsExist();
    } catch (e) {
      LoggerFactory.error(
          '❌ No se pudieron asegurar las listas predeterminadas: $e');
    }
  }

  Future<void> _migrateLocalData(String userId) async {
    try {
      final migrationService = ref.read(dataMigrationServiceProvider);
      final result = await migrationService.migrateAndSyncData(userId);

      LoggerFactory.info(
        '📦 Migración local → remota completada: '
        'watched=${result.migratedWatchedMovies}, '
        'ratings=${result.migratedRatings}, '
        'lists=${result.migratedCustomLists}',
      );
    } catch (e) {
      LoggerFactory.error('❌ Error migrando datos locales: $e');
    }
  }

  Future<void> _initializeSync() async {
    try {
      LoggerFactory.info('🔄 Forzando sincronización global después del login');
      await ref.read(syncIntegrationProvider.notifier).forceFullResync();
    } catch (e) {
      LoggerFactory.error('❌ No se pudo iniciar la sincronización global: $e');
    }
  }

  Future<void> _refreshFavorites() async {
    try {
      await ref.read(favoriteMoviesProvider.notifier).refreshFavorites();
    } catch (e) {
      LoggerFactory.error(
          '❌ Error refrescando favoritos después del login: $e');
    }
  }

  Future<void> _initializeDirectProviders(String userId) async {
    try {
      LoggerFactory.info(
          '🔄 Inicializando providers directos para datos de usuario');

      // Forzar inicialización de providers directos para cargar datos inmediatamente
      PostLoginInitializationService.instance.forceInitialization(userId, ref);

      LoggerFactory.info('✅ Providers directos inicializados correctamente');
    } catch (e) {
      LoggerFactory.error('❌ Error inicializando providers directos: $e');
    }
  }
}

final postLoginServiceProvider = Provider<PostLoginService>((ref) {
  return PostLoginService(ref);
});
