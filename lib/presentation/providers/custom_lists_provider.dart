import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../../core/gamification/gamification_integration_service.dart';
import '../../core/logging/logger_factory.dart';
import '../../domain/entities/custom_list.dart';
import '../../domain/repositories/i_custom_lists_repository.dart';
import '../../infrastructure/repositories/custom_lists_repository_impl.dart';
import '../../services/list_sync_service.dart';
import 'custom_lists_providers.dart';

// Estado que contiene tanto listas predefinidas como personalizadas
class AllListsState {
  AllListsState({
    required this.defaultLists,
    required this.customLists,
  });
  final List<CustomList> defaultLists;
  final List<CustomList> customLists;

  List<CustomList> get allLists => [...defaultLists, ...customLists];

  AllListsState copyWith({
    List<CustomList>? defaultLists,
    List<CustomList>? customLists,
  }) {
    return AllListsState(
      defaultLists: defaultLists ?? this.defaultLists,
      customLists: customLists ?? this.customLists,
    );
  }
}

// StateNotifier unificado para manejar todas las listas
class AllListsNotifier extends StateNotifier<AllListsState> {
  // Logger usando LoggerFactory directamente

  AllListsNotifier(
      this._repository, this._syncService, this._gamificationService)
      : super(AllListsState(
          defaultLists: [],
          customLists: [],
        )) {
    _loadLists();
    _initializeSync();
  }

  // Constructor para crear notifier con estado inicial (sin dependencias)
  AllListsNotifier.withInitialState()
      : _repository = null,
        _syncService = null,
        _gamificationService = null,
        super(getInitialState());

  ICustomListsRepository? _repository;
  ListSyncService? _syncService;
  final GamificationIntegrationService? _gamificationService;

  /// Configura el repositorio después de la inicialización
  void _setRepository(ICustomListsRepository repository) {
    _repository = repository;
  }

  /// Configura el servicio de sincronización después de la inicialización
  void _setSyncService(ListSyncService syncService) {
    _syncService = syncService;
    _initializeSync();
  }

  /// Inicializa la sincronización y escucha los streams del servicio
  void _initializeSync() {
    if (_syncService == null) return;

    // Escuchar cambios de estado de sincronización
    _syncService!.syncStatusStream.listen((status) {
      LoggerFactory.info('Sync status changed: $status');
    });

    // Escuchar conflictos
    _syncService!.conflictsStream.listen((conflicts) {
      LoggerFactory.warning('Conflicts detected: ${conflicts.length}');
    });

    // Iniciar sincronización automática
    _syncService!.startAutoSync();
  }

  @override
  void dispose() {
    // Limpiar recursos si es necesario
    _syncService?.dispose();
    super.dispose();
  }

  void _loadLists() async {
    if (_repository == null) return;

    try {
      // Cargar listas predefinidas
      final defaultLists = getInitialState().defaultLists;

      // Cargar listas personalizadas usando el servicio de sincronización
      final customLists = await _repository!.getUserLists();

      state = AllListsState(
        defaultLists: defaultLists,
        customLists: customLists,
      );
    } catch (e) {
      LoggerFactory.error('Error loading lists: $e');
    }
  }

  // Guardar listas usando métodos individuales del repositorio
  Future<void> _saveLists() async {
    try {
      if (_repository == null) {
        LoggerFactory.warning('Repository is null, cannot save lists');
        return;
      }

      // Guardar cada lista personalizada
      for (final list in state.customLists) {
        if (!list.isDefault) {
          try {
            await _repository!.createList(list);
            LoggerFactory.info('Lista "${list.name}" guardada exitosamente');
          } catch (e) {
            LoggerFactory.error('Error guardando lista "${list.name}": $e');
          }
        }
      }
    } catch (e) {
      LoggerFactory.error('CustomListsProvider: Error saving lists: $e');
    }
  }

