import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../core/sync/trigger_free_custom_lists_sync.dart';
import '../../../domain/entities/custom_list.dart';
import '../../../services/list_sync_service.dart';
import '../custom_lists_providers.dart';
// OfflineChange está definido en list_sync_service.dart

/// Estado para listas con sus películas
class CustomListsState {
  const CustomListsState({
    this.lists = const {},
    this.listItems = const {},
  });

  final Map<String, CustomList> lists; // listId -> CustomList
  final Map<String, List<int>> listItems; // listId -> List<movieId>

  CustomListsState copyWith({
    Map<String, CustomList>? lists,
    Map<String, List<int>>? listItems,
  }) {
    return CustomListsState(
      lists: lists ?? this.lists,
      listItems: listItems ?? this.listItems,
    );
  }

  /// Obtiene una lista con sus películas incluidas
  CustomList? getListWithMovies(String listId) {
    final list = lists[listId];
    if (list == null) return null;

    final movieIds = listItems[listId] ?? [];
    return list.copyWith(movieIds: movieIds);
  }

  /// Obtiene todas las listas con sus películas incluidas
  List<CustomList> getAllListsWithMovies() {
    return lists.keys.map((listId) {
      final list = lists[listId]!;
      final movieIds = listItems[listId] ?? [];
      return list.copyWith(movieIds: movieIds);
    }).toList();
  }
}

/// Provider directo que evita completamente el repositorio híbrido
/// y solo usa TriggerFreeCustomListsSync para operaciones de Supabase
final directCustomListsProvider =
    StateNotifierProvider<DirectCustomListsNotifier, CustomListsState>((ref) {
  // Note: listSyncServiceProvider is a FutureProvider, but we'll handle it in the notifier
  return DirectCustomListsNotifier(
    ref: ref,
    onListCreated: (CustomList list) {
      // Opcional: trackear creación de lista para achievements
      // ref.read(achievementsProvider.notifier).trackListCreated();
    },
  );
});

class DirectCustomListsNotifier extends StateNotifier<CustomListsState> {
  DirectCustomListsNotifier({
    required this.ref,
    required this.onListCreated,
  }) : super(const CustomListsState()) {
    _loadListsFromSupabase();
    _setupRealtimeListeners();
    _initializeSync();
  }

  final Ref ref;
  final Function(CustomList list) onListCreated;
  ListSyncService? _syncService;
  final TriggerFreeCustomListsSync _sync = TriggerFreeCustomListsSync.instance;
  RealtimeChannel? _listsChannel;
  RealtimeChannel? _listItemsChannel;
  String? _currentUserId;

