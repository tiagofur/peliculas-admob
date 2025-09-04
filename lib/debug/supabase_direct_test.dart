import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logging/logger_factory.dart';
import '../presentation/providers/auth_provider.dart';

/// Helper para probar la conexión directa con Supabase
/// y verificar qué datos están realmente en las tablas
class SupabaseDirectTest {
  SupabaseDirectTest({required Ref ref}) : _ref = ref;

  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Ejecutar prueba completa de conectividad y datos en Supabase
  Future<Map<String, dynamic>> runDirectTest() async {
    if (!kDebugMode) {
      throw Exception('SupabaseDirectTest solo puede usarse en modo debug');
    }

    LoggerFactory.info('🧪 Iniciando prueba directa de Supabase...');

    final results = <String, dynamic>{
      'user_authenticated': false,
      'user_id': null,
      'connectivity_test': false,
      'tables_accessible': false,
      'favorites_in_supabase': 0,
      'watchlist_in_supabase': 0,
      'watched_in_supabase': 0,
      'custom_lists_in_supabase': 0,
      'raw_data_samples': {},
      'errors': <String>[],
    };

    try {
      // 1. Verificar autenticación
      final user = _ref.read(currentUserProvider);
      results['user_authenticated'] = user != null;
      results['user_id'] = user?.id;

      if (user == null) {
        results['errors']
            .add('Usuario no autenticado - no se pueden verificar datos');
        return results;
      }

      LoggerFactory.info(
          '✅ Usuario autenticado: ${user.email} (ID: ${user.id})');

      // 2. Probar conectividad básica
      await _testConnectivity(results);

      // 3. Verificar acceso a tablas
      await _testTableAccess(results, user.id);

      // 4. Contar datos del usuario
      await _countUserData(results, user.id);

      // 5. Obtener muestras de datos
      await _getSampleData(results, user.id);

      LoggerFactory.info('🎉 Prueba directa de Supabase completada');
      LoggerFactory.info('📊 Resultados: $results');
    } catch (e) {
      results['errors'].add('Error general en prueba directa: $e');
      LoggerFactory.error('❌ Error en prueba directa de Supabase: $e');
    }

    return results;
  }

  /// Probar conectividad básica con Supabase
  Future<void> _testConnectivity(Map<String, dynamic> results) async {
    try {
      LoggerFactory.info('🌐 Probando conectividad básica...');

      // Hacer una consulta simple para verificar conectividad
      await _supabase.from('user_favorites').select('count').limit(1);

      results['connectivity_test'] = true;
      LoggerFactory.info('✅ Conectividad con Supabase OK');
    } catch (e) {
      results['connectivity_test'] = false;
      results['errors'].add('Error de conectividad: $e');
      LoggerFactory.error('❌ Error de conectividad: $e');
    }
  }

  /// Verificar acceso a todas las tablas necesarias
  Future<void> _testTableAccess(
      Map<String, dynamic> results, String userId) async {
    try {
      LoggerFactory.info('🗃️ Probando acceso a tablas...');

      final tables = [
        'user_favorites',
        'user_watchlist',
        'user_watched_movies',
        'user_lists'
      ];

      for (final table in tables) {
        try {
          await _supabase
              .from(table)
              .select('count')
              .eq('user_id', userId)
              .limit(1);
          LoggerFactory.info('✅ Acceso a tabla $table OK');
        } catch (e) {
          results['errors'].add('Error accediendo a tabla $table: $e');
          LoggerFactory.error('❌ Error en tabla $table: $e');
          return;
        }
      }

      results['tables_accessible'] = true;
      LoggerFactory.info('✅ Acceso a todas las tablas OK');
    } catch (e) {
      results['tables_accessible'] = false;
      results['errors'].add('Error general de acceso a tablas: $e');
      LoggerFactory.error('❌ Error de acceso a tablas: $e');
    }
  }

