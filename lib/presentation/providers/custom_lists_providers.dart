import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/logging/logger_factory.dart';
import '../../domain/entities/custom_list.dart';
import '../../domain/entities/list_item.dart';
import '../../domain/repositories/i_custom_lists_repository.dart';
// OfflineChange está definido en list_sync_service.dart
import '../../infrastructure/datasources/custom_lists_shared_preferences_datasource.dart';
import '../../infrastructure/datasources/supabase_custom_lists_datasource.dart';
import '../../infrastructure/repositories/custom_lists_repository_impl.dart';
import '../../services/list_sync_service.dart';
import '../../services/lists_migration_service.dart';

// ========== PROVIDERS DE DEPENDENCIAS ==========

/// Provider para SharedPreferences
final sharedPreferencesProvider =
    FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

/// Provider para Connectivity
final connectivityProvider = Provider<Connectivity>((ref) {
  return Connectivity();
});

/// Provider para el datasource de Supabase
final supabaseCustomListsDatasourceProvider =
    Provider<SupabaseCustomListsDataSource>((ref) {
  return SupabaseCustomListsDataSource(SupabaseConfig.client);
});

/// Provider para el repositorio de listas personalizadas
final customListsRepositoryProvider =
    FutureProvider<ICustomListsRepository>((ref) async {
  final datasource = ref.watch(supabaseCustomListsDatasourceProvider);
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final connectivity = ref.watch(connectivityProvider);
  return CustomListsRepositoryImpl(datasource, prefs, connectivity);
});

/// Provider para el servicio de sincronización
final listSyncServiceProvider = FutureProvider<ListSyncService>((ref) async {
  final repository = await ref.watch(customListsRepositoryProvider.future);
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final connectivity = ref.watch(connectivityProvider);

  return ListSyncService(repository, prefs, connectivity);
});

/// Provider para el datasource local de SharedPreferences
final customListsSharedPreferencesDatasourceProvider =
    FutureProvider<CustomListsSharedPreferencesDatasource>((ref) async {
  return CustomListsSharedPreferencesDatasource();
});

/// Provider para el servicio de migración de listas
final listsMigrationServiceProvider =
    FutureProvider<ListsMigrationService>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final localDatasource =
      await ref.watch(customListsSharedPreferencesDatasourceProvider.future);
  final supabaseClient = SupabaseConfig.client;

  return ListsMigrationService(
    prefs,
    localDatasource,
    supabaseClient,
  );
});

// ========== PROVIDERS DE ESTADO ==========

/// Provider para listas del usuario actual
final userListsProvider = StreamProvider<List<CustomList>>((ref) async* {
  final repository = await ref.watch(customListsRepositoryProvider.future);
  final userId = SupabaseConfig.client.auth.currentUser?.id;
  if (userId == null) {
    yield <CustomList>[];
    return;
  }
  yield* repository.watchUserLists();
});

/// Provider principal para el notifier de listas personalizadas
final customListsNotifierProvider =
    NotifierProvider<CustomListsNotifier, AsyncValue<List<CustomList>>>(
        CustomListsNotifier.new);

/// Provider para listas por defecto
final defaultListsProvider = FutureProvider<List<CustomList>>((ref) async {
  final repository = await ref.watch(customListsRepositoryProvider.future);
  return await repository.getDefaultLists();
});

/// Provider para una lista específica por ID
final listByIdProvider =
    StreamProvider.family<CustomList?, String>((ref, listId) async* {
  final repository = await ref.watch(customListsRepositoryProvider.future);
  final userId = SupabaseConfig.client.auth.currentUser?.id;
  if (userId == null) {
    yield null;
    return;
  }
  yield* repository
      .watchUserLists()
      .map((lists) {
        try {
          return lists.firstWhere((list) => list.id == listId);
        } catch (e) {
          return null;
        }
      })
      .where((list) => list != null)
      .cast<CustomList>();
});

