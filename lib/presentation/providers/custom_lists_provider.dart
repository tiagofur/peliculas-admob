import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/gamification/gamification_integration_service.dart';
import '../../core/logging/logger_factory.dart';
import '../../domain/entities/custom_list.dart';
import '../../domain/entities/list_item.dart';
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

// Notificador principal para gestionar todas las listas
class AllListsNotifier extends Notifier<AllListsState> {
  AllListsNotifier();

  Future<GamificationIntegrationService?>? _gamificationServiceFuture;

  Future<GamificationIntegrationService?> _resolveGamificationService() {
    _gamificationServiceFuture ??= _loadGamificationService();
    return _gamificationServiceFuture!;
  }

  Future<GamificationIntegrationService?> _loadGamificationService() async {
    return ref.read(gamificationIntegrationServiceProvider.future);
  }

  Future<void> _runGamificationAction(
    Future<void> Function(GamificationIntegrationService service) action,
  ) async {
    GamificationIntegrationService? service;
    try {
      service = await _resolveGamificationService();
    } catch (error, stackTrace) {
      LoggerFactory.error(
        'Failed to resolve gamification service: $error',
        stackTrace: stackTrace,
      );
      _gamificationServiceFuture = null;
      return;
    }

    if (service == null) {
      LoggerFactory.debug(
        'Skipping gamification action: service not available',
      );
      _gamificationServiceFuture = null;
      return;
    }

    try {
      await action(service);
    } catch (error, stackTrace) {
      LoggerFactory.error(
        'Error running gamification action: $error',
        stackTrace: stackTrace,
      );
    }
  }

  @override
  AllListsState build() {
    _loadLists();
    return AllListsState(defaultLists: [], customLists: []);
  }

  ICustomListsRepository get _repository =>
      ref.watch(customListsRepositoryProvider).when(
            data: (repo) => repo,
            loading: () => throw StateError('Repository not loaded'),
            error: (err, stack) => throw err,
          );

  ListSyncService get _syncService => ref.watch(listSyncServiceProvider).when(
        data: (service) => service,
        loading: () => throw StateError('Sync service not loaded'),
        error: (err, stack) => throw err,
      );

  /// Cargar listas desde el repositorio
  Future<void> _loadLists() async {
    try {
      final allUserLists = await _repository.getUserLists();
      final defaultLists =
          allUserLists.where((list) => list.isDefault).toList();
      final customLists =
          allUserLists.where((list) => !list.isDefault).toList();

      state = AllListsState(
        defaultLists: defaultLists,
        customLists: customLists,
      );
    } catch (e) {
      LoggerFactory.error('Error loading lists: $e');
    }
  }

  /// Guardar cambios en el repositorio
  Future<void> _saveLists() async {
    // Este método puede ser usado para sincronizar cambios si es necesario
    // En este caso, los cambios ya se guardan individualmente en cada método
  }

  /// Obtener estado inicial
  static AllListsState getInitialState() {
    return AllListsState(defaultLists: [], customLists: []);
  }

  Future<void> updateListAsync(
    String listId, {
    String? name,
    String? description,
  }) async {
    try {
      final currentLists = state.customLists;
      final listIndex = currentLists.indexWhere((list) => list.id == listId);

      if (listIndex == -1) {
        LoggerFactory.warning(
            '⚠️ customListsProvider.updateListAsync: lista $listId no encontrada en estado, se omite actualización');
        return;
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
      await _repository.updateList(updatedList);

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
      await _repository.createList(newList);

      // Recargar todas las listas desde el repositorio para asegurar consistencia
      _loadLists();

      LoggerFactory.info('Lista "$name" creada exitosamente');

      await _runGamificationAction(
        (service) => service.trackListCreated(newId, name),
      );
    } catch (e) {
      LoggerFactory.error('Error creando lista: $e');
      // Revertir cambio optimista si hay error
      _loadLists();
      rethrow;
    }
  }

  // Actualizar una lista existente (síncrono para el estado local)
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
  }

