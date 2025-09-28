import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/exceptions/app_exceptions.dart';
import 'package:peliculas/domain/entities/entities.dart';
import 'package:peliculas/domain/repositories/movies_repository.dart';
import 'package:peliculas/presentation/providers/movies/movie_info_provider.dart';
import 'package:peliculas/presentation/providers/movies/movies_repository_provider.dart';

void main() {
  group('MovieMapNotifier', () {
    test(
        'marks movie as missing without throwing when repository reports not found',
        () async {
      final container = ProviderContainer(overrides: [
        movieRepositoryProvider.overrideWith((ref) {
          return _FakeMoviesRepository(
            onGetMovieById: (id) async =>
                throw MovieException('Movie not found: $id', 'MOVIE_NOT_FOUND'),
          );
        }),
      ]);
      addTearDown(container.dispose);

      await container.read(movieInfoProvider.notifier).loadMovie('123');

      final cacheState = container.read(movieInfoProvider);
      expect(cacheState, isA<AsyncData<Map<String, Movie>>>());
      expect(cacheState.value, isEmpty);

      final missingIds = container.read(movieLoadFailuresProvider);
      expect(missingIds, contains('123'));
    });

    test('can force reload after previous failure', () async {
      var shouldFail = true;
      final container = ProviderContainer(overrides: [
        movieRepositoryProvider.overrideWith((ref) {
          return _FakeMoviesRepository(
            onGetMovieById: (id) async {
              if (shouldFail) {
                throw MovieException('Movie not found: $id', 'MOVIE_NOT_FOUND');
              }
              return _sampleMovie(id);
            },
          );
        }),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(movieInfoProvider.notifier);

      await notifier.loadMovie('456');
      expect(container.read(movieLoadFailuresProvider), contains('456'));

      shouldFail = false;
      await notifier.loadMovie('456', force: true);

      final cacheState = container.read(movieInfoProvider);
      expect(cacheState, isA<AsyncData<Map<String, Movie>>>());
      expect(cacheState.value?['456']?.id, 456);
      expect(container.read(movieLoadFailuresProvider), isNot(contains('456')));
    });
  });
}

Movie _sampleMovie(String id) {
  final movieId = int.tryParse(id) ?? 0;
  return Movie(
    adult: false,
    backdropPath: '',
    genreIds: const [],
    id: movieId,
    originalLanguage: 'en',
    originalTitle: 'Sample Movie',
    overview: 'Overview',
    popularity: 0,
    posterPath: '',
    releaseDate: DateTime(2020, 1, 1),
    title: 'Sample Movie',
    video: false,
    voteAverage: 0,
    voteCount: 0,
  );
}

class _FakeMoviesRepository extends MoviesRepository {
  _FakeMoviesRepository({required this.onGetMovieById});

  final Future<Movie> Function(String id) onGetMovieById;

  @override
  Future<Movie> getMovieById(String id) => onGetMovieById(id);

  @override
  Future<List<Movie>> getNowPlaying({int page = 1}) {
    throw UnimplementedError();
  }

  @override
  Future<List<Movie>> getPopular({int page = 1}) {
    throw UnimplementedError();
  }

  @override
  Future<List<Movie>> getSimilarMovies(int movieId) {
    throw UnimplementedError();
  }

  @override
  Future<List<Movie>> getTopRated({int page = 1}) {
    throw UnimplementedError();
  }

  @override
  Future<List<Movie>> getUpcoming({int page = 1}) {
    throw UnimplementedError();
  }

  @override
  Future<List<Video>> getYoutubeVideosById(int movieId) {
    throw UnimplementedError();
  }

  @override
  Future<List<Movie>> searchMovies(String query) {
    throw UnimplementedError();
  }
}
