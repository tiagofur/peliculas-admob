import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/exceptions/sync_exceptions.dart';
import '../../domain/entities/custom_list.dart';
import '../../domain/entities/sync_models.dart';
import '../../domain/repositories/syncable_repository.dart';
import '../../presentation/providers/auth_provider.dart';
import '../datasources/custom_lists_shared_preferences_datasource.dart';
import '../services/persistent_sync_queue.dart';

// Repositorio híbrido que maneja listas personalizadas localmente y sincroniza con Supabase
class HybridCustomListsRepository
    implements SyncableRepository<SyncableCustomList> {
  HybridCustomListsRepository({
    required CustomListsSharedPreferencesDatasource localDatasource,
    required Ref ref,
  })  : _localDatasource = localDatasource,
        _ref = ref {
    _syncQueue.init();
  }
  final CustomListsSharedPreferencesDatasource _localDatasource;
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;
  final PersistentSyncQueue _syncQueue = PersistentSyncQueue();

  // Métodos auxiliares
  Future<void> _checkOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw NetworkException();
    }
  }

  bool _isAuthenticated() {
    final appState = _ref.read(appStateProvider);
    return appState.isAuthenticated && appState.user != null;
  }

  String? _getCurrentUserId() {
    final appState = _ref.read(appStateProvider);
    return appState.user?.id;
  }

  // Métodos principales de listas personalizadas
  Future<List<CustomList>> getCustomLists() async {
    if (_isAuthenticated()) {
      try {
        await _checkOnline();
        await syncWithSupabase();
      } on SyncException catch (e) {
        print('Error en sincronización automática de listas: $e');
      }
    }

    try {
      return await _localDatasource.getCustomLists();
    } catch (e) {
      throw LocalStorageException(
          'Error al obtener las listas personalizadas: $e');
    }
  }

  Future<List<CustomList>> getDefaultLists() async {
    try {
      return await _localDatasource.getDefaultLists();
    } catch (e) {
      throw LocalStorageException(
          'Error al obtener las listas por defecto: $e');
    }
  }

  Future<void> saveCustomLists(List<CustomList> lists) async {
    try {
      await _localDatasource.saveCustomLists(lists);
    } catch (e) {
      throw LocalStorageException(
          'Error al guardar las listas personalizadas: $e');
    }
  }

  Future<void> saveDefaultLists(List<CustomList> lists) async {
    try {
      await _localDatasource.saveDefaultLists(lists);
    } catch (e) {
      throw LocalStorageException(
          'Error al guardar las listas por defecto: $e');
    }
  }

  Future<void> addCustomList(CustomList list) async {
    try {
      await _localDatasource.addCustomList(list);
    } catch (e) {
      throw LocalStorageException('Error al añadir la lista personalizada: $e');
    }

    try {
      await _checkOnline();
      if (_isAuthenticated()) {
        await _syncSingleList(list, isDeleted: false);
      }
    } on SyncException catch (e) {
      await markForSync('${list.id}_add');
      print('Error sincronizando nueva lista ${list.id}: $e');
    }
  }

  Future<void> updateCustomList(CustomList list) async {
    try {
      await _localDatasource.updateCustomList(list);
    } catch (e) {
      throw LocalStorageException(
          'Error al actualizar la lista personalizada: $e');
    }

    try {
      await _checkOnline();
      if (_isAuthenticated()) {
        await _syncSingleList(list, isDeleted: false);
      }
    } on SyncException catch (e) {
      await markForSync('${list.id}_update');
      print('Error sincronizando actualización de lista ${list.id}: $e');
    }
  }

  Future<void> deleteCustomList(String listId) async {
    try {
      await _localDatasource.deleteCustomList(listId);
    } catch (e) {
      throw LocalStorageException(
          'Error al eliminar la lista personalizada: $e');
    }

    try {
      await _checkOnline();
      if (_isAuthenticated()) {
        await _syncSingleListDeletion(listId);
      }
    } on SyncException catch (e) {
      await markForSync('${listId}_delete');
      print('Error sincronizando eliminación de lista $listId: $e');
    }
  }

  Future<void> clearAllCustomLists() async {
    try {
      await _localDatasource.clearAllCustomLists();
      await _syncQueue.clear();
    } catch (e) {
      throw LocalStorageException(
          'Error al limpiar las listas personalizadas: $e');
    }
  }

  // Sincronizar un elemento individual
  Future<void> _syncSingleList(CustomList list,
      {required bool isDeleted}) async {
    final userId = _getCurrentUserId();
    if (userId == null) return;

    try {
      if (!isDeleted) {
        // Agregar/actualizar lista en Supabase
        await _supabase.from('user_lists').upsert({
          'id': list.id,
          'user_id': userId,
          'name': list.name,
          'description': list.description,
          'color_hex': list.emoji, // Usando emoji como color por ahora
          'is_public': false,
          'created_at': list.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        // Sincronizar elementos de la lista
        await _syncListItems(list);
      }

      // Limpiar marcador de sincronización
      await clearSyncMarker('${list.id}_add');
      await clearSyncMarker('${list.id}_update');
    } on PostgrestException catch (e) {
      throw SupabaseSyncException(e.message, code: e.code);
    } catch (e) {
      throw SupabaseSyncException(e.toString());
    }
  }

  Future<void> _syncSingleListDeletion(String listId) async {
    final userId = _getCurrentUserId();
    if (userId == null) return;

    try {
      // Eliminar elementos de la lista primero
      await _supabase.from('user_list_items').delete().eq('list_id', listId);

      // Eliminar la lista
      await _supabase
          .from('user_lists')
          .delete()
          .eq('id', listId)
          .eq('user_id', userId);

      // Limpiar marcador de sincronización
      await clearSyncMarker('${listId}_delete');
    } on PostgrestException catch (e) {
      throw SupabaseSyncException(e.message, code: e.code);
    } catch (e) {
      throw SupabaseSyncException(e.toString());
    }
  }

  Future<void> _syncListItems(CustomList list) async {
    final userId = _getCurrentUserId();
    if (userId == null) return;

    try {
      // Primero eliminar todos los elementos existentes de esta lista
      await _supabase.from('user_list_items').delete().eq('list_id', list.id);

      // Luego agregar los elementos actuales
      for (int i = 0; i < list.movieIds.length; i++) {
        final movieId = list.movieIds[i];
        await _supabase.from('user_list_items').insert({
          'id': '${list.id}_${movieId}_item',
          'list_id': list.id,
          'movie_id': movieId,
          'movie_title': '', // Se podría obtener del caché local
          'movie_poster_path': null,
          'movie_backdrop_path': null,
          'movie_overview': null,
          'movie_release_date': null,
          'movie_vote_average': null,
          'order_index': i,
          'added_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } on PostgrestException catch (e) {
      throw SupabaseSyncException(e.message, code: e.code);
    } catch (e) {
      throw SupabaseSyncException(e.toString());
    }
  }

  // Implementación de SyncableRepository
  @override
  Future<List<SyncableCustomList>> getLocalData() async {
    try {
      final customLists = await _localDatasource.getCustomLists();
      final userId = _getCurrentUserId();
      if (userId == null) return [];

      return customLists
          .map((list) => SyncableCustomList.fromCustomList(list, userId))
          .toList();
    } catch (e) {
      throw LocalStorageException(
          'Error al obtener los datos locales de listas: $e');
    }
  }

  @override
  Future<List<SyncableCustomList>> getRemoteData() async {
    final userId = _getCurrentUserId();
    if (userId == null) return [];

    try {
      await _checkOnline();
      final response =
          await _supabase.from('user_lists').select().eq('user_id', userId);

      List<SyncableCustomList> remoteLists = [];

      for (final data in response as List) {
        // Obtener elementos de la lista
        final itemsResponse = await _supabase
            .from('user_list_items')
            .select()
            .eq('list_id', data['id'])
            .order('order_index');

        final movieIds = (itemsResponse as List)
            .map((item) => item['movie_id'] as int)
            .toList();

        remoteLists.add(_mapFromSupabase(data, movieIds));
      }

      return remoteLists;
    } on PostgrestException catch (e) {
      throw SupabaseSyncException(e.message, code: e.code);
    } catch (e) {
      throw SupabaseSyncException('Error obteniendo listas remotas: $e');
    }
  }

  @override
  Future<void> markForSync(String itemId) async {
    await _syncQueue.addItem(itemId);
  }

  @override
  Future<bool> hasPendingSync() async {
    return !_syncQueue.isEmpty;
  }

  @override
  Future<List<String>> getPendingSyncItems() async {
    return _syncQueue.getItems();
  }

  @override
  Future<void> clearSyncMarker(String itemId) async {
    await _syncQueue.removeItem(itemId);
  }

  // Implementación de métodos abstractos faltantes
  @override
  Future<void> syncWithSupabase() async {
    if (!_isAuthenticated()) return;

    try {
      await _checkOnline();

      final localData = await getLocalData();
      final remoteData = await getRemoteData();

      await resolveConflicts(localData, remoteData);
    } catch (e) {
      throw SyncException('Error en sincronización: $e');
    }
  }

  @override
  Future<void> upload(List<SyncableCustomList> items) async {
    if (!_isAuthenticated()) return;

    try {
      await _checkOnline();

      for (final item in items) {
        await _syncSingleList(item.toCustomList(), isDeleted: false);
      }
    } catch (e) {
      throw SyncException('Error subiendo listas: $e');
    }
  }

  @override
  Future<void> download(List<SyncableCustomList> items) async {
    if (!_isAuthenticated()) return;

    try {
      final customLists = items.map((item) => item.toCustomList()).toList();
      await saveCustomLists(customLists);
    } catch (e) {
      throw SyncException('Error descargando listas: $e');
    }
  }

  @override
  Future<void> resolveConflicts(
      List<SyncableCustomList> local, List<SyncableCustomList> remote) async {
    // Resolver conflictos comparando timestamps
    for (final remoteItem in remote) {
      final localItem = local.firstWhere(
        (item) => item.id == remoteItem.id,
        orElse: () => throw Exception('Item not found'),
      );

      try {
        if (localItem.updatedAt.isAfter(remoteItem.updatedAt)) {
          // Local es más reciente, subir cambios
          await upload([localItem]);
        } else if (remoteItem.updatedAt.isAfter(localItem.updatedAt)) {
          // Remoto es más reciente, descargar cambios
          await download([remoteItem]);
        }
        // Si son iguales, no hacer nada
      } catch (e) {
        // Si no se encuentra localmente, descargar el remoto
        await download([remoteItem]);
      }
    }

    // Subir elementos que solo existen localmente
    for (final localItem in local) {
      final existsInRemote = remote.any((item) => item.id == localItem.id);
      if (!existsInRemote) {
        await upload([localItem]);
      }
    }
  }

  // Método auxiliar que faltaba
  SyncableCustomList _mapFromSupabase(
      Map<String, dynamic> data, List<int> movieIds) {
    return SyncableCustomList(
      id: data['id'] as String,
      userId: data['user_id'] as String,
      name: data['name'] as String,
      description: data['description'] as String? ?? '',
      emoji: data['color_hex'] as String? ?? '📝',
      color: data['color_hex'] as String? ?? 'blue',
      movieIds: movieIds,
      isPublic: data['is_public'] as bool? ?? false,
      createdAt: DateTime.parse(data['created_at'] as String),
      updatedAt: DateTime.parse(data['updated_at'] as String),
    );
  }
}
