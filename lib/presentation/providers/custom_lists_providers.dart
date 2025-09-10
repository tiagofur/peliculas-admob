import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/entities/custom_list.dart';
import '../../domain/entities/list_item.dart';
import '../../domain/repositories/i_custom_lists_repository.dart';
import '../../infrastructure/repositories/custom_lists_repository_impl.dart';
import '../../infrastructure/datasources/supabase_custom_lists_datasource.dart';
import '../../services/list_sync_service.dart';
import '../../services/lists_migration_service.dart';
import '../../services/sync/offline_change.dart';
import '../../infrastructure/datasources/custom_lists_shared_preferences_datasource.dart';
import '../../config/supabase_config.dart';

// ========== PROVIDERS DE DEPENDENCIAS ==========

/// Provider para SharedPreferences
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

/// Provider para Connectivity
final connectivityProvider = Provider<Connectivity>((ref) {
  return Connectivity();
});

/// Provider para el datasource de Supabase
final supabaseCustomListsDatasourceProvider = Provider<SupabaseCustomListsDatasource>((ref) {
  return SupabaseCustomListsDatasource(SupabaseConfig.client);
});

/// Provider para el repositorio de listas personalizadas
final customListsRepositoryProvider = Provider<ICustomListsRepository>((ref) {
  final datasource = ref.watch(supabaseCustomListsDatasourceProvider);
  return CustomListsRepositoryImpl(datasource);
});

/// Provider para el servicio de sincronización
final listSyncServiceProvider = FutureProvider<ListSyncService>((ref) async {
  final repository = ref.watch(customListsRepositoryProvider);
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final connectivity = ref.watch(connectivityProvider);
  
  return ListSyncService(repository, prefs, connectivity);
});

/// Provider para el datasource local de SharedPreferences
final customListsSharedPreferencesDatasourceProvider = FutureProvider<CustomListsSharedPreferencesDatasource>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return CustomListsSharedPreferencesDatasource(prefs);
});

/// Provider para el servicio de migración de listas
final listsMigrationServiceProvider = FutureProvider<ListsMigrationService>((ref) async {
  final localDatasource = await ref.watch(customListsSharedPreferencesDatasourceProvider.future);
  final remoteDatasource = ref.watch(supabaseCustomListsDatasourceProvider);
  
  return ListsMigrationService(
    localDatasource: localDatasource,
    remoteDatasource: remoteDatasource,
  );
});

// ========== PROVIDERS DE ESTADO ==========

/// Provider para listas del usuario actual
final userListsProvider = StreamProvider<List<CustomList>>((ref) {
  final repository = ref.watch(customListsRepositoryProvider);
  return repository.getUserListsStream();
});

/// Provider principal para el notifier de listas personalizadas
final customListsNotifierProvider = StateNotifierProvider<CustomListsNotifier, AsyncValue<List<CustomList>>>((ref) {
  final repository = ref.watch(customListsRepositoryProvider);
  return CustomListsNotifier(repository);
});

/// Provider para listas por defecto
final defaultListsProvider = FutureProvider<List<CustomList>>((ref) async {
  final repository = ref.watch(customListsRepositoryProvider);
  return await repository.getDefaultLists();
});

/// Provider para una lista específica por ID
final listByIdProvider = StreamProvider.family<CustomList?, String>((ref, listId) {
  final repository = ref.watch(customListsRepositoryProvider);
  return repository.getListStream(listId);
});

/// Provider para elementos de una lista específica
final listItemsProvider = StreamProvider.family<List<ListItem>, String>((ref, listId) {
  final repository = ref.watch(customListsRepositoryProvider);
  return repository.getListItemsStream(listId);
});

/// Provider para el estado de sincronización
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  return ref.watch(listSyncServiceProvider.future).then((service) {
    return service.syncStatusStream;
  }).asStream().asyncExpand((stream) => stream);
});

/// Provider para conflictos de sincronización
final syncConflictsProvider = StreamProvider<List<ConflictInfo>>((ref) {
  return ref.watch(listSyncServiceProvider.future).then((service) {
    return service.conflictsStream;
  }).asStream().asyncExpand((stream) => stream);
});