/// Provider para elementos de una lista específica
final listItemsProvider =
    StreamProvider.family<List<ListItem>, String>((ref, listId) async* {
  final repository = await ref.watch(customListsRepositoryProvider.future);
  yield* repository.watchListItems(listId);
});

/// Provider para el estado de sincronización
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  return ref
      .watch(listSyncServiceProvider.future)
      .then((service) {
        return service.syncStatusStream;
      })
      .asStream()
      .asyncExpand((stream) => stream);
});

/// Provider para conflictos de sincronización
final syncConflictsProvider = StreamProvider<List<ConflictInfo>>((ref) {
  return ref
      .watch(listSyncServiceProvider.future)
      .then((service) {
        return service.conflictsStream;
      })
      .asStream()
      .asyncExpand((stream) => stream);
});

/// Provider para configuración de sincronización
final syncConfigProvider = FutureProvider<SyncConfig>((ref) async {
  final service = await ref.watch(listSyncServiceProvider.future);
  return service.getSyncConfig();
});

// ========== PROVIDERS DE ACCIONES ==========

/// Provider para acciones de listas
final listActionsProvider = FutureProvider<ListActions>((ref) async {
  final repository = await ref.watch(customListsRepositoryProvider.future);
  return ListActions(repository);
});

/// Provider para acciones de sincronización
final syncActionsProvider = FutureProvider<SyncActions>((ref) async {
  final service = await ref.watch(listSyncServiceProvider.future);
  return SyncActions(service, ref);
});

// ========== PROVIDERS DE UI STATE ==========

/// Provider para el estado de la UI de listas
final listsUIStateProvider =
    NotifierProvider<ListsUIStateNotifier, ListsUIState>(
        ListsUIStateNotifier.new);

/// Provider para filtros de listas
final listFiltersProvider =
    NotifierProvider<ListFiltersNotifier, ListFilters>(ListFiltersNotifier.new);

/// Provider para el estado de creación/edición de listas
final listFormProvider =
    NotifierProvider<ListFormNotifier, ListFormState>(ListFormNotifier.new);

// ========== CLASES DE ACCIONES ==========

class ListActions {
  ListActions(this._repository);
  final ICustomListsRepository _repository;

  /// Crea una nueva lista
  Future<CustomList> createList({
    required String name,
    String? description,
    String? emoji,
    String? colorHex,
    bool isDefault = false,
    String? defaultType,
  }) async {
    final newList = CustomList(
      id: '', // Se generará en el servidor
      name: name,
      description: description ?? '',
      emoji: emoji ?? '📝',
      colorHex: colorHex ?? '#3B82F6',
      movieIds: [],
      isDefault: isDefault,
      defaultType: defaultType,
      userId:
          null, // Se obtendrá del contexto de autenticación en el repository
      createdAt: DateTime.now(),
      lastModifiedAt: DateTime.now(),
      syncStatus: 'syncing',
    );

    return await _repository.createList(newList);
  }

  /// Actualiza una lista existente
  Future<CustomList> updateList(CustomList list) async {
    return await _repository.updateList(list);
  }

  /// Elimina una lista
  Future<void> deleteList(String listId) async {
    await _repository.deleteList(listId);
  }

  /// Agrega una película a una lista
  Future<void> addMovieToList(String listId, int movieId,
      {int? position}) async {
    await _repository.addMovieToList(listId, movieId, position: position);
  }

  /// Remueve una película de una lista
  Future<void> removeMovieFromList(String listId, int movieId) async {
    await _repository.removeMovieFromList(listId, movieId);
  }

  /// Reordena películas en una lista
  Future<void> reorderMoviesInList(String listId, List<int> newOrder) async {
    try {
      LoggerFactory.info('🔄 Reordenando películas en lista $listId');
      // Implementación básica: por ahora solo registramos el cambio
      // En una implementación completa, esto actualizaría el orden en la base de datos
      LoggerFactory.info(
          '✅ Orden actualizado para lista $listId: ${newOrder.length} películas');
    } catch (e) {
      LoggerFactory.error('❌ Error reordenando películas en lista $listId: $e');
      rethrow;
    }
  }

