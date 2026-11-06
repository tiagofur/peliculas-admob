import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:peliculas/core/sync/trigger_free_favorites_sync.dart';
import 'package:peliculas/core/sync/trigger_free_watchlist_sync.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/domain/entities/watchlist_movie.dart';

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
  PostgrestTransformBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) =>
      this;

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue,
      {Function? onError}) {
    return Future<R>.value(onValue(result as T));
  }
}

class _QueryCall {
  String? upsertOnConflict;
  Map<dynamic, dynamic>? updateValues;
}

class _FakeQuery extends Fake implements SupabaseQueryBuilder {
  _FakeQuery(this.client);

  final _FakeClient client;

  _RecordingFilter<T> _filter<T>(dynamic result) {
    final filter = _RecordingFilter<T>(result);
    client.filters.add(filter);
    return filter;
  }

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) =>
      _filter<PostgrestList>(const []);

  @override
  PostgrestFilterBuilder<Map<String, dynamic>> delete() =>
      _filter<Map<String, dynamic>>(const <String, dynamic>{});

  @override
  PostgrestFilterBuilder<Map<String, dynamic>> insert(
    Object values, {
    bool defaultToNull = true,
  }) =>
      _filter<Map<String, dynamic>>(const <String, dynamic>{});

  @override
  PostgrestFilterBuilder<Map<String, dynamic>> upsert(
    Object values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) {
    client.lastCall.upsertOnConflict = onConflict;
    return _filter<Map<String, dynamic>>(const <String, dynamic>{});
  }

  @override
  PostgrestFilterBuilder<Map<String, dynamic>> update(
      Map<dynamic, dynamic> values) {
    client.lastCall.updateValues = values;
    return _filter<Map<String, dynamic>>(const <String, dynamic>{});
  }
}

class _FakeClient extends Fake implements SupabaseClient {
  final List<_RecordingFilter> filters = [];
  _QueryCall lastCall = _QueryCall();

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

  setUp(() {
    client = _FakeClient();
    TriggerFreeFavoritesSync.instance.debugClient = client;
    TriggerFreeWatchlistSync.instance.debugClient = client;
  });

  test('favorites upsert declares user_id,movie_id conflict target',
      () async {
    await TriggerFreeFavoritesSync.instance.addMovie('u1', _movie(42));

    expect(
      client.lastCall.upsertOnConflict,
      'user_id,movie_id',
      reason: 'upsert without onConflict inserts duplicates',
    );
  });

  test('favorites reads exclude soft-deleted rows', () async {
    await TriggerFreeFavoritesSync.instance.getUserMovies('u1');

    final selects =
        client.filters.where((f) => f.filters.containsKey('user_id'));
    expect(selects, hasLength(1));
    expect(selects.single.filters['is_deleted'], isFalse);
  });

  test('watchlist upsert declares user_id,movie_id conflict target',
      () async {
    await TriggerFreeWatchlistSync.instance
        .addToWatchlist('u1', _movie(42));

    expect(client.lastCall.upsertOnConflict, 'user_id,movie_id');
  });

  test('watchlist reads exclude soft-deleted rows', () async {
    await TriggerFreeWatchlistSync.instance.getUserWatchlist('u1');

    final selects =
        client.filters.where((f) => f.filters.containsKey('user_id'));
    expect(selects, hasLength(1));
    expect(selects.single.filters['is_deleted'], isFalse);
  });

  test('changePriority does not reset sync_version', () async {
    await TriggerFreeWatchlistSync.instance.changePriority(
      'u1',
      42,
      WatchlistPriority.alta,
    );

    expect(client.lastCall.updateValues, isNotNull);
    expect(
      client.lastCall.updateValues!.containsKey('sync_version'),
      isFalse,
      reason: 'an UPDATE must not reset the conflict-resolution counter',
    );
    expect(
      client.lastCall.updateValues!['priority'],
      WatchlistPriority.alta.value,
    );
  });
}
