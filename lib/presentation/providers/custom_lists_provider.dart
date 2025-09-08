import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/gamification/gamification_manager.dart';
import '../../core/gamification/models/activity_type.dart';
import '../../core/services/logger_factory.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/custom_lists_repository.dart';
import '../../infrastructure/datasources/custom_lists_shared_preferences_datasource.dart';
import '../../infrastructure/repositories/custom_lists_repository_impl.dart';
import 'gamification_providers.dart';

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
  AllListsNotifier(this._repository, this._ref) : super(_getInitialState()) {
    _gamificationManager = _ref.read(gamificationManagerProvider);
    _loadCustomLists();
  }

  final CustomListsRepository _repository;
  final Ref _ref;
  late final GamificationManager _gamificationManager;

  @override
  void dispose() {
    // Limpiar recursos si es necesario
    // _gamificationService?.dispose(); // Cuando se implemente
    super.dispose();
  }

  // Cargar listas personalizadas y predeterminadas desde el almacenamiento
  Future<void> _loadCustomLists() async {
    try {
      final customLists = await _repository.getCustomLists();
      final savedDefaultLists = await _repository.getDefaultLists();

      List<CustomList> finalDefaultLists;

      if (savedDefaultLists.isNotEmpty) {
        // Si hay listas guardadas, fusionar con las iniciales para preservar movieIds
        final initialDefaultLists = state.defaultLists;
        finalDefaultLists = initialDefaultLists.map((initialList) {
          // Buscar la lista correspondiente en las guardadas
          final savedList = savedDefaultLists.firstWhere(
            (saved) => saved.id == initialList.id,
            orElse: () => initialList, // Si no se encuentra, usar la inicial
          );

          // Preservar movieIds de la lista guardada pero mantener otros datos actualizados
          return initialList.copyWith(
            movieIds: savedList.movieIds,
            lastModifiedAt: savedList.lastModifiedAt,
          );
        }).toList();
      } else {
        // Si no hay listas guardadas, usar las iniciales y guardarlas inmediatamente
        finalDefaultLists = state.defaultLists;
        await _repository.saveDefaultLists(finalDefaultLists);
      }

      state = state.copyWith(
        customLists: customLists,
        defaultLists: finalDefaultLists,
      );
    } catch (e) {
      // En caso de error, mantener el estado inicial
      LoggerFactory.error('Error loading lists: $e',
          tag: 'CustomListsProvider');
    }
  }

  // Guardar tanto listas personalizadas como predeterminadas
  Future<void> _saveCustomLists() async {
    try {
      await _repository.saveCustomLists(state.customLists);
      await _repository.saveDefaultLists(state.defaultLists);
    } catch (e) {
      LoggerFactory.error('CustomListsProvider: Error saving lists: $e');
    }
  }

  static AllListsState _getInitialState() {
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

  void createList({
    required String name,
    required String description,
    required String emoji,
    String color = 'blue',
  }) {
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

    state = state.copyWith(
      customLists: [...state.customLists, newList],
    );
    _saveCustomLists();
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
    _saveCustomLists();
  }

  // Eliminar una lista personalizada (solo listas no predefinidas)
  void deleteList(String listId) {
    final updatedCustomLists =
        state.customLists.where((list) => list.id != listId).toList();
    state = state.copyWith(customLists: updatedCustomLists);
    _saveCustomLists();
  }

  // Añadir película a una lista
  void addMovieToList(String listId, int movieId) {
    bool movieAdded = false;
    String? listName;

    final updatedCustomLists = state.customLists.map((list) {
      if (list.id == listId && !list.movieIds.contains(movieId)) {
        movieAdded = true;
        listName = list.name;
        final updatedMovieIds = [...list.movieIds, movieId];
        return list.copyWith(
          movieIds: updatedMovieIds,
          lastModifiedAt: DateTime.now(),
        );
      }
      return list;
    }).toList();

    final updatedDefaultLists = state.defaultLists.map((list) {
      if (list.id == listId && !list.movieIds.contains(movieId)) {
        movieAdded = true;
        listName = list.name;
        final updatedMovieIds = [...list.movieIds, movieId];
        return list.copyWith(
          movieIds: updatedMovieIds,
          lastModifiedAt: DateTime.now(),
        );
      }
      return list;
    }).toList();

    state = state.copyWith(
      customLists: updatedCustomLists,
      defaultLists: updatedDefaultLists,
    );
    _saveCustomLists();

    // Track gamification event
    if (movieAdded) {
      _gamificationManager.trackActivity(
          ActivityType
              .completeWatchlist, // Using a similar existing activity type
          metadata: {'listName': listName, 'movieId': movieId});
    }
  }

  // Remover película de una lista
  void removeMovieFromList(String listId, int movieId) {
    final updatedCustomLists = state.customLists.map((list) {
      if (list.id == listId) {
        final updatedMovieIds =
            list.movieIds.where((id) => id != movieId).toList();
        return list.copyWith(
          movieIds: updatedMovieIds,
          lastModifiedAt: DateTime.now(),
        );
      }
      return list;
    }).toList();

    final updatedDefaultLists = state.defaultLists.map((list) {
      if (list.id == listId) {
        final updatedMovieIds =
            list.movieIds.where((id) => id != movieId).toList();
        return list.copyWith(
          movieIds: updatedMovieIds,
          lastModifiedAt: DateTime.now(),
        );
      }
      return list;
    }).toList();

    state = state.copyWith(
      customLists: updatedCustomLists,
      defaultLists: updatedDefaultLists,
    );
    _saveCustomLists();
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
    _saveCustomLists();
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
    _saveCustomLists();
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
    _saveCustomLists();
  }
}

// Provider del repositorio
final customListsRepositoryProvider = Provider<CustomListsRepository>((ref) {
  return CustomListsRepositoryImpl(CustomListsSharedPreferencesDatasource(), ref);
});

// Provider principal unificado
final allListsProvider =
    StateNotifierProvider<AllListsNotifier, AllListsState>((ref) {
  final repository = ref.watch(customListsRepositoryProvider);
  return AllListsNotifier(repository, ref);
});

// Provider para obtener todas las listas
final listsProvider = Provider<List<CustomList>>((ref) {
  final state = ref.watch(allListsProvider);
  return state.allLists;
});

// Provider para obtener solo listas personalizadas
final customListsProvider = Provider<List<CustomList>>((ref) {
  final state = ref.watch(allListsProvider);
  return state.customLists;
});

// Provider para obtener solo listas predefinidas
final defaultListsProvider = Provider<List<CustomList>>((ref) {
  final state = ref.watch(allListsProvider);
  return state.defaultLists;
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