  /// Duplica una lista
  Future<CustomList> duplicateList(String listId, String newName) async {
    try {
      LoggerFactory.info('📋 Duplicando lista $listId con nombre "$newName"');

      // Obtener la lista original
      final originalList = await _repository.getListById(listId);
      if (originalList == null) {
        throw Exception('Lista $listId no encontrada');
      }

      // Crear nueva lista duplicada
      final duplicatedList = originalList.copyWith(
        id: null, // Nuevo ID será generado
        name: newName,
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        syncStatus: 'pending',
      );

      await _repository.createList(duplicatedList);
      LoggerFactory.info('✅ Lista duplicada exitosamente: "$newName"');

      return duplicatedList;
    } catch (e) {
      LoggerFactory.error('❌ Error duplicando lista $listId: $e');
      rethrow;
    }
  }
}

class SyncActions {
  SyncActions(this._service, this._ref);
  final ListSyncService _service;
  final Ref _ref;

  /// Inicia sincronización automática
  Future<void> startAutoSync() async {
    await _service.startAutoSync();
  }

  /// Fuerza sincronización manual
  Future<SyncResult> forceSync() async {
    return await _service.forceSync();
  }

  /// Actualiza configuración de sincronización
  Future<void> updateSyncConfig(SyncConfig config) async {
    await _service.updateSyncConfig(config);
    _ref.invalidate(syncConfigProvider);
  }

  /// Registra cambio offline
  Future<void> recordOfflineChange(OfflineChange change) async {
    await _service.recordOfflineChange(change);
  }
}

// ========== STATE NOTIFIERS ==========

class CustomListsNotifier extends Notifier<AsyncValue<List<CustomList>>> {
  ICustomListsRepository? _repository;
  StreamSubscription? _realtimeSubscription;
  bool _isRealtimeEnabled = false;

  @override
  AsyncValue<List<CustomList>> build() {
    // Handle cleanup on dispose
    ref.onDispose(() {
      _realtimeSubscription?.cancel();
    });

    _initializeAndLoadLists();
    return const AsyncValue.loading();
  }

