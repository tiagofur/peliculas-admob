import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:peliculas/domain/adapters/legacy_hive_adapters.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/infrastructure/datasources/favorite_movies_hive_datasource.dart';
import 'package:peliculas/infrastructure/datasources/general_movies_hive_datasource.dart';

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
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('hive_ds_test');
    Hive.init(dir.path);
    ensureMovieAdaptersRegistered();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  group('FavoriteMoviesHiveDatasource', () {
    test('clearExpiredCache preserves favorites (no TTL on entries)',
        () async {
      final ds = FavoriteMoviesHiveDatasource();
      await ds.saveFavorite(_movie(1));
      await ds.saveFavorite(_movie(2));

      await ds.clearExpiredCache();

      expect(await ds.loadMovies(limit: 100), hasLength(2));
    });

    test('saveFavorite is idempotent, no duplicates', () async {
      final ds = FavoriteMoviesHiveDatasource();
      final movie = _movie(1);

      await ds.saveFavorite(movie);
      await ds.saveFavorite(movie);
      await ds.toggleFavorite(movie);

      expect(await ds.loadMovies(limit: 100), hasLength(1));
      expect(await ds.isMovieFavorite(1), isTrue);
    });

    test('removeFavoriteById removes legacy auto-key rows too', () async {
      final ds = FavoriteMoviesHiveDatasource();
      // Simulate rows written by the old box.add() path (auto-increment keys).
      final box = await Hive.openBox<Movie>('favorite_movies');
      await box.add(_movie(1));
      await box.add(_movie(1));
      await ds.saveFavorite(_movie(2));

      await ds.removeFavoriteById(1);

      final remaining = await ds.loadMovies(limit: 100);
      expect(remaining.where((m) => m.id == 1), isEmpty,
          reason: 'all rows for the movie must go, whatever their key');
      expect(remaining.map((m) => m.id), [2]);
    });
  });

  group('GeneralMoviesHiveDatasource', () {
    test('clearExpiredCache preserves cached categories (no TTL stored)',
        () async {
      final ds = GeneralMoviesHiveDatasource();
      await ds.cacheMovies([_movie(1), _movie(2)], 'popular_1');

      await ds.clearExpiredCache();

      expect(
        await ds.getCachedMoviesByCategory('popular_1'),
        hasLength(2),
      );
    });
  });
}