  static AllListsState getInitialState() {
    final now = DateTime.now();

    final defaultLists = [
      CustomList(
        id: 'quiero-ver',
        name: 'Quiero Ver',
        description: 'Películas que quiero ver próximamente',
        emoji: '🍿',
        movieIds: [],
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'blue',
      ),
      CustomList(
        id: 'para-el-fin-de-semana',
        name: 'Para el Fin de Semana',
        description: 'Películas perfectas para relajarse',
        emoji: '🛋️',
        movieIds: [],
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'green',
      ),
      CustomList(
        id: 'noche-de-citas',
        name: 'Noche de Citas',
        description: 'Películas románticas para ver en pareja',
        emoji: '💕',
        movieIds: [],
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'pink',
      ),
      CustomList(
        id: 'con-amigos',
        name: 'Con Amigos',
        description: 'Películas divertidas para ver en grupo',
        emoji: '👥',
        movieIds: [],
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'orange',
      ),
      CustomList(
        id: 'clasicos-pendientes',
        name: 'Clásicos Pendientes',
        description: 'Películas clásicas que debo ver',
        emoji: '🎭',
        movieIds: [],
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'purple',
      ),
      CustomList(
        id: 'accion-y-aventura',
        name: 'Acción y Aventura',
        description: 'Para cuando quiero adrenalina',
        emoji: '💥',
        movieIds: [],
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'red',
      ),
      CustomList(
        id: 'documentales',
        name: 'Documentales',
        description: 'Para aprender algo nuevo',
        emoji: '📚',
        movieIds: [],
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'teal',
      ),
      CustomList(
        id: 'cuando-llueve',
        name: 'Cuando Llueve',
        description: 'Películas perfectas para días lluviosos',
        emoji: '🌧️',
        movieIds: [],
        createdAt: now,
        lastModifiedAt: now,
        isDefault: true,
        color: 'indigo',
      ),
    ];

    return AllListsState(
      defaultLists: defaultLists,
      customLists: [],
    );
  }

  /// Crea una nueva lista personalizada
  Future<void> createCustomList({
    required String name,
    String? description,
    List<int>? movieIds,
  }) async {
    if (_repository == null) {
      LoggerFactory.warning('Cannot create list: repository not available');
      return;
    }

    try {
      // Actualización optimista del estado
      final newList = CustomList(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        description: description ?? '',
        emoji: '📋', // Emoji por defecto
        movieIds: movieIds ?? [],
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
      );

      state = state.copyWith(
        customLists: [...state.customLists, newList],
      );

      // Guardar en el repositorio
      final savedList = await _repository!.createList(newList);

      // Actualizar con el ID real del servidor
      final updatedLists = state.customLists
          .map((list) => list.id == newList.id ? savedList : list)
          .toList();

      state = state.copyWith(customLists: updatedLists);

      // Registrar cambio offline para sincronización
      await _syncService?.recordOfflineChange(OfflineChange(
        id: 'create_${savedList.id}_${DateTime.now().millisecondsSinceEpoch}',
        type: OfflineChangeType.createList,
        data: savedList.toJson(),
        timestamp: DateTime.now(),
      ));

      // Registrar evento de gamificación
      await _gamificationService?.trackListCreated(newList.id, newList.name);

      LoggerFactory.info('✅ Lista personalizada creada: $name');
    } catch (e) {
      LoggerFactory.error('❌ Error al crear lista personalizada: $e');
      // Revertir cambio optimista
      _loadLists();
      rethrow;
    }
  }

