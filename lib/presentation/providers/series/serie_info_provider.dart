import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../domain/entities/serie.dart';
import 'series_repository_provider.dart';

final serieLoadFailuresProvider =
    NotifierProvider<_SerieIdSetNotifier, Set<String>>(_SerieIdSetNotifier.new);

final serieLoadInProgressProvider =
    NotifierProvider<_SerieIdSetNotifier, Set<String>>(_SerieIdSetNotifier.new);

class _SerieIdSetNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  bool contains(String id) => state.contains(id);

  void add(String id) => state = <String>{...state, id};

  void remove(String id) {
    if (!state.contains(id)) return;
    final updated = <String>{...state}..remove(id);
    state = updated;
  }

  void clear() => state = const <String>{};
}

final serieInfoProvider =
    AsyncNotifierProvider<SerieMapNotifier, Map<String, Serie>>(
  SerieMapNotifier.new,
);

class SerieMapNotifier extends AsyncNotifier<Map<String, Serie>> {
  @override
  FutureOr<Map<String, Serie>> build() {
    return {};
  }

  Future<void> loadSerie(String serieId, {bool force = false}) async {
    final failuresNotifier = ref.read(serieLoadFailuresProvider.notifier);
    final loadingNotifier = ref.read(serieLoadInProgressProvider.notifier);

    if (!force && failuresNotifier.contains(serieId)) {
      LoggerFactory.debug(
          'SerieMapNotifier: omitiendo carga de $serieId por fallo previo');
      return;
    }

    if (loadingNotifier.contains(serieId)) {
      return;
    }

    if (!force && (state.value?.containsKey(serieId) ?? false)) {
      return;
    }

    loadingNotifier.add(serieId);

    final currentSeries = Map<String, Serie>.from(state.value ?? {});
    final seriesRepository = ref.read(seriesRepositoryProvider);

    try {
      final serie = await seriesRepository.getSerieById(serieId);
      failuresNotifier.remove(serieId);

      final updatedSeries = Map<String, Serie>.from(currentSeries)
        ..[serieId] = serie;

      state = AsyncValue.data(updatedSeries);
    } catch (e, stackTrace) {
      LoggerFactory.error('SerieMapNotifier: error cargando $serieId: $e',
          stackTrace: stackTrace);
      failuresNotifier.add(serieId);
      state = AsyncValue.error(e, stackTrace);
    } finally {
      loadingNotifier.remove(serieId);
    }
  }

  void clear() {
    state = const AsyncValue.data({});
    ref.read(serieLoadFailuresProvider.notifier).clear();
    ref.read(serieLoadInProgressProvider.notifier).clear();
  }
}
