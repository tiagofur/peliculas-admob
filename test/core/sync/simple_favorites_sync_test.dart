import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:peliculas/core/sync/simple_favorites_sync.dart';
import 'package:peliculas/domain/entities/movie.dart';

/// Records `.eq()` filters of a single query chain and replays a canned
/// result when awaited.
class _RecordingFilter<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  _RecordingFilter(this.result);

  final dynamic result;
  final Map<String, Object> filters = {};

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) {
    filters[column] = value;
    return this;
  }

  @override
  PostgrestFilterBuilder<T> limit(int count,
          {String? referencedTable}) =>
      this;

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue,
      {Function? onError}) {
    return Future<R>.value(onValue(result as T));
  }
}

class _FakeQuery extends Fake implements SupabaseQueryBuilder {
  _FakeQuery(this.client);

  final _FakeClient client;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    final filter = _RecordingFilter<PostgrestList>(const []);
    client.filters.add(filter);
    return filter;
  }

  @override
  PostgrestFilterBuilder<Map<String, dynamic>> delete() {
    final filter =
        _RecordingFilter<Map<String, dynamic>>(const <String, dynamic>{});
    client.filters.add(filter);
    return filter;
  }

  @override
  PostgrestFilterBuilder<Map<String, dynamic>> insert(
    Object values, {
    bool defaultToNull = true,
  }) {
    if (client.throwOnInsertDuplicate && !client._duplicateThrown) {
      client._duplicateThrown = true;
      throw const PostgrestException(
        message:
            'duplicate key value violates unique constraint "user_favorites_pkey"',
      );
    }
    final filter =
        _RecordingFilter<Map<String, dynamic>>(const <String, dynamic>{});
    client.filters.add(filter);
    return filter;
  }
}

class _FakeClient extends Fake implements SupabaseClient {
  final List<_RecordingFilter> filters = [];
  bool throwOnInsertDuplicate = false;
  bool _duplicateThrown = false;

  @override
  SupabaseQueryBuilder from(String table) => _FakeQuery(this);
}

Movie _movie(int id) => Movie(
      adult: false,
      backdropPath: '/b.jpg',
      genreIds: const [28],
      id: id,
      originalLanguage: 'en',
      originalTitle: 'T $id',
      overview: 'o',
      popularity: 1.0,
      posterPath: '/p.jpg',
      releaseDate: DateTime(2026, 1, 1),
      title: 'T $id',
      video: false,
      voteAverage: 7.0,
      voteCount: 10,
    );

void main() {
  late _FakeClient client;
  late SimpleFavoritesSync sync;

  setUp(() {
    client = _FakeClient();
    sync = SimpleFavoritesSync.instance;
    sync.debugClient = client;
  });

  test('removeFavorite scopes delete to user AND movie', () async {
    await sync.removeFavorite('u1', 42);

    final deletes =
        client.filters.where((f) => f.filters.containsKey('user_id'));
    expect(deletes, hasLength(1));
    expect(deletes.single.filters['user_id'], 'u1');
    expect(
      deletes.single.filters['movie_id'],
      42,
      reason: 'delete must be scoped to the movie, not the whole user',
    );
  });

  test('isFavorite filters by movie', () async {
    final result = await sync.isFavorite('u1', 42);

    expect(result, isFalse);
    final selects =
        client.filters.where((f) => f.filters.containsKey('user_id'));
    expect(selects, hasLength(1));
    expect(
      selects.single.filters['movie_id'],
      42,
      reason: 'isFavorite must check this movie, not any favorite',
    );
  });

  test('addFavorite duplicate fallback delete is scoped to movie',
      () async {
    client.throwOnInsertDuplicate = true;

    await sync.addFavorite('u1', _movie(42));

    final deletes =
        client.filters.where((f) => f.filters.containsKey('user_id'));
    expect(deletes, hasLength(1));
    expect(deletes.single.filters['user_id'], 'u1');
    expect(
      deletes.single.filters['movie_id'],
      42,
      reason: 'duplicate-key fallback must not wipe all user favorites',
    );
  });
}
