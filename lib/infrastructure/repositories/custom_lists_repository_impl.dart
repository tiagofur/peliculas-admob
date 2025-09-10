import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../domain/entities/custom_list.dart';
import '../../domain/entities/list_item.dart';
import '../../domain/repositories/i_custom_lists_repository.dart';
import '../datasources/supabase_custom_lists_datasource.dart';

/// Implementación del repositorio de listas personalizadas
/// Maneja sincronización real-time, operaciones offline y resolución de conflictos
class CustomListsRepositoryImpl implements ICustomListsRepository {
  final SupabaseCustomListsDataSource _supabaseDataSource;
  final SharedPreferences _prefs;
  final Connectivity _connectivity;
  
  // Claves para SharedPreferences
  static const String _localListsKey = 'local_custom_lists';
  static const String _pendingOperationsKey = 'pending_operations';
  static const String _lastSyncKey = 'last_sync_timestamp';
  
  CustomListsRepositoryImpl(
    this._supabaseDataSource,
    this._prefs,
    this._connectivity,
  );
  
  // ========== OPERACIONES DE LISTAS ==========
  
  @override
  Future<List<CustomList>> getUserLists() async {
    try {
      if (await hasInternetConnection()) {
        final lists = await _supabaseDataSource.getUserLists(_getCurrentUserId());
        await _saveListsLocally(lists);
        return lists;
      } else {
        return await getLocalLists();
      }
    } catch (e) {
      // En caso de error, intentar obtener datos locales
      return await getLocalLists();
    }
  }
  
  @override
  Future<CustomList?> getListById(String listId) async {
    try {
      if (await hasInternetConnection()) {
        return await _supabaseDataSource.getListById(listId);
      } else {
        final localLists = await getLocalLists();
        return localLists.firstWhere(
          (list) => list.id == listId,
          orElse: () => throw Exception('Lista no encontrada localmente'),
        );
      }
    } catch (e) {
      throw Exception('Error al obtener lista: $e');
    }
  }
  
  @override
  Future<CustomList> createList(CustomList list) async {
    try {
      if (await hasInternetConnection()) {
        final createdList = await _supabaseDataSource.createList(list);
        await _updateLocalList(createdList);
        return createdList;
      } else {
        // Guardar operación pendiente
        await _savePendingOperation('create', list.toJson());
        final offlineList = list.copyWith(
          syncStatus: 'pending',
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        );
        await _updateLocalList(offlineList);
        return offlineList;
      }
    } catch (e) {
      throw Exception('Error al crear lista: $e');
    }
  }
  
  @override
  Future<CustomList> updateList(CustomList list) async {
    try {
      if (await hasInternetConnection()) {
        final updatedList = await _supabaseDataSource.updateList(list);
        await _updateLocalList(updatedList);
        return updatedList;
      } else {
        // Guardar operación pendiente
        await _savePendingOperation('update', list.toJson());
        final offlineList = list.copyWith(syncStatus: 'pending');
        await _updateLocalList(offlineList);
        return offlineList;
      }
    } catch (e) {
      throw Exception('Error al actualizar lista: $e');
    }
  }
  
  @override
  Future<void> deleteList(String listId) async {
    try {
      if (await hasInternetConnection()) {
        await _supabaseDataSource.deleteList(listId);
        await _removeLocalList(listId);
      } else {
        // Guardar operación pendiente
        await _savePendingOperation('delete', {'id': listId});
        // Marcar como eliminada localmente
        final localLists = await getLocalLists();
        final listIndex = localLists.indexWhere((l) => l.id == listId);
        if (listIndex != -1) {
          final updatedList = localLists[listIndex].copyWith(
            isDeleted: true,
            syncStatus: 'pending',
          );
          await _updateLocalList(updatedList);
        }
      }
    } catch (e) {
      throw Exception('Error al eliminar lista: $e');
    }
  }
  
  @override
  Future<List<CustomList>> getDefaultLists() async {
    try {
      if (await hasInternetConnection()) {
        return await _supabaseDataSource.getDefaultLists(_getCurrentUserId());
      } else {
        final localLists = await getLocalLists();
        return localLists.where((list) => list.isDefault).toList();
      }
    } catch (e) {
      throw Exception('Error al obtener listas por defecto: $e');
    }
  }
  
  @override
  Future<void> initializeDefaultLists(String userId) async {
    try {
      final defaultConfigs = _getDefaultListConfigs();
      
      if (await hasInternetConnection()) {
        await _supabaseDataSource.initializeDefaultLists(userId, defaultConfigs);
      } else {
        // Crear listas por defecto localmente
        final defaultLists = defaultConfigs.map((config) => CustomList(
          id: config.id,
          name: config.name,
          description: config.description,
          emoji: config.emoji,
          movieIds: [],
          createdAt: DateTime.now(),
          lastModifiedAt: DateTime.now(),
          userId: userId,
          isDefault: true,
          isPublic: false,
          color: config.colorHex,
          isDeleted: false,
          syncStatus: 'pending',
          defaultType: config.defaultType,
          colorHex: config.colorHex,
        )).toList();
        
        for (final list in defaultLists) {
          await _updateLocalList(list);
        }
        
        // Guardar operación pendiente
        await _savePendingOperation('init_defaults', {'userId': userId});
      }
    } catch (e) {
      throw Exception('Error al inicializar listas por defecto: $e');
    }
  }
  