  /// Actualiza una lista personalizada existente
  Future<void> updateCustomList({
    required String listId,
    String? name,
    String? description,
  }) async {
    try {
      final currentLists = state.customLists;
      final listIndex = currentLists.indexWhere((list) => list.id == listId);

      if (listIndex == -1) {
        throw Exception('Lista no encontrada: $listId');
      }

      final currentList = currentLists[listIndex];
      final updatedList = currentList.copyWith(
        name: name ?? currentList.name,
        description: description ?? currentList.description,
        lastModifiedAt: DateTime.now(),
      );

      // Actualización optimista del estado
      final updatedLists = [...currentLists];
      updatedLists[listIndex] = updatedList;
      state = state.copyWith(customLists: updatedLists);

      // Guardar en el repositorio
      await _repository?.updateList(updatedList);

      // Registrar cambio offline para sincronización
      await _syncService?.recordOfflineChange(OfflineChange(
        id: 'update_${listId}_${DateTime.now().millisecondsSinceEpoch}',
        type: OfflineChangeType.updateList,
        data: updatedList.toJson(),
        timestamp: DateTime.now(),
      ));

      // Registrar evento de gamificación
      // Note: No specific tracking for list updates in gamification

      LoggerFactory.info(
          '✅ Lista personalizada actualizada: ${updatedList.name}');
    } catch (e) {
      LoggerFactory.error('❌ Error al actualizar lista personalizada: $e');
      // Revertir cambio optimista
      _loadLists();
      rethrow;
    }
  }

  Future<void> createList({
    required String name,
    required String description,
    required String emoji,
    String color = 'blue',
  }) async {
    if (_repository == null) {
      LoggerFactory.error('Repository is null, cannot create list');
      return;
    }

    try {
      final now = DateTime.now();
      const uuid = Uuid();
      final newId = uuid.v4();

      final newList = CustomList(
        id: newId,
        name: name,
        description: description,
        emoji: emoji,
        movieIds: [],
        createdAt: now,
        lastModifiedAt: now,
        isDefault: false,
        color: color,
      );

      // Actualizar estado optimísticamente
      state = state.copyWith(
        customLists: [...state.customLists, newList],
      );

      // Guardar en el repositorio
      await _repository!.createList(newList);

      // Recargar todas las listas desde el repositorio para asegurar consistencia
      _loadLists();

      LoggerFactory.info('Lista "$name" creada exitosamente');
    } catch (e) {
      LoggerFactory.error('Error creando lista: $e');
      // Revertir cambio optimista si hay error
      _loadLists();
      rethrow;
    }
  }

  // Actualizar una lista existente
  void updateList(
    String listId, {
    String? name,
    String? description,
    String? emoji,
    String? color,
  }) {
    // Actualizar en listas personalizadas
    final updatedCustomLists = state.customLists.map((list) {
      if (list.id == listId) {
        return list.copyWith(
          name: name,
          description: description,
          emoji: emoji,
          color: color,
          lastModifiedAt: DateTime.now(),
        );
      }
      return list;
    }).toList();

    // Actualizar en listas predefinidas (solo si es necesario)
    final updatedDefaultLists = state.defaultLists.map((list) {
      if (list.id == listId) {
        return list.copyWith(
          name: name,
          description: description,
          emoji: emoji,
          color: color,
          lastModifiedAt: DateTime.now(),
        );
      }
      return list;
    }).toList();

    state = state.copyWith(
      customLists: updatedCustomLists,
      defaultLists: updatedDefaultLists,
    );
    _saveLists();
  }

  /// Elimina una lista personalizada
  Future<void> deleteCustomList(String listId) async {
    try {
      // Actualización optimista del estado
      final updatedLists =
          state.customLists.where((list) => list.id != listId).toList();

      state = state.copyWith(customLists: updatedLists);

      // Eliminar del repositorio
      await _repository?.deleteList(listId);

      // Registrar cambio offline para sincronización
      await _syncService?.recordOfflineChange(OfflineChange(
        id: 'delete_${listId}_${DateTime.now().millisecondsSinceEpoch}',
        type: OfflineChangeType.deleteList,
        data: {'id': listId},
        timestamp: DateTime.now(),
      ));

      // Registrar evento de gamificación
      final listToDelete =
          state.customLists.firstWhere((list) => list.id == listId);
      await _gamificationService?.trackListDeleted(listId, listToDelete.name);

      LoggerFactory.info('✅ Lista personalizada eliminada: $listId');
    } catch (e) {
      LoggerFactory.error('❌ Error al eliminar lista personalizada: $e');
      // Revertir cambio optimista
      _loadLists();
      rethrow;
    }
  }

