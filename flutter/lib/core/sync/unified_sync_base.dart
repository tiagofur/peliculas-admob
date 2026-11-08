import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/movie.dart';
import '../logging/logger_factory.dart';

/// Base unificada para TODOS los sistemas de sincronización
/// Maneja: Favorites, Watched, Ratings, Watchlist
///
/// Esta clase proporciona una implementación consistente y reutilizable
/// para sincronización offline-first con Supabase, incluyendo:
/// - CRUD operations
/// - Real-time sync
/// - Conflict resolution
/// - Batch operations
/// - Connection testing
abstract class UnifiedSyncBase<T> {
  UnifiedSyncBase({
    required this.tableName,
    required this.entityName,
  }) : _supabase = Supabase.instance.client;

  final String tableName;
  final String entityName;
  final SupabaseClient _supabase;

  // ============================================
  // MÉTODOS ABSTRACTOS QUE CADA HIJO IMPLEMENTA
  // ============================================

  /// Convierte Movie a Map para Supabase
  /// [extraData] puede contener campos adicionales específicos (rating, watched_at, etc.)
  Map<String, dynamic> movieToSupabaseData(
    String userId,
    Movie movie, [
    Map<String, dynamic>? extraData,
  ]);

  /// Convierte Map de Supabase a entidad local
  T supabaseDataToEntity(Map<String, dynamic> data);

  /// Obtiene el ID único para evitar duplicados
  String getUniqueId(String userId, int movieId);

  // ============================================
  // MÉTODOS COMUNES PARA TODOS
  // ============================================