  // ========== OPERACIONES DE ELEMENTOS ==========
  
  @override
  Future<List<ListItem>> getListItems(String listId) async {
    try {
      if (await hasInternetConnection()) {
        return await _supabaseDataSource.getListItems(listId);
      } else {
        // Obtener elementos locales (simplificado para este ejemplo)
        return [];
      }
    } catch (e) {
      throw Exception('Error al obtener elementos de la lista: $e');
    }
  }
  
  @override
  Future<ListItem> addMovieToList(String listId, int movieId, {int? position}) async {
    try {
      if (await hasInternetConnection()) {
        return await _supabaseDataSource.addMovieToList(listId, movieId, position: position);
      } else {
        // Crear elemento temporal
        final tempItem = ListItem(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          listId: listId,
          movieId: movieId,
          position: position ?? 0,
          addedAt: DateTime.now(),
        );
        
        await _savePendingOperation('add_movie', {
          'listId': listId,
          'movieId': movieId,
          'position': position,
        });
        
        return tempItem;
      }
    } catch (e) {
      throw Exception('Error al agregar película a la lista: $e');
    }
  }
  
  @override
  Future<void> removeMovieFromList(String listId, int movieId) async {
    try {
      if (await hasInternetConnection()) {
        await _supabaseDataSource.removeMovieFromList(listId, movieId);
      } else {
        await _savePendingOperation('remove_movie', {
          'listId': listId,
          'movieId': movieId,
        });
      }
    } catch (e) {
      throw Exception('Error al remover película de la lista: $e');
    }
  }
  
  @override
  Future<void> reorderListItems(String listId, List<ListItem> items) async {
    try {
      if (await hasInternetConnection()) {
        await _supabaseDataSource.reorderListItems(listId, items);
      } else {
        await _savePendingOperation('reorder_items', {
          'listId': listId,
          'items': items.map((item) => item.toJson()).toList(),
        });
      }
    } catch (e) {
      throw Exception('Error al reordenar elementos: $e');
    }
  }
  
  @override
  Future<bool> isMovieInList(String listId, int movieId) async {
    try {
      if (await hasInternetConnection()) {
        return await _supabaseDataSource.isMovieInList(listId, movieId);
      } else {
        // Verificación local simplificada
        return false;
      }
    } catch (e) {
      return false;
    }
  }
  
  // ========== SINCRONIZACIÓN ==========
  
  @override
  Stream<List<CustomList>> watchUserLists() {
    return _supabaseDataSource.watchUserLists(_getCurrentUserId());
  }
  
  @override
  Stream<List<ListItem>> watchListItems(String listId) {
    return _supabaseDataSource.watchListItems(listId);
  }
  