  // Eliminar una lista personalizada (solo listas no predefinidas)
  void deleteList(String listId) {
    final updatedCustomLists =
        state.customLists.where((list) => list.id != listId).toList();
    state = state.copyWith(customLists: updatedCustomLists);
    _saveLists();
  }

  // Agregar película a lista
  Future<void> addMovieToList(String listId, int movieId,
      {int? position}) async {
    try {
      // Actualizar estado optimísticamente
      _updateListInState(listId, (list) {
        final newMovieIds = List<int>.from(list.movieIds);
        if (!newMovieIds.contains(movieId)) {
          if (position != null &&
              position >= 0 &&
              position <= newMovieIds.length) {
            newMovieIds.insert(position, movieId);
          } else {
            newMovieIds.add(movieId);
          }
        }
        return list.copyWith(
          movieIds: newMovieIds,
          lastModifiedAt: DateTime.now(),
        );
      });

      // Intentar agregar usando el repositorio
      try {
        await _repository?.addMovieToList(listId, movieId, position: position);
      } catch (e) {
        // Si falla, registrar como cambio offline
        await _syncService?.recordOfflineChange(OfflineChange(
          id: 'add_movie_${listId}_${movieId}_${DateTime.now().millisecondsSinceEpoch}',
          type: OfflineChangeType.addMovie,
          data: {
            'listId': listId,
            'movieId': movieId,
            'position': position,
          },
          timestamp: DateTime.now(),
        ));
      }

      // Registrar evento de gamificación
      await _gamificationService?.trackMovieAddedToList(movieId, listId);
    } catch (e) {
      throw Exception('Error adding movie to list: $e');
    }
  }

  // Helper method to update list in state
  void _updateListInState(
      String listId, CustomList Function(CustomList) updater) {
    final updatedCustomLists = state.customLists.map((list) {
      return list.id == listId ? updater(list) : list;
    }).toList();

    final updatedDefaultLists = state.defaultLists.map((list) {
      return list.id == listId ? updater(list) : list;
    }).toList();

    state = state.copyWith(
      customLists: updatedCustomLists,
      defaultLists: updatedDefaultLists,
    );
  }

  // Remover película de lista
  Future<void> removeMovieFromList(String listId, int movieId) async {
    try {
      // Actualizar estado optimísticamente
      _updateListInState(listId, (list) {
        final newMovieIds = List<int>.from(list.movieIds)..remove(movieId);
        return list.copyWith(
          movieIds: newMovieIds,
          lastModifiedAt: DateTime.now(),
        );
      });

      // Intentar remover usando el repositorio
      try {
        await _repository?.removeMovieFromList(listId, movieId);
      } catch (e) {
        // Si falla, registrar como cambio offline
        await _syncService?.recordOfflineChange(OfflineChange(
          id: 'remove_movie_${listId}_${movieId}_${DateTime.now().millisecondsSinceEpoch}',
          type: OfflineChangeType.removeMovie,
          data: {
            'listId': listId,
            'movieId': movieId,
          },
          timestamp: DateTime.now(),
        ));
      }

      // Registrar evento de gamificación
      // Note: No specific tracking for movie removal in current gamification system
    } catch (e) {
      throw Exception('Error removing movie from list: $e');
    }
  }

  // Alternar película en una lista (añadir si no está, remover si está)
  void toggleMovieInList(String listId, int movieId) {
    final allLists = state.allLists;
    final list = allLists.firstWhere((l) => l.id == listId);
    if (list.movieIds.contains(movieId)) {
      removeMovieFromList(listId, movieId);
    } else {
      addMovieToList(listId, movieId);
    }
  }

