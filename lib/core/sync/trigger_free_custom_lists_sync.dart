import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/custom_list.dart';
import '../logging/logger_factory.dart';

/// Servicio de sincronización que evita completamente los triggers de PostgreSQL
/// usando operaciones directas INSERT/DELETE en lugar de UPSERT para Listas Personalizadas
class TriggerFreeCustomListsSync {
  TriggerFreeCustomListsSync._internal();

  static final TriggerFreeCustomListsSync _instance =
      TriggerFreeCustomListsSync._internal();
  static TriggerFreeCustomListsSync get instance => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obtiene listas del usuario
  Future<List<CustomList>> getUserLists(String userId) async {
    try {
      LoggerFactory.info('📥 [TriggerFree] Obteniendo listas: $userId');

      final response = await _supabase
          .from('user_lists')
          .select('*')
          .eq("user_id", userId)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final listsData = data.cast<Map<String, dynamic>>();

      final customLists =
          listsData.map((data) => _dataToCustomList(data)).toList();

      LoggerFactory.info(
          '✅ [TriggerFree] Encontradas ${customLists.length} listas');

      return customLists;
    } catch (e) {
      LoggerFactory.error('❌ [TriggerFree] Error obteniendo listas: $e');
      return [];
    }
  }

  /// Obtiene items de una lista específica
  Future<List<int>> getListItems(String userId, String listId) async {
    try {
      LoggerFactory.info('📥 [TriggerFree] Obteniendo items de lista: $listId');

      final response = await _supabase
          .from('user_list_items')
          .select('movie_id')
          .eq("user_id", userId)
          .order('added_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final itemsData = data.cast<Map<String, dynamic>>();

      final movieIds =
          itemsData.map((data) => data['movie_id'] as int).toList();

      LoggerFactory.info(
          '✅ [TriggerFree] Encontrados ${movieIds.length} items en lista $listId');

      return movieIds;
    } catch (e) {
      LoggerFactory.error(
          '❌ [TriggerFree] Error obteniendo items de lista: $e');
      return [];
    }
  }

  /// Crear nueva lista
  Future<CustomList?> createList(String userId, CustomList list) async {
    try {
      LoggerFactory.info('➕ [TriggerFree] Creando lista: ${list.name}');

      // final now = DateTime.now().toUtc().toIso8601String();

      final response = await _supabase
          .from('user_lists')
          .insert({
            'id': list.id,
            'user_id': userId,
            'name': list.name,
            'description': list.description,
            'color_hex': _colorNameToHex(list.color),
            'is_public': false,
            'sync_version': 1,
            'is_deleted': false,
          })
          .select()
          .single();

      final createdList = _dataToCustomList(response);

      LoggerFactory.info('✅ [TriggerFree] Lista creada: ${list.name}');
      return createdList;
    } catch (e) {
      LoggerFactory.error('❌ [TriggerFree] Error creando lista: $e');
      return null;
    }
  }

  /// Actualizar lista existente
  Future<void> updateList(String userId, CustomList list) async {
    try {
      LoggerFactory.info('🔄 [TriggerFree] Actualizando lista: ${list.name}');

      // final now = DateTime.now().toUtc().toIso8601String();

      await _supabase
          .from('user_lists')
          .update({
            'name': list.name,
            'description': list.description,
            // Campos opcionales - solo usar los que existen
            // 'emoji': list.emoji,
            // 'color': list.color,
            // 'sync_version': 1,
          })
          .eq("user_id", userId);

      LoggerFactory.info('✅ [TriggerFree] Lista actualizada: ${list.name}');
    } catch (e) {
      LoggerFactory.error('❌ [TriggerFree] Error actualizando lista: $e');
      rethrow;
    }
  }

  /// Eliminar lista usando DELETE directo
  Future<void> deleteList(String userId, String listId) async {
    try {
      LoggerFactory.info('🗑️ [TriggerFree] Eliminando lista: $listId');

      // Primero eliminar todos los items de la lista
      await _supabase.from('user_list_items').delete().eq("user_id", userId);

      // Luego eliminar la lista
      await _supabase
          .from('user_lists')
          .delete()
          .eq("user_id", userId);

      LoggerFactory.info('✅ [TriggerFree] Lista eliminada: $listId');
    } catch (e) {
      LoggerFactory.error('❌ [TriggerFree] Error eliminando lista: $e');
      rethrow;
    }
  }

  /// Añadir película a lista
  Future<void> addMovieToList(String userId, String listId, int movieId) async {
    try {
      LoggerFactory.info(
          '➕ [TriggerFree] Agregando película $movieId a lista $listId');

      // final now = DateTime.now().toUtc().toIso8601String();

      // Necesitamos obtener información de la película para movie_title
      // Por ahora usaremos un título por defecto, pero idealmente debería obtenerse
      await _supabase.from('user_list_items').insert({
        'list_id': listId,
        'movie_id': movieId,
        'movie_title':
            'Movie $movieId', // Título temporal - debería venir de TMDB
        'is_deleted': false,
        'sync_version': 1,
      });

      LoggerFactory.info('✅ [TriggerFree] Película agregada a lista');
    } catch (e) {
      LoggerFactory.error(
          '❌ [TriggerFree] Error agregando película a lista: $e');
      rethrow;
    }
  }

  /// Remover película de lista usando DELETE directo
  Future<void> removeMovieFromList(
      String userId, String listId, int movieId) async {
    try {
      LoggerFactory.info(
          '🗑️ [TriggerFree] Removiendo película $movieId de lista $listId');

      await _supabase
          .from('user_list_items')
          .delete()
          .eq("user_id", userId);

      LoggerFactory.info('✅ [TriggerFree] Película removida de lista');
    } catch (e) {
      LoggerFactory.error(
          '❌ [TriggerFree] Error removiendo película de lista: $e');
      rethrow;
    }
  }

  /// Verifica si una película está en una lista específica
  Future<bool> isMovieInList(String userId, String listId, int movieId) async {
    try {
      final response = await _supabase
          .from('user_list_items')
          .select('movie_id')
          .eq("user_id", userId)
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      LoggerFactory.error(
          '❌ [TriggerFree] Error verificando película en lista: $e');
      return false;
    }
  }

  /// Convierte datos de Supabase a CustomList
  CustomList _dataToCustomList(Map<String, dynamic> data) {
    // Convertir color hex de vuelta a nombre de color para compatibilidad
    String colorHex = data['color_hex'] as String? ?? '#2196F3';
    String colorName = _hexToColorName(colorHex);

    return CustomList(
      id: data['id'] as String,
      name: data['name'] as String,
      description: data['description'] as String? ?? '',
      emoji: data['emoji'] as String? ?? '📝', // Default si no existe
      color: colorName,
      movieIds: [], // Los IDs se cargan por separado
      createdAt: DateTime.parse(
          data['created_at'] as String? ?? DateTime.now().toIso8601String()),
      lastModifiedAt: DateTime.parse(data['last_modified_at'] as String? ??
          data['created_at'] as String? ??
          DateTime.now().toIso8601String()),
      isDefault: data['is_default'] as bool? ?? false,
    );
  }

  /// Test básico de conectividad
  Future<bool> testConnection() async {
    try {
      LoggerFactory.info('🔗 [TriggerFree] Probando conexión...');

      await _supabase.from('user_lists').select('count').limit(1);

      LoggerFactory.info('✅ [TriggerFree] Conexión exitosa');
      return true;
    } catch (e) {
      LoggerFactory.error('❌ [TriggerFree] Error de conexión: $e');
      return false;
    }
  }

  /// Convierte nombre de color a código hexadecimal
  String _colorNameToHex(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'red':
        return '#F44336';
      case 'pink':
        return '#E91E63';
      case 'purple':
        return '#9C27B0';
      case 'deep_purple':
        return '#673AB7';
      case 'indigo':
        return '#3F51B5';
      case 'blue':
        return '#2196F3';
      case 'light_blue':
        return '#03A9F4';
      case 'cyan':
        return '#00BCD4';
      case 'teal':
        return '#009688';
      case 'green':
        return '#4CAF50';
      case 'light_green':
        return '#8BC34A';
      case 'lime':
        return '#CDDC39';
      case 'yellow':
        return '#FFEB3B';
      case 'amber':
        return '#FFC107';
      case 'orange':
        return '#FF9800';
      case 'deep_orange':
        return '#FF5722';
      case 'brown':
        return '#795548';
      case 'grey':
        return '#9E9E9E';
      case 'blue_grey':
        return '#607D8B';
      default:
        return '#2196F3'; // Default blue
    }
  }

  /// Convierte código hexadecimal de vuelta a nombre de color
  String _hexToColorName(String hexColor) {
    switch (hexColor.toUpperCase()) {
      case '#F44336':
        return 'red';
      case '#E91E63':
        return 'pink';
      case '#9C27B0':
        return 'purple';
      case '#673AB7':
        return 'deep_purple';
      case '#3F51B5':
        return 'indigo';
      case '#2196F3':
        return 'blue';
      case '#03A9F4':
        return 'light_blue';
      case '#00BCD4':
        return 'cyan';
      case '#009688':
        return 'teal';
      case '#4CAF50':
        return 'green';
      case '#8BC34A':
        return 'light_green';
      case '#CDDC39':
        return 'lime';
      case '#FFEB3B':
        return 'yellow';
      case '#FFC107':
        return 'amber';
      case '#FF9800':
        return 'orange';
      case '#FF5722':
        return 'deep_orange';
      case '#795548':
        return 'brown';
      case '#9E9E9E':
        return 'grey';
      case '#607D8B':
        return 'blue_grey';
      default:
        return 'blue'; // Default blue
    }
  }
}
