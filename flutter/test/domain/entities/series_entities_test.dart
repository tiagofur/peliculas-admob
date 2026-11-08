import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/domain/entities/serie.dart';
import 'package:peliculas/domain/entities/temporada.dart';
import 'package:peliculas/domain/entities/episodio.dart';
import 'package:peliculas/domain/entities/watched_episode.dart';
import 'package:peliculas/domain/entities/series_progress.dart';

void main() {
  group('Serie.fromJson TMDB /tv', () {
    test('parses name/first_air_date and seasons metadata', () {
      final serie = Serie.fromJson({
        'id': 1399,
        'name': 'Game of Thrones',
        'original_name': 'Game of Thrones',
        'overview': 'Overview',
        'poster_path': '/poster.png',
        'backdrop_path': '/backdrop.png',
        'first_air_date': '2011-04-17',
        'origin_country': ['US'],
        'genre_ids': [10765, 18],
        'vote_average': 8.4,
        'vote_count': 100,
        'popularity': 10.0,
        'original_language': 'en',
        'number_of_seasons': 8,
        'number_of_episodes': 73,
        'episode_run_time': [57],
        'status': 'Ended',
        'in_production': false,
        'type': 'Scripted',
        'networks': [
          {'name': 'HBO'}
        ],
      });

      expect(serie.id, 1399);
      expect(serie.name, 'Game of Thrones');
      expect(serie.firstAirDate?.year, 2011);
      expect(serie.numberOfSeasons, 8);
      expect(serie.numberOfEpisodes, 73);
      expect(serie.episodeRunTime, [57]);
      expect(serie.status, 'Ended');
      expect(serie.networks, ['HBO']);
    });
  });

  group('Temporada/Episodio', () {
    test('keys carry serieId+season+episode', () {
      const temporada = Temporada(
        serieId: 1399,
        seasonNumber: 1,
        episodeCount: 10,
        name: 'Season 1',
      );
      const episodio = Episodio(
        serieId: 1399,
        seasonNumber: 1,
        episodeNumber: 1,
        name: 'Winter Is Coming',
      );

      expect(temporada.key, '1399-1');
      expect(episodio.key, '1399-1-1');
    });
  });

  group('WatchedEpisode/SeriesProgress', () {
    test('watched episode key format', () {
      final watched = WatchedEpisode(
        serieId: 1399,
        seasonNumber: 1,
        episodeNumber: 1,
        watchedDate: DateTime.utc(2024, 1, 1),
        lastModifiedAt: DateTime.utc(2024, 1, 1),
      );

      expect(watched.key, '1399-1-1');
    });

    test('progress percent from watched count', () {
      final progress = SeriesProgress.calculate(
        serieId: 1399,
        watchedEpisodeKeys: const {'1399-1-1', '1399-1-2'},
        totalEpisodes: 10,
      );

      expect(progress.watchedEpisodeCount, 2);
      expect(progress.percent, closeTo(0.2, 0.0001));
      expect(progress.status, SeriesWatchStatus.watching);
    });

    test('empty progress is not started', () {
      final progress = SeriesProgress.calculate(
        serieId: 1399,
        watchedEpisodeKeys: const {},
        totalEpisodes: 10,
      );

      expect(progress.percent, 0.0);
      expect(progress.status, SeriesWatchStatus.notStarted);
    });
  });
}
