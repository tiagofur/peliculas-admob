import 'package:hive/hive.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/entities/custom_list.dart';

/// Datasource local para Custom Lists usando Hive
class CustomListsHiveDataSource {
  static const String _boxName = 'custom_lists_cache';
  static const String _itemsBoxName = 'custom_list_items_cache';

  /// Obtiene todas las listas del cache local
  Future<List<CustomList>> getAllCachedLists() async {
    try {
      final box = await Hive.openBox<Map>(_boxName);
      final itemsBox = await Hive.openBox<List<int>>(_itemsBoxName);

      final customLists = <CustomList>[];

      for (final entry in box.toMap().entries) {
        try {
          final listData = Map<String, dynamic>.from(entry.value);
          final listId = entry.key as String;

          // Obtener los movie IDs de la caja de items
          final movieIds = itemsBox.get(listId) ?? <int>[];
          listData['movieIds'] = movieIds;

          final customList = CustomList.fromJson(listData);
          customLists.add(customList);
        } catch (e) {
          LoggerFactory.error(
              'CustomListsHive: Error parseando lista ${entry.key}: $e');
        }
      }

      LoggerFactory.debug(
          'CustomListsHive: ${customLists.length} listas cargadas desde cache');

      return customLists;
    } catch (e) {
      LoggerFactory.error('CustomListsHive: Error cargando listas: $e');
      return [];
    }
  }

  /// Guarda una lista en el cache local
  Future<void> cacheList(CustomList list) async {
    try {
      final box = await Hive.openBox<Map>(_boxName);
      final itemsBox = await Hive.openBox<List<int>>(_itemsBoxName);

      // Guardar la información de la lista
      final listData = list.toJson();
      listData.remove('movieIds'); // Los movie IDs se guardan por separado
      await box.put(list.id, listData);

      // Guardar los movie IDs por separado
      await itemsBox.put(list.id, list.movieIds);

      LoggerFactory.debug('CustomListsHive: Lista cached: ${list.name}');
    } catch (e) {
      LoggerFactory.error('CustomListsHive: Error cacheando lista: $e');
    }
  }

  /// Guarda múltiples listas en el cache local
  Future<void> cacheLists(List<CustomList> lists) async {
    try {
      final box = await Hive.openBox<Map>(_boxName);
      final itemsBox = await Hive.openBox<List<int>>(_itemsBoxName);

      // Limpiar cache existente
      await box.clear();
      await itemsBox.clear();

      // Guardar todas las listas
      for (final list in lists) {
        final listData = list.toJson();
        listData.remove('movieIds');
        await box.put(list.id, listData);
        await itemsBox.put(list.id, list.movieIds);
      }

      LoggerFactory.debug(
          'CustomListsHive: ${lists.length} listas cacheadas en batch');
    } catch (e) {
      LoggerFactory.error('CustomListsHive: Error cacheando listas: $e');
    }
  }

  /// Elimina una lista del cache local
  Future<void> removeList(String listId) async {
    try {
      final box = await Hive.openBox<Map>(_boxName);
      final itemsBox = await Hive.openBox<List<int>>(_itemsBoxName);

      await box.delete(listId);
      await itemsBox.delete(listId);

      LoggerFactory.debug('CustomListsHive: Lista eliminada del cache: $listId');
    } catch (e) {
      LoggerFactory.error('CustomListsHive: Error eliminando lista: $e');
    }
  }

  /// Obtiene una lista específica del cache
  Future<CustomList?> getCachedList(String listId) async {
    try {
      final box = await Hive.openBox<Map>(_boxName);
      final itemsBox = await Hive.openBox<List<int>>(_itemsBoxName);

      final listData = box.get(listId);
      if (listData == null) return null;

      final data = Map<String, dynamic>.from(listData);
      final movieIds = itemsBox.get(listId) ?? <int>[];
      data['movieIds'] = movieIds;

      return CustomList.fromJson(data);
    } catch (e) {
      LoggerFactory.error('CustomListsHive: Error obteniendo lista $listId: $e');
      return null;
    }
  }