  /// Obtiene todos los items del usuario
  Future<List<Map<String, dynamic>>> getUserItems(String userId) async {
    try {
      LoggerFactory.info(
          '📥 [$entityName] Obteniendo items para usuario: $userId');

      final response = await _supabase
          .from(tableName)
          .select('*')
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .order('last_modified_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final items = data.cast<Map<String, dynamic>>();

      LoggerFactory.info('✅ [$entityName] Encontrados ${items.length} items');
      return items;
    } catch (e) {
      LoggerFactory.error('❌ [$entityName] Error obteniendo items: $e');
      return [];
    }
  }

  /// Agrega o actualiza un item
  Future<void> addOrUpdateItem(
    String userId,
    Movie movie, [
    Map<String, dynamic>? extraData,
  ]) async {
    try {
      LoggerFactory.info(
          '➕ [$entityName] Agregando/actualizando: ${movie.title}');

      final now = DateTime.now().toUtc().toIso8601String();
      final data = movieToSupabaseData(userId, movie, extraData);

      // Agregar campos de sincronización
      data['last_modified_at'] = now;
      data['sync_version'] = (data['sync_version'] ?? 0) + 1;
      data['is_deleted'] = false;

      // Usar UPSERT con conflict resolution
      await _supabase.from(tableName).upsert(
            data,
            onConflict: 'user_id,movie_id',
            ignoreDuplicates: false,
          );

      LoggerFactory.info('✅ [$entityName] Item guardado: ${movie.title}');
    } catch (e) {
      LoggerFactory.error('❌ [$entityName] Error guardando item: $e');

      // Fallback: DELETE + INSERT si UPSERT falla
      if (e.toString().contains('duplicate') ||
          e.toString().contains('unique')) {
        await _fallbackSave(userId, movie, extraData);
      } else {
        rethrow;
      }
    }
  }

  /// Elimina un item (soft delete)
  Future<void> removeItem(String userId, int movieId) async {
    try {
      LoggerFactory.info('🗑️ [$entityName] Eliminando movie_id: $movieId');

      await _supabase
          .from(tableName)
          .delete()
          .eq('user_id', userId)
          .eq('movie_id', movieId);

      LoggerFactory.info('✅ [$entityName] Item eliminado: $movieId');
    } catch (e) {
      LoggerFactory.error('❌ [$entityName] Error eliminando item: $e');
      rethrow;
    }
  }

  /// Verifica si un item existe
  Future<bool> itemExists(String userId, int movieId) async {
    try {
      final response = await _supabase
          .from(tableName)
          .select('id')
          .eq('user_id', userId)
          .eq('movie_id', movieId)
          .eq('is_deleted', false)
          .maybeSingle();

      return response != null;
    } catch (e) {
      LoggerFactory.error('❌ [$entityName] Error verificando item: $e');
      return false;
    }
  }

  /// Stream de cambios en tiempo real
  /// ✅ CORREGIDO: Usar la misma lógica exitosa de DirectWatchlistProvider
  Stream<List<T>> watchUserItems(String userId) {
    try {
      LoggerFactory.info(
          '👀 [$entityName] Configurando real-time sync para usuario: $userId');
      LoggerFactory.info('👀 [$entityName] Tabla: $tableName');

      // ✅ USAR LA MISMA CONFIGURACIÓN QUE WATCHLIST (que funciona)
      return _supabase
          .from(tableName)
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .map((data) {
            LoggerFactory.info(
                '📡 [$entityName] Stream emitió ${data.length} registros ANTES de filtrar');

            // Filtrar is_deleted = false
            final filtered = data.where((item) {
              final isDeleted = item['is_deleted'] as bool? ?? false;
              return !isDeleted;
            }).toList();

            LoggerFactory.info(
                '🔄 [$entityName] Real-time update: ${filtered.length} items después de filtrar is_deleted');

            if (filtered.isEmpty && data.isNotEmpty) {
              LoggerFactory.warning(
                  '⚠️ [$entityName] Todos los registros fueron filtrados por is_deleted=true');
            }

            // Convertir a entidades
            final entities =
                filtered.map((item) => supabaseDataToEntity(item)).toList();

            LoggerFactory.info(
                '✅ [$entityName] Procesadas ${entities.length} entidades para el stream');

            return entities;
          });
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ [$entityName] Error configurando real-time: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
      return Stream.value([]);
    }
  }

  /// Obtiene un item específico por movie_id
  Future<T?> getItem(String userId, int movieId) async {
    try {
      final response = await _supabase
          .from(tableName)
          .select('*')
          .eq('user_id', userId)
          .eq('movie_id', movieId)
          .eq('is_deleted', false)
          .maybeSingle();

      if (response == null) return null;

      return supabaseDataToEntity(response);
    } catch (e) {
      LoggerFactory.error('❌ [$entityName] Error obteniendo item: $e');
      return null;
    }
  }

  /// Fallback para guardar si UPSERT falla
  Future<void> _fallbackSave(
    String userId,
    Movie movie,
    Map<String, dynamic>? extraData,
  ) async {
    try {
      LoggerFactory.info('🔄 [$entityName] Usando fallback DELETE + INSERT');

      // Primero eliminar si existe
      await removeItem(userId, movie.id);

      // Esperar un poco para que se propague la eliminación
      await Future.delayed(const Duration(milliseconds: 100));

      // Luego insertar nuevo
      final now = DateTime.now().toUtc().toIso8601String();
      final data = movieToSupabaseData(userId, movie, extraData);

      data['last_modified_at'] = now;
      data['created_at'] = now;
      data['sync_version'] = 1;
      data['is_deleted'] = false;

      await _supabase.from(tableName).insert(data);

      LoggerFactory.info(
          '✅ [$entityName] Fallback exitoso para: ${movie.title}');
    } catch (e) {
      LoggerFactory.error('❌ [$entityName] Fallback también falló: $e');
      rethrow;
    }
  }

  /// Test de conectividad
  Future<bool> testConnection() async {
    try {
      LoggerFactory.info('🔗 [$entityName] Probando conexión...');

      await _supabase.from(tableName).select('count').limit(1);

      LoggerFactory.info('✅ [$entityName] Conexión exitosa');
      return true;
    } catch (e) {
      LoggerFactory.error('❌ [$entityName] Error de conexión: $e');
      return false;
    }
  }

  /// Sincronización por lotes para mejor performance
  Future<void> batchSync(
    String userId,
    List<Movie> movies, [
    Map<int, Map<String, dynamic>>? extraDataMap,
  ]) async {
    try {
      LoggerFactory.info(
          '📦 [$entityName] Sincronizando ${movies.length} items en lote');

      final now = DateTime.now().toUtc().toIso8601String();
      final batchData = <Map<String, dynamic>>[];

      for (final movie in movies) {
        final extraData = extraDataMap?[movie.id];
        final data = movieToSupabaseData(userId, movie, extraData);

        data['last_modified_at'] = now;
        data['sync_version'] = (data['sync_version'] ?? 0) + 1;
        data['is_deleted'] = false;

        batchData.add(data);
      }

      // Dividir en lotes de 50 para evitar timeout
      const batchSize = 50;
      for (var i = 0; i < batchData.length; i += batchSize) {
        final end = (i + batchSize < batchData.length)
            ? i + batchSize
            : batchData.length;
        final batch = batchData.sublist(i, end);

        await _supabase.from(tableName).upsert(
              batch,
              onConflict: 'user_id,movie_id',
              ignoreDuplicates: false,
            );

        LoggerFactory.debug(
            '✅ [$entityName] Lote ${i ~/ batchSize + 1} sincronizado');
      }

      LoggerFactory.info('✅ [$entityName] Sincronización por lotes completada');
    } catch (e) {
      LoggerFactory.error(
          '❌ [$entityName] Error en sincronización por lotes: $e');
      rethrow;
    }
  }

  /// Elimina múltiples items
  Future<void> batchRemove(String userId, List<int> movieIds) async {
    try {
      LoggerFactory.info(
          '🗑️ [$entityName] Eliminando ${movieIds.length} items en lote');

      // Eliminar de uno en uno (más lento pero compatible)
      for (final movieId in movieIds) {
        await removeItem(userId, movieId);
      }

      LoggerFactory.info('✅ [$entityName] Eliminación por lotes completada');
    } catch (e) {
      LoggerFactory.error('❌ [$entityName] Error en eliminación por lotes: $e');
      rethrow;
    }
  }

  /// Limpia todos los items del usuario (usar con precaución)
  Future<void> clearAllUserItems(String userId) async {
    try {
      LoggerFactory.warning(
          '⚠️ [$entityName] Limpiando TODOS los items del usuario: $userId');

      await _supabase.from(tableName).delete().eq('user_id', userId);

      LoggerFactory.info('✅ [$entityName] Items limpiados');
    } catch (e) {
      LoggerFactory.error('❌ [$entityName] Error limpiando items: $e');
      rethrow;
    }
  }

  /// Obtiene el conteo de items del usuario
  Future<int> getItemCount(String userId) async {
    try {
      final response = await _supabase
          .from(tableName)
          .select('id')
          .eq('user_id', userId)
          .eq('is_deleted', false);

      final List<dynamic> data = response as List<dynamic>;
      return data.length;
    } catch (e) {
      LoggerFactory.error('❌ [$entityName] Error obteniendo conteo: $e');
      return 0;
    }
  }
}
