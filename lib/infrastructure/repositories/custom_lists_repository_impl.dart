import '../../domain/entities/custom_list.dart';
import '../datasources/custom_lists_shared_preferences_datasource.dart';

abstract class CustomListsRepository {
  Future<List<CustomList>> getCustomLists();
  Future<void> saveCustomLists(List<CustomList> lists);
  Future<void> addCustomList(CustomList list);
  Future<void> updateCustomList(CustomList list);
  Future<void> deleteCustomList(String listId);
  Future<void> clearAllCustomLists();
  
  // Métodos para listas predeterminadas
  Future<List<CustomList>> getDefaultLists();
  Future<void> saveDefaultLists(List<CustomList> lists);
}

class CustomListsRepositoryImpl extends CustomListsRepository {
  CustomListsRepositoryImpl(this.datasource);

  final CustomListsDatasource datasource;

  @override
  Future<List<CustomList>> getCustomLists() {
    return datasource.getCustomLists();
  }

  @override
  Future<void> saveCustomLists(List<CustomList> lists) {
    return datasource.saveCustomLists(lists);
  }

  @override
  Future<void> addCustomList(CustomList list) {
    return datasource.addCustomList(list);
  }

  @override
  Future<void> updateCustomList(CustomList list) {
    return datasource.updateCustomList(list);
  }

  @override
  Future<void> deleteCustomList(String listId) {
    return datasource.deleteCustomList(listId);
  }

  @override
  Future<void> clearAllCustomLists() {
    return datasource.clearAllCustomLists();
  }

  @override
  Future<List<CustomList>> getDefaultLists() {
    return datasource.getDefaultLists();
  }

  @override
  Future<void> saveDefaultLists(List<CustomList> lists) {
    return datasource.saveDefaultLists(lists);
  }
}