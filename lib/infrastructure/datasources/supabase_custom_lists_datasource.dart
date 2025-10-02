import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/entities/custom_list.dart';
import '../../domain/entities/list_item.dart';

/// Datasource para operaciones CRUD de listas personalizadas en Supabase
class SupabaseCustomListsDataSource {
  const SupabaseCustomListsDataSource(this._supabase);
  final SupabaseClient _supabase;

  // ========== OPERACIONES DE LISTAS ==========

  /// Obtiene todas las listas del usuario actual
  Future<List<CustomList>> getUserLists(String userId) async {
    try {
      final response = await _supabase
          .from('user_lists')
          .select()
          .filter('user_id', 'eq', userId)
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
          .maybeSingle();

      return response != null ? CustomList.fromJson(response) : null;
    } catch (e) {
      throw Exception('Error al obtener lista por ID: $e');
    }
  }

  /// Crea una nueva lista personalizada
  Future<CustomList> createList(CustomList list) async {
    try {
      final payload = _sanitizePayload(list.toSupabaseJson());
      final response = await _insertWithFallback(payload);

      return CustomList.fromJson(response);
    } catch (e) {
      throw Exception('Error al crear lista: $e');
    }
  }

  /// Actualiza una lista existente
  Future<CustomList> updateList(CustomList list) async {
    try {
      final updateData = _sanitizePayload(list.toSupabaseJson()
        ..['last_modified_at'] = DateTime.now().toUtc().toIso8601String());

      final response = await _updateWithFallback(updateData, list.id);

      return CustomList.fromJson(response);
    } catch (e) {
      throw Exception('Error al actualizar lista: $e');
    }
  }

  /// Elimina una lista (hard delete)
  Future<void> deleteList(String listId) async {
    try {
      // Primero eliminar todos los items de la lista
      await _supabase.from('user_list_items').delete().eq('list_id', listId);

      // Luego eliminar la lista misma
      await _supabase.from('user_lists').delete().eq('id', listId);
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
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => CustomList.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener listas por defecto: $e');
    }
  }

