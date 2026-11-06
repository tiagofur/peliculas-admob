import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/streaming/tmdb_provider_mapper.dart';
import 'package:peliculas/domain/entities/streaming_platform.dart';

/// Regression coverage for TMDB-only availability:
/// every provider TMDB reports for MX must resolve to a real platform,
/// and unknown IDs must resolve to null (never to invented data).
void main() {
  group('TmdbProviderMapper - current TMDB IDs resolve to real platforms', () {
    test('Max: current, channel and legacy IDs map to hbo_max', () {
      for (final id in [1899, 1825, 384, 425]) {
        expect(
          TmdbProviderMapper.mapProvider(id, 'HBO Max')?.id,
          'hbo_max',
          reason: 'TMDB provider $id should map to hbo_max',
        );
      }
    });

    test('Netflix tiers and Prime variants map to their brands', () {
      expect(TmdbProviderMapper.mapProvider(8, 'Netflix')?.id, 'netflix');
      expect(
        TmdbProviderMapper.mapProvider(1796, 'Netflix Standard with Ads')?.id,
        'netflix',
      );
      for (final id in [9, 119, 2100]) {
        expect(
          TmdbProviderMapper.mapProvider(id, 'Amazon Prime Video')?.id,
          'amazon_prime',
          reason: 'TMDB provider $id should map to amazon_prime',
        );
      }
      expect(
        TmdbProviderMapper.mapProvider(10, 'Amazon Video')?.id,
        'amazon_prime',
      );
    });

    test('Apple, Disney and Paramount families map correctly', () {
      expect(TmdbProviderMapper.mapProvider(350, 'Apple TV')?.id, 'apple_tv');
      expect(
        TmdbProviderMapper.mapProvider(2, 'Apple TV Store')?.id,
        'apple_tv',
      );
      expect(
        TmdbProviderMapper.mapProvider(337, 'Disney Plus')?.id,
        'disney_plus',
      );
      for (final id in [531, 582, 2303]) {
        expect(
          TmdbProviderMapper.mapProvider(id, 'Paramount Plus')?.id,
          'paramount_plus',
          reason: 'TMDB provider $id should map to paramount_plus',
        );
      }
    });

    test('LATAM transactional and local platforms map correctly', () {
      expect(
        TmdbProviderMapper.mapProvider(167, 'Claro video')?.id,
        'claro_video',
      );
      expect(TmdbProviderMapper.mapProvider(457, 'VIX ')?.id, 'vix');
      expect(TmdbProviderMapper.mapProvider(11, 'MUBI')?.id, 'mubi');
      expect(TmdbProviderMapper.mapProvider(73, 'Tubi TV')?.id, 'tubi');
      expect(
        TmdbProviderMapper.mapProvider(283, 'Crunchyroll')?.id,
        'crunchyroll',
      );
      expect(TmdbProviderMapper.mapProvider(300, 'Pluto TV')?.id, 'pluto_tv');
      expect(TmdbProviderMapper.mapProvider(538, 'Plex')?.id, 'plex');
      expect(
        TmdbProviderMapper.mapProvider(1889, 'Universal+ Amazon Channel')?.id,
        'universal_plus',
      );
    });

    test('Dune 2 MX providers all resolve (nothing is dropped)', () {
      // Observed live from TMDB /movie/693134/watch/providers, region MX.
      const duneMxIds = [1899, 1825, 1889, 2, 10, 167];
      for (final id in duneMxIds) {
        expect(
          TmdbProviderMapper.mapProvider(id, 'provider $id'),
          isNotNull,
          reason: 'TMDB provider $id (Dune 2, MX) must not be dropped',
        );
      }
    });

    test('Fight Club US providers all resolve (nothing is dropped)', () {
      // Observed live from TMDB /movie/550/watch/providers, region US.
      const fightClubUsIds = [10, 2, 3, 192, 7];
      for (final id in fightClubUsIds) {
        expect(
          TmdbProviderMapper.mapProvider(id, 'provider $id'),
          isNotNull,
          reason: 'TMDB provider $id (Fight Club, US) must not be dropped',
        );
      }
    });

    test('unknown IDs resolve to null instead of invented platforms', () {
      expect(
        TmdbProviderMapper.mapProvider(999999, 'Some New Service'),
        isNull,
      );
    });

    test('every mapped platform is a known platform', () {
      const ids = [
        8,
        1796,
        9,
        119,
        2100,
        10,
        337,
        350,
        2,
        3,
        192,
        188,
        7,
        1899,
        1825,
        384,
        425,
        531,
        582,
        2303,
        283,
        1968,
        167,
        457,
        1866,
        11,
        201,
        73,
        300,
        538,
        1889,
        15,
        387,
        68,
      ];
      final knownIds = StreamingPlatform.allPlatforms.map((p) => p.id).toSet();
      for (final id in ids) {
        final platform = TmdbProviderMapper.mapProvider(id, 'provider $id');
        expect(platform, isNotNull, reason: 'TMDB provider $id must resolve');
        expect(knownIds, contains(platform!.id));
      }
    });
  });
}
