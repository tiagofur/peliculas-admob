import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../core/sync/trigger_free_custom_lists_sync.dart';
import '../../../domain/entities/custom_list.dart';
import '../../../infrastructure/datasources/supabase_custom_lists_datasource.dart';
import '../../../infrastructure/repositories/custom_lists_repository_impl.dart';
import '../../../services/list_sync_service.dart';
// 🧹 CLEANUP: Removed unused import references

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

  /// Obtiene todas las listas con sus películas incluidas (incluyendo predeterminadas)
  List<CustomList> getAllListsWithMovies() {
    final customLists = lists.keys.map((listId) {
      final list = lists[listId]!;
      final movieIds = listItems[listId] ?? [];
      return list.copyWith(movieIds: movieIds);
    }).toList();

    // Agregar listas predeterminadas con sus items
    final defaultLists = _getDefaultListsWithItems();

    return [...defaultLists, ...customLists];
  }

  /// Obtiene las listas predeterminadas con sus items
  List<CustomList> _getDefaultListsWithItems() {
    final now = DateTime.now();

    final defaultLists = [
      CustomList(
        id: 'en-familia',
        name: 'En Familia',
        description: 'Películas aptas para toda la familia',
        emoji: '👨‍👩‍👧‍👦',
        movieIds: listItems['en-familia'] ?? [],
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'orange',
      ),
      CustomList(
        id: 'en-pareja',
        name: 'En Pareja',
        description: 'Películas románticas y de citas',
        emoji: '�',
        movieIds: listItems['en-pareja'] ?? [],
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'pink',
      ),
      CustomList(
        id: 'clasicos',
        name: 'Clásicos',
        description: 'Clásicos imperdibles del cine',
        emoji: '🏆',
        movieIds: listItems['clasicos'] ?? [],
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'purple',
      ),
      CustomList(
        id: 'sugeridas',
        name: 'Sugeridas',
        description: 'Recomendaciones personalizadas',
        emoji: '⭐',
        movieIds: listItems['sugeridas'] ?? [],
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'teal',
      ),
      CustomList(
        id: 'con-amigos',
        name: 'Con Amigos',
        description: 'Películas para grupos y reuniones',
        emoji: '🍕',
        movieIds: listItems['con-amigos'] ?? [],
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'yellow',
      ),
      CustomList(
        id: 'noches-lluvia',
        name: 'Noches de Lluvia',
        description: 'Películas cómodas para días lluviosos',
        emoji: '�️',
        movieIds: listItems['noches-lluvia'] ?? [],
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'grey',
      ),
      CustomList(
        id: 'cortas',
        name: 'Películas Cortas',
        description: 'Películas de menos de 100 minutos',
        emoji: '⏱️',
        movieIds: listItems['cortas'] ?? [],
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'cyan',
      ),
      CustomList(
        id: 'premiadas',
        name: 'Premiadas',
        description: 'Ganadoras de premios importantes',
        emoji: '🏅',
        movieIds: listItems['premiadas'] ?? [],
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'amber',
      ),
    ];

    return defaultLists;
  }
}

/// Provider directo que evita completamente el repositorio híbrido
/// y solo usa TriggerFreeCustomListsSync para operaciones de Supabase
final directCustomListsProvider =
    StateNotifierProvider<DirectCustomListsNotifier, CustomListsState>((ref) {
  // Note: listSyncServiceProvider is a FutureProvider, but we'll handle it in the notifier
  return DirectCustomListsNotifier(
    // ref: ref, // Commented out for legacy compatibility
    onListCreated: (CustomList list) {
      // Opcional: trackear creación de lista para achievements
      // ref.read(achievementsProvider.notifier).trackListCreated();
    },
  );
});

class DirectCustomListsNotifier extends StateNotifier<CustomListsState> {
  DirectCustomListsNotifier({
    // required this.ref, // Commented out for legacy compatibility
    required this.onListCreated,
  }) : super(const CustomListsState()) {
    _init();
  }

  /// Inicializa el provider: caché local primero, luego sincronización
  Future<void> _init() async {
    try {
      // 1. Cargar desde caché local primero (instantáneo)
      await _loadFromLocal();

      // 2. Luego sincronizar con Supabase en background
      await _loadListsFromSupabase();

      // 3. Configurar listeners real-time
      _setupRealtimeListeners();

      // 4. Inicializar servicio de sync offline
      _initializeSync();

      LoggerFactory.info(
          '✅ DirectCustomListsProvider inicializado completamente');
    } catch (e) {
      LoggerFactory.error(
          '❌ Error inicializando DirectCustomListsProvider: $e');
    }
  }

  // final Ref ref; // Commented out for legacy compatibility
  final Function(CustomList list) onListCreated;
  ListSyncService? _syncService;
  final TriggerFreeCustomListsSync _sync = TriggerFreeCustomListsSync.instance;
  RealtimeChannel? _listsChannel;
  RealtimeChannel? _listItemsChannel;
  String? _currentUserId;
  Timer? _reconnectionTimer;
  bool _isRealtimeConnected = false;

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

      // Cargar cada lista personalizada y sus items
      for (final list in customLists) {
        listsMap[list.id] = list;
        final movieIds = await _sync.getListItems(currentUser.id, list.id);
        listItemsMap[list.id] = movieIds;
      }

      // Cargar items de las listas predeterminadas desde Supabase
      final defaultListsIds = _getDefaultListIds();

      for (final listId in defaultListsIds) {
        final movieIds = await _sync.getListItems(currentUser.id, listId);
        listItemsMap[listId] = movieIds;
        LoggerFactory.debug(
            'DirectCustomLists: Cargados ${movieIds.length} items para lista predeterminada $listId');
      }

      state = CustomListsState(
        lists: listsMap,
        listItems: listItemsMap,
      );

      final totalLists = customLists.length + defaultListsIds.length;
      LoggerFactory.info(
          'DirectCustomLists: Cargadas ${customLists.length} listas personalizadas + ${defaultListsIds.length} predeterminadas = $totalLists total');
      LoggerFactory.debug(
          'DirectCustomLists: IDs personalizadas: ${listsMap.keys.toList()}');
      LoggerFactory.debug(
          'DirectCustomLists: IDs predeterminadas: $defaultListsIds');