  /// Inicializa las listas por defecto para un usuario
  Future<void> initializeDefaultLists(
      String userId, List<DefaultListConfig> configs) async {
    try {
      // Obtener las listas por defecto existentes para este usuario
      final existingDefaultLists = await getDefaultLists(userId);
      final existingTypes =
          existingDefaultLists.map((list) => list.defaultType).toSet();

      // Filtrar solo las configuraciones que no existen aún
      final configsToCreate = configs
          .where((config) => !existingTypes.contains(config.defaultType))
          .toList();

      if (configsToCreate.isEmpty) {
        // Todas las listas por defecto ya existen para este usuario
        return;
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final defaultLists = configsToCreate
          .map((config) => _sanitizePayload({
                'id': config.localId,
                'name': config.name,
                'description': config.description,
                'emoji': config.emoji,
                'user_id': userId,
                'is_default': true,
                'is_public': false,
                'color_hex':
                    config.color, // FIX: Usar color_hex en vez de color
                'default_type': config.defaultType,
                'created_at': now,
                'last_modified_at': now,
              }))
          .toList();

      await _insertBatchWithFallback(defaultLists);
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

      return (response as List).map((json) => ListItem.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Error al obtener elementos de la lista: $e');
    }
  }

  /// Agrega una película a una lista
  Future<ListItem> addMovieToList(String listId, int movieId,
      {int? position}) async {
    try {
      // Si no se especifica posición, obtener la siguiente disponible
      int finalPosition = position ?? await _getNextPosition(listId);

      final listItem = ListItem(
        id: '', // Supabase generará el UUID
        listId: listId,
        movieId: movieId,
        movieTitle: '', // Se actualizará desde TMDB
        position: finalPosition,
        addedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final payload = _sanitizePayload(listItem.toSupabaseJson());
      final response = await _insertListItemWithFallback(payload);

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
      final updates = items
          .asMap()
          .entries
          .map((entry) => {
                'id': entry.value.id,
                'position': entry.key,
                'updated_at': DateTime.now().toIso8601String(),
              })
          .toList();

      // Actualizar posiciones en lote
      for (final update in updates) {
        await _supabase.from('user_list_items').update({
          'position': update['position'],
          'updated_at': update['updated_at']
        }).eq('id', update['id'] as String);
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
    return _supabase.from('user_lists').stream(primaryKey: ['id']).map((data) =>
        data
            .where((json) => json['user_id'] == userId)
            .map((json) => CustomList.fromJson(json))
            .toList());
  }

  /// Stream para escuchar cambios en los elementos de una lista
  Stream<List<ListItem>> watchListItems(String listId) {
    return _supabase.from('user_list_items').stream(primaryKey: ['id']).map(
        (data) => data
            .where((json) => json['list_id'] == listId)
            .map((json) => ListItem.fromJson(json))
            .toList());
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

  // ========== OPERACIONES AVANZADAS ==========

  /// Duplica una lista con todas sus películas
  Future<CustomList> duplicateList(
      String listId, String newName, String userId) async {
    try {
      // 1. Obtener lista original
      final originalList = await getListById(listId);
      if (originalList == null) {
        throw Exception('Lista original no encontrada');
      }

      // 2. Crear nueva lista
      final now = DateTime.now().toUtc();
      final newList = CustomList(
        id: '', // Será generado por Supabase
        name: newName,
        description: '${originalList.description} (Copia)',
        emoji: originalList.emoji,
        movieIds: [], // Deprecated, no se usa
        createdAt: now,
        lastModifiedAt: now,
        isDefault: false,
        color: originalList.color,
      );

      final createdList = await createList(newList);

      // 3. Obtener items de la lista original
      final originalItems = await getListItems(listId);

      // 4. Copiar items a la nueva lista
      if (originalItems.isNotEmpty) {
        final itemsToInsert = originalItems.map((item) {
          return {
            'list_id': createdList.id,
            'movie_id': item.movieId,
            'position': item.position,
            'added_at': now.toIso8601String(),
          };
        }).toList();

        await _supabase.from('user_list_items').insert(itemsToInsert);
      }

      LoggerFactory.info(
          '✅ Lista duplicada: ${originalList.name} → $newName (${originalItems.length} películas)');

      return createdList;
    } catch (e) {
      throw Exception('Error al duplicar lista: $e');
    }
  }

  /// Elimina todas las películas de una lista
  Future<void> clearListMovies(String listId) async {
    try {
      await _supabase.from('user_list_items').delete().eq('list_id', listId);

      LoggerFactory.info('✅ Películas eliminadas de lista $listId');
    } catch (e) {
      throw Exception('Error al limpiar lista: $e');
    }
  }
}

extension on SupabaseCustomListsDataSource {
  Map<String, dynamic> _sanitizePayload(Map<String, dynamic> payload) {
    final sanitized = Map<String, dynamic>.from(payload)
      ..removeWhere((key, value) => value == null);

    // Evitar enviar campos vacíos que pueden no existir en el esquema remoto
    if (sanitized['default_type'] is String &&
        (sanitized['default_type'] as String).trim().isEmpty) {
      sanitized.remove('default_type');
    }

    return sanitized;
  }

  Future<Map<String, dynamic>> _insertWithFallback(
      Map<String, dynamic> payload) async {
    try {
      return await _supabase
          .from('user_lists')
          .insert(payload)
          .select()
          .single();
    } on PostgrestException catch (error) {
      await LoggerFactory.warning(
        'Fallo al insertar lista, reintentando sin columnas no soportadas: ${error.message}',
      );
      final retryPayload = _payloadWithoutUnsupportedColumns(payload, error);
      if (retryPayload.length == payload.length) {
        rethrow;
      }
      return await _supabase
          .from('user_lists')
          .insert(retryPayload)
          .select()
          .single();
    }
  }

  Future<void> _insertBatchWithFallback(
      List<Map<String, dynamic>> payloads) async {
    try {
      await _supabase.from('user_lists').insert(payloads);
    } on PostgrestException catch (error) {
      await LoggerFactory.warning(
        'Fallo al insertar batch de listas, aplicando fallback: ${error.message}',
      );
      final retryPayloads = payloads
          .map((payload) => _payloadWithoutUnsupportedColumns(payload, error))
          .toList();
      if (_listsAreIdentical(payloads, retryPayloads)) {
        rethrow;
      }
      await _supabase.from('user_lists').insert(retryPayloads);
    }
  }

  Future<Map<String, dynamic>> _updateWithFallback(
      Map<String, dynamic> payload, String listId) async {
    try {
      return await _supabase
          .from('user_lists')
          .update(payload)
          .eq('id', listId)
          .select()
          .single();
    } on PostgrestException catch (error) {
      await LoggerFactory.warning(
        'Fallo al actualizar lista $listId, reintentando: ${error.message}',
      );
      final retryPayload = _payloadWithoutUnsupportedColumns(payload, error);
      if (retryPayload.length == payload.length) {
        rethrow;
      }
      return await _supabase
          .from('user_lists')
          .update(retryPayload)
          .eq('id', listId)
          .select()
          .single();
    }
  }

  Map<String, dynamic> _payloadWithoutUnsupportedColumns(
    Map<String, dynamic> payload,
    PostgrestException error,
  ) {
    final sanitized = Map<String, dynamic>.from(payload);
    final message = error.message.toLowerCase();
    final details = error.details?.toString().toLowerCase() ?? '';

    bool containsKeyword(String keyword) =>
        message.contains(keyword) || details.contains(keyword);

    if (containsKeyword("'default_type'") || containsKeyword('default_type')) {
      sanitized.remove('default_type');
    }

    if (containsKeyword("'color_hex'") || containsKeyword('color_hex')) {
      sanitized['color'] = sanitized['color_hex'];
      sanitized.remove('color_hex');
    }

    if (containsKeyword("'color'") || containsKeyword('color')) {
      // Fallback a color_hex para compatibilidad con esquemas antiguos
      if (sanitized.containsKey('color')) {
        sanitized['color_hex'] = sanitized['color'];
        sanitized.remove('color');
      }
    }

    if (containsKeyword("'last_modified_at'") ||
        containsKeyword('last_modified_at')) {
      sanitized.remove('last_modified_at');
    }

    if (containsKeyword("'is_deleted'") || containsKeyword('is_deleted')) {
      sanitized.remove('is_deleted');
    }

    if (containsKeyword("'sync_status'") || containsKeyword('sync_status')) {
      sanitized.remove('sync_status');
    }

    if (containsKeyword("'created_at'") || containsKeyword('created_at')) {
      sanitized.remove('created_at');
    }

    if (containsKeyword("'emoji'") || containsKeyword('emoji')) {
      sanitized.remove('emoji');
    }

    if (containsKeyword("'description'") || containsKeyword('description')) {
      sanitized.remove('description');
    }

    if (containsKeyword("'is_public'") || containsKeyword('is_public')) {
      sanitized.remove('is_public');
    }

    if (containsKeyword("'is_default'") || containsKeyword('is_default')) {
      sanitized.remove('is_default');
    }

    if (containsKeyword("'movie_poster_path'") ||
        containsKeyword('movie_poster_path')) {
      sanitized.remove('movie_poster_path');
    }

    if (containsKeyword("'movie_title'") || containsKeyword('movie_title')) {
      // Algunos esquemas antiguos usan movie_name
      sanitized['movie_name'] = sanitized['movie_title'];
      sanitized.remove('movie_title');
    }

    if (containsKeyword("'position'") || containsKeyword('position')) {
      sanitized.remove('position');
    }

    if (containsKeyword("'added_at'") || containsKeyword('added_at')) {
      sanitized.remove('added_at');
    }

    if (containsKeyword("'updated_at'") || containsKeyword('updated_at')) {
      sanitized.remove('updated_at');
    }

    if (containsKeyword("'id'") || containsKeyword('id')) {
      sanitized.remove('id');
    }

    // Si no se eliminó ninguna columna específica, ejecutar fallback mínimo
    if (sanitized.length == payload.length) {
      final optionalColumns = payload.containsKey('movie_id')
          ? <String>{
              'movie_title',
              'movie_poster_path',
              'position',
              'added_at',
              'updated_at',
            }
          : <String>{
              'emoji',
              'description',
              'color',
              'color_hex',
              'default_type',
              'last_modified_at',
              'is_deleted',
              'sync_status',
              'created_at',
              'is_public',
              'is_default',
            };

      for (final key in optionalColumns) {
        sanitized.remove(key);
      }
    }

    return sanitized;
  }

  Future<Map<String, dynamic>> _insertListItemWithFallback(
      Map<String, dynamic> payload) async {
    try {
      return await _supabase
          .from('user_list_items')
          .insert(payload)
          .select()
          .single();
    } on PostgrestException catch (error) {
      await LoggerFactory.warning(
        'Fallo al insertar elemento de lista, aplicando fallback: ${error.message}',
      );
      final retryPayload = _payloadWithoutUnsupportedColumns(payload, error);
      if (retryPayload.length == payload.length) {
        rethrow;
      }
      return await _supabase
          .from('user_list_items')
          .insert(retryPayload)
          .select()
          .single();
    }
  }

  bool _listsAreIdentical(
    List<Map<String, dynamic>> original,
    List<Map<String, dynamic>> transformed,
  ) {
    if (original.length != transformed.length) {
      return false;
    }

    for (var i = 0; i < original.length; i++) {
      if (original[i].length != transformed[i].length) {
        return false;
      }
      for (final key in original[i].keys) {
        if (!transformed[i].containsKey(key)) {
          return false;
        }
      }
    }
    return true;
  }
}
