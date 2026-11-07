import 'dart:async';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/serie.dart';

typedef SearchSeriesCallback = Future<List<Serie>> Function(String query);

class SearchSeriesDelegate extends SearchDelegate<Serie?> {
  SearchSeriesDelegate({
    required this.searchSeries,
    required this.initialSeries,
  }) : super(searchFieldLabel: 'Buscar series');

  final SearchSeriesCallback searchSeries;
  List<Serie> initialSeries;

  StreamController<List<Serie>> debouncedSeries = StreamController.broadcast();
  StreamController<bool> isLoadingStream = StreamController.broadcast();

  Timer? _debounceTimer;

  void clearStreams() {
    debouncedSeries.close();
  }

  void _onQueryChanged(String query) {
    isLoadingStream.add(true);

    final timer = _debounceTimer;
    if (timer?.isActive ?? false) timer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final series = await searchSeries(query);
      initialSeries = series;
      debouncedSeries.add(series);
      isLoadingStream.add(false);
    });
  }

  Widget buildResultsAndSuggestions() {
    return StreamBuilder(
      initialData: initialSeries,
      stream: debouncedSeries.stream,
      builder: (context, snapshot) {
        final series = snapshot.data ?? [];

        return ListView.builder(
          itemCount: series.length,
          itemBuilder: (context, index) => _SerieItem(
            serie: series[index],
            onSerieSelected: (context, serie) {
              clearStreams();
              close(context, serie);
            },
          ),
        );
      },
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      StreamBuilder(
        initialData: false,
        stream: isLoadingStream.stream,
        builder: (context, snapshot) {
          if (snapshot.data ?? false) {
            return SpinPerfect(
              duration: const Duration(seconds: 20),
              spins: 10,
              infinite: true,
              child: IconButton(
                  onPressed: () => query = '',
                  icon: const Icon(Icons.refresh_rounded)),
            );
          }

          return FadeIn(
            animate: query.isNotEmpty,
            child: IconButton(
                onPressed: () => query = '', icon: const Icon(Icons.clear)),
          );
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
        onPressed: () {
          clearStreams();
          close(context, null);
        },
        icon: const Icon(Icons.arrow_back_ios_new_rounded));
  }

  @override
  Widget buildResults(BuildContext context) {
    return buildResultsAndSuggestions();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    _onQueryChanged(query);
    return buildResultsAndSuggestions();
  }
}

class _SerieItem extends StatelessWidget {
  const _SerieItem({required this.serie, required this.onSerieSelected});

  final Serie serie;
  final void Function(BuildContext, Serie) onSerieSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: serie.posterPath.isEmpty
          ? const Icon(Icons.tv)
          : Image.network(
              'https://image.tmdb.org/t/p/w92${serie.posterPath}',
              width: 50,
              errorBuilder: (_, _, _) => const Icon(Icons.tv),
            ),
      title: Text(serie.name),
      subtitle: Text(serie.firstAirDate != null
          ? '${serie.firstAirDate!.year}'
          : ''),
      trailing: serie.voteAverage > 0
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, size: 16),
                Text(serie.voteAverage.toStringAsFixed(1)),
              ],
            )
          : null,
      onTap: () => onSerieSelected(context, serie),
    );
  }
}
