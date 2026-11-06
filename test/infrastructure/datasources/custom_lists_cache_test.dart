import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:peliculas/domain/entities/custom_list.dart';
import 'package:peliculas/infrastructure/datasources/custom_lists_hive_datasource.dart';

CustomList _list(String id, List<int> movieIds) => CustomList(
      id: id,
      name: 'List $id',
      description: 'd',
      emoji: '🎬',
      movieIds: movieIds,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('custom_lists_test');
    Hive.init(dir.path);
  });

  tearDownAll(() async {
    await Hive.close();
  });

  test('cacheLists replaces stale entries without a wipe window', () async {
    final ds = CustomListsHiveDataSource();
    await ds.cacheLists([_list('old', [1])]);

    await ds.cacheLists([_list('a', [1, 2]), _list('b', [3])]);

    final cached = await ds.getAllCachedLists();
    expect(cached.map((l) => l.id).toSet(), {'a', 'b'});
    final a = cached.firstWhere((l) => l.id == 'a');
    expect(a.movieIds, [1, 2]);
  });
}
