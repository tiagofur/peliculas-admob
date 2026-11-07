import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../domain/entities/episodio.dart';
import '../../../domain/entities/serie.dart';
import '../../../domain/entities/series_progress.dart';
import '../../../domain/entities/temporada.dart';
import '../../../domain/entities/watched_episode.dart';

void ensureSeriesAdaptersRegistered() {
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(SerieAdapter());
  }
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(TemporadaAdapter());
  }
  if (!Hive.isAdapterRegistered(6)) {
    Hive.registerAdapter(EpisodioAdapter());
  }
  if (!Hive.isAdapterRegistered(7)) {
    Hive.registerAdapter(WatchedEpisodeAdapter());
  }
  if (!Hive.isAdapterRegistered(8)) {
    Hive.registerAdapter(SeriesWatchStatusAdapter());
  }
  if (!Hive.isAdapterRegistered(9)) {
    Hive.registerAdapter(SeriesProgressAdapter());
  }
}

class WatchedEpisodesHiveDatasource {
  static const String boxName = 'watched_episodes';

  Box<WatchedEpisode>? _box;
  Future<void>? _initFuture;
  bool _isInitialized = false;

  Future<void> _initHive() {
    _initFuture ??= _doInitHive();
    return _initFuture!;
  }

  Future<void> _doInitHive() async {
    if (_isInitialized) return;
    try {
      await Hive.initFlutter();
    } catch (_) {
      // Tests u otro path ya inicializado: continuar.
    }
    ensureSeriesAdaptersRegistered();
    try {
      _box = await Hive.openBox<WatchedEpisode>(boxName);
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error abriendo box $boxName: $e. Reparando.');
      }
      await Hive.deleteBoxFromDisk(boxName);
      _box = await Hive.openBox<WatchedEpisode>(boxName);
      _isInitialized = true;
    }
  }

  Future<Set<String>> watchedKeysForSerie(int serieId) async {
    if (!_isInitialized) await _initHive();
    final box = _box;
    if (box == null) return {};
    return box.values
        .where((w) => w.serieId == serieId && !w.isDeleted)
        .map((w) => w.key)
        .toSet();
  }

  Future<bool> isEpisodeWatched(
      int serieId, int seasonNumber, int episodeNumber) async {
    final keys = await watchedKeysForSerie(serieId);
    return keys.contains('$serieId-$seasonNumber-$episodeNumber');
  }

  Future<void> markEpisodeWatched({
    required int serieId,
    required int seasonNumber,
    required int episodeNumber,
    String serieName = '',
    String posterPath = '',
  }) async {
    if (!_isInitialized) await _initHive();
    final box = _box;
    if (box == null) throw Exception('Watched episodes box not available');
    final key = '$serieId-$seasonNumber-$episodeNumber';
    final exists = box.values.any((w) => w.key == key && !w.isDeleted);
    if (exists) return;
    await box.put(
      key,
      WatchedEpisode(
        serieId: serieId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        watchedDate: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        serieName: serieName,
        posterPath: posterPath,
      ),
    );
  }

  Future<void> unmarkEpisodeWatched(
      int serieId, int seasonNumber, int episodeNumber) async {
    if (!_isInitialized) await _initHive();
    final box = _box;
    if (box == null) return;
    await box.delete('$serieId-$seasonNumber-$episodeNumber');
  }

  Future<void> markSeasonWatched({
    required int serieId,
    required int seasonNumber,
    required List<Episodio> episodes,
    String serieName = '',
    String posterPath = '',
  }) async {
    for (final episode in episodes) {
      await markEpisodeWatched(
        serieId: serieId,
        seasonNumber: seasonNumber,
        episodeNumber: episode.episodeNumber,
        serieName: serieName,
        posterPath: posterPath,
      );
    }
  }
}
