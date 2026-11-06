import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/entities/list_item.dart';
import 'custom_lists_provider.dart';

/// Provider para obtener los items (películas) de una lista específica
/// Usa streams de Supabase para actualizaciones en tiempo real
final listItemsProvider =
    StreamProvider.family<List<ListItem>, String>((ref, listId) async* {
  try {
    final repository = await ref.watch(customListsRepositoryProvider.future);

    // Stream desde el repository
    await for (final items in repository.watchListItems(listId)) {
      LoggerFactory.info(
          'listItemsProvider: ${items.length} items para lista $listId');
      yield items;
    }
  } catch (e, stackTrace) {
    LoggerFactory.error(
      'Error en listItemsProvider para lista $listId: $e',
      stackTrace: stackTrace,
    );
    yield [];
  }
});

/// Provider para contar las películas en una lista sin cargar todos los items
/// Útil para mostrar el contador sin impacto de performance
final listMovieCountProvider = Provider.family<int, String>((ref, listId) {
  return ref.watch(listItemsProvider(listId)).when(
        data: (items) => items.length,
        loading: () => 0,
        error: (_, _) => 0,
      );
});

/// Provider para verificar si una película específica está en una lista
/// Útil para mostrar checkmarks en UI de selección de listas
final isMovieInListProvider =
    Provider.family<bool, ({int movieId, String listId})>((ref, params) {
  return ref.watch(listItemsProvider(params.listId)).when(
        data: (items) => items.any((item) => item.movieId == params.movieId),
        loading: () => false,
        error: (_, _) => false,
      );
});

/// Provider para obtener todas las listas que contienen una película específica
/// Útil para mostrar "Esta película está en X listas"
final movieListsProvider = Provider.family<List<String>, int>((ref, movieId) {
  final allLists = ref.watch(listsProvider);
  final listsWithMovie = <String>[];

  for (final list in allLists) {
    final hasMovie = ref.watch(isMovieInListProvider(
      (movieId: movieId, listId: list.id),
    ));

    if (hasMovie) {
      listsWithMovie.add(list.id);
    }
  }

  return listsWithMovie;
});

/// Provider para obtener estadísticas de películas en todas las listas
/// Reemplaza el uso de movieIds.length en cada lista
final totalMoviesInListsProvider = Provider<int>((ref) {
  final allLists = ref.watch(listsProvider);
  int total = 0;

  for (final list in allLists) {
    final count = ref.watch(listMovieCountProvider(list.id));
    total += count;
  }

  return total;
});

/// Provider para obtener un item específico de una lista
final listItemByIdProvider =
    Provider.family<ListItem?, ({String listId, String itemId})>(
  (ref, params) {
    return ref.watch(listItemsProvider(params.listId)).when(
          data: (items) => items.firstWhere(
            (item) => item.id == params.itemId,
            orElse: () => throw StateError('Item not found'),
          ),
          loading: () => null,
          error: (_, _) => null,
        );
  },
);
