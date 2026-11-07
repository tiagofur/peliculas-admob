import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/domain/entities/series_filter.dart';

void main() {
  group('SeriesFilter.toQueryParameters', () {
    test('emits first_air_date keys, not primary_release_date', () {
      const filter = SeriesFilter(minYear: 2010, maxYear: 2020);

      final params = filter.toQueryParameters();

      expect(params['first_air_date.gte'], '2010-01-01');
      expect(params['first_air_date.lte'], '2020-12-31');
      expect(params.containsKey('primary_release_date.gte'), isFalse);
      expect(params.containsKey('with_runtime.gte'), isFalse);
    });

    test('emits series-specific status networks and episode runtime', () {
      const filter = SeriesFilter(
        status: 'Returning Series',
        networks: [213],
        minEpisodes: 10,
        minEpisodeRuntime: 40,
        sortBy: 'first_air_date.desc',
      );

      final params = filter.toQueryParameters();

      expect(params['with_status'], '0');
      expect(params['with_networks'], '213');
      expect(params['with_episode_runtime.gte'], 40);
      expect(params['sort_by'], 'first_air_date.desc');
      expect(params.containsKey('revenue.desc'), isFalse);
    });

    test('empty filter emits nothing series-specific', () {
      const filter = SeriesFilter();

      expect(filter.isEmpty, isTrue);
      expect(filter.toQueryParameters(), isEmpty);
    });
  });
}