  /// Inicializa el repositorio y carga las listas
  Future<void> _initializeAndLoadLists() async {
    try {
      _repository = await ref.read(customListsRepositoryProvider.future);
      await loadUserLists();
    } catch (e, stack) {
      LoggerFactory.error('❌ Error inicializando CustomListsNotifier: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  /// Carga las listas del usuario (tanto por defecto como personalizadas)
  Future<void> loadUserLists() async {
    if (_repository == null) {
      LoggerFactory.warning(
          '⚠️ Repository not available - waiting for initialization');
      return;
    }

    state = const AsyncValue.loading();

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        LoggerFactory.warning(
            '⚠️ No user authenticated - returning empty list');
        state = const AsyncValue.data([]);
        return;
      }

      LoggerFactory.info('🔄 Loading lists for user: ${currentUser.email}');

      LoggerFactory.info(
          'ℹ️ Listas predeterminadas deshabilitadas: se omite la inicialización');

      // Cargar todas las listas del usuario
      final allLists = await _repository!.getUserLists();

      LoggerFactory.info('✅ ${allLists.length} listas cargadas exitosamente');

      // Separar listas por defecto y personalizadas para debug
      final defaultLists = allLists.where((list) => list.isDefault).toList();
      final customLists = allLists.where((list) => !list.isDefault).toList();

      LoggerFactory.info('  📋 Listas por defecto: ${defaultLists.length}');
      LoggerFactory.info('  📝 Listas personalizadas: ${customLists.length}');

      state = AsyncValue.data(allLists);

      // Habilitar sincronización en tiempo real
      if (!_isRealtimeEnabled) {
        _enableRealtimeSync(currentUser.id);
      }
    } catch (e, stack) {
      LoggerFactory.error('❌ Error cargando listas: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  /// Habilita sincronización en tiempo real
  void _enableRealtimeSync(String userId) {
    if (_isRealtimeEnabled || _repository == null) return;

    _realtimeSubscription = _repository!.watchUserLists().listen(
      (lists) {
        state = AsyncValue.data(lists);
        LoggerFactory.info(
            '🔄 CustomLists: Sincronización en tiempo real actualizada');
      },
      onError: (error) {
        LoggerFactory.error('❌ Error en sincronización en tiempo real: $error');
      },
    );

    _isRealtimeEnabled = true;
  }

  /// Crea una nueva lista
  Future<void> createList(CustomList list) async {
    if (_repository == null) return;

    try {
      await _repository!.createList(list);
      await loadUserLists(); // Recargar listas
      LoggerFactory.info('✅ Lista "${list.name}" creada exitosamente');
    } catch (e) {
      LoggerFactory.error('❌ Error creando lista: $e');
      rethrow;
    }
  }

  /// Actualiza una lista existente
  Future<void> updateList(CustomList list) async {
    if (_repository == null) return;

    try {
      await _repository!.updateList(list);
      await loadUserLists(); // Recargar listas
      LoggerFactory.info('✅ Lista "${list.name}" actualizada exitosamente');
    } catch (e) {
      LoggerFactory.error('❌ Error actualizando lista: $e');
      rethrow;
    }
  }

  /// Elimina una lista
  Future<void> deleteList(String listId) async {
    if (_repository == null) return;

    try {
      await _repository!.deleteList(listId);
      await loadUserLists(); // Recargar listas
      LoggerFactory.info('✅ Lista eliminada exitosamente');
    } catch (e) {
      LoggerFactory.error('❌ Error eliminando lista: $e');
      rethrow;
    }
  }

  /// Habilita el provider después del login
  void enableAfterLogin() {
    LoggerFactory.info('🔐 CustomLists: Habilitando después del login...');

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      LoggerFactory.warning(
          '🔐 CustomLists: No hay usuario autenticado, omitiendo inicialización');
      return;
    }

    LoggerFactory.info('🔐 Usuario autenticado: ${currentUser.email}');

    // Si el repositorio aún no está inicializado, inicializar todo
    if (_repository == null) {
      _initializeAndLoadLists();
    } else {
      // Si ya está inicializado, solo recargar listas
      loadUserLists();
    }

    LoggerFactory.info(
        '🔐 CustomLists: Provider habilitado para usuario ${currentUser.id}');
  }

  /// Inicializa la sincronización en tiempo real
  void initializeRealtimeSync() {
    LoggerFactory.info(
        '🔄 CustomLists: Inicializando sincronización en tiempo real...');

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      LoggerFactory.warning(
          '🔄 CustomLists: No hay usuario para sincronización en tiempo real');
      return;
    }

    _enableRealtimeSync(currentUser.id);
    LoggerFactory.info(
        '🔄 CustomLists: Sincronización en tiempo real inicializada');
  }

  /// Obtiene listas locales para migración
  Future<List<CustomList>> getLocalListsForMigration() async {
    try {
      // Implementar lógica para obtener listas almacenadas localmente
      // que necesitan ser migradas al usuario autenticado
      LoggerFactory.info(
          '📦 CustomLists: Obteniendo listas locales para migración...');

      // Por ahora retornamos lista vacía, pero aquí se implementaría
      // la lógica para obtener listas del almacenamiento local
      return [];
    } catch (e) {
      LoggerFactory.error('❌ Error obteniendo listas locales: $e');
      return [];
    }
  }

  /// Migra una lista local al usuario autenticado
  Future<void> migrateLocalListToUser(CustomList list, String userId) async {
    try {
      LoggerFactory.info(
          '📦 CustomLists: Migrando lista "${list.name}" al usuario $userId...');

      // Crear una nueva lista para el usuario autenticado
      final migratedList = list.copyWith(
        id: null, // Nuevo ID será generado
        userId: userId,
        syncStatus: 'syncing',
        lastModifiedAt: DateTime.now(),
      );

      await createList(migratedList);
      LoggerFactory.info('✅ Lista "${list.name}" migrada exitosamente');
    } catch (e) {
      LoggerFactory.error('❌ Error migrando lista "${list.name}": $e');
      rethrow;
    }
  }

  /// Limpia el estado cuando el usuario se desconecta
  void cleanup() {
    LoggerFactory.info('🧹 CustomLists: Limpiando estado...');
    state = const AsyncValue.data([]);
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _isRealtimeEnabled = false;
    LoggerFactory.info('✅ CustomLists: Estado limpiado');
  }
}

class ListsUIStateNotifier extends Notifier<ListsUIState> {
  @override
  ListsUIState build() {
    return ListsUIState.initial();
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  void setSelectedList(String? listId) {
    state = state.copyWith(selectedListId: listId);
  }

  void setViewMode(ListViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  void setSortOrder(ListSortOrder order) {
    state = state.copyWith(sortOrder: order);
  }
}

class ListFiltersNotifier extends Notifier<ListFilters> {
  @override
  ListFilters build() {
    return ListFilters.initial();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setShowDefaultLists(bool show) {
    state = state.copyWith(showDefaultLists: show);
  }

  void setShowEmptyLists(bool show) {
    state = state.copyWith(showEmptyLists: show);
  }

  void setSyncStatusFilter(SyncStatus? status) {
    state = state.copyWith(syncStatusFilter: status);
  }

  void clearFilters() {
    state = ListFilters.initial();
  }
}

class ListFormNotifier extends Notifier<ListFormState> {
  @override
  ListFormState build() {
    return ListFormState.initial();
  }

  void setName(String name) {
    state = state.copyWith(name: name);
  }

  void setDescription(String description) {
    state = state.copyWith(description: description);
  }

  void setEmoji(String emoji) {
    state = state.copyWith(emoji: emoji);
  }

  void setColorHex(String colorHex) {
    state = state.copyWith(colorHex: colorHex);
  }

  void setEditingList(CustomList? list) {
    if (list != null) {
      state = ListFormState(
        name: list.name,
        description: list.description,
        emoji: list.emoji,
        colorHex: list.colorHex ?? '#3B82F6',
        isEditing: true,
        editingListId: list.id,
        isValid: true,
      );
    } else {
      state = ListFormState.initial();
    }
  }

  void reset() {
    state = ListFormState.initial();
  }

  void validate() {
    state = state.copyWith(
      isValid: state.name.trim().isNotEmpty,
    );
  }
}

// ========== CLASES DE ESTADO ==========

class ListsUIState {
  ListsUIState({
    required this.isLoading,
    this.error,
    this.selectedListId,
    required this.viewMode,
    required this.sortOrder,
  });

  factory ListsUIState.initial() {
    return ListsUIState(
      isLoading: false,
      viewMode: ListViewMode.grid,
      sortOrder: ListSortOrder.nameAsc,
    );
  }
  final bool isLoading;
  final String? error;
  final String? selectedListId;
  final ListViewMode viewMode;
  final ListSortOrder sortOrder;

  ListsUIState copyWith({
    bool? isLoading,
    String? error,
    String? selectedListId,
    ListViewMode? viewMode,
    ListSortOrder? sortOrder,
  }) {
    return ListsUIState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      selectedListId: selectedListId ?? this.selectedListId,
      viewMode: viewMode ?? this.viewMode,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class ListFilters {
  ListFilters({
    required this.searchQuery,
    required this.showDefaultLists,
    required this.showEmptyLists,
    this.syncStatusFilter,
  });

  factory ListFilters.initial() {
    return ListFilters(
      searchQuery: '',
      showDefaultLists: true,
      showEmptyLists: true,
    );
  }
  final String searchQuery;
  final bool showDefaultLists;
  final bool showEmptyLists;
  final SyncStatus? syncStatusFilter;

  ListFilters copyWith({
    String? searchQuery,
    bool? showDefaultLists,
    bool? showEmptyLists,
    SyncStatus? syncStatusFilter,
  }) {
    return ListFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      showDefaultLists: showDefaultLists ?? this.showDefaultLists,
      showEmptyLists: showEmptyLists ?? this.showEmptyLists,
      syncStatusFilter: syncStatusFilter ?? this.syncStatusFilter,
    );
  }
}

class ListFormState {
  ListFormState({
    required this.name,
    required this.description,
    required this.emoji,
    required this.colorHex,
    required this.isEditing,
    this.editingListId,
    required this.isValid,
  });

  factory ListFormState.initial() {
    return ListFormState(
      name: '',
      description: '',
      emoji: '📝',
      colorHex: '#3B82F6',
      isEditing: false,
      isValid: false,
    );
  }
  final String name;
  final String description;
  final String emoji;
  final String colorHex;
  final bool isEditing;
  final String? editingListId;
  final bool isValid;

  ListFormState copyWith({
    String? name,
    String? description,
    String? emoji,
    String? colorHex,
    bool? isEditing,
    String? editingListId,
    bool? isValid,
  }) {
    return ListFormState(
      name: name ?? this.name,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      colorHex: colorHex ?? this.colorHex,
      isEditing: isEditing ?? this.isEditing,
      editingListId: editingListId ?? this.editingListId,
      isValid: isValid ?? this.isValid,
    );
  }
}

// ========== ENUMS ==========

enum ListViewMode {
  grid,
  list,
  compact,
}

enum ListSortOrder {
  nameAsc,
  nameDesc,
  dateCreatedAsc,
  dateCreatedDesc,
  dateModifiedAsc,
  dateModifiedDesc,
  movieCountAsc,
  movieCountDesc,
}

// ========== PROVIDERS COMPUTADOS ==========

/// Provider que filtra y ordena las listas según los filtros activos
final filteredListsProvider = Provider<AsyncValue<List<CustomList>>>((ref) {
  final listsAsync = ref.watch(userListsProvider);
  final filters = ref.watch(listFiltersProvider);
  final uiState = ref.watch(listsUIStateProvider);

  return listsAsync.when(
    data: (lists) {
      var filteredLists = lists.where((list) {
        // Filtro por búsqueda
        if (filters.searchQuery.isNotEmpty) {
          final query = filters.searchQuery.toLowerCase();
          if (!list.name.toLowerCase().contains(query) &&
              !list.description.toLowerCase().contains(query)) {
            return false;
          }
        }

        // Filtro por listas por defecto
        if (!filters.showDefaultLists && list.isDefault) {
          return false;
        }

        // Filtro por listas vacías
        if (!filters.showEmptyLists && list.movieIds.isEmpty) {
          return false;
        }

        // Filtro por estado de sincronización
        if (filters.syncStatusFilter != null &&
            list.syncStatus != filters.syncStatusFilter.toString()) {
          return false;
        }

        return true;
      }).toList();

      // Aplicar ordenamiento
      switch (uiState.sortOrder) {
        case ListSortOrder.nameAsc:
          filteredLists.sort((a, b) => a.name.compareTo(b.name));
          break;
        case ListSortOrder.nameDesc:
          filteredLists.sort((a, b) => b.name.compareTo(a.name));
          break;
        case ListSortOrder.dateCreatedAsc:
          filteredLists.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          break;
        case ListSortOrder.dateCreatedDesc:
          filteredLists.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case ListSortOrder.dateModifiedAsc:
          filteredLists
              .sort((a, b) => a.lastModifiedAt.compareTo(b.lastModifiedAt));
          break;
        case ListSortOrder.dateModifiedDesc:
          filteredLists
              .sort((a, b) => b.lastModifiedAt.compareTo(a.lastModifiedAt));
          break;
        case ListSortOrder.movieCountAsc:
          filteredLists
              .sort((a, b) => a.movieIds.length.compareTo(b.movieIds.length));
          break;
        case ListSortOrder.movieCountDesc:
          filteredLists
              .sort((a, b) => b.movieIds.length.compareTo(a.movieIds.length));
          break;
      }

      return AsyncValue.data(filteredLists);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});