  /// Cargar listas directamente desde Supabase
  Future<void> _loadListsFromSupabase() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        state = const CustomListsState();
        _currentUserId = null;
        return;
      }

      _currentUserId = currentUser.id;

      LoggerFactory.info(
          'DirectCustomLists: Cargando listas directas desde Supabase...');

      final customLists = await _sync.getUserLists(currentUser.id);

      final listsMap = <String, CustomList>{};
      final listItemsMap = <String, List<int>>{};

      // Cargar cada lista y sus items
      for (final list in customLists) {
        listsMap[list.id] = list;
        final movieIds = await _sync.getListItems(currentUser.id, list.id);
        listItemsMap[list.id] = movieIds;
      }

      state = CustomListsState(
        lists: listsMap,
        listItems: listItemsMap,
      );

      LoggerFactory.info(
          'DirectCustomLists: Cargadas ${customLists.length} listas directas');
      LoggerFactory.debug('DirectCustomLists: IDs: ${listsMap.keys.toList()}');
    } catch (e) {
      LoggerFactory.error('DirectCustomLists: Error cargando: $e');
      state = const CustomListsState();
    }
  }

  /// Inicializar sincronización con ListSyncService
  void _initializeSync() async {
    try {
      _syncService = await ref.read(listSyncServiceProvider.future);

      // Escuchar cambios de estado de sincronización
      _syncService!.syncStatusStream.listen((status) {
        LoggerFactory.info('DirectCustomLists - Sync status: $status');
      });

      // Escuchar conflictos
      _syncService!.conflictsStream.listen((conflicts) {
        LoggerFactory.info(
            'DirectCustomLists - Conflicts detected: ${conflicts.length}');
        // Aquí podrías mostrar una notificación al usuario sobre conflictos
      });

      // Iniciar auto-sync si está habilitado
      _syncService!.startAutoSync();
    } catch (e) {
      LoggerFactory.error(
          'DirectCustomLists: Error initializing sync service: $e');
    }
  }

  /// Crear nueva lista
  Future<void> createList({
    required String name,
    String description = '',
    required String emoji,
    String color = 'blue',
  }) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      LoggerFactory.info('DirectCustomLists: No hay usuario logueado');
      return;
    }

    const uuid = Uuid();
    final listId = uuid.v4();
    final now = DateTime.now();

    final newList = CustomList(
      id: listId,
      name: name,
      description: description,
      emoji: emoji,
      movieIds: [],
      createdAt: now,
      lastModifiedAt: now,
      isDefault: false,
      color: color,
    );

    LoggerFactory.info(
        '🚀 [CREAR LISTA] Iniciando creación: ${newList.name} para user ${currentUser.id}');

    // Actualización optimista de la UI
    final updatedLists = Map<String, CustomList>.from(state.lists);
    final updatedItems = Map<String, List<int>>.from(state.listItems);
    updatedLists[listId] = newList;
    updatedItems[listId] = [];

    state = state.copyWith(
      lists: updatedLists,
      listItems: updatedItems,
    );

    try {
      LoggerFactory.info(
          '🔄 [CREAR LISTA] Llamando a TriggerFreeCustomListsSync...');
      final createdList = await _sync.createList(currentUser.id, newList);
      if (createdList != null) {
        LoggerFactory.info(
            '✅ [CREAR LISTA] Lista creada exitosamente en Supabase: ${newList.name}');
        onListCreated(createdList);
      } else {
        LoggerFactory.error(
            '❌ [CREAR LISTA] TriggerFreeCustomListsSync retornó null');
      }
    } catch (e) {
      LoggerFactory.error(
          '❌ [CREAR LISTA] Error en TriggerFreeCustomListsSync: $e');

      // Registrar cambio offline para sincronización posterior
      await _syncService?.recordOfflineChange(OfflineChange(
        id: 'create_list_${listId}_${DateTime.now().millisecondsSinceEpoch}',
        type: OfflineChangeType.createList,
        data: newList.toJson(),
        timestamp: DateTime.now(),
      ));

      // Revertir cambio optimista en caso de error
      final revertedLists = Map<String, CustomList>.from(state.lists);
      final revertedItems = Map<String, List<int>>.from(state.listItems);
      revertedLists.remove(listId);
      revertedItems.remove(listId);

      state = state.copyWith(
        lists: revertedLists,
        listItems: revertedItems,
      );

      rethrow;
    }
  }

  /// Actualizar lista existente
  Future<void> updateList(
    String listId, {
    String? name,
    String? description,
    String? emoji,
    String? color,
  }) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final currentList = state.lists[listId];
    if (currentList == null) return;

    LoggerFactory.debug(
        'DirectCustomLists: Actualizando lista ${currentList.name}');

    // Actualización optimista de la UI
    final updatedList = currentList.copyWith(
      name: name,
      description: description,
      emoji: emoji,
      color: color,
      lastModifiedAt: DateTime.now(),
    );

    final updatedLists = Map<String, CustomList>.from(state.lists);
    updatedLists[listId] = updatedList;

    state = state.copyWith(lists: updatedLists);

    try {
      await _sync.updateList(currentUser.id, updatedList);
      LoggerFactory.info(
          'DirectCustomLists: Lista actualizada: ${updatedList.name}');
    } catch (e) {
      LoggerFactory.error('DirectCustomLists: Error actualizando lista: $e');

      // Registrar cambio offline para sincronización posterior
      await _syncService?.recordOfflineChange(OfflineChange(
        id: 'update_list_${listId}_${DateTime.now().millisecondsSinceEpoch}',
        type: OfflineChangeType.updateList,
        data: updatedList.toJson(),
        timestamp: DateTime.now(),
      ));

      // Revertir cambio optimista en caso de error
      final revertedLists = Map<String, CustomList>.from(state.lists);
      revertedLists[listId] = currentList;
      state = state.copyWith(lists: revertedLists);

      rethrow;
    }
  }

  /// Eliminar lista
  Future<void> deleteList(String listId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final currentList = state.lists[listId];
    if (currentList == null) return;

    LoggerFactory.debug(
        'DirectCustomLists: Eliminando lista ${currentList.name}');

    // Actualización optimista de la UI
    final updatedLists = Map<String, CustomList>.from(state.lists);
    final updatedItems = Map<String, List<int>>.from(state.listItems);
    final removedList = updatedLists.remove(listId);
    final removedItems = updatedItems.remove(listId);

    state = state.copyWith(
      lists: updatedLists,
      listItems: updatedItems,
    );

    try {
      await _sync.deleteList(currentUser.id, listId);
      LoggerFactory.info(
          'DirectCustomLists: Lista eliminada: ${currentList.name}');
    } catch (e) {
      LoggerFactory.error('DirectCustomLists: Error eliminando lista: $e');

      // Registrar cambio offline para sincronización posterior
      await _syncService?.recordOfflineChange(OfflineChange(
        id: 'delete_list_${listId}_${DateTime.now().millisecondsSinceEpoch}',
        type: OfflineChangeType.deleteList,
        data: {'id': listId},
        timestamp: DateTime.now(),
      ));

      // Revertir cambio optimista en caso de error
      if (removedList != null) {
        final revertedLists = Map<String, CustomList>.from(state.lists);
        final revertedItems = Map<String, List<int>>.from(state.listItems);
        revertedLists[listId] = removedList;
        if (removedItems != null) {
          revertedItems[listId] = removedItems;
        }
        state = state.copyWith(
          lists: revertedLists,
          listItems: revertedItems,
        );
      }

      rethrow;
    }
  }

  /// Añadir película a lista
  Future<void> addMovieToList(String listId, int movieId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final currentItems = state.listItems[listId] ?? [];
    if (currentItems.contains(movieId)) return; // Ya está en la lista

    LoggerFactory.debug(
        'DirectCustomLists: Agregando película $movieId a lista $listId');

    // Actualización optimista de la UI
    final updatedItems = Map<String, List<int>>.from(state.listItems);
    updatedItems[listId] = [...currentItems, movieId];

    state = state.copyWith(listItems: updatedItems);

    try {
      await _sync.addMovieToList(currentUser.id, listId, movieId);
      LoggerFactory.info('DirectCustomLists: Película agregada a lista');
    } catch (e) {
      LoggerFactory.error(
          'DirectCustomLists: Error agregando película a lista: $e');

      // Registrar cambio offline para sincronización posterior
      await _syncService?.recordOfflineChange(OfflineChange(
        id: 'add_movie_${listId}_${movieId}_${DateTime.now().millisecondsSinceEpoch}',
        type: OfflineChangeType.addMovie,
        data: {
          'listId': listId,
          'movieId': movieId,
        },
        timestamp: DateTime.now(),
      ));

      // Revertir cambio optimista en caso de error
      final revertedItems = Map<String, List<int>>.from(state.listItems);
      revertedItems[listId] = currentItems;
      state = state.copyWith(listItems: revertedItems);

      rethrow;
    }
  }

  /// Remover película de lista
  Future<void> removeMovieFromList(String listId, int movieId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final currentItems = state.listItems[listId] ?? [];
    if (!currentItems.contains(movieId)) return; // No está en la lista

    LoggerFactory.debug(
        'DirectCustomLists: Removiendo película $movieId de lista $listId');

    // Actualización optimista de la UI
    final updatedItems = Map<String, List<int>>.from(state.listItems);
    updatedItems[listId] = currentItems.where((id) => id != movieId).toList();

    state = state.copyWith(listItems: updatedItems);

    try {
      await _sync.removeMovieFromList(currentUser.id, listId, movieId);
      LoggerFactory.info('DirectCustomLists: Película removida de lista');
    } catch (e) {
      LoggerFactory.error(
          'DirectCustomLists: Error removiendo película de lista: $e');

      // Registrar cambio offline para sincronización posterior
      await _syncService?.recordOfflineChange(OfflineChange(
        id: 'remove_movie_${listId}_${movieId}_${DateTime.now().millisecondsSinceEpoch}',
        type: OfflineChangeType.removeMovie,
        data: {
          'listId': listId,
          'movieId': movieId,
        },
        timestamp: DateTime.now(),
      ));

      // Revertir cambio optimista en caso de error
      final revertedItems = Map<String, List<int>>.from(state.listItems);
      revertedItems[listId] = currentItems;
      state = state.copyWith(listItems: revertedItems);

      rethrow;
    }
  }

  /// Alternar película en lista (añadir si no está, remover si está)
  Future<void> toggleMovieInList(String listId, int movieId) async {
    final currentItems = state.listItems[listId] ?? [];
    if (currentItems.contains(movieId)) {
      await removeMovieFromList(listId, movieId);
    } else {
      await addMovieToList(listId, movieId);
    }
  }

  /// Configurar listeners de tiempo real
  void _setupRealtimeListeners() {
    try {
      LoggerFactory.info(
          '📡 [REAL-TIME CUSTOM LISTS] Configurando listeners de tiempo real...');

      // Listener para cambios en listas
      _listsChannel = Supabase.instance.client
          .channel(
              'custom_lists_realtime_${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'user_lists',
            callback: _handleListsRealtimeEvent,
            filter: _currentUserId != null
                ? PostgresChangeFilter(
                    type: PostgresChangeFilterType.eq,
                    column: 'user_id',
                    value: _currentUserId)
                : null,
          )
          .subscribe();

      // Listener para cambios en items de listas
      _listItemsChannel = Supabase.instance.client
          .channel(
              'list_items_realtime_${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'user_list_items',
            callback: _handleListItemsRealtimeEvent,
          )
          .subscribe();

      LoggerFactory.info(
          '✅ DirectCustomLists: Listeners de tiempo real configurados');
    } catch (e) {
      LoggerFactory.error(
          '❌ DirectCustomLists: Error configurando listeners: $e');
    }
  }

  /// Maneja eventos de tiempo real para listas
  void _handleListsRealtimeEvent(PostgresChangePayload payload) {
    try {
      LoggerFactory.info(
          '🔴 DirectCustomLists: Evento en listas: ${payload.eventType}');
      LoggerFactory.debug(
          '🔴 DirectCustomLists: Payload: ${payload.newRecord}');

      final newRecord = payload.newRecord;
      final oldRecord = payload.oldRecord;

      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
          _handleListInsert(newRecord);
          break;
        case PostgresChangeEvent.update:
          _handleListUpdate(newRecord, oldRecord);
          break;
        case PostgresChangeEvent.delete:
          _handleListDelete(oldRecord);
          break;
        case PostgresChangeEvent.all:
          break;
      }
    } catch (e) {
      LoggerFactory.error(
          '❌ DirectCustomLists: Error manejando evento de listas: $e');
    }
  }

  /// Maneja eventos de tiempo real para items de listas
  void _handleListItemsRealtimeEvent(PostgresChangePayload payload) {
    try {
      LoggerFactory.info(
          '🔴 DirectCustomLists: Evento en items: ${payload.eventType}');

      final newRecord = payload.newRecord;
      final oldRecord = payload.oldRecord;

      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
          _handleItemInsert(newRecord);
          break;
        case PostgresChangeEvent.update:
          _handleItemUpdate(newRecord, oldRecord);
          break;
        case PostgresChangeEvent.delete:
          _handleItemDelete(oldRecord);
          break;
        case PostgresChangeEvent.all:
          break;
      }
    } catch (e) {
      LoggerFactory.error(
          '❌ DirectCustomLists: Error manejando evento de items: $e');
    }
  }

  void _handleListInsert(Map<String, dynamic> record) {
    if (record['user_id'] != _currentUserId) return;
    if (record['is_deleted'] ?? false) return;

    final listId = record['id'] as String;
    final customList = _recordToCustomList(record);

    LoggerFactory.info(
        '➕ DirectCustomLists: Insertando lista ${customList.name}');

    final updatedLists = Map<String, CustomList>.from(state.lists);
    final updatedItems = Map<String, List<int>>.from(state.listItems);

    updatedLists[listId] = customList;
    if (!updatedItems.containsKey(listId)) {
      updatedItems[listId] = [];
    }

    state = state.copyWith(lists: updatedLists, listItems: updatedItems);
  }

  void _handleListUpdate(
      Map<String, dynamic> newRecord, Map<String, dynamic> oldRecord) {
    if (newRecord['user_id'] != _currentUserId) return;

    final listId = newRecord['id'] as String;

    if (newRecord['is_deleted'] ?? false) {
      LoggerFactory.info(
          '🗑️ DirectCustomLists: Lista eliminada ${newRecord['name']}');
      final updatedLists = Map<String, CustomList>.from(state.lists);
      final updatedItems = Map<String, List<int>>.from(state.listItems);
      updatedLists.remove(listId);
      updatedItems.remove(listId);
      state = state.copyWith(lists: updatedLists, listItems: updatedItems);
    } else {
      final customList = _recordToCustomList(newRecord);
      LoggerFactory.info(
          '🔄 DirectCustomLists: Actualizando lista ${customList.name}');
      final updatedLists = Map<String, CustomList>.from(state.lists);
      updatedLists[listId] = customList;
      state = state.copyWith(lists: updatedLists);
    }
  }

  void _handleListDelete(Map<String, dynamic> record) {
    if (record['user_id'] != _currentUserId) return;

    final listId = record['id'] as String;
    LoggerFactory.info(
        '🗑️ DirectCustomLists: Eliminando lista ${record['name']}');

    final updatedLists = Map<String, CustomList>.from(state.lists);
    final updatedItems = Map<String, List<int>>.from(state.listItems);
    updatedLists.remove(listId);
    updatedItems.remove(listId);
    state = state.copyWith(lists: updatedLists, listItems: updatedItems);
  }

  void _handleItemInsert(Map<String, dynamic> record) {
    if (record['is_deleted'] ?? false) return;

    final listId = record['list_id'] as String;
    final movieId = record['movie_id'] as int;

    // Solo procesar si tenemos esta lista
    if (!state.lists.containsKey(listId)) return;

    LoggerFactory.info(
        '➕ DirectCustomLists: Agregando película $movieId a lista $listId');

    final updatedItems = Map<String, List<int>>.from(state.listItems);
    final currentItems = updatedItems[listId] ?? [];

    if (!currentItems.contains(movieId)) {
      updatedItems[listId] = [...currentItems, movieId];
      state = state.copyWith(listItems: updatedItems);
    }
  }

  void _handleItemUpdate(
      Map<String, dynamic> newRecord, Map<String, dynamic> oldRecord) {
    final listId = newRecord['list_id'] as String;
    final movieId = newRecord['movie_id'] as int;

    // Solo procesar si tenemos esta lista
    if (!state.lists.containsKey(listId)) return;

    if (newRecord['is_deleted'] ?? false) {
      LoggerFactory.info(
          '🗑️ DirectCustomLists: Item eliminado $movieId de lista $listId');
      final updatedItems = Map<String, List<int>>.from(state.listItems);
      final currentItems = updatedItems[listId] ?? [];
      updatedItems[listId] = currentItems.where((id) => id != movieId).toList();
      state = state.copyWith(listItems: updatedItems);
    }
  }

  void _handleItemDelete(Map<String, dynamic> record) {
    final listId = record['list_id'] as String;
    final movieId = record['movie_id'] as int;

    // Solo procesar si tenemos esta lista
    if (!state.lists.containsKey(listId)) return;

    LoggerFactory.info(
        '🗑️ DirectCustomLists: Eliminando item $movieId de lista $listId');

    final updatedItems = Map<String, List<int>>.from(state.listItems);
    final currentItems = updatedItems[listId] ?? [];
    updatedItems[listId] = currentItems.where((id) => id != movieId).toList();
    state = state.copyWith(listItems: updatedItems);
  }

  /// Convierte un record de Supabase a CustomList
  CustomList _recordToCustomList(Map<String, dynamic> record) {
    return CustomList(
      id: record['id'] as String,
      name: record['name'] as String,
      description: record['description'] as String? ?? '',
      emoji: record['emoji'] as String? ?? '📝',
      color: record['color'] as String? ?? 'blue',
      movieIds: [], // Se cargan por separado
      createdAt: DateTime.parse(record['created_at'] as String),
      lastModifiedAt: DateTime.parse(record['last_modified_at'] as String? ??
          record['created_at'] as String),
      isDefault: record['is_default'] as bool? ?? false,
    );
  }

  /// Habilita el provider después del login
  void enableAfterLogin() {
    LoggerFactory.info(
        '🔐 DirectCustomLists: Habilitando después del login...');
    _loadListsFromSupabase();
    _setupRealtimeListeners();
  }

  /// Verifica si una película está en una lista específica
  bool isMovieInList(String listId, int movieId) {
    final items = state.listItems[listId] ?? [];
    return items.contains(movieId);
  }

  /// Obtiene todas las listas que contienen una película específica
  List<CustomList> getListsContainingMovie(int movieId) {
    final result = <CustomList>[];

    for (final entry in state.listItems.entries) {
      final listId = entry.key;
      final movieIds = entry.value;

      if (movieIds.contains(movieId)) {
        final list = state.lists[listId];
        if (list != null) {
          result.add(list.copyWith(movieIds: movieIds));
        }
      }
    }

    return result;
  }

  /// Obtiene una lista específica con sus películas
  CustomList? getListWithMovies(String listId) {
    return state.getListWithMovies(listId);
  }

  /// Obtiene todas las listas con sus películas
  List<CustomList> get allListsWithMovies => state.getAllListsWithMovies();

  @override
  void dispose() {
    LoggerFactory.info('🗑️ DirectCustomLists: Cerrando listeners...');
    _listsChannel?.unsubscribe();
    _listItemsChannel?.unsubscribe();
    super.dispose();
  }
}

/// Provider para obtener todas las listas como Map
final directCustomListsMapProvider = Provider<Map<String, CustomList>>((ref) {
  final state = ref.watch(directCustomListsProvider);
  return state.lists;
});

/// Provider para obtener todas las listas con sus películas
final directCustomListsWithMoviesProvider = Provider<List<CustomList>>((ref) {
  final notifier = ref.read(directCustomListsProvider.notifier);
  return notifier.allListsWithMovies;
});

/// Provider para verificar si una película está en una lista específica
final isMovieInDirectListProvider =
    Provider.family<bool, ({String listId, int movieId})>((ref, params) {
  final notifier = ref.read(directCustomListsProvider.notifier);
  return notifier.isMovieInList(params.listId, params.movieId);
});

/// Provider para obtener las listas que contienen una película específica
final directMovieListsProvider =
    Provider.family<List<CustomList>, int>((ref, movieId) {
  final notifier = ref.read(directCustomListsProvider.notifier);
  return notifier.getListsContainingMovie(movieId);
});
