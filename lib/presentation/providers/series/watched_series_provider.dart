import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../domain/entities/entities.dart';
import '../../../infrastructure/datasources/watched_episodes_hive_datasource.dart';

final watchedEpisodesDatasourceProvider =
    Provider<WatchedEpisodesHiveDatasource>((ref) {
  return WatchedEpisodesHiveDatasource();
});

final isEpisodeWatchedProvider =
    FutureProvider.family<bool, EpisodeKey>((ref, key) async {
  final datasource = ref.watch(watchedEpisodesDatasourceProvider);
  return datasource.isEpisodeWatched(
      key.serieId, key.seasonNumber, key.episodeNumber);
});

class EpisodeKey {
  const EpisodeKey({
    required this.serieId,
    required this.seasonNumber,
    required this.episodeNumber,
  });

  final int serieId;
  final int seasonNumber;
  final int episodeNumber;

  @override
  bool operator ==(Object other) =>
      other is EpisodeKey &&
      other.serieId == serieId &&
      other.seasonNumber == seasonNumber &&
      other.episodeNumber == episodeNumber;

  @override
  int get hashCode =>
      serieId.hashCode ^ seasonNumber.hashCode ^ episodeNumber.hashCode;
}

class WatchedSeriesState {
  const WatchedSeriesState({
    this.watchedKeys = const {},
    this.isLoading = false,
  });

  final Set<String> watchedKeys;
  final bool isLoading;

  WatchedSeriesState copyWith({
    Set<String>? watchedKeys,
    bool? isLoading,
  }) {
    return WatchedSeriesState(
      watchedKeys: watchedKeys ?? this.watchedKeys,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class WatchedSeriesNotifier extends Notifier<WatchedSeriesState> {
  @override
  WatchedSeriesState build() => const WatchedSeriesState();

  WatchedEpisodesHiveDatasource get _datasource =>
      ref.read(watchedEpisodesDatasourceProvider);

  Future<void> loadSerie(int serieId) async {
    state = state.copyWith(isLoading: true);
    try {
      final keys = await _datasource.watchedKeysForSerie(serieId);
      state = state.copyWith(watchedKeys: keys, isLoading: false);
    } catch (e) {
      LoggerFactory.error('WatchedSeriesNotifier: error cargando $serieId: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> toggleEpisode({
    required int serieId,
    required int seasonNumber,
    required int episodeNumber,
    String serieName = '',
    String posterPath = '',
  }) async {
    final key = '$serieId-$seasonNumber-$episodeNumber';
    final isWatched = state.watchedKeys.contains(key);
    try {
      if (isWatched) {
        await _datasource.unmarkEpisodeWatched(
            serieId, seasonNumber, episodeNumber);
        state = state.copyWith(
          watchedKeys: {...state.watchedKeys}..remove(key),
        );
      } else {
        await _datasource.markEpisodeWatched(
          serieId: serieId,
          seasonNumber: seasonNumber,
          episodeNumber: episodeNumber,
          serieName: serieName,
          posterPath: posterPath,
        );
        state = state.copyWith(
          watchedKeys: {...state.watchedKeys, key},
        );
      }
      ref.invalidate(isEpisodeWatchedProvider(EpisodeKey(
        serieId: serieId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      )));
    } catch (e) {
      LoggerFactory.error('WatchedSeriesNotifier: error toggle $key: $e');
    }
  }

  SeriesProgress progressFor(int serieId, int totalEpisodes) {
    return SeriesProgress.calculate(
      serieId: serieId,
      watchedEpisodeKeys: state.watchedKeys,
      totalEpisodes: totalEpisodes,
    );
  }

  bool isWatched(int serieId, int seasonNumber, int episodeNumber) {
    return state.watchedKeys.contains('$serieId-$seasonNumber-$episodeNumber');
  }
}

final watchedSeriesProvider =
    NotifierProvider<WatchedSeriesNotifier, WatchedSeriesState>(
  () => WatchedSeriesNotifier(),
);
