import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../generated/app_localizations.dart';
import '../../providers/watched_movies_provider.dart';
import '../../widgets/movies/movie_masonry_with_ads.dart';
import '../../widgets/admob/native_ad_widget.dart';
import '../../widgets/sync/sync_refresh_wrapper.dart';
import '../../widgets/sync/sync_status_indicator.dart';

class WatchedView extends ConsumerStatefulWidget {
  const WatchedView({super.key});

  @override
  WatchedViewState createState() => WatchedViewState();
}

class WatchedViewState extends ConsumerState<WatchedView>
    with AutomaticKeepAliveClientMixin {
  void loadNextPage() {
    ref.read(watchedMoviesProvider.notifier).loadNextPage();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final watchedMoviesState = ref.watch(watchedMoviesProvider);
    final watchedMovies = watchedMoviesState.movies
        .map((watchedMovie) => watchedMovie.movie)
        .toList();
    final l10n = AppLocalizations.of(context)!;

    if (watchedMovies.isEmpty) {
      final colors = Theme.of(context).colorScheme;
      return SyncRefreshWrapper(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              children: [
                // Indicador de sync en la parte superior
                const SyncStatusCard(),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility_outlined, size: 60, color: colors.primary),
                        Text(l10n.notWatchedYet,
                            style: TextStyle(fontSize: 30, color: colors.primary)),
                        Text(l10n.noWatchedMessage,
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 20),
                        FilledButton.tonal(
                            onPressed: () => context.go('/'),
                            child: Text(l10n.startExploring))
                      ],
                    ),
                  ),
                ),
                // Anuncio discreto al final cuando no hay películas vistas
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
        ),
      );
    }

    return Scaffold(
      body: SyncRefreshWrapper(
        onRefresh: () async {
          // Refrescar datos específicos de películas vistas
          ref.read(watchedMoviesProvider.notifier).loadNextPage();
        },
        child: Column(
          children: [
            // Indicador de sync compacto
            const SyncStatusCard(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: WatchedMasonryWithAds(
                  loadNextPage: loadNextPage, 
                  movies: watchedMovies
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
