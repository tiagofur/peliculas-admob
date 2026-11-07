import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/tmdb_image_utils.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/series/serie_info_provider.dart';
import '../../providers/series/series_filter_provider.dart';
import '../../providers/series/series_repository_provider.dart';
import '../../providers/series/watched_series_provider.dart';
import '../../widgets/skeletons/skeletons.dart';

String serieMetaLine(Serie serie) {
  final parts = <String>[];
  if (serie.numberOfSeasons > 0) {
    parts.add(
        '${serie.numberOfSeasons} temporada${serie.numberOfSeasons == 1 ? '' : 's'}');
  }
  if (serie.numberOfEpisodes > 0) {
    parts.add('${serie.numberOfEpisodes} episodios');
  }
  if (serie.status.isNotEmpty) {
    parts.add(_serieStatusLabel(serie.status));
  }
  return parts.join(' · ');
}

String _serieStatusLabel(String status) {
  switch (status) {
    case 'Returning Series':
      return 'En emisión';
    case 'Ended':
      return 'Finalizada';
    case 'Canceled':
    case 'Cancelled':
      return 'Cancelada';
    case 'In Production':
      return 'En producción';
    case 'Planned':
      return 'Planeada';
    case 'Pilot':
      return 'Piloto';
    default:
      return status;
  }
}

String episodeLabel(Episodio episode) {
  final number = 'E${episode.episodeNumber}';
  if (episode.name.isEmpty) return number;
  return '$number · ${episode.name}';
}

class SerieScreen extends ConsumerStatefulWidget {
  const SerieScreen({super.key, required this.serieId});

  static const name = 'serie-screen';

  final String serieId;

  @override
  SerieScreenState createState() => SerieScreenState();
}