/// Provider para configuración de sincronización
final syncConfigProvider = FutureProvider<SyncConfig>((ref) async {
  final service = await ref.watch(listSyncServiceProvider.future);
  return service.getSyncConfig();
});

// ========== PROVIDERS DE ACCIONES ==========

/// Provider para acciones de listas
final listActionsProvider = Provider<ListActions>((ref) {
  final repository = ref.watch(customListsRepositoryProvider);
  return ListActions(repository, ref);
});

/// Provider para acciones de sincronización
final syncActionsProvider = FutureProvider<SyncActions>((ref) async {
  final service = await ref.watch(listSyncServiceProvider.future);
  return SyncActions(service, ref);
});



// ========== PROVIDERS DE UI STATE ==========

/// Provider para el estado de la UI de listas
final listsUIStateProvider = StateNotifierProvider<ListsUIStateNotifier, ListsUIState>((ref) {
  return ListsUIStateNotifier();
});

/// Provider para filtros de listas
final listFiltersProvider = StateNotifierProvider<ListFiltersNotifier, ListFilters>((ref) {
  return ListFiltersNotifier();
});

/// Provider para el estado de creación/edición de listas
final listFormProvider = StateNotifierProvider<ListFormNotifier, ListFormState>((ref) {
  return ListFormNotifier();
});

// ========== CLASES DE ACCIONES ==========

class ListActions {
  final ICustomListsRepository _repository;
  final Ref _ref;
  
  ListActions(this._repository, this._ref);
  
