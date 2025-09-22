import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/movie.dart';
import '../../l10n/app_localizations.dart';
import '../providers/storage/direct_watchlist_provider.dart';
import '../widgets/movies/movie_masonry_with_ads.dart';

class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // Safe fallback text when localizations are not available
    final emptyWatchlistText = l10n?.emptyWatchlist ?? 'Empty Watchlist!';
    final emptyWatchlistMessageText = l10n?.emptyWatchlistMessage ??
        l10n?.noWatchlistMoviesYet ??
        'You haven\'t added any movies to your watchlist yet';
    final startExploringText = l10n?.startExploring ?? 'Start Exploring';

    final watchlistMovies =
        ref.watch(directWatchlistMoviesProvider).values.toList();
    final movies = watchlistMovies
        .map((wm) => Movie(
              id: wm.movieId,
              title: wm.movieTitle,
              posterPath: wm.moviePosterPath ?? '',
              backdropPath: wm.movieBackdropPath ?? '',
              overview: wm.movieOverview ?? '',
              releaseDate: wm.movieReleaseDate ?? DateTime.now(),
              voteAverage: wm.movieVoteAverage ?? 0.0,
              genreIds: [],
              adult: false,
              originalLanguage: 'en',
              originalTitle: wm.movieTitle,
              popularity: 0.0,
              video: false,
              voteCount: 0,
            ))
        .toList();

    if (movies.isEmpty) {
      final colors = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_outline, size: 60, color: colors.primary),
            Text(emptyWatchlistText,
                style: TextStyle(fontSize: 30, color: colors.primary)),
            Text(emptyWatchlistMessageText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            FilledButton.tonal(
                onPressed: () => context.go('/'),
                child: Text(startExploringText)),
          ],
        ),
      );
    }

    return MovieMasonryWithAds(movies: movies, loadNextPage: () {});
  }
}