  /// Elimina una lista personalizada
  Future<void> deleteCustomList(String listId) async {
    try {
      final listIndex =
          state.customLists.indexWhere((list) => list.id == listId);
      final CustomList? listToDelete =
          listIndex != -1 ? state.customLists[listIndex] : null;

      // Actualización optimista del estado
      final updatedLists =
          state.customLists.where((list) => list.id != listId).toList();

      state = state.copyWith(customLists: updatedLists);

      // Eliminar del repositorio
      await _repository.deleteList(listId);

      // Registrar cambio offline para sincronización
      await _syncService.recordOfflineChange(OfflineChange(
        id: 'delete_${listId}_${DateTime.now().millisecondsSinceEpoch}',
        type: OfflineChangeType.deleteList,
        data: {'id': listId},
        timestamp: DateTime.now(),
      ));

      // Registrar evento de gamificación
      if (listToDelete != null) {
        await _runGamificationAction(
          (service) => service.trackListDeleted(listId, listToDelete.name),
        );
      }

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

  /// Agregar película a lista
  ///
  /// MIGRADO: Ya no manipula movieIds directamente.
  /// Usa el repository y confía en los streams para actualizar UI.
  Future<void> addMovieToList(String listId, int movieId,
      {int? position}) async {
    try {
      // Verificar si ya existe antes de agregar (para gamificación)
      final wasAlreadyInList = await _repository.isMovieInList(listId, movieId);

      // Agregar usando el repositorio
      // Los streams de listItemsProvider actualizarán la UI automáticamente
      try {
        await _repository.addMovieToList(listId, movieId, position: position);

        LoggerFactory.info('✅ Película $movieId agregada a lista $listId');
      } catch (e) {
        LoggerFactory.warning(
            '⚠️ Error al agregar película, registrando como cambio offline: $e');

        // Si falla, registrar como cambio offline
        await _syncService.recordOfflineChange(OfflineChange(
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

      // Registrar evento de gamificación solo si es nueva
      if (!wasAlreadyInList) {
        await _runGamificationAction(
          (service) => service.trackMovieAddedToList(movieId, listId),
        );
      }
    } catch (e) {
      LoggerFactory.error('❌ Error al agregar película a lista: $e');
      rethrow;
    }
  }

  /// Remover película de lista
  ///
  /// MIGRADO: Ya no manipula movieIds directamente.
  /// Usa el repository y confía en los streams para actualizar UI.
  Future<void> removeMovieFromList(String listId, int movieId) async {
    try {
      // Remover usando el repositorio
      // Los streams de listItemsProvider actualizarán la UI automáticamente
      try {
        await _repository.removeMovieFromList(listId, movieId);

        LoggerFactory.info('✅ Película $movieId removida de lista $listId');
      } catch (e) {
        LoggerFactory.warning(
            '⚠️ Error al remover película, registrando como cambio offline: $e');

        // Si falla, registrar como cambio offline
        await _syncService.recordOfflineChange(OfflineChange(
          id: 'remove_movie_${listId}_${movieId}_${DateTime.now().millisecondsSinceEpoch}',
          type: OfflineChangeType.removeMovie,
          data: {
            'listId': listId,
            'movieId': movieId,
          },
          timestamp: DateTime.now(),
        ));
      }

      // Note: No specific tracking for movie removal in current gamification system
    } catch (e) {
      LoggerFactory.error('❌ Error al remover película de lista: $e');
      rethrow;
    }
  }

  /// Alternar película en una lista (añadir si no está, remover si está)
  ///
  /// MIGRADO: Usa el repository directamente en lugar de acceder a movieIds.
  Future<void> toggleMovieInList(String listId, int movieId) async {
    try {
      // Verificar si la película ya está en la lista usando el repository
      final isInList = await _repository.isMovieInList(listId, movieId);

      if (isInList) {
        await removeMovieFromList(listId, movieId);
      } else {
        await addMovieToList(listId, movieId);
      }
    } catch (e) {
      LoggerFactory.error('❌ Error al alternar película en lista: $e');
      rethrow;
    }
  }

  /// Reordenar películas en una lista
  ///
  /// MIGRADO: Usa el repository para reordenar items.
  /// Los streams actualizarán la UI automáticamente.
  Future<void> reorderMoviesInList(
      String listId, int oldIndex, int newIndex) async {
    try {
      // Obtener items actuales de la lista
      final items = await _repository.getListItems(listId);

      // Reordenar
      final reorderedItems = List<ListItem>.from(items);
      final item = reorderedItems.removeAt(oldIndex);
      reorderedItems.insert(newIndex, item);

      // Actualizar posiciones
      for (var i = 0; i < reorderedItems.length; i++) {
        reorderedItems[i] = reorderedItems[i].copyWith(position: i);
      }

      // Guardar en repository
      await _repository.reorderListItems(listId, reorderedItems);

      LoggerFactory.info('✅ Películas reordenadas en lista $listId');
    } catch (e) {
      LoggerFactory.error('❌ Error al reordenar películas: $e');
      rethrow;
    }
  }

  /// Duplicar una lista
  ///
  /// MIGRADO: Usa el repository para duplicar lista con sus películas.
  Future<void> duplicateList(String listId, String newName) async {
    try {
      // Duplicar usando el repository (incluye las películas)
      final duplicatedList = await _repository.duplicateList(listId, newName);

      // Recargar listas para reflejar el cambio
      await _loadLists();

      LoggerFactory.info('✅ Lista duplicada: $newName');

      await _runGamificationAction(
        (service) => service.trackListCreated(duplicatedList.id, newName),
      );
    } catch (e) {
      LoggerFactory.error('❌ Error al duplicar lista: $e');
      rethrow;
    }
  }

  /// Limpiar todas las películas de una lista
  ///
  /// MIGRADO: Usa el repository para eliminar todos los items.
  /// Los streams actualizarán la UI automáticamente.
  Future<void> clearList(String listId) async {
    try {
      // Limpiar usando el repository
      await _repository.clearListMovies(listId);

      LoggerFactory.info('✅ Lista limpiada: $listId');
    } catch (e) {
      LoggerFactory.error('❌ Error al limpiar lista: $e');
      rethrow;
    }
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
    return AllListsState(defaultLists: [], customLists: []);
  }
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
@Deprecated(
    'Usa el nuevo isMovieInListProvider de list_items_provider.dart que usa streams. '
    'Este provider será eliminado en la próxima versión mayor. '
    'Ejemplo: ref.watch(isMovieInListProvider(listId: listId, movieId: movieId))')
final isMovieInListProviderOld =
    Provider.family<bool, ({int movieId, String listId})>((ref, params) {
  final list = ref.watch(listByIdProvider(params.listId));
  return list?.movieIds.contains(params.movieId) ?? false;
});

// Provider para obtener las listas que contienen una película específica
@Deprecated(
    'Usa el nuevo movieListsProvider de list_items_provider.dart que usa streams. '
    'Este provider será eliminado en la próxima versión mayor. '
    'Ejemplo: ref.watch(movieListsProvider(movieId))')
final movieListsProviderOld =
    Provider.family<List<CustomList>, int>((ref, movieId) {
  final allLists = ref.watch(listsProvider);
  return allLists.where((list) => list.movieIds.contains(movieId)).toList();
});

// Provider para estadísticas de listas
// MIGRADO PARCIAL: Usa totalMoviesInListsProvider para contar películas
final listStatsProvider = Provider<Map<String, int>>((ref) {
  final allLists = ref.watch(listsProvider);

  int totalLists = allLists.length;
  // NUEVO: Usar provider basado en streams para contar películas
  int totalMovies = ref.watch(totalMoviesInListsProvider);
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
