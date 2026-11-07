import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/domain/entities/entities.dart';
import 'package:peliculas/domain/repositories/series_repository.dart';
import 'package:peliculas/presentation/providers/series/series_filter_provider.dart';
import 'package:peliculas/presentation/providers/series/series_providers.dart';
import 'package:peliculas/presentation/providers/series/series_repository_provider.dart';

class FakeSeriesRepository extends SeriesRepository {
  @override
  Future<List<Serie>> getAiringToday({int page = 1}) async => const [];

  @override
  Future<List<Episodio>> getEpisodes(int serieId, int seasonNumber) async =>
      const [];

  @override
  Future<List<Serie>> getOnTheAir({int page = 1}) async => const [];

  @override
  Future<List<Serie>> getPopular({int page = 1}) async => const [];

  @override
  Future<Temporada> getSeason(int serieId, int seasonNumber) async =>
      const Temporada(serieId: 0, seasonNumber: 0);

  @override
  Future<List<Temporada>> getSeasons(int serieId) async => const [];

  @override
  Future<Serie> getSerieById(String id) async =>
      Serie(id: int.tryParse(id) ?? 0, name: 'Fake');

  @override
  Future<List<Serie>> getSimilarSeries(int serieId) async => const [];

  @override
  Future<List<Serie>> getTopRated({int page = 1}) async => const [];

  @override
  Future<List<Serie>> searchSeries(String query) async => const [];
}

void main() {
  group('Series browse wiring', () {
    test('filter starts empty and accepts series status', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(seriesFilterProvider).isEmpty, isTrue);

      container
          .read(seriesFilterProvider.notifier)
          .updateStatus('Returning Series');

      final filter = container.read(seriesFilterProvider);
      expect(filter.isEmpty, isFalse);
      expect(
          filter.toQueryParameters()['with_status'], '0');
    });

    test('series rows start idle for lazy load', () {
      final container = ProviderContainer(overrides: [
        seriesRepositoryProvider.overrideWithValue(FakeSeriesRepository()),
      ]);
      addTearDown(container.dispose);

      expect(container.read(popularSeriesProvider).state,
          SeriesState.initial);
      expect(container.read(onTheAirSeriesProvider).series, isEmpty);
    });

    test('series genres exclude movie-only ids', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ids =
          container.read(seriesGenreOptionsProvider).map((g) => g.id);
      expect(ids, contains(10765));
      expect(ids, isNot(contains(10770)));
    });
  });
}
