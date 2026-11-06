import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:peliculas/domain/adapters/legacy_hive_adapters.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/domain/entities/watched_movie.dart';
import 'package:peliculas/infrastructure/datasources/watched_movies_hive_datasource.dart';

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
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('watched_repair_test');
    Hive.init(dir.path);
    ensureMovieAdaptersRegistered();
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(WatchedMovieAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
  });

  test('corrupt main box is repaired in place, never forked', () async {
    // Arrange: a healthy main box with one row.
    final setup = WatchedMoviesHiveDatasource();
    await setup.markAsWatched(_movie(1));
    expect(await setup.isMovieWatched(1), isTrue);

    // Simulate on-disk corruption.
    await Hive.box<WatchedMovie>('watched_movies').close();
    await File('${dir.path}/watched_movies.hive')
        .writeAsBytes([0, 1, 2, 3, 255]);

    // Act: fresh datasource hits the corrupt box.
    final repaired = WatchedMoviesHiveDatasource();
    await repaired.markAsWatched(_movie(2));

    // Assert: no silent fork, main box usable again.
    expect(
      await Hive.boxExists('watched_movies_fallback'),
      isFalse,
      reason: 'a fallback box silently splits user data across two stores',
    );
    expect(await repaired.isMovieWatched(2), isTrue);
  });
}
