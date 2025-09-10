import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/custom_list.dart';
import '../../domain/entities/list_item.dart';

/// Datasource para operaciones CRUD de listas personalizadas en Supabase
class SupabaseCustomListsDataSource {
  final SupabaseClient _supabase;
  
  SupabaseCustomListsDataSource(this._supabase);
  
  // ========== OPERACIONES DE LISTAS ==========
  
  /// Obtiene todas las listas del usuario actual
  Future<List<CustomList>> getUserLists(String userId) async {
    try {
      final response = await _supabase
          .from('user_lists')
          .select()
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((json) => CustomList.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener listas del usuario: $e');
    }
  }
  
  /// Obtiene una lista específica por ID
  Future<CustomList?> getListById(String listId) async {
    try {
      final response = await _supabase
          .from('user_lists')
          .select()
          .eq('id', listId)
          .eq('is_deleted', false)
          .maybeSingle();
      
      return response != null ? CustomList.fromJson(response) : null;
    } catch (e) {
      throw Exception('Error al obtener lista por ID: $e');
    }
  }
  
  /// Crea una nueva lista personalizada
  Future<CustomList> createList(CustomList list) async {
    try {
      final response = await _supabase
          .from('user_lists')
          .insert(list.toSupabaseJson())
          .select()
          .single();
      
      return CustomList.fromJson(response);
    } catch (e) {
      throw Exception('Error al crear lista: $e');
    }
  }
  
  /// Actualiza una lista existente
  Future<CustomList> updateList(CustomList list) async {
    try {
      final updateData = list.toSupabaseJson();
      updateData['updated_at'] = DateTime.now().toIso8601String();
      
      final response = await _supabase
          .from('user_lists')
          .update(updateData)
          .eq('id', list.id)
          .select()
          .single();
      
      return CustomList.fromJson(response);
    } catch (e) {
      throw Exception('Error al actualizar lista: $e');
    }
  }
  
  /// Elimina una lista (soft delete)
  Future<void> deleteList(String listId) async {
    try {
      await _supabase
          .from('user_lists')
          .update({
            'is_deleted': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', listId);
    } catch (e) {
      throw Exception('Error al eliminar lista: $e');
    }
  }
  
  /// Obtiene las listas por defecto del usuario
  Future<List<CustomList>> getDefaultLists(String userId) async {
    try {
      final response = await _supabase
          .from('user_lists')
          .select()
          .eq('user_id', userId)
          .eq('is_default', true)
          .eq('is_deleted', false)
          .order('created_at', ascending: true);
      
      return (response as List)
          .map((json) => CustomList.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener listas por defecto: $e');
    }
  }
  
  /// Inicializa las listas por defecto para un usuario
  Future<void> initializeDefaultLists(String userId, List<DefaultListConfig> configs) async {
    try {
      final defaultLists = configs.map((config) => {
        'id': config.id,
        'name': config.name,
        'description': config.description,
        'emoji': config.emoji,
        'user_id': userId,
        'is_default': true,
        'is_public': false,
        'color_hex': config.colorHex,
        'default_type': config.defaultType,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).toList();
      
      await _supabase.from('user_lists').insert(defaultLists);
    } catch (e) {
      throw Exception('Error al inicializar listas por defecto: $e');
    }
  }
  
  // ========== OPERACIONES DE ELEMENTOS ==========
  
  /// Obtiene todos los elementos de una lista
  Future<List<ListItem>> getListItems(String listId) async {
    try {
      final response = await _supabase
          .from('user_list_items')
          .select()
          .eq('list_id', listId)
          .order('position', ascending: true);
      
      return (response as List)
          .map((json) => ListItem.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener elementos de la lista: $e');
    }
  }
  
  /// Agrega una película a una lista
  Future<ListItem> addMovieToList(String listId, int movieId, {int? position}) async {
    try {
      // Si no se especifica posición, obtener la siguiente disponible
      int finalPosition = position ?? await _getNextPosition(listId);
      
      final listItem = ListItem(
        id: '', // Supabase generará el UUID
        listId: listId,
        movieId: movieId,
        position: finalPosition,
        addedAt: DateTime.now(),
      );
      
      final response = await _supabase
          .from('user_list_items')
          .insert(listItem.toSupabaseJson())
          .select()
          .single();
      
      return ListItem.fromJson(response);
    } catch (e) {
      throw Exception('Error al agregar película a la lista: $e');
    }
  }
  
  /// Remueve una película de una lista
  Future<void> removeMovieFromList(String listId, int movieId) async {
    try {
      await _supabase
          .from('user_list_items')
          .delete()
          .eq('list_id', listId)
          .eq('movie_id', movieId);
    } catch (e) {
      throw Exception('Error al remover película de la lista: $e');
    }
  }
  
  /// Reordena los elementos de una lista
  Future<void> reorderListItems(String listId, List<ListItem> items) async {
    try {
      final updates = items.asMap().entries.map((entry) => {
        'id': entry.value.id,
        'position': entry.key,
        'updated_at': DateTime.now().toIso8601String(),
      }).toList();
      
      // Actualizar posiciones en lote
      for (final update in updates) {
        await _supabase
            .from('user_list_items')
            .update({'position': update['position'], 'updated_at': update['updated_at']})
            .eq('id', update['id']);
      }
    } catch (e) {
      throw Exception('Error al reordenar elementos de la lista: $e');
    }
  }
  
  /// Verifica si una película está en una lista específica
  Future<bool> isMovieInList(String listId, int movieId) async {
    try {
      final response = await _supabase
          .from('user_list_items')
          .select('id')
          .eq('list_id', listId)
          .eq('movie_id', movieId)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      throw Exception('Error al verificar película en lista: $e');
    }
  }
  
  // ========== STREAMS PARA REAL-TIME ==========
  
  /// Stream para escuchar cambios en las listas del usuario
  Stream<List<CustomList>> watchUserLists(String userId) {
    return _supabase
        .from('user_lists')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => CustomList.fromJson(json)).toList());
  }
  
  /// Stream para escuchar cambios en los elementos de una lista
  Stream<List<ListItem>> watchListItems(String listId) {
    return _supabase
        .from('user_list_items')
        .stream(primaryKey: ['id'])
        .eq('list_id', listId)
        .order('position', ascending: true)
        .map((data) => data.map((json) => ListItem.fromJson(json)).toList());
  }
  
  // ========== MÉTODOS AUXILIARES ==========
  
  /// Obtiene la siguiente posición disponible en una lista
  Future<int> _getNextPosition(String listId) async {
    try {
      final response = await _supabase
          .from('user_list_items')
          .select('position')
          .eq('list_id', listId)
          .order('position', ascending: false)
          .limit(1)
          .maybeSingle();
      
      return response != null ? (response['position'] as int) + 1 : 0;
    } catch (e) {
      return 0; // Si hay error, empezar desde 0
    }
  }
  
  /// Verifica si el usuario tiene acceso a una lista
  Future<bool> hasAccessToList(String listId, String userId) async {
    try {
      final response = await _supabase
          .from('user_lists')
          .select('user_id, is_public')
          .eq('id', listId)
          .maybeSingle();
      
      if (response == null) return false;
      
      // El usuario tiene acceso si es el propietario o si la lista es pública
      return response['user_id'] == userId || response['is_public'] == true;
    } catch (e) {
      return false;
    }
  }
}