      // Persistir los datos recién cargados
      await _persistToLocal();
    } catch (e) {
      LoggerFactory.error('DirectCustomLists: Error cargando: $e');
      state = const CustomListsState();
    }
  }

  /// Inicializar sincronización con ListSyncService
  void _initializeSync() async {
    try {
      LoggerFactory.info(
          'DirectCustomLists: Initializing ListSyncService directly...');

      // Crear dependencias directamente sin usar ref (legacy compatibility)
      final supabaseDataSource =
          SupabaseCustomListsDataSource(Supabase.instance.client);
      final prefs = await SharedPreferences.getInstance();
      final connectivity = Connectivity();

      // Crear repository con las dependencias
      final repository =
          CustomListsRepositoryImpl(supabaseDataSource, prefs, connectivity);

      // Crear sync service
      _syncService = ListSyncService(repository, prefs, connectivity);

      LoggerFactory.info(
          'DirectCustomLists: ListSyncService created successfully');

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
      await _syncService!.startAutoSync();

      LoggerFactory.info(
          'DirectCustomLists: Sync service initialized successfully without ref');
    } catch (e) {
      LoggerFactory.error(
          'DirectCustomLists: Error initializing sync service: $e');
      // No hacer rethrow para que no afecte la funcionalidad básica
      // El provider puede funcionar sin sync service
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
    final currentState = state;
    final updatedLists = Map<String, CustomList>.from(currentState.lists);
    final updatedItems = Map<String, List<int>>.from(currentState.listItems);
    updatedLists[listId] = newList;
    updatedItems[listId] = [];

    state = currentState.copyWith(
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
      final currentState2 = state;
      final revertedLists = Map<String, CustomList>.from(currentState2.lists);
      final revertedItems =
          Map<String, List<int>>.from(currentState2.listItems);
      revertedLists.remove(listId);
      revertedItems.remove(listId);

      state = currentState2.copyWith(
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

    final currentState = state;
    final currentList = currentState.lists[listId];
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

    final currentState2 = state;
    final updatedLists = Map<String, CustomList>.from(currentState2.lists);
    updatedLists[listId] = updatedList;

    state = currentState2.copyWith(lists: updatedLists);

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
      final currentState3 = state;
      final revertedLists = Map<String, CustomList>.from(currentState3.lists);
      revertedLists[listId] = currentList;
      state = currentState3.copyWith(lists: revertedLists);

      rethrow;
    }
  }

  /// Eliminar lista
  Future<void> deleteList(String listId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final currentState = state;
    final currentList = currentState.lists[listId];
    if (currentList == null) return;

    LoggerFactory.debug(
        'DirectCustomLists: Eliminando lista ${currentList.name}');

    // Actualización optimista de la UI
    final currentState2 = state;
    final updatedLists = Map<String, CustomList>.from(currentState2.lists);
    final updatedItems = Map<String, List<int>>.from(currentState2.listItems);
    final removedList = updatedLists.remove(listId);
    final removedItems = updatedItems.remove(listId);

    state = currentState2.copyWith(
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
        final currentState = state;
        final revertedLists = Map<String, CustomList>.from(currentState.lists);
        final revertedItems =
            Map<String, List<int>>.from(currentState.listItems);
        revertedLists[listId] = removedList;
        if (removedItems != null) {
          revertedItems[listId] = removedItems;
        }
        state = currentState.copyWith(
          lists: revertedLists,
          listItems: revertedItems,
        );
      }

      rethrow;
    }
  }

  /// Añadir película a lista
  Future<void> addMovieToList(String listId, int movieId) async {
    LoggerFactory.info(
        '🎬 [DEBUG] Iniciando addMovieToList - listId: $listId, movieId: $movieId');

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      LoggerFactory.error(
          '❌ [DEBUG] Usuario no autenticado - cancelando addMovieToList');
      return;
    }
    LoggerFactory.info('✅ [DEBUG] Usuario autenticado: ${currentUser.id}');

    final currentState = state;
    final currentItems = currentState.listItems[listId] ?? [];

    // Verificar si la lista existe (personalizada o predeterminada)
    final isDefaultList = _isDefaultList(listId);
    final isCustomList = currentState.lists.containsKey(listId);

    if (!isDefaultList && !isCustomList) {
      LoggerFactory.error('❌ [DEBUG] Lista $listId no existe');
      LoggerFactory.info(
          '📋 [DEBUG] Listas personalizadas: ${currentState.lists.keys.toList()}');
      LoggerFactory.info(
          '📋 [DEBUG] Listas predeterminadas: ${_getDefaultListIds()}');
      return;
    }
    LoggerFactory.info(
        '✅ [DEBUG] Lista $listId existe (predeterminada: $isDefaultList, personalizada: $isCustomList)');

    if (currentItems.contains(movieId)) {
      LoggerFactory.info(
          '⚠️ [DEBUG] Película $movieId ya está en la lista $listId - cancelando');
      return; // Ya está en la lista
    }

    LoggerFactory.info(
        '🚀 [DEBUG] Procediendo a agregar película $movieId a lista $listId');
    LoggerFactory.info('📊 [DEBUG] Items actuales en lista: $currentItems');

    // Actualización optimista de la UI
    final updatedItems = Map<String, List<int>>.from(currentState.listItems);
    updatedItems[listId] = [...currentItems, movieId];

    state = currentState.copyWith(listItems: updatedItems);
    LoggerFactory.info('✅ [DEBUG] Estado local actualizado optimísticamente');

    // Persistir inmediatamente en caché local
    await _persistToLocal();

    try {
      // Usar TriggerFreeCustomListsSync directamente
      LoggerFactory.info('📡 [DEBUG] Llamando a TriggerFreeCustomListsSync...');
      await _sync.addMovieToList(currentUser.id, listId, movieId);
      LoggerFactory.info(
          '✅ [DEBUG] TriggerFreeCustomListsSync completado exitosamente');
      LoggerFactory.info(
          '🎉 [SUCCESS] Película $movieId agregada a lista $listId');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ [ERROR] Error agregando película a lista: $e');
      LoggerFactory.error('📍 [ERROR] StackTrace: $stackTrace');

      // Revertir actualización optimista en caso de error
      final revertedItems = Map<String, List<int>>.from(currentState.listItems);
      revertedItems[listId] = currentItems;
      state = currentState.copyWith(listItems: revertedItems);
      LoggerFactory.info('🔄 [DEBUG] Estado local revertido por error');

      // Registrar cambio offline para sincronización posterior
      try {
        await _syncService?.recordOfflineChange(OfflineChange(
          id: 'add_movie_${listId}_${movieId}_${DateTime.now().millisecondsSinceEpoch}',
          type: OfflineChangeType.addMovie,
          data: {
            'listId': listId,
            'movieId': movieId,
          },
          timestamp: DateTime.now(),
        ));
        LoggerFactory.info(
            '📝 [DEBUG] Cambio offline registrado para sincronización');
      } catch (offlineError) {
        LoggerFactory.error(
            '❌ [ERROR] No se pudo registrar cambio offline: $offlineError');
      }

      rethrow;
    }
  }

  /// Remover película de lista
  Future<void> removeMovieFromList(String listId, int movieId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final currentState = state;
    final currentItems = currentState.listItems[listId] ?? [];
    if (!currentItems.contains(movieId)) return; // No está en la lista

    // Verificar si la lista existe (personalizada o predeterminada)
    final isDefaultList = _isDefaultList(listId);
    final isCustomList = currentState.lists.containsKey(listId);

    if (!isDefaultList && !isCustomList) {
      LoggerFactory.error('❌ Lista $listId no existe');
      return;
    }

    LoggerFactory.debug(
        'DirectCustomLists: Removiendo película $movieId de lista $listId');

    // Actualización optimista de la UI
    final updatedItems = Map<String, List<int>>.from(currentState.listItems);
    updatedItems[listId] = currentItems.where((id) => id != movieId).toList();

    state = currentState.copyWith(listItems: updatedItems);

    // Persistir inmediatamente en caché local
    await _persistToLocal();

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
      final currentState2 = state;
      final revertedItems =
          Map<String, List<int>>.from(currentState2.listItems);
      revertedItems[listId] = currentItems;
      state = currentState2.copyWith(listItems: revertedItems);

      rethrow;
    }
  }

  /// Verificar si es una lista predeterminada
  bool _isDefaultList(String listId) {
    return _getDefaultListIds().contains(listId);
  }

  /// Obtener IDs de listas predeterminadas (deben coincidir con defaultType del repository)
  List<String> _getDefaultListIds() {
    return [
      'en-familia',
      'en-pareja',
      'clasicos',
      'sugeridas',
      'con-amigos',
      'noches-lluvia',
      'cortas',
      'premiadas',
    ];
  }

  /// Verifica si las listas predeterminadas ya han sido inicializadas para el usuario
  Future<bool> areDefaultListsInitialized(String userId) async {
    try {
      LoggerFactory.info(
          '🔍 Verificando si las listas predeterminadas ya están creadas para usuario: $userId');

      // Obtener todas las listas del usuario desde Supabase
      final userLists = await _sync.getUserLists(userId);
      final defaultIds = _getDefaultListIds();

      // Contar cuántas listas predeterminadas ya existen
      final existingDefaultIds = userLists
          .where((list) => list.isDefault && defaultIds.contains(list.id))
          .map((list) => list.id)
          .toList();

      LoggerFactory.info(
          '📊 Listas predeterminadas encontradas: ${existingDefaultIds.length}/${defaultIds.length}');
      LoggerFactory.debug('📋 IDs encontrados: $existingDefaultIds');
      LoggerFactory.debug('📋 IDs esperados: $defaultIds');

      // Si tiene al menos 6 de las 8 listas, consideramos que ya están inicializadas
      // Esto permite tolerancia para migraciones o actualizaciones futuras
      final isInitialized = existingDefaultIds.length >= 6;

      LoggerFactory.info(isInitialized
          ? '✅ Listas predeterminadas ya inicializadas'
          : '❌ Listas predeterminadas necesitan ser creadas');

      return isInitialized;
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ Error verificando listas predeterminadas: $e');
      LoggerFactory.debug('Stack trace: $stackTrace');
      // En caso de error, asumir que no están creadas para ser conservadores
      return false;
    }
  }

  /// Inicializa las listas predeterminadas si no existen ya para el usuario
  Future<void> initializeDefaultListsIfNeeded(String userId) async {
    try {
      LoggerFactory.info(
          '🚀 Iniciando verificación de listas predeterminadas para usuario: $userId');

      // Verificar si ya están creadas
      if (await areDefaultListsInitialized(userId)) {
        LoggerFactory.info(
            '✅ Las listas predeterminadas ya existen, omitiendo creación');
        return;
      }

      LoggerFactory.info('📝 Creando listas predeterminadas faltantes...');

      // Obtener las definiciones de las listas predeterminadas
      final defaultListsDefinitions = _getDefaultListsDefinitions();

      // Crear cada lista en Supabase si no existe
      int createdCount = 0;
      for (final listDef in defaultListsDefinitions) {
        try {
          // Verificar si esta lista específica ya existe
          final userLists = await _sync.getUserLists(userId);
          final existsAlready = userLists.any(
              (existing) => existing.id == listDef.id && existing.isDefault);

          if (existsAlready) {
            LoggerFactory.debug(
                '⏭️ Lista ${listDef.name} ya existe, omitiendo');
            continue;
          }

          // Crear la lista en Supabase
          LoggerFactory.info('➕ Creando lista predeterminada: ${listDef.name}');
          final createdList = await _sync.createList(userId, listDef);

          if (createdList != null) {
            createdCount++;
            LoggerFactory.info('✅ Lista creada exitosamente: ${listDef.name}');
          } else {
            LoggerFactory.warning(
                '⚠️ No se pudo crear la lista: ${listDef.name}');
          }

          // Pequeña pausa para evitar saturar Supabase
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          LoggerFactory.error('❌ Error creando lista ${listDef.name}: $e');
          // Continuar con las demás listas aunque una falle
        }
      }

      LoggerFactory.info(
          '🎉 Proceso de inicialización completado. Listas creadas: $createdCount/${defaultListsDefinitions.length}');

      // Recargar las listas desde Supabase para actualizar el estado local
      await _loadListsFromSupabase();
    } catch (e, stackTrace) {
      LoggerFactory.error(
          '❌ Error en inicialización de listas predeterminadas: $e');
      LoggerFactory.debug('Stack trace: $stackTrace');
      // No hacer throw para no bloquear el flujo de la app
    }
  }

  /// Obtiene las definiciones de las listas predeterminadas sin depender del estado actual
  List<CustomList> _getDefaultListsDefinitions() {
    final now = DateTime.now();

    return [
      CustomList(
        id: 'en-familia',
        name: 'En Familia',
        description: 'Películas aptas para toda la familia',
        emoji: '👨‍👩‍👧‍👦',
        movieIds: [], // Lista vacía para inicialización
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'orange',
      ),
      CustomList(
        id: 'en-pareja',
        name: 'En Pareja',
        description: 'Películas románticas y de citas',
        emoji: '💕',
        movieIds: [], // Lista vacía para inicialización
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'pink',
      ),
      CustomList(
        id: 'clasicos',
        name: 'Clásicos',
        description: 'Clásicos imperdibles del cine',
        emoji: '🏆',
        movieIds: [], // Lista vacía para inicialización
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'purple',
      ),
      CustomList(
        id: 'sugeridas',
        name: 'Sugeridas',
        description: 'Recomendaciones personalizadas',
        emoji: '⭐',
        movieIds: [], // Lista vacía para inicialización
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'teal',
      ),
      CustomList(
        id: 'con-amigos',
        name: 'Con Amigos',
        description: 'Películas para grupos y reuniones',
        emoji: '🍕',
        movieIds: [], // Lista vacía para inicialización
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'yellow',
      ),
      CustomList(
        id: 'noches-lluvia',
        name: 'Noches de Lluvia',
        description: 'Películas cómodas para días lluviosos',
        emoji: '🌧️',
        movieIds: [], // Lista vacía para inicialización
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'grey',
      ),
      CustomList(
        id: 'cortas',
        name: 'Películas Cortas',
        description: 'Películas de menos de 100 minutos',
        emoji: '⏱️',
        movieIds: [], // Lista vacía para inicialización
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'cyan',
      ),
      CustomList(
        id: 'premiadas',
        name: 'Premiadas',
        description: 'Ganadoras de premios importantes',
        emoji: '🏅',
        movieIds: [], // Lista vacía para inicialización
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'amber',
      ),
    ];
  }

  /// Alternar película en lista (añadir si no está, remover si está)
  Future<void> toggleMovieInList(String listId, int movieId) async {
    final currentState = state;
    final currentItems = currentState.listItems[listId] ?? [];
    if (currentItems.contains(movieId)) {
      await removeMovieFromList(listId, movieId);
    } else {
      await addMovieToList(listId, movieId);
    }
  }

  /// Configurar listeners de tiempo real
  void _setupRealtimeListeners() {
    try {
      if (_currentUserId == null) {
        LoggerFactory.warning(
            '⚠️ No hay usuario autenticado, saltando setup real-time');
        return;
      }

      LoggerFactory.info(
          '📡 [REAL-TIME] Configurando listeners para usuario: $_currentUserId');

      // Limpiar listeners existentes primero
      _cleanupRealtimeListeners();

      // Listener para cambios en listas
      _listsChannel = Supabase.instance.client
          .channel('custom_lists_$_currentUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'user_lists',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: _currentUserId!,
            ),
            callback: _handleListsRealtimeEvent,
          )
          .subscribe((status, error) {
        LoggerFactory.info('📡 Lista Channel status: $status');
        if (error != null) {
          LoggerFactory.error('📡 Lista Channel error: $error');
        }
        _isRealtimeConnected = status == RealtimeSubscribeStatus.subscribed;
        if (!_isRealtimeConnected) {
          _startReconnectionTimer();
        }
      });

      // Listener para cambios en items de listas
      _listItemsChannel = Supabase.instance.client
          .channel('list_items_$_currentUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'user_list_items',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: _currentUserId!,
            ),
            callback: _handleListItemsRealtimeEvent,
          )
          .subscribe((status, error) {
        LoggerFactory.info('📡 Items Channel status: $status');
        if (error != null) {
          LoggerFactory.error('📡 Items Channel error: $error');
        }
        _isRealtimeConnected = status == RealtimeSubscribeStatus.subscribed;
        if (!_isRealtimeConnected) {
          _startReconnectionTimer();
        }
      });

      LoggerFactory.info('✅ Real-time listeners configurados');
    } catch (e) {
      LoggerFactory.error('❌ Error configurando real-time listeners: $e');
      _startReconnectionTimer();
    }
  }

  void _cleanupRealtimeListeners() {
    _listsChannel?.unsubscribe();
    _listItemsChannel?.unsubscribe();
    _listsChannel = null;
    _listItemsChannel = null;
    _reconnectionTimer?.cancel();
    _isRealtimeConnected = false;
  }

  void _startReconnectionTimer() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isRealtimeConnected && _currentUserId != null) {
        LoggerFactory.info('🔄 Intentando reconectar real-time...');
        _setupRealtimeListeners();
      } else if (_isRealtimeConnected) {
        timer.cancel();
      }
    });
  }

  /// Maneja eventos de tiempo real para listas
  void _handleListsRealtimeEvent(PostgresChangePayload payload) {
    try {
      LoggerFactory.info('🔴 DirectCustomLists: ===== CAMBIO EN LISTAS =====');
      LoggerFactory.info(
          '🔴 DirectCustomLists: Tipo de evento: ${payload.eventType}');
      LoggerFactory.debug(
          '🔍 DirectCustomLists: newRecord: ${payload.newRecord}');
      LoggerFactory.debug(
          '🔍 DirectCustomLists: oldRecord: ${payload.oldRecord}');

      // 🔧 FIXED: Mejor manejo de datos para diferentes tipos de eventos
      Map<String, dynamic> data = {};

      if (payload.eventType == PostgresChangeEvent.delete) {
        data = payload.oldRecord.isNotEmpty
            ? payload.oldRecord
            : payload.newRecord;
      } else {
        data = payload.newRecord.isNotEmpty
            ? payload.newRecord
            : payload.oldRecord;
      }

      // 🔧 FIXED: Validación robusta de datos críticos
      final userId = data['user_id'] as String?;
      final listId = data['id'] as String?;
      final isDeleted = data['is_deleted'] as bool? ?? false;

      LoggerFactory.debug('🔍 DirectCustomLists: user_id: ${userId ?? 'NULL'}');
      LoggerFactory.debug(
          '🔍 DirectCustomLists: current_user: $_currentUserId');
      LoggerFactory.debug('🔍 DirectCustomLists: list_id: ${listId ?? 'NULL'}');
      LoggerFactory.debug('🔍 DirectCustomLists: is_deleted: $isDeleted');

      // 🔧 FIXED: Filtrar eventos de otros usuarios primero
      if (userId != null && userId != _currentUserId) {
        LoggerFactory.debug(
            '🔴 DirectCustomLists: Evento de otro usuario, ignorando');
        return;
      }

      // 🔧 FIXED: Manejar casos donde list_id es NULL
      if (listId == null) {
        LoggerFactory.warning(
            '⚠️ DirectCustomLists: list_id es NULL, haciendo refresh completo');
        Future.delayed(const Duration(milliseconds: 500), () {
          _loadListsFromSupabase();
        });
        return;
      }

      // 🔧 FIXED: Procesar eventos de forma consistente
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
          LoggerFactory.info(
              '➕ DirectCustomLists: Procesando INSERT para lista: $listId');
          if (!isDeleted) {
            _handleListInsert(payload.newRecord);
          }
          break;

        case PostgresChangeEvent.delete:
          LoggerFactory.info(
              '🗑️ DirectCustomLists: Procesando DELETE para lista: $listId');
          _handleListDelete(payload.oldRecord);
          break;

        case PostgresChangeEvent.update:
          LoggerFactory.info(
              '🔄 DirectCustomLists: Procesando UPDATE para lista: $listId');
          if (isDeleted) {
            _handleListDelete(payload.newRecord);
          } else {
            _handleListInsert(payload.newRecord);
          }
          break;

        case PostgresChangeEvent.all:
          LoggerFactory.info(
              '🔄 DirectCustomLists: Procesando evento genérico');
          _handleGenericListEvent(payload, data, listId, isDeleted);
          break;
      }
    } catch (e, stackTrace) {
      LoggerFactory.error(
          '❌ DirectCustomLists: Error manejando evento de listas: $e');
      LoggerFactory.error('❌ DirectCustomLists: Stack: $stackTrace');

      // 🔧 FIXED: En caso de error crítico, hacer refresh completo
      Future.delayed(const Duration(milliseconds: 1000), () {
        _loadListsFromSupabase();
      });
    }
  }

  /// Maneja eventos de tiempo real para items de listas
  void _handleListItemsRealtimeEvent(PostgresChangePayload payload) {
    try {
      LoggerFactory.info('🔴 DirectCustomLists: ===== CAMBIO EN ITEMS =====');
      LoggerFactory.info(
          '🔴 DirectCustomLists: Tipo de evento: ${payload.eventType}');
      LoggerFactory.debug(
          '🔍 DirectCustomLists: newRecord: ${payload.newRecord}');
      LoggerFactory.debug(
          '🔍 DirectCustomLists: oldRecord: ${payload.oldRecord}');

      // 🔧 FIXED: Mejor manejo de datos para diferentes tipos de eventos
      Map<String, dynamic> data = {};

      if (payload.eventType == PostgresChangeEvent.delete) {
        data = payload.oldRecord.isNotEmpty
            ? payload.oldRecord
            : payload.newRecord;
      } else {
        data = payload.newRecord.isNotEmpty
            ? payload.newRecord
            : payload.oldRecord;
      }

      // 🔧 FIXED: Validación robusta de datos críticos
      final userId = data['user_id'] as String?;
      final listId = data['list_id'] as String?;
      final movieId = data['movie_id'] as int?;
      final isDeleted = data['is_deleted'] as bool? ?? false;

      LoggerFactory.debug('🔍 DirectCustomLists: user_id: ${userId ?? 'NULL'}');
      LoggerFactory.debug('🔍 DirectCustomLists: list_id: ${listId ?? 'NULL'}');
      LoggerFactory.debug(
          '🔍 DirectCustomLists: movie_id: ${movieId ?? 'NULL'}');
      LoggerFactory.debug('🔍 DirectCustomLists: is_deleted: $isDeleted');

      // 🔧 FIXED: Solo procesar si tenemos esta lista y no es de otro usuario
      final currentState = state;
      if (listId == null || !currentState.lists.containsKey(listId)) {
        LoggerFactory.debug(
            '🔴 DirectCustomLists: Lista no encontrada localmente, ignorando');
        return;
      }

      // 🔧 FIXED: Manejar casos donde movie_id es NULL
      if (movieId == null) {
        LoggerFactory.warning(
            '⚠️ DirectCustomLists: movie_id es NULL, recargando lista $listId');
        Future.delayed(const Duration(milliseconds: 500), () async {
          final currentUser = Supabase.instance.client.auth.currentUser;
          if (currentUser != null) {
            final movieIds = await _sync.getListItems(currentUser.id, listId);
            final currentState = state;
            final updatedItems =
                Map<String, List<int>>.from(currentState.listItems);
            updatedItems[listId] = movieIds;
            state = currentState.copyWith(listItems: updatedItems);
          }
        });
        return;
      }

      // 🔧 FIXED: Procesar eventos de forma consistente
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
          LoggerFactory.info(
              '➕ DirectCustomLists: Procesando INSERT para item: movie_id=$movieId en lista=$listId');
          if (!isDeleted) {
            _handleItemInsert(payload.newRecord);
          }
          break;

        case PostgresChangeEvent.delete:
          LoggerFactory.info(
              '🗑️ DirectCustomLists: Procesando DELETE para item: movie_id=$movieId en lista=$listId');
          _handleItemDelete(payload.oldRecord);
          break;

        case PostgresChangeEvent.update:
          LoggerFactory.info(
              '🔄 DirectCustomLists: Procesando UPDATE para item: movie_id=$movieId en lista=$listId');
          if (isDeleted) {
            _handleItemDelete(payload.newRecord);
          } else {
            _handleItemInsert(payload.newRecord);
          }
          break;

        case PostgresChangeEvent.all:
          LoggerFactory.info(
              '🔄 DirectCustomLists: Procesando evento genérico en items');
          _handleGenericItemEvent(payload, data, listId, movieId, isDeleted);
          break;
      }
    } catch (e, stackTrace) {
      LoggerFactory.error(
          '❌ DirectCustomLists: Error manejando evento de items: $e');
      LoggerFactory.error('❌ DirectCustomLists: Stack: $stackTrace');
    }
  }

  void _handleListInsert(Map<String, dynamic> record) {
    try {
      final userId = record['user_id'] as String?;
      final isDeleted = record['is_deleted'] as bool? ?? false;
      final listId = record['id'] as String?;

      if (userId != _currentUserId || isDeleted || listId == null) return;

      // 🔧 FIXED: Solo insertar si no existe localmente
      final currentState = state;
      if (!currentState.lists.containsKey(listId)) {
        final customList = _recordToCustomList(record);
        LoggerFactory.info(
            '➕ DirectCustomLists: Lista agregada remotamente: ${customList.name}');

        // 🔧 FIXED: Crear nuevo estado para triggear rebuild
        final updatedLists = Map<String, CustomList>.from(currentState.lists);
        final updatedItems =
            Map<String, List<int>>.from(currentState.listItems);

        updatedLists[listId] = customList;
        if (!updatedItems.containsKey(listId)) {
          updatedItems[listId] = [];
        }

        state =
            currentState.copyWith(lists: updatedLists, listItems: updatedItems);

        // Persistir cambios inmediatamente
        _persistToLocal();
      }
    } catch (e, stackTrace) {
      LoggerFactory.error(
          '❌ DirectCustomLists: Error en inserción de lista: $e');
      LoggerFactory.debug('❌ Stack trace: $stackTrace');
    }
  }

  void _handleListUpdate(
      Map<String, dynamic> newRecord, Map<String, dynamic> oldRecord) {
    if (newRecord['user_id'] != _currentUserId) return;

    final listId = newRecord['id'] as String;

    if (newRecord['is_deleted'] ?? false) {
      LoggerFactory.info(
          '🗑️ DirectCustomLists: Lista eliminada ${newRecord['name']}');
      final currentState = state;
      final updatedLists = Map<String, CustomList>.from(currentState.lists);
      final updatedItems = Map<String, List<int>>.from(currentState.listItems);
      updatedLists.remove(listId);
      updatedItems.remove(listId);
      state =
          currentState.copyWith(lists: updatedLists, listItems: updatedItems);

      // Persistir cambios inmediatamente
      _persistToLocal();
    } else {
      final customList = _recordToCustomList(newRecord);
      LoggerFactory.info(
          '🔄 DirectCustomLists: Actualizando lista ${customList.name}');
      final currentState2 = state;
      final updatedLists = Map<String, CustomList>.from(currentState2.lists);
      updatedLists[listId] = customList;
      state = currentState2.copyWith(lists: updatedLists);

      // Persistir cambios inmediatamente
      _persistToLocal();
    }
  }

  void _handleListDelete(Map<String, dynamic> record) {
    try {
      final userId = record['user_id'] as String?;
      final listId = record['id'] as String?;

      if (userId != _currentUserId || listId == null) return;

      LoggerFactory.info('🗑️ DirectCustomLists: Eliminando lista: $listId');
      final currentState = state;
      LoggerFactory.debug(
          '🗑️ DirectCustomLists: Estado antes: ${currentState.lists.keys.length} listas');

      if (currentState.lists.containsKey(listId)) {
        final list = currentState.lists[listId];
        // 🔧 FIXED: Crear nuevo estado sin la lista eliminada
        final updatedLists = Map<String, CustomList>.from(currentState.lists);
        final updatedItems =
            Map<String, List<int>>.from(currentState.listItems);
        updatedLists.remove(listId);
        updatedItems.remove(listId);
        final newState =
            currentState.copyWith(lists: updatedLists, listItems: updatedItems);
        state = newState;

        LoggerFactory.info(
            '✅ DirectCustomLists: Lista eliminada remotamente: ${list?.name}');
        LoggerFactory.debug(
            '🗑️ DirectCustomLists: Estado después: ${newState.lists.keys.length} listas');
      } else {
        LoggerFactory.debug(
            'ℹ️ DirectCustomLists: Lista $listId no estaba en estado local');
      }
    } catch (e, stackTrace) {
      LoggerFactory.error(
          '❌ DirectCustomLists: Error en eliminación de lista: $e');
      LoggerFactory.debug('❌ Stack trace: $stackTrace');

      // 🔧 FIXED: En caso de error, hacer refresh para mantener consistencia
      Future.delayed(const Duration(milliseconds: 500), () {
        _loadListsFromSupabase();
      });
    }
  }

  void _handleItemInsert(Map<String, dynamic> record) {
    try {
      final isDeleted = record['is_deleted'] as bool? ?? false;
      final listId = record['list_id'] as String?;
      final movieId = record['movie_id'] as int?;

      if (isDeleted || listId == null || movieId == null) return;

      // Solo procesar si tenemos esta lista
      final currentState = state;
      if (!currentState.lists.containsKey(listId)) return;

      LoggerFactory.info(
          '➕ DirectCustomLists: Agregando película $movieId a lista $listId');

      // 🔧 FIXED: Solo agregar si no existe localmente
      final currentState2 = state;
      final currentItems = currentState2.listItems[listId] ?? [];
      if (!currentItems.contains(movieId)) {
        // 🔧 FIXED: Crear nuevo estado para triggear rebuild
        final updatedItems =
            Map<String, List<int>>.from(currentState2.listItems);
        updatedItems[listId] = [...currentItems, movieId];
        state = currentState2.copyWith(listItems: updatedItems);

        LoggerFactory.info(
            '✅ DirectCustomLists: Película agregada remotamente a lista');
      }
    } catch (e, stackTrace) {
      LoggerFactory.error(
          '❌ DirectCustomLists: Error en inserción de item: $e');
      LoggerFactory.debug('❌ Stack trace: $stackTrace');
    }
  }

  void _handleItemUpdate(
      Map<String, dynamic> newRecord, Map<String, dynamic> oldRecord) {
    try {
      final listId = newRecord['list_id'] as String?;
      final movieId = newRecord['movie_id'] as int?;

      if (listId == null || movieId == null) return;

      // Solo procesar si tenemos esta lista
      final currentState = state;
      if (!currentState.lists.containsKey(listId)) return;

      if (newRecord['is_deleted'] ?? false) {
        LoggerFactory.info(
            '🗑️ DirectCustomLists: Item eliminado $movieId de lista $listId');

        final currentStateForDelete = state;
        final currentItems = currentStateForDelete.listItems[listId] ?? [];
        if (currentItems.contains(movieId)) {
          final updatedItems =
              Map<String, List<int>>.from(currentStateForDelete.listItems);
          updatedItems[listId] =
              currentItems.where((id) => id != movieId).toList();
          state = currentStateForDelete.copyWith(listItems: updatedItems);

          LoggerFactory.info(
              '✅ DirectCustomLists: Item actualizado y eliminado de lista');
        }
      } else {
        // Item was updated but not deleted, ensure it exists in the list
        final currentStateForAdd = state;
        final currentItems = currentStateForAdd.listItems[listId] ?? [];
        if (!currentItems.contains(movieId)) {
          final updatedItems =
              Map<String, List<int>>.from(currentStateForAdd.listItems);
          updatedItems[listId] = [...currentItems, movieId];
          state = currentStateForAdd.copyWith(listItems: updatedItems);

          LoggerFactory.info(
              '✅ DirectCustomLists: Item actualizado y agregado a lista');
        }
      }
    } catch (e, stackTrace) {
      LoggerFactory.error(
          '❌ DirectCustomLists: Error en actualización de item: $e');
      LoggerFactory.debug('❌ Stack trace: $stackTrace');
    }
  }

  void _handleItemDelete(Map<String, dynamic> record) {
    try {
      final listId = record['list_id'] as String?;
      final movieId = record['movie_id'] as int?;

      if (listId == null || movieId == null) return;

      // Solo procesar si tenemos esta lista
      final currentState = state;
      if (!currentState.lists.containsKey(listId)) return;

      LoggerFactory.info(
          '🗑️ DirectCustomLists: Eliminando item $movieId de lista $listId');

      final currentItems = List<int>.from(currentState.listItems[listId] ?? []);
      LoggerFactory.debug(
          '🗑️ DirectCustomLists: Items antes: ${currentItems.length}');

      if (currentItems.contains(movieId)) {
        // Crear nuevo estado sin el item eliminado
        currentItems.remove(movieId);
        final updatedItems =
            Map<String, List<int>>.from(currentState.listItems);
        updatedItems[listId] = currentItems;

        final newState = currentState.copyWith(listItems: updatedItems);
        state = newState;

        LoggerFactory.info(
            '✅ DirectCustomLists: Item eliminado remotamente de lista');
        LoggerFactory.debug(
            '🗑️ DirectCustomLists: Items después: ${currentItems.length}');
      } else {
        LoggerFactory.debug(
            'ℹ️ DirectCustomLists: Item $movieId no estaba en lista $listId local');
      }
    } catch (e, stackTrace) {
      LoggerFactory.error(
          '❌ DirectCustomLists: Error en eliminación de item: $e');
      LoggerFactory.debug('❌ Stack trace: $stackTrace');
    }
  }

  /// Convierte un record de Supabase a CustomList
  CustomList _recordToCustomList(Map<String, dynamic> record) {
    // 🔧 FIXED: Validación robusta de datos obligatorios
    final id = record['id'] as String?;
    final name = record['name'] as String?;
    final createdAt = record['created_at'] as String?;

    if (id == null || name == null || name.isEmpty || createdAt == null) {
      throw ArgumentError(
          'Record debe tener id, name y created_at válidos: $record');
    }

    // 🔧 FIXED: Convertir color hex de vuelta a nombre si existe
    String colorHex = record['color_hex'] as String? ?? '#2196F3';
    String colorName = _hexToColorName(colorHex);

    return CustomList(
      id: id,
      name: name,
      description: record['description']?.toString() ?? '',
      emoji: record['emoji']?.toString() ?? '📝',
      color: colorName,
      movieIds: [], // Se cargan por separado
      createdAt: DateTime.parse(createdAt),
      lastModifiedAt: DateTime.tryParse(
              record['last_modified_at']?.toString() ?? createdAt) ??
          DateTime.parse(createdAt),
      isDefault: record['is_default'] as bool? ?? false,
    );
  }

  /// Habilita el provider después del login
  Future<void> enableAfterLogin() async {
    LoggerFactory.info(
        '🔐 DirectCustomLists: Habilitando después del login...');

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      LoggerFactory.warning(
          '🔐 DirectCustomLists: No hay usuario autenticado, omitiendo inicialización');
      return;
    }

    _currentUserId = currentUser.id;

    // Inicializar listas predeterminadas si es necesario (solo se ejecuta una vez por usuario)
    await initializeDefaultListsIfNeeded(currentUser.id);

    await _loadListsFromSupabase();
    _setupRealtimeListeners();

    LoggerFactory.info('✅ DirectCustomLists: Listas habilitadas correctamente');
  }

  /// Verifica si una película está en una lista específica
  bool isMovieInList(String listId, int movieId) {
    final currentState = state;
    final items = currentState.listItems[listId] ?? [];
    return items.contains(movieId);
  }

  /// Obtiene todas las listas que contienen una película específica
  List<CustomList> getListsContainingMovie(int movieId) {
    final result = <CustomList>[];
    final currentState = state;

    for (final entry in currentState.listItems.entries) {
      final listId = entry.key;
      final movieIds = entry.value;

      if (movieIds.contains(movieId)) {
        final list = currentState.lists[listId];
        if (list != null) {
          result.add(list.copyWith(movieIds: movieIds));
        }
      }
    }

    return result;
  }

  /// Obtiene una lista específica con sus películas
  CustomList? getListWithMovies(String listId) {
    final currentState = state;
    return currentState.getListWithMovies(listId);
  }

  /// Obtiene todas las listas con sus películas
  List<CustomList> get allListsWithMovies {
    final currentState = state;
    return currentState.getAllListsWithMovies();
  }

  /// Refresca todas las listas desde Supabase
  Future<void> refresh() async {
    await _loadListsFromSupabase();
  }

  /// Fuerza la inicialización de listas predeterminadas (uso manual/debug)
  /// Normalmente no es necesario llamar este método ya que se ejecuta automáticamente al login
  Future<void> forceInitializeDefaultLists() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      LoggerFactory.warning('No hay usuario autenticado');
      return;
    }

    LoggerFactory.info(
        '🔧 Forzando inicialización manual de listas predeterminadas');
    await initializeDefaultListsIfNeeded(currentUser.id);
  }

  /// 🔄 ADDED: Manejar evento genérico de tiempo real para listas (PostgresChangeEvent.all)
  void _handleGenericListEvent(PostgresChangePayload payload,
      Map<String, dynamic> data, String? listId, bool isDeleted) {
    try {
      LoggerFactory.info(
          '🔄 DirectCustomLists: Manejando evento genérico de lista');

      if (listId == null) {
        LoggerFactory.warning(
            '⚠️ DirectCustomLists: Evento genérico sin list_id, haciendo refresh');
        Future.delayed(const Duration(milliseconds: 500), () {
          _loadListsFromSupabase();
        });
        return;
      }

      // 🔧 FIXED: Determinar acción basada en datos y estado de los records
      final hasNewRecord = payload.newRecord.isNotEmpty;
      final hasOldRecord = payload.oldRecord.isNotEmpty;

      if (!hasNewRecord && hasOldRecord) {
        // Solo oldRecord = DELETE
        LoggerFactory.info(
            '🗑️ DirectCustomLists: Evento genérico -> DELETE detectado');
        _handleListDelete(payload.oldRecord);
      } else if (hasNewRecord && !hasOldRecord) {
        // Solo newRecord = INSERT
        LoggerFactory.info(
            '➕ DirectCustomLists: Evento genérico -> INSERT detectado');
        if (!isDeleted) {
          _handleListInsert(payload.newRecord);
        }
      } else if (hasNewRecord && hasOldRecord) {
        // Ambos records = UPDATE
        LoggerFactory.info(
            '🔄 DirectCustomLists: Evento genérico -> UPDATE detectado');
        _handleListUpdate(payload.newRecord, payload.oldRecord);
      } else {
        // Caso fallback
        LoggerFactory.info('🔄 DirectCustomLists: Evento genérico fallback');
        if (isDeleted) {
          _handleListDelete(data);
        } else {
          _handleListInsert(data);
        }
      }
    } catch (e) {
      LoggerFactory.error(
          '❌ DirectCustomLists: Error en evento genérico de lista: $e');
    }
  }

  /// 🔄 ADDED: Manejar evento genérico de tiempo real para items (PostgresChangeEvent.all)
  void _handleGenericItemEvent(PostgresChangePayload payload,
      Map<String, dynamic> data, String? listId, int? movieId, bool isDeleted) {
    try {
      LoggerFactory.info(
          '🔄 DirectCustomLists: Manejando evento genérico de item');

      if (listId == null || movieId == null) {
        LoggerFactory.warning(
            '⚠️ DirectCustomLists: Evento genérico sin list_id o movie_id, ignorando');
        return;
      }

      // 🔧 FIXED: Determinar acción basada en datos y estado de los records
      final hasNewRecord = payload.newRecord.isNotEmpty;
      final hasOldRecord = payload.oldRecord.isNotEmpty;

      if (!hasNewRecord && hasOldRecord) {
        // Solo oldRecord = DELETE
        LoggerFactory.info(
            '🗑️ DirectCustomLists: Evento genérico item -> DELETE detectado');
        _handleItemDelete(payload.oldRecord);
      } else if (hasNewRecord && !hasOldRecord) {
        // Solo newRecord = INSERT
        LoggerFactory.info(
            '➕ DirectCustomLists: Evento genérico item -> INSERT detectado');
        if (!isDeleted) {
          _handleItemInsert(payload.newRecord);
        }
      } else if (hasNewRecord && hasOldRecord) {
        // Ambos records = UPDATE
        LoggerFactory.info(
            '🔄 DirectCustomLists: Evento genérico item -> UPDATE detectado');
        _handleItemUpdate(payload.newRecord, payload.oldRecord);
      } else {
        // Caso fallback
        LoggerFactory.info(
            '🔄 DirectCustomLists: Evento genérico item fallback');
        if (isDeleted) {
          _handleItemDelete(data);
        } else {
          _handleItemInsert(data);
        }
      }
    } catch (e) {
      LoggerFactory.error(
          '❌ DirectCustomLists: Error en evento genérico de item: $e');
    }
  }

  /// 🔧 ADDED: Convierte código hexadecimal de vuelta a nombre de color
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

  /// Persiste el estado actual en almacenamiento local
  Future<void> _persistToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Guardar listas personalizadas
      final listsJson =
          state.lists.values.map((list) => list.toJson()).toList();
      await prefs.setString('custom_lists_cache', jsonEncode(listsJson));

      // Guardar items de listas
      final itemsJson = <String, dynamic>{};
      state.listItems.forEach((listId, movieIds) {
        itemsJson[listId] = movieIds;
      });
      await prefs.setString('custom_list_items_cache', jsonEncode(itemsJson));

      // Guardar timestamp de última sincronización
      await prefs.setString(
          'custom_lists_last_sync', DateTime.now().toIso8601String());

      LoggerFactory.debug('✅ Estado de Custom Lists persistido localmente');
    } catch (e) {
      LoggerFactory.error('❌ Error persistiendo estado local: $e');
    }
  }

  /// Carga el estado desde almacenamiento local
  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Cargar listas
      final listsString = prefs.getString('custom_lists_cache');
      if (listsString != null) {
        final listsJson = jsonDecode(listsString) as List;
        final lists = <String, CustomList>{};
        for (final json in listsJson) {
          final list = CustomList.fromJson(json as Map<String, dynamic>);
          lists[list.id] = list;
        }

        // Cargar items
        final itemsString = prefs.getString('custom_list_items_cache');
        final items = <String, List<int>>{};
        if (itemsString != null) {
          final itemsJson = jsonDecode(itemsString) as Map<String, dynamic>;
          itemsJson.forEach((listId, movieIds) {
            items[listId] = List<int>.from(movieIds as List);
          });
        }

        // Actualizar estado solo si hay datos
        if (lists.isNotEmpty || items.isNotEmpty) {
          state = CustomListsState(
            lists: lists,
            listItems: items,
          );

          final lastSync = prefs.getString('custom_lists_last_sync');
          LoggerFactory.info(
              '✅ Estado de Custom Lists cargado desde caché local');
          if (lastSync != null) {
            LoggerFactory.debug('📅 Última sincronización: $lastSync');
          }
        }
      }
    } catch (e) {
      LoggerFactory.error('❌ Error cargando estado local: $e');
    }
  }

  @override
  void dispose() {
    LoggerFactory.info('🗑️ DirectCustomLists: Cerrando listeners...');
    _cleanupRealtimeListeners();
    super.dispose();
  }
}

// 🧹 CLEANUP: Removed commented legacy providers that were not being used
// This reduces file size by ~30 lines and improves code readability
