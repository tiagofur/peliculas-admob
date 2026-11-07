import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../domain/entities/entities.dart';
import 'series_repository_provider.dart';

enum SeriesState {
  initial,
  loading,
  loaded,
  error,
}

class SeriesStateData {
  const SeriesStateData({
    this.series = const [],
    this.state = SeriesState.initial,
    this.errorMessage,
    this.hasReachedMax = false,
  });

  final List<Serie> series;
  final SeriesState state;
  final String? errorMessage;
  final bool hasReachedMax;

  SeriesStateData copyWith({
    List<Serie>? series,
    SeriesState? state,
    String? errorMessage,
    bool? hasReachedMax,
  }) {
    return SeriesStateData(
      series: series ?? this.series,
      state: state ?? this.state,
      errorMessage: errorMessage,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    );
  }
}

final popularSeriesProvider =
    NotifierProvider<PopularSeriesNotifier, SeriesStateData>(
        PopularSeriesNotifier.new);

final topRatedSeriesProvider =
    NotifierProvider<TopRatedSeriesNotifier, SeriesStateData>(
        TopRatedSeriesNotifier.new);

final onTheAirSeriesProvider =
    NotifierProvider<OnTheAirSeriesNotifier, SeriesStateData>(
        OnTheAirSeriesNotifier.new);

final airingTodaySeriesProvider =
    NotifierProvider<AiringTodaySeriesNotifier, SeriesStateData>(
        AiringTodaySeriesNotifier.new);

typedef SerieCallback = Future<List<Serie>> Function({int page});

abstract class SeriesNotifier extends Notifier<SeriesStateData> {
  int currentPage = 0;
  SerieCallback? fetchMoreSeries;
  static const int maxRetries = 3;

  Future<void> loadNextPage() async {
    if (state.state == SeriesState.loading ||
        state.hasReachedMax ||
        fetchMoreSeries == null) {
      return;
    }

    state = state.copyWith(state: SeriesState.loading);

    try {
      final series = await fetchMoreSeries!(page: currentPage + 1);
      currentPage++;

      if (series.isEmpty) {
        state = state.copyWith(
          state: SeriesState.loaded,
          hasReachedMax: true,
        );
        return;
      }

      state = state.copyWith(
        hasReachedMax: false,
        state: SeriesState.loaded,
        series: [...state.series, ...series],
      );
    } catch (e) {
      LoggerFactory.error('SeriesNotifier: Error al cargar series: $e');
      state = state.copyWith(
        state: SeriesState.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    try {
      currentPage = 0;
      state = state.copyWith(
        state: SeriesState.loading,
        series: [],
        hasReachedMax: false,
        errorMessage: null,
      );
      await loadNextPage();
    } catch (e) {
      LoggerFactory.error('SeriesNotifier: Error al refrescar series: $e');
      state = state.copyWith(
        state: SeriesState.error,
        errorMessage: 'Error al refrescar series: ${e.toString()}',
      );
    }
  }

  void clearError() {
    if (state.state == SeriesState.error) {
      state = state.copyWith(
        state: state.series.isEmpty ? SeriesState.initial : SeriesState.loaded,
        errorMessage: null,
      );
    }
  }
}

class PopularSeriesNotifier extends SeriesNotifier {
  @override
  SeriesStateData build() {
    final repository = ref.watch(seriesRepositoryProvider);
    fetchMoreSeries = repository.getPopular;
    return const SeriesStateData();
  }
}

class TopRatedSeriesNotifier extends SeriesNotifier {
  @override
  SeriesStateData build() {
    final repository = ref.watch(seriesRepositoryProvider);
    fetchMoreSeries = repository.getTopRated;
    return const SeriesStateData();
  }
}

class OnTheAirSeriesNotifier extends SeriesNotifier {
  @override
  SeriesStateData build() {
    final repository = ref.watch(seriesRepositoryProvider);
    fetchMoreSeries = repository.getOnTheAir;
    return const SeriesStateData();
  }
}

class AiringTodaySeriesNotifier extends SeriesNotifier {
  @override
  SeriesStateData build() {
    final repository = ref.watch(seriesRepositoryProvider);
    fetchMoreSeries = repository.getAiringToday;
    return const SeriesStateData();
  }
}
