import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/watched_movies_provider.dart';
import '../../widgets/movies/movie_masonry_with_ads.dart';
import '../../widgets/admob/native_ad_widget.dart';

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

    if (watchedMovies.isEmpty) {
      final colors = Theme.of(context).colorScheme;
      return Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.visibility_outlined, size: 60, color: colors.primary),
                  Text('¡Aún no has visto nada!',
                      style: TextStyle(fontSize: 30, color: colors.primary)),
                  const Text('No tienes películas marcadas como vistas',
                      style: TextStyle(fontSize: 20)),
                  const SizedBox(height: 20),
                  FilledButton.tonal(
                      onPressed: () => context.go('/'),
                      child: const Text('Empieza a explorar'))
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
      );
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: WatchedMasonryWithAds(loadNextPage: loadNextPage, movies: watchedMovies),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
