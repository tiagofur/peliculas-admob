import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/custom_list.dart';
import '../../domain/entities/movie.dart';
import '../../domain/repositories/custom_lists_repository.dart';
import '../datasources/custom_lists_shared_preferences_datasource.dart';

class CustomListsRepositoryImpl extends CustomListsRepository {
  CustomListsRepositoryImpl(this.datasource, this.ref);

  final CustomListsDatasource datasource;
  final Ref ref;

  @override
  Future<List<CustomList>> getCustomLists() {
    return datasource.getCustomLists();
  }

  @override
  Future<CustomList?> getCustomListById(String listId) async {
    final lists = await datasource.getCustomLists();
    try {
      return lists.firstWhere((list) => list.id == listId);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<CustomList> createCustomList({
    required String name,
    String? description,
    bool isPublic = false,
  }) async {
    final now = DateTime.now();
    final newList = CustomList(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description ?? '',
      emoji: '📝',
      movieIds: [],
      createdAt: now,
      lastModifiedAt: now,
      isDefault: false,
      color: 'blue',
    );

    await datasource.addCustomList(newList);

    // La sincronización se manejará automáticamente
    return newList;
  }

  @override
  Future<CustomList> updateCustomList(CustomList list) async {
    await datasource.updateCustomList(list);

    // La sincronización se manejará automáticamente
    return list;
  }

  @override
  Future<void> deleteCustomList(String listId) async {
    await datasource.deleteCustomList(listId);

    // La sincronización se manejará automáticamente
  }

  @override
  Future<void> addMovieToList(String listId, Movie movie) async {
    final list = await getCustomListById(listId);
    if (list != null) {
      final updatedList = list.copyWith(
        movieIds: [...list.movieIds, movie.id],
        lastModifiedAt: DateTime.now(),
      );
      await updateCustomList(updatedList);
    }
  }

  @override
  Future<void> removeMovieFromList(String listId, int movieId) async {
    final list = await getCustomListById(listId);
    if (list != null) {
      final updatedList = list.copyWith(
        movieIds: list.movieIds.where((id) => id != movieId).toList(),
        lastModifiedAt: DateTime.now(),
      );
      await updateCustomList(updatedList);
    }
  }

  @override
  Future<List<Movie>> getMoviesInList(String listId) async {
    // Esta implementación requiere acceso al repositorio de películas
    // Por ahora retornamos una lista vacía
    return [];
  }

  @override
  Future<void> syncWithRemote() async {
    // La sincronización se maneja automáticamente por el sistema
  }

  @override
  Future<void> clearLocalData() {
    return datasource.clearAllCustomLists();
  }

  @override
  Future<bool> hasPendingSync() async {
    // Por ahora siempre retornar false, el sistema maneja la sincronización automáticamente
    return false;
  }

  // Métodos adicionales para compatibilidad con el código existente
  @override
  Future<void> saveCustomLists(List<CustomList> lists) async {
    return datasource.saveCustomLists(lists);
  }

  Future<void> addCustomList(CustomList list) async {
    await datasource.addCustomList(list);
    // La sincronización se manejará automáticamente
  }

  Future<void> clearAllCustomLists() {
    return datasource.clearAllCustomLists();
  }

  @override
  Future<List<CustomList>> getDefaultLists() async {
    return datasource.getDefaultLists();
  }

  @override
  Future<void> saveDefaultLists(List<CustomList> lists) async {
    return datasource.saveDefaultLists(lists);
  }
}
