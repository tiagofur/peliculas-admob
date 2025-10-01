import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/sync/sync_utilities.dart';
import 'package:peliculas/domain/entities/custom_list.dart';
import 'package:peliculas/domain/entities/list_item.dart';
import 'package:peliculas/domain/repositories/i_custom_lists_repository.dart';
import 'package:peliculas/presentation/providers/custom_lists_providers.dart';

class _FakeCustomListsRepository implements ICustomListsRepository {
  CustomList? lastCreated;
  final Map<String, CustomList> _lists = {};

  @override
  Future<CustomList> createList(CustomList list) async {
    lastCreated = list;
    _lists[list.id] = list;
    return list;
  }

  @override
  Future<CustomList> updateList(CustomList list) async {
    _lists[list.id] = list;
    return list;
  }

  @override
  Future<CustomList?> getListById(String listId) async {
    return _lists[listId];
  }

  // ----- Unimplemented methods for this fake -----
  @override
  Future<List<ListItem>> getListItems(String listId) {
    throw UnimplementedError();
  }

  @override
  Future<List<CustomList>> getDefaultLists() {
    throw UnimplementedError();
  }

  @override
  Future<List<CustomList>> getLocalLists() {
    throw UnimplementedError();
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingOperations() {
    throw UnimplementedError();
  }

  @override
  Future<String> getSyncStatus() {
    throw UnimplementedError();
  }

  @override
  Future<List<CustomList>> getUserLists() {
    throw UnimplementedError();
  }

  @override
  Stream<List<ListItem>> watchListItems(String listId) {
    throw UnimplementedError();
  }

  @override
  Stream<List<CustomList>> watchUserLists() {
    throw UnimplementedError();
  }

  @override
  Future<bool> hasInternetConnection() {
    throw UnimplementedError();
  }

  @override
  Future<void> markOperationAsSynced(String operationId) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeMovieFromList(String listId, int movieId) {
    throw UnimplementedError();
  }

  @override
  Future<ListItem> addMovieToList(String listId, int movieId, {int? position}) {
    throw UnimplementedError();
  }

  @override
  Future<bool> isMovieInList(String listId, int movieId) {
    throw UnimplementedError();
  }

  @override
  Future<void> reorderListItems(String listId, List<ListItem> items) {
    throw UnimplementedError();
  }

  @override
  Future<CustomList> resolveConflict(
      CustomList localList, CustomList remoteList) {
    throw UnimplementedError();
  }

  @override
  Future<void> saveListLocally(CustomList list) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteList(String listId) {
    throw UnimplementedError();
  }

  @override
  Future<void> clearLocalCache() {
    throw UnimplementedError();
  }

  @override
  Future<void> initializeDefaultLists(String userId) {
    throw UnimplementedError();
  }

  @override
  Future<void> syncLists() {
    throw UnimplementedError();
  }
}

void main() {
  group('ListActions', () {
    late _FakeCustomListsRepository repository;
    late ListActions listActions;

    setUp(() {
      repository = _FakeCustomListsRepository();
      listActions = ListActions(repository);
    });

    test('createList generates a valid UUID before delegating to repository',
        () async {
      final result = await listActions.createList(name: 'My List');

      expect(repository.lastCreated, isNotNull);
      expect(SyncUtilities.isValidUuid(repository.lastCreated!.id), isTrue);
      expect(result.id, repository.lastCreated!.id);
      expect(result.name, 'My List');
    });

    test('duplicateList creates a new list with a different UUID', () async {
      final originalList = CustomList(
        id: SyncUtilities.generateUuid(),
        name: 'Original',
        description: 'Original description',
        emoji: '🎬',
        movieIds: [1, 2, 3],
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        lastModifiedAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      repository._lists[originalList.id] = originalList;

      final duplicated =
          await listActions.duplicateList(originalList.id, 'Duplicated');

      expect(SyncUtilities.isValidUuid(duplicated.id), isTrue);
      expect(duplicated.id, isNot(originalList.id));
      expect(duplicated.name, 'Duplicated');
      expect(duplicated.movieIds, originalList.movieIds);
    });
  });
}