  /// Contar datos específicos del usuario en cada tabla
  Future<void> _countUserData(
      Map<String, dynamic> results, String userId) async {
    try {
      LoggerFactory.info('📊 Contando datos del usuario...');

      // Contar favoritos
      final favoritesResponse = await _supabase
          .from('user_favorites')
          .select()
          .eq('user_id', userId)
          .eq('is_deleted', false);
      results['favorites_in_supabase'] = (favoritesResponse as List).length;

      // Contar watchlist
      final watchlistResponse = await _supabase
          .from('user_watchlist')
          .select()
          .eq('user_id', userId)
          .eq('is_deleted', false);
      results['watchlist_in_supabase'] = (watchlistResponse as List).length;

      // Contar películas vistas
      final watchedResponse = await _supabase
          .from('user_watched_movies')
          .select()
          .eq('user_id', userId)
          .eq('is_deleted', false);
      results['watched_in_supabase'] = (watchedResponse as List).length;

      // Contar listas personalizadas
      final listsResponse = await _supabase
          .from('user_lists')
          .select()
          .eq('user_id', userId)
          .eq('is_deleted', false);
      results['custom_lists_in_supabase'] = (listsResponse as List).length;

      LoggerFactory.info('✅ Conteo completado:');
      LoggerFactory.info('   Favoritos: ${results['favorites_in_supabase']}');
      LoggerFactory.info('   Watchlist: ${results['watchlist_in_supabase']}');
      LoggerFactory.info('   Vistas: ${results['watched_in_supabase']}');
      LoggerFactory.info('   Listas: ${results['custom_lists_in_supabase']}');
    } catch (e) {
      results['errors'].add('Error contando datos: $e');
      LoggerFactory.error('❌ Error contando datos: $e');
    }
  }

  /// Obtener muestras de datos para inspección
  Future<void> _getSampleData(
      Map<String, dynamic> results, String userId) async {
    try {
      LoggerFactory.info('📋 Obteniendo muestras de datos...');

      final samples = <String, dynamic>{};

      // Muestra de favoritos
      final favoritesResponse = await _supabase
          .from('user_favorites')
          .select()
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .limit(2);
      samples['favorites'] = (favoritesResponse as List)
          .map((item) => {
                'movie_id': item['movie_id'],
                'movie_title': item['movie_title'],
                'added_at': item['added_at'],
              })
          .toList();

      // Muestra de watchlist
      final watchlistResponse = await _supabase
          .from('user_watchlist')
          .select()
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .limit(2);
      samples['watchlist'] = (watchlistResponse as List)
          .map((item) => {
                'movie_id': item['movie_id'],
                'movie_title': item['movie_title'],
                'priority': item['priority'],
              })
          .toList();

      results['raw_data_samples'] = samples;
      LoggerFactory.info('✅ Muestras obtenidas: $samples');
    } catch (e) {
      results['errors'].add('Error obteniendo muestras: $e');
      LoggerFactory.error('❌ Error obteniendo muestras: $e');
    }
  }

  /// Insertar datos de prueba directamente en Supabase
  Future<Map<String, dynamic>> insertTestData() async {
    if (!kDebugMode) return {'error': 'Solo disponible en debug mode'};

    final user = _ref.read(currentUserProvider);
    if (user == null) return {'error': 'Usuario no autenticado'};

    try {
      LoggerFactory.info('🧪 Insertando datos de prueba...');

      // Insertar favorito de prueba
      await _supabase.from('user_favorites').upsert({
        'user_id': user.id,
        'movie_id': 999999,
        'movie_title': 'PELÍCULA DE PRUEBA',
        'movie_poster_path': '/test.jpg',
        'movie_overview':
            'Esta es una película de prueba para verificar sincronización',
        'movie_vote_average': 8.5,
        'is_deleted': false,
        'last_modified_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,movie_id');

      LoggerFactory.info('✅ Datos de prueba insertados');
      return {
        'success': true,
        'message': 'Datos de prueba insertados correctamente'
      };
    } catch (e) {
      LoggerFactory.error('❌ Error insertando datos de prueba: $e');
      return {'error': 'Error insertando datos: $e'};
    }
  }

  /// Limpiar datos de prueba
  Future<Map<String, dynamic>> cleanTestData() async {
    if (!kDebugMode) return {'error': 'Solo disponible en debug mode'};

    final user = _ref.read(currentUserProvider);
    if (user == null) return {'error': 'Usuario no autenticado'};

    try {
      LoggerFactory.info('🧹 Limpiando datos de prueba...');

      await _supabase
          .from('user_favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('movie_id', 999999);

      LoggerFactory.info('✅ Datos de prueba limpiados');
      return {'success': true, 'message': 'Datos de prueba eliminados'};
    } catch (e) {
      LoggerFactory.error('❌ Error limpiando datos de prueba: $e');
      return {'error': 'Error limpiando datos: $e'};
    }
  }
}

/// Provider para el helper de pruebas directas de Supabase
final supabaseDirectTestProvider = Provider<SupabaseDirectTest>((ref) {
  return SupabaseDirectTest(ref: ref);
});
