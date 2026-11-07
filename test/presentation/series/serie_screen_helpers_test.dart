import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/domain/entities/episodio.dart';
import 'package:peliculas/domain/entities/serie.dart';
import 'package:peliculas/presentation/screens/series/serie_screen.dart';

void main() {
  group('serieMetaLine', () {
    test('includes seasons episodes and status label', () {
      final serie = Serie(
        id: 1399,
        name: 'Game of Thrones',
        numberOfSeasons: 8,
        numberOfEpisodes: 73,
        status: 'Ended',
      );

      expect(serieMetaLine(serie), '8 temporadas · 73 episodios · Finalizada');
    });

    test('omits empty parts', () {
      final serie = Serie(id: 1, name: 'Sin datos');

      expect(serieMetaLine(serie), isEmpty);
    });
  });

  group('episodeLabel', () {
    test('formats number and name', () {
      const episode = Episodio(
        serieId: 1399,
        seasonNumber: 1,
        episodeNumber: 1,
        name: 'Winter Is Coming',
      );

      expect(episodeLabel(episode), 'E1 · Winter Is Coming');
    });
  });
}
