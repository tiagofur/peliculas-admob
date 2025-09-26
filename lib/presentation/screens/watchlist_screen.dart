import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/movie.dart';
import '../../domain/entities/watchlist_movie.dart';
import '../../generated/app_localizations.dart';
import '../providers/storage/direct_watchlist_provider.dart';
import '../widgets/admob/native_ad_widget.dart';
import '../widgets/sync/minimal_sync_indicator.dart';
import '../widgets/sync/sync_refresh_wrapper.dart';
import '../widgets/watchlist/priority_filter_chip.dart';
import '../widgets/watchlist/watchlist_movie_card.dart';

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  static const name = 'watchlist-screen';

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  WatchlistPriority? _selectedPriority;

  @override
  Widget build(BuildContext context) {
    // Usar el sistema directo que mantiene datos en tiempo real
    final watchlistMovies = ref.watch(directWatchlistMoviesProvider);
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    // Filtrar por prioridad si está seleccionada
    List<WatchlistMovie> filteredMovies = watchlistMovies.values.toList();
    if (_selectedPriority != null) {
      filteredMovies = filteredMovies
          .where((movie) => movie.priority == _selectedPriority)
          .toList();
    }

    // Ordenar por fecha de agregado (más recientes primero)
    filteredMovies.sort((a, b) => b.addedAt.compareTo(a.addedAt));

    return Scaffold(
      body: SyncRefreshWrapper(
        onRefresh: () async {
          ref.read(directWatchlistMoviesProvider.notifier).enableAfterLogin();
        },
        child: Column(
          children: [
            const MinimalSyncIndicator(),
            _buildPriorityFilters(context, l10n),
            Expanded(
              child: filteredMovies.isEmpty
                  ? _buildEmptyState(context, l10n, colors)
                  : _buildWatchlistList(filteredMovies),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityFilters(BuildContext context, AppLocalizations l10n) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            PriorityFilterChip(
              label: l10n.all,
              isSelected: _selectedPriority == null,
              onTap: () {
                setState(() {
                  _selectedPriority = null;
                });
              },
            ),
            const SizedBox(width: 8),
            PriorityFilterChip(
              label: l10n.watchlistPriorityHigh,
              isSelected: _selectedPriority == WatchlistPriority.alta,
              color: colors.error,
              onTap: () {
                setState(() {
                  _selectedPriority = WatchlistPriority.alta;
                });
              },
            ),
            const SizedBox(width: 8),
            PriorityFilterChip(
              label: l10n.watchlistPriorityNormal,
              isSelected: _selectedPriority == WatchlistPriority.normal,
              color: colors.secondary,
              onTap: () {
                setState(() {
                  _selectedPriority = WatchlistPriority.normal;
                });
              },
            ),
            const SizedBox(width: 8),
            PriorityFilterChip(
              label: l10n.watchlistPriorityLow,
              isSelected: _selectedPriority == WatchlistPriority.baja,
              color: colors.tertiary,
              onTap: () {
                setState(() {
                  _selectedPriority = WatchlistPriority.baja;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colors,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bookmark_border,
                          size: 60,
                          color: colors.primary,
                        ),
                        Text(
                          _selectedPriority == null
                              ? l10n.watchlistEmptyTitle
                              : l10n.watchlistEmptyFiltered(
                                  _priorityLabel(l10n, _selectedPriority!)
                                      .toLowerCase(),
                                ),
                          style: TextStyle(
                            fontSize: 30,
                            color: colors.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          l10n.watchlistEmptyDescription,
                          style: const TextStyle(fontSize: 20),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.tonal(
                          onPressed: () => context.go('/'),
                          child: Text(l10n.watchlistExploreButton),
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: NativeAdWidget(
                    height: 90,
                    showLabel: false,
                    borderRadius: 8,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWatchlistList(List<WatchlistMovie> movies) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        return WatchlistMovieCard(
          movie: movie,
          onRemove: () {
            _showRemoveConfirmationDialog(movie);
          },
          onPriorityChanged: (newPriority) {
            ref
                .read(directWatchlistMoviesProvider.notifier)
                .changePriority(movie.movieId, newPriority);
          },
          onTap: () {
            context.push('/movie/${movie.movieId}');
          },
        );
      },
    );
  }

  String _priorityLabel(AppLocalizations l10n, WatchlistPriority priority) {
    switch (priority) {
      case WatchlistPriority.alta:
        return l10n.watchlistPriorityHigh;
      case WatchlistPriority.normal:
        return l10n.watchlistPriorityNormal;
      case WatchlistPriority.baja:
        return l10n.watchlistPriorityLow;
    }
  }

  void _showRemoveConfirmationDialog(WatchlistMovie movie) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) {
        final dialogL10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          title: Text(dialogL10n.watchlistRemoveDialogTitle),
          content: Text(
            dialogL10n.watchlistRemoveDialogMessage(movie.movieTitle),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(dialogL10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                // Crear objeto Movie para el método toggleWatchlist
                final movieEntity = Movie(
                  id: movie.movieId,
                  title: movie.movieTitle,
                  overview: movie.movieOverview ?? '',
                  releaseDate: movie.movieReleaseDate ?? DateTime.now(),
                  posterPath: movie.moviePosterPath ?? '',
                  backdropPath: movie.movieBackdropPath ?? '',
                  genreIds: const [],
                  originalLanguage: 'en',
                  originalTitle: movie.movieTitle,
                  popularity: 0.0,
                  voteAverage: movie.movieVoteAverage ?? 0.0,
                  voteCount: 0,
                  adult: false,
                  video: false,
                );

                // Remover usando el provider directo
                await ref
                    .read(directWatchlistMoviesProvider.notifier)
                    .toggleWatchlist(movieEntity);

                // Mostrar snackbar de confirmación de forma más segura
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.watchlistRemoveSuccess(movie.movieTitle),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Text(dialogL10n.watchlistRemoveDialogConfirm),
            ),
          ],
        );
      },
    );
  }
}
