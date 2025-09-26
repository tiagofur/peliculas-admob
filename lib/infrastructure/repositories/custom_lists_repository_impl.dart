import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logging/app_logger.dart';
import '../../domain/entities/custom_list.dart';
import '../../domain/entities/list_item.dart';
import '../../domain/repositories/i_custom_lists_repository.dart';
import '../datasources/supabase_custom_lists_datasource.dart';

/// Implementación del repositorio de listas personalizadas
/// Maneja sincronización real-time, operaciones offline y resolución de conflictos
class CustomListsRepositoryImpl implements ICustomListsRepository {
  CustomListsRepositoryImpl(
    this._supabaseDataSource,
    this._prefs,
    this._connectivity,
  );
  final SupabaseCustomListsDataSource _supabaseDataSource;
  final SharedPreferences _prefs;
  final Connectivity _connectivity;

  // Claves para SharedPreferences
  static const String _localListsKey = 'local_custom_lists';
  static const String _pendingOperationsKey = 'pending_operations';
  static const String _lastSyncKey = 'last_sync_timestamp';

  // ========== OPERACIONES DE LISTAS ==========

  @override
  Future<List<CustomList>> getUserLists() async {
    try {
      // Validar que el usuario esté autenticado
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        AppLogger.repo(
            'CustomLists', 'Usuario no autenticado para obtener listas');
        throw Exception('Usuario no autenticado. Por favor, inicia sesión.');
      }

      // Validar que el userId del usuario sea válido
      if (currentUser.id.isEmpty) {
        AppLogger.repo('CustomLists', 'ID de usuario vacío o inválido');
        throw Exception(
            'ID de usuario inválido. Por favor, reinicia la aplicación.');
      }

      if (await hasInternetConnection()) {
        AppLogger.repo('CustomLists',
            'Obteniendo listas desde Supabase para usuario: ${currentUser.id}');
        final lists = await _supabaseDataSource.getUserLists(currentUser.id);
        await _saveListsLocally(lists);
        AppLogger.repo('CustomLists',
            '📥 ${lists.length} listas obtenidas desde Supabase');
        return lists;
      } else {
        AppLogger.repo(
            'CustomLists', '📱 Sin conexión, obteniendo listas locales');
        final localLists = await getLocalLists();
        AppLogger.repo('CustomLists',
            '📱 ${localLists.length} listas locales encontradas');
        return localLists;
      }
    } catch (e) {
      AppLogger.repo(
          'CustomLists', '❌ Error obteniendo listas, usando locales: $e');
      // En caso de error, intentar obtener datos locales
      final localLists = await getLocalLists();
      AppLogger.repo(
          'CustomLists', '📱 ${localLists.length} listas locales de respaldo');
      return localLists;
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
      // Validar que el usuario esté autenticado con validaciones más robustas
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        AppLogger.repo(
            'CustomLists', '❌ Usuario no autenticado - currentUser es null');
        throw Exception('Usuario no autenticado. Por favor, inicia sesión.');
      }

      // Validar que el userId del usuario sea válido con múltiples verificaciones
      final userId = currentUser.id;
      if (userId.isEmpty || userId.trim().isEmpty) {
        AppLogger.repo(
            'CustomLists', '❌ ID de usuario inválido - userId: "$userId"');
        AppLogger.repo(
            'CustomLists', '❌ Verificando estado de autenticación...');

        // Intentar refrescar la sesión si el userId es inválido
        try {
          final session = Supabase.instance.client.auth.currentSession;
          if (session == null) {
            AppLogger.repo('CustomLists', '❌ No hay sesión activa');
            throw Exception(
                'Sesión expirada. Por favor, inicia sesión nuevamente.');
          }

          final refreshedUser = session.user;
          if (refreshedUser.id.isEmpty) {
            AppLogger.repo('CustomLists', '❌ Usuario de sesión inválido');
            throw Exception(
                'Sesión inválida. Por favor, inicia sesión nuevamente.');
          }

          AppLogger.repo('CustomLists',
              '✅ Sesión refrescada, userId válido: ${refreshedUser.id}');
          // Usar el userId de la sesión refrescada
        } catch (refreshError) {
          AppLogger.repo(
              'CustomLists', '❌ Error refrescando sesión: $refreshError');
          throw Exception(
              'Error de autenticación. Por favor, inicia sesión nuevamente.');
        }

        throw Exception(
            'ID de usuario inválido. Por favor, reinicia la aplicación.');
      }

