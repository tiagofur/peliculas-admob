import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging/logger_factory.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/providers/hybrid_repositories_provider.dart';

/// Helper para probar la sincronización y validar que los datos
/// se estén subiendo correctamente a Supabase
class SyncTestHelper {
  SyncTestHelper({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Ejecutar prueba completa de sincronización
  Future<Map<String, dynamic>> runFullSyncTest() async {
    if (!kDebugMode) {
      throw Exception('SyncTestHelper solo puede usarse en modo debug');
    }

    LoggerFactory.info('🧪 Iniciando prueba completa de sincronización...');

    final results = <String, dynamic>{
      'user_authenticated': false,
      'favorites_sync': {'local_count': 0, 'remote_count': 0, 'sync_success': false},
      'watchlist_sync': {'local_count': 0, 'remote_count': 0, 'sync_success': false},
      'watched_sync': {'local_count': 0, 'remote_count': 0, 'sync_success': false},
      'custom_lists_sync': {'local_count': 0, 'remote_count': 0, 'sync_success': false},
      'errors': <String>[],
    };

    try {
      // 1. Verificar autenticación
      final user = _ref.read(currentUserProvider);
      results['user_authenticated'] = user != null;
      
      if (user == null) {
        results['errors'].add('Usuario no autenticado - no se pueden probar los syncs');
        return results;
      }

      LoggerFactory.info('✅ Usuario autenticado: ${user.email}');

      // 2. Probar sincronización de favoritos
      await _testFavoritesSync(results);

      // 3. Probar sincronización de watchlist
      await _testWatchlistSync(results);

      // 4. Probar sincronización de películas vistas
      await _testWatchedSync(results);

      // 5. Probar sincronización de listas personalizadas
      await _testCustomListsSync(results);

      LoggerFactory.info('🎉 Prueba completa de sincronización finalizada');
      LoggerFactory.info('📊 Resultados: $results');

    } catch (e) {
      results['errors'].add('Error general en prueba de sync: $e');
      LoggerFactory.error('❌ Error en prueba de sincronización: $e');
    }

    return results;
  }

  /// Probar sincronización de favoritos
  Future<void> _testFavoritesSync(Map<String, dynamic> results) async {
    try {
      LoggerFactory.info('🧪 Probando sincronización de favoritos...');
      
      final favoritesRepo = _ref.read(hybridFavoritesRepositoryProvider);
      
      // Obtener datos locales
      final localData = await favoritesRepo.getLocalData();
      final localCount = localData.length;
      
      // Obtener datos remotos
      final remoteData = await favoritesRepo.getRemoteData();
      final remoteCount = remoteData.length;
      
      // Ejecutar sincronización
      await favoritesRepo.syncWithSupabase();
      
      results['favorites_sync'] = {
        'local_count': localCount,
        'remote_count': remoteCount,
        'sync_success': true,
      };
      
      LoggerFactory.info('✅ Favoritos - Local: $localCount, Remote: $remoteCount');
      
    } catch (e) {
      results['favorites_sync']['sync_success'] = false;
      results['errors'].add('Error en sync de favoritos: $e');
      LoggerFactory.error('❌ Error en sync de favoritos: $e');
    }
  }

  /// Probar sincronización de watchlist
  Future<void> _testWatchlistSync(Map<String, dynamic> results) async {
    try {
      LoggerFactory.info('🧪 Probando sincronización de watchlist...');
      
      final watchlistRepo = _ref.read(hybridWatchlistRepositoryProvider);
      
      // Obtener datos locales
      final localData = await watchlistRepo.getLocalData();
      final localCount = localData.length;
      
      // Obtener datos remotos
      final remoteData = await watchlistRepo.getRemoteData();
      final remoteCount = remoteData.length;
      
      // Ejecutar sincronización
      await watchlistRepo.syncWithSupabase();
      
      results['watchlist_sync'] = {
        'local_count': localCount,
        'remote_count': remoteCount,
        'sync_success': true,
      };
      
      LoggerFactory.info('✅ Watchlist - Local: $localCount, Remote: $remoteCount');
      
    } catch (e) {
      results['watchlist_sync']['sync_success'] = false;
      results['errors'].add('Error en sync de watchlist: $e');
      LoggerFactory.error('❌ Error en sync de watchlist: $e');
    }
  }

  /// Probar sincronización de películas vistas
  Future<void> _testWatchedSync(Map<String, dynamic> results) async {
    try {
      LoggerFactory.info('🧪 Probando sincronización de películas vistas...');
      
      final watchedRepo = _ref.read(hybridWatchedRepositoryProvider);
      
      // Obtener datos locales
      final localData = await watchedRepo.getLocalData();
      final localCount = localData.length;
      
      // Obtener datos remotos
      final remoteData = await watchedRepo.getRemoteData();
      final remoteCount = remoteData.length;
      
      // Ejecutar sincronización
      await watchedRepo.syncWithSupabase();
      
      results['watched_sync'] = {
        'local_count': localCount,
        'remote_count': remoteCount,
        'sync_success': true,
      };
      
      LoggerFactory.info('✅ Vistas - Local: $localCount, Remote: $remoteCount');
      
    } catch (e) {
      results['watched_sync']['sync_success'] = false;
      results['errors'].add('Error en sync de películas vistas: $e');
      LoggerFactory.error('❌ Error en sync de películas vistas: $e');
    }
  }

  /// Probar sincronización de listas personalizadas
  Future<void> _testCustomListsSync(Map<String, dynamic> results) async {
    try {
      LoggerFactory.info('🧪 Probando sincronización de listas personalizadas...');
      
      final customListsRepo = _ref.read(hybridCustomListsRepositoryProvider);
      
      // Obtener datos locales
      final localData = await customListsRepo.getLocalData();
      final localCount = localData.length;
      
      // Obtener datos remotos
      final remoteData = await customListsRepo.getRemoteData();
      final remoteCount = remoteData.length;
      
      // Ejecutar sincronización
      await customListsRepo.syncWithSupabase();
      
      results['custom_lists_sync'] = {
        'local_count': localCount,
        'remote_count': remoteCount,
        'sync_success': true,
      };
      
      LoggerFactory.info('✅ Listas personalizadas - Local: $localCount, Remote: $remoteCount');
      
    } catch (e) {
      results['custom_lists_sync']['sync_success'] = false;
      results['errors'].add('Error en sync de listas personalizadas: $e');
      LoggerFactory.error('❌ Error en sync de listas personalizadas: $e');
    }
  }

  /// Forzar sincronización completa manual
  Future<void> forceSyncAll() async {
    if (!kDebugMode) return;

    LoggerFactory.info('🔄 Forzando sincronización completa manual...');

    try {
      final favoritesRepo = _ref.read(hybridFavoritesRepositoryProvider);
      await favoritesRepo.syncWithSupabase();
      LoggerFactory.info('✅ Favoritos sincronizados');

      final watchlistRepo = _ref.read(hybridWatchlistRepositoryProvider);
      await watchlistRepo.syncWithSupabase();
      LoggerFactory.info('✅ Watchlist sincronizada');

      final watchedRepo = _ref.read(hybridWatchedRepositoryProvider);
      await watchedRepo.syncWithSupabase();
      LoggerFactory.info('✅ Películas vistas sincronizadas');

      final customListsRepo = _ref.read(hybridCustomListsRepositoryProvider);
      await customListsRepo.syncWithSupabase();
      LoggerFactory.info('✅ Listas personalizadas sincronizadas');

      LoggerFactory.info('🎉 Sincronización completa manual finalizada');
    } catch (e) {
      LoggerFactory.error('❌ Error en sincronización manual: $e');
    }
  }
}

/// Provider para el helper de pruebas de sincronización
final syncTestHelperProvider = Provider<SyncTestHelper>((ref) {
  return SyncTestHelper(ref: ref);
});