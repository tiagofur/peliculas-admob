import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/domain/entities/serie.dart';
import 'package:peliculas/infrastructure/mappers/serie_mapper.dart';
import 'package:peliculas/infrastructure/models/moviedb/serie_moviedb.dart';
import 'package:peliculas/infrastructure/models/trakt/show_trakt.dart';

void main() {
  group('SerieMapper', () {
    test('serieDBToEntity maps tv list item to Serie', () {
      final db = SerieMovieDB.fromJson({
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
      });

      final Serie serie = SerieMapper.serieDBToEntity(db);

      expect(serie.id, 1399);
      expect(serie.name, 'Game of Thrones');
      expect(serie.firstAirDate?.year, 2011);
      expect(serie.genreIds, [10765, 18]);
    });

    test('showTraktToEntity bridges Trakt ids to Serie', () {
      final show = ShowTrakt.fromJson({
        'title': 'Breaking Bad',
        'year': 2008,
        'ids': {'trakt': 1, 'tmdb': 1396, 'tvdb': 81189, 'imdb': 'tt0903747'},
        'overview': 'Overview',
        'first_aired': '2008-01-20T00:00:00.000Z',
        'network': 'AMC',
        'status': 'ended',
        'rating': 9.5,
        'aired_episodes': 62,
      });

      final Serie serie = SerieMapper.showTraktToEntity(show);

      expect(serie.id, 1396);
      expect(serie.name, 'Breaking Bad');
      expect(serie.networks, ['AMC']);
      expect(serie.numberOfEpisodes, 62);
    });
  });
}