  /// Crea una nueva lista
  Future<CustomList> createList({
    required String name,
    String? description,
    String? emoji,
    String? colorHex,
  }) async {
    final newList = CustomList(
      id: '', // Se generará en el servidor
      name: name,
      description: description ?? '',
      emoji: emoji ?? '📝',
      colorHex: colorHex ?? '#3B82F6',
      movieIds: [],
      isDefault: false,
      userId: '', // Se obtendrá del contexto de autenticación
      createdAt: DateTime.now(),
      lastModifiedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
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
  Future<void> addMovieToList(String listId, int movieId, {int? position}) async {
    await _repository.addMovieToList(listId, movieId, position: position);
  }
  
  /// Remueve una película de una lista
  Future<void> removeMovieFromList(String listId, int movieId) async {
    await _repository.removeMovieFromList(listId, movieId);
  }
  
  /// Reordena películas en una lista
  Future<void> reorderMoviesInList(String listId, List<int> newOrder) async {
    await _repository.reorderMoviesInList(listId, newOrder);
  }
  
  /// Duplica una lista
  Future<CustomList> duplicateList(String listId, String newName) async {
    return await _repository.duplicateList(listId, newName);
  }
}

class SyncActions {
  final ListSyncService _service;
  final Ref _ref;
  
  SyncActions(this._service, this._ref);
  
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

class CustomListsNotifier extends StateNotifier<AsyncValue<List<CustomList>>> {
  CustomListsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadUserLists();
  }
  
  final ICustomListsRepository _repository;
  StreamSubscription? _realtimeSubscription;
  bool _isRealtimeEnabled = false;
  
  /// Carga las listas del usuario actual
  Future<void> loadUserLists() async {
    try {
      state = const AsyncValue.loading();
      final lists = await _repository.getUserLists();
      state = AsyncValue.data(lists);
      LoggerFactory.info('✅ CustomLists: ${lists.length} listas cargadas');
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      LoggerFactory.error('❌ Error cargando listas: $e');
    }
  }
  
  /// Habilita sincronización en tiempo real
  void _enableRealtimeSync(String userId) {
    if (_isRealtimeEnabled) return;
    
    _realtimeSubscription = _repository.getUserListsStream().listen(
      (lists) {
        state = AsyncValue.data(lists);
        LoggerFactory.info('🔄 CustomLists: Sincronización en tiempo real actualizada');
      },
      onError: (error) {
        LoggerFactory.error('❌ Error en sincronización en tiempo real: $error');
      },
    );
    
    _isRealtimeEnabled = true;
  }
  
  /// Crea una nueva lista
  Future<void> createList(CustomList list) async {
    try {
      await _repository.createList(list);
      await loadUserLists(); // Recargar listas
      LoggerFactory.info('✅ Lista "${list.name}" creada exitosamente');
    } catch (e) {
      LoggerFactory.error('❌ Error creando lista: $e');
      rethrow;
    }
  }
  
  /// Actualiza una lista existente
  Future<void> updateList(CustomList list) async {
    try {
      await _repository.updateList(list);
      await loadUserLists(); // Recargar listas
      LoggerFactory.info('✅ Lista "${list.name}" actualizada exitosamente');
    } catch (e) {
      LoggerFactory.error('❌ Error actualizando lista: $e');
      rethrow;
    }
  }
  
  /// Elimina una lista
  Future<void> deleteList(String listId) async {
    try {
      await _repository.deleteList(listId);
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
    
    // Cargar listas del usuario
    loadUserLists();
    LoggerFactory.info('🔐 CustomLists: Provider habilitado para usuario ${currentUser.id}');
  }
  
  /// Inicializa la sincronización en tiempo real
  void initializeRealtimeSync() {
    LoggerFactory.info('🔄 CustomLists: Inicializando sincronización en tiempo real...');
    
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      LoggerFactory.warning(
          '🔄 CustomLists: No hay usuario para sincronización en tiempo real');
      return;
    }
    
    _enableRealtimeSync(currentUser.id);
    LoggerFactory.info('🔄 CustomLists: Sincronización en tiempo real inicializada');
  }
  
  /// Obtiene listas locales para migración
  Future<List<CustomList>> getLocalListsForMigration() async {
    try {
      // Implementar lógica para obtener listas almacenadas localmente
      // que necesitan ser migradas al usuario autenticado
      LoggerFactory.info('📦 CustomLists: Obteniendo listas locales para migración...');
      
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
      LoggerFactory.info('📦 CustomLists: Migrando lista "${list.name}" al usuario $userId...');
      
      // Crear una nueva lista para el usuario autenticado
      final migratedList = list.copyWith(
        id: null, // Nuevo ID será generado
        userId: userId,
        syncStatus: SyncStatus.pending,
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
  
  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}

class ListsUIStateNotifier extends StateNotifier<ListsUIState> {
  ListsUIStateNotifier() : super(ListsUIState.initial());
  
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

class ListFiltersNotifier extends StateNotifier<ListFilters> {
  ListFiltersNotifier() : super(ListFilters.initial());
  
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

class ListFormNotifier extends StateNotifier<ListFormState> {
  ListFormNotifier() : super(ListFormState.initial());
  
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
  final bool isLoading;
  final String? error;
  final String? selectedListId;
  final ListViewMode viewMode;
  final ListSortOrder sortOrder;
  
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
  final String searchQuery;
  final bool showDefaultLists;
  final bool showEmptyLists;
  final SyncStatus? syncStatusFilter;
  
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
  final String name;
  final String description;
  final String emoji;
  final String colorHex;
  final bool isEditing;
  final String? editingListId;
  final bool isValid;
  
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
            list.syncStatus != filters.syncStatusFilter) {
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
          filteredLists.sort((a, b) => a.lastModifiedAt.compareTo(b.lastModifiedAt));
          break;
        case ListSortOrder.dateModifiedDesc:
          filteredLists.sort((a, b) => b.lastModifiedAt.compareTo(a.lastModifiedAt));
          break;
        case ListSortOrder.movieCountAsc:
          filteredLists.sort((a, b) => a.movieIds.length.compareTo(b.movieIds.length));
          break;
        case ListSortOrder.movieCountDesc:
          filteredLists.sort((a, b) => b.movieIds.length.compareTo(a.movieIds.length));
          break;
      }
      
      return AsyncValue.data(filteredLists);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});