  // Reordenar películas en una lista
  void reorderMoviesInList(String listId, int oldIndex, int newIndex) {
    final updatedCustomLists = state.customLists.map((list) {
      if (list.id == listId) {
        final movieIds = [...list.movieIds];
        final movieId = movieIds.removeAt(oldIndex);
        movieIds.insert(newIndex, movieId);

        return list.copyWith(
          movieIds: movieIds,
          lastModifiedAt: DateTime.now(),
        );
      }
      return list;
    }).toList();

    final updatedDefaultLists = state.defaultLists.map((list) {
      if (list.id == listId) {
        final movieIds = [...list.movieIds];
        final movieId = movieIds.removeAt(oldIndex);
        movieIds.insert(newIndex, movieId);

        return list.copyWith(
          movieIds: movieIds,
          lastModifiedAt: DateTime.now(),
        );
      }
      return list;
    }).toList();

    state = state.copyWith(
      customLists: updatedCustomLists,
      defaultLists: updatedDefaultLists,
    );
    _saveLists();
  }

  // Duplicar una lista
  void duplicateList(String listId, String newName) {
    final allLists = state.allLists;
    final originalList = allLists.firstWhere((l) => l.id == listId);
    final now = DateTime.now();
    const uuid = Uuid();
    final newId = uuid.v4();

    final duplicatedList = CustomList(
      id: newId,
      name: newName,
      description: '${originalList.description} (Copia)',
      emoji: originalList.emoji,
      movieIds: [...originalList.movieIds],
      createdAt: now,
      lastModifiedAt: now,
      isDefault: false,
      color: originalList.color,
    );

    state = state.copyWith(
      customLists: [...state.customLists, duplicatedList],
    );
    _saveLists();
  }

  // Limpiar todas las películas de una lista
  void clearList(String listId) {
    final updatedCustomLists = state.customLists.map((list) {
      if (list.id == listId) {
        return list.copyWith(
          movieIds: [],
          lastModifiedAt: DateTime.now(),
        );
      }
      return list;
    }).toList();

    final updatedDefaultLists = state.defaultLists.map((list) {
      if (list.id == listId) {
        return list.copyWith(
          movieIds: [],
          lastModifiedAt: DateTime.now(),
        );
      }
      return list;
    }).toList();

    state = state.copyWith(
      customLists: updatedCustomLists,
      defaultLists: updatedDefaultLists,
    );
    _saveLists();
  }
}

// Provider del repositorio
final customListsRepositoryProvider =
    FutureProvider<ICustomListsRepository>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final supabaseDataSource = ref.watch(supabaseCustomListsDatasourceProvider);
  final connectivity = ref.watch(connectivityProvider);

  return CustomListsRepositoryImpl(supabaseDataSource, prefs, connectivity);
});

// Provider principal que maneja el estado asyncrónicamente
final allListsProvider = FutureProvider<AllListsState>((ref) async {
  try {
    final repository = await ref.watch(customListsRepositoryProvider.future);
    final allUserLists = await repository.getUserLists();

    // Separar listas por defecto y personalizadas desde los datos reales del usuario
    final defaultLists = allUserLists.where((list) => list.isDefault).toList();
    final customLists = allUserLists.where((list) => !list.isDefault).toList();

    LoggerFactory.info(
        'AllListsProvider: ${allUserLists.length} listas totales del usuario');
    LoggerFactory.info(
        'AllListsProvider: ${defaultLists.length} listas por defecto, ${customLists.length} listas personalizadas');

    // Calcular total de películas para debug
    final totalMovies =
        allUserLists.fold(0, (sum, list) => sum + list.movieIds.length);
    LoggerFactory.info(
        'AllListsProvider: Total de películas en todas las listas: $totalMovies');

    return AllListsState(
      defaultLists: defaultLists,
      customLists: customLists,
    );
  } catch (e) {
    LoggerFactory.error('Error loading lists: $e');
    return AllListsNotifier.getInitialState();
  }
});

