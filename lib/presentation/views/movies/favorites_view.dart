import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../generated/app_localizations.dart';
import '../../providers/providers.dart';
import '../../widgets/admob/native_ad_widget.dart';
import '../../widgets/movies/movie_masonry_with_ads.dart';
import '../../widgets/sync/sync_refresh_wrapper.dart';
import '../../widgets/sync/sync_status_indicator.dart';

class FavoritesView extends ConsumerStatefulWidget {
  const FavoritesView({super.key});

  @override
  FavoritesViewState createState() => FavoritesViewState();
}

class FavoritesViewState extends ConsumerState<FavoritesView>
    with AutomaticKeepAliveClientMixin {
  bool isLastPage = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    loadNextPage();
  }

  void loadNextPage() async {
    if (isLoading || isLastPage) return;
    isLoading = true;

    final movies =
        await ref.read(favoriteMoviesProvider.notifier).loadNextPage();
    isLoading = false;

    if (movies.isEmpty) {
      isLastPage = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final favoriteMovies = ref.watch(favoriteMoviesProvider).values.toList();
    final l10n = AppLocalizations.of(context)!;

    if (favoriteMovies.isEmpty) {
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
                        Icon(Icons.favorite_outline_sharp,
                            size: 60, color: colors.primary),
                        Text(l10n.noFavorites,
                            style:
                                TextStyle(fontSize: 30, color: colors.primary)),
                        Text(l10n.noFavoritesMessage,
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 20),
                        FilledButton.tonal(
                            onPressed: () => context.go('/'),
                            child: Text(l10n.startSearching))
                      ],
                    ),
                  ),
                ),
                // Anuncio discreto al final
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
          // Refrescar datos específicos de favoritos
          await ref.refresh(favoriteMoviesProvider.notifier).loadNextPage();
        },
        child: Column(
          children: [
            // Indicador de sync compacto
            const SyncStatusCard(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FavoritesMasonryWithAds(
                    loadNextPage: loadNextPage, movies: favoriteMovies),
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