      AppLogger.repo('CustomLists',
          '🟡 Creando lista "${list.name}" para usuario $userId');
      AppLogger.repo('CustomLists', '🔐 Email del usuario: $currentUser.email');

      // Asegurar que la lista tenga el userId correcto
      final listWithUserId = list.copyWith(userId: userId);

      AppLogger.repo(
          'CustomLists', '🌐 Conexión disponible, guardando en Supabase');
      final createdList = await _supabaseDataSource.createList(listWithUserId);
      await _updateLocalList(createdList);
      AppLogger.repo('CustomLists',
          '✅ Lista creada exitosamente en Supabase y guardada localmente');
      return createdList;
    } catch (e) {
      AppLogger.repo('CustomLists', '❌ Error al crear lista: $e');
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
    AppLogger.repo('CustomLists',
        'ℹ️ Solicitud de listas por defecto ignorada: característica deshabilitada');
    return [];
  }

  @override
  Future<void> initializeDefaultLists(String userId) async {
    AppLogger.repo('CustomLists',
        'ℹ️ Inicialización de listas por defecto omitida para el usuario $userId');
  }

  // ========== OPERACIONES DE ELEMENTOS ==========

  @override
  Future<List<ListItem>> getListItems(String listId) async {
    try {
      // Validar que el usuario esté autenticado
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        AppLogger.repo('CustomLists',
            '❌ Usuario no autenticado para obtener elementos de lista');
        return [];
      }

      // Validar que el userId del usuario sea válido
      final userId = currentUser.id;
      if (userId.isEmpty) {
        AppLogger.repo('CustomLists',
            '❌ ID de usuario vacío o inválido para obtener elementos de lista');
        return [];
      }

      if (await hasInternetConnection()) {
        return await _supabaseDataSource.getListItems(listId);
      } else {
        // Obtener elementos locales (simplificado para este ejemplo)
        return [];
      }
    } catch (e) {
      AppLogger.repo(
          'CustomLists', '❌ Error al obtener elementos de la lista: $e');
      return [];
    }
  }

  @override
  Future<ListItem> addMovieToList(String listId, int movieId,
      {int? position}) async {
    try {
      // Validar que el usuario esté autenticado
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        AppLogger.repo(
            'CustomLists', '❌ Usuario no autenticado para añadir película');
        throw Exception('Usuario no autenticado');
      }

      // Validar que el userId del usuario sea válido
      final userId = currentUser.id;
      if (userId.isEmpty) {
        AppLogger.repo('CustomLists',
            '❌ ID de usuario vacío o inválido para añadir película');
        throw Exception('ID de usuario inválido');
      }

      if (await hasInternetConnection()) {
        return await _supabaseDataSource.addMovieToList(listId, movieId,
            position: position);
      } else {
        // Crear elemento temporal
        final tempItem = ListItem(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          listId: listId,
          movieId: movieId,
          movieTitle: '', // Se actualizará desde TMDB
          position: position ?? 0,
          addedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _savePendingOperation('add_movie', {
          'listId': listId,
          'movieId': movieId,
          'position': position,
        });

        return tempItem;
      }
    } catch (e) {
      AppLogger.repo('CustomLists', '❌ Error al añadir película a lista: $e');
      throw Exception('Error al agregar película a la lista: $e');
    }
  }

  @override
  Future<void> removeMovieFromList(String listId, int movieId) async {
    try {
      // Validar que el usuario esté autenticado
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        AppLogger.repo(
            'CustomLists', '❌ Usuario no autenticado para remover película');
        throw Exception('Usuario no autenticado');
      }

      // Validar que el userId del usuario sea válido
      final userId = currentUser.id;
      if (userId.isEmpty) {
        AppLogger.repo('CustomLists',
            '❌ ID de usuario vacío o inválido para remover película');
        throw Exception('ID de usuario inválido');
      }

      if (await hasInternetConnection()) {
        await _supabaseDataSource.removeMovieFromList(listId, movieId);
      } else {
        await _savePendingOperation('remove_movie', {
          'listId': listId,
          'movieId': movieId,
        });
      }
    } catch (e) {
      AppLogger.repo('CustomLists', '❌ Error al remover película de lista: $e');
      throw Exception('Error al remover película de la lista: $e');
    }
  }

  @override
  Future<void> reorderListItems(String listId, List<ListItem> items) async {
    try {
      // Validar que el usuario esté autenticado
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        AppLogger.repo(
            'CustomLists', '❌ Usuario no autenticado para reordenar elementos');
        throw Exception('Usuario no autenticado');
      }

      // Validar que el userId del usuario sea válido
      final userId = currentUser.id;
      if (userId.isEmpty) {
        AppLogger.repo('CustomLists',
            '❌ ID de usuario vacío o inválido para reordenar elementos');
        throw Exception('ID de usuario inválido');
      }

      if (await hasInternetConnection()) {
        await _supabaseDataSource.reorderListItems(listId, items);
      } else {
        await _savePendingOperation('reorder_items', {
          'listId': listId,
          'items': items.map((item) => item.toJson()).toList(),
        });
      }
    } catch (e) {
      AppLogger.repo('CustomLists', '❌ Error al reordenar elementos: $e');
      throw Exception('Error al reordenar elementos: $e');
    }
  }

  @override
  Future<bool> isMovieInList(String listId, int movieId) async {
    try {
      // Validar que el usuario esté autenticado
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        AppLogger.repo('CustomLists',
            '❌ Usuario no autenticado para verificar película en lista');
        return false;
      }

      // Validar que el userId del usuario sea válido
      final userId = currentUser.id;
      if (userId.isEmpty) {
        AppLogger.repo('CustomLists',
            '❌ ID de usuario vacío o inválido para verificar película en lista');
        return false;
      }

      if (await hasInternetConnection()) {
        return await _supabaseDataSource.isMovieInList(listId, movieId);
      } else {
        // Verificación local simplificada
        return false;
      }
    } catch (e) {
      AppLogger.repo(
          'CustomLists', '❌ Error al verificar película en lista: $e');
      return false;
    }
  }

  // ========== SINCRONIZACIÓN ==========

  @override
  Stream<List<CustomList>> watchUserLists() {
    try {
      // Validar que el usuario esté autenticado
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        AppLogger.repo(
            'CustomLists', '❌ Usuario no autenticado para observar listas');
        return Stream.value([]);
      }

      // Validar que el userId del usuario sea válido
      final userId = currentUser.id;
      if (userId.isEmpty) {
        AppLogger.repo('CustomLists',
            '❌ ID de usuario vacío o inválido para observar listas');
        return Stream.value([]);
      }

      return _supabaseDataSource.watchUserLists(userId);
    } catch (e) {
      AppLogger.repo('CustomLists', '❌ Error al observar listas: $e');
      return Stream.value([]);
    }
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
          // Error al sincronizar operación $op['id']: $e
        }
      }

      // Actualizar timestamp de última sincronización
      await _prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      throw Exception('Error durante la sincronización: $e');
    }
  }

  @override
  Future<CustomList> resolveConflict(
      CustomList localList, CustomList remoteList) async {
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
      final updatedOps =
          pendingOps.where((op) => op['id'] != operationId).toList();
      await _prefs.setString(_pendingOperationsKey, json.encode(updatedOps));
    } catch (e) {
      // Error al marcar operación como sincronizada: $e
    }
  }

  // ========== UTILIDADES ==========

  @override
  Future<bool> hasInternetConnection() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      return !connectivityResults.contains(ConnectivityResult.none);
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

  Future<void> _saveListsLocally(List<CustomList> lists) async {
    try {
      final listsJson =
          json.encode(lists.map((list) => list.toJson()).toList());
      await _prefs.setString(_localListsKey, listsJson);
      AppLogger.repo(
          'CustomLists', '💾 ${lists.length} listas guardadas localmente');
    } catch (e) {
      AppLogger.repo('CustomLists', '❌ Error al guardar listas localmente: $e');
    }
  }

  Future<void> _updateLocalList(CustomList list) async {
    try {
      final localLists = await getLocalLists();
      final existingIndex = localLists.indexWhere((l) => l.id == list.id);

      if (existingIndex != -1) {
        localLists[existingIndex] = list;
        AppLogger.repo(
            'CustomLists', '🔄 Lista actualizada localmente: ${list.name}');
      } else {
        localLists.add(list);
        AppLogger.repo(
            'CustomLists', '➕ Lista agregada localmente: ${list.name}');
      }

      await _saveListsLocally(localLists);
    } catch (e) {
      AppLogger.repo('CustomLists', '❌ Error al actualizar lista local: $e');
    }
  }

  Future<void> _removeLocalList(String listId) async {
    try {
      final localLists = await getLocalLists();
      localLists.removeWhere((list) => list.id == listId);
      await _saveListsLocally(localLists);
    } catch (e) {
      // Error al remover lista local: $e
    }
  }

  Future<void> _savePendingOperation(
      String type, Map<String, dynamic> data) async {
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
      // Error al guardar operación pendiente: $e
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
}