// Provider simplificado para las operaciones de mutación
final allListsNotifierProvider =
    StateNotifierProvider<AllListsNotifier, AllListsState>((ref) {
  // Crear notifier con estado inicial y configurar dependencias asíncronamente
  final notifier = AllListsNotifier.withInitialState();

  // Configurar dependencias asíncronamente
  ref.read(customListsRepositoryProvider.future).then((repo) {
    notifier._setRepository(repo);
    notifier._loadLists();
  }).catchError((e) {
    LoggerFactory.error('Error setting up repository: $e');
  });

  ref.read(listSyncServiceProvider.future).then((sync) {
    notifier._setSyncService(sync);
  }).catchError((e) {
    LoggerFactory.error('Error setting up sync service: $e');
  });

  return notifier;
});

// Provider para obtener todas las listas
final listsProvider = Provider<List<CustomList>>((ref) {
  final stateAsync = ref.watch(allListsProvider);
  return stateAsync.when(
    data: (data) => data.allLists,
    loading: () => <CustomList>[],
    error: (error, stack) {
      LoggerFactory.error('Error in listsProvider: $error');
      return <CustomList>[];
    },
  );
});

// Provider para obtener solo listas personalizadas
final customListsProvider = Provider<List<CustomList>>((ref) {
  final stateAsync = ref.watch(allListsProvider);
  return stateAsync.when(
    data: (data) => data.customLists,
    loading: () => <CustomList>[],
    error: (error, stack) {
      LoggerFactory.error('Error in customListsProvider: $error');
      return <CustomList>[];
    },
  );
});

// Provider para obtener solo listas predefinidas
final defaultListsProvider = Provider<List<CustomList>>((ref) {
  final state = ref.watch(allListsProvider);
  return state.when(
    data: (data) => data.defaultLists,
    loading: () => <CustomList>[],
    error: (error, stack) {
      LoggerFactory.error('Error in defaultListsProvider: $error');
      return <CustomList>[];
    },
  );
});

// Provider para obtener una lista específica por ID
final listByIdProvider = Provider.family<CustomList?, String>((ref, listId) {
  final allLists = ref.watch(listsProvider);

  for (final list in allLists) {
    if (list.id == listId) return list;
  }

  return null;
});

// Provider para verificar si una película está en una lista específica
final isMovieInListProvider =
    Provider.family<bool, ({int movieId, String listId})>((ref, params) {
  final list = ref.watch(listByIdProvider(params.listId));
  return list?.movieIds.contains(params.movieId) ?? false;
});

// Provider para obtener las listas que contienen una película específica
final movieListsProvider =
    Provider.family<List<CustomList>, int>((ref, movieId) {
  final allLists = ref.watch(listsProvider);
  return allLists.where((list) => list.movieIds.contains(movieId)).toList();
});

// Provider para estadísticas de listas
final listStatsProvider = Provider<Map<String, int>>((ref) {
  final allLists = ref.watch(listsProvider);

  int totalLists = allLists.length;
  int totalMovies = allLists.fold(0, (sum, list) => sum + list.movieIds.length);
  int customLists = allLists.where((list) => !list.isDefault).length;
  int defaultLists = allLists.where((list) => list.isDefault).length;

  return {
    'totalLists': totalLists,
    'totalMovies': totalMovies,
    'customLists': customLists,
    'defaultLists': defaultLists,
  };
});

// Provider para las categorías de listas predefinidas
final listCategoriesProvider = Provider<List<ListCategory>>((ref) {
  return [
    ListCategory(
      id: 'planning',
      name: 'Planificación',
      description: 'Listas para organizar qué ver',
      emoji: '📋',
      color: 'blue',
      lists: [],
    ),
    ListCategory(
      id: 'mood',
      name: 'Por Estado de Ánimo',
      description: 'Listas según tu humor',
      emoji: '🎭',
      color: 'purple',
      lists: [],
    ),
    ListCategory(
      id: 'occasion',
      name: 'Por Ocasión',
      description: 'Listas para momentos especiales',
      emoji: '🎉',
      color: 'orange',
      lists: [],
    ),
    ListCategory(
      id: 'genre',
      name: 'Por Género',
      description: 'Listas organizadas por género',
      emoji: '🎬',
      color: 'green',
      lists: [],
    ),
  ];
});