  @override
  Future<void> syncLists() async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('Sin conexión a internet');
      }
      
      // Sincronizar operaciones pendientes
      final pendingOps = await getPendingOperations();
      
      for (final op in pendingOps) {
        try {
          await _executePendingOperation(op);
          await markOperationAsSynced(op['id']);
        } catch (e) {
          print('Error al sincronizar operación ${op['id']}: $e');
        }
      }
      
      // Actualizar timestamp de última sincronización
      await _prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      throw Exception('Error durante la sincronización: $e');
    }
  }
  
  @override
  Future<CustomList> resolveConflict(CustomList localList, CustomList remoteList) async {
    // Estrategia simple: el más reciente gana
    if (localList.lastModifiedAt.isAfter(remoteList.lastModifiedAt)) {
      return await updateList(localList);
    } else {
      await _updateLocalList(remoteList);
      return remoteList;
    }
  }
  
  // ========== OPERACIONES OFFLINE ==========
  
  @override
  Future<List<CustomList>> getLocalLists() async {
    try {
      final listsJson = _prefs.getString(_localListsKey);
      if (listsJson == null) return [];
      
      final List<dynamic> listData = json.decode(listsJson);
      return listData
          .map((json) => CustomList.fromJson(json))
          .where((list) => !list.isDeleted)
          .toList();
    } catch (e) {
      return [];
    }
  }
  
  @override
  Future<void> saveListLocally(CustomList list) async {
    await _updateLocalList(list);
  }
  
  @override
  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    try {
      final opsJson = _prefs.getString(_pendingOperationsKey);
      if (opsJson == null) return [];
      
      final List<dynamic> opsData = json.decode(opsJson);
      return opsData.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }
  
  @override
  Future<void> markOperationAsSynced(String operationId) async {
    try {
      final pendingOps = await getPendingOperations();
      final updatedOps = pendingOps.where((op) => op['id'] != operationId).toList();
      await _prefs.setString(_pendingOperationsKey, json.encode(updatedOps));
    } catch (e) {
      print('Error al marcar operación como sincronizada: $e');
    }
  }
  
  // ========== UTILIDADES ==========
  
  @override
  Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }
  
  @override
  Future<String> getSyncStatus() async {
    final lastSync = _prefs.getString(_lastSyncKey);
    final pendingOps = await getPendingOperations();
    
    if (pendingOps.isNotEmpty) {
      return 'pending';
    } else if (lastSync != null) {
      return 'synced';
    } else {
      return 'never_synced';
    }
  }
  
  @override
  Future<void> clearLocalCache() async {
    await _prefs.remove(_localListsKey);
    await _prefs.remove(_pendingOperationsKey);
    await _prefs.remove(_lastSyncKey);
  }
  
  // ========== MÉTODOS PRIVADOS ==========
  
  String _getCurrentUserId() {
    // TODO: Obtener del sistema de autenticación
    return 'current_user_id';
  }
  
  Future<void> _saveListsLocally(List<CustomList> lists) async {
    try {
      final listsJson = json.encode(lists.map((list) => list.toJson()).toList());
      await _prefs.setString(_localListsKey, listsJson);
    } catch (e) {
      print('Error al guardar listas localmente: $e');
    }
  }
  
  Future<void> _updateLocalList(CustomList list) async {
    try {
      final localLists = await getLocalLists();
      final existingIndex = localLists.indexWhere((l) => l.id == list.id);
      
      if (existingIndex != -1) {
        localLists[existingIndex] = list;
      } else {
        localLists.add(list);
      }
      
      await _saveListsLocally(localLists);
    } catch (e) {
      print('Error al actualizar lista local: $e');
    }
  }
  
  Future<void> _removeLocalList(String listId) async {
    try {
      final localLists = await getLocalLists();
      localLists.removeWhere((list) => list.id == listId);
      await _saveListsLocally(localLists);
    } catch (e) {
      print('Error al remover lista local: $e');
    }
  }
  
  Future<void> _savePendingOperation(String type, Map<String, dynamic> data) async {
    try {
      final pendingOps = await getPendingOperations();
      final operation = {
        'id': 'op_${DateTime.now().millisecondsSinceEpoch}',
        'type': type,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      pendingOps.add(operation);
      await _prefs.setString(_pendingOperationsKey, json.encode(pendingOps));
    } catch (e) {
      print('Error al guardar operación pendiente: $e');
    }
  }
  
  Future<void> _executePendingOperation(Map<String, dynamic> operation) async {
    final type = operation['type'];
    final data = operation['data'];
    
    switch (type) {
      case 'create':
        await _supabaseDataSource.createList(CustomList.fromJson(data));
        break;
      case 'update':
        await _supabaseDataSource.updateList(CustomList.fromJson(data));
        break;
      case 'delete':
        await _supabaseDataSource.deleteList(data['id']);
        break;
      case 'add_movie':
        await _supabaseDataSource.addMovieToList(
          data['listId'],
          data['movieId'],
          position: data['position'],
        );
        break;
      case 'remove_movie':
        await _supabaseDataSource.removeMovieFromList(
          data['listId'],
          data['movieId'],
        );
        break;
      case 'init_defaults':
        await initializeDefaultLists(data['userId']);
        break;
    }
  }
  
  List<DefaultListConfig> _getDefaultListConfigs() {
    return [
      DefaultListConfig(
        id: 'favorites',
        name: 'Favoritas',
        description: 'Mis películas favoritas',
        emoji: '❤️',
        colorHex: '#FF6B6B',
        defaultType: 'favorites',
      ),
      DefaultListConfig(
        id: 'watchlist',
        name: 'Por Ver',
        description: 'Películas que quiero ver',
        emoji: '📺',
        colorHex: '#4ECDC4',
        defaultType: 'watchlist',
      ),
      DefaultListConfig(
        id: 'watched',
        name: 'Vistas',
        description: 'Películas que ya vi',
        emoji: '✅',
        colorHex: '#45B7D1',
        defaultType: 'watched',
      ),
      DefaultListConfig(
        id: 'action',
        name: 'Acción',
        description: 'Películas de acción',
        emoji: '💥',
        colorHex: '#F39C12',
        defaultType: 'genre_action',
      ),
      DefaultListConfig(
        id: 'comedy',
        name: 'Comedia',
        description: 'Películas de comedia',
        emoji: '😂',
        colorHex: '#E74C3C',
        defaultType: 'genre_comedy',
      ),
      DefaultListConfig(
        id: 'drama',
        name: 'Drama',
        description: 'Películas de drama',
        emoji: '🎭',
        colorHex: '#9B59B6',
        defaultType: 'genre_drama',
      ),
      DefaultListConfig(
        id: 'horror',
        name: 'Terror',
        description: 'Películas de terror',
        emoji: '👻',
        colorHex: '#2C3E50',
        defaultType: 'genre_horror',
      ),
      DefaultListConfig(
        id: 'scifi',
        name: 'Ciencia Ficción',
        description: 'Películas de ciencia ficción',
        emoji: '🚀',
        colorHex: '#1ABC9C',
        defaultType: 'genre_scifi',
      ),
    ];
  }
}