  /// Actualiza los movie IDs de una lista en el cache
  Future<void> updateListItems(String listId, List<int> movieIds) async {
    try {
      final itemsBox = await Hive.openBox<List<int>>(_itemsBoxName);
      await itemsBox.put(listId, movieIds);

      LoggerFactory.debug(
          'CustomListsHive: Items actualizados para lista $listId: ${movieIds.length} películas');
    } catch (e) {
      LoggerFactory.error(
          'CustomListsHive: Error actualizando items de lista: $e');
    }
  }

  /// Agrega una película a una lista en el cache
  Future<void> addMovieToList(String listId, int movieId) async {
    try {
      final itemsBox = await Hive.openBox<List<int>>(_itemsBoxName);
      final currentIds = itemsBox.get(listId) ?? <int>[];

      if (!currentIds.contains(movieId)) {
        final updatedIds = [...currentIds, movieId];
        await itemsBox.put(listId, updatedIds);

        LoggerFactory.debug(
            'CustomListsHive: Película $movieId agregada a lista $listId');
      }
    } catch (e) {
      LoggerFactory.error(
          'CustomListsHive: Error agregando película a lista: $e');
    }
  }

  /// Remueve una película de una lista en el cache
  Future<void> removeMovieFromList(String listId, int movieId) async {
    try {
      final itemsBox = await Hive.openBox<List<int>>(_itemsBoxName);
      final currentIds = itemsBox.get(listId) ?? <int>[];

      if (currentIds.contains(movieId)) {
        final updatedIds = currentIds.where((id) => id != movieId).toList();
        await itemsBox.put(listId, updatedIds);

        LoggerFactory.debug(
            'CustomListsHive: Película $movieId removida de lista $listId');
      }
    } catch (e) {
      LoggerFactory.error(
          'CustomListsHive: Error removiendo película de lista: $e');
    }
  }

  /// Verifica si una película está en una lista específica
  Future<bool> isMovieInList(String listId, int movieId) async {
    try {
      final itemsBox = await Hive.openBox<List<int>>(_itemsBoxName);
      final movieIds = itemsBox.get(listId) ?? <int>[];
      return movieIds.contains(movieId);
    } catch (e) {
      LoggerFactory.error(
          'CustomListsHive: Error verificando película en lista: $e');
      return false;
    }
  }

  /// Obtiene todas las listas que contienen una película específica
  Future<List<String>> getListsContainingMovie(int movieId) async {
    try {
      final itemsBox = await Hive.openBox<List<int>>(_itemsBoxName);
      final listsWithMovie = <String>[];

      for (final entry in itemsBox.toMap().entries) {
        final listId = entry.key as String;
        final movieIds = entry.value;

        if (movieIds.contains(movieId)) {
          listsWithMovie.add(listId);
        }
      }

      return listsWithMovie;
    } catch (e) {
      LoggerFactory.error(
          'CustomListsHive: Error buscando listas con película: $e');
      return [];
    }
  }

  /// Limpia completamente el cache de listas
  Future<void> clearCache() async {
    try {
      final box = await Hive.openBox<Map>(_boxName);
      final itemsBox = await Hive.openBox<List<int>>(_itemsBoxName);

      await box.clear();
      await itemsBox.clear();

      LoggerFactory.debug('CustomListsHive: Cache limpiado completamente');
    } catch (e) {
      LoggerFactory.error('CustomListsHive: Error limpiando cache: $e');
    }
  }

  /// Obtiene estadísticas del cache
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final box = await Hive.openBox<Map>(_boxName);
      final itemsBox = await Hive.openBox<List<int>>(_itemsBoxName);

      int totalLists = box.length;
      int totalItems = 0;

      for (final items in itemsBox.values) {
        totalItems += (items).length;
      }

      return {
        'total_lists': totalLists,
        'total_items': totalItems,
        'cache_size_lists': box.toMap().toString().length,
        'cache_size_items': itemsBox.toMap().toString().length,
      };
    } catch (e) {
      LoggerFactory.error('CustomListsHive: Error obteniendo estadísticas: $e');
      return {'error': e.toString()};
    }
  }
}