class SerieScreenState extends ConsumerState<SerieScreen> {
  int _retryCount = 0;
  static const int _maxRetries = 2;
  bool _disposed = false;
  int _season = 1;
  String _episodesKey = '';
  bool _episodesLoading = false;
  String? _episodesError;
  List<Episodio> _episodes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      final cache = ref.read(serieInfoProvider).value;
      if (cache == null || cache[widget.serieId] == null) {
        _loadSerieWithRetry();
      } else {
        _ensureEpisodes(cache[widget.serieId]!);
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _loadSerieWithRetry() async {
    if (_disposed) return;
    try {
      await ref.read(serieInfoProvider.notifier).loadSerie(widget.serieId);
      if (!_disposed && mounted) {
        final serie = ref.read(serieInfoProvider).value?[widget.serieId];
        if (serie != null) _ensureEpisodes(serie);
      }
    } catch (_) {
      if (_retryCount < _maxRetries && !_disposed && mounted) {
        _retryCount++;
        await Future.delayed(Duration(seconds: _retryCount));
        if (!_disposed && mounted) _loadSerieWithRetry();
      } else if (!_disposed && mounted) {
        _showErrorSnackbar();
      }
    }
  }

  void _showErrorSnackbar() {
    if (!mounted || _disposed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('No se pudo cargar la serie'),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Reintentar',
          textColor: Colors.white,
          onPressed: () {
            if (!_disposed && mounted) {
              _retryCount = 0;
              _loadSerieWithRetry();
            }
          },
        ),
      ),
    );
  }

  Future<void> _ensureEpisodes(Serie serie) async {
    final key = '${widget.serieId}-$_season';
    if (key == _episodesKey || _episodesLoading) return;
    _episodesKey = key;
    setState(() {
      _episodesLoading = true;
      _episodesError = null;
    });
    final serieId = int.tryParse(widget.serieId) ?? serie.id;
    try {
      final repository = ref.read(seriesRepositoryProvider);
      final episodes = await repository.getEpisodes(serieId, _season);
      await ref.read(watchedSeriesProvider.notifier).loadSerie(serie.id);
      if (_disposed || !mounted) return;
      setState(() {
        _episodes = episodes;
        _episodesLoading = false;
      });
    } catch (e) {
      if (_disposed || !mounted) return;
      setState(() {
        _episodesLoading = false;
        _episodesError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final seriesCache = ref.watch(serieInfoProvider);

    return seriesCache.when(
      loading: () => const Scaffold(body: MovieDetailsSkeleton()),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('No se pudo cargar la serie: $error')),
      ),
      data: (cache) {
        final serie = cache[widget.serieId];
        if (serie == null) {
          return const Scaffold(body: MovieDetailsSkeleton());
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_disposed && mounted) _ensureEpisodes(serie);
        });
        return _buildDetail(context, ref, serie);
      },
    );
  }

  Widget _buildDetail(BuildContext context, WidgetRef ref, Serie serie) {
    final watched = ref.watch(watchedSeriesProvider);
    final total = serie.numberOfEpisodes > 0
        ? serie.numberOfEpisodes
        : _episodes.length;
    final progress =
        ref.read(watchedSeriesProvider.notifier).progressFor(serie.id, total);
    final genreNames = _genreNames(ref, serie);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(serie.name, maxLines: 1),
              background: Image.network(
                resolveBackdropUrl(serie.backdropPath.isEmpty
                    ? serie.posterPath
                    : serie.backdropPath),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Colors.black26),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serieMetaLine(serie),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    if (genreNames.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        children: genreNames
                            .map((g) => Chip(label: Text(g)))
                            .toList(),
                      ),
                    if (genreNames.isNotEmpty) const SizedBox(height: 8),
                    if (serie.overview.isNotEmpty) Text(serie.overview),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: progress.percent,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                            '${progress.watchedEpisodeCount}/$total vistos'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Temporada'),
                        const SizedBox(width: 12),
                        DropdownButton<int>(
                          value: _season,
                          items: List.generate(
                            serie.numberOfSeasons > 0
                                ? serie.numberOfSeasons
                                : 1,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text('T${i + 1}'),
                            ),
                          ),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _season = value;
                              _episodesKey = '';
                              _episodes = [];
                            });
                            _ensureEpisodes(serie);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_episodesLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_episodesError != null)
                      Row(
                        children: [
                          Expanded(
                              child:
                                  Text('Error: $_episodesError')),
                          TextButton(
                            onPressed: () {
                              _episodesKey = '';
                              _ensureEpisodes(serie);
                            },
                            child: const Text('Reintentar'),
                          ),
                        ],
                      )
                    else
                      ..._episodes.map((episode) => _EpisodeTile(
                            episode: episode,
                            serie: serie,
                            isWatched: watched.watchedKeys
                                .contains(episode.key),
                          )),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  List<String> _genreNames(WidgetRef ref, Serie serie) {
    final options = ref.watch(seriesGenreOptionsProvider);
    final byId = {for (final o in options) o.id: o.name};
    return serie.genreIds
        .map((id) => byId[id])
        .whereType<String>()
        .toList();
  }
}

class _EpisodeTile extends ConsumerWidget {
  const _EpisodeTile({
    required this.episode,
    required this.serie,
    required this.isWatched,
  });

  final Episodio episode;
  final Serie serie;
  final bool isWatched;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: episode.stillPath.isEmpty
            ? const Icon(Icons.tv)
            : Image.network(
                resolvePosterUrl(episode.stillPath, size: 'w185'),
                width: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.tv),
              ),
        title: Text(episodeLabel(episode)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (episode.runtime != null)
              Text('${episode.runtime} min'),
            if (episode.overview.isNotEmpty)
              Text(episode.overview,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: Checkbox(
          value: isWatched,
          onChanged: (_) {
            ref.read(watchedSeriesProvider.notifier).toggleEpisode(
                  serieId: serie.id,
                  seasonNumber: episode.seasonNumber,
                  episodeNumber: episode.episodeNumber,
                  serieName: serie.name,
                  posterPath: serie.posterPath,
                );
          },
        ),
      ),
    );
  